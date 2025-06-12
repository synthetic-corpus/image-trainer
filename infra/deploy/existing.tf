# This file is for Resources that
# are assumed to have been set up already
# Modify locations as needed

data "aws_s3_bucket" "existing" {
  bucket = var.s3_bucket_name
}