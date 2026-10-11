terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-vpc-architecture"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Fetch current account ID and region — used in IAM policies
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Latest Amazon Linux 2023 AMI — used for EC2 instances
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
