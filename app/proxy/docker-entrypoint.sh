#!/bin/bash

# Ensure nginx user can write to necessary directories
mkdir -p /var/run /var/log/nginx /etc/nginx/conf.d
chown -R nginx:nginx /var/run /var/log/nginx /etc/nginx/conf.d
chmod -R 755 /var/run /var/log/nginx /etc/nginx/conf.d

# Run environment substitution on templates
envsubst < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g "daemon off;" 