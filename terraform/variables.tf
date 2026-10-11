variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Deployment environment label."
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Used to name all resources consistently."
  type        = string
  default     = "vpc-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "app_port" {
  description = "Port the FastAPI app listens on."
  type        = number
  default     = 8000
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the app server."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "PostgreSQL database name."
  type        = string
  default     = "portfolio"
}

variable "db_username" {
  description = "PostgreSQL master username."
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL master password. Set this in a tfvars file — never hardcode."
  type        = string
  sensitive   = true
}
