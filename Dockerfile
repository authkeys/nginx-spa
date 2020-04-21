FROM nginx:alpine
RUN sed -i 's/^user .*/#user nginx;/; s/^pid .*/pid  \/var\/run\/nginx\/nginx.pid;/' /etc/nginx/nginx.conf \
    && mkdir /var/run/nginx \
    && chown nginx /var/cache/nginx /var/log/nginx /var/run/nginx
USER nginx
EXPOSE 8080
COPY default.conf /etc/nginx/conf.d/

# Metadata
LABEL name="authkeys/nginx-spa" \
        description="Nginx for Single Page Application" \
        org.opencontainers.image.vendor="AuthKeys" \
        org.opencontainers.image.source="https://github.com/authkeys/nginx-spa" \
        org.opencontainers.image.title="nginx-spa" \
        org.opencontainers.image.description="Nginx for Single Page Application" \
        org.opencontainers.image.version="0.1.0" \
        org.opencontainers.image.documentation="https://github.com/authkeys/nginx-spa" \
        org.opencontainers.image.licenses='Apache-2.0'

