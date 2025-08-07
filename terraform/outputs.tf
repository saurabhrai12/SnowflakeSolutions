# ECS Cluster Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

# ECR Repository Outputs
output "report_service_ecr_repository_url" {
  description = "URL of the report service ECR repository"
  value       = aws_ecr_repository.report_service.repository_url
}

output "streamlit_service_ecr_repository_url" {
  description = "URL of the Streamlit service ECR repository"
  value       = aws_ecr_repository.streamlit_service.repository_url
}

output "report_service_ecr_repository_name" {
  description = "Name of the report service ECR repository"
  value       = aws_ecr_repository.report_service.name
}

output "streamlit_service_ecr_repository_name" {
  description = "Name of the Streamlit service ECR repository"
  value       = aws_ecr_repository.streamlit_service.name
}

# ECS Service Outputs
output "report_service_arn" {
  description = "ARN of the report service"
  value       = var.enable_report_service ? aws_ecs_service.report_service[0].id : null
}

output "streamlit_service_arn" {
  description = "ARN of the Streamlit service"
  value       = var.enable_streamlit_service ? aws_ecs_service.streamlit_service[0].id : null
}

output "report_service_name" {
  description = "Name of the report service"
  value       = var.enable_report_service ? aws_ecs_service.report_service[0].name : null
}

output "streamlit_service_name" {
  description = "Name of the Streamlit service"
  value       = var.enable_streamlit_service ? aws_ecs_service.streamlit_service[0].name : null
}

# Security Group Outputs
output "report_service_security_group_id" {
  description = "ID of the report service security group"
  value       = aws_security_group.report_service.id
}

output "streamlit_service_security_group_id" {
  description = "ID of the Streamlit service security group"
  value       = aws_security_group.streamlit_service.id
}

# IAM Role Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

# Secrets Manager Outputs
output "snowflake_credentials_secret_arn" {
  description = "ARN of the Snowflake credentials secret"
  value       = aws_secretsmanager_secret.snowflake_credentials.arn
  sensitive   = true
}

# CloudWatch Log Group Outputs
output "report_service_log_group_name" {
  description = "Name of the report service CloudWatch log group"
  value       = aws_cloudwatch_log_group.report_service.name
}

output "streamlit_service_log_group_name" {
  description = "Name of the Streamlit service CloudWatch log group"
  value       = aws_cloudwatch_log_group.streamlit_service.name
}

# VPC and Network Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = data.aws_subnets.default.ids
}

# AWS Account and Region Outputs
output "aws_account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS Region"
  value       = data.aws_region.current.name
}

# Task Definition Outputs
output "report_service_task_definition_arn" {
  description = "ARN of the report service task definition"
  value       = aws_ecs_task_definition.report_service.arn
}

output "streamlit_service_task_definition_arn" {
  description = "ARN of the Streamlit service task definition"
  value       = aws_ecs_task_definition.streamlit_service.arn
}

# Service URLs (will be populated after deployment)
output "deployment_instructions" {
  description = "Instructions for accessing deployed services"
  value = <<-EOT
    
    🚀 Deployment Complete!
    
    To access your services:
    1. Get the public IP addresses of running tasks:
       - Report Service: aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${var.project_name}-report-service --query 'taskArns[0]' --output text | xargs aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks | jq -r '.tasks[0].attachments[0].details[] | select(.name=="networkInterfaceId") | .value' | xargs aws ec2 describe-network-interfaces --network-interface-ids | jq -r '.NetworkInterfaces[0].Association.PublicIp'
       - Streamlit Service: aws ecs list-tasks --cluster ${aws_ecs_cluster.main.name} --service-name ${var.project_name}-streamlit-service --query 'taskArns[0]' --output text | xargs aws ecs describe-tasks --cluster ${aws_ecs_cluster.main.name} --tasks | jq -r '.tasks[0].attachments[0].details[] | select(.name=="networkInterfaceId") | .value' | xargs aws ec2 describe-network-interfaces --network-interface-ids | jq -r '.NetworkInterfaces[0].Association.PublicIp'
    
    2. Access your applications:
       - Report Service: http://<REPORT_SERVICE_IP>:8000
       - Streamlit Service: http://<STREAMLIT_SERVICE_IP>:8501
    
    3. View logs:
       - Report Service logs: aws logs tail ${aws_cloudwatch_log_group.report_service.name} --follow
       - Streamlit Service logs: aws logs tail ${aws_cloudwatch_log_group.streamlit_service.name} --follow
    
    📊 Infrastructure Summary:
    - ECS Cluster: ${aws_ecs_cluster.main.name}
    - Report Service ECR: ${aws_ecr_repository.report_service.repository_url}
    - Streamlit Service ECR: ${aws_ecr_repository.streamlit_service.repository_url}
    - Region: ${data.aws_region.current.name}
    - Account: ${data.aws_caller_identity.current.account_id}
    
  EOT
}