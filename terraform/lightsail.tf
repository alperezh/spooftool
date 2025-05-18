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
}

# Despliegue del servicio - Configuración mínima con la imagen oficial de nginx
resource "aws_lightsail_container_service_deployment_version" "dmarcdefense" {
  service_name = aws_lightsail_container_service.dmarcdefense.name

  container {
    container_name = "dmarcdefense"
    # Usar la imagen oficial de nginx, que sabemos funcionará
    image          = "nginx:alpine"
    
    # Configuración mínima sin variables de entorno
    ports = {
      "80" = "HTTP"
    }
  }

  public_endpoint {
    container_name = "dmarcdefense"
    container_port = 80
    health_check {
      # Usar una ruta de health check simple para nginx
      path          = "/"
      success_codes = "200"
    }
  }
}

# Salidas para facilitar la gestión
output "lightsail_service_url" {
  value = aws_lightsail_container_service.dmarcdefense.url
}

output "ecr_repository_url" {
  value = aws_ecr_repository.dmarcdefense.repository_url
}
