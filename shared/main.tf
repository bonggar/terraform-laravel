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
    bucket  = "bgrdev.terraform"
    key     = "best-parts/shared.tfstate"
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
  default     = "shared"
}

variable "default_region" {
  type        = string
  description = "the region this infrastructure is in"
  default     = "ap-southeast-1"
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token"
  sensitive   = true
}

variable "git_url" {
  type        = string
  description = "Git Clone URL (.git)"
}

module "ci_cd" {
  source = "../modules/codebuild"

  infra_env    = var.infra_env
  git_url      = var.git_url
  github_token = var.github_token
}
