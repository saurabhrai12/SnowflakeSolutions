-- Permissions and Security Setup
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE {{ database }};

-- Grant schema usage permissions
GRANT USAGE ON SCHEMA raw_data TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA processed_data TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA reporting TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA monitoring TO ROLE PUBLIC;

-- Grant table permissions for raw_data schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw_data TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA raw_data TO ROLE PUBLIC;

-- Grant table permissions for processed_data schema
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA processed_data TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA processed_data TO ROLE PUBLIC;

-- Grant view permissions for reporting schema
GRANT SELECT ON ALL VIEWS IN SCHEMA reporting TO ROLE PUBLIC;

-- Grant monitoring permissions
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA monitoring TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA monitoring TO ROLE PUBLIC;

-- Grant stored procedure permissions for raw_data
GRANT USAGE ON PROCEDURE raw_data.process_order(STRING) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE raw_data.create_job(STRING, STRING, STRING, VARIANT, NUMBER) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE raw_data.update_job_status(STRING, STRING, STRING, STRING, NUMBER) TO ROLE PUBLIC;

-- Grant stored procedure permissions for processed_data
GRANT USAGE ON PROCEDURE processed_data.calculate_customer_analytics() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE processed_data.generate_daily_metrics(DATE) TO ROLE PUBLIC;

-- Grant stored procedure permissions for monitoring
GRANT USAGE ON PROCEDURE monitoring.run_data_quality_checks() TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE monitoring.log_system_metric(STRING, STRING, NUMBER, STRING, VARIANT) TO ROLE PUBLIC;
GRANT USAGE ON PROCEDURE monitoring.cleanup_monitoring_data(NUMBER) TO ROLE PUBLIC;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE analytics_wh TO ROLE PUBLIC;