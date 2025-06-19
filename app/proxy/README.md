# Nginx Reverse Proxy for Flask Web App behind AWS ALB

This directory contains the nginx reverse proxy configuration for the image trainer Flask application, optimized for deployment behind an AWS Application Load Balancer (ALB).

## Overview

The nginx reverse proxy:
- Listens on port 8000
- Proxies requests to the Flask web app (app.py)
- Designed for ECS deployment alongside the Flask container
- Optimized for AWS Application Load Balancer integration
- Provides rate limiting and security headers
- Includes gzip compression and caching
- Handles ALB-specific headers and real IP detection

## Files

- `Dockerfile` - Docker image definition
- `default.conf.tpl` - Nginx configuration template with environment variable substitution
- `gunicorn_headers` - Additional headers for Flask/gunicorn applications with ALB support
- `.dockerignore` - Files to exclude from Docker build

## Configuration

### Environment Variables

The nginx configuration uses these environment variables:

- `FLASK_HOST` - Flask app hostname (default: localhost)
- `FLASK_PORT` - Flask app port (default: 5000)

### ALB-Specific Features

1. **Real IP Detection**
   - Configures nginx to extract real client IPs from ALB headers
   - Supports private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
   - Uses X-Forwarded-For header for accurate client IP logging

2. **ALB Header Forwarding**
   - Forwards ALB-specific headers to Flask app
   - X-AWS-ELB-Health-Check
   - X-AWS-ELB-Id
   - X-AWS-ELB-Instance-Id

3. **Enhanced Proxy Headers**
   - X-Forwarded-Port
   - X-Forwarded-Host
   - Proper HTTP/1.1 connection handling

4. **Rate Limiting**
   - Web routes: 20 requests/second with burst of 30
   - API endpoints: 10 requests/second with burst of 20
   - Based on real client IPs (not ALB IPs)

5. **Security Headers**
   - X-Frame-Options
   - X-Content-Type-Options
   - X-XSS-Protection
   - Referrer-Policy

6. **Compression**
   - Gzip compression for text-based content types

7. **Static File Handling**
   - Proper caching for Flask static files
   - Optimized for CSS, JS, and images

8. **Health Check**
   - Endpoint: `/health`
   - Returns 200 OK when healthy
   - Compatible with ALB health checks

## ECS Deployment with ALB

This proxy is designed to be deployed behind an AWS Application Load Balancer:

### ALB Configuration:
- **Target Group**: Points to ECS service on port 8000
- **Health Check Path**: `/health`
- **Health Check Protocol**: HTTP
- **Health Check Interval**: 30 seconds
- **Health Check Timeout**: 5 seconds
- **Healthy Threshold**: 2
- **Unhealthy Threshold**: 3

### Task Definition Example:
```json
{
  "family": "image-trainer",
  "containerDefinitions": [
    {
      "name": "flask-app",
      "image": "your-ecr-repo/flask-app:latest",
      "portMappings": [
        {
          "containerPort": 5000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "FLASK_APP",
          "value": "app.py"
        }
      ]
    },
    {
      "name": "nginx-proxy",
      "image": "your-ecr-repo/nginx-proxy:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "FLASK_HOST",
          "value": "localhost"
        },
        {
          "name": "FLASK_PORT",
          "value": "5000"
        }
      ],
      "dependsOn": [
        {
          "containerName": "flask-app",
          "condition": "START"
        }
      ]
    }
  ]
}
```

## Building and Running

### Build the image:
```bash
docker build -t image-trainer-proxy .
```

### Run locally with Flask app:
```bash
# Start Flask app
docker run -d --name flask-app -p 5000:5000 your-flask-image

# Start proxy
docker run -d \
  -p 8000:8000 \
  -e FLASK_HOST=flask-app \
  -e FLASK_PORT=5000 \
  --link flask-app \
  --name nginx-proxy \
  image-trainer-proxy
```

## Endpoints

- `/health` - Health check endpoint (ALB compatible)
- `/static/*` - Flask static files with caching
- `/api/*` - API endpoints (future use)
- `/` - Main Flask application routes
- `/select-gender` - Gender selection endpoint

## Flask App Integration

The proxy is configured to work with your Flask app (`app/web/app.py`) which includes:
- Main index page (`/`)
- Gender selection endpoint (`/select-gender`)
- Static file serving (`/static/`)

## ALB Traffic Flow

1. **Client** → **ALB** (port 80/443)
2. **ALB** → **ECS Task** (port 8000)
3. **Nginx Proxy** → **Flask App** (port 5000)
4. **Flask App** → **Nginx Proxy** → **ALB** → **Client**

## Monitoring

The container includes a health check that:
- Runs every 30 seconds
- Times out after 3 seconds
- Retries 3 times before marking unhealthy
- Uses curl to check the `/health` endpoint
- Compatible with ALB health checks 