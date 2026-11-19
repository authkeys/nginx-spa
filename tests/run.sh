#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: bash tests/run.sh IMAGE" >&2
    exit 1
fi

fixtures="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
tmp="$(mktemp -d)"

cleanup() {
    local status=$?
    trap - EXIT
    if [[ $status -ne 0 ]]; then
        echo "HTTP integration tests failed." >&2
        if [[ -f "$tmp/headers" ]]; then
            cat "$tmp/headers" >&2
        fi
        if [[ -f "$tmp/body" ]]; then
            head -c 2048 "$tmp/body" >&2
            echo >&2
        fi
        if [[ -s "$tmp/container.cid" ]]; then
            docker logs --tail 50 "$(cat "$tmp/container.cid")" >&2 || status=1
        fi
    fi
    if [[ -s "$tmp/container.cid" ]]; then
        docker rm --force "$(cat "$tmp/container.cid")" >/dev/null || status=1
    fi
    rm -f "$tmp/container.cid" "$tmp/headers" "$tmp/body" || status=1
    rmdir "$tmp" || status=1
    exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

docker run --detach \
    --cidfile "$tmp/container.cid" \
    --publish 127.0.0.1::8080 \
    --mount "type=bind,source=$fixtures,target=/app,readonly" \
    "$1" >/dev/null
container_id="$(cat "$tmp/container.cid")"
base_url="http://$(docker port "$container_id" 8080/tcp)"

ready=false
for ((attempt = 0; attempt < 30; attempt++)); do
    if curl --noproxy '*' --silent --fail --max-time 1 "$base_url/" >/dev/null; then
        ready=true
        break
    fi
    sleep 1
done
[[ "$ready" == true ]] || fail "Container did not become ready"

request() {
    local path=$1 expected_status=$2
    shift 2
    echo "Checking $path (expected $expected_status)"
    local status
    status="$(curl --noproxy '*' --silent --show-error --max-time 5 \
        --dump-header "$tmp/headers" --output "$tmp/body" \
        --write-out '%{http_code}' "$@" "$base_url$path")"
    [[ "$status" == "$expected_status" ]] ||
        fail "$path: expected HTTP $expected_status, got $status"
}

header() {
    awk -v name="$1" '
        {
            sub(/\r$/, "")
            colon = index($0, ":")
            if (tolower(substr($0, 1, colon - 1)) == tolower(name)) {
                value = substr($0, colon + 1)
                sub(/^[ \t]+/, "", value)
                print value
            }
        }
    ' "$tmp/headers"
}

assert_body() {
    cmp -s "$fixtures/$1" "$tmp/body" || fail "Body differs from $1"
}

assert_type() {
    local actual
    actual="$(header Content-Type | awk -F ';' '{ print tolower($1) }')"
    [[ "$actual" == "$1" ]] || fail "Expected Content-Type $1, got $actual"
}

assert_cache() {
    header Cache-Control | tr ',' '\n' |
        awk '{ gsub(/^[ \t]+|[ \t]+$/, ""); print tolower($0) }' |
        grep -Fxq -- "$1" || fail "Missing Cache-Control directive: $1"
}

assert_epoch_cache() {
    assert_cache "$1"
    assert_cache no-cache
    [[ "$(header Expires)" == "Thu, 01 Jan 1970 00:00:01 GMT" ]] ||
        fail "Expected epoch Expires header"
}

assert_uncompressed() {
    [[ -z "$(header Content-Encoding)" ]] || fail "Unexpected Content-Encoding"
}

http_timestamp() {
    # GNU date on CI, BSD date on macOS.
    date -u -d "$1" +%s 2>/dev/null ||
        LC_ALL=C date -j -u -f '%a, %d %b %Y %T GMT' "$1" +%s
}

for path in / /index.html /account/settings '/account/settings?tab=profile' /missing.html; do
    request "$path" 200
    assert_body index.html
    assert_type text/html
    assert_epoch_cache no-store
done

request /another.html 200
assert_body another.html
assert_type text/html
assert_epoch_cache no-store

request /test.css 200
assert_body test.css
assert_type text/css
assert_epoch_cache private

request /test.js 200
assert_body test.js
assert_type application/javascript
assert_epoch_cache private

request /large.svg 200
assert_body large.svg
assert_type image/svg+xml
assert_cache private
assert_cache max-age=43200
response_date="$(http_timestamp "$(header Date)")"
expires="$(http_timestamp "$(header Expires)")"
[[ $((expires - response_date)) -eq 43200 ]] || fail "Expected Expires 12 hours after Date"
assert_uncompressed

for extension in ico js css jpg jpeg png woff ttf svg gif map txt json JS; do
    request "/missing.$extension" 404
    if cmp -s "$fixtures/index.html" "$tmp/body"; then
        fail "Missing .$extension asset returned SPA document"
    fi
done

[[ "$(wc -c < "$fixtures/large.svg")" -gt 1024 ]] || fail "Gzip fixture must exceed 1024 bytes"
request /large.svg 200 --compressed --header 'Accept-Encoding: gzip'
[[ "$(header Content-Encoding)" == gzip ]] || fail "Expected gzip compression"
assert_body large.svg

[[ "$(wc -c < "$fixtures/test.js")" -lt 1024 ]] || fail "Small fixture must be below 1024 bytes"
request /test.js 200 --compressed --header 'Accept-Encoding: gzip'
assert_uncompressed
assert_body test.js

echo "All HTTP integration tests passed."
