# outputs.tf

output "lightsail_url" {
  description = "URL del servicio Lightsail"
  value       = aws_lightsail_container_service.dmarcdefense.url
}

output "cloudfront_url" {
  description = "URL de la distribución CloudFront"
  value       = aws_cloudfront_distribution.dmarcdefense.domain_name
}

output "website_url" {
  description = "URL principal del sitio web"
  value       = "https://spoofingtool.dmarcdefense.net"
}

output "backup_bucket" {
  description = "Nombre del bucket S3 para backups"
  value       = aws_s3_bucket.backups.id
}

output "backup_commands" {
  description = "Comandos para ejecutar backup/restore manual"
  value = {
    backup       = "aws s3 cp s3://${aws_s3_bucket.backups.id}/scripts/backup.sh . && chmod +x backup.sh && ./backup.sh"
    restore      = "aws s3 cp s3://${aws_s3_bucket.backups.id}/scripts/restore.sh . && chmod +x restore.sh && ./restore.sh [nombre_backup]"
    list_backups = "aws s3 ls s3://${aws_s3_bucket.backups.id}/daily/ && aws s3 ls s3://${aws_s3_bucket.backups.id}/weekly/ && aws s3 ls s3://${aws_s3_bucket.backups.id}/monthly/"
  }
}
