# ============================================================
# VARIABLES - INFRAESTRUCTURA MICROSERVICIOS
# ============================================================

variable "AWS_REGION" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  description = "AWS Access Key ID"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  description = "AWS Secret Access Key"
}

variable "AWS_SESSION_TOKEN" {
  type        = string
  description = "AWS Session Token"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID para los recursos"
}

variable "subnet1" {
  type        = string
  description = "ID de la primera subnet (AZ 1)"
}

variable "subnet2" {
  type        = string
  description = "ID de la segunda subnet (AZ 2)"
}

variable "ami_id" {
  type        = string
  description = "AMI ID para las instancias EC2 (Amazon Linux 2023 con Docker)"
  default     = "ami-0c7217cdde317cfec" # Amazon Linux 2023 us-east-1
}

variable "docker_hub_username" {
  type        = string
  description = "Usuario de Docker Hub"
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag de las imágenes Docker"
}

# Database Variables
variable "db_name" {
  type        = string
  default     = "microservices_db"
  description = "Nombre de la base de datos PostgreSQL"
}

variable "db_username" {
  type        = string
  description = "Usuario de la base de datos PostgreSQL"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Contraseña de la base de datos PostgreSQL"
}

# MySQL Database Variables
variable "mysql_username" {
  type        = string
  description = "Usuario de la base de datos MySQL"
}

variable "mysql_password" {
  type        = string
  sensitive   = true
  description = "Contraseña de la base de datos MySQL"
}

variable "mysql_root_password" {
  type        = string
  sensitive   = true
  description = "Contraseña root de MySQL"
}
