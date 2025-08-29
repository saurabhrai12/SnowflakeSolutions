-- Database and Warehouse Setup
-- Uses CREATE OR ALTER for idempotent deployments
-- Uses Jinja templating for environment-specific configuration

-- Create or alter database
CREATE OR ALTER DATABASE {{ database }};
USE DATABASE {{ database }};

-- Create or alter schemas
CREATE OR ALTER SCHEMA raw_data;
CREATE OR ALTER SCHEMA processed_data;
CREATE OR ALTER SCHEMA reporting;
CREATE OR ALTER SCHEMA monitoring;

-- Create or alter warehouse
CREATE OR ALTER WAREHOUSE {{ warehouse }}
    WAREHOUSE_SIZE = '{{ warehouse_size | default("SMALL") }}'
    AUTO_SUSPEND = {{ auto_suspend_minutes | default(60) }}
    AUTO_RESUME = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'Primary warehouse for analytics platform - {{ environment }} environment';