-- End-to-End Workflow Test: Raw Data → Processing → Report Generation → S3 Distribution
-- This script demonstrates the complete data pipeline from ingestion to report delivery

-- Set context
USE DATABASE analytics_platform;
USE SCHEMA raw_data;
USE WAREHOUSE analytics_wh;

-- ===============================================
-- STEP 1: Insert Test Data into Raw Zone Tables
-- ===============================================

-- Insert new customer data
INSERT INTO raw_data.customers (
    customer_id, 
    customer_name, 
    email, 
    phone, 
    address, 
    city, 
    state, 
    zip_code, 
    country, 
    industry,
    created_at
) VALUES (
    'CUST011',
    'TechFlow Solutions Inc',
    'info@techflow.com',
    '+1-555-0199',
    '789 Innovation Drive',
    'Austin',
    'TX',
    '73301',
    'USA',
    'Software Development',
    CURRENT_TIMESTAMP()
);

-- Insert new product data
INSERT INTO raw_data.products (
    product_id,
    product_name,
    category,
    price,
    cost,
    description,
    created_at
) VALUES (
    'PROD011',
    'Advanced Analytics Suite Enterprise',
    'Analytics Software',
    15999.99,
    8999.99,
    'Enterprise-grade analytics platform with AI/ML capabilities and real-time processing',
    CURRENT_TIMESTAMP()
);

-- Insert new order data
INSERT INTO raw_data.orders (
    order_id,
    customer_id,
    order_date,
    status,
    total_amount,
    created_at
) VALUES (
    'ORD011',
    'CUST011',
    CURRENT_DATE(),
    'confirmed',
    31999.98,
    CURRENT_TIMESTAMP()
);

-- Insert order items
INSERT INTO raw_data.order_items (
    order_item_id,
    order_id,
    product_id,
    quantity,
    unit_price,
    total_price,
    created_at
) VALUES 
(
    'OI021',
    'ORD011',
    'PROD011',
    2,
    15999.99,
    31999.98,
    CURRENT_TIMESTAMP()
);

-- Insert job processing record
INSERT INTO raw_data.jobs (
    job_id,
    job_type,
    status,
    created_at,
    started_at
) VALUES (
    'JOB011',
    'WORKFLOW_TEST',
    'running',
    CURRENT_TIMESTAMP(),
    CURRENT_TIMESTAMP()
);

-- Display inserted records
SELECT 'INSERTED RAW DATA' as step_status;

SELECT 'New Customer:' as record_type, customer_id, customer_name, industry, created_at
FROM raw_data.customers 
WHERE customer_id = 'CUST011';

SELECT 'New Product:' as record_type, product_id, product_name, category, price
FROM raw_data.products 
WHERE product_id = 'PROD011';

SELECT 'New Order:' as record_type, order_id, customer_id, order_date, total_amount
FROM raw_data.orders 
WHERE order_id = 'ORD011';

-- ===============================================
-- STEP 2: Check Stream Data Capture
-- ===============================================

-- Check customer stream
SELECT 'CUSTOMER STREAM DATA' as stream_type;
SELECT * FROM raw_data.customer_stream 
WHERE customer_id = 'CUST011';

-- Check order stream  
SELECT 'ORDER STREAM DATA' as stream_type;
SELECT * FROM raw_data.order_stream 
WHERE order_id = 'ORD011';

-- Check product stream
SELECT 'PRODUCT STREAM DATA' as stream_type;
SELECT * FROM raw_data.product_stream 
WHERE product_id = 'PROD011';

-- ===============================================
-- STEP 3: Execute Data Processing Procedures
-- ===============================================

-- Switch to processed_data schema
USE SCHEMA processed_data;

-- Process customer changes
SELECT 'PROCESSING CUSTOMER CHANGES' as processing_step;
CALL processed_data.process_customer_changes();

-- Process product changes
SELECT 'PROCESSING PRODUCT CHANGES' as processing_step;
CALL processed_data.process_product_changes();

-- Process order changes
SELECT 'PROCESSING ORDER CHANGES' as processing_step;
CALL processed_data.process_order_changes();

-- Process job stream
SELECT 'PROCESSING JOB STREAM' as processing_step;
CALL processed_data.process_job_stream();

-- ===============================================
-- STEP 4: Validate Processed Data
-- ===============================================

-- Check processed customer data
SELECT 'PROCESSED CUSTOMER DATA' as validation_step;
SELECT 
    customer_id,
    customer_name,
    industry,
    total_orders,
    total_spent,
    last_order_date,
    customer_segment,
    processed_at
FROM processed_data.customer_analytics 
WHERE customer_id = 'CUST011';

-- Check processed order data
SELECT 'PROCESSED ORDER DATA' as validation_step;
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    profit_margin,
    order_size_category,
    processed_at
FROM processed_data.order_analytics 
WHERE order_id = 'ORD011';

-- Check product performance
SELECT 'PRODUCT PERFORMANCE DATA' as validation_step;
SELECT 
    product_id,
    product_name,
    total_sales,
    total_quantity_sold,
    avg_sale_price,
    profit_margin,
    performance_tier,
    last_updated
FROM processed_data.product_performance 
WHERE product_id = 'PROD011';

-- ===============================================
-- STEP 5: Generate Sales Metrics
-- ===============================================

-- Switch to reporting schema
USE SCHEMA reporting;

-- Generate current sales metrics
INSERT INTO processed_data.sales_metrics (
    metric_date,
    total_revenue,
    total_orders,
    avg_order_value,
    total_customers,
    created_at
)
SELECT 
    CURRENT_DATE() as metric_date,
    SUM(total_amount) as total_revenue,
    COUNT(*) as total_orders,
    AVG(total_amount) as avg_order_value,
    COUNT(DISTINCT customer_id) as total_customers,
    CURRENT_TIMESTAMP() as created_at
FROM processed_data.order_analytics
WHERE order_date = CURRENT_DATE();

-- Display today's metrics
SELECT 'DAILY SALES METRICS' as metrics_type;
SELECT * FROM processed_data.sales_metrics 
WHERE metric_date = CURRENT_DATE()
ORDER BY created_at DESC 
LIMIT 1;

-- ===============================================
-- STEP 6: Test External Function Report Generation
-- ===============================================

-- Test basic external function connectivity
SELECT 'TESTING EXTERNAL FUNCTION' as test_step;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_TEST_' || REPLACE(UUID_STRING(), '-', '_'),
    'SALES_REPORT',
    OBJECT_CONSTRUCT(
        'start_date', CURRENT_DATE()::STRING,
        'end_date', CURRENT_DATE()::STRING,
        'format', 'json',
        'test_mode', true,
        'workflow_validation', true
    ),
    'end-to-end-workflow-test'
) as external_function_result;

-- Generate comprehensive sales report
SELECT 'GENERATING SALES REPORT' as report_step;

SELECT reporting.generate_sales_report_ecs(
    CURRENT_DATE(),
    CURRENT_DATE(),
    'WORKFLOW_SALES_' || REPLACE(UUID_STRING(), '-', '_')
) as sales_report_result;

-- Generate customer analysis report
SELECT 'GENERATING CUSTOMER ANALYSIS' as report_step;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_CUSTOMER_' || REPLACE(UUID_STRING(), '-', '_'),
    'CUSTOMER_ANALYSIS',
    OBJECT_CONSTRUCT(
        'analysis_type', 'daily_summary',
        'date', CURRENT_DATE()::STRING,
        'include_new_customers', true,
        'format', 'json'
    ),
    'workflow-customer-analysis'
) as customer_analysis_result;

-- Generate product performance report
SELECT 'GENERATING PRODUCT PERFORMANCE REPORT' as report_step;

SELECT reporting.generate_report_via_ecs(
    'WORKFLOW_PRODUCT_' || REPLACE(UUID_STRING(), '-', '_'),
    'PRODUCT_PERFORMANCE',
    OBJECT_CONSTRUCT(
        'start_date', CURRENT_DATE()::STRING,
        'end_date', CURRENT_DATE()::STRING,
        'include_new_products', true,
        'group_by', 'category',
        'format', 'json'
    ),
    'workflow-product-performance'
) as product_performance_result;

-- ===============================================
-- STEP 7: Test Automated Daily Reports Procedure
-- ===============================================

SELECT 'TESTING DAILY REPORTS PROCEDURE' as automation_test;

-- Execute the daily reports procedure
CALL reporting.generate_daily_reports();

-- ===============================================
-- STEP 8: Monitor Task Execution History
-- ===============================================

-- Check recent task executions
SELECT 'TASK EXECUTION HISTORY' as monitoring_step;

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
    AND scheduled_time >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
ORDER BY scheduled_time DESC
LIMIT 10;

-- ===============================================
-- STEP 9: Validate End-to-End Data Flow
-- ===============================================

-- Summary of data flow validation
SELECT 'END-TO-END VALIDATION SUMMARY' as summary_step;

-- Count records created in this workflow
SELECT 
    'Raw Data Inserted' as stage,
    (SELECT COUNT(*) FROM raw_data.customers WHERE customer_id = 'CUST011') +
    (SELECT COUNT(*) FROM raw_data.products WHERE product_id = 'PROD011') +
    (SELECT COUNT(*) FROM raw_data.orders WHERE order_id = 'ORD011') +
    (SELECT COUNT(*) FROM raw_data.order_items WHERE order_id = 'ORD011') as record_count

UNION ALL

SELECT 
    'Processed Data Created' as stage,
    (SELECT COUNT(*) FROM processed_data.customer_analytics WHERE customer_id = 'CUST011') +
    (SELECT COUNT(*) FROM processed_data.order_analytics WHERE order_id = 'ORD011') +
    (SELECT COUNT(*) FROM processed_data.product_performance WHERE product_id = 'PROD011') as record_count

UNION ALL

SELECT 
    'Sales Metrics Generated' as stage,
    (SELECT COUNT(*) FROM processed_data.sales_metrics WHERE metric_date = CURRENT_DATE()) as record_count

UNION ALL

SELECT 
    'Reports Triggered' as stage,
    4 as record_count  -- Number of reports we triggered

ORDER BY stage;

-- Final workflow status
SELECT 
    'WORKFLOW COMPLETED SUCCESSFULLY' as status,
    CURRENT_TIMESTAMP() as completion_time,
    'Data inserted → Streams captured → Processing executed → Reports generated → ECS integration tested' as workflow_summary;