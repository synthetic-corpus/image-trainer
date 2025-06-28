#######################################
# S3 Event Triggers for Lambda Functions #
#######################################

# Combined S3 bucket notification for all Lambda functions
# Note: S3 buckets can only have one notification configuration
resource "aws_s3_bucket_notification" "lambda_notification" {
  bucket = data.aws_s3_bucket.existing.id

  # Hash Lambda trigger - processes files uploaded to upload/ folder
  lambda_function {
    lambda_function_arn = aws_lambda_function.processor.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "upload/"
  }

  # Numpy Lambda trigger - processes files uploaded to sources/ folder
  lambda_function {
    lambda_function_arn = aws_lambda_function.numpy_convert.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "sources/"
  }

  # Future Lambda trigger - will also process files uploaded to sources/ folder
  # Uncomment and configure when ready to implement
  # lambda_function {
  #   lambda_function_arn = aws_lambda_function.future_lambda.arn
  #   events              = ["s3:ObjectCreated:*"]
  #   filter_prefix       = "sources/"
  # }

  # Dependencies on Lambda permissions to ensure they exist before creating notifications
  depends_on = [
    aws_lambda_permission.s3_permission,
    aws_lambda_permission.numpy_s3_permission
    # aws_lambda_permission.future_lambda_permission  # Uncomment when ready
  ]
} 