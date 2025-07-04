resource "aws_security_group" "console_access" {
  name        = "console-ssh-access"
  description = "Allow SSH from AWS Console IP range for NAT subnet resources"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from AWS Console"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["18.237.140.160/29"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "console-ssh-access"
  }
}

resource "aws_instance" "console_test" {
  ami                         = "ami-00687676a54f9a8d5"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private_nat.id
  vpc_security_group_ids      = [aws_security_group.console_access.id]
  associate_public_ip_address = false

  user_data = <<-EOF
    #!/bin/bash
    cat <<EOT > /etc/profile.d/terraform_env.sh
    export PREFIX="${local.prefix}"
    export CLOUDFRONT_URL="${local.cloudfront_url}"
    export S3_BUCKET_NAME="${local.s3_bucket_name}"
    export ECR_LAMBDA_MD5_IMAGE="${local.ecr_lambda_md5_image}"
    export PROJECT_NAME="${local.project_name}"
    export DB_USERNAME="${local.db_username}"
    export DB_NAME="${local.db_name}"
    export DB_PASSWORD="${local.db_password}"
    export DB_HOST="${local.db_host}"
    EOT
  EOF

  tags = {
    Name = "console-test-ec2"
  }
} 