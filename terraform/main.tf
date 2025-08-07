# AWS Provider Configuration
terraform {
  required_version = ">= 1.0"
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
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Owner       = var.owner
    }
  }
}

# Data sources for existing resources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# VPC and Networking
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "report_service" {
  name              = "/ecs/${var.project_name}-report-service"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-report-service-logs"
  }
}

resource "aws_cloudwatch_log_group" "streamlit_service" {
  name              = "/ecs/${var.project_name}-streamlit-service"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-streamlit-service-logs"
  }
}

# Security Groups
resource "aws_security_group" "report_service" {
  name_prefix = "${var.project_name}-report-sg-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-report-service-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "streamlit_service" {
  name_prefix = "${var.project_name}-streamlit-sg-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8501
    to_port     = 8501
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-streamlit-service-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ECR Repositories
resource "aws_ecr_repository" "report_service" {
  name                 = "${var.project_name}-report-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-report-service-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "report_service" {
  repository = aws_ecr_repository.report_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
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

resource "aws_ecr_repository" "streamlit_service" {
  name                 = "${var.project_name}-streamlit-service"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-streamlit-service-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "streamlit_service" {
  repository = aws_ecr_repository.streamlit_service.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
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

# IAM Roles and Policies
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

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

  tags = {
    Name = "${var.project_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          aws_secretsmanager_secret.snowflake_credentials.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

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

  tags = {
    Name = "${var.project_name}-ecs-task-role"
  }
}

# Secrets Manager for Snowflake credentials
resource "aws_secretsmanager_secret" "snowflake_credentials" {
  name        = "${var.project_name}-snowflake-credentials"
  description = "Snowflake database credentials for ${var.project_name}"

  tags = {
    Name = "${var.project_name}-snowflake-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "snowflake_credentials" {
  secret_id = aws_secretsmanager_secret.snowflake_credentials.id
  secret_string = jsonencode({
    account   = var.snowflake_account
    user      = var.snowflake_user
    password  = var.snowflake_password
    database  = var.snowflake_database
    warehouse = var.snowflake_warehouse
    schema    = var.snowflake_schema
  })
}

# Task Definitions
resource "aws_ecs_task_definition" "report_service" {
  family                   = "${var.project_name}-report-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.report_service_cpu
  memory                   = var.report_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "report-service"
      image     = "${aws_ecr_repository.report_service.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "SERVICE_NAME"
          value = "report-service"
        }
      ]

      secrets = [
        {
          name      = "SNOWFLAKE_ACCOUNT"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:account::"
        },
        {
          name      = "SNOWFLAKE_USER"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:user::"
        },
        {
          name      = "SNOWFLAKE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:password::"
        },
        {
          name      = "SNOWFLAKE_DATABASE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:database::"
        },
        {
          name      = "SNOWFLAKE_WAREHOUSE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:warehouse::"
        },
        {
          name      = "SNOWFLAKE_SCHEMA"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:schema::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.report_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:8000/health || exit 1"]
        interval = 30
        timeout = 10
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-report-service-task"
  }
}

resource "aws_ecs_task_definition" "streamlit_service" {
  family                   = "${var.project_name}-streamlit-service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.streamlit_service_cpu
  memory                   = var.streamlit_service_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "streamlit-service"
      image     = "${aws_ecr_repository.streamlit_service.repository_url}:latest"
      essential = true
      
      portMappings = [
        {
          containerPort = 8501
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "STREAMLIT_SERVER_PORT"
          value = "8501"
        },
        {
          name  = "STREAMLIT_SERVER_ADDRESS"
          value = "0.0.0.0"
        },
        {
          name  = "STREAMLIT_SERVER_HEADLESS"
          value = "true"
        },
        {
          name  = "STREAMLIT_BROWSER_GATHER_USAGE_STATS"
          value = "false"
        },
        {
          name  = "SERVICE_NAME"
          value = "streamlit-cortex-analyst"
        }
      ]

      secrets = [
        {
          name      = "SNOWFLAKE_ACCOUNT"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:account::"
        },
        {
          name      = "SNOWFLAKE_USER"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:user::"
        },
        {
          name      = "SNOWFLAKE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:password::"
        },
        {
          name      = "SNOWFLAKE_DATABASE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:database::"
        },
        {
          name      = "SNOWFLAKE_WAREHOUSE"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:warehouse::"
        },
        {
          name      = "SNOWFLAKE_SCHEMA"
          valueFrom = "${aws_secretsmanager_secret.snowflake_credentials.arn}:schema::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.streamlit_service.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command = ["CMD-SHELL", "curl -f http://localhost:8501/_stcore/health || exit 1"]
        interval = 30
        timeout = 10
        retries = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.project_name}-streamlit-service-task"
  }
}

# ECS Services
resource "aws_ecs_service" "report_service" {
  count           = var.enable_report_service ? 1 : 0
  name            = "${var.project_name}-report-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.report_service.arn
  desired_count   = var.report_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.report_service.id]
    assign_public_ip = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = {
    Name = "${var.project_name}-report-service"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]
}

resource "aws_ecs_service" "streamlit_service" {
  count           = var.enable_streamlit_service ? 1 : 0
  name            = "${var.project_name}-streamlit-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.streamlit_service.arn
  desired_count   = var.streamlit_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.streamlit_service.id]
    assign_public_ip = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  tags = {
    Name = "${var.project_name}-streamlit-service"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]
}