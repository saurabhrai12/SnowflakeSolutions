-- Pipeline Monitoring Procedures
-- Called by tasks for health monitoring and error handling

USE DATABASE {{ database }};
USE SCHEMA raw_data;

-- Drop existing procedures if they exist
DROP PROCEDURE IF EXISTS monitor_pipeline_health();
DROP PROCEDURE IF EXISTS log_task_execution(STRING, STRING, STRING);
DROP PROCEDURE IF EXISTS log_task_error(STRING, STRING);
DROP PROCEDURE IF EXISTS process_order_items_changes();
DROP PROCEDURE IF EXISTS process_job_stream();
DROP PROCEDURE IF EXISTS cleanup_jobs_and_monitoring();
DROP PROCEDURE IF EXISTS generate_daily_metrics_and_checks();

-- Procedure for pipeline health monitoring (called by orchestrator task)
CREATE PROCEDURE monitor_pipeline_health()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    error_count NUMBER;
    pipeline_health STRING;
    streams_with_data NUMBER := 0;
    processing_summary STRING;
BEGIN
    -- Check for recent errors in the last hour
    SELECT COUNT(*)
    INTO error_count
    FROM monitoring.task_errors
    WHERE error_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    AND error_category = 'DATA_PIPELINE'
    AND resolved = FALSE;
    
    -- Count streams with pending data
    IF (SYSTEM$STREAM_HAS_DATA('customers_stream')) THEN
        streams_with_data := streams_with_data + 1;
    END IF;
    
    IF (SYSTEM$STREAM_HAS_DATA('products_stream')) THEN
        streams_with_data := streams_with_data + 1;
    END IF;
    
    IF (SYSTEM$STREAM_HAS_DATA('orders_stream')) THEN
        streams_with_data := streams_with_data + 1;
    END IF;
    
    IF (SYSTEM$STREAM_HAS_DATA('order_items_stream')) THEN
        streams_with_data := streams_with_data + 1;
    END IF;
    
    -- Determine pipeline health
    IF (error_count = 0) THEN
        pipeline_health := 'HEALTHY';
    ELSEIF (error_count <= 3) THEN
        pipeline_health := 'WARNING';
    ELSE
        pipeline_health := 'UNHEALTHY';
    END IF;
    
    -- Log pipeline status
    INSERT INTO monitoring.system_metrics (
        metric_id,
        metric_type,
        metric_name,
        metric_value,
        tags
    ) VALUES (
        'PIPELINE_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        'data_pipeline',
        'pipeline_health_check',
        CASE pipeline_health 
            WHEN 'HEALTHY' THEN 1 
            WHEN 'WARNING' THEN 0.5 
            ELSE 0 
        END,
        PARSE_JSON('{"health_status": "' || pipeline_health || 
                   '", "error_count": ' || error_count || 
                   ', "streams_with_data": ' || streams_with_data || '}')
    );
    
    -- If there are many errors, mark old ones as resolved
    IF (error_count > 5) THEN
        UPDATE monitoring.task_errors 
        SET resolved = TRUE,
            resolution_notes = 'Auto-resolved by orchestrator due to high error volume'
        WHERE error_timestamp < DATEADD('day', -1, CURRENT_TIMESTAMP())
        AND error_category = 'DATA_PIPELINE'
        AND resolved = FALSE;
    END IF;
    
    processing_summary := 'Pipeline Health: ' || pipeline_health || 
                         ' | Recent Errors: ' || error_count || 
                         ' | Streams with Data: ' || streams_with_data;
    
    RETURN processing_summary;
    
EXCEPTION
    WHEN OTHER THEN
        -- Log the error
        INSERT INTO monitoring.task_errors (
            error_id,
            task_name,
            error_message,
            error_timestamp,
            error_category,
            severity
        ) VALUES (
            'ERR_MONITOR_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'monitor_pipeline_health',
            'Pipeline monitoring failed: Unknown error',
            CURRENT_TIMESTAMP(),
            'DATA_PIPELINE',
            'CRITICAL'
        );
        
        RETURN 'Pipeline monitoring failed: Unknown error';
END;
$$;

-- Procedure to log task execution (can be called by tasks)
CREATE PROCEDURE log_task_execution(
    task_name STRING,
    execution_status STRING,
    details STRING DEFAULT NULL
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO monitoring.system_metrics (
        metric_id,
        metric_type,
        metric_name,
        metric_value,
        tags
    ) VALUES (
        'TASK_' || task_name || '_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        'task_execution',
        'task_run',
        CASE execution_status 
            WHEN 'SUCCESS' THEN 1 
            WHEN 'WARNING' THEN 0.5 
            ELSE 0 
        END,
        PARSE_JSON('{"task_name": "' || task_name || 
                   '", "status": "' || execution_status || 
                   '", "details": "' || COALESCE(details, '') || '"}')
    );
    
    RETURN 'Task execution logged: ' || task_name || ' - ' || execution_status;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error logging task execution: ' || 'Unknown error';
END;
$$;

-- Procedure to handle task errors (simplified error logging)
CREATE PROCEDURE log_task_error(
    task_name STRING,
    error_message STRING
)
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO monitoring.task_errors (
        error_id,
        task_name,
        error_message,
        error_timestamp,
        error_category,
        severity
    ) VALUES (
        'ERR_' || task_name || '_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        task_name,
        error_message,
        CURRENT_TIMESTAMP(),
        'DATA_PIPELINE',
        'HIGH'
    );
    
    RETURN 'Error logged for task: ' || task_name;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Failed to log error: ' || 'Unknown error';
END;
$$;

-- Procedure to handle order items changes (calls multiple procedures)
CREATE PROCEDURE process_order_items_changes()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    changes_count NUMBER := 0;
    result STRING;
BEGIN
    -- Check if there are any changes in the stream
    SELECT COUNT(*) INTO changes_count 
    FROM order_items_stream;
    
    IF (changes_count = 0) THEN
        RETURN 'No order items changes to process';
    END IF;
    
    -- Refresh product analytics when order items change
    CALL processed_data.process_product_changes();
    
    -- Also refresh customer analytics as purchase patterns may have changed
    CALL processed_data.process_customer_changes();
    
    result := 'Processed ' || changes_count || ' order items changes and refreshed analytics';
    
    -- Log the processing
    INSERT INTO monitoring.system_metrics (
        metric_id,
        metric_type,
        metric_name,
        metric_value,
        tags
    ) VALUES (
        'OI_PROC_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        'data_processing',
        'order_items_processed',
        changes_count,
        PARSE_JSON('{"procedure": "process_order_items_changes", "schema": "raw_data"}')
    );
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        -- Log the error
        INSERT INTO monitoring.task_errors (
            error_id,
            task_name,
            error_message,
            error_timestamp,
            error_category,
            severity
        ) VALUES (
            'ERR_OI_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'process_order_items_changes',
            'Order items processing failed: ' || 'Unknown error',
            CURRENT_TIMESTAMP(),
            'DATA_PIPELINE',
            'HIGH'
        );
        
        RETURN 'Error processing order items changes: ' || 'Unknown error';
END;
$$;

-- Procedure to process job stream (called by job_processor_task)
CREATE PROCEDURE process_job_stream()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    job_cursor CURSOR FOR 
        SELECT job_id, job_type, input_data, priority, status, created_at
        FROM job_stream
        WHERE METADATA$ACTION = 'INSERT'
        AND status = 'PENDING';
    
    current_job_id STRING;
    current_job_type STRING;
    current_input_data VARIANT;
    current_priority NUMBER;
    jobs_processed NUMBER := 0;
    processing_result VARIANT;
    result_message STRING;
BEGIN
    -- Process each job from the stream
    FOR job_record IN job_cursor DO
        current_job_id := job_record.job_id;
        current_job_type := job_record.job_type;
        current_input_data := job_record.input_data;
        current_priority := job_record.priority;
        
        BEGIN
            -- Update job status to PROCESSING
            UPDATE jobs 
            SET status = 'PROCESSING',
                updated_at = CURRENT_TIMESTAMP()
            WHERE job_id = current_job_id;
            
            -- Call external function to trigger ECS app
            SELECT call_ecs_python_app(
                OBJECT_CONSTRUCT(
                    'job_id', current_job_id,
                    'job_type', current_job_type,
                    'input_data', current_input_data,
                    'priority', current_priority
                )
            ) INTO processing_result;
            
            -- Check if call was successful
            IF (processing_result:status::STRING = 'accepted') THEN
                -- Update job with ECS tracking information
                UPDATE jobs 
                SET status = 'SENT_TO_ECS',
                    updated_at = CURRENT_TIMESTAMP(),
                    output_data = processing_result
                WHERE job_id = current_job_id;
                
                jobs_processed := jobs_processed + 1;
                
                -- Log successful processing
                CALL log_task_execution('process_job_stream', 'SUCCESS', 
                    'Job ' || current_job_id || ' sent to ECS successfully');
                    
            ELSE
                -- Handle processing error
                UPDATE jobs 
                SET status = 'FAILED',
                    updated_at = CURRENT_TIMESTAMP(),
                    error_message = 'ECS call failed: ' || processing_result:error::STRING,
                    retry_count = retry_count + 1
                WHERE job_id = current_job_id;
                
                -- Log the error
                CALL log_task_error('process_job_stream', 
                    'Job ' || current_job_id || ' failed: ' || processing_result:error::STRING);
            END IF;
            
        EXCEPTION
            WHEN OTHER THEN
                -- Handle any processing errors
                UPDATE jobs 
                SET status = 'FAILED',
                    updated_at = CURRENT_TIMESTAMP(),
                    error_message = 'Processing error: ' || 'Unknown error',
                    retry_count = retry_count + 1
                WHERE job_id = current_job_id;
                
                -- Log the error
                CALL log_task_error('process_job_stream', 
                    'Job ' || current_job_id || ' processing error: ' || 'Unknown error');
        END;
    END FOR;
    
    -- Log processing summary (with error handling)
    BEGIN
        INSERT INTO monitoring.system_metrics (
            metric_id,
            metric_type,
            metric_name,
            metric_value,
            tags
        ) VALUES (
            'JOB_PROC_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'job_processing',
            'jobs_processed_count',
            jobs_processed,
            PARSE_JSON('{"procedure": "process_job_stream", "task": "job_processor_task"}')
        );
    EXCEPTION
        WHEN OTHER THEN
            -- Ignore if monitoring table doesn't exist yet
            NULL;
    END;
    
    result_message := 'Processed ' || jobs_processed || ' jobs from stream';
    RETURN result_message;
    
EXCEPTION
    WHEN OTHER THEN
        -- Log critical error
        INSERT INTO monitoring.task_errors (
            error_id,
            task_name,
            error_message,
            error_timestamp,
            error_category,
            severity
        ) VALUES (
            'ERR_JOB_PROC_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'process_job_stream',
            'Job stream processing failed: ' || 'Unknown error',
            CURRENT_TIMESTAMP(),
            'JOB_PROCESSING',
            'CRITICAL'
        );
        
        RETURN 'Error processing job stream: ' || 'Unknown error';
END;
$$;

-- Procedure for job cleanup and maintenance (called by job_cleanup_task)
CREATE PROCEDURE cleanup_jobs_and_monitoring()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    cleanup_stats VARIANT;
    old_jobs_count NUMBER;
    retry_jobs_count NUMBER;
BEGIN
    -- Clean up old completed jobs (older than 30 days)
    DELETE FROM jobs 
    WHERE status = 'COMPLETED' 
    AND created_at < DATEADD('day', -30, CURRENT_TIMESTAMP());
    old_jobs_count := SQLROWCOUNT;
    
    -- Auto-retry failed jobs that haven't exceeded max retries
    UPDATE jobs 
    SET status = 'PENDING',
        retry_count = retry_count + 1,
        updated_at = CURRENT_TIMESTAMP(),
        error_message = NULL
    WHERE status = 'FAILED'
    AND retry_count < max_retries
    AND updated_at < DATEADD('minute', -10, CURRENT_TIMESTAMP());
    retry_jobs_count := SQLROWCOUNT;
    
    -- Clean up old monitoring data
    CALL monitoring.cleanup_monitoring_data(7);
    
    -- Log cleanup metrics
    INSERT INTO monitoring.system_metrics (
        metric_id,
        metric_type,
        metric_name,
        metric_value,
        tags
    ) VALUES (
        'METRIC_CLEANUP_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        'maintenance',
        'jobs_cleaned_up',
        old_jobs_count,
        PARSE_JSON('{"task_name": "job_cleanup_task", "action": "cleanup"}')
    ),
    (
        'METRIC_RETRY_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
        'maintenance',
        'jobs_retried',
        retry_jobs_count,
        PARSE_JSON('{"task_name": "job_cleanup_task", "action": "retry"}')
    );
    
    RETURN 'Cleanup completed: ' || old_jobs_count || ' old jobs removed, ' || retry_jobs_count || ' jobs retried';
    
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO monitoring.task_errors (
            error_id,
            task_name,
            error_message,
            error_timestamp,
            error_category,
            severity
        ) VALUES (
            'ERR_CLEANUP_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'job_cleanup_task',
            'Cleanup task error: ' || 'Unknown error',
            CURRENT_TIMESTAMP(),
            'MAINTENANCE',
            'MEDIUM'
        );
        RETURN 'Cleanup failed with error: ' || 'Unknown error';
END;
$$;

-- Procedure for daily metrics generation (called by daily_metrics_task)
CREATE PROCEDURE generate_daily_metrics_and_checks()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
    -- Generate daily metrics for yesterday
    CALL processed_data.generate_daily_metrics(DATEADD('day', -1, CURRENT_DATE()));
    
    -- Run data quality checks
    CALL monitoring.run_data_quality_checks();
    
    -- Calculate customer analytics
    CALL processed_data.calculate_customer_analytics();
    
    RETURN 'Daily metrics and quality checks completed for ' || DATEADD('day', -1, CURRENT_DATE());
    
EXCEPTION
    WHEN OTHER THEN
        INSERT INTO monitoring.task_errors (
            error_id,
            task_name,
            error_message,
            error_timestamp,
            error_category,
            severity
        ) VALUES (
            'ERR_DAILY_' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
            'daily_metrics_task',
            'Daily metrics task error: ' || 'Unknown error',
            CURRENT_TIMESTAMP(),
            'ANALYTICS',
            'HIGH'
        );
        RETURN 'Daily metrics failed with error: ' || 'Unknown error';
END;
$$;

-- Grant permissions
GRANT USAGE ON PROCEDURE monitor_pipeline_health() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE log_task_execution(STRING, STRING, STRING) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE log_task_error(STRING, STRING) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE process_order_items_changes() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE process_job_stream() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE cleanup_jobs_and_monitoring() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE generate_daily_metrics_and_checks() TO ROLE PUBLIC;