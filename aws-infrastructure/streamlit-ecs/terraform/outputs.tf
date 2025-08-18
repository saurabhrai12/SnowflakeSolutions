# Terraform Outputs for Streamlit ECS Infrastructure

output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "streamlit_app_url" {
  description = "URL of the Streamlit application"
  value = var.certificate_arn != "" && var.domain_name != "" ? "https://${var.domain_name}" : (
    var.certificate_arn != "" ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
  )
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.streamlit.name
}

output "ecs_service_arn" {
  description = "ARN of the ECS service"
  value       = aws_ecs_service.streamlit.id
}

output "ecr_repository_uri" {
  description = "URI of the ECR repository"
  value       = aws_ecr_repository.streamlit.repository_url
}

output "ecr_repository_name" {
  description = "Name of the ECR repository"
  value       = aws_ecr_repository.streamlit.name
}

output "task_execution_role_arn" {
  description = "ARN of the task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "task_role_arn" {
  description = "ARN of the task role"
  value       = aws_iam_role.ecs_task.arn
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.snowflake.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.snowflake.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.streamlit.name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.streamlit.arn
}

output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"  
  value       = aws_security_group.ecs.id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.streamlit.arn
}

# Environment-specific outputs
output "environment" {
  description = "Deployment environment"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = data.aws_region.current.name
}

output "aws_account_id" {
  description = "AWS account ID"
  value       = data.aws_caller_identity.current.account_id
  sensitive   = true
}

# Task definition details
output "task_definition_family" {
  description = "Task definition family"
  value       = aws_ecs_task_definition.streamlit.family
}

output "task_definition_revision" {
  description = "Task definition revision"
  value       = aws_ecs_task_definition.streamlit.revision
}

output "task_definition_arn" {
  description = "Full ARN of the task definition"
  value       = aws_ecs_task_definition.streamlit.arn
}

# Configuration summary for next steps
output "deployment_summary" {
  description = "Deployment configuration summary"
  value = {
    environment           = var.environment
    project_name         = var.project_name
    region               = data.aws_region.current.name
    cluster_name         = aws_ecs_cluster.main.name
    service_name         = aws_ecs_service.streamlit.name
    ecr_repository       = aws_ecr_repository.streamlit.repository_url
    app_url             = var.certificate_arn != "" && var.domain_name != "" ? "https://${var.domain_name}" : (var.certificate_arn != "" ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}")
    secrets_manager_name = aws_secretsmanager_secret.snowflake.name
    log_group_name      = aws_cloudwatch_log_group.streamlit.name
  }
}