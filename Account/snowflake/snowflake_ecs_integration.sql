-- Snowflake External Function Integration with AWS ECS Report Service
-- This script creates an external function to call the ECS-hosted report generation service

-- First, create a network rule for the ECS service
CREATE OR REPLACE NETWORK RULE ecs_report_service_rule
  MODE = EGRESS
  TYPE = HOST_PORT
  VALUE_LIST = ('54.88.92.124:8000');

-- Create an external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION ecs_report_integration
  ALLOWED_NETWORK_RULES = (ecs_report_service_rule)
  ENABLED = true;

-- Grant access to the integration to the current role
GRANT USAGE ON INTEGRATION ecs_report_integration TO ROLE ACCOUNTADMIN;

-- Create the external function to call the ECS report service
CREATE OR REPLACE FUNCTION reporting.generate_report_via_ecs(
    job_id STRING,
    job_type STRING,
    input_data VARIANT,
    source STRING DEFAULT 'snowflake-external-function'
)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('requests')
EXTERNAL_ACCESS_INTEGRATIONS = (ecs_report_integration)
HANDLER = 'call_ecs_service'
AS
$$
import requests
import json
from datetime import datetime

def call_ecs_service(job_id, job_type, input_data, source):
    """
    Calls the ECS report generation service
    """
    try:
        # ECS service endpoint
        ecs_endpoint = "http://54.88.92.124:8000/process-job"
        
        # Prepare the request payload
        payload = {
            "job_id": job_id,
            "job_type": job_type,
            "input_data": input_data,
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "source": source,
            "priority": 2
        }
        
        # Make the HTTP request
        response = requests.post(
            ecs_endpoint,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json()
        else:
            return {
                "error": f"HTTP {response.status_code}",
                "message": response.text,
                "status": "failed"
            }
            
    except Exception as e:
        return {
            "error": "Exception occurred",
            "message": str(e),
            "status": "failed"
        }
$$;

-- Create a convenience function for sales reports
CREATE OR REPLACE FUNCTION reporting.generate_sales_report_ecs(
    start_date DATE,
    end_date DATE,
    job_id STRING DEFAULT NULL
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
    SELECT reporting.generate_report_via_ecs(
        COALESCE(job_id, 'SALES_' || REPLACE(UUID_STRING(), '-', '_')),
        'SALES_REPORT',
        OBJECT_CONSTRUCT(
            'start_date', start_date::STRING,
            'end_date', end_date::STRING,
            'format', 'json'
        ),
        'snowflake-sales-function'
    )
$$;

-- Create a function to check job status
CREATE OR REPLACE FUNCTION reporting.check_ecs_job_status(job_id STRING)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('requests')
EXTERNAL_ACCESS_INTEGRATIONS = (ecs_report_integration)
HANDLER = 'check_job_status'
AS
$$
import requests

def check_job_status(job_id):
    """
    Checks the status of a job in the ECS service
    """
    try:
        # ECS service status endpoint
        status_endpoint = f"http://54.88.92.124:8000/job/{job_id}/status"
        
        # Make the HTTP request
        response = requests.get(status_endpoint, timeout=10)
        
        if response.status_code == 200:
            return response.json()
        else:
            return {
                "error": f"HTTP {response.status_code}",
                "message": response.text,
                "status": "unknown"
            }
            
    except Exception as e:
        return {
            "error": "Exception occurred",
            "message": str(e),
            "status": "failed"
        }
$$;

-- Create a stored procedure for automated report generation
CREATE OR REPLACE PROCEDURE reporting.generate_daily_reports()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    sales_result VARIANT;
    customer_result VARIANT;
    product_result VARIANT;
    job_id_sales STRING;
    job_id_customer STRING;
    job_id_product STRING;
    result_message STRING DEFAULT '';
BEGIN
    -- Generate unique job IDs
    job_id_sales := 'DAILY_SALES_' || REPLACE(UUID_STRING(), '-', '_');
    job_id_customer := 'DAILY_CUSTOMER_' || REPLACE(UUID_STRING(), '-', '_');
    job_id_product := 'DAILY_PRODUCT_' || REPLACE(UUID_STRING(), '-', '_');
    
    -- Generate sales report for yesterday
    sales_result := reporting.generate_report_via_ecs(
        job_id_sales,
        'SALES_REPORT',
        OBJECT_CONSTRUCT(
            'start_date', DATEADD(day, -1, CURRENT_DATE())::STRING,
            'end_date', CURRENT_DATE()::STRING,
            'format', 'json'
        ),
        'snowflake-daily-automation'
    );
    
    -- Generate customer analysis report
    customer_result := reporting.generate_report_via_ecs(
        job_id_customer,
        'CUSTOMER_ANALYSIS',
        OBJECT_CONSTRUCT(
            'analysis_type', 'daily_activity',
            'date', DATEADD(day, -1, CURRENT_DATE())::STRING,
            'format', 'json'
        ),
        'snowflake-daily-automation'
    );
    
    -- Generate product performance report
    product_result := reporting.generate_report_via_ecs(
        job_id_product,
        'PRODUCT_PERFORMANCE',
        OBJECT_CONSTRUCT(
            'start_date', DATEADD(day, -7, CURRENT_DATE())::STRING,
            'end_date', CURRENT_DATE()::STRING,
            'format', 'json'
        ),
        'snowflake-daily-automation'
    );
    
    -- Build result message
    result_message := 'Daily reports initiated successfully:\\n' ||
                     'Sales Report Job: ' || job_id_sales || '\\n' ||
                     'Customer Analysis Job: ' || job_id_customer || '\\n' ||
                     'Product Performance Job: ' || job_id_product;
    
    RETURN result_message;
END;
$$;

-- Example usage and testing queries:

-- Test the basic external function
-- SELECT reporting.generate_report_via_ecs(
--     'TEST_' || REPLACE(UUID_STRING(), '-', '_'),
--     'SALES_REPORT',
--     OBJECT_CONSTRUCT('start_date', '2024-01-01', 'end_date', '2024-01-31'),
--     'snowflake-test'
-- );

-- Test the sales report convenience function
-- SELECT reporting.generate_sales_report_ecs('2024-01-01', '2024-01-31');

-- Test job status checking
-- SELECT reporting.check_ecs_job_status('your-job-id-here');

-- Run the daily reports procedure
-- CALL reporting.generate_daily_reports();