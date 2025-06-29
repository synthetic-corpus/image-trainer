#!/bin/bash

# Database table setup script (runs after Terraform)
# Determines if tables need to be created based on snapshot usage
# Usage: ./setup-database-tables.sh [prefix]

set -e

# Default prefix if not provided
PREFIX=${1:-"ml-simple"}

echo "=== Database Table Setup ==="
echo "Prefix: ${PREFIX}"
echo ""

# Step 1: Determine if we need to create tables
echo "Step 1: Checking if tables need to be created..."
cd scripts

# Source the environment variables from determine-db-approach.sh
eval "$(./determine-db-approach.sh "${PREFIX}")"

echo "Database approach: ${DB_APPROACH}"
if [ "$USE_SNAPSHOT" = "true" ]; then
    echo "Snapshot identifier: ${SNAPSHOT_IDENTIFIER}"
    echo "✓ Database restored from snapshot - tables already exist"
    echo "=== Setup Complete ==="
    exit 0
else
    echo "Will create fresh database tables"
fi
echo ""

# Step 2: Create tables (only for fresh databases)
echo "Step 2: Creating database tables..."

# Get database connection details from environment variables
# These should be set by deploy.yml after Terraform runs
DB_HOST="${DB_HOST}"
DB_NAME="${DB_NAME:-image-trainer-db}"
DB_USER="${DB_USER:-image-trainer-user}"
DB_PASSWORD="${DB_PASSWORD}"

if [ -z "$DB_HOST" ]; then
    echo "❌ DB_HOST environment variable not set"
    echo "Make sure deploy.yml sets database connection details after Terraform"
    exit 1
fi

if [ -z "$DB_PASSWORD" ]; then
    echo "❌ DB_PASSWORD environment variable not set"
    exit 1
fi

echo "Database endpoint: ${DB_HOST}"
echo "Database name: ${DB_NAME}"
echo "Database user: ${DB_USER}"

# Wait for database to be ready
echo "Waiting for database to be ready..."
sleep 30

# Run the table creation script
echo "Creating tables..."
pip install -r requirements.txt
python create-tables.py

echo "✓ Database tables created successfully!"
echo "=== Setup Complete ===" 