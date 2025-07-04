####################################
# Roles and Polices for MD5 Lambda #
####################################
resource "aws_iam_role" "lambda_role" {
  name = "${var.prefix}-lambda-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name = "${var.prefix}-lambda-role-${var.environment}"
  }
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "lambda_s3_policy" {
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
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name        = "${var.prefix}-lambda-s3-policy-${var.environment}"
  description = "Policy for Lambda to access S3 upload and sources folders"
  policy      = data.aws_iam_policy_document.lambda_s3_policy.json

  tags = {
    Name = "${var.prefix}-lambda-s3-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "lambda_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.project_name}/*"]
  }
}

resource "aws_iam_policy" "lambda_logs_policy" {
  name        = "${var.prefix}-lambda-logs-policy-${var.environment}"
  description = "Policy for Lambda to write to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.lambda_logs_policy.json

  tags = {
    Name = "${var.prefix}-lambda-logs-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "lambda_ecr_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages"
    ]
    resources = [data.aws_ecr_repository.hash_lambda_repo.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_ecr_policy" {
  name        = "${var.prefix}-lambda-ecr-policy-${var.environment}"
  description = "Policy for Lambda to pull images from ECR"
  policy      = data.aws_iam_policy_document.lambda_ecr_policy.json

  tags = {
    Name = "${var.prefix}-lambda-ecr-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "lambda_vpc_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_vpc_policy" {
  name        = "${var.prefix}-lambda-vpc-policy-${var.environment}"
  description = "Policy for Lambda to manage network interfaces in VPC"
  policy      = data.aws_iam_policy_document.lambda_vpc_policy.json

  tags = {
    Name = "${var.prefix}-lambda-vpc-policy-${var.environment}"
  }
}

#######################################
# Policy attachements for this Lambda #
#######################################
resource "aws_iam_role_policy_attachment" "lambda_s3_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_logs_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_ecr_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_ecr_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${local.project_name}/processor"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.prefix}-lambda-logs-${var.environment}"
  }
}

##############################
# The Lambda Function Itself #
##############################
resource "aws_lambda_function" "processor" {
  function_name = "${var.prefix}-hash-lambda-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = var.ecr_lambda_md5_image

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.hash_lambda_sg.id]
  }

  environment {
    variables = {
      S3_BUCKET_NAME = local.s3_bucket_name
      ENVIRONMENT    = var.environment
      DB_HOST        = aws_db_instance.main.endpoint
      DB_PORT        = "5432"
      DB_NAME        = local.db_name
      DB_USER        = local.db_username
      DB_PASSWORD    = local.db_password
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
    aws_iam_role_policy_attachment.lambda_s3_attachment,
    aws_iam_role_policy_attachment.lambda_logs_attachment,
    aws_iam_role_policy_attachment.lambda_ecr_attachment,
    aws_iam_role_policy_attachment.lambda_vpc_attachment,
    aws_ecr_repository_policy.hash_lambda_policy,
    aws_db_instance.main
  ]

  tags = {
    Name = "${var.prefix}-lambda-${var.environment}"
  }
}

#######################################
# Lambda Permission for S3 Invocation #
#######################################
resource "aws_lambda_permission" "s3_permission" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.existing.arn
}

# Security group for Lambda to access RDS
resource "aws_security_group" "hash_lambda_sg" {
  name        = "${var.prefix}-hash-lambda-sg-${var.environment}"
  description = "Security group for hash Lambda to access RDS"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (needed for Lambda to reach RDS and other services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-hash-lambda-sg-${var.environment}"
  }
}
