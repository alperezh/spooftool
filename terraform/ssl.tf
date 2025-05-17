# ssl.tf

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

# Asegurarse de que el certificado esté validado antes de crear CloudFront
resource "aws_cloudfront_distribution" "dmarcdefense" {
  # ... configuración previa de CloudFront ...
  
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.dmarcdefense.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  
  # ... resto de la configuración de CloudFront ...
}

# Configuración en Lightsail para usar HTTPS
resource "aws_lightsail_container_service_deployment_version" "dmarcdefense" {
  service_name = aws_lightsail_container_service.dmarcdefense.name
  
  # ... configuración previa de contenedor ...
  
  public_endpoint {
    container_name = "dmarcdefense"
    container_port = 8000
    health_check {
      path = "/login"
    }
    
    # Configuración HTTPS
    https_redirection = true
  }
}
