#!/bin/bash

# Standalone database deployment script
# This script runs Terraform AND sets up database tables
# Use this for manual deployments or when you want full control
# For GitHub Actions, use deploy.yml + setup-database-tables.sh instead
# Usage: ./deploy-database.sh [prefix]

set -e

# Default prefix if not provided
PREFIX=${1:-"ml-simple"}

echo "=== Standalone Database Deployment Script ==="
echo "Prefix: ${PREFIX}"
echo "Note: This script runs Terraform directly"
echo ""

# Step 1: Determine database approach
echo "Step 1: Determining database approach..."
cd scripts

# Source the environment variables from determine-db-approach.sh
eval "$(./determine-db-approach.sh "${PREFIX}")"

echo "Database approach: ${DB_APPROACH}"
if [ "$USE_SNAPSHOT" = "true" ]; then
    echo "Snapshot identifier: ${SNAPSHOT_IDENTIFIER}"
else
    echo "Will create fresh database"
fi
echo ""

# Step 2: Run Terraform
echo "Step 2: Running Terraform..."
cd ..

# Export variables for Terraform
export USE_SNAPSHOT
export SNAPSHOT_IDENTIFIER

# Run Terraform apply
echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Step 3: Conditionally run table creation script
if [ "$USE_SNAPSHOT" = "false" ]; then
    echo ""
    echo "Step 3: Creating database tables (fresh database)..."
    
    # Get database connection details from Terraform output
    DB_HOST=$(terraform output -raw db_endpoint 2>/dev/null || echo "")
    DB_NAME=$(terraform output -raw db_name 2>/dev/null || echo "image-trainer-db")
    DB_USER=$(terraform output -raw db_username 2>/dev/null || echo "image-trainer-user")
    
    if [ -n "$DB_HOST" ]; then
        echo "Database endpoint: ${DB_HOST}"
        echo "Database name: ${DB_NAME}"
        echo "Database user: ${DB_USER}"
        
        # Wait for database to be ready
        echo "Waiting for database to be ready..."
        sleep 30
        
        # Run the table creation script
        cd scripts
        pip install -r requirements.txt
        python create-tables.py
        cd ..
        
        echo "✓ Database tables created successfully!"
    else
        echo "⚠ Could not get database details from Terraform output"
        echo "You may need to run the table creation script manually"
    fi
else
    echo ""
    echo "Step 3: Skipping table creation (restored from snapshot)"
    echo "✓ Database restored from snapshot with existing tables and data"
fi

echo ""
echo "=== Standalone Database Deployment Complete ===" 