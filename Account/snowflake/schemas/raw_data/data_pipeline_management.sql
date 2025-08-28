-- Data Pipeline Management and Control Scripts
-- Commands to manage the data pipeline tasks and monitor streams

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- ============================================
-- PIPELINE CONTROL COMMANDS
-- ============================================

-- To ENABLE the data pipeline (run these after testing):
-- ALTER TASK customer_analytics_task RESUME;
-- ALTER TASK product_analytics_task RESUME;
-- ALTER TASK order_metrics_task RESUME;
-- ALTER TASK order_items_analytics_task RESUME;
-- ALTER TASK data_pipeline_orchestrator RESUME;

-- To DISABLE the data pipeline:
-- ALTER TASK customer_analytics_task SUSPEND;
-- ALTER TASK product_analytics_task SUSPEND;
-- ALTER TASK order_metrics_task SUSPEND;
-- ALTER TASK order_items_analytics_task SUSPEND;
-- ALTER TASK data_pipeline_orchestrator SUSPEND;

-- ============================================
-- MONITORING PROCEDURES FOR DATA PIPELINE
-- ============================================

-- Note: Using procedures with SHOW commands instead of information_schema views
-- for better compatibility with Snowflake security model

-- Query examples for manual monitoring:
-- SHOW TASKS IN DATABASE analytics_platform;
-- SHOW STREAMS IN DATABASE analytics_platform;

-- Procedure to get data pipeline task status
CREATE OR ALTER PROCEDURE get_pipeline_task_status()
RETURNS TABLE(task_name STRING, state STRING, warehouse STRING, schedule STRING, comment STRING)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (SHOW TASKS LIKE '%analytics_task' IN DATABASE analytics_platform);
    RETURN TABLE(res);
END;
$$;

-- Procedure to get stream status with data availability
CREATE OR ALTER PROCEDURE get_pipeline_stream_status()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    customers_data BOOLEAN;
    products_data BOOLEAN;
    orders_data BOOLEAN;
    order_items_data BOOLEAN;
    result STRING;
BEGIN
    customers_data := SYSTEM$STREAM_HAS_DATA('customers_stream');
    products_data := SYSTEM$STREAM_HAS_DATA('products_stream');
    orders_data := SYSTEM$STREAM_HAS_DATA('orders_stream');
    order_items_data := SYSTEM$STREAM_HAS_DATA('order_items_stream');
    
    result := 'Stream Status: ' ||
              'customers_stream: ' || CASE WHEN customers_data THEN 'HAS_DATA' ELSE 'UP_TO_DATE' END ||
              ', products_stream: ' || CASE WHEN products_data THEN 'HAS_DATA' ELSE 'UP_TO_DATE' END ||
              ', orders_stream: ' || CASE WHEN orders_data THEN 'HAS_DATA' ELSE 'UP_TO_DATE' END ||
              ', order_items_stream: ' || CASE WHEN order_items_data THEN 'HAS_DATA' ELSE 'UP_TO_DATE' END;
    
    RETURN result;
END;
$$;

-- Procedure to get data pipeline processing metrics (replaces view for conditional access)
CREATE OR ALTER PROCEDURE get_pipeline_metrics()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
    metrics_count NUMBER;
BEGIN
    BEGIN
        SELECT COUNT(*) INTO metrics_count
        FROM monitoring.system_metrics
        WHERE metric_type = 'data_processing'
        AND metric_timestamp >= DATEADD('day', -7, CURRENT_TIMESTAMP());
        
        result := 'Found ' || metrics_count || ' data processing metrics in the last 7 days. Use SELECT * FROM monitoring.system_metrics WHERE metric_type = ''data_processing'' to view details.';
    EXCEPTION
        WHEN OTHER THEN
            result := 'Monitoring system not available yet. Deploy monitoring schema first to access metrics.';
    END;
    
    RETURN result;
END;
$$;

-- ============================================
-- PIPELINE MANAGEMENT PROCEDURES
-- ============================================

-- Procedure to start the entire data pipeline
CREATE OR ALTER PROCEDURE start_data_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
BEGIN
    -- Enable all data pipeline tasks in the correct order
    ALTER TASK customer_analytics_task RESUME;
    ALTER TASK product_analytics_task RESUME;
    ALTER TASK order_metrics_task RESUME;
    ALTER TASK order_items_analytics_task RESUME;
    ALTER TASK data_pipeline_orchestrator RESUME;
    
    -- Log the pipeline start (with error handling)
    BEGIN
        INSERT INTO monitoring.system_metrics (
            metric_id,
            metric_type,
            metric_name,
            metric_value,
            tags
        ) VALUES (
            'PIPELINE_START_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'data_pipeline',
            'pipeline_started',
            1,
            PARSE_JSON('{"action": "start_pipeline", "initiated_by": "manual"}')
        );
    EXCEPTION
        WHEN OTHER THEN
            -- Ignore if monitoring table doesn't exist yet
            NULL;
    END;
    
    result := 'Data pipeline started successfully. All tasks are now running.';
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error starting data pipeline: ' || SQLERRM;
END;
$$;

-- Procedure to stop the entire data pipeline
CREATE OR ALTER PROCEDURE stop_data_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
BEGIN
    -- Suspend all data pipeline tasks
    ALTER TASK customer_analytics_task SUSPEND;
    ALTER TASK product_analytics_task SUSPEND;
    ALTER TASK order_metrics_task SUSPEND;
    ALTER TASK order_items_analytics_task SUSPEND;
    ALTER TASK data_pipeline_orchestrator SUSPEND;
    
    -- Log the pipeline stop (with error handling)
    BEGIN
        INSERT INTO monitoring.system_metrics (
            metric_id,
            metric_type,
            metric_name,
            metric_value,
            tags
        ) VALUES (
            'PIPELINE_STOP_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'data_pipeline',
            'pipeline_stopped',
            0,
            PARSE_JSON('{"action": "stop_pipeline", "initiated_by": "manual"}')
        );
    EXCEPTION
        WHEN OTHER THEN
            -- Ignore if monitoring table doesn't exist yet
            NULL;
    END;
    
    result := 'Data pipeline stopped successfully. All tasks are now suspended.';
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error stopping data pipeline: ' || SQLERRM;
END;
$$;

-- Procedure to check data pipeline health
CREATE OR ALTER PROCEDURE check_data_pipeline_health()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    recent_errors NUMBER;
    pending_streams NUMBER;
    health_status STRING;
    result STRING;
BEGIN
    -- Count recent errors (last hour) - with error handling for missing table
    BEGIN
        SELECT COUNT(*)
        INTO recent_errors
        FROM monitoring.task_errors
        WHERE error_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
        AND error_category = 'DATA_PIPELINE'
        AND resolved = FALSE;
    EXCEPTION
        WHEN OTHER THEN
            recent_errors := 0; -- Default to 0 if monitoring table doesn't exist yet
    END;
    
    -- Count streams with pending data
    SELECT 
        CASE WHEN SYSTEM$STREAM_HAS_DATA('customers_stream') THEN 1 ELSE 0 END +
        CASE WHEN SYSTEM$STREAM_HAS_DATA('products_stream') THEN 1 ELSE 0 END +
        CASE WHEN SYSTEM$STREAM_HAS_DATA('orders_stream') THEN 1 ELSE 0 END +
        CASE WHEN SYSTEM$STREAM_HAS_DATA('order_items_stream') THEN 1 ELSE 0 END
    INTO pending_streams;
    
    -- Determine overall health (simplified without task counting)
    IF (recent_errors = 0 AND pending_streams <= 1) THEN
        health_status := 'HEALTHY';
    ELSEIF (recent_errors <= 2) THEN
        health_status := 'WARNING';
    ELSE
        health_status := 'UNHEALTHY';
    END IF;
    
    result := 'Pipeline Health: ' || health_status || 
              ' | Recent Errors: ' || recent_errors ||
              ' | Streams with Pending Data: ' || pending_streams ||
              ' | Use SHOW TASKS to check task status manually';
    
    -- Log the health check (with error handling for missing table)
    BEGIN
        INSERT INTO monitoring.system_metrics (
            metric_id,
            metric_type,
            metric_name,
            metric_value,
            tags
        ) VALUES (
            'HEALTH_CHECK_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'data_pipeline',
            'health_check',
            CASE health_status 
                WHEN 'HEALTHY' THEN 1 
                WHEN 'WARNING' THEN 0.5 
                ELSE 0 
            END,
            PARSE_JSON('{"recent_errors": ' || recent_errors || 
                      ', "pending_streams": ' || pending_streams || '}')
        );
    EXCEPTION
        WHEN OTHER THEN
            -- Ignore if monitoring table doesn't exist yet
            NULL;
    END;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error checking pipeline health: ' || SQLERRM;
END;
$$;

-- Procedure to manually trigger processing for all streams
CREATE OR ALTER PROCEDURE force_pipeline_processing()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
    processing_results ARRAY;
BEGIN
    processing_results := ARRAY_CONSTRUCT();
    
    -- Force process customers if stream has data
    IF (SYSTEM$STREAM_HAS_DATA('customers_stream')) THEN
        CALL processed_data.process_customer_changes();
        processing_results := ARRAY_APPEND(processing_results, 'customers');
    END IF;
    
    -- Force process products if stream has data
    IF (SYSTEM$STREAM_HAS_DATA('products_stream')) THEN
        CALL processed_data.process_product_changes();
        processing_results := ARRAY_APPEND(processing_results, 'products');
    END IF;
    
    -- Force process orders if stream has data
    IF (SYSTEM$STREAM_HAS_DATA('orders_stream')) THEN
        CALL processed_data.process_order_changes();
        processing_results := ARRAY_APPEND(processing_results, 'orders');
    END IF;
    
    -- Force process order items (this will trigger product and customer analytics)
    IF (SYSTEM$STREAM_HAS_DATA('order_items_stream')) THEN
        CALL processed_data.process_product_changes();
        CALL processed_data.process_customer_changes();
        processing_results := ARRAY_APPEND(processing_results, 'order_items');
    END IF;
    
    IF (ARRAY_SIZE(processing_results) > 0) THEN
        result := 'Forced processing completed for: ' || ARRAY_TO_STRING(processing_results, ', ');
    ELSE
        result := 'No pending data found in streams. Nothing to process.';
    END IF;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error during forced processing: ' || SQLERRM;
END;
$$;

-- ============================================
-- TESTING AND VALIDATION PROCEDURES
-- ============================================

-- Procedure to test the data pipeline with sample data
CREATE OR ALTER PROCEDURE test_data_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    test_customer_id STRING;
    test_product_id STRING;
    test_order_id STRING;
    result STRING;
BEGIN
    -- Create a test customer
    test_customer_id := 'TEST_CUST_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    
    INSERT INTO customers (
        customer_id, customer_name, email, customer_tier, is_active
    ) VALUES (
        test_customer_id, 'Test Customer Pipeline', 'test@pipeline.com', 'STANDARD', TRUE
    );
    
    -- Create a test product
    test_product_id := 'TEST_PROD_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    
    INSERT INTO products (
        product_id, product_name, category, price, cost, is_active, inventory_count
    ) VALUES (
        test_product_id, 'Test Product Pipeline', 'Test Category', 100.00, 60.00, TRUE, 50
    );
    
    -- Create a test order
    test_order_id := 'TEST_ORDER_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    
    INSERT INTO orders (
        order_id, customer_id, total_amount, status
    ) VALUES (
        test_order_id, test_customer_id, 100.00, 'COMPLETED'
    );
    
    -- Create test order item
    INSERT INTO order_items (
        order_item_id, order_id, product_id, quantity, unit_price, total_price
    ) VALUES (
        'TEST_OI_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        test_order_id, test_product_id, 1, 100.00, 100.00
    );
    
    -- Wait a moment for streams to capture changes
    CALL SYSTEM$WAIT(2);
    
    -- Check if streams have the test data
    result := 'Test data inserted. Stream status: ' ||
              'Customers: ' || CASE WHEN SYSTEM$STREAM_HAS_DATA('customers_stream') THEN 'HAS_DATA' ELSE 'NO_DATA' END ||
              ', Products: ' || CASE WHEN SYSTEM$STREAM_HAS_DATA('products_stream') THEN 'HAS_DATA' ELSE 'NO_DATA' END ||
              ', Orders: ' || CASE WHEN SYSTEM$STREAM_HAS_DATA('orders_stream') THEN 'HAS_DATA' ELSE 'NO_DATA' END ||
              ', Order Items: ' || CASE WHEN SYSTEM$STREAM_HAS_DATA('order_items_stream') THEN 'HAS_DATA' ELSE 'NO_DATA' END;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error testing data pipeline: ' || SQLERRM;
END;
$$;

-- Grant permissions on all management objects
GRANT USAGE ON PROCEDURE get_pipeline_metrics() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE get_pipeline_task_status() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE get_pipeline_stream_status() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE start_data_pipeline() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE stop_data_pipeline() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE check_data_pipeline_health() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE force_pipeline_processing() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE test_data_pipeline() TO ROLE PUBLIC;