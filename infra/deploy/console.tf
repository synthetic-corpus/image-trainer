resource "aws_security_group" "console_access" {
  name        = "console-ssh-access"
  description = "Allow SSH from AWS Console IP range for NAT subnet resources"
  vpc_id      = aws_vpc.main.id

  # Allow SSH from AWS EC2 Instance Connect service
  ingress {
    description = "SSH from AWS EC2 Instance Connect service"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow SSH from VPC for internal access
  ingress {
    description = "SSH from VPC for internal access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  # Explicitly allow outbound access to EC2 Instance Metadata Service (IMDS)
  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["169.254.169.254/32"]
    description = "Allow outbound HTTP to IMDS"
  }

  tags = {
    Name = "console-ssh-access"
  }
}

resource "aws_iam_role" "console_s3_role" {
  name = "console-ec2-s3-role"

  assume_role_policy = data.aws_iam_policy_document.console_s3_assume_role_policy.json
}

# Assume role policy document
data "aws_iam_policy_document" "console_s3_assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# S3 access policy document
data "aws_iam_policy_document" "console_s3_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      data.aws_s3_bucket.existing.arn,
      "${data.aws_s3_bucket.existing.arn}/upload/*",
      "${data.aws_s3_bucket.existing.arn}/sources/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:*:log-group:/aws/ec2/console-test:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "logs:PutRetentionPolicy"
    ]
    resources = ["*"]
  }

  # EC2 Instance Connect permissions
  statement {
    effect = "Allow"
    actions = [
      "ec2-instance-connect:SendSSHPublicKey",
      "ec2-instance-connect:SendSerialConsoleSSHPublicKey"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "console_s3_policy" {
  name   = "console-ec2-s3-policy"
  policy = data.aws_iam_policy_document.console_s3_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "console_s3_attach" {
  role       = aws_iam_role.console_s3_role.name
  policy_arn = aws_iam_policy.console_s3_policy.arn
}

resource "aws_iam_instance_profile" "console_s3_profile" {
  name = "console-ec2-s3-profile"
  role = aws_iam_role.console_s3_role.name
}

# CloudWatch Log Group for EC2 Console Instance
resource "aws_cloudwatch_log_group" "ec2_console" {
  name              = "/aws/ec2/console-test"
  retention_in_days = 7

  tags = {
    Name = "${local.prefix}-ec2-console-logs"
  }
}

resource "aws_instance" "console_test" {
  ami                         = local.ami_image_id
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private_nat.id
  vpc_security_group_ids      = [aws_security_group.console_access.id]
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.console_s3_profile.name

  user_data = <<-EOF
#!/bin/bash

# Install Python 3 and Pip 3
echo "Installing Python 3 and Pip 3..." > /tmp/python_pip_install.log
yum install -y python3-pip >> /tmp/python_pip_install.log 2>&1
echo "Python 3 and Pip 3 installation complete." >> /tmp/python_pip_install.log

# Install PostgreSQL client
echo "Installing PostgreSQL client..." >> /tmp/postgresql_install.log
yum install -y postgresql-devel >> /tmp/postgresql_install.log 2>&1
echo "PostgreSQL client installation complete." >> /tmp/postgresql_install.log

echo "DB_PASSWORD=${local.db_password}" > /tmp/config.txt
echo "DB_HOST=${local.db_host}" >> /tmp/config.txt
echo "S3_BUCKET_NAME=${local.s3_bucket_name}" >> /tmp/config.txt
echo "DB_USERNAME=${local.db_username}" >> /tmp/config.txt

# Export variables from /tmp/config.txt as environment variables
echo "Setting up environment variables for SSH users..." >> /tmp/env_setup.log
( while IFS= read -r line; do echo "export $line"; done < /tmp/config.txt ) | sudo tee /etc/profile.d/my_app_env.sh >> /tmp/env_setup.log 2>&1
echo "Environment variables setup complete." >> /tmp/env_setup.log
EOF

  tags = {
    Name = "console-test-ec2"
  }

  lifecycle {
    replace_triggered_by = [null_resource.force_recreate_console_instance.id]
  }
}

# This null_resource exists solely to force the replacement of the EC2 instance
# every time terraform apply is run.
resource "null_resource" "force_recreate_console_instance" {
  triggers = {
    always_recreate = timestamp()
  }
}

resource "aws_ec2_instance_connect_endpoint" "public_endpoint" {
  subnet_id          = aws_subnet.public_a.id # EC2 Instance Connect endpoints must be in public subnets
  security_group_ids = [aws_security_group.console_access.id]
  tags = {
    Name = "${local.prefix}-ec2-instance-connect-endpoint"
  }
} 