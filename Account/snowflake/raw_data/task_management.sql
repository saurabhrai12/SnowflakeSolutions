-- Task Management and Control Scripts
-- Commands to manage Snowflake tasks

USE DATABASE {{ database }};
USE SCHEMA raw_data;

-- ============================================
-- TASK CONTROL COMMANDS
-- ============================================

-- To ENABLE tasks (run these after testing):
-- ALTER TASK job_processor_task RESUME;
-- ALTER TASK job_cleanup_task RESUME;
-- ALTER TASK daily_metrics_task RESUME;

-- To DISABLE tasks:
-- ALTER TASK job_processor_task SUSPEND;
-- ALTER TASK job_cleanup_task SUSPEND;
-- ALTER TASK daily_metrics_task SUSPEND;

-- ============================================
-- MONITORING QUERIES
-- ============================================

-- Note: Task and stream monitoring queries
-- Use SHOW commands instead of information_schema for better compatibility

-- Query to check task status (use SHOW TASKS)
-- SHOW TASKS IN DATABASE analytics_platform;

-- Query to check task history (use account_usage if available)
-- SELECT * FROM snowflake.account_usage.task_history 
-- WHERE database_name = 'ANALYTICS_PLATFORM' 
-- ORDER BY query_start_time DESC LIMIT 10;

-- Query to check streams (use SHOW STREAMS)
-- SHOW STREAMS IN DATABASE analytics_platform;

-- Simplified monitoring procedures instead of views
CREATE OR ALTER PROCEDURE show_task_status()
RETURNS TABLE(task_name STRING, state STRING, warehouse STRING, schedule STRING)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (SHOW TASKS IN DATABASE analytics_platform);
    RETURN TABLE(res);
END;
$$;

CREATE OR ALTER PROCEDURE show_stream_status() 
RETURNS TABLE(stream_name STRING, table_name STRING, owner STRING, comment STRING)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (SHOW STREAMS IN DATABASE analytics_platform);
    RETURN TABLE(res);
END;
$$;

-- ============================================
-- MANUAL TASK EXECUTION
-- ============================================

-- Manually execute job processor (for testing)
-- EXECUTE TASK job_processor_task;

-- Manually execute cleanup task
-- EXECUTE TASK job_cleanup_task;

-- Manually execute daily metrics
-- EXECUTE TASK daily_metrics_task;

-- ============================================
-- TESTING PROCEDURES
-- ============================================

-- Procedure to test job processing pipeline
CREATE OR ALTER PROCEDURE test_job_pipeline()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    test_job_id STRING;
    result STRING;
BEGIN
    -- Create a test job
    SELECT raw_data.create_job(
        'Test Report Generation',
        'REPORT',
        'test_user',
        PARSE_JSON('{"report_type": "sales", "date_range": "yesterday", "format": "PDF"}'),
        1
    ) INTO result;
    
    -- Extract job ID
    test_job_id := SPLIT_PART(result, ': ', 2);
    
    -- Wait a moment for stream to capture
    CALL SYSTEM$WAIT(2);
    
    -- Check if stream has data
    IF (SYSTEM$STREAM_HAS_DATA('job_stream')) THEN
        result := 'Test successful - Job ' || test_job_id || ' created and stream has data. Execute job_processor_task to process.';
    ELSE
        result := 'Test incomplete - Job ' || test_job_id || ' created but stream may not have captured yet.';
    END IF;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Test failed: ' || SQLERRM;
END;
$$;

-- Procedure to check system health
CREATE OR ALTER PROCEDURE check_system_health()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    pending_jobs NUMBER;
    failed_jobs NUMBER;
    running_jobs NUMBER;
    recent_errors NUMBER;
    result STRING;
BEGIN
    -- Count job statuses
    SELECT 
        COUNT(CASE WHEN status = 'PENDING' THEN 1 END),
        COUNT(CASE WHEN status = 'FAILED' AND retry_count >= max_retries THEN 1 END),
        COUNT(CASE WHEN status = 'RUNNING' THEN 1 END)
    INTO pending_jobs, failed_jobs, running_jobs
    FROM jobs
    WHERE created_at >= DATEADD('day', -1, CURRENT_TIMESTAMP());
    
    -- Count recent errors
    SELECT COUNT(*)
    INTO recent_errors
    FROM monitoring.task_errors
    WHERE error_timestamp >= DATEADD('hour', -1, CURRENT_TIMESTAMP())
    AND resolved = FALSE;
    
    result := 'System Health Summary: ' ||
              'Pending Jobs: ' || pending_jobs || ', ' ||
              'Failed Jobs: ' || failed_jobs || ', ' ||
              'Running Jobs: ' || running_jobs || ', ' ||
              'Recent Errors: ' || recent_errors;
    
    -- Determine overall health
    IF (failed_jobs > 5 OR recent_errors > 3) THEN
        result := result || ' - STATUS: UNHEALTHY';
    ELSEIF (failed_jobs > 0 OR recent_errors > 0) THEN
        result := result || ' - STATUS: WARNING';
    ELSE
        result := result || ' - STATUS: HEALTHY';
    END IF;
    
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Health check failed: ' || SQLERRM;
END;
$$;

-- Grant permissions
GRANT USAGE ON PROCEDURE show_task_status() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE show_stream_status() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE test_job_pipeline() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE check_system_health() TO ROLE PUBLIC; 