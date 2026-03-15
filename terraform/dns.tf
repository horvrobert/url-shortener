data "aws_route53_zone" "shrinkr" {
  name         = "shrinkr.click"
  private_zone = false
}

# Certificate in eu-central-1 — used by ALB
resource "aws_acm_certificate" "shrinkr" {
  domain_name               = "shrinkr.click"
  subject_alternative_names = ["www.shrinkr.click"]
  validation_method         = "DNS"

  tags = {
    Name      = "shrinkr.click"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate in us-east-1 — required by CloudFront
resource "aws_acm_certificate" "shrinkr_us" {
  provider                  = aws.us_east_1
  domain_name               = "shrinkr.click"
  subject_alternative_names = ["www.shrinkr.click"]
  validation_method         = "DNS"

  tags = {
    Name      = "shrinkr.click-us-east-1"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "shrinkr_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.shrinkr.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.shrinkr.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "shrinkr" {
  certificate_arn         = aws_acm_certificate.shrinkr.arn
  validation_record_fqdns = [for record in aws_route53_record.shrinkr_cert_validation : record.fqdn]
}

resource "aws_acm_certificate_validation" "shrinkr_us" {
  provider        = aws.us_east_1
  certificate_arn = aws_acm_certificate.shrinkr_us.arn
  validation_record_fqdns = [for record in aws_route53_record.shrinkr_cert_validation : record.fqdn]
}

resource "aws_route53_record" "shrinkr_alb" {
  zone_id = data.aws_route53_zone.shrinkr.zone_id
  name    = "shrinkr.click"
  type    = "A"

  alias {
    name                   = aws_lb.url_shortener_alb.dns_name
    zone_id                = aws_lb.url_shortener_alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.shrinkr.zone_id
  name    = "www.shrinkr.click"
  type    = "CNAME"
  ttl     = 300
  records = [aws_cloudfront_distribution.url_shortener_distribution.domain_name]
}

output "domain_name" {
  value       = "https://shrinkr.click"
  description = "API and short links URL"
}

output "frontend_url" {
  value       = "https://www.shrinkr.click"
  description = "Frontend URL"
}