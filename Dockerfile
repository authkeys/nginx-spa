FROM nginx

COPY expires.conf /etc/nginx/conf.d/expires.conf
COPY default.conf /etc/nginx/conf.d/default.conf
