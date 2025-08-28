-- Database and Warehouse Setup
-- Uses CREATE OR ALTER for idempotent deployments

-- Create or alter database
CREATE OR ALTER DATABASE analytics_platform;
USE DATABASE analytics_platform;

-- Create or alter schemas
CREATE OR ALTER SCHEMA raw_data;
CREATE OR ALTER SCHEMA processed_data;
CREATE OR ALTER SCHEMA reporting;
CREATE OR ALTER SCHEMA monitoring;

-- Create or alter warehouse
CREATE OR ALTER WAREHOUSE analytics_wh
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Primary warehouse for analytics platform';