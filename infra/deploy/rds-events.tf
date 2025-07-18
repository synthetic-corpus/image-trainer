####################################
# EventBridge for RDS Database Events #
####################################

# EventBridge bus (uses default bus)
data "aws_cloudwatch_event_bus" "default" {
  name = "default"
}

# EventBridge rule to capture RDS database availability events
resource "aws_cloudwatch_event_rule" "rds_db_available" {
  name        = "${var.prefix}-rds-db-available-${var.environment}"
  description = "Capture RDS database availability events"

  event_pattern = jsonencode({
    source      = ["aws.rds"]
    detail-type = ["RDS DB Instance Event"]
    detail = {
      EventCategories = ["availability"]
      SourceType      = ["DB_INSTANCE"]
      SourceArn       = ["arn:aws:rds:${var.aws_region}:*:db:${local.prefix}-db"]
      Message         = ["DB instance is available"]
    }
  })

  tags = {
    Name = "${var.prefix}-rds-db-available-rule-${var.environment}"
  }
}

# EventBridge target to invoke the init-db Lambda (for availability events)
resource "aws_cloudwatch_event_target" "init_db_lambda" {
  rule      = aws_cloudwatch_event_rule.rds_db_available.name
  target_id = "InitDBLambda"
  arn       = aws_lambda_function.init_db.arn

  # Pass the event detail to the Lambda
  input_transformer {
    input_paths = {
      "detail" = "$.detail"
    }
    input_template = jsonencode({
      "source"      = "aws.rds"
      "detail-type" = "RDS DB Instance Event"
      "detail"      = "$${detail}"
    })
  }

  depends_on = [
    aws_lambda_function.init_db
  ]
}

# Lambda permission to allow EventBridge to invoke the function
resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.init_db.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_db_available.arn
} 