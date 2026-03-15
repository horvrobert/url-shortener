resource "aws_cloudfront_origin_access_control" "url_shortener_oac" {
  name                              = "url-shortener-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "url_shortener_distribution" {
  enabled             = true
  default_root_object = "index.html"
  aliases             = ["www.shrinkr.click"]

  origin {
    domain_name              = aws_s3_bucket.url_shortener_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.url_shortener_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.url_shortener_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.url_shortener_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.shrinkr.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name      = "URL-Shortener-Distribution"
    Project   = "URL-shortener"
    ManagedBy = "Terraform"
  }
}