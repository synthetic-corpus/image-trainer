#!/bin/bash
# This file runs as the root user. Then later the nginx user is used.
# with all the permissions that this file set up for the nginx user.
# Create necessary directories
mkdir -p /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run

# Set ownership and permissions for all necessary directories
chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run
chmod -R 755 /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d /run 