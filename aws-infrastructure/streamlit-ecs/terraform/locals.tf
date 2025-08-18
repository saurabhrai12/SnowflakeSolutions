# Local values for Terraform configuration
# This file defines computed values and constants used throughout the configuration

locals {
  # Common naming convention
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Resource naming
  cluster_name       = "${local.name_prefix}-cluster"
  service_name      = "streamlit-app-${var.environment}"
  repository_name   = "${var.project_name}-streamlit-app"
  log_group_name    = "/ecs/streamlit-app/${var.environment}"
  secret_name       = "streamlit/${var.environment}/snowflake"
  
  # Environment-specific configurations
  environment_config = {
    dev = {
      cpu                    = 512
      memory                = 1024
      desired_count         = 1
      log_retention_days    = 7
      enable_container_insights = false
      enable_deletion_protection = false
      health_check_grace_period = 300
      
      # Cost optimization settings
      capacity_provider_strategy = {
        fargate = {
          base   = 0
          weight = 1
        }
        fargate_spot = {
          base   = 1
          weight = 2
        }
      }
    }
    
    staging = {
      cpu                    = 1024
      memory                = 2048
      desired_count         = 1
      log_retention_days    = 14
      enable_container_insights = true
      enable_deletion_protection = false
      health_check_grace_period = 300
      
      # Balanced performance/cost
      capacity_provider_strategy = {
        fargate = {
          base   = 1
          weight = 2
        }
        fargate_spot = {
          base   = 0
          weight = 1
        }
      }
    }
    
    prod = {
      cpu                    = 2048
      memory                = 4096
      desired_count         = 2
      log_retention_days    = 30
      enable_container_insights = true
      enable_deletion_protection = true
      health_check_grace_period = 600
      
      # Production reliability
      capacity_provider_strategy = {
        fargate = {
          base   = 2
          weight = 1
        }
        fargate_spot = {
          base   = 0
          weight = 0
        }
      }
    }
  }
  
  # Current environment configuration
  config = local.environment_config[var.environment]
  
  # AWS Account and Region
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Container image URI  
  container_image = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.repository_name}:${var.environment}-latest"
  
  # SSL/TLS Configuration
  use_ssl = var.certificate_arn != ""
  
  # Common tags applied to all resources
  common_tags = merge(
    {
      Project              = var.project_name
      Environment          = var.environment
      ManagedBy           = "Terraform"
      Application         = "streamlit-app"
      Component           = "infrastructure"
      TerraformWorkspace  = terraform.workspace
      CreatedDate         = formatdate("YYYY-MM-DD", timestamp())
    },
    var.additional_tags
  )
  
  # Security group rules
  alb_ingress_rules = [
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
  
  # Target group health check configuration
  health_check = {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout            = 10
    interval           = 30
    path               = "/_stcore/health"
    matcher            = "200"
    protocol           = "HTTP"
    port               = "traffic-port"
  }
  
  # Container environment variables
  container_environment = [
    {
      name  = "ENVIRONMENT"
      value = var.environment
    },
    {
      name  = "AWS_DEFAULT_REGION"
      value = local.region
    },
    {
      name  = "SERVICE_NAME"
      value = local.service_name
    },
    {
      name  = "LOG_LEVEL"
      value = var.environment == "prod" ? "WARNING" : "INFO"
    }
  ]
  
  # Container secrets from AWS Secrets Manager
  container_secrets = [
    {
      name      = "SNOWFLAKE_ACCOUNT"
      valueFrom = "${aws_secretsmanager_secret.snowflake.arn}:ACCOUNT::"
    },
    {
      name      = "SNOWFLAKE_USER"
      valueFrom = "${aws_secretsmanager_secret.snowflake.arn}:USER::"
    },
    {
      name      = "SNOWFLAKE_PASSWORD"
      valueFrom = "${aws_secretsmanager_secret.snowflake.arn}:PASSWORD::"
    },
    {
      name      = "SNOWFLAKE_DATABASE"
      valueFrom = "${aws_secretsmanager_secret.snowflake.arn}:DATABASE::"
    },
    {
      name      = "SNOWFLAKE_WAREHOUSE"
      valueFrom = "${aws_secretsmanager_secret.snowflake.arn}:WAREHOUSE::"
    }
  ]
}