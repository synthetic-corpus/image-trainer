####################################
# Roles and Polices for Numpy Lambda #
####################################
resource "aws_iam_role" "numpy_lambda_role" {
  name = "${var.prefix}-numpy-lambda-role-${var.environment}"

  assume_role_policy = data.aws_iam_policy_document.numpy_lambda_assume_role.json

  tags = {
    Name = "${var.prefix}-numpy-lambda-role-${var.environment}"
  }
}

data "aws_iam_policy_document" "numpy_lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "numpy_lambda_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      data.aws_s3_bucket.existing.arn,
      "${data.aws_s3_bucket.existing.arn}/sources/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${data.aws_s3_bucket.existing.arn}/numpys/*"
    ]
  }
}

resource "aws_iam_policy" "numpy_lambda_s3_policy" {
  name        = "${var.prefix}-numpy-lambda-s3-policy-${var.environment}"
  description = "Policy for Numpy Lambda to read from sources and write to monochrome folder"
  policy      = data.aws_iam_policy_document.numpy_lambda_s3_policy.json

  tags = {
    Name = "${var.prefix}-numpy-lambda-s3-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "numpy_lambda_logs_policy" {
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

resource "aws_iam_policy" "numpy_lambda_logs_policy" {
  name        = "${var.prefix}-numpy-lambda-logs-policy-${var.environment}"
  description = "Policy for Numpy Lambda to write to CloudWatch Logs"
  policy      = data.aws_iam_policy_document.numpy_lambda_logs_policy.json

  tags = {
    Name = "${var.prefix}-numpy-lambda-logs-policy-${var.environment}"
  }
}

data "aws_iam_policy_document" "numpy_lambda_ecr_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:DescribeRepositories",
      "ecr:DescribeImages"
    ]
    resources = [data.aws_ecr_repository.numpy_lambda_repo.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "numpy_lambda_ecr_policy" {
  name        = "${var.prefix}-numpy-lambda-ecr-policy-${var.environment}"
  description = "Policy for Numpy Lambda to pull images from ECR"
  policy      = data.aws_iam_policy_document.numpy_lambda_ecr_policy.json

  tags = {
    Name = "${var.prefix}-numpy-lambda-ecr-policy-${var.environment}"
  }
}

#######################################
# Policy attachements for this Lambda #
#######################################
resource "aws_iam_role_policy_attachment" "numpy_lambda_s3_attachment" {
  role       = aws_iam_role.numpy_lambda_role.name
  policy_arn = aws_iam_policy.numpy_lambda_s3_policy.arn
}

resource "aws_iam_role_policy_attachment" "numpy_lambda_logs_attachment" {
  role       = aws_iam_role.numpy_lambda_role.name
  policy_arn = aws_iam_policy.numpy_lambda_logs_policy.arn
}

resource "aws_iam_role_policy_attachment" "numpy_lambda_ecr_attachment" {
  role       = aws_iam_role.numpy_lambda_role.name
  policy_arn = aws_iam_policy.numpy_lambda_ecr_policy.arn
}

resource "aws_cloudwatch_log_group" "numpy_lambda_logs" {
  name              = "/aws/lambda/${local.project_name}/numpy-convert"
  retention_in_days = var.lambda_log_retention_days

  tags = {
    Name = "${var.prefix}-numpy-lambda-logs-${var.environment}"
  }
}

##############################
# The Lambda Function Itself #
##############################
resource "aws_lambda_function" "numpy_convert" {
  function_name = "${var.prefix}-numpy-lambda-${var.environment}"
  role          = aws_iam_role.numpy_lambda_role.arn
  package_type  = "Image"
  image_uri     = var.ecr_numpy_lambda_image

  timeout     = var.lambda_timeout
  memory_size = var.lambda_memory_size

  environment {
    variables = {
      S3_BUCKET_NAME = var.s3_bucket_name
      ENVIRONMENT    = var.environment
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.numpy_lambda_logs,
    aws_iam_role_policy_attachment.numpy_lambda_s3_attachment,
    aws_iam_role_policy_attachment.numpy_lambda_logs_attachment,
    aws_iam_role_policy_attachment.numpy_lambda_ecr_attachment
  ]

  tags = {
    Name = "${var.prefix}-numpy-lambda-${var.environment}"
  }
}

#######################################
# Lambda Permission for S3 Invocation #
#######################################
resource "aws_lambda_permission" "numpy_s3_permission" {
  statement_id  = "AllowS3InvokeNumpy"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.numpy_convert.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.existing.arn
} 