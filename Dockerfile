FROM nginx:alpine
RUN sed -i 's/^user .*/#user nginx;/; s/^pid .*/pid  \/var\/run\/nginx\/nginx.pid;/' /etc/nginx/nginx.conf \
    && mkdir /var/run/nginx \
    && chown nginx /var/cache/nginx /var/log/nginx /var/run/nginx
USER nginx
EXPOSE 8080
COPY default.conf /etc/nginx/conf.d/
