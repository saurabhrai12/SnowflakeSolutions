# Jinja Template Examples for Snowflake SQL

This document shows the Jinja templating patterns implemented across the SQL files for environment-specific deployments.

## Template Variables Available

All variables are defined in `.github/deployment-config.yml` per environment:

| Variable | DEV | STAGING | PROD | Description |
|----------|-----|---------|------|-------------|
| `environment` | "dev" | "staging" | "prod" | Environment identifier |
| `database` | analytics_platform_dev | analytics_platform_staging | analytics_platform | Database name |
| `warehouse` | analytics_wh_dev | analytics_wh_staging | analytics_wh | Warehouse name |
| `warehouse_size` | SMALL | MEDIUM | LARGE | Warehouse compute size |
| `retention_days` | 7 | 30 | 90 | Data retention period |
| `auto_suspend_minutes` | 5 | 30 | 60 | Warehouse auto-suspend |
| `task_schedule` | "5 minute" | "2 minute" | "1 minute" | Task execution frequency |

## Template Patterns Used

### 1. Basic Variable Substitution

```sql
-- Database and warehouse context
USE DATABASE {{ database }};
CREATE OR ALTER WAREHOUSE {{ warehouse }}
    WAREHOUSE_SIZE = '{{ warehouse_size }}'
    AUTO_SUSPEND = {{ auto_suspend_minutes }};
```

### 2. Default Values

```sql
-- Warehouse size with fallback
WAREHOUSE_SIZE = '{{ warehouse_size | default("SMALL") }}'

-- Retention with fallback  
data_retention_time_in_days = {{ retention_days | default(7) }}

-- Task schedule with fallback
SCHEDULE = '{{ task_schedule | default("2 minute") }}'
```

### 3. Conditional Environment Logic

```sql
-- Production-only features
{% if environment == 'prod' %}
CREATE OR ALTER TASK prod_data_cleanup_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = '1440 minute'  -- Daily cleanup
    AS
    DELETE FROM jobs WHERE created_at < DATEADD(day, -{{ retention_days }}, CURRENT_DATE());
{% endif %}
```

### 4. Environment-Specific Table Features

```sql
-- Production clustering for performance
CREATE OR ALTER TABLE jobs (
    job_id STRING PRIMARY KEY,
    -- ... other columns
) data_retention_time_in_days = {{ retention_days | default(30) }}
  {% if environment == 'prod' %}
  cluster by (created_at, status)
  {% endif %};
```

### 5. Dynamic Comments

```sql
CREATE OR ALTER WAREHOUSE {{ warehouse }}
    -- ... warehouse config
    COMMENT = 'Analytics warehouse for {{ environment }} environment';
```

### 6. Environment-Specific Task Schedules

```sql
-- Different frequencies per environment
CREATE OR ALTER TASK customer_analytics_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = '{{ task_schedule | default("2 minute") }}'
    WHEN SYSTEM$STREAM_HAS_DATA('customers_stream')
    AS
    CALL processed_data.process_customer_changes();
```

## Files Updated with Jinja Templates

### Foundation
- `Account/snowflake/schemas/00_database_and_warehouse.sql` - Database/warehouse with environment-specific sizing

### Monitoring Schema  
- `Customer/snowflake/monitoring/tables.sql` - Tables with retention policies
- `Customer/snowflake/monitoring/stored_procedures.sql` - Database context

### Raw Data Schema
- `Account/snowflake/schemas/raw_data/tables.sql` - Tables with conditional clustering
- `Account/snowflake/schemas/raw_data/data_pipeline_tasks.sql` - Tasks with environment schedules
- `Account/snowflake/schemas/raw_data/stored_procedures.sql` - Database context
- `Account/snowflake/schemas/raw_data/comments.sql` - Database context
- All other raw_data files - Database context

### Processed Data Schema
- `Account/snowflake/schemas/processed_data/tables.sql` - Database context
- `Account/snowflake/schemas/processed_data/stored_procedures.sql` - Database context
- `Account/snowflake/schemas/processed_data/data_pipeline_procedures.sql` - Database context

### Reporting Schema
- `shared/snowflake/reporting/views.sql` - Database context

### Sample Data & Permissions
- `Account/snowflake/02_sample_data.sql` - Environment-specific sample data paths
- `Account/snowflake/schemas/permissions.sql` - Database context

## Deployment Usage

When deploying via Git integration, variables are passed as `-D` parameters:

```bash
# DEV deployment
snow git execute '@repo/branches/main/path/to/script.sql' \
    -D "environment='dev'" \
    -D "database='analytics_platform_dev'" \
    -D "warehouse='analytics_wh_dev'" \
    -D "warehouse_size='SMALL'" \
    -D "retention_days=7" \
    -D "auto_suspend_minutes=5" \
    -D "task_schedule='5 minute'"

# PROD deployment  
snow git execute '@repo/branches/main/path/to/script.sql' \
    -D "environment='prod'" \
    -D "database='analytics_platform'" \
    -D "warehouse='analytics_wh'" \
    -D "warehouse_size='LARGE'" \
    -D "retention_days=90" \
    -D "auto_suspend_minutes=60" \
    -D "task_schedule='1 minute'"
```

## Advanced Template Examples

### Multi-Environment Conditional

```sql
-- Different retention policies by environment
CREATE OR ALTER TABLE monitoring_logs (
    log_id STRING,
    log_message STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) 
{% if environment == 'dev' %}
data_retention_time_in_days = 3  -- Short retention in dev
{% elif environment == 'staging' %}  
data_retention_time_in_days = 14  -- Medium retention in staging
{% else %}
data_retention_time_in_days = {{ retention_days }}  -- Full retention in prod
{% endif %};
```

### Environment-Specific Resource Allocation

```sql
-- More resources in production
CREATE OR ALTER TASK heavy_analytics_task
    WAREHOUSE = {{ warehouse }}
    {% if environment == 'prod' %}
    USER_TASK_TIMEOUT_MS = 1800000  -- 30 minutes in prod
    {% else %}
    USER_TASK_TIMEOUT_MS = 300000   -- 5 minutes in dev/staging
    {% endif %}
    SCHEDULE = '{{ task_schedule }}'
    AS
    CALL run_heavy_analytics();
```

### Template Inheritance Pattern

```sql
-- Base table definition with environment overrides  
{% set base_retention = retention_days | default(7) %}
{% set table_retention = base_retention if environment != 'dev' else 1 %}

CREATE OR ALTER TABLE {{ table_name | default('default_table') }} (
    id STRING PRIMARY KEY,
    data VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) data_retention_time_in_days = {{ table_retention }};
```

## Benefits of This Approach

### ✅ **Environment Consistency**
- Same SQL logic across all environments
- Environment-specific configuration without code duplication
- Automatic scaling of resources based on environment

### ✅ **Maintainability** 
- Single source of truth for environment configurations
- Easy to add new environments or modify existing ones
- Template logic is self-documenting

### ✅ **Safety**
- Production-only features like cleanup tasks
- Development-friendly settings (shorter retention, smaller warehouses)
- Staging mirrors production behavior with intermediate settings

### ✅ **Cost Optimization**
- Smaller warehouses in dev (SMALL vs LARGE)
- Shorter retention in non-prod environments
- Less frequent task execution in development

This Jinja templating approach provides a powerful, maintainable solution for environment-specific Snowflake deployments while keeping the SQL readable and the deployment process simple.