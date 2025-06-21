# Nginx configuration template for Flask web app proxy behind AWS ALB
# Environment variables will be substituted at runtime

upstream flask_app {
    server ${APP_HOST}:${FLASK_PORT};
}

# Real IP configuration for ALB
real_ip_header X-Forwarded-For;
real_ip_recursive on;
set_real_ip_from 10.0.0.0/8;
set_real_ip_from 172.16.0.0/12;
set_real_ip_from 192.168.0.0/16;

server {
    listen 8000;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Client max body size for potential file uploads
    client_max_body_size 5M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Health check endpoint for ALB
    location /health {
        access_log off;
        proxy_pass http://${APP_HOST}:${FLASK_PORT};
        include /etc/nginx/gunicorn_headers;
        add_header Content-Type text/plain;
    }

    # Static files (CSS, JS, images)
    location /static/ {
        proxy_pass http://${APP_HOST}:${FLASK_PORT};
        
        # Cache static files
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Include gunicorn headers
        include /etc/nginx/gunicorn_headers;
    }

    # Flask routes
    location / {
        proxy_pass http://${APP_HOST}:${FLASK_PORT};
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Include gunicorn headers
        include /etc/nginx/gunicorn_headers;
    }

    # Error pages
    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    
    location = /50x.html {
        root /usr/share/nginx/html;
    }
} 