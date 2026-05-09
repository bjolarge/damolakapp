variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Application name used for resource naming"
  type        = string
  default     = "damolakapp"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ec2_key_name" {
  description = "Name of the AWS key pair for SSH access"
  type        = string
}

# Aiven DB secrets — passed in via terraform.tfvars or env vars (never hardcoded)
variable "db_host" {
  description = "Aiven PostgreSQL host"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Aiven PostgreSQL port"
  type        = number
  default     = 13838
}

variable "db_username" {
  description = "Aiven PostgreSQL username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Aiven PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Aiven PostgreSQL database name"
  type        = string
  default     = "defaultdb"
}

variable "db_sslg" {
  description = "Base64-encoded Aiven SSL CA certificate"
  type        = string
  sensitive   = true
}