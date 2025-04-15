FROM nginx:1.27.4-alpine-slim

RUN rm -rf /usr/share/nginx/html/*

COPY index.html /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80