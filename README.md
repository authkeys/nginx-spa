# Nginx SPA

## Description

The container will run the `nginx` process under the unprivileged user `nginx`. It exposes the port 8080

Gzip compression is enabled for files bigger than 1024 bytes.

## Single Page Application

All path that does not end with `.xxx` except `.html` (i.e. .css, .js, .png etc) must exists, otherwise 404 is returned.  
All other paths - without extension or that ends with `.html` - if not exists will return `/index.html`


### Usage

Extending the image:

```
FROM authkeys/nginx-spa

COPY dist/ /app
```

Using it:  

`docker run -p 8080:8080 -v $PWD/dist:/app authkeys/nginx-spa`

### Integration tests

With Docker, Bash and curl available, run the same HTTP checks as CI:

```sh
docker build --tag nginx-spa:test .
bash tests/run.sh nginx-spa:test
```

The runner mounts `tests/fixtures` read-only at `/app`, publishes port 8080 on a
dynamic localhost port, and removes the container when it exits. It checks SPA
fallback, missing assets, response bodies, MIME types, cache headers and gzip.
Failures print response details and container logs.

CI runs these tests on current platform after linting and before the existing multiarch
build. Tag publication is blocked if the tests fail; the published multiarch
image is built separately from the same sources.