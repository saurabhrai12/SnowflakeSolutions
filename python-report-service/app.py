"""
AWS ECS Fargate Python Report Generation Service
Processes jobs from Snowflake and generates reports to S3
"""

import os
import json
import logging
import asyncio
from datetime import datetime, timedelta
from typing import Dict, Any, Optional
import uuid

import boto3
import pandas as pd
import snowflake.connector
from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import uvicorn
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# FastAPI app setup
app = FastAPI(
    title="Snowflake Report Generation Service",
    description="Processes report generation jobs from Snowflake and uploads to S3",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models
class JobRequest(BaseModel):
    job_id: str
    job_type: str
    input_data: Dict[str, Any]
    priority: int = Field(default=3, ge=1, le=5)
    timestamp: str
    source: str
    callback_url: Optional[str] = None

class JobResponse(BaseModel):
    status: str
    job_id: str
    message: str
    tracking_id: str
    estimated_completion: str
    s3_output_location: Optional[str] = None

# Configuration from environment variables
class Config:
    # Snowflake configuration
    SNOWFLAKE_ACCOUNT = os.getenv('SNOWFLAKE_ACCOUNT')
    SNOWFLAKE_USER = os.getenv('SNOWFLAKE_USER')
    SNOWFLAKE_PASSWORD = os.getenv('SNOWFLAKE_PASSWORD')
    SNOWFLAKE_DATABASE = os.getenv('SNOWFLAKE_DATABASE', 'analytics_platform')
    SNOWFLAKE_WAREHOUSE = os.getenv('SNOWFLAKE_WAREHOUSE', 'analytics_wh')
    
    # AWS configuration
    AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
    S3_BUCKET = os.getenv('S3_REPORTS_BUCKET', 'snowflake-reports-bucket')
    
    # Service configuration
    SERVICE_NAME = os.getenv('SERVICE_NAME', 'report-generator')
    ENVIRONMENT = os.getenv('ENVIRONMENT', 'development')

config = Config()

# AWS clients
s3_client = boto3.client('s3', region_name=config.AWS_REGION)
ecs_client = boto3.client('ecs', region_name=config.AWS_REGION)

class SnowflakeConnection:
    """Manages Snowflake database connections"""
    
    def __init__(self):
        self.connection_params = {
            'account': config.SNOWFLAKE_ACCOUNT,
            'user': config.SNOWFLAKE_USER,
            'password': config.SNOWFLAKE_PASSWORD,
            'database': config.SNOWFLAKE_DATABASE,
            'warehouse': config.SNOWFLAKE_WAREHOUSE,
            'schema': 'raw_data'
        }
    
    def get_connection(self):
        """Create new Snowflake connection"""
        try:
            conn = snowflake.connector.connect(**self.connection_params)
            return conn
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise

    def execute_query(self, query: str, params: dict = None) -> pd.DataFrame:
        """Execute query and return results as DataFrame"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(query, params)
            
            # Get column names and data
            columns = [desc[0] for desc in cursor.description]
            data = cursor.fetchall()
            
            return pd.DataFrame(data, columns=columns)
        finally:
            conn.close()

    def update_job_status(self, job_id: str, status: str, output_location: str = None, 
                         error_message: str = None, execution_time: float = None):
        """Update job status in Snowflake"""
        conn = self.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(
                "CALL update_job_status(%s, %s, %s, %s, %s)",
                (job_id, status, output_location, error_message, execution_time)
            )
            conn.commit()
        finally:
            conn.close()

sf_conn = SnowflakeConnection()

class ReportGenerator:
    """Handles different types of report generation"""
    
    def __init__(self):
        self.generators = {
            'SALES_REPORT': self.generate_sales_report,
            'CUSTOMER_ANALYSIS': self.generate_customer_analysis,
            'PRODUCT_PERFORMANCE': self.generate_product_performance,
            'EXECUTIVE_DASHBOARD': self.generate_executive_dashboard,
            'DATA_QUALITY': self.generate_data_quality_report
        }
    
    async def generate_report(self, job_id: str, report_type: str, parameters: dict) -> str:
        """Generate report based on type and parameters"""
        generator = self.generators.get(report_type.upper())
        if not generator:
            raise ValueError(f"Unsupported report type: {report_type}")
        
        return await generator(job_id, parameters)
    
    async def generate_sales_report(self, job_id: str, params: dict) -> str:
        """Generate sales performance report"""
        try:
            # Query sales data
            query = """
            SELECT 
                sales_month,
                total_orders,
                unique_customers,
                total_revenue,
                avg_order_value,
                revenue_growth_pct,
                top_selling_product,
                top_selling_category
            FROM reporting.sales_performance
            WHERE sales_month >= DATEADD('month', -6, CURRENT_DATE())
            ORDER BY sales_month DESC
            """
            
            df = sf_conn.execute_query(query)
            
            # Generate report content
            report_content = self._create_sales_report_content(df, params)
            
            # Upload to S3
            s3_key = f"reports/sales/{job_id}_sales_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            s3_url = await self._upload_to_s3(report_content, s3_key)
            
            return s3_url
            
        except Exception as e:
            logger.error(f"Error generating sales report: {e}")
            raise
    
    async def generate_customer_analysis(self, job_id: str, params: dict) -> str:
        """Generate customer analysis report"""
        try:
            query = """
            SELECT 
                customer_tier,
                COUNT(*) as customer_count,
                AVG(lifetime_value) as avg_ltv,
                AVG(total_orders) as avg_orders,
                SUM(total_spent) as total_revenue,
                customer_status
            FROM reporting.customer_360
            GROUP BY customer_tier, customer_status
            ORDER BY customer_tier, customer_status
            """
            
            df = sf_conn.execute_query(query)
            
            # Generate analysis content
            report_content = self._create_customer_analysis_content(df, params)
            
            # Upload to S3
            s3_key = f"reports/customers/{job_id}_customer_analysis_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            s3_url = await self._upload_to_s3(report_content, s3_key)
            
            return s3_url
            
        except Exception as e:
            logger.error(f"Error generating customer analysis: {e}")
            raise
    
    async def generate_product_performance(self, job_id: str, params: dict) -> str:
        """Generate product performance report"""
        try:
            query = """
            SELECT 
                product_name,
                category,
                total_revenue,
                total_quantity_sold,
                margin_percentage,
                revenue_rank,
                unique_customers,
                last_sale_date
            FROM reporting.product_performance
            WHERE total_revenue > 0
            ORDER BY total_revenue DESC
            LIMIT 50
            """
            
            df = sf_conn.execute_query(query)
            
            # Generate report content
            report_content = self._create_product_performance_content(df, params)
            
            # Upload to S3
            s3_key = f"reports/products/{job_id}_product_performance_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            s3_url = await self._upload_to_s3(report_content, s3_key)
            
            return s3_url
            
        except Exception as e:
            logger.error(f"Error generating product performance report: {e}")
            raise
    
    async def generate_executive_dashboard(self, job_id: str, params: dict) -> str:
        """Generate executive dashboard report"""
        try:
            query = """
            SELECT 
                report_date,
                ytd_revenue,
                last_year_revenue,
                total_active_customers,
                customers_with_orders_ytd,
                active_products,
                products_sold_ytd,
                orders_ytd,
                avg_order_value_ytd,
                jobs_today,
                jobs_completed_today,
                jobs_failed_today
            FROM reporting.executive_dashboard
            """
            
            df = sf_conn.execute_query(query)
            
            # Generate dashboard content
            report_content = self._create_executive_dashboard_content(df, params)
            
            # Upload to S3
            s3_key = f"reports/executive/{job_id}_executive_dashboard_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            s3_url = await self._upload_to_s3(report_content, s3_key)
            
            return s3_url
            
        except Exception as e:
            logger.error(f"Error generating executive dashboard: {e}")
            raise
    
    async def generate_data_quality_report(self, job_id: str, params: dict) -> str:
        """Generate data quality report"""
        try:
            query = """
            SELECT 
                check_name,
                table_name,
                check_type,
                status,
                check_timestamp,
                expected_result,
                actual_result,
                error_details
            FROM monitoring.data_quality_checks
            WHERE check_timestamp >= DATEADD('day', -7, CURRENT_DATE())
            ORDER BY check_timestamp DESC
            """
            
            df = sf_conn.execute_query(query)
            
            # Generate quality report content
            report_content = self._create_data_quality_content(df, params)
            
            # Upload to S3
            s3_key = f"reports/quality/{job_id}_data_quality_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            s3_url = await self._upload_to_s3(report_content, s3_key)
            
            return s3_url
            
        except Exception as e:
            logger.error(f"Error generating data quality report: {e}")
            raise
    
    def _create_sales_report_content(self, df: pd.DataFrame, params: dict) -> dict:
        """Create sales report content structure"""
        return {
            "report_type": "Sales Performance Report",
            "generated_at": datetime.now().isoformat(),
            "parameters": params,
            "summary": {
                "total_months": len(df),
                "latest_revenue": float(df.iloc[0]['TOTAL_REVENUE']) if not df.empty else 0,
                "total_orders_ytd": int(df['TOTAL_ORDERS'].sum()),
                "avg_monthly_revenue": float(df['TOTAL_REVENUE'].mean())
            },
            "data": df.to_dict(orient='records')
        }
    
    def _create_customer_analysis_content(self, df: pd.DataFrame, params: dict) -> dict:
        """Create customer analysis content structure"""
        return {
            "report_type": "Customer Analysis Report",
            "generated_at": datetime.now().isoformat(),
            "parameters": params,
            "summary": {
                "total_customers": int(df['CUSTOMER_COUNT'].sum()),
                "avg_lifetime_value": float(df['AVG_LTV'].mean()),
                "total_revenue": float(df['TOTAL_REVENUE'].sum())
            },
            "data": df.to_dict(orient='records')
        }
    
    def _create_product_performance_content(self, df: pd.DataFrame, params: dict) -> dict:
        """Create product performance content structure"""
        return {
            "report_type": "Product Performance Report",
            "generated_at": datetime.now().isoformat(),
            "parameters": params,
            "summary": {
                "total_products": len(df),
                "top_product": df.iloc[0]['PRODUCT_NAME'] if not df.empty else None,
                "total_revenue": float(df['TOTAL_REVENUE'].sum()),
                "avg_margin": float(df['MARGIN_PERCENTAGE'].mean())
            },
            "data": df.to_dict(orient='records')
        }
    
    def _create_executive_dashboard_content(self, df: pd.DataFrame, params: dict) -> dict:
        """Create executive dashboard content structure"""
        data = df.iloc[0] if not df.empty else {}
        return {
            "report_type": "Executive Dashboard",
            "generated_at": datetime.now().isoformat(),
            "parameters": params,
            "metrics": {
                "ytd_revenue": float(data.get('YTD_REVENUE', 0)),
                "revenue_growth": float(data.get('YTD_REVENUE', 0)) - float(data.get('LAST_YEAR_REVENUE', 0)),
                "active_customers": int(data.get('TOTAL_ACTIVE_CUSTOMERS', 0)),
                "orders_ytd": int(data.get('ORDERS_YTD', 0)),
                "avg_order_value": float(data.get('AVG_ORDER_VALUE_YTD', 0)),
                "jobs_today": int(data.get('JOBS_TODAY', 0)),
                "jobs_success_rate": (int(data.get('JOBS_COMPLETED_TODAY', 0)) / max(int(data.get('JOBS_TODAY', 1)), 1)) * 100
            }
        }
    
    def _create_data_quality_content(self, df: pd.DataFrame, params: dict) -> dict:
        """Create data quality report content structure"""
        return {
            "report_type": "Data Quality Report",
            "generated_at": datetime.now().isoformat(),
            "parameters": params,
            "summary": {
                "total_checks": len(df),
                "passed_checks": len(df[df['STATUS'] == 'PASS']),
                "failed_checks": len(df[df['STATUS'] == 'FAIL']),
                "success_rate": (len(df[df['STATUS'] == 'PASS']) / max(len(df), 1)) * 100
            },
            "data": df.to_dict(orient='records')
        }
    
    async def _upload_to_s3(self, content: dict, s3_key: str) -> str:
        """Upload report content to S3"""
        try:
            # Convert to JSON string
            json_content = json.dumps(content, indent=2, default=str)
            
            # Upload to S3
            s3_client.put_object(
                Bucket=config.S3_BUCKET,
                Key=s3_key,
                Body=json_content.encode('utf-8'),
                ContentType='application/json',
                Metadata={
                    'generated_by': config.SERVICE_NAME,
                    'environment': config.ENVIRONMENT,
                    'timestamp': datetime.now().isoformat()
                }
            )
            
            # Return S3 URL
            s3_url = f"s3://{config.S3_BUCKET}/{s3_key}"
            logger.info(f"Report uploaded to {s3_url}")
            return s3_url
            
        except ClientError as e:
            logger.error(f"Failed to upload to S3: {e}")
            raise

report_generator = ReportGenerator()

# Background task processor
async def process_job_async(job_request: JobRequest):
    """Process job asynchronously"""
    start_time = datetime.now()
    tracking_id = f"ECS_TRACK_{job_request.job_id}_{int(start_time.timestamp())}"
    
    try:
        logger.info(f"Processing job {job_request.job_id} of type {job_request.job_type}")
        
        # Update job status to RUNNING in Snowflake
        sf_conn.update_job_status(job_request.job_id, 'RUNNING')
        
        # Determine report type from input data
        report_type = job_request.input_data.get('report_type', job_request.job_type)
        
        # Generate report
        s3_url = await report_generator.generate_report(
            job_request.job_id,
            report_type,
            job_request.input_data
        )
        
        # Calculate execution time
        execution_time = (datetime.now() - start_time).total_seconds()
        
        # Update job status to COMPLETED
        sf_conn.update_job_status(
            job_request.job_id,
            'COMPLETED',
            output_location=s3_url,
            execution_time=execution_time
        )
        
        logger.info(f"Job {job_request.job_id} completed successfully. Output: {s3_url}")
        
    except Exception as e:
        # Calculate execution time even for failed jobs
        execution_time = (datetime.now() - start_time).total_seconds()
        
        # Update job status to FAILED
        error_message = f"Job processing failed: {str(e)}"
        sf_conn.update_job_status(
            job_request.job_id,
            'FAILED',
            error_message=error_message,
            execution_time=execution_time
        )
        
        logger.error(f"Job {job_request.job_id} failed: {e}")

# API endpoints
@app.get("/health")
async def health_check():
    """Health check endpoint for ECS health checks"""
    return {
        "status": "healthy",
        "service": config.SERVICE_NAME,
        "environment": config.ENVIRONMENT,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/process-job", response_model=JobResponse)
async def process_job(job_request: JobRequest, background_tasks: BackgroundTasks):
    """Process a job request from Snowflake"""
    try:
        # Generate tracking ID
        tracking_id = f"ECS_TRACK_{job_request.job_id}_{int(datetime.now().timestamp())}"
        
        # Add background task for processing
        background_tasks.add_task(process_job_async, job_request)
        
        # Estimate completion time based on job type
        completion_estimates = {
            'REPORT': '5-10 minutes',
            'ANALYSIS': '10-15 minutes',
            'DATA_SYNC': '2-5 minutes'
        }
        estimated_completion = completion_estimates.get(job_request.job_type, '5-10 minutes')
        
        logger.info(f"Job {job_request.job_id} accepted for processing")
        
        return JobResponse(
            status="accepted",
            job_id=job_request.job_id,
            message=f"Job {job_request.job_id} queued for processing",
            tracking_id=tracking_id,
            estimated_completion=estimated_completion
        )
        
    except Exception as e:
        logger.error(f"Failed to accept job {job_request.job_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/job/{job_id}/status")
async def get_job_status(job_id: str):
    """Get job status from Snowflake"""
    try:
        query = "SELECT status, output_location, error_message, execution_time_seconds FROM jobs WHERE job_id = %s"
        df = sf_conn.execute_query(query, {'job_id': job_id})
        
        if df.empty:
            raise HTTPException(status_code=404, detail="Job not found")
        
        job_data = df.iloc[0]
        return {
            "job_id": job_id,
            "status": job_data['STATUS'],
            "output_location": job_data['OUTPUT_LOCATION'],
            "error_message": job_data['ERROR_MESSAGE'],
            "execution_time_seconds": job_data['EXECUTION_TIME_SECONDS']
        }
        
    except Exception as e:
        logger.error(f"Failed to get job status for {job_id}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics")
async def get_metrics():
    """Get service metrics"""
    try:
        # Query recent job statistics
        query = """
        SELECT 
            COUNT(*) as total_jobs,
            COUNT(CASE WHEN status = 'COMPLETED' THEN 1 END) as completed_jobs,
            COUNT(CASE WHEN status = 'FAILED' THEN 1 END) as failed_jobs,
            COUNT(CASE WHEN status = 'RUNNING' THEN 1 END) as running_jobs,
            AVG(execution_time_seconds) as avg_execution_time
        FROM jobs 
        WHERE created_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP())
        """
        
        df = sf_conn.execute_query(query)
        metrics = df.iloc[0] if not df.empty else {}
        
        return {
            "service": config.SERVICE_NAME,
            "timestamp": datetime.now().isoformat(),
            "metrics": {
                "total_jobs_24h": int(metrics.get('TOTAL_JOBS', 0)),
                "completed_jobs_24h": int(metrics.get('COMPLETED_JOBS', 0)),
                "failed_jobs_24h": int(metrics.get('FAILED_JOBS', 0)),
                "running_jobs": int(metrics.get('RUNNING_JOBS', 0)),
                "avg_execution_time_seconds": float(metrics.get('AVG_EXECUTION_TIME', 0)) if metrics.get('AVG_EXECUTION_TIME') else 0,
                "success_rate": (int(metrics.get('COMPLETED_JOBS', 0)) / max(int(metrics.get('TOTAL_JOBS', 1)), 1)) * 100
            }
        }
        
    except Exception as e:
        logger.error(f"Failed to get metrics: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    # Run the application
    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=int(os.getenv("PORT", 8000)),
        log_level="info",
        access_log=True
    )