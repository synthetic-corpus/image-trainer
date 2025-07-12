####################################
# Roles and Polices for Init DB Lambda #
####################################
resource "aws_iam_role" "init_db_lambda_role" {
  name = "${var.prefix}-init-db-lambda-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.init_db_lambda_assume_role.json

  tags = {
    Name = "${var.prefix}-init-db-lambda-role-${var.environment}"
  }
}

data "aws_iam_policy_document" "init_db_lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "init_db_lambda_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda/${local.project_name}/*",
    "arn:aws:logs:${var.aws_region}:*:log-group:/aws/lambda*"]
  }
}

resource "aws_iam_policy" "init_db_lambda_logs_policy" {
  name        = "${var.prefix}-init-db-lambda-logs-policy-${var.environment}"
  description = "Policy for Init DB Lambda to write to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.init_db_lambda_logs_policy.json

  tags = {
    Name = "${var.prefix}-init-db-lambda-logs-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "init_db_lambda_ecr_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages"
    ]
    resources = [data.aws_ecr_repository.init_db_repo.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "init_db_lambda_ecr_policy" {
  name        = "${var.prefix}-init-db-lambda-ecr-policy-${var.environment}"
  description = "Policy for Init DB Lambda to pull images from ECR"
  policy      = data.aws_iam_policy_document.init_db_lambda_ecr_policy.json

  tags = {
    Name = "${var.prefix}-init-db-lambda-ecr-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "init_db_lambda_vpc_policy" {
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

resource "aws_iam_policy" "init_db_lambda_vpc_policy" {
  name        = "${var.prefix}-init-db-lambda-vpc-policy-${var.environment}"
  description = "Policy for Init DB Lambda to manage network interfaces in VPC"
  policy      = data.aws_iam_policy_document.init_db_lambda_vpc_policy.json

  tags = {
    Name = "${var.prefix}-init-db-lambda-vpc-policy-${var.environment}"
  }
}

#######################################
# Policy attachements for this Lambda #
#######################################
resource "aws_iam_role_policy_attachment" "init_db_lambda_logs_attachment" {
  role       = aws_iam_role.init_db_lambda_role.name
  policy_arn = aws_iam_policy.init_db_lambda_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "init_db_lambda_ecr_attachment" {
  role       = aws_iam_role.init_db_lambda_role.name
  policy_arn = aws_iam_policy.init_db_lambda_ecr_policy.arn
}

resource "aws_iam_role_policy_attachment" "init_db_lambda_vpc_attachment" {
  role       = aws_iam_role.init_db_lambda_role.name
  policy_arn = aws_iam_policy.init_db_lambda_vpc_policy.arn
}

resource "aws_cloudwatch_log_group" "init_db_lambda_logs" {
  name              = "/aws/lambda/${local.project_name}/init-db"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.prefix}-init-db-lambda-logs-${var.environment}"
  }
}

##############################
# The Lambda Function Itself #
##############################
resource "aws_lambda_function" "init_db" {
  function_name = "${var.prefix}-init-db-lambda-${var.environment}"
  role          = aws_iam_role.init_db_lambda_role.arn
  package_type  = "Image"
  image_uri     = var.ecr_init_db_image

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_group_ids = [aws_security_group.init_db_lambda_sg.id]
  }

  environment {
    variables = {
      ENVIRONMENT = var.environment
      DB_HOST     = aws_db_instance.main.endpoint
      DB_NAME     = local.db_name
      DB_USER     = local.db_username
      DB_PASSWORD = local.db_password
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.init_db_lambda_logs,
    aws_iam_role_policy_attachment.init_db_lambda_logs_attachment,
    aws_iam_role_policy_attachment.init_db_lambda_ecr_attachment,
    aws_iam_role_policy_attachment.init_db_lambda_vpc_attachment,
    aws_cloudwatch_event_rule.rds_db_created
  ]

  tags = {
    Name = "${var.prefix}-init-db-lambda-${var.environment}"
  }
}

# Output for the Lambda function name
output "init_db_lambda_function_name" {
  description = "The name of the database initialization Lambda function"
  value       = aws_lambda_function.init_db.function_name
}

# Security group for Init DB Lambda to access RDS
resource "aws_security_group" "init_db_lambda_sg" {
  name        = "${var.prefix}-init-db-lambda-sg-${var.environment}"
  description = "Security group for Init DB Lambda to access RDS"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound traffic (needed for Lambda to reach RDS and other services)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.prefix}-init-db-lambda-sg-${var.environment}"
  }
} 