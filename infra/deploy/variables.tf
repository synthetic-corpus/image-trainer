variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Prefix for resoruces in AWS"
  default     = "ml-simple"
}

variable "project_name" {
  description = "Name of the project for resource naming"
  type        = string
  default     = "image-trainer-one"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# VPC-related variables for customization
variable "vpc_name_tag" {
  description = "Name tag of the existing VPC to reference"
  type        = string
  default     = "main-vpc"
}

variable "public_subnet_tag" {
  description = "Tag key-value pair to identify public subnets"
  type        = map(string)
  default = {
    Type = "public"
  }
}

variable "private_subnet_tag" {
  description = "Tag key-value pair to identify private subnets"
  type        = map(string)
  default = {
    Type = "private"
  }
}

# S3 bucket variable. This should be set via environment variable or terraform.tfvars
variable "s3_bucket_name" {
  description = "Name of the existing S3 bucket to reference"
  type        = string
  default     = "image-trainer-sources" # Default for local development
}

# Lambda configuration variables
variable "lambda_log_retention_days" {
  description = "Number of days to retain Lambda logs in CloudWatch"
  type        = number
  default     = 14
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "lambda_image_tag" {
  description = "Docker image tag for Lambda function"
  type        = string
  default     = "latest"
}

# Variables related to Terraform Deployments

variable "tf_state_bucket" {
  description = "Name of an s3 bucket that stores the Terraform state"
  default     = "jtg-terraform-buckets"
}

variable "tf_state_lock_table" {
  description = "The DynamoDB table handles Terraform locks"
  default     = "terraform-lock-table"
}

variable "project" {
  description = "This be the name of the project, yarg"
  default     = "image-trainer-one"
}

variable "contact" {
  description = "who to contact about these resources"
  default     = "joel@joelgonzaga.com"
}

variable "db_username" {
  description = "Username for database access"
  default     = "imagetraineruser"
}

variable "db_name" {
  description = "Name of the database"
  default     = "imagetrainerdb"
}

variable "db_password" {
  description = "Password for the terraform database."
  default     = "placeholder-password"
}

variable "ecr_proxy_image" {
  description = "Path to the ECR repo with the proxy image"
  default     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/web-proxy:latest"
}

variable "ecr_app_image" {
  description = "Path to the ECR repo with the image image"
  default     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/web-app:latest"
}

variable "ecr_lambda_md5_image" {
  description = "Path to the ECR Repo for a lambda."
  type        = string
  default     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/hash-lambda:latest" # Default for local development
}

variable "ecr_numpy_lambda_image" {
  description = "Path to the ECR Repo for the numpy-convert lambda."
  type        = string
  default     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/numpy-convert:latest" # Default for local development
}

variable "ecr_init_db_image" {
  description = "Path to the ECR Repo for the database initialization lambda."
  type        = string
  default     = "123456789012.dkr.ecr.us-west-2.amazonaws.com/init-db:latest" # Default for local development
}

variable "domain_name" {
  description = "Domain name for the application (e.g., image-trainer.magicalapis.net)"
  type        = string
  default     = "image-trainer.magicalapis.net"
}

variable "use_snapshot" {
  description = "Whether to restore RDS from snapshot (true) or create fresh (false)"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Snapshot identifier to restore from (only used if use_snapshot is true)"
  type        = string
  default     = ""
}