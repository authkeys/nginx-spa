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

