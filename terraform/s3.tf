resource "aws_s3_bucket" "url_shortener_bucket" {
  bucket = "url-shortener-frontend-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name      = "URL-Shortener-Frontend"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "url_shortener_bucket" {
  bucket = aws_s3_bucket.url_shortener_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "url_shortener_bucket" {
  bucket = aws_s3_bucket.url_shortener_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.url_shortener_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.url_shortener_distribution.arn
          }
        }
      }
    ]
  })
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.url_shortener_bucket.bucket
  description = "S3 bucket name — use this to upload index.html"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.url_shortener_distribution.domain_name
  description = "CloudFront domain name — use this as the frontend URL"
}