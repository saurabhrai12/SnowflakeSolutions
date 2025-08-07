# Quick Reference - AWS ECS Snowflake Integration

## Emergency Commands

### Check Service Health
```bash
# Service status
aws ecs describe-services --cluster snowflake-analytics-cluster --services snowflake-report-service --query 'services[0].[serviceName,status,runningCount,desiredCount]' --output table

# Application health
curl http://54.88.92.124:8000/health

# Task status
aws ecs list-tasks --cluster snowflake-analytics-cluster --service-name snowflake-report-service
```

### Scale Service
```bash
# Scale up
aws ecs update-service --cluster snowflake-analytics-cluster --service snowflake-report-service --desired-count 2

# Scale down
aws ecs update-service --cluster snowflake-analytics-cluster --service snowflake-report-service --desired-count 0
```

### Force Restart
```bash
aws ecs update-service --cluster snowflake-analytics-cluster --service snowflake-report-service --force-new-deployment
```

## Deployment Commands

### Build and Push Image
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 203977009513.dkr.ecr.us-east-1.amazonaws.com

# Build for AMD64
docker build --platform linux/amd64 -t snowflake-report-service:latest .

# Tag and push
docker tag snowflake-report-service:latest 203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
docker push 203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
```

### Update Task Definition
```bash
aws ecs register-task-definition --cli-input-json file://aws-infrastructure/ecs-task-definitions/report-service-task.json
```

## Monitoring Commands

### View Logs
```bash
# List log streams
aws logs describe-log-streams --log-group-name /ecs/snowflake-report-service

# Get recent logs
aws logs get-log-events --log-group-name /ecs/snowflake-report-service --log-stream-name ecs/report-service/[TASK-ID] --start-time $(date -d '1 hour ago' +%s)000
```

### Check Metrics
```bash
# CPU utilization
aws cloudwatch get-metric-statistics --namespace AWS/ECS --metric-name CPUUtilization --dimensions Name=ServiceName,Value=snowflake-report-service --start-time $(date -d '1 hour ago' -u +%Y-%m-%dT%H:%M:%SZ) --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) --period 300 --statistics Average

# Service metrics via API
curl http://54.88.92.124:8000/metrics
```

## Snowflake Integration

### Test External Function
```sql
-- Test connectivity
SELECT reporting.generate_report_via_ecs(
    'TEST_' || REPLACE(UUID_STRING(), '-', '_'),
    'SALES_REPORT',
    OBJECT_CONSTRUCT('start_date', '2024-01-01', 'end_date', '2024-01-31'),
    'snowflake-test'
);

-- Check task status
SHOW TASKS IN SCHEMA reporting;

-- Manual task execution
EXECUTE TASK reporting.daily_reports_task;
```

## Troubleshooting

### Get Task IP Address
```bash
# Get task ID
TASK_ID=$(aws ecs list-tasks --cluster snowflake-analytics-cluster --service-name snowflake-report-service --query 'taskArns[0]' --output text | cut -d'/' -f3)

# Get network interface
ENI_ID=$(aws ecs describe-tasks --cluster snowflake-analytics-cluster --tasks $TASK_ID --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)

# Get public IP
aws ec2 describe-network-interfaces --network-interface-ids $ENI_ID --query 'NetworkInterfaces[0].Association.PublicIp' --output text
```

### Common Test Commands
```bash
# Health check
curl -f http://[TASK-IP]:8000/health

# API documentation
curl http://[TASK-IP]:8000/docs

# Test job processing
curl -X POST "http://[TASK-IP]:8000/process-job" -H "Content-Type: application/json" -d '{"job_id":"TEST","job_type":"SALES_REPORT","input_data":{"test":"data"},"timestamp":"2024-08-03T14:30:00Z","source":"test"}'

# Check job status
curl "http://[TASK-IP]:8000/job/TEST/status"
```

## AWS Resource ARNs

### ECR Repository
```
203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service
```

### ECS Resources
```
Cluster: arn:aws:ecs:us-east-1:203977009513:cluster/snowflake-analytics-cluster
Service: arn:aws:ecs:us-east-1:203977009513:service/snowflake-analytics-cluster/snowflake-report-service
Task Definition: arn:aws:ecs:us-east-1:203977009513:task-definition/snowflake-report-service
```

### Secrets Manager
```
Account: arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/account-qwS5Xr
User: arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/user-VCf0AZ
Password: arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/password-5lgORr
Database: arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/database-HAJmi9
Warehouse: arn:aws:secretsmanager:us-east-1:203977009513:secret:snowflake/warehouse-YDBeGW
```

### IAM Roles
```
Execution Role: arn:aws:iam::203977009513:role/ecsTaskExecutionRole
Task Role: arn:aws:iam::203977009513:role/snowflake-report-service-task-role
```

## Network Configuration

### Subnets (Multi-AZ)
```
us-east-1a: subnet-0c8ae010a9215f951
us-east-1b: subnet-0535fa2e0264d0701
```

### Security Group
```
snowflake-report-service-sg: sg-0472eb521ab57d29c
```

## Emergency Contacts

### AWS Support
- Console: https://console.aws.amazon.com/support/
- CLI: `aws support describe-cases`

### Snowflake Support  
- Console: https://app.snowflake.com/support
- Phone: Available through console

## Status Page URLs

### AWS Service Health
- https://status.aws.amazon.com/

### Snowflake Status
- https://status.snowflake.com/

## Configuration Files

### Task Definition
```
/aws-infrastructure/ecs-task-definitions/report-service-task.json
```

### Service Configuration  
```
/aws-infrastructure/ecs-services/report-service.json
```

### Snowflake Integration
```
/sql/snowflake_ecs_integration.sql
/sql/snowflake_tasks.sql
/sql/test_ecs_integration.sql
```

## Current Deployment Status

### Production Environment
- **Region**: us-east-1
- **Account**: 203977009513  
- **Service IP**: 54.88.92.124:8000
- **Desired Count**: 1
- **CPU/Memory**: 512 CPU / 1024 MB
- **Image**: latest (AMD64)
- **Health Status**: ✅ Healthy

### Snowflake Integration
- **Network Rule**: ecs_report_service_rule ✅
- **Integration**: ecs_report_integration ✅  
- **Functions**: reporting.generate_report_via_ecs ✅
- **Tasks**: daily_reports_task (Active) ✅

### Last Updated
```
Date: 2024-08-03
Version: 1.0.0
Deployment: Production
```