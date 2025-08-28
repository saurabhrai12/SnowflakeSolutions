-- Data Pipeline Tasks for Automated Raw to Processed Data Movement
-- Uses streams to trigger processing only when data changes

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- Drop existing tasks if they exist
DROP TASK IF EXISTS data_pipeline_orchestrator;
DROP TASK IF EXISTS order_items_analytics_task;
DROP TASK IF EXISTS order_metrics_task;
DROP TASK IF EXISTS product_analytics_task;
DROP TASK IF EXISTS customer_analytics_task;

-- Task to process customer changes
CREATE OR ALTER TASK customer_analytics_task
    WAREHOUSE = analytics_wh
    SCHEDULE = '2 minute'  -- Check every 2 minutes
    WHEN SYSTEM$STREAM_HAS_DATA('customers_stream')
    AS
    CALL processed_data.process_customer_changes();

-- Task to process product changes
CREATE OR ALTER TASK product_analytics_task
    WAREHOUSE = analytics_wh
    SCHEDULE = '2 minute'  -- Check every 2 minutes
    WHEN SYSTEM$STREAM_HAS_DATA('products_stream')
    AS
    CALL processed_data.process_product_changes();

-- Task to process order changes and update metrics
CREATE OR ALTER TASK order_metrics_task
    WAREHOUSE = analytics_wh
    SCHEDULE = '1 minute'  -- More frequent for order processing
    WHEN SYSTEM$STREAM_HAS_DATA('orders_stream')
    AS
    CALL processed_data.process_order_changes();

-- Task to process order items changes (for product analytics)
CREATE OR ALTER TASK order_items_analytics_task
    WAREHOUSE = analytics_wh
    SCHEDULE = '3 minute'  -- Less frequent as it's more for detailed analytics
    WHEN SYSTEM$STREAM_HAS_DATA('order_items_stream')
    AS
    CALL process_order_items_changes();

-- Master data pipeline orchestration task
CREATE OR ALTER TASK data_pipeline_orchestrator
    WAREHOUSE = analytics_wh
    SCHEDULE = '5 minute'  -- Runs every 5 minutes to check overall pipeline health
    AS
    CALL monitor_pipeline_health();

-- Initially suspend all tasks for safety (enable manually after testing)
ALTER TASK customer_analytics_task SUSPEND;
ALTER TASK product_analytics_task SUSPEND;
ALTER TASK order_metrics_task SUSPEND;
ALTER TASK order_items_analytics_task SUSPEND;
ALTER TASK data_pipeline_orchestrator SUSPEND;

-- Add task comments for documentation
ALTER TASK customer_analytics_task SET COMMENT = 'Processes customer changes from stream and updates customer analytics in processed_data schema';
ALTER TASK product_analytics_task SET COMMENT = 'Processes product changes from stream and updates product analytics in processed_data schema';
ALTER TASK order_metrics_task SET COMMENT = 'Processes order changes from stream and updates daily/monthly metrics in processed_data schema';
ALTER TASK order_items_analytics_task SET COMMENT = 'Processes order items changes and refreshes related analytics';
ALTER TASK data_pipeline_orchestrator SET COMMENT = 'Monitors overall data pipeline health and provides automated remediation';

-- Grant necessary permissions
GRANT MONITOR ON TASK customer_analytics_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK product_analytics_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK order_metrics_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK order_items_analytics_task TO ROLE PUBLIC;
GRANT MONITOR ON TASK data_pipeline_orchestrator TO ROLE PUBLIC;