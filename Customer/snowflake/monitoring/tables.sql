-- Monitoring Schema Tables
-- Uses CREATE OR ALTER for idempotent deployments
-- Uses Jinja templating for environment-specific configuration

USE DATABASE {{ database }};
USE SCHEMA monitoring;

-- Create or alter API calls tracking table
CREATE OR ALTER TABLE api_calls (
    call_id STRING PRIMARY KEY,
    job_id STRING NOT NULL,
    endpoint STRING NOT NULL,
    request_payload VARIANT,
    response_payload VARIANT,
    call_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    response_timestamp TIMESTAMP_NTZ,
    status STRING DEFAULT 'INITIATED',
    http_status_code NUMBER,
    port NUMBER,
    retry_count NUMBER DEFAULT 0,
    error_message STRING,
    execution_time_ms NUMBER
) data_retention_time_in_days = {{ retention_days | default(7) }};

-- Create or alter task errors table
CREATE OR ALTER TABLE task_errors (
    error_id STRING PRIMARY KEY,
    task_name STRING NOT NULL,
    error_message STRING,
    error_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    resolved BOOLEAN DEFAULT FALSE,
    resolution_notes STRING,
    error_category STRING,
    severity STRING DEFAULT 'MEDIUM'
);

-- Create or alter system metrics table
CREATE OR ALTER TABLE system_metrics (
    metric_id STRING PRIMARY KEY,
    metric_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    metric_type STRING NOT NULL,
    metric_name STRING NOT NULL,
    metric_value NUMBER,
    metric_unit STRING,
    tags VARIANT,
    source_system STRING DEFAULT 'snowflake'
);

-- Create or alter data quality checks table
CREATE OR ALTER TABLE data_quality_checks (
    check_id STRING PRIMARY KEY,
    check_name STRING NOT NULL,
    table_name STRING NOT NULL,
    check_type STRING NOT NULL,
    check_description STRING,
    expected_result VARIANT,
    actual_result VARIANT,
    status STRING,
    check_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    execution_time_seconds NUMBER(5,2),
    error_details STRING
);

-- Create or alter audit log table
CREATE OR ALTER TABLE audit_log (
    audit_id STRING PRIMARY KEY,
    event_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    event_type STRING NOT NULL,
    object_type STRING,
    object_name STRING,
    action STRING NOT NULL,
    user_name STRING,
    session_id STRING,
    client_info VARIANT,
    before_value VARIANT,
    after_value VARIANT,
    success BOOLEAN DEFAULT TRUE,
    error_message STRING
);