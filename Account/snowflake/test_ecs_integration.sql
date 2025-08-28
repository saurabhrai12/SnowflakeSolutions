-- Test Script for Snowflake-ECS Integration
-- This script tests the external functions and task integration with the ECS report service

-- Set the context
USE DATABASE analytics_platform;
USE SCHEMA reporting;
USE WAREHOUSE analytics_wh;

-- Test 1: Basic connectivity test to ECS service
-- Note: Execute these tests one by one and check results

-- Test the basic external function with a simple sales report
SELECT 'TEST 1: Basic ECS connectivity' as test_name;

SELECT reporting.generate_report_via_ecs(
    'TEST_BASIC_' || REPLACE(UUID_STRING(), '-', '_'),
    'SALES_REPORT',
    OBJECT_CONSTRUCT(
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'format', 'json'
    ),
    'snowflake-test-basic'
) as test_result;

-- Test 2: Sales report convenience function
SELECT 'TEST 2: Sales report convenience function' as test_name;

SELECT reporting.generate_sales_report_ecs(
    '2024-01-01'::DATE,
    '2024-01-31'::DATE,
    'TEST_SALES_' || REPLACE(UUID_STRING(), '-', '_')
) as test_result;

-- Test 3: Customer analysis report
SELECT 'TEST 3: Customer analysis report' as test_name;

SELECT reporting.generate_report_via_ecs(
    'TEST_CUSTOMER_' || REPLACE(UUID_STRING(), '-', '_'),
    'CUSTOMER_ANALYSIS',
    OBJECT_CONSTRUCT(
        'analysis_type', 'monthly_summary',
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'include_demographics', true,
        'format', 'json'
    ),
    'snowflake-test-customer'
) as test_result;

-- Test 4: Product performance report
SELECT 'TEST 4: Product performance report' as test_name;

SELECT reporting.generate_report_via_ecs(
    'TEST_PRODUCT_' || REPLACE(UUID_STRING(), '-', '_'),
    'PRODUCT_PERFORMANCE',
    OBJECT_CONSTRUCT(
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'include_trends', true,
        'group_by', 'category',
        'format', 'json'
    ),
    'snowflake-test-product'
) as test_result;

-- Test 5: Executive dashboard report
SELECT 'TEST 5: Executive dashboard report' as test_name;

SELECT reporting.generate_report_via_ecs(
    'TEST_EXEC_' || REPLACE(UUID_STRING(), '-', '_'),
    'EXECUTIVE_DASHBOARD',
    OBJECT_CONSTRUCT(
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'include_trends', true,
        'include_forecasts', false,
        'format', 'json'
    ),
    'snowflake-test-executive'
) as test_result;

-- Test 6: Data quality report
SELECT 'TEST 6: Data quality report' as test_name;

SELECT reporting.generate_report_via_ecs(
    'TEST_DQ_' || REPLACE(UUID_STRING(), '-', '_'),
    'DATA_QUALITY',
    OBJECT_CONSTRUCT(
        'scope', 'processed_data',
        'include_metrics', true,
        'start_date', '2024-01-01',
        'end_date', '2024-01-31',
        'format', 'json'
    ),
    'snowflake-test-dq'
) as test_result;

-- Test 7: Job status checking (replace 'your-job-id' with actual job ID from previous tests)
-- SELECT 'TEST 7: Job status check' as test_name;
-- 
-- SELECT reporting.check_ecs_job_status('your-job-id-here') as status_result;

-- Test 8: Daily reports procedure
SELECT 'TEST 8: Daily reports procedure' as test_name;

CALL reporting.generate_daily_reports();

-- Test 9: Check task status and history
SELECT 'TEST 9: Task status check' as test_name;

SHOW TASKS IN SCHEMA reporting;

-- Test 10: Manual task execution (for testing)
-- EXECUTE TASK reporting.daily_reports_task;

-- View recent task execution history
SELECT 
    task_name,
    scheduled_time,
    started_time,
    completed_time,
    state,
    return_value,
    error_code,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE task_name LIKE '%REPORTS_TASK%'
    OR task_name LIKE '%DASHBOARD_TASK%'
    OR task_name LIKE '%QUALITY_TASK%'
ORDER BY scheduled_time DESC
LIMIT 20;

-- Performance monitoring query
SELECT 
    'ECS Integration Performance Summary' as summary_type,
    COUNT(*) as total_executions,
    SUM(CASE WHEN state = 'SUCCEEDED' THEN 1 ELSE 0 END) as successful_executions,
    SUM(CASE WHEN state = 'FAILED' THEN 1 ELSE 0 END) as failed_executions,
    AVG(DATEDIFF('seconds', started_time, completed_time)) as avg_execution_seconds
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE task_name IN ('DAILY_REPORTS_TASK', 'WEEKLY_EXECUTIVE_DASHBOARD_TASK', 'MONTHLY_DATA_QUALITY_TASK')
    AND scheduled_time >= DATEADD('day', -7, CURRENT_TIMESTAMP());

-- Troubleshooting queries for debugging

-- Check network rules and integrations
SHOW NETWORK RULES;
SHOW EXTERNAL ACCESS INTEGRATIONS;

-- Check function definitions
SHOW FUNCTIONS IN SCHEMA reporting;

-- Check task privileges
SHOW GRANTS TO ROLE ACCOUNTADMIN;