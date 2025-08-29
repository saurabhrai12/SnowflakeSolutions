-- Streamlined End-to-End Workflow Test
-- This script tests the complete data pipeline with actual table structures

-- Set context
USE DATABASE {{ database }};
USE SCHEMA raw_data;
USE WAREHOUSE analytics_wh;

-- ===============================================
-- STEP 1: Insert New Test Record (Trigger Streams)
-- ===============================================

-- Insert a new customer to trigger the customer stream
INSERT INTO customers (
    customer_id,
    customer_name, 
    email,
    phone,
    address,
    customer_tier,
    lifetime_value,
    is_active,
    tags
) VALUES (
    'CUST_WORKFLOW_TEST',
    'End-to-End Workflow Test Company',
    'test@workflowtest.com',
    '+1-555-0999',
    PARSE_JSON('{"street": "123 Test Drive", "city": "Test City", "state": "TX", "zip": "12345"}'),
    'ENTERPRISE',
    50000.00,
    TRUE,
    PARSE_JSON('["Workflow", "Test", "Demo"]')
);

-- Insert a new job record to trigger job stream
INSERT INTO jobs (
    job_id,
    job_name,
    job_type,
    status,
    created_by,
    input_data,
    priority,
    tags
) VALUES (
    'JOB_WORKFLOW_TEST',
    'End-to-End Workflow Test Job',
    'SALES_REPORT',
    'PENDING',
    'workflow_test_user',
    PARSE_JSON('{"test_mode": true, "workflow": "end-to-end"}'),
    1,
    PARSE_JSON('["workflow", "test", "demo"]')
);

-- Verify the inserted records
SELECT 'STEP 1 COMPLETED: Raw data inserted' as status;

SELECT customer_id, customer_name, email, customer_tier, created_at
FROM customers 
WHERE customer_id = 'CUST_WORKFLOW_TEST';

SELECT job_id, job_name, job_type, status, created_by, created_at
FROM jobs 
WHERE job_id = 'JOB_WORKFLOW_TEST';

-- ===============================================
-- STEP 2: Test ECS Service Connectivity
-- ===============================================

-- Switch to reporting schema for external function testing
USE SCHEMA reporting;

-- Test basic connectivity to ECS service
SELECT 'STEP 2: Testing ECS service connectivity' as status;

SELECT reporting.generate_report_via_ecs(
    'CONNECTIVITY_TEST_' || REPLACE(UUID_STRING(), '-', '_'),
    'SALES_REPORT',
    OBJECT_CONSTRUCT(
        'test_mode', true,
        'connectivity_check', true,
        'start_date', '2024-01-01',
        'end_date', '2024-01-31'
    ),
    'workflow-connectivity-test'
) as connectivity_test_result;

-- ===============================================
-- STEP 3: Generate Test Reports via External Function
-- ===============================================

-- Generate a sales report
SELECT 'STEP 3A: Generating Sales Report' as status;

SELECT reporting.generate_sales_report_ecs(
    '2024-01-01'::DATE,
    '2024-01-31'::DATE,
    'WORKFLOW_SALES_' || REPLACE(UUID_STRING(), '-', '_')
) as sales_report_result;

-- Generate customer analysis report  
SELECT 'STEP 3B: Generating Customer Analysis Report' as status;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_CUSTOMER_' || REPLACE(UUID_STRING(), '-', '_'),
    'CUSTOMER_ANALYSIS',
    OBJECT_CONSTRUCT(
        'analysis_type', 'workflow_test',
        'include_test_customers', true,
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'format', 'json'
    ),
    'workflow-customer-analysis'
) as customer_analysis_result;

-- Generate product performance report
SELECT 'STEP 3C: Generating Product Performance Report' as status;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_PRODUCT_' || REPLACE(UUID_STRING(), '-', '_'),
    'PRODUCT_PERFORMANCE',
    OBJECT_CONSTRUCT(
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'include_trends', true,
        'group_by', 'category',
        'format', 'json'
    ),
    'workflow-product-performance'
) as product_performance_result;

-- Generate executive dashboard
SELECT 'STEP 3D: Generating Executive Dashboard' as status;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_EXEC_' || REPLACE(UUID_STRING(), '-', '_'),
    'EXECUTIVE_DASHBOARD',
    OBJECT_CONSTRUCT(
        'start_date', '2024-01-01', 
        'end_date', '2024-01-31',
        'include_trends', true,
        'include_forecasts', false,
        'format', 'json'
    ),
    'workflow-executive-dashboard'
) as executive_dashboard_result;

-- Generate data quality report
SELECT 'STEP 3E: Generating Data Quality Report' as status;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_DQ_' || REPLACE(UUID_STRING(), '-', '_'),
    'DATA_QUALITY',
    OBJECT_CONSTRUCT(
        'scope', 'raw_data',
        'include_metrics', true,
        'check_completeness', true,
        'format', 'json'
    ),
    'workflow-data-quality'
) as data_quality_result;

-- ===============================================
-- STEP 4: Test Automated Daily Reports Procedure
-- ===============================================

SELECT 'STEP 4: Testing Automated Daily Reports Procedure' as status;

CALL reporting.generate_daily_reports();

-- ===============================================
-- STEP 5: Workflow Summary and Validation
-- ===============================================

SELECT 'STEP 5: Workflow Summary' as status;

-- Summary of workflow execution
SELECT 
    'Workflow Execution Summary' as summary_type,
    CURRENT_TIMESTAMP() as execution_time,
    'Data inserted → ECS connectivity tested → 5 reports generated → Daily automation tested' as workflow_steps,
    'SUCCESS' as status;

-- Cleanup test data (optional - comment out to keep test data)
-- DELETE FROM raw_data.customers WHERE customer_id = 'CUST_WORKFLOW_TEST';
-- DELETE FROM raw_data.jobs WHERE job_id = 'JOB_WORKFLOW_TEST';

SELECT 'END-TO-END WORKFLOW TEST COMPLETED SUCCESSFULLY' as final_status;