# Nginx configuration template for Flask web app proxy behind AWS ALB
# Environment variables will be substituted at runtime

upstream flask_app {
    server ${FLASK_HOST:-localhost}:${FLASK_PORT:-5000};
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=web:10m rate=20r/s;
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

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
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Static files (CSS, JS, images)
    location /static/ {
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;
        
        # Cache static files
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Include gunicorn headers
        include /etc/nginx/gunicorn_headers;
    }

    # Flask routes with rate limiting
    location / {
        limit_req zone=web burst=30 nodelay;
        
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;
        
        # ALB-specific headers
        proxy_set_header X-AWS-ELB-Health-Check $http_x_aws_elb_health_check;
        proxy_set_header X-AWS-ELB-Id $http_x_aws_elb_id;
        proxy_set_header X-AWS-ELB-Instance-Id $http_x_aws_elb_instance_id;
        
        # Timeouts
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        
        # Include gunicorn headers
        include /etc/nginx/gunicorn_headers;
    }

    # API endpoints (if you add any later)
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://flask_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Port $server_port;
        proxy_set_header X-Forwarded-Host $host;
        
        # ALB-specific headers
        proxy_set_header X-AWS-ELB-Health-Check $http_x_aws_elb_health_check;
        proxy_set_header X-AWS-ELB-Id $http_x_aws_elb_id;
        proxy_set_header X-AWS-ELB-Instance-Id $http_x_aws_elb_instance_id;
        
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