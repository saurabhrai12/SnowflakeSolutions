-- Snowflake Tasks and Streams for Job Processing
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE {{ database }};
USE SCHEMA raw_data;

-- Create or replace stream to capture job table changes
CREATE OR REPLACE STREAM job_stream 
ON TABLE jobs
APPEND_ONLY = FALSE
COMMENT = 'Stream to capture job table inserts and updates for triggering external processing';

-- Create external function for HTTP calls to AWS ECS
-- Note: This requires proper external function setup with AWS API Gateway
CREATE OR ALTER FUNCTION call_ecs_python_app(job_data VARIANT)
RETURNS VARIANT
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'call_external_api'
AS
$$
import json
import time
from typing import Dict, Any

def call_external_api(job_data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Calls external Python app hosted on AWS ECS Fargate
    This is a simulation - in production you'd use Snowflake's external function
    with AWS API Gateway integration
    """
    try:
        # Extract job information
        job_id = job_data.get('job_id')
        job_type = job_data.get('job_type')
        input_data = job_data.get('input_data', {})
        priority = job_data.get('priority', 3)
        
        # Prepare payload for external service
        payload = {
            'job_id': job_id,
            'job_type': job_type,
            'input_data': input_data,
            'priority': priority,
            'timestamp': str(int(time.time())),
            'source': 'snowflake_task',
            'callback_url': 'https://your-snowflake-external-function.execute-api.region.amazonaws.com/prod/job-callback'
        }
        
        # In production, this would be your actual ECS service endpoint
        # For this example, we'll simulate a successful response
        # The actual implementation would use requests or urllib to make HTTP calls
        
        # Simulated response based on job type
        if job_type == 'REPORT':
            simulated_response = {
                'status': 'accepted',
                'job_id': job_id,
                'message': f'Report generation job {job_id} queued for processing',
                'estimated_completion': '5-10 minutes',
                'tracking_id': f'ECS_TRACK_{job_id}_{int(time.time())}',
                'ecs_task_arn': f'arn:aws:ecs:us-east-1:123456789:task/cluster-name/task-{job_id}',
                's3_output_bucket': 'your-reports-bucket'
            }
        elif job_type == 'ANALYSIS':
            simulated_response = {
                'status': 'accepted',
                'job_id': job_id,
                'message': f'Analysis job {job_id} queued for processing',
                'estimated_completion': '10-15 minutes',
                'tracking_id': f'ECS_TRACK_{job_id}_{int(time.time())}',
                'ecs_task_arn': f'arn:aws:ecs:us-east-1:123456789:task/cluster-name/task-{job_id}',
                's3_output_bucket': 'your-analysis-bucket'
            }
        else:
            simulated_response = {
                'status': 'accepted',
                'job_id': job_id,
                'message': f'Job {job_id} queued for processing',
                'estimated_completion': '2-5 minutes',
                'tracking_id': f'ECS_TRACK_{job_id}_{int(time.time())}',
                'ecs_task_arn': f'arn:aws:ecs:us-east-1:123456789:task/cluster-name/task-{job_id}'
            }
        
        return simulated_response
        
    except Exception as e:
        return {
            'status': 'error',
            'job_id': job_data.get('job_id'),
            'error': str(e),
            'retry_recommended': True
        }
$$;

-- Create task to process job stream and call external Python app
CREATE OR ALTER TASK job_processor_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = '1 minute'  -- Check every minute for new jobs
    WHEN SYSTEM$STREAM_HAS_DATA('job_stream')
    AS
    CALL process_job_stream();

-- Create task for job status monitoring and cleanup
CREATE OR ALTER TASK job_cleanup_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = '10 minute'
    AS
    CALL cleanup_jobs_and_monitoring();

-- Create task for daily metrics generation
CREATE OR ALTER TASK daily_metrics_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Run daily at 6 AM UTC
    AS
    CALL generate_daily_metrics_and_checks();

-- Initially suspend all tasks for safety (enable manually after testing)
ALTER TASK job_processor_task SUSPEND;
ALTER TASK job_cleanup_task SUSPEND;
ALTER TASK daily_metrics_task SUSPEND;

-- Add task comments
ALTER TASK job_processor_task SET COMMENT = 'Processes new jobs from job_stream and calls external Python app on AWS ECS Fargate';
ALTER TASK job_cleanup_task SET COMMENT = 'Cleans up old jobs, retries failed jobs, and maintains monitoring data';
ALTER TASK daily_metrics_task SET COMMENT = 'Generates daily metrics and runs data quality checks';

-- Grant necessary permissions
GRANT SELECT ON STREAM job_stream TO ROLE PUBLIC;
GRANT MONITOR ON TASK job_processor_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK job_cleanup_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK daily_metrics_task TO ROLE PUBLIC;