variable "resource_group_name" {
  type        = string
  default     = "rg-sonarqube"
  description = "Nombre del grupo de recursos"
}

variable "location" {
  type        = string
  default     = "East US"
  description = "Ubicación de la infraestructura"
}

variable "prefix" {
  type        = string
  default     = "sonarqube"
  description = "Prefijo para nombrar los recursos"
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"  # 2 vCPUs, 4 GB RAM - mínimo recomendado para SonarQube
  description = "Tamaño de la máquina virtual"
}

variable "admin_username" {
  type        = string
  default     = "sonaradmin"
  description = "Usuario administrador de la VM"
}

variable "admin_password" {
  type        = string
  default     = "SonarQube2024!"  # Asegúrate de cambiar esto
  description = "Contraseña del usuario administrador"
}