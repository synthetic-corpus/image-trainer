# This file is for Resources that
# are assumed to have been set up already
# Modify locations as needed

data "aws_s3_bucket" "existing" {
  bucket = var.s3_bucket_name
}

# Extract ECR repository name from the image URI and get repository details
data "aws_ecr_repository" "hash_lambda_repo" {
  name = split("/", split(":", var.ecr_lambda_md5_image)[0])[1]
}