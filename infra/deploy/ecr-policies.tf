#######################################
# ECR Repository Policies for Lambdas #
#######################################

data "aws_iam_policy_document" "hash_lambda_ecr_policy" {
  statement {
    sid    = "AllowLambdaPull"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [data.aws_ecr_repository.hash_lambda_repo.arn]
  }
}

resource "aws_ecr_repository_policy" "hash_lambda_policy" {
  repository = data.aws_ecr_repository.hash_lambda_repo.name
  policy     = data.aws_iam_policy_document.hash_lambda_ecr_policy.json
} 