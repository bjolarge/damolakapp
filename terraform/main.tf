terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: store state remotely (recommended)
  # backend "s3" {
  #   bucket = "your-tf-state-bucket"
  #   key    = "damolakapp/terraform.tfstate"
  #   region = var.aws_region
  # }
}

provider "aws" {
  region = var.aws_region
}

module "vpc" {
  source     = "./modules/vpc"
  app_name   = var.app_name
  aws_region = var.aws_region
}

module "ecr" {
  source   = "./modules/ecr"
  app_name = var.app_name
}

module "secrets" {
  source      = "./modules/secrets"
  app_name    = var.app_name
  db_host     = var.db_host
  db_port     = var.db_port
  db_username = var.db_username
  db_password = var.db_password
  db_name     = var.db_name
  db_sslg     = var.db_sslg
}

module "ec2" {
  source           = "./modules/ec2"
  app_name         = var.app_name
  vpc_id           = module.vpc.vpc_id
  public_subnet_id = module.vpc.public_subnet_id
  ec2_key_name     = var.ec2_key_name
  instance_type    = var.instance_type
  ecr_repo_url     = module.ecr.repository_url
  secret_arn       = module.secrets.secret_arn
  aws_region       = var.aws_region
}