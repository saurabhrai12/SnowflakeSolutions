# Snowflake Report Service

AWS ECS Fargate Python Report Generation Service for Snowflake Analytics Platform.

## Features

- FastAPI-based REST API for report generation
- Multiple report types: Sales, Customer Analysis, Product Performance, Executive Dashboard, Data Quality
- Snowflake integration for data queries
- S3 integration for report storage
- Background job processing
- Health checks and metrics endpoints

## Local Development

### Prerequisites
- Docker
- Snowflake account credentials
- AWS credentials (optional for S3 integration)

### Environment Setup

1. Copy the environment template:
   ```bash
   cp ../.env.template .env
   ```

2. Fill in your Snowflake credentials in `.env`

3. Build and run with Docker:
   ```bash
   docker build -t snowflake-report-service .
   docker run -p 8000:8000 --env-file .env snowflake-report-service
   ```

## API Endpoints

- `GET /health` - Health check
- `POST /process-job` - Process report generation job
- `GET /job/{job_id}/status` - Get job status
- `GET /metrics` - Service metrics

## Report Types

- **SALES_REPORT**: Sales performance analytics
- **CUSTOMER_ANALYSIS**: Customer segmentation and LTV analysis
- **PRODUCT_PERFORMANCE**: Product sales and inventory metrics
- **EXECUTIVE_DASHBOARD**: High-level business metrics
- **DATA_QUALITY**: Data quality checks and validation