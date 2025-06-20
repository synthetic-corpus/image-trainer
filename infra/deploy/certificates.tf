#######################################
# SSL/TLS Certificate Configuration  #
#######################################

# Reference existing ACM certificate (created outside Terraform)
# This avoids recreating the certificate on every deployment

# A record for the subdomain pointing to the ALB
resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Output the certificate ARN for use in ALB
output "certificate_arn" {
  description = "The ARN of the existing ACM certificate"
  value       = data.aws_acm_certificate.existing.arn
}

# Output the nameservers for domain configuration
output "nameservers" {
  description = "Nameservers for the hosted zone"
  value       = data.aws_route53_zone.main.name_servers
} 