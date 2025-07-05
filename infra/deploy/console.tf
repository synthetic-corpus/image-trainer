resource "aws_security_group" "console_access" {
  name        = "console-ssh-access"
  description = "Allow SSH from AWS Console IP range for NAT subnet resources"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from VPC (for EC2 Instance Connect Endpoint)"
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

  user_data = templatefile("${path.module}/scripts/ec2-user-data.sh", {
    PREFIX               = local.prefix
    CLOUDFRONT_URL       = local.cloudfront_url
    S3_BUCKET_NAME       = local.s3_bucket_name
    ECR_LAMBDA_MD5_IMAGE = local.ecr_lambda_md5_image
    PROJECT_NAME         = local.project_name
    DB_USERNAME          = local.db_username
    DB_NAME              = local.db_name
    DB_PASSWORD          = local.db_password
    DB_HOST              = local.db_host
  })

  tags = {
    Name = "console-test-ec2"
  }
}

resource "aws_ec2_instance_connect_endpoint" "private_nat" {
  subnet_id          = aws_subnet.private_nat.id
  security_group_ids = [aws_security_group.console_access.id]
  tags = {
    Name = "${local.prefix}-ec2-instance-connect-endpoint"
  }
} 