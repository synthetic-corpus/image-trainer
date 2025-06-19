#########################################
# ECR Repositories for Image Trainer    #
#########################################

resource "aws_ecr_repository" "web_app" {
  name                 = "web-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository" "web_proxy" {
  name                 = "web-proxy"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_ecr_repository" "hash_lambda" {
  name                 = "hash-lambda"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
} 