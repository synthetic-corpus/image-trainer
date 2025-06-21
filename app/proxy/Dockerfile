# Nginx reverse proxy for image trainer application
FROM nginx:alpine

# Install necessary packages
RUN apk add --no-cache \
    bash \
    curl \
    gettext

# Copy configuration templates
COPY default.conf.tpl /etc/nginx/templates/default.conf.template
COPY gunicorn_headers /etc/nginx/gunicorn_headers

# Remove default nginx config to ensure our template is used
RUN rm -f /etc/nginx/conf.d/default.conf

# Create necessary directories and ensure proper permissions
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d && \
    chmod -R 755 /var/cache/nginx /var/run /var/log/nginx /etc/nginx/conf.d

# Create startup script to handle permissions and environment substitution
RUN echo '#!/bin/bash\n\
# Ensure nginx user can write to necessary directories\n\
mkdir -p /var/run /var/log/nginx /etc/nginx/conf.d\n\
chown -R nginx:nginx /var/run /var/log/nginx /etc/nginx/conf.d\n\
chmod -R 755 /var/run /var/log/nginx /etc/nginx/conf.d\n\
\n\
# Run environment substitution on templates\n\
envsubst < /etc/nginx/templates/default.conf.template > /etc/nginx/conf.d/default.conf\n\
\n\
# Start nginx\n\
exec nginx -g "daemon off;"' > /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh

# Expose port 8000
EXPOSE 8000

# Set default backend host and port for template interpolation
ENV APP_HOST=localhost
ENV APP_PORT=5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Use the startup script
CMD ["/docker-entrypoint.sh"] 