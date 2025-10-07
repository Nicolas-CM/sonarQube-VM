output "public_ip_address" {
  value       = azurerm_public_ip.public_ip.ip_address
  description = "La dirección IP pública de la VM de SonarQube"
}

output "sonarqube_url" {
  value       = "http://${azurerm_public_ip.public_ip.ip_address}:9000"
  description = "URL para acceder a SonarQube"
}