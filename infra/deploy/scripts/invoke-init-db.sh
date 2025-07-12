#!/bin/bash

# Script to manually invoke the database initialization Lambda function
# Usage: ./invoke-init-db.sh [workspace]

set -e

# Default workspace
WORKSPACE=${1:-"staging"}

echo "=== Manual Database Initialization ==="
echo "Workspace: $WORKSPACE"

# Change to the deploy directory
cd "$(dirname "$0")/.."

# Select the workspace
terraform workspace select "$WORKSPACE"

# Get the Lambda function name
LAMBDA_FUNCTION_NAME=$(terraform output -raw init_db_lambda_function_name)
echo "Lambda function name: $LAMBDA_FUNCTION_NAME"

# Get the AWS region
AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-west-2")
echo "AWS Region: $AWS_REGION"

# Invoke the Lambda function
echo "Invoking Lambda function..."
aws lambda invoke \
  --function-name "$LAMBDA_FUNCTION_NAME" \
  --payload '{"source": "manual.script", "detail-type": "Manual Database Initialization", "detail": {"trigger": "manual_script"}}' \
  --region "$AWS_REGION" \
  response.json

# Check the response
echo "Lambda invocation response:"
cat response.json

# Check if the invocation was successful
if [ $? -eq 0 ]; then
    echo "✅ Lambda function invoked successfully"
    
    # Wait a moment and check logs
    echo "Waiting 5 seconds for logs to appear..."
    sleep 5
    
    LOG_GROUP_NAME="/aws/lambda/$LAMBDA_FUNCTION_NAME"
    echo "Checking logs for: $LOG_GROUP_NAME"
    
    # Get the latest log stream
    LATEST_STREAM=$(aws logs describe-log-streams \
      --log-group-name "$LOG_GROUP_NAME" \
      --order-by LastEventTime \
      --descending \
      --max-items 1 \
      --region "$AWS_REGION" \
      --query 'logStreams[0].logStreamName' \
      --output text)
    
    if [ "$LATEST_STREAM" != "None" ] && [ "$LATEST_STREAM" != "null" ]; then
        echo "Latest log stream: $LATEST_STREAM"
        echo "=== Recent Lambda Logs ==="
        aws logs get-log-events \
          --log-group-name "$LOG_GROUP_NAME" \
          --log-stream-name "$LATEST_STREAM" \
          --region "$AWS_REGION" \
          --query 'events[*].message' \
          --output text | tail -10
    else
        echo "No log streams found for Lambda function"
    fi
else
    echo "❌ Failed to invoke Lambda function"
    exit 1
fi 