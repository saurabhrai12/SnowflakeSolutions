# Streamlit ECS Terraform Infrastructure

This directory contains the Terraform configuration for deploying the Snowflake Cortex Analyst Streamlit application on AWS ECS Fargate. The infrastructure is designed for multi-environment deployments with a focus on security, scalability, and cost optimization.

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Internet      │    │  Application     │    │  ECS Fargate    │
│   Gateway       │────│  Load Balancer   │────│  Service        │
│                 │    │  (ALB)           │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                       ┌──────────────────┐    ┌─────────────────┐
                       │  Security        │    │  CloudWatch     │
                       │  Groups          │    │  Logs           │
                       └──────────────────┘    └─────────────────┘
                                │                        │
                       ┌──────────────────┐    ┌─────────────────┐
                       │  AWS Secrets     │    │  ECR            │
                       │  Manager         │    │  Repository     │
                       └──────────────────┘    └─────────────────┘
```

### Key Components

- **ECS Fargate Cluster**: Serverless container orchestration
- **Application Load Balancer**: Traffic distribution with SSL termination
- **ECR Repository**: Container image storage with lifecycle policies
- **AWS Secrets Manager**: Secure Snowflake credentials storage
- **CloudWatch**: Comprehensive logging and monitoring
- **IAM Roles**: Least-privilege security model

## 📁 Directory Structure

```
terraform/
├── main.tf                    # Main Terraform configuration
├── variables.tf              # Input variable definitions
├── outputs.tf               # Output value definitions
├── locals.tf                # Local values and computed data
├── data.tf                  # Data sources
├── versions.tf              # Provider version constraints
├── backend.tf               # Backend configuration guide
├── deploy.sh                # Deployment script
├── validate.sh              # Validation script
├── Makefile                 # Convenient commands
├── README.md                # This file
└── environments/
    ├── dev.tfvars          # Development environment variables
    ├── dev.backend         # Development backend configuration
    ├── staging.tfvars      # Staging environment variables
    ├── staging.backend     # Staging backend configuration
    ├── prod.tfvars         # Production environment variables
    └── prod.backend        # Production backend configuration
```

## 🚀 Quick Start

### Prerequisites

1. **Tools Required**:
   ```bash
   # Core tools
   terraform >= 1.5.0
   aws-cli >= 2.0
   docker >= 20.0
   
   # Optional but recommended
   tflint          # Security and best practices
   infracost       # Cost estimation
   terraform-docs  # Documentation generation
   ```

2. **AWS Setup**:
   ```bash
   # Configure AWS CLI
   aws configure
   
   # Verify credentials
   aws sts get-caller-identity
   ```

3. **Infrastructure Prerequisites**:
   - Existing VPC with at least 2 public subnets
   - (Optional) ACM certificate for SSL/TLS
   - (Optional) Route 53 hosted zone for custom domain

### Environment Configuration

1. **Update Environment Variables**:
   ```bash
   # Edit environment-specific configuration
   vi environments/dev.tfvars
   
   # Update VPC and subnet IDs
   vpc_id = "vpc-your-vpc-id"
   subnet_ids = [
     "subnet-your-subnet-1",
     "subnet-your-subnet-2"
   ]
   ```

2. **Configure Backend** (Recommended):
   ```bash
   # Create S3 bucket for Terraform state
   aws s3 mb s3://your-terraform-state-bucket
   
   # Create DynamoDB table for state locking
   aws dynamodb create-table \
     --table-name terraform-state-locks \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
   
   # Update backend configuration
   vi environments/dev.backend
   ```

### Deployment Options

#### Option 1: Using the Deploy Script (Recommended)

```bash
# Deploy to development
./deploy.sh -e dev

# Deploy with custom parameters
./deploy.sh -e dev -v vpc-12345 -s subnet-123,subnet-456

# Plan only (dry-run)
./deploy.sh -e staging --plan-only

# Auto-approve deployment
./deploy.sh -e prod -a
```

#### Option 2: Using Makefile

```bash
# Show available commands
make help

# Validate configuration
make validate ENV=dev

# Plan deployment
make plan ENV=dev

# Deploy infrastructure
make apply ENV=dev

# Quick deployment (format, validate, and apply)
make quick-dev
```

#### Option 3: Direct Terraform Commands

```bash
# Initialize
terraform init -backend-config=environments/dev.backend

# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
```

## 🌍 Environment Configuration

### Development Environment

```hcl
# environments/dev.tfvars
environment    = "dev"
project_name   = "snowflake-analytics"
aws_region     = "us-east-1"

# Cost-optimized configuration
# - 512 CPU / 1024 MB RAM
# - 1 replica
# - 7-day log retention
# - Fargate Spot for cost savings
```

### Staging Environment

```hcl
# environments/staging.tfvars
environment    = "staging"
project_name   = "snowflake-analytics"
aws_region     = "us-east-1"

# Performance testing configuration
# - 1024 CPU / 2048 MB RAM
# - 1 replica
# - 14-day log retention
# - Mixed Fargate/Fargate Spot
```

### Production Environment

```hcl
# environments/prod.tfvars
environment    = "prod"
project_name   = "snowflake-analytics"
aws_region     = "us-east-1"

# Production-ready configuration
# - 2048 CPU / 4096 MB RAM
# - 2 replicas
# - 30-day log retention
# - Fargate only for reliability
# - Container Insights enabled
# - Deletion protection enabled
```

## 🔐 Security Configuration

### IAM Roles and Policies

The infrastructure uses a least-privilege security model:

1. **ECS Task Execution Role**:
   - Pulls images from ECR
   - Accesses Secrets Manager
   - Writes to CloudWatch Logs

2. **ECS Task Role**:
   - Runtime permissions for the application
   - Access to specific AWS services as needed

### Secrets Management

Snowflake credentials are stored securely in AWS Secrets Manager:

```bash
# Update secrets after deployment
aws secretsmanager update-secret \
  --secret-id "streamlit/dev/snowflake" \
  --secret-string '{
    "ACCOUNT": "your-account.region",
    "USER": "your-user",
    "PASSWORD": "your-password",
    "DATABASE": "analytics_platform_dev",
    "WAREHOUSE": "analytics_wh_dev"
  }'
```

### Network Security

- **ALB Security Group**: Only allows HTTP(80) and HTTPS(443) from internet
- **ECS Security Group**: Only allows traffic from ALB on port 8501
- **Private networking**: ECS tasks communicate privately with AWS services

## 📊 Monitoring and Observability

### CloudWatch Integration

- **Log Groups**: Centralized application logs
- **Metrics**: ECS service and task metrics
- **Alarms**: (Can be added) Health check failures, resource utilization

### Health Checks

- **ALB Health Checks**: Monitors `/_stcore/health` endpoint
- **Container Health Checks**: Built-in Docker health checks
- **Service Health**: ECS service stability monitoring

## 💰 Cost Optimization

### Environment-Specific Resource Allocation

| Environment | CPU  | Memory | Replicas | Fargate Spot |
|------------|------|---------|----------|--------------|
| Dev        | 512  | 1024MB  | 1        | Primary      |
| Staging    | 1024 | 2048MB  | 1        | Mixed        |
| Prod       | 2048 | 4096MB  | 2        | None         |

### Cost Monitoring

```bash
# Generate cost estimate
make cost ENV=dev

# Alternative: Using infracost directly
infracost breakdown --path . --terraform-var-file=environments/dev.tfvars
```

## 🔄 CI/CD Integration

### GitHub Actions Workflow

The infrastructure integrates with GitHub Actions for automated deployments:

- **Branch Strategy**: 
  - Feature branches → Dev environment
  - Main branch → Staging environment
  - Manual trigger → Production environment

- **Terraform Actions**:
  - `plan`: Review changes before deployment
  - `apply`: Deploy infrastructure changes
  - `destroy`: Remove infrastructure

### Workflow Configuration

```yaml
# .github/workflows/streamlit-terraform-deployment.yml
- name: 🏗️ Terraform Apply
  run: |
    terraform apply -auto-approve \
      -var-file=environments/${{ env.ENVIRONMENT }}.tfvars
```

## 🛠️ Advanced Usage

### State Management

```bash
# List all resources
terraform state list

# Show specific resource
terraform state show aws_ecs_cluster.main

# Import existing resource
terraform import aws_ecs_cluster.main cluster-name

# Move resource to different address
terraform state mv aws_ecs_cluster.main aws_ecs_cluster.primary
```

### Workspace Management

```bash
# Create workspace for feature branch
terraform workspace new feature-branch

# Switch workspace
terraform workspace select dev

# List workspaces
terraform workspace list
```

### Custom Domains and SSL

```hcl
# environments/prod.tfvars
domain_name     = "streamlit.yourcompany.com"
certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/your-cert-id"
```

## 📝 Maintenance Tasks

### Regular Maintenance

1. **Update Terraform**:
   ```bash
   # Check for updates
   terraform version
   
   # Upgrade providers
   make upgrade ENV=dev
   ```

2. **Security Updates**:
   ```bash
   # Run security checks
   make security
   
   # Update base images
   docker pull python:3.11-slim
   ```

3. **Cost Review**:
   ```bash
   # Generate cost reports
   make cost ENV=prod
   
   # Review resource utilization
   aws ecs describe-services --cluster prod-cluster
   ```

### Troubleshooting

#### Common Issues

1. **State Lock**: 
   ```bash
   terraform force-unlock <lock-id>
   ```

2. **Backend Configuration**:
   ```bash
   terraform init -reconfigure -backend-config=environments/dev.backend
   ```

3. **Resource Conflicts**:
   ```bash
   terraform import <resource_type>.<resource_name> <resource_id>
   ```

#### Validation Commands

```bash
# Comprehensive validation
./validate.sh -e dev

# Format and validate
make format validate ENV=dev

# Plan with detailed output
make plan-detailed ENV=dev
```

## 🤝 Contributing

### Development Workflow

1. **Create Feature Branch**:
   ```bash
   git checkout -b feature/infrastructure-enhancement
   ```

2. **Make Changes**:
   ```bash
   # Edit Terraform files
   vi main.tf
   
   # Validate changes
   make validate ENV=dev
   ```

3. **Test Changes**:
   ```bash
   # Plan deployment
   make plan ENV=dev
   
   # Apply to dev environment
   make apply ENV=dev
   ```

4. **Submit PR**: GitHub Actions will automatically plan and validate

### Best Practices

1. **Code Style**:
   ```bash
   # Format code before commit
   make format
   ```

2. **Security**:
   ```bash
   # Run security checks
   make security
   ```

3. **Documentation**:
   ```bash
   # Generate updated documentation
   make docs
   ```

## 📚 References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS ECS Fargate](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/AWS_Fargate.html)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [Snowflake Connector](https://docs.snowflake.com/en/user-guide/python-connector.html)

## 🆘 Support

For issues and questions:

1. Check the troubleshooting section above
2. Review GitHub Actions logs for deployment issues
3. Check AWS CloudWatch logs for application issues
4. Create an issue in the repository for infrastructure problems

---

**Note**: This infrastructure configuration is designed for production use with security, scalability, and cost optimization in mind. Always review changes in development and staging environments before deploying to production.