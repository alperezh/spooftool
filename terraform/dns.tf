# dns.tf

resource "aws_route53_zone" "dmarcdefense" {
  # Si la zona ya existe, debes importarla en lugar de crearla
  count = var.create_zone ? 1 : 0
  name  = "dmarcdefense.net"
}

data "aws_route53_zone" "dmarcdefense" {
  # Siempre usar la zona existente o la recién creada
  zone_id      = var.create_zone ? aws_route53_zone.dmarcdefense[0].zone_id : var.zone_id
  name         = "dmarcdefense.net."
  private_zone = false
}

resource "aws_route53_record" "spoofingtool" {
  zone_id = data.aws_route53_zone.dmarcdefense.zone_id
  name    = "spoofingtool.dmarcdefense.net"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.dmarcdefense.domain_name
    zone_id                = aws_cloudfront_distribution.dmarcdefense.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_spoofingtool" {
  zone_id = data.aws_route53_zone.dmarcdefense.zone_id
  name    = "www.spoofingtool.dmarcdefense.net"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.dmarcdefense.domain_name
    zone_id                = aws_cloudfront_distribution.dmarcdefense.hosted_zone_id
    evaluate_target_health = false
  }
}

# Registro para la validación del certificado (creado por ACM)
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.dmarcdefense.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.dmarcdefense.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}
