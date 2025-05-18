# variables.tf

variable "aws_region" {
  description = "Región AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Entorno de despliegue (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "lightsail_power" {
  description = "Tamaño del contenedor Lightsail (micro, small, medium, large, xlarge)"
  type        = string
  default     = "micro"
}

variable "lightsail_scale" {
  description = "Número de nodos en el servicio de contenedor"
  type        = number
  default     = 1
}

variable "api_url" {
  description = "URL del API de DMARCDefense"
  type        = string
  sensitive   = true
}

variable "api_token" {
  description = "Token para el API de DMARCDefense"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "Clave secreta para Flask"
  type        = string
  sensitive   = true
}

variable "create_zone" {
  description = "Si se debe crear la zona DNS o usar una existente"
  type        = bool
  default     = false
}

variable "zone_id" {
  description = "ID de la zona DNS existente si create_zone es false"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Nombre de dominio para la aplicación DMARCDefense (ej: spoofingtool.dmarcdefense.net)"
  type        = string
}
