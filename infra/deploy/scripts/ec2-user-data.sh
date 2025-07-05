#!/bin/bash
set -e

echo "Starting EC2 instance initialization..."

# Install EC2 Instance Connect agent
echo "Installing EC2 Instance Connect agent..."
yum update -y
yum install -y ec2-instance-connect

# Enable and start the EC2 Instance Connect service
echo "Enabling and starting EC2 Instance Connect service..."
systemctl enable ec2-instance-connect
systemctl start ec2-instance-connect

# Verify the service is running
echo "Verifying EC2 Instance Connect service status..."
systemctl status ec2-instance-connect || echo "Service status check failed, but continuing..."

# Install CloudWatch agent
echo "Installing CloudWatch agent..."
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/bin/config.json <<'CONFIG'
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/messages",
            "log_group_name": "/aws/ec2/console-test",
            "log_stream_name": "{instance_id}",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/secure",
            "log_group_name": "/aws/ec2/console-test",
            "log_stream_name": "{instance_id}-secure",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init.log",
            "log_group_name": "/aws/ec2/console-test",
            "log_stream_name": "{instance_id}-cloud-init",
            "timezone": "UTC"
          },
          {
            "file_path": "/var/log/cloud-init-output.log",
            "log_group_name": "/aws/ec2/console-test",
            "log_stream_name": "{instance_id}-cloud-init-output",
            "timezone": "UTC"
          }
        ]
      }
    }
  }
}
CONFIG

# Start CloudWatch agent
echo "Starting CloudWatch agent..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Set up environment variables
echo "Setting up environment variables..."
cat <<EOT > /etc/profile.d/terraform_env.sh
export PREFIX="${PREFIX}"
export CLOUDFRONT_URL="${CLOUDFRONT_URL}"
export S3_BUCKET_NAME="${S3_BUCKET_NAME}"
export ECR_LAMBDA_MD5_IMAGE="${ECR_LAMBDA_MD5_IMAGE}"
export PROJECT_NAME="${PROJECT_NAME}"
export DB_USERNAME="${DB_USERNAME}"
export DB_NAME="${DB_NAME}"
export DB_PASSWORD="${DB_PASSWORD}"
export DB_HOST="${DB_HOST}"
EOT

echo "EC2 instance initialization completed successfully!" 