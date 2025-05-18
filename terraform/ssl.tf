resource "aws_acm_certificate" "dmarcdefense" {
  domain_name       = "spoofingtool.dmarcdefense.net"
  validation_method = "DNS"

  subject_alternative_names = ["www.spoofingtool.dmarcdefense.net"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "DMARCDefense Spoofingtool Certificate"
    Environment = var.environment
  }
}

# Validación de certificado usando Route 53
resource "aws_acm_certificate_validation" "dmarcdefense" {
  certificate_arn         = aws_acm_certificate.dmarcdefense.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
