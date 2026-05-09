output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.ec2.public_ip
}

output "ecr_repository_url" {
  description = "ECR repository URL for Docker image pushes"
  value       = module.ecr.repository_url
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = module.secrets.secret_arn
}