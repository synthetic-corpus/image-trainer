# Use Python 3.11 slim image as base
FROM python:3.11-slim

# Set working directory in container
WORKDIR /app

# Copy requirements file
COPY web/requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY web .

# Copy modules and ensure they're in Python path
COPY modules ./modules/
ENV PYTHONPATH=/app

# Expose port 5000 (for documentation; actual port is configurable via the PORT environment variable)
EXPOSE 5000

# Set environment variables
ENV PORT=5000
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV IMAGE_URL=https://some-cdn.amazonaws.com/my-placeholder.jpeg

# Run the Flask application
CMD flask run --host=0.0.0.0 --port=${PORT}
