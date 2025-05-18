resource "aws_lightsail_container_service" "dmarcdefense" {
  name  = "dmarcdefense"
  power = var.lightsail_power
  scale = var.lightsail_scale

  private_registry_access {
    ecr_repository_name = aws_ecr_repository.dmarcdefense.name
  }

  public_domain_names {
    domain_names = [var.domain_name]
    certificate {
      certificate_name = aws_lightsail_certificate.dmarcdefense.name
    }
  }
}

resource "aws_lightsail_certificate" "dmarcdefense" {
  name                      = "dmarcdefense-cert"
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
}

resource "aws_lightsail_container_service_deployment_version" "dmarcdefense" {
  service_name = aws_lightsail_container_service.dmarcdefense.name

  container {
    container_name = "dmarcdefense"
    image          = "${aws_ecr_repository.dmarcdefense.repository_url}:latest"

    environment {
      API_URL    = var.api_url
      API_TOKEN  = var.api_token
      SECRET_KEY = var.secret_key
    }

    ports {
      port     = 8000
      protocol = "HTTP"
    }
  }

  public_endpoint {
    container_name = "dmarcdefense"
    container_port = 8000
    health_check {
      path          = "/login"
      success_codes = "200-299"
    }

    # Configuración HTTPS
    https_redirection = true
  }
}
