# Streamlit ECS Fargate Deployment Guide

This guide provides step-by-step instructions for deploying the Snowflake Cortex Analyst Streamlit application on AWS ECS Fargate using Docker and GitHub Actions CI/CD.

## Overview

The deployment architecture includes:
- **Docker containerization** with multi-stage builds and security best practices
- **GitHub Actions CI/CD** with branch-based deployments (feature → dev, main → staging)
- **AWS ECS Fargate** for serverless container orchestration
- **Application Load Balancer (ALB)** for traffic distribution and SSL termination
- **AWS Secrets Manager** for secure credential management
- **CloudWatch** for comprehensive logging and monitoring

## Prerequisites

### AWS Account Setup
1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
3. **Docker** installed locally for testing
4. **GitHub repository** with Actions enabled

### Required AWS Services
- ECS (Elastic Container Service)
- ECR (Elastic Container Registry)  
- ALB (Application Load Balancer)
- Secrets Manager
- CloudWatch
- IAM (Identity and Access Management)

### GitHub Secrets Configuration

Configure the following secrets in your GitHub repository:
```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=your_access_key_id
AWS_SECRET_ACCESS_KEY=your_secret_access_key
AWS_ACCOUNT_ID=123456789012

# Snowflake Credentials (for local development)
SNOWFLAKE_ACCOUNT=your_snowflake_account
SNOWFLAKE_USER=your_snowflake_user
SNOWFLAKE_PASSWORD=your_snowflake_password
```

## Step 1: Infrastructure Setup

### 1.1 Deploy Infrastructure using CloudFormation

The infrastructure is defined in `aws-infrastructure/streamlit-ecs/cloudformation-template.yml`.

**Prerequisites:**
- Existing VPC with at least 2 public subnets
- AWS CLI configured with appropriate permissions

**Deploy Infrastructure:**
```bash
cd aws-infrastructure/streamlit-ecs

# For development environment
./deploy.sh -e dev -v vpc-12345678 -s subnet-12345678,subnet-87654321

# For staging environment (with SSL)
./deploy.sh -e staging -v vpc-12345678 -s subnet-12345678,subnet-87654321 \
  -d streamlit.yourcompany.com -c arn:aws:acm:us-east-1:123456789012:certificate/cert-id

# For production environment (with SSL and custom domain)
./deploy.sh -e prod -v vpc-12345678 -s subnet-12345678,subnet-87654321 \
  -d streamlit.yourcompany.com -c arn:aws:acm:us-east-1:123456789012:certificate/cert-id
```

**What gets created:**
- ECS Cluster: `snowflake-analytics-cluster`
- ECR Repository: `snowflake-streamlit-app`
- Application Load Balancer with target groups
- Security groups for ALB and ECS tasks
- IAM roles for ECS task execution and application
- CloudWatch log groups
- Environment-specific task definitions (dev: 512 CPU/1GB RAM, staging: 1024 CPU/2GB RAM, prod: 2048 CPU/4GB RAM)

### 1.2 Configure Snowflake Credentials

After infrastructure deployment, update the AWS Secrets Manager secret with your actual Snowflake credentials:

```bash
# Replace with your actual credentials
aws secretsmanager update-secret \
  --secret-id "streamlit/dev/snowflake" \
  --secret-string '{
    "ACCOUNT": "your_snowflake_account.region", 
    "USER": "your_snowflake_user",
    "PASSWORD": "your_snowflake_password",
    "DATABASE": "analytics_platform_dev",
    "WAREHOUSE": "analytics_wh_dev"
  }'
```

## Step 2: GitHub Actions CI/CD Setup

### 2.1 Workflow Configuration

The CI/CD pipeline is defined in `.github/workflows/streamlit-app-deployment.yml` and includes:

**Workflow Triggers:**
- **Push to feature branches** → Deploy to DEV environment
- **Push to main branch** → Deploy to STAGING environment  
- **Manual dispatch** → Deploy to any environment (DEV/STAGING/PROD)
- **Pull requests** → Deploy to DEV for testing

**Pipeline Stages:**
1. **Setup**: Determine environment and deployment parameters
2. **Build & Test**: Python dependency installation, security scanning
3. **Docker**: Build multi-platform image, vulnerability scanning, push to ECR
4. **Deploy**: Update ECS service with new task definition

### 2.2 Environment-Specific Deployments

**Branch Strategy:**
```bash
feature/new-feature → DEV environment
main branch → STAGING environment
Manual trigger → PROD environment (requires approval)
```

**Automatic Deployments:**
- Only triggered when files in `streamlit-app/` directory change
- Smart change detection prevents unnecessary deployments
- Force deployment option available for manual triggers

## Step 3: Local Development and Testing

### 3.1 Local Development Setup

```bash
# Navigate to streamlit app directory
cd streamlit-app

# Create virtual environment using UV
uv venv
source .venv/bin/activate

# Install dependencies
uv pip install -r requirements.txt

# Set environment variables
export SNOWFLAKE_ACCOUNT="your_account"
export SNOWFLAKE_USER="your_user" 
export SNOWFLAKE_PASSWORD="your_password"
export SNOWFLAKE_DATABASE="analytics_platform"
export SNOWFLAKE_WAREHOUSE="analytics_wh"

# Run locally
streamlit run app.py
```

### 3.2 Local Docker Testing

```bash
# Build Docker image
docker build -t streamlit-cortex-local .

# Run container locally
docker run -p 8501:8501 \
  -e SNOWFLAKE_ACCOUNT="your_account" \
  -e SNOWFLAKE_USER="your_user" \
  -e SNOWFLAKE_PASSWORD="your_password" \
  -e SNOWFLAKE_DATABASE="analytics_platform" \
  -e SNOWFLAKE_WAREHOUSE="analytics_wh" \
  streamlit-cortex-local

# Test health endpoint
curl http://localhost:8501/_stcore/health
```

## Step 4: Deployment Process

### 4.1 Feature Development Workflow

1. **Create Feature Branch:**
   ```bash
   git checkout -b feature/cortex-analytics-enhancement
   # Make changes to streamlit-app/
   git commit -m "Add new analytics dashboard"
   git push origin feature/cortex-analytics-enhancement
   ```

2. **Automatic DEV Deployment:**
   - GitHub Actions automatically detects changes in `streamlit-app/`
   - Builds and deploys to DEV environment
   - Provides deployment summary with service URLs

3. **Testing in DEV:**
   - Access DEV environment via ALB URL
   - Test functionality with development data
   - Verify health checks and logs in CloudWatch

### 4.2 Production Release Workflow

1. **Merge to Main:**
   ```bash
   git checkout main
   git merge feature/cortex-analytics-enhancement
   git push origin main
   ```

2. **Automatic STAGING Deployment:**
   - GitHub Actions deploys to STAGING environment
   - Higher resource allocation (1024 CPU / 2GB RAM)
   - Production-like environment for final testing

3. **Manual PROD Deployment:**
   ```bash
   # Trigger manual deployment via GitHub Actions UI
   # Or use GitHub CLI
   gh workflow run "Streamlit App ECS Deployment" \
     -f environment=prod \
     -f force_deploy=true
   ```

### 4.3 Deployment Monitoring

**GitHub Actions Dashboard:**
- Real-time deployment status
- Deployment history and rollback options
- Security scan results and artifacts

**AWS Console Monitoring:**
- ECS Service health and task status
- CloudWatch logs and metrics
- ALB target group health checks

## Step 5: Monitoring and Troubleshooting

### 5.1 Health Monitoring

**ECS Service Health:**
```bash
# Check service status
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services streamlit-app-dev

# View running tasks
aws ecs list-tasks \
  --cluster snowflake-analytics-cluster \
  --service-name streamlit-app-dev
```

**Application Health Checks:**
```bash
# Health endpoint (replace with your ALB DNS)
curl http://your-alb-dns-name/_stcore/health

# Expected response: OK (Status: 200)
```

### 5.2 Log Analysis

**CloudWatch Logs:**
```bash
# View application logs
aws logs describe-log-groups --log-group-name-prefix "/ecs/streamlit-app"

# Stream logs in real-time
aws logs tail /ecs/streamlit-app/dev --follow
```

**Common Log Patterns:**
- `Successfully connected to Snowflake` - Successful startup
- `Failed to connect to Snowflake` - Connection issues
- `Error in Cortex Analyst query` - Query processing errors

### 5.3 Troubleshooting Common Issues

**Issue: ECS Tasks Failing to Start**
```bash
# Check task definition
aws ecs describe-task-definition --task-definition streamlit-app-dev

# Check service events  
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services streamlit-app-dev \
  --query 'services[0].events[0:5]'
```

**Issue: Snowflake Connection Failures**
```bash
# Verify secrets in AWS Secrets Manager
aws secretsmanager get-secret-value --secret-id "streamlit/dev/snowflake"

# Check ECS task logs
aws logs filter-log-events \
  --log-group-name "/ecs/streamlit-app/dev" \
  --filter-pattern "snowflake"
```

**Issue: Load Balancer Health Check Failures**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn your-target-group-arn

# Verify security group rules
aws ec2 describe-security-groups --group-ids sg-your-ecs-security-group
```

## Step 6: Security Best Practices

### 6.1 Container Security

**Docker Security Features:**
- Non-root user (`streamlit` user)
- Multi-stage builds to minimize attack surface
- Security scanning with Trivy in CI/CD pipeline
- Secrets injection via AWS Secrets Manager (not environment variables)

**Security Validation:**
```bash
# Run security validation script
./scripts/validate-docker-security.sh

# Manual security scan
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image streamlit-cortex-app:latest
```

### 6.2 Network Security

**Security Groups:**
- ALB Security Group: Only allows HTTP(80) and HTTPS(443) from internet
- ECS Security Group: Only allows traffic from ALB on port 8501
- No direct internet access to ECS tasks

**SSL/TLS Configuration:**
- Optional SSL certificate for custom domains
- Automatic HTTP to HTTPS redirection when SSL is configured
- TLS 1.2+ enforcement at the load balancer level

### 6.3 Secrets Management

**AWS Secrets Manager Integration:**
- Snowflake credentials stored securely in Secrets Manager
- Automatic secret rotation support
- Granular IAM permissions for secret access
- No hardcoded credentials in containers or code

## Step 7: Scaling and Performance

### 7.1 Auto Scaling Configuration

**Horizontal Scaling:**
```bash
# Update service desired count
aws ecs update-service \
  --cluster snowflake-analytics-cluster \
  --service streamlit-app-prod \
  --desired-count 3
```

**Resource Optimization:**
- DEV: 512 CPU / 1024 MB RAM (cost-optimized)
- STAGING: 1024 CPU / 2048 MB RAM (performance testing)
- PROD: 2048 CPU / 4096 MB RAM (production workload)

### 7.2 Performance Monitoring

**CloudWatch Metrics:**
- CPU and memory utilization
- Request count and response times
- Error rates and health check status

**Application Metrics:**
- Snowflake connection pool status
- Query execution times
- User session metrics

## Step 8: Backup and Disaster Recovery

### 8.1 Container Image Management

**ECR Lifecycle Policy:**
- Keeps last 10 tagged images automatically
- Environment-specific tags (dev-latest, staging-latest, prod-latest)
- Immutable tags with timestamps for point-in-time recovery

### 8.2 Database Backup Strategy

**Snowflake Data Protection:**
- Time Travel for data recovery (up to 90 days in enterprise)
- Database cloning for testing and development
- Cross-region replication for disaster recovery

### 8.3 Infrastructure Backup

**CloudFormation Stack:**
- Infrastructure as Code ensures reproducibility
- Version controlled deployment scripts
- Cross-region deployment capability

## Appendix: Useful Commands

### A.1 AWS CLI Commands

```bash
# List ECS clusters
aws ecs list-clusters

# Describe ECS service
aws ecs describe-services --cluster snowflake-analytics-cluster --services streamlit-app-dev

# Update ECS service
aws ecs update-service --cluster snowflake-analytics-cluster --service streamlit-app-dev --force-new-deployment

# View CloudWatch logs
aws logs describe-log-streams --log-group-name "/ecs/streamlit-app/dev"

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/target-group-name

# List ECR repositories
aws ecr describe-repositories

# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

### A.2 Docker Commands

```bash
# Build multi-platform image
docker buildx build --platform linux/amd64 -t streamlit-app .

# Push to ECR
docker tag streamlit-app:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/snowflake-streamlit-app:dev-latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/snowflake-streamlit-app:dev-latest

# Run container with secrets
docker run --rm -p 8501:8501 \
  -e SNOWFLAKE_ACCOUNT="account.region" \
  -e SNOWFLAKE_USER="username" \
  -e SNOWFLAKE_PASSWORD="password" \
  streamlit-app:latest
```

### A.3 GitHub CLI Commands

```bash
# Trigger manual deployment
gh workflow run "Streamlit App ECS Deployment" -f environment=dev -f force_deploy=true

# View workflow runs
gh run list --workflow="streamlit-app-deployment.yml"

# View workflow logs
gh run view --log
```

## Conclusion

This deployment guide provides a comprehensive, production-ready solution for deploying Streamlit applications on AWS ECS Fargate. The architecture emphasizes security, scalability, and operational excellence while maintaining cost efficiency through environment-specific resource allocation.

Key benefits of this deployment approach:
- **Serverless container orchestration** with ECS Fargate
- **Branch-based CI/CD** for streamlined development workflow
- **Comprehensive security** with secrets management and container scanning  
- **Auto-scaling capabilities** for varying workload demands
- **Cost optimization** through environment-specific resource sizing
- **Production-grade monitoring** and logging

For additional support or questions about this deployment, refer to the AWS documentation for ECS Fargate, Streamlit documentation, or contact your DevOps team.