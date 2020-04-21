
VERSION=$(cat VERSION)

sed -i '' 's/org.opencontainers.image.version=.*/org.opencontainers.image.version="'"${PACKAGE_VERSION}"'" \\/' Dockerfile

git add Dockerfile

