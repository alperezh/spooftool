# Definir el repositorio ECR
resource "aws_ecr_repository" "dmarcdefense" {
  name                 = "dmarcdefense"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Certificado Lightsail
resource "aws_lightsail_certificate" "dmarcdefense" {
  name                      = "dmarcdefense-cert"
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
}

# Servicio de contenedor Lightsail
resource "aws_lightsail_container_service" "dmarcdefense" {
  name  = "dmarcdefense"
  power = var.lightsail_power
  scale = var.lightsail_scale

  # Importante: Omitir los bloques private_registry_access y public_domain_names 
  # que están causando errores. Estos se configurarán después del aprovisionamiento
  # inicial del recurso o a través de la consola AWS.
}

# Despliegue del servicio de contenedor
resource "aws_lightsail_container_service_deployment_version" "dmarcdefense" {
  service_name = aws_lightsail_container_service.dmarcdefense.name

  container {
    container_name = "dmarcdefense"
    # Usar una imagen estándar inicialmente, luego actualizar a la de ECR
    image          = "amazon/amazon-linux-2" 

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

# Salidas relevantes
output "lightsail_service_url" {
  value = aws_lightsail_container_service.dmarcdefense.url
}

output "ecr_repository_url" {
  value = aws_ecr_repository.dmarcdefense.repository_url
}
