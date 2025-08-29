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

-- Grant stored procedure permissions (using ALL syntax to avoid specific procedure signature issues)
GRANT USAGE ON ALL PROCEDURES IN SCHEMA raw_data TO ROLE PUBLIC;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA processed_data TO ROLE PUBLIC;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA monitoring TO ROLE PUBLIC;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE analytics_wh TO ROLE PUBLIC;