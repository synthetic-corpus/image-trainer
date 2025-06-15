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
  default     = "imagage-trainer-one"
}

variable "contact" {
  description = "who to contact about these resources"
  default     = "joel@joelgonzaga.com"
}

data "aws_s3_bucket" "existing" {
  bucket = "ai-test-bucket-jtg"
}