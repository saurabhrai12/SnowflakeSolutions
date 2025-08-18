# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a modern cloud-native analytics platform built around Snowflake as the core data warehouse. It includes automated report generation, natural language querying via Snowflake Cortex Analyst, real-time data pipelines, and container-based microservices deployed on AWS ECS Fargate. The platform features seamless integration between Snowflake external functions and AWS ECS services for scalable report processing.

## Technology Stack

- **Database**: Snowflake (primary data warehouse)
- **Cloud Platform**: AWS (ECS Fargate, ECR, S3, ALB)
- **Languages**: Python 3.11+, SQL
- **Package Manager**: UV (modern Python package manager)
- **Backend**: FastAPI (report service), Streamlit (analytics UI)
- **Infrastructure**: Docker, Docker Compose, AWS ECS, Traefik

## Key Architecture Components

### Database Layer (Snowflake)
Four-schema architecture:
- `raw_data`: Source data with streams for CDC
- `processed_data`: Transformed analytics tables  
- `monitoring`: System health and job tracking
- `reporting`: Views and dashboards

Key patterns:
- CREATE OR ALTER statements for idempotent deployments
- Snowflake streams for change data capture
- Automated tasks for data pipeline orchestration

### Application Services
- **Report Service** (`python-report-service/`): FastAPI REST API with async background job processing
- **Analytics UI** (`streamlit-app/`): Streamlit interface with Cortex Analyst integration
- **Infrastructure** (`aws-infrastructure/`): ECS deployment configurations
  - **Terraform** (`streamlit-ecs/terraform/`): Modern Infrastructure as Code (recommended)
  - **CloudFormation** (`streamlit-ecs/`): Legacy AWS-native deployment

## Development Commands

### Local Development Environment
```bash
# Start all services locally
cd aws-infrastructure
docker-compose up -d

# Services available at:
# - Report Service: http://localhost:8000
# - Streamlit App: http://localhost:8501  
# - Traefik Dashboard: http://localhost:8080
```

### Python Service Development
```bash
# Report Service
cd python-report-service
uv venv && source .venv/bin/activate
uv pip install --dev .
uv run pytest                    # Run tests
uv run uvicorn app:app --reload  # Local development

# Streamlit App  
cd streamlit-app
uv venv && source .venv/bin/activate
uv pip install --dev .
uv run streamlit run app.py      # Local development
```

### Database Development
```bash
# Deploy schemas in dependency order (see sql/deploy_order.md)
cd sql
snowsql -f schemas/00_database_and_warehouse.sql
snowsql -f schemas/raw_data/tables.sql
# Continue per deploy_order.md
```

### Testing
```bash
# Run tests for either service
uv run pytest                    # All tests
uv run pytest tests/test_*.py    # Specific test file
uv run pytest --cov             # With coverage
```

### Code Quality
```bash
# Both services use these tools (configured in pyproject.toml)
uv run black .                   # Format code
uv run isort .                   # Sort imports  
uv run flake8                    # Linting
uv run mypy .                    # Type checking
uv run bandit -r .               # Security analysis
```

## Important Patterns and Conventions

### Development Workflow
- Single branch strategy with CI/CD gates
- Mono-repo structure with independent service deployments
- Git diff-based intelligent deployment (only deploys changed components)
- Container-first development and deployment

### Database Conventions
- All SQL uses CREATE OR ALTER for idempotent deployments
- Schema deployment follows dependency order in `sql/deploy_order.md`
- Comprehensive monitoring tables in `monitoring` schema
- Stream-based change data capture patterns

### Code Quality
- Python: PEP 8 compliance, type hints required
- Docker: Multi-stage builds with non-root users
- No hardcoded credentials (use environment variables)
- Comprehensive error handling and logging

### Environment Variables Required
```bash
# Snowflake
SNOWFLAKE_ACCOUNT=your-account
SNOWFLAKE_USER=your-user  
SNOWFLAKE_PASSWORD=your-password
SNOWFLAKE_DATABASE=analytics_platform
SNOWFLAKE_WAREHOUSE=analytics_wh

# AWS
AWS_REGION=us-east-1
S3_REPORTS_BUCKET=your-reports-bucket
```

## CI/CD Pipeline

Jenkins pipeline (`jenkins/`) provides intelligent deployment:
- Detects changes via git diff analysis
- Deploys only modified components
- Parallel deployment of independent services
- Comprehensive validation and testing

## AWS ECS Production Deployment

### ECS Service Details
- **Service Name**: snowflake-report-service  
- **Cluster**: snowflake-analytics-cluster
- **Launch Type**: Fargate (serverless containers)
- **Image**: 203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
- **Public IP**: 54.88.92.124:8000 (for testing)

### AWS Resources Created
```bash
# ECR Repository
aws ecr describe-repositories --repository-names snowflake-report-service

# ECS Service  
aws ecs describe-services --cluster snowflake-analytics-cluster --services snowflake-report-service

# Secrets Manager (Snowflake credentials)
aws secretsmanager list-secrets --filters Key=name,Values=snowflake/
```

### Snowflake-ECS Integration

The platform integrates Snowflake external functions with AWS ECS services:

1. **External Functions** (`sql/snowflake_ecs_integration.sql`):
   - `reporting.generate_report_via_ecs()`: Main function to call ECS service
   - `reporting.generate_sales_report_ecs()`: Convenience function for sales reports  
   - `reporting.check_ecs_job_status()`: Monitor job execution

2. **Automated Tasks** (`sql/snowflake_tasks.sql`):
   - Daily reports: 6 AM UTC
   - Weekly executive dashboard: Monday 8 AM UTC
   - Monthly data quality: 1st of month 7 AM UTC

3. **Testing** (`sql/test_ecs_integration.sql`):
   - Comprehensive test suite for all report types
   - Task execution monitoring
   - Performance metrics

### ECS Deployment Commands
```bash
# Build and push AMD64 image
docker build --platform linux/amd64 -t snowflake-report-service:latest .
docker tag snowflake-report-service:latest 203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest
docker push 203977009513.dkr.ecr.us-east-1.amazonaws.com/snowflake-report-service:latest

# Deploy ECS service
aws ecs create-service --cluster snowflake-analytics-cluster \
  --service-name snowflake-report-service \
  --task-definition snowflake-report-service \
  --desired-count 1 --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-0c8ae010a9215f951,subnet-0535fa2e0264d0701],securityGroups=[sg-0472eb521ab57d29c],assignPublicIp=ENABLED}"

# Test service health
curl http://54.88.92.124:8000/health
```

## Testing Framework

- **pytest** with async support for both Python services
- Coverage reporting with HTML and XML output  
- Pre-commit hooks for automated quality checks
- Integration tests with Snowflake connections