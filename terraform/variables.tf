# General Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "snowflake-analytics"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "analytics-team"
}

# Snowflake Configuration
variable "snowflake_account" {
  description = "Snowflake account identifier"
  type        = string
  default     = "BIREZNC-ZHB27778"
}

variable "snowflake_user" {
  description = "Snowflake username"
  type        = string
  default     = "SAURABHMAC"
}

variable "snowflake_password" {
  description = "Snowflake password"
  type        = string
  sensitive   = true
  default     = "AwsSnowAdmin1234"
}

variable "snowflake_database" {
  description = "Snowflake database name"
  type        = string
  default     = "analytics_platform"
}

variable "snowflake_warehouse" {
  description = "Snowflake warehouse name"
  type        = string
  default     = "analytics_wh"
}

variable "snowflake_schema" {
  description = "Snowflake schema name"
  type        = string
  default     = "reporting"
}

# CloudWatch Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 30
}

# Report Service Configuration
variable "report_service_cpu" {
  description = "CPU units for report service (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "report_service_memory" {
  description = "Memory for report service in MB"
  type        = number
  default     = 2048
}

variable "report_service_desired_count" {
  description = "Desired number of report service tasks"
  type        = number
  default     = 1
}

# Streamlit Service Configuration
variable "streamlit_service_cpu" {
  description = "CPU units for Streamlit service (1024 = 1 vCPU)"
  type        = number
  default     = 1024
}

variable "streamlit_service_memory" {
  description = "Memory for Streamlit service in MB"
  type        = number
  default     = 2048
}

variable "streamlit_service_desired_count" {
  description = "Desired number of Streamlit service tasks"
  type        = number
  default     = 1
}

# Enable/Disable Services
variable "enable_report_service" {
  description = "Whether to deploy the report service"
  type        = bool
  default     = true
}

variable "enable_streamlit_service" {
  description = "Whether to deploy the Streamlit service"
  type        = bool
  default     = true
}

# Auto Scaling Configuration
variable "enable_auto_scaling" {
  description = "Whether to enable auto scaling for services"
  type        = bool
  default     = false
}

variable "auto_scaling_min_capacity" {
  description = "Minimum number of tasks for auto scaling"
  type        = number
  default     = 1
}

variable "auto_scaling_max_capacity" {
  description = "Maximum number of tasks for auto scaling"
  type        = number
  default     = 10
}

variable "auto_scaling_target_cpu" {
  description = "Target CPU utilization for auto scaling"
  type        = number
  default     = 70
}

# Load Balancer Configuration
variable "enable_load_balancer" {
  description = "Whether to create an Application Load Balancer"
  type        = bool
  default     = false
}

variable "certificate_arn" {
  description = "ARN of SSL certificate for HTTPS (optional)"
  type        = string
  default     = ""
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for the services (optional)"
  type        = string
  default     = ""
}

variable "subdomain_report" {
  description = "Subdomain for report service"
  type        = string
  default     = "reports"
}

variable "subdomain_streamlit" {
  description = "Subdomain for Streamlit service"
  type        = string
  default     = "chat"
}