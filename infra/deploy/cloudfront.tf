#######################################
# CloudFront CDN for S3 Sources Folder #
#######################################

# S3 Origin Access Control (OAC) - modern replacement for OAI
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${local.prefix}-s3-oac"
  description                       = "Origin Access Control for S3 sources folder"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Cache Policy for CloudFront
resource "aws_cloudfront_cache_policy" "sources_cache_policy" {
  name        = "${local.prefix}-sources-cache-policy"
  comment     = "Cache policy for S3 sources folder"
  default_ttl = 3600    # 1 hour
  max_ttl     = 86400   # 24 hours
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
  }
}

# Origin Request Policy for CloudFront
resource "aws_cloudfront_origin_request_policy" "sources_request_policy" {
  name    = "${local.prefix}-sources-request-policy"
  comment = "Origin request policy for S3 sources folder"

  cookies_config {
    cookie_behavior = "none"
  }

  headers_config {
    header_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "none"
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "sources_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Mexico only (cheapest)

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "MX"]
    }
  }

  origin {
    domain_name              = data.aws_s3_bucket.existing.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
    origin_id                = "s3-sources"
    origin_path              = "/sources"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-sources"

    cache_policy_id          = aws_cloudfront_cache_policy.sources_cache_policy.id
    origin_request_policy_id = aws_cloudfront_origin_request_policy.sources_request_policy.id

    viewer_protocol_policy = "redirect-to-https"
    compress               = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = "200"
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = "200"
    response_page_path = "/index.html"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  # Tags
  tags = {
    Name    = "${local.prefix}-sources-cdn"
    Project = var.project_name
    Contact = var.contact
  }
}

# S3 Bucket Policy to allow CloudFront access via OAC
data "aws_iam_policy_document" "s3_cloudfront_access" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    resources = [
      "${data.aws_s3_bucket.existing.arn}/sources/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.sources_cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = data.aws_s3_bucket.existing.id
  policy = data.aws_iam_policy_document.s3_cloudfront_access.json
}

#######################################
# Outputs for CloudFront CDN URL #
#######################################

output "cloudfront_url" {
  description = "Public URL of the CloudFront distribution"
  value       = "https://${aws_cloudfront_distribution.sources_cdn.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.sources_cdn.id
} 