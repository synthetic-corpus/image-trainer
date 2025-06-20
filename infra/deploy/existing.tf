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

# Extract ECR repository names from the image URIs and get repository details
data "aws_ecr_repository" "proxy_repo" {
  name = split("/", split(":", var.ecr_proxy_image)[0])[1]
}

data "aws_ecr_repository" "app_repo" {
  name = split("/", split(":", var.ecr_app_image)[0])[1]
}

# Reference existing ACM certificate
# You can use any of these options:
# 1. Wildcard certificate: "*.magicalapis.net"
# 2. Root domain certificate: "magicalapis.net" 
# 3. Specific subdomain: "image-trainer.magicalapis.net"
data "aws_acm_certificate" "existing" {
  domain      = var.domain_name # This will be "image-trainer.magicalapis.net"
  statuses    = ["ISSUED", "PENDING_VALIDATION"]
  most_recent = true

  # Alternative: If you have a wildcard certificate, you could use:
  # domain = "*.magicalapis.net"
  # 
  # Or if you have a root domain certificate:
  # domain = "magicalapis.net"
}

# Data source for existing Route53 hosted zone
data "aws_route53_zone" "main" {
  name = "magicalapis.net"
}