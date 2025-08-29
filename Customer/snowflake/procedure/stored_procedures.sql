-- Monitoring Schema Stored Procedures
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE {{ database }};
USE SCHEMA monitoring;

-- Procedure for data quality checks
CREATE OR ALTER PROCEDURE run_data_quality_checks()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    issues_found NUMBER := 0;
    result STRING;
    check_results ARRAY;
    check_id STRING;
BEGIN
    check_results := ARRAY_CONSTRUCT();
    
    -- Check for null customer emails
    SELECT COUNT(*) INTO issues_found
    FROM raw_data.customers 
    WHERE email IS NULL OR email = '';
    
    check_id := 'DQ_CUSTOMER_EMAIL_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    INSERT INTO data_quality_checks (
        check_id, check_name, table_name, check_type, check_description,
        expected_result, actual_result, status, check_timestamp
    ) VALUES (
        check_id, 'Customer Email Validation', 'customers', 'NULL_CHECK',
        'Check for customers with missing email addresses',
        PARSE_JSON('{"expected_nulls": 0}'),
        PARSE_JSON('{"actual_nulls": ' || issues_found || '}'),
        CASE WHEN issues_found = 0 THEN 'PASS' ELSE 'FAIL' END,
        CURRENT_TIMESTAMP()
    );
    
    IF (issues_found > 0) THEN
        check_results := ARRAY_APPEND(check_results, 'Found ' || issues_found || ' customers with missing emails');
    END IF;
    
    -- Check for orders without items
    SELECT COUNT(*) INTO issues_found
    FROM raw_data.orders o
    LEFT JOIN raw_data.order_items oi ON o.order_id = oi.order_id
    WHERE oi.order_id IS NULL;
    
    check_id := 'DQ_ORDER_ITEMS_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    INSERT INTO data_quality_checks (
        check_id, check_name, table_name, check_type, check_description,
        expected_result, actual_result, status, check_timestamp
    ) VALUES (
        check_id, 'Order Items Validation', 'orders', 'REFERENTIAL_INTEGRITY',
        'Check for orders without corresponding order items',
        PARSE_JSON('{"expected_orphans": 0}'),
        PARSE_JSON('{"actual_orphans": ' || issues_found || '}'),
        CASE WHEN issues_found = 0 THEN 'PASS' ELSE 'FAIL' END,
        CURRENT_TIMESTAMP()
    );
    
    IF (issues_found > 0) THEN
        check_results := ARRAY_APPEND(check_results, 'Found ' || issues_found || ' orders without items');
    END IF;
    
    -- Check for negative prices
    SELECT COUNT(*) INTO issues_found
    FROM raw_data.products
    WHERE price < 0;
    
    check_id := 'DQ_PRODUCT_PRICE_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    INSERT INTO data_quality_checks (
        check_id, check_name, table_name, check_type, check_description,
        expected_result, actual_result, status, check_timestamp
    ) VALUES (
        check_id, 'Product Price Validation', 'products', 'RANGE_CHECK',
        'Check for products with negative prices',
        PARSE_JSON('{"min_price": 0}'),
        PARSE_JSON('{"negative_prices": ' || issues_found || '}'),
        CASE WHEN issues_found = 0 THEN 'PASS' ELSE 'FAIL' END,
        CURRENT_TIMESTAMP()
    );
    
    IF (issues_found > 0) THEN
        check_results := ARRAY_APPEND(check_results, 'Found ' || issues_found || ' products with negative prices');
    END IF;
    
    -- Check for future order dates
    SELECT COUNT(*) INTO issues_found
    FROM raw_data.orders
    WHERE order_date > CURRENT_TIMESTAMP();
    
    check_id := 'DQ_ORDER_DATE_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    INSERT INTO data_quality_checks (
        check_id, check_name, table_name, check_type, check_description,
        expected_result, actual_result, status, check_timestamp
    ) VALUES (
        check_id, 'Order Date Validation', 'orders', 'TEMPORAL_CHECK',
        'Check for orders with future dates',
        PARSE_JSON('{"max_date": "' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYY-MM-DD HH24:MI:SS') || '"}'),
        PARSE_JSON('{"future_orders": ' || issues_found || '}'),
        CASE WHEN issues_found = 0 THEN 'PASS' ELSE 'FAIL' END,
        CURRENT_TIMESTAMP()
    );
    
    IF (issues_found > 0) THEN
        check_results := ARRAY_APPEND(check_results, 'Found ' || issues_found || ' orders with future dates');
    END IF;
    
    IF (ARRAY_SIZE(check_results) = 0) THEN
        result := 'All data quality checks passed';
    ELSE
        result := 'Data quality issues found: ' || ARRAY_TO_STRING(check_results, '; ');
    END IF;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error running data quality checks: ' || SQLERRM;
END;
$$;

-- Procedure to log system metrics
CREATE OR ALTER PROCEDURE log_system_metric(
    metric_type STRING,
    metric_name STRING,
    metric_value NUMBER,
    metric_unit STRING DEFAULT NULL,
    tags VARIANT DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    metric_id STRING;
    result STRING;
BEGIN
    metric_id := 'METRIC_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS') || '_' || ABS(RANDOM());
    
    INSERT INTO system_metrics (
        metric_id, metric_timestamp, metric_type, metric_name,
        metric_value, metric_unit, tags, source_system
    ) VALUES (
        metric_id, CURRENT_TIMESTAMP(), :metric_type, :metric_name,
        :metric_value, :metric_unit, :tags, 'snowflake'
    );
    
    result := 'System metric logged: ' || :metric_name || ' = ' || :metric_value;
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error logging system metric: ' || SQLERRM;
END;
$$;

-- Procedure to clean up old monitoring data
CREATE OR ALTER PROCEDURE cleanup_monitoring_data(retention_days NUMBER DEFAULT 30)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    deleted_count NUMBER;
    result STRING;
BEGIN
    -- Clean up old API calls
    DELETE FROM api_calls 
    WHERE call_timestamp < DATEADD('day', -:retention_days, CURRENT_TIMESTAMP());
    deleted_count := SQLROWCOUNT;
    
    -- Clean up old system metrics
    DELETE FROM system_metrics 
    WHERE metric_timestamp < DATEADD('day', -:retention_days, CURRENT_TIMESTAMP());
    deleted_count := deleted_count + SQLROWCOUNT;
    
    -- Clean up resolved task errors older than retention period
    DELETE FROM task_errors 
    WHERE resolved = TRUE 
    AND error_timestamp < DATEADD('day', -:retention_days, CURRENT_TIMESTAMP());
    deleted_count := deleted_count + SQLROWCOUNT;
    
    -- Clean up old data quality checks
    DELETE FROM data_quality_checks 
    WHERE check_timestamp < DATEADD('day', -:retention_days, CURRENT_TIMESTAMP());
    deleted_count := deleted_count + SQLROWCOUNT;
    
    -- Clean up old audit logs
    DELETE FROM audit_log 
    WHERE event_timestamp < DATEADD('day', -:retention_days, CURRENT_TIMESTAMP());
    deleted_count := deleted_count + SQLROWCOUNT;
    
    result := 'Cleanup completed. Deleted ' || deleted_count || ' records older than ' || :retention_days || ' days';
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error during cleanup: ' || SQLERRM;
END;
$$;