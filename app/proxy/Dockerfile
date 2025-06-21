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

# Copy the setup and entrypoint scripts
COPY setup.sh /setup.sh
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Remove default nginx config to ensure our template is used
RUN rm -f /etc/nginx/conf.d/default.conf

# Set permissions for scripts (this must be done in Dockerfile)
RUN chmod 755 /setup.sh /docker-entrypoint.sh

# Run setup as root to create directories and set permissions
RUN /setup.sh

# Expose port 8000
EXPOSE 8000

# Set default backend host and port for template interpolation
ENV APP_HOST=localhost
ENV FLASK_PORT=5000
ENV PROXY_PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Switch to nginx user and use the startup script
USER nginx
CMD ["/docker-entrypoint.sh"] 