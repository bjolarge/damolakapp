resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.app_name}/production/db"
  recovery_window_in_days = 7
  tags                    = { Name = "${var.app_name}-db-secret" }
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    DB_HOST     = var.db_host
    DB_PORT     = tostring(var.db_port)
    DB_USERNAME = var.db_username
    DB_PASSWORD = var.db_password
    DB_NAME     = var.db_name
    DB_SSLG     = var.db_sslg
    NODE_ENV    = "production"
    PORT        = "3000"
  })
}

output "secret_arn" { value = aws_secretsmanager_secret.db.arn }

variable "app_name"    {}
variable "db_host"     { sensitive = true }
variable "db_port"     {}
variable "db_username" { sensitive = true }
variable "db_password" { sensitive = true }
variable "db_name"     {}
variable "db_sslg"     { sensitive = true }