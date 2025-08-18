# Streamlit ECS Fargate Infrastructure - Terraform Configuration
# Replaces CloudFormation template with modern Terraform approach

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Backend configuration for state management
  backend "s3" {
    # These will be configured via backend.tf or CLI
    key    = "streamlit-ecs/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources are defined in data.tf

# Local values for resource naming and configuration
locals {
  common_name = "${var.project_name}-${var.environment}"
  
  # Environment-specific resource configurations
  task_definitions = {
    dev = {
      cpu    = 512
      memory = 1024
      replicas = 1
      log_retention = 7
    }
    staging = {
      cpu    = 1024
      memory = 2048
      replicas = 1
      log_retention = 14
    }
    prod = {
      cpu    = 2048
      memory = 4096
      replicas = 2
      log_retention = 30
    }
  }
  
  task_config = local.task_definitions[var.environment]
  
# Container image configuration is defined in locals.tf
}

# ECR Repository for Streamlit App
resource "aws_ecr_repository" "streamlit" {
  name                 = "${var.project_name}-streamlit-app"
  image_tag_mutability = "MUTABLE"
  
  encryption_configuration {
    encryption_type = "AES256"
  }
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "streamlit" {
  repository = aws_ecr_repository.streamlit.name
  
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = var.environment == "prod" ? "enabled" : "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name
  
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  
  default_capacity_provider_strategy {
    base              = 1
    weight            = 1
    capacity_provider = "FARGATE"
  }
  
  default_capacity_provider_strategy {
    base              = 0
    weight            = var.environment == "prod" ? 0 : 1
    capacity_provider = "FARGATE_SPOT"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${local.common_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
  
  enable_deletion_protection = var.environment == "prod"
  
  depends_on = [aws_security_group.alb]
}

# ALB Target Group
resource "aws_lb_target_group" "streamlit" {
  name        = "${local.common_name}-tg"
  port        = 8501
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/_stcore/health"
    matcher             = "200"
    protocol            = "HTTP"
  }
  
  depends_on = [aws_lb.main]
}

# ALB Listeners
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type = var.certificate_arn != "" ? "redirect" : "forward"
    
    dynamic "redirect" {
      for_each = var.certificate_arn != "" ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
    
    dynamic "forward" {
      for_each = var.certificate_arn == "" ? [1] : []
      content {
        target_group {
          arn = aws_lb_target_group.streamlit.arn
        }
      }
    }
  }
}

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0
  
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.certificate_arn
  
  default_action {
    type = "forward"
    forward {
      target_group {
        arn = aws_lb_target_group.streamlit.arn
      }
    }
  }
}

# Security Groups
resource "aws_security_group" "alb" {
  name        = "${local.common_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id
  
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs" {
  name        = "${local.common_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id
  
  ingress {
    description     = "Traffic from ALB"
    from_port       = 8501
    to_port         = 8501
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "streamlit" {
  name              = local.log_group_name
  retention_in_days = local.config.log_retention_days
}

# IAM Roles
resource "aws_iam_role" "ecs_task_execution" {
  name = "${local.common_name}-execution-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "SecretsManagerAccess"
  role = aws_iam_role.ecs_task_execution.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${aws_secretsmanager_secret.snowflake.arn}*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.streamlit.arn}*"
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${local.common_name}-task-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "StreamlitAppPermissions"
  role = aws_iam_role.ecs_task.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.streamlit.arn}*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "${aws_secretsmanager_secret.snowflake.arn}*"
      }
    ]
  })
}

# AWS Secrets Manager
resource "aws_secretsmanager_secret" "snowflake" {
  name        = local.secret_name
  description = "Snowflake credentials for Streamlit app (${var.environment})"
  
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "snowflake" {
  secret_id = aws_secretsmanager_secret.snowflake.id
  
  secret_string = jsonencode({
    ACCOUNT   = var.snowflake_account != "" ? var.snowflake_account : "YOUR_SNOWFLAKE_ACCOUNT"
    USER      = var.snowflake_user != "" ? var.snowflake_user : "YOUR_SNOWFLAKE_USER"
    PASSWORD  = var.snowflake_password != "" ? var.snowflake_password : "YOUR_SNOWFLAKE_PASSWORD"
    DATABASE  = "analytics_platform_${var.environment}"
    WAREHOUSE = "analytics_wh_${var.environment}"
  })
  
  lifecycle {
    ignore_changes = [secret_string]
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "streamlit" {
  family                   = "streamlit-app-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = local.config.cpu
  memory                   = local.config.memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn           = aws_iam_role.ecs_task.arn
  
  container_definitions = jsonencode([
    {
      name      = "streamlit-app"
      image     = local.container_image
      essential = true
      
      portMappings = [
        {
          containerPort = 8501
          protocol      = "tcp"
        }
      ]
      
      environment = local.container_environment
      
      secrets = local.container_secrets
      
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.streamlit.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }
      
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8501/_stcore/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "streamlit" {
  name            = "streamlit-app-${var.environment}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.streamlit.arn
  desired_count   = local.config.desired_count
  launch_type     = "FARGATE"
  
  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = var.subnet_ids
    assign_public_ip = true
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.streamlit.arn
    container_name   = "streamlit-app"
    container_port   = 8501
  }
  
  health_check_grace_period_seconds = local.config.health_check_grace_period
  
  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https
  ]
  
  lifecycle {
    ignore_changes = [task_definition]
  }
}