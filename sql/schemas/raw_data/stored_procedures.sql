-- Raw Data Schema Stored Procedures
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- Procedure to process new orders and update metrics
CREATE OR ALTER PROCEDURE process_order(order_id STRING)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    customer_id STRING;
    total_amount NUMBER(12,2);
    order_date DATE;
    result STRING;
BEGIN
    -- Get order details
    SELECT o.customer_id, o.total_amount, o.order_date::DATE
    INTO customer_id, total_amount, order_date
    FROM orders o
    WHERE o.order_id = :order_id;
    
    -- Update customer lifetime value
    UPDATE customers 
    SET lifetime_value = lifetime_value + :total_amount,
        updated_at = CURRENT_TIMESTAMP()
    WHERE customer_id = :customer_id;
    
    -- Update or insert daily sales metrics
    MERGE INTO processed_data.sales_metrics AS target
    USING (
        SELECT 
            'SM_' || TO_CHAR(:order_date, 'YYYYMMDD') AS metric_id,
            :order_date AS metric_date,
            :total_amount AS daily_sales,
            1 AS daily_orders,
            1 AS daily_customers,
            :total_amount AS avg_order_value
    ) AS source
    ON target.metric_id = source.metric_id
    WHEN MATCHED THEN UPDATE SET
        total_sales = target.total_sales + source.daily_sales,
        total_orders = target.total_orders + source.daily_orders,
        average_order_value = target.total_sales / target.total_orders,
        updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        metric_id, metric_date, total_sales, total_orders, 
        unique_customers, average_order_value
    ) VALUES (
        source.metric_id, source.metric_date, source.daily_sales,
        source.daily_orders, source.daily_customers, source.avg_order_value
    );
    
    result := 'Order ' || :order_id || ' processed successfully';
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error processing order ' || :order_id || ': ' || SQLERRM;
END;
$$;

-- Procedure to create and track jobs
CREATE OR ALTER PROCEDURE create_job(
    job_name STRING,
    job_type STRING,
    created_by STRING,
    input_data VARIANT,
    priority NUMBER DEFAULT 3
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    job_id STRING;
    result STRING;
BEGIN
    -- Generate unique job ID
    job_id := 'JOB_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS') || '_' || ABS(RANDOM());
    
    -- Insert new job
    INSERT INTO jobs (
        job_id, job_name, job_type, status, created_by,
        input_data, priority, created_at, updated_at
    ) VALUES (
        :job_id, :job_name, :job_type, 'PENDING', :created_by,
        :input_data, :priority, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP()
    );
    
    result := 'Job created with ID: ' || :job_id;
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error creating job: ' || SQLERRM;
END;
$$;

-- Procedure to update job status
CREATE OR ALTER PROCEDURE update_job_status(
    job_id STRING,
    new_status STRING,
    output_location STRING DEFAULT NULL,
    error_message STRING DEFAULT NULL,
    execution_time NUMBER DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
BEGIN
    UPDATE jobs 
    SET status = :new_status,
        output_location = COALESCE(:output_location, output_location),
        error_message = :error_message,
        execution_time_seconds = COALESCE(:execution_time, execution_time_seconds),
        updated_at = CURRENT_TIMESTAMP()
    WHERE job_id = :job_id;
    
    IF (SQLROWCOUNT = 0) THEN
        result := 'Job not found: ' || :job_id;
    ELSE
        result := 'Job ' || :job_id || ' status updated to ' || :new_status;
    END IF;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error updating job status: ' || SQLERRM;
END;
$$;