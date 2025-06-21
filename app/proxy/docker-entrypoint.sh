#!/bin/bash

# Create necessary directories
mkdir -p /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run

# Set ownership and permissions for all necessary directories
chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run
chmod -R 755 /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run

# Run environment substitution on templates
envsubst < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf

# Start nginx
exec nginx -g "daemon off;" 