# Terraform Variables for Streamlit ECS Infrastructure

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "snowflake-analytics"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID for the infrastructure"
  type        = string
  
  validation {
    condition     = can(regex("^vpc-[a-z0-9]{8,17}$", var.vpc_id))
    error_message = "VPC ID must be a valid AWS VPC ID (e.g., vpc-12345678)."
  }
}

variable "subnet_ids" {
  description = "List of subnet IDs (minimum 2 for ALB)"
  type        = list(string)
  
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs are required for the load balancer."
  }
  
  validation {
    condition = alltrue([
      for subnet_id in var.subnet_ids : can(regex("^subnet-[a-z0-9]{8,17}$", subnet_id))
    ])
    error_message = "All subnet IDs must be valid AWS subnet IDs (e.g., subnet-12345678)."
  }
}

variable "domain_name" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
  
  validation {
    condition = var.domain_name == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?([.][a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.domain_name))
    error_message = "Domain name must be a valid DNS name or empty string."
  }
}

variable "certificate_arn" {
  description = "SSL Certificate ARN (optional, required if domain_name is provided)"
  type        = string
  default     = ""
  
  validation {
    condition = var.certificate_arn == "" || can(regex("^arn:aws:acm:[a-z0-9-]+:[0-9]{12}:certificate/[a-z0-9-]+$", var.certificate_arn))
    error_message = "Certificate ARN must be a valid AWS ACM certificate ARN or empty string."
  }
}

# Snowflake Configuration (optional - can be set via secrets manager manually)
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  default     = ""
  sensitive   = true
}

# Backend Configuration Variables (optional)
variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state (optional, for remote backend)"
  type        = string
  default     = ""
}

variable "terraform_state_key" {
  description = "S3 key for Terraform state (optional, for remote backend)"
  type        = string
  default     = "streamlit-ecs/terraform.tfstate"
}

variable "terraform_dynamodb_table" {
  description = "DynamoDB table for Terraform state locking (optional)"
  type        = string
  default     = ""
}

# Resource Tagging
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}