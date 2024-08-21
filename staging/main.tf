###
# Providers
##
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.50.0"
    }
  }

  backend "s3" {
    bucket  = "alphabet-terraform"
    key     = "alphabet/staging.tfstate"
    region  = "ap-southeast-1"
  }
}

provider "aws" {
  region  = "ap-southeast-1"
}


###
# Variables
##
variable "infra_env" {
  type        = string
  description = "infrastructure environment"
  default     = "staging"
}

variable "default_region" {
  type        = string
  description = "the region this infrastructure is in"
  default     = "ap-southeast-1"
}

variable "git_url" {
  type        = string
  description = "Git Clone URL (.git)"
}

locals {
  cidr_subnets = cidrsubnets("10.0.0.0/17", 4, 4, 4, 4, 4, 4)
}

###
# Data
##
data "aws_ami" "app" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Component"
    values = ["app"]
  }

  filter {
    name   = "tag:Project"
    values = ["alphabet"]
  }

  filter {
    name   = "tag:Environment"
    values = [var.infra_env]
  }

  owners = ["self"]
}

data "aws_s3_bucket" "artifact_bucket" {
  bucket = "alphabet-artifacts-dummy"
}

###
# Resources
##
module "vpc" {
  source = "../modules/vpc"

  infra_env       = var.infra_env
  vpc_cidr        = "10.0.0.0/17"
  azs             = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  public_subnets  = slice(local.cidr_subnets, 0, 3)
  private_subnets = slice(local.cidr_subnets, 3, 6)
}

module "autoscale_core" {
  source = "../modules/ec2"

  ami             = data.aws_ami.app.id
  git_url         = var.git_url
  infra_env       = var.infra_env
  infra_role      = "core"
  instance_type   = "t4g.small"
  security_groups = [module.vpc.internal_sg, module.vpc.web_sg]
  ssh_key_name    = "alphabet-forge"

  asg_subnets = module.vpc.vpc_private_subnets
  alb_subnets = module.vpc.vpc_public_subnets
  vpc_id      = module.vpc.vpc_id

  min_size    = 0
  max_size    = 2
  desired_capacity = 1

  artifact_bucket = data.aws_s3_bucket.artifact_bucket.arn
}

module "autoscale_admin" {
  source = "../modules/ec2"

  ami             = data.aws_ami.app.id
  git_url         = var.git_url
  infra_env       = var.infra_env
  infra_role      = "admin"
  instance_type   = "t4g.micro"
  security_groups = [module.vpc.internal_sg]
  ssh_key_name    = "alphabet-forge"

  asg_subnets = module.vpc.vpc_private_subnets
  vpc_id      = module.vpc.vpc_id

  min_size    = 0
  max_size    = 2
  desired_capacity = 1

  artifact_bucket = data.aws_s3_bucket.artifact_bucket.arn
}

module "deploy_app" {
  source = "../modules/codedeploy"

  infra_env    = var.infra_env
  deploy_groups = {
    core: {
      traffic: "WITH_TRAFFIC_CONTROL",
      asg: module.autoscale_core.asg_group_name
      alb: module.autoscale_core.alb_target_group_name
    },
    admin: {
      traffic: "WITHOUT_TRAFFIC_CONTROL",
      asg: module.autoscale_admin.asg_group_name
      alb: null
    }
  }
}