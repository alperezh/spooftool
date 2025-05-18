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

# Servicio de contenedor Lightsail - Configuración básica
resource "aws_lightsail_container_service" "dmarcdefense" {
  name  = "dmarcdefense"
  power = var.lightsail_power
  scale = var.lightsail_scale
}

# Despliegue del servicio de contenedor - Configuración simplificada
resource "aws_lightsail_container_service_deployment_version" "dmarcdefense" {
  service_name = aws_lightsail_container_service.dmarcdefense.name

  container {
    container_name = "dmarcdefense"
    # Usar una imagen estándar inicialmente
    image          = "amazon/amazon-linux-2" 
    
    # Environment como mapa, no como bloque
    environment = {
      API_URL    = var.api_url
      API_TOKEN  = var.api_token
      SECRET_KEY = var.secret_key
    }
    
    # Ports como mapa, no como bloque
    ports = {
      "8000" = "HTTP"
    }
  }

  public_endpoint {
    container_name = "dmarcdefense"
    container_port = 8000
    health_check {
      path          = "/login"
      success_codes = "200-299"
    }
    # Eliminado https_redirection que estaba causando problemas
  }
}

# Salidas relevantes
output "lightsail_service_url" {
  value = aws_lightsail_container_service.dmarcdefense.url
}

output "ecr_repository_url" {
  value = aws_ecr_repository.dmarcdefense.repository_url
}
