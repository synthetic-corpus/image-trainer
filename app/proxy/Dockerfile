# Nginx reverse proxy for image trainer application
FROM nginx:alpine

# Install necessary packages
RUN apk add --no-cache \
    bash \
    curl \
    gettext

# Create nginx user if it doesn't exist
RUN addgroup -g 101 -S nginx && \
    adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx

# Copy configuration templates
COPY default.conf.tpl /etc/nginx/templates/default.conf.template
COPY gunicorn_headers /etc/nginx/gunicorn_headers

# Create necessary directories
RUN mkdir -p /var/cache/nginx /var/run /var/log/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /var/log/nginx

# Expose port 8000
EXPOSE 8000

# Set default backend host and port for template interpolation
ENV APP_HOST=localhost
ENV APP_PORT=5000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"] 