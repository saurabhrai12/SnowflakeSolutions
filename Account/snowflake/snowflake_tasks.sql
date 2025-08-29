-- Snowflake Tasks for Automated Report Generation via ECS
-- This script creates automated tasks that call the ECS report service

-- Resume the task warehouse if it's suspended
-- ALTER WAREHOUSE analytics_wh RESUME IF SUSPENDED;

-- Create a task to generate daily reports via ECS
CREATE OR REPLACE TASK reporting.daily_reports_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = 'USING CRON 0 6 * * * UTC'  -- Run daily at 6 AM UTC
    COMMENT = 'Daily automated report generation via ECS service'
AS
    CALL reporting.generate_daily_reports();

-- Create a task to generate weekly executive dashboard
CREATE OR REPLACE TASK reporting.weekly_executive_dashboard_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = 'USING CRON 0 8 * * 1 UTC'  -- Run weekly on Monday at 8 AM UTC
    COMMENT = 'Weekly executive dashboard generation via ECS service'
AS
    SELECT reporting.generate_report_via_ecs(
        'WEEKLY_EXEC_' || REPLACE(UUID_STRING(), '-', '_'),
        'EXECUTIVE_DASHBOARD',
        OBJECT_CONSTRUCT(
            'start_date', DATEADD(week, -1, CURRENT_DATE())::STRING,
            'end_date', CURRENT_DATE()::STRING,
            'include_trends', true,
            'include_forecasts', true,
            'format', 'json'
        ),
        'snowflake-weekly-automation'
    );

-- Create a task to generate monthly data quality reports
CREATE OR REPLACE TASK reporting.monthly_data_quality_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = 'USING CRON 0 7 1 * * UTC'  -- Run monthly on 1st day at 7 AM UTC
    COMMENT = 'Monthly data quality report generation via ECS service'
AS
    SELECT reporting.generate_report_via_ecs(
        'MONTHLY_DQ_' || REPLACE(UUID_STRING(), '-', '_'),
        'DATA_QUALITY',
        OBJECT_CONSTRUCT(
            'start_date', DATEADD(month, -1, DATE_TRUNC('month', CURRENT_DATE()))::STRING,
            'end_date', DATE_TRUNC('month', CURRENT_DATE())::STRING,
            'scope', 'all_schemas',
            'include_metrics', true,
            'format', 'json'
        ),
        'snowflake-monthly-automation'
    );

-- Create a task to monitor failed ECS jobs and retry them
CREATE OR REPLACE TASK monitoring.ecs_job_retry_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = 'USING CRON */15 * * * * UTC'  -- Run every 15 minutes
    COMMENT = 'Monitor and retry failed ECS jobs'
AS
    -- This would typically query a job tracking table and retry failed jobs
    -- For now, we'll create a placeholder that could be expanded
    SELECT 'ECS job monitoring task executed at ' || CURRENT_TIMESTAMP()::STRING as message;

-- Grant necessary privileges for task execution
GRANT EXECUTE TASK ON ACCOUNT TO ROLE ACCOUNTADMIN;

-- Start the tasks (they are created in suspended state by default)
ALTER TASK reporting.daily_reports_task RESUME;
ALTER TASK reporting.weekly_executive_dashboard_task RESUME;
ALTER TASK reporting.monthly_data_quality_task RESUME;
ALTER TASK monitoring.ecs_job_retry_task RESUME;

-- Show all tasks and their status
SHOW TASKS IN SCHEMA reporting;
SHOW TASKS IN SCHEMA monitoring;

-- Check task execution history
-- SELECT *
-- FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
-- WHERE TASK_NAME IN ('DAILY_REPORTS_TASK', 'WEEKLY_EXECUTIVE_DASHBOARD_TASK', 'MONTHLY_DATA_QUALITY_TASK')
-- ORDER BY SCHEDULED_TIME DESC
-- LIMIT 50;