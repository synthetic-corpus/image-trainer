terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.23.0"
    }
  }

  backend "s3" {
    bucket               = "jtg-terraform-buckets"
    key                  = "image-trainer-one-deploy"
    workspace_key_prefix = "image-trainer-one-deploy-env"
    region               = "us-west-2"
    encrypt              = true
    dynamodb_table       = "terraform-lock-table"
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Environment = terraform.workspace
      Project     = var.project
      contact     = var.contact
      ManageBy    = "Terraform/deploy"
    }
  }
}

locals {
  prefix               = "${var.prefix}-${terraform.workspace}"
  cloudfront_url       = "https://${aws_cloudfront_distribution.sources_cdn.domain_name}"
  s3_bucket_name       = var.s3_bucket_name
  ecr_lambda_md5_image = var.ecr_lambda_md5_image
  project_name         = var.project
}

data "aws_region" "current" {}