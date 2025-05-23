resource "aws_cloudfront_distribution" "dmarcdefense" {
  origin {
    # Dominio específico del servicio Lightsail (sin protocolo https://)
    domain_name = "dmarcdefense.mp6q91hcmz3jp.us-east-1.cs.amazonlightsail.com"
    origin_id   = "lightsail"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "/"

  aliases = [var.domain_name, "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "lightsail"

    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  web_acl_id = aws_wafv2_web_acl.dmarcdefense.arn

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.dmarcdefense.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.dmarcdefense.domain_name
  description = "Dominio de CloudFront"
}
