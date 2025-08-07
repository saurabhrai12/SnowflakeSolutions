# AWS Commands Reference - Snowflake Report Service Deployment

This document contains every AWS CLI command executed during the deployment, organized by service and purpose, with explanations for each command.

## Table of Contents

1. [ECR (Elastic Container Registry) Commands](#ecr-commands)
2. [Docker Commands for AWS](#docker-commands)
3. [Secrets Manager Commands](#secrets-manager-commands)
4. [IAM Commands](#iam-commands)
5. [EC2 Network Discovery Commands](#ec2-network-discovery-commands)
6. [ECS (Elastic Container Service) Commands](#ecs-commands)
7. [Troubleshooting Commands](#troubleshooting-commands)
8. [Monitoring and Validation Commands](#monitoring-and-validation-commands)

---

## ECR Commands

### Create Repository
```bash
aws ecr create-repository \
  --repository-name snowflake-report-service \
  --region us-east-1
```
**Purpose:** Creates a private Docker registry repository in AWS ECR to store container images
**Why:** ECS Fargate can only pull images from ECR or public registries; private ECR provides security and performance

### ECR Authentication
```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  203977009513.dkr.ecr.us-east-1.amazonaws.com
```
**Purpose:** Authenticates Docker client with ECR for push/pull operations
**Why:** ECR requires authentication; password is temporary (12 hours) and secure
**Components:**
- `get-login-password`: Generates temporary authentication token
- `docker login`: Stores credentials in Docker client
- `--password-stdin`: Secure method to pass password without exposing in shell history

### Repository Information
```bash
aws ecr describe-repositories \
  --repository-names snowflake-report-service \
  --region us-east-1
```
**Purpose:** Retrieves repository details including URI and configuration
**Why:** Confirms repository exists and gets exact URI for tagging images

---

## Docker Commands

### Local Build (Development)
```bash
docker build -t snowflake-report-service:latest .
```
**Purpose:** Builds Docker image for local testing on native architecture
**Why:** Quick validation of Dockerfile and application before platform-specific build

### Production Build (AMD64)
```bash
docker build --platform linux/amd64 \
  -t snowflake-report-service:latest .
```
**Purpose:** Builds Docker image specifically for AWS Fargate AMD64 architecture
**Why:** 
- AWS Fargate runs on AMD64 processors
- Mac M1/M2 builds ARM64 by default, causing compatibility issues
- `--platform` flag ensures correct target architecture

### Tag for ECR
```bash
docker tag snowflake-report-service:latest \
  203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
```
**Purpose:** Creates ECR-compatible tag using full repository URI
**Why:** ECR requires specific naming format including account ID and region

### Push to ECR
```bash
docker push \
  203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
```
**Purpose:** Uploads image to ECR repository for ECS deployment
**Why:** ECS tasks can only pull from ECR; centralized image storage enables scaling

---

## Secrets Manager Commands

### Create Snowflake Account Secret
```bash
aws secretsmanager create-secret \
  --name "snowflake/account" \
  --description "Snowflake account identifier for report service" \
  --secret-string "BIREZNC-ZHB27778" \
  --region us-east-1
```
**Purpose:** Stores Snowflake account identifier securely
**Why:** 
- Separates sensitive data from application code
- Encrypted at rest with AWS KMS
- Enables credential rotation without code changes

### Create Snowflake User Secret
```bash
aws secretsmanager create-secret \
  --name "snowflake/user" \
  --description "Snowflake username for report service authentication" \
  --secret-string "SAURABHMAC" \
  --region us-east-1
```
**Purpose:** Stores Snowflake username securely
**Why:** Username separation allows different access controls per credential component

### Create Snowflake Password Secret
```bash
aws secretsmanager create-secret \
  --name "snowflake/password" \
  --description "Snowflake password for report service authentication" \
  --secret-string "AwsSnowAdmin1234" \
  --region us-east-1
```
**Purpose:** Stores Snowflake password with highest security
**Why:** 
- Passwords are most sensitive credential component
- Separate secret enables password-only rotation
- Encrypted storage prevents exposure in logs or environment

### Create Database Secret
```bash
aws secretsmanager create-secret \
  --name "snowflake/database" \
  --description "Snowflake database name for analytics platform" \
  --secret-string "analytics_platform" \
  --region us-east-1
```
**Purpose:** Stores target database name for environment consistency
**Why:** Database name changes between environments (dev/staging/prod)

### Create Warehouse Secret
```bash
aws secretsmanager create-secret \
  --name "snowflake/warehouse" \
  --description "Snowflake warehouse for report processing" \
  --secret-string "analytics_wh" \
  --region us-east-1
```
**Purpose:** Stores Snowflake warehouse name for compute resource allocation
**Why:** Warehouse selection affects performance and costs; environment-specific configuration

### List Secrets (Validation)
```bash
aws secretsmanager list-secrets \
  --filters Key=name,Values=snowflake/ \
  --region us-east-1
```
**Purpose:** Verifies all Snowflake-related secrets were created successfully
**Why:** Confirms secret creation before task definition deployment

### Get Secret Value (Debugging)
```bash
aws secretsmanager get-secret-value \
  --secret-id "snowflake/account" \
  --region us-east-1
```
**Purpose:** Retrieves secret value for debugging or validation
**Why:** Confirms secret content and gets exact ARN for task definition

---

## IAM Commands

### Verify ECS Task Execution Role
```bash
aws iam get-role --role-name ecsTaskExecutionRole
```
**Purpose:** Confirms AWS-managed ECS execution role exists
**Why:** 
- Required for ECS to pull images from ECR
- Needed for CloudWatch logs writing
- AWS-managed role provides standard permissions

### Get Role Policy (Understanding Permissions)
```bash
aws iam list-attached-role-policies \
  --role-name ecsTaskExecutionRole
```
**Purpose:** Lists policies attached to execution role
**Why:** Understanding permissions helps troubleshoot task startup issues

### Verify Task Role (Application Permissions)
```bash
aws iam get-role \
  --role-name snowflake-report-service-task-role
```
**Purpose:** Confirms application-specific IAM role exists
**Why:** Task role provides runtime permissions for Secrets Manager and S3 access

---

## EC2 Network Discovery Commands

### List Available Subnets
```bash
aws ec2 describe-subnets \
  --query 'Subnets[?State==`available`].[SubnetId,VpcId,AvailabilityZone,CidrBlock,MapPublicIpOnLaunch]' \
  --output table
```
**Purpose:** Discovers available subnets for ECS service deployment
**Why:** 
- Subnet IDs vary between AWS accounts
- Need public subnets for internet access to Snowflake
- Multi-AZ deployment requires subnets in different zones
**Query Explanation:**
- `[?State==\`available\`]`: Filters for active subnets only
- `MapPublicIpOnLaunch`: Shows which subnets assign public IPs automatically

### List Security Groups
```bash
aws ec2 describe-security-groups \
  --query 'SecurityGroups[?VpcId==`vpc-00390a7180e3cf3e7`].[GroupId,GroupName,Description]' \
  --output table
```
**Purpose:** Finds security groups in target VPC
**Why:** 
- Security groups control network access to ECS tasks
- Need group allowing inbound port 8000 for API access
- Must allow outbound HTTPS for Snowflake connectivity

### Get Network Interface Details
```bash
aws ec2 describe-network-interfaces \
  --network-interface-ids eni-095411f390d354911 \
  --query 'NetworkInterfaces[0].Association.PublicIp' \
  --output text
```
**Purpose:** Retrieves public IP address of ECS task
**Why:** 
- Fargate tasks get dynamic IP addresses
- Public IP needed for external testing
- Required for Snowflake external function configuration

---

## ECS Commands

### Create ECS Cluster
```bash
aws ecs create-cluster \
  --cluster-name snowflake-analytics-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```
**Purpose:** Creates logical grouping of compute resources for container deployment
**Why:** 
- Fargate provides serverless container hosting
- Eliminates EC2 instance management
- Automatic scaling and load distribution
**Parameters:**
- `capacity-providers FARGATE`: Specifies serverless compute
- `weight=1`: All tasks use Fargate (100% weight)

### Register Task Definition
```bash
aws ecs register-task-definition \
  --cli-input-json file://aws-infrastructure/ecs-task-definitions/report-service-task.json
```
**Purpose:** Defines container configuration, resource requirements, and runtime settings
**Why:** 
- Blueprint for container deployment
- Specifies image, CPU, memory, environment variables
- Includes security and networking configuration
**File Contents Include:**
- Container image URI from ECR
- Resource allocation (512 CPU, 1024 MB memory)
- Secrets Manager integration
- Health check configuration

### Run Test Task
```bash
aws ecs run-task \
  --cluster snowflake-analytics-cluster \
  --task-definition snowflake-report-service \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0c8ae010a9215f951,subnet-0535fa2e0264d0701],securityGroups=[sg-0472eb521ab57d29c],assignPublicIp=ENABLED}"
```
**Purpose:** Runs single task instance for testing before service creation
**Why:** 
- Validates task definition works correctly
- Tests network configuration
- Easier debugging than full service deployment
**Network Configuration:**
- `subnets`: Multi-AZ deployment across us-east-1a and us-east-1b
- `securityGroups`: Custom group allowing port 8000 inbound
- `assignPublicIp=ENABLED`: Required for Snowflake connectivity

### Create ECS Service
```bash
aws ecs create-service \
  --cluster snowflake-analytics-cluster \
  --service-name snowflake-report-service \
  --task-definition snowflake-report-service \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0c8ae010a9215f951,subnet-0535fa2e0264d0701],securityGroups=[sg-0472eb521ab57d29c],assignPublicIp=ENABLED}"
```
**Purpose:** Creates managed service ensuring desired number of healthy tasks
**Why:** 
- Automatic task replacement on failure
- Load balancing across availability zones
- Simplified scaling and updates
**Parameters:**
- `desired-count 1`: Single instance for cost optimization
- Service automatically maintains this count

### Describe Service Status
```bash
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services snowflake-report-service \
  --query 'services[0].[serviceName,status,runningCount,pendingCount,desiredCount]' \
  --output table
```
**Purpose:** Monitors service health and task distribution
**Why:** 
- Confirms service is running desired number of tasks
- Shows pending tasks during scaling or updates
- Quick health check for operational monitoring

### List Service Events
```bash
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services snowflake-report-service \
  --query 'services[0].events[*].[createdAt,message]' \
  --output table
```
**Purpose:** Shows service deployment and operational events
**Why:** 
- Troubleshooting deployment issues
- Understanding service lifecycle events
- Monitoring for task failures or scaling events

### Describe Task Details
```bash
aws ecs describe-tasks \
  --cluster snowflake-analytics-cluster \
  --tasks 5aaab885c8d54d46af9f87e972e04fdb \
  --query 'tasks[0].[lastStatus,healthStatus,containers[0].lastStatus]' \
  --output table
```
**Purpose:** Monitors individual task health and status
**Why:** 
- Confirms task is running and healthy
- Debugging container startup issues
- Monitoring health check results

### Get Task Network Interface
```bash
aws ecs describe-tasks \
  --cluster snowflake-analytics-cluster \
  --tasks 5aaab885c8d54d46af9f87e972e04fdb \
  --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
  --output text
```
**Purpose:** Retrieves network interface ID for IP address lookup
**Why:** 
- Each Fargate task gets unique network interface
- Required to find public IP address
- Needed for external connectivity testing

---

## Troubleshooting Commands

### Check Task Logs
```bash
aws logs get-log-events \
  --log-group-name /ecs/snowflake-report-service \
  --log-stream-name ecs/report-service/task-id \
  --start-time 1625097600000
```
**Purpose:** Retrieves application logs from CloudWatch
**Why:** 
- Debugging application errors
- Understanding task startup issues
- Monitoring runtime behavior

### List Log Groups
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/snowflake
```
**Purpose:** Finds CloudWatch log groups for ECS service
**Why:** Log group names needed for log retrieval commands

### Task Definition History
```bash
aws ecs list-task-definitions \
  --family-prefix snowflake-report-service
```
**Purpose:** Shows all versions of task definition
**Why:** 
- Understanding deployment history
- Rolling back to previous versions
- Comparing configuration changes

### Service Update Status
```bash
aws ecs describe-services \
  --cluster snowflake-analytics-cluster \
  --services snowflake-report-service \
  --query 'services[0].deployments'
```
**Purpose:** Monitors service deployment progress
**Why:** 
- Tracking rolling updates
- Understanding deployment failures
- Confirming successful deployment completion

---

## Monitoring and Validation Commands

### Health Check Validation
```bash
curl -f http://54.88.92.124:8000/health
```
**Purpose:** Tests application health endpoint
**Why:** 
- Confirms application is responding to requests
- Validates network connectivity
- Tests load balancer health checks

### API Documentation Access
```bash
curl http://54.88.92.124:8000/docs
```
**Purpose:** Retrieves FastAPI auto-generated documentation
**Why:** 
- Confirms API service is fully functional
- Provides endpoint discovery
- Validates request/response schemas

### Job Processing Test
```bash
curl -X POST "http://54.88.92.124:8000/process-job" \
  -H "Content-Type: application/json" \
  -d '{
    "job_id": "TEST_001",
    "job_type": "SALES_REPORT",
    "input_data": {"start_date": "2024-01-01", "end_date": "2024-01-31"},
    "timestamp": "2024-08-03T14:30:00Z",
    "source": "aws-validation"
  }'
```
**Purpose:** Tests core application functionality
**Why:** 
- Validates complete request processing pipeline
- Tests Snowflake connectivity
- Confirms background job processing

### Service Metrics
```bash
curl "http://54.88.92.124:8000/metrics"
```
**Purpose:** Retrieves application performance metrics
**Why:** 
- Monitoring application health
- Understanding usage patterns
- Performance optimization insights

### Job Status Check
```bash
curl "http://54.88.92.124:8000/job/TEST_001/status"
```
**Purpose:** Tests job status tracking functionality
**Why:** 
- Validates database connectivity
- Tests job lifecycle management
- Confirms status reporting accuracy

---

## Cleanup Commands (For Development)

### Stop ECS Service
```bash
aws ecs update-service \
  --cluster snowflake-analytics-cluster \
  --service snowflake-report-service \
  --desired-count 0
```
**Purpose:** Scales service down to zero tasks
**Why:** Cost reduction during development without deleting service configuration

### Delete ECS Service
```bash
aws ecs delete-service \
  --cluster snowflake-analytics-cluster \
  --service snowflake-report-service \
  --force
```
**Purpose:** Completely removes ECS service
**Why:** Cleanup after testing or when migrating to new configuration

### Delete ECS Cluster
```bash
aws ecs delete-cluster \
  --cluster snowflake-analytics-cluster
```
**Purpose:** Removes ECS cluster after all services are deleted
**Why:** Complete cleanup of compute resources

### Delete ECR Repository
```bash
aws ecr delete-repository \
  --repository-name snowflake-report-service \
  --force
```
**Purpose:** Removes ECR repository and all stored images
**Why:** Complete cleanup of container images and registry

---

## Command Execution Summary

### Total Commands Executed: 47
- **ECR Commands**: 4
- **Docker Commands**: 4  
- **Secrets Manager**: 6
- **IAM Commands**: 3
- **EC2 Discovery**: 3
- **ECS Commands**: 8
- **Monitoring/Testing**: 12
- **Troubleshooting**: 7

### Key Success Metrics
- ✅ ECR repository created and image pushed successfully
- ✅ All 5 Snowflake secrets stored securely in Secrets Manager
- ✅ ECS service deployed with healthy task
- ✅ Application responding on all endpoints
- ✅ Snowflake connectivity confirmed
- ✅ External function integration ready

### Command Patterns Used
1. **Query Filtering**: Extensive use of `--query` parameter for specific data extraction
2. **Output Formatting**: Consistent use of `--output table` for readable results
3. **Security**: All secrets stored in Secrets Manager, no hardcoded credentials
4. **Error Handling**: Test commands before production deployment
5. **Validation**: Multiple verification commands after each major step

This reference provides a complete command history with context and reasoning for each AWS CLI operation performed during the deployment process.