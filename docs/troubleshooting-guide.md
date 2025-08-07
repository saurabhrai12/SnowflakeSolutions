# Troubleshooting Guide - AWS ECS Snowflake Integration

This document provides comprehensive troubleshooting guidance for common issues encountered during AWS ECS deployment and Snowflake integration.

## Table of Contents

1. [Docker Build and Image Issues](#docker-build-and-image-issues)
2. [ECR Authentication and Push Problems](#ecr-authentication-and-push-problems)
3. [ECS Task Launch Failures](#ecs-task-launch-failures)
4. [Network and Connectivity Issues](#network-and-connectivity-issues)
5. [Secrets Manager and IAM Problems](#secrets-manager-and-iam-problems)
6. [Snowflake Integration Issues](#snowflake-integration-issues)
7. [Application Runtime Errors](#application-runtime-errors)
8. [Performance and Scaling Issues](#performance-and-scaling-issues)
9. [Monitoring and Logging Problems](#monitoring-and-logging-problems)
10. [Cost Optimization Issues](#cost-optimization-issues)

---

## Docker Build and Image Issues

### Issue 1: Architecture Compatibility Error

**Error Message:**
```
exec /usr/local/bin/python: exec format error
```
or
```
image with reference was found but does not match the specified platform
```

**Root Cause:**
- Building ARM64 image on Apple M1/M2 Mac
- AWS Fargate requires linux/amd64 architecture
- Default Docker build uses host architecture

**Solution:**
```bash
# Build for correct architecture
docker build --platform linux/amd64 -t snowflake-report-service:latest .

# Verify image architecture
docker inspect snowflake-report-service:latest | grep Architecture
```

**Prevention:**
- Always specify `--platform linux/amd64` for AWS deployments
- Use multi-platform builds for broader compatibility
- Test images on target architecture before deployment

### Issue 2: Docker Build Fails on Dependencies

**Error Message:**
```
ERROR: Could not find a version that satisfies the requirement
```

**Root Cause:**
- Platform-specific Python packages
- Missing system dependencies
- Package version conflicts

**Diagnostic Commands:**
```bash
# Check available package versions
docker run --platform linux/amd64 python:3.11-slim pip index versions snowflake-connector-python

# Test dependency installation
docker build --platform linux/amd64 --target builder -t test-deps .
docker run --platform linux/amd64 test-deps pip list
```

**Solution:**
```dockerfile
# Add platform-specific package sources
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Use UV for faster, more reliable package management
RUN uv pip install --no-cache .
```

### Issue 3: Large Image Size

**Problem:** Docker image exceeds 10GB, causing slow deployments

**Diagnostic:**
```bash
# Check image layers
docker history snowflake-report-service:latest

# Check image size
docker images snowflake-report-service
```

**Solution:**
```dockerfile
# Multi-stage build optimization
FROM python:3.11-slim as builder
# Install dependencies

FROM python:3.11-slim
# Copy only necessary files
COPY --from=builder /opt/venv /opt/venv

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
```

---

## ECR Authentication and Push Problems

### Issue 1: ECR Login Failure

**Error Message:**
```
Error response from daemon: Get https://203977009513.dkr.ecr.us-east-1.amazonaws.com/v2/: no basic auth credentials
```

**Root Cause:**
- ECR authentication token expired (12-hour limit)
- Incorrect AWS credentials
- Wrong region specified

**Diagnostic Commands:**
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify ECR repository exists
aws ecr describe-repositories --repository-names snowflake-report-service

# Check region configuration
aws configure get region
```

**Solution:**
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  203977009513.dkr.ecr.us-east-1.amazonaws.com

# Verify login success
docker info | grep Registry
```

### Issue 2: Push Permission Denied

**Error Message:**
```
denied: User is not authorized to perform: ecr:BatchCheckLayerAvailability
```

**Root Cause:**
- Insufficient IAM permissions
- ECR repository policy restrictions
- Cross-account access issues

**Required IAM Permissions:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "arn:aws:ecr:us-east-1:203977009513:repository/snowflake-report-service"
        }
    ]
}
```

**Diagnostic:**
```bash
# Check user permissions
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ecr:PutImage \
  --resource-arns arn:aws:ecr:us-east-1:203977009513:repository/snowflake-report-service
```

---

## ECS Task Launch Failures

### Issue 1: Task Fails to Start

**Error Message:**
```
Task stopped with reason: Task failed to start
```

**Common Causes and Solutions:**

#### Insufficient CPU/Memory
```bash
# Check task definition resources
aws ecs describe-task-definition --task-definition snowflake-report-service

# Monitor resource utilization
aws ecs describe-tasks --cluster snowflake-analytics-cluster --tasks <task-id>
```

**Solution:** Increase CPU/memory allocation in task definition

#### Image Pull Errors
```bash
# Check ECR permissions
aws ecr get-authorization-token

# Verify image exists
aws ecr list-images --repository-name snowflake-report-service
```

#### Secrets Access Issues
```bash
# Check task role permissions
aws iam get-role --role-name snowflake-report-service-task-role

# Verify secret ARNs in task definition
aws secretsmanager describe-secret --secret-id snowflake/account
```

### Issue 2: Health Check Failures

**Error Message:**
```
Task failed container health checks
```

**Diagnostic Commands:**
```bash
# Check application logs
aws logs get-log-events \
  --log-group-name /ecs/snowflake-report-service \
  --log-stream-name ecs/report-service/<task-id>

# Test health endpoint manually
curl -f http://<task-ip>:8000/health
```

**Common Solutions:**

#### Application Startup Time
```json
{
  "healthCheck": {
    "startPeriod": 120,  // Increase from 60 seconds
    "interval": 30,
    "timeout": 10,
    "retries": 3
  }
}
```

#### Port Configuration
```bash
# Verify application listens on correct port
docker run -p 8000:8000 snowflake-report-service:latest
curl http://localhost:8000/health
```

### Issue 3: Subnet and Security Group Issues

**Error Message:**
```
InvalidParameterException: The subnet ID 'subnet-xxx' does not exist
```

**Diagnostic Commands:**
```bash
# List available subnets
aws ec2 describe-subnets --query 'Subnets[?State==`available`]'

# Check security group rules
aws ec2 describe-security-groups --group-ids sg-0472eb521ab57d29c
```

**Solution:**
```bash
# Use correct subnet IDs for your account
aws ecs create-service \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-correct-id],securityGroups=[sg-correct-id]}"
```

---

## Network and Connectivity Issues

### Issue 1: Cannot Access Application from Internet

**Problem:** curl commands to task IP timeout or refuse connection

**Diagnostic Steps:**

#### Check Security Group Rules
```bash
aws ec2 describe-security-groups \
  --group-ids sg-0472eb521ab57d29c \
  --query 'SecurityGroups[0].IpPermissions'
```

**Required Inbound Rules:**
- Port 8000 from 0.0.0.0/0 (or specific IPs)
- Protocol: TCP

#### Verify Public IP Assignment
```bash
# Check if task has public IP
aws ecs describe-tasks \
  --cluster snowflake-analytics-cluster \
  --tasks <task-id> \
  --query 'tasks[0].attachments[0].details'
```

#### Test Network Connectivity
```bash
# Test from different networks
curl -v http://<task-ip>:8000/health

# Check DNS resolution
nslookup <task-ip>

# Test port connectivity
telnet <task-ip> 8000
```

### Issue 2: Snowflake Connectivity Problems

**Error Message:**
```
250001 (08001): Failed to connect to DB: xxx.snowflakecomputing.com:443
```

**Diagnostic Commands:**
```bash
# Test Snowflake connectivity from task
aws ecs execute-command \
  --cluster snowflake-analytics-cluster \
  --task <task-id> \
  --container report-service \
  --interactive \
  --command "/bin/bash"

# Inside container:
curl -v https://BIREZNC-ZHB27778.snowflakecomputing.com
```

**Common Solutions:**

#### Outbound Internet Access
- Ensure tasks are in public subnets with internet gateway
- Or use NAT Gateway for private subnets
- Check outbound security group rules

#### Firewall/Proxy Issues
```bash
# Check if corporate firewall blocks Snowflake
aws ec2 describe-security-groups \
  --group-ids sg-0472eb521ab57d29c \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

**Required Outbound Rules:**
- HTTPS (443) to 0.0.0.0/0
- HTTP (80) to 0.0.0.0/0 (for some Snowflake operations)

---

## Secrets Manager and IAM Problems

### Issue 1: Cannot Access Secrets

**Error Message:**
```
User is not authorized to perform: secretsmanager:GetSecretValue
```

**Diagnostic Commands:**
```bash
# Check task role
aws ecs describe-task-definition \
  --task-definition snowflake-report-service \
  --query 'taskDefinition.taskRoleArn'

# Check role permissions
aws iam list-attached-role-policies \
  --role-name snowflake-report-service-task-role

# Test secret access
aws secretsmanager get-secret-value \
  --secret-id snowflake/account
```

**Required IAM Policy:**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/*"
            ]
        }
    ]
}
```

### Issue 2: Secret ARN Changes

**Problem:** Task definition references old secret ARNs after secret recreation

**Diagnostic:**
```bash
# List current secret ARNs
aws secretsmanager list-secrets \
  --filters Key=name,Values=snowflake/

# Compare with task definition
aws ecs describe-task-definition \
  --task-definition snowflake-report-service \
  --query 'taskDefinition.containerDefinitions[0].secrets'
```

**Solution:**
- Update task definition with new ARNs
- Use IAM policies with wildcard ARNs for flexibility

### Issue 3: Cross-Region Secret Access

**Error Message:**
```
Secrets Manager can't find the specified secret
```

**Cause:** Secrets and ECS tasks in different regions

**Solution:**
```bash
# Ensure secrets and tasks are in same region
aws secretsmanager list-secrets --region us-east-1
aws ecs list-clusters --region us-east-1
```

---

## Snowflake Integration Issues

### Issue 1: External Function Creation Fails

**Error Message:**
```
SQL compilation error: External access integration 'ECS_REPORT_INTEGRATION' does not exist
```

**Diagnostic Steps:**
```sql
-- Check network rules
SHOW NETWORK RULES;

-- Check external access integrations
SHOW EXTERNAL ACCESS INTEGRATIONS;

-- Check grants
SHOW GRANTS TO ROLE ACCOUNTADMIN;
```

**Solution Sequence:**
```sql
-- 1. Create network rule first
CREATE OR REPLACE NETWORK RULE ecs_report_service_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('54.88.92.124:8000');

-- 2. Create integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION ecs_report_integration
  ALLOWED_NETWORK_RULES = (ecs_report_service_rule)
  ENABLED = true;

-- 3. Grant usage
GRANT USAGE ON INTEGRATION ecs_report_integration TO ROLE ACCOUNTADMIN;

-- 4. Create function
CREATE OR REPLACE FUNCTION reporting.generate_report_via_ecs(...)
```

### Issue 2: Python Function Execution Errors

**Error Message:**
```
Python Interpreter Error: ModuleNotFoundError: No module named 'requests'
```

**Solution:**
```sql
-- Ensure packages are specified correctly
CREATE OR REPLACE FUNCTION reporting.generate_report_via_ecs(...)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('requests')  -- Must be in tuple format
```

### Issue 3: Network Connectivity from Snowflake

**Error Message:**
```
HTTP request failed: Connection timeout
```

**Diagnostic:**
```sql
-- Test simple HTTP call
SELECT reporting.generate_report_via_ecs(
    'TEST_CONN',
    'SALES_REPORT',
    OBJECT_CONSTRUCT('test', 'connectivity'),
    'connection-test'
);
```

**Common Solutions:**

#### IP Address Changes
- Fargate tasks get dynamic IPs
- Update network rules when IP changes
- Consider using Application Load Balancer for stable endpoint

#### Firewall Issues
- Snowflake may have outbound restrictions
- Contact Snowflake support for network allowlisting

---

## Application Runtime Errors

### Issue 1: Snowflake Connector Errors

**Error Message:**
```
snowflake.connector.errors.DatabaseError: 250001 (08001): Failed to connect
```

**Diagnostic in Container:**
```python
# Test connection parameters
import snowflake.connector
import os

try:
    conn = snowflake.connector.connect(
        user=os.environ['SNOWFLAKE_USER'],
        password=os.environ['SNOWFLAKE_PASSWORD'],
        account=os.environ['SNOWFLAKE_ACCOUNT'],
        warehouse=os.environ['SNOWFLAKE_WAREHOUSE'],
        database=os.environ['SNOWFLAKE_DATABASE']
    )
    print("Connection successful")
except Exception as e:
    print(f"Connection failed: {e}")
```

**Common Solutions:**

#### Credential Issues
```bash
# Check if secrets are properly loaded
aws ecs execute-command --cluster snowflake-analytics-cluster \
  --task <task-id> --container report-service \
  --interactive --command "env | grep SNOWFLAKE"
```

#### Account Format Issues
- Ensure account format: `ORGNAME-ACCOUNT_NAME`
- Check for extra characters or spaces

### Issue 2: FastAPI Startup Errors

**Error Message:**
```
uvicorn.error: Error loading ASGI app
```

**Diagnostic:**
```bash
# Check application logs
aws logs get-log-events \
  --log-group-name /ecs/snowflake-report-service \
  --log-stream-name ecs/report-service/<task-id>

# Test application locally
docker run -it snowflake-report-service:latest python -c "import app; print('OK')"
```

**Common Causes:**
- Missing environment variables
- Import errors in application code
- Port binding issues

### Issue 3: Memory/CPU Exhaustion

**Symptoms:**
- Tasks frequently restarting
- Slow response times
- OOM (Out of Memory) errors

**Diagnostic:**
```bash
# Check resource utilization
aws ecs describe-tasks \
  --cluster snowflake-analytics-cluster \
  --tasks <task-id> \
  --include TAGS

# Monitor CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=snowflake-report-service \
  --start-time 2024-08-03T00:00:00Z \
  --end-time 2024-08-03T23:59:59Z \
  --period 300 \
  --statistics Average
```

**Solutions:**
- Increase CPU/memory allocation in task definition
- Optimize application code for memory usage
- Implement connection pooling for database connections

---

## Performance and Scaling Issues

### Issue 1: Slow Response Times

**Diagnostic Tools:**
```bash
# Test API response times
time curl http://<task-ip>:8000/health

# Check application metrics
curl http://<task-ip>:8000/metrics

# Monitor database connection pool
```

**Optimization Strategies:**

#### Database Connection Pooling
```python
# In application code
from snowflake.connector.pooling import PooledConnectionManager

pool_manager = PooledConnectionManager(
    pool_size=5,
    max_overflow=10,
    timeout=30,
    **connection_params
)
```

#### Async Processing
```python
# Use FastAPI background tasks
from fastapi import BackgroundTasks

@app.post("/process-job")
async def process_job(job: JobRequest, background_tasks: BackgroundTasks):
    background_tasks.add_task(process_job_async, job)
    return {"status": "accepted", "job_id": job.job_id}
```

### Issue 2: Auto-Scaling Configuration

**Problem:** Service doesn't scale under load

**Solution - Configure Auto Scaling:**
```bash
# Create auto-scaling target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/snowflake-analytics-cluster/snowflake-report-service \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 1 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --policy-name cpu-scaling-policy \
  --service-namespace ecs \
  --resource-id service/snowflake-analytics-cluster/snowflake-report-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{
    "TargetValue": 70.0,
    "PredefinedMetricSpecification": {
      "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
    }
  }'
```

---

## Monitoring and Logging Problems

### Issue 1: Missing Application Logs

**Problem:** Can't find logs in CloudWatch

**Diagnostic:**
```bash
# Check log group exists
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/snowflake-report-service

# Check task definition log configuration
aws ecs describe-task-definition \
  --task-definition snowflake-report-service \
  --query 'taskDefinition.containerDefinitions[0].logConfiguration'
```

**Solution:**
```json
{
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/snowflake-report-service",
      "awslogs-region": "us-east-1",
      "awslogs-stream-prefix": "ecs"
    }
  }
}
```

### Issue 2: Insufficient Log Detail

**Problem:** Logs don't contain enough information for debugging

**Solution - Enhanced Logging:**
```python
# In application code
import logging
import sys

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(name)s %(message)s',
    stream=sys.stdout
)

# Add request logging middleware
from fastapi import Request
import time

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    logger.info(f"{request.method} {request.url.path} {response.status_code} {process_time:.3f}s")
    return response
```

### Issue 3: Monitoring Dashboard Setup

**Create CloudWatch Dashboard:**
```bash
aws cloudwatch put-dashboard \
  --dashboard-name SnowflakeReportService \
  --dashboard-body '{
    "widgets": [
      {
        "type": "metric",
        "properties": {
          "metrics": [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "snowflake-report-service"],
            [".", "MemoryUtilization", ".", "."]
          ],
          "period": 300,
          "stat": "Average",
          "region": "us-east-1",
          "title": "ECS Service Metrics"
        }
      }
    ]
  }'
```

---

## Cost Optimization Issues

### Issue 1: Unexpected High Costs

**Diagnostic Commands:**
```bash
# Check running tasks
aws ecs list-tasks --cluster snowflake-analytics-cluster

# Review service configuration
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services snowflake-report-service

# Check cost allocation tags
aws resourcegroupstaggingapi get-resources \
  --resource-type-filters ECS
```

**Cost Optimization Strategies:**

#### Right-Size Resources
```bash
# Monitor resource utilization
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=snowflake-report-service \
  --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 3600 \
  --statistics Average,Maximum
```

#### Use Fargate Spot
```json
{
  "capacityProviders": ["FARGATE", "FARGATE_SPOT"],
  "defaultCapacityProviderStrategy": [
    {
      "capacityProvider": "FARGATE_SPOT",
      "weight": 1,
      "base": 0
    }
  ]
}
```

#### Implement Auto-Shutdown
```python
# Scheduled shutdown for development environments
import boto3
from datetime import datetime, time

def lambda_handler(event, context):
    ecs = boto3.client('ecs')
    
    # Scale down during non-business hours
    current_time = datetime.now().time()
    if time(18, 0) <= current_time or current_time <= time(8, 0):
        ecs.update_service(
            cluster='snowflake-analytics-cluster',
            service='snowflake-report-service',
            desiredCount=0
        )
```

---

## Emergency Recovery Procedures

### Complete Service Recovery

**If service is completely down:**

1. **Check Service Status:**
```bash
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services snowflake-report-service
```

2. **Scale Up Service:**
```bash
aws ecs update-service \
  --cluster snowflake-analytics-cluster \
  --service snowflake-report-service \
  --desired-count 2
```

3. **Force New Deployment:**
```bash
aws ecs update-service \
  --cluster snowflake-analytics-cluster \
  --service snowflake-report-service \
  --force-new-deployment
```

4. **Rollback to Previous Version:**
```bash
# List task definition revisions
aws ecs list-task-definitions --family-prefix snowflake-report-service

# Update to previous version
aws ecs update-service \
  --cluster snowflake-analytics-cluster \
  --service snowflake-report-service \
  --task-definition snowflake-report-service:PREVIOUS_REVISION
```

### Data Recovery

**If reports are lost:**

1. **Check S3 Bucket:**
```bash
aws s3 ls s3://snowflake-reports-bucket-prod-203977009513/ --recursive
```

2. **Regenerate Reports:**
```sql
-- In Snowflake
CALL reporting.generate_daily_reports();
```

3. **Check Backup Sources:**
```bash
# Check CloudWatch logs for job history
aws logs filter-log-events \
  --log-group-name /ecs/snowflake-report-service \
  --filter-pattern "job_id"
```

This troubleshooting guide covers the most common issues encountered during deployment and operation of the Snowflake Report Service on AWS ECS. For issues not covered here, check AWS CloudTrail for detailed API call logs and consider enabling AWS X-Ray for distributed tracing.