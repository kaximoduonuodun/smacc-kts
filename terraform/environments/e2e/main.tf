terraform {
  required_version = ">= 1.8.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.90"
    }
  }

  backend "s3" {
    bucket         = "smacc-kts-terraform-state"
    key            = "smacc-kts/e2e/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    kms_key_id     = "alias/smacc-kts-terraform-state"
    use_lockfile   = true
    profile        = "default"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "default"
}

# 读 bootstrap 建的资源
data "terraform_remote_state" "bootstrap" {
  backend = "s3"
  config = {
    bucket         = "smacc-kts-terraform-state"
    key            = "bootstrap/terraform.tfstate"
    region         = "ap-southeast-1"
    use_lockfile   = true
    kms_key_id     = "alias/smacc-kts-terraform-state"
    profile        = "default"
  }
}

# 调用各 module
module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
}

module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
}

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "cluster" {
  source = "../../modules/cluster"

  project_name     = var.project_name
  environment      = var.environment
  aws_region       = var.aws_region
  vpc_id           = module.vpc.vpc_id
  kms_key_arn      = data.terraform_remote_state.bootstrap.outputs.kms_key_arn
  subnet_ids       = module.vpc.public_subnet_ids
  security_group_id = module.security_groups.k3s_sg_id
  iam_instance_profile = module.iam.k3s_instance_profile_name
  key_name         = var.key_name
  server_instance_type = var.server_instance_type
  agent_instance_type  = var.agent_instance_type
  agent_count      = var.agent_count
}

