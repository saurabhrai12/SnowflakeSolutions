# Snowflake Git Integration Setup Guide

This guide explains how to set up and use the new Jinja-templated, Git-integrated Snowflake deployment system.

## Overview

The new deployment system leverages:
- **Jinja templating** for environment-specific SQL files
- **Snowflake Git integration** for native version control
- **Declarative configuration** with `CREATE OR ALTER` statements
- **Environment variables** passed via `-D` parameters

## Prerequisites

### 1. Snowflake Setup

#### Create API Integration
```sql
-- Create API integration for Git repository access
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

-- Grant usage to roles that will perform deployments
GRANT USAGE ON INTEGRATION git_api_integration TO ROLE SYSADMIN;
```

#### Create Git Credentials Secret
```sql
-- Create secret for Git authentication (if private repo)
CREATE OR REPLACE SECRET git_secret
  TYPE = password
  USERNAME = 'your-github-username'
  PASSWORD = 'your-github-personal-access-token';

-- For public repositories, this secret may not be needed
```

### 2. GitHub Repository Secrets

Set up the following GitHub secrets:
- `SNOWFLAKE_ACCOUNT` - Your Snowflake account identifier
- `SNOWFLAKE_USER` - Snowflake user with deployment permissions
- `SNOWFLAKE_PASSWORD` - Snowflake user password

### 3. Snowflake Permissions

The deployment user needs these permissions:
```sql
-- Create role for deployments
CREATE OR REPLACE ROLE deployment_role;

-- Grant necessary privileges
GRANT CREATE DATABASE ON ACCOUNT TO ROLE deployment_role;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE deployment_role;
GRANT USAGE ON INTEGRATION git_api_integration TO ROLE deployment_role;
GRANT ALL ON FUTURE DATABASES TO ROLE deployment_role;
GRANT ALL ON FUTURE SCHEMAS TO ROLE deployment_role;

-- Assign role to deployment user
GRANT ROLE deployment_role TO USER your_deployment_user;
```

## SQL File Structure with Jinja Templates

### Environment-Specific Variables

Use Jinja templates for environment-specific values:

```sql
-- Database and Warehouse Setup
CREATE OR ALTER DATABASE {{ database }};
USE DATABASE {{ database }};

CREATE OR ALTER WAREHOUSE {{ warehouse }}
    WAREHOUSE_SIZE = '{{ warehouse_size | default("SMALL") }}'
    AUTO_SUSPEND = {{ auto_suspend_minutes | default(60) }}
    AUTO_RESUME = TRUE
    COMMENT = 'Analytics warehouse for {{ environment }} environment';
```

### Data Retention Configuration

```sql
-- Tables with environment-specific retention
CREATE OR ALTER TABLE monitoring.api_calls (
    call_id STRING PRIMARY KEY,
    -- ... other columns
    call_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) data_retention_time_in_days = {{ retention_days | default(7) }};
```

### Conditional Logic

```sql
-- Environment-specific features
{% if environment == 'prod' %}
CREATE OR ALTER TASK production_cleanup_task
    WAREHOUSE = {{ warehouse }}
    SCHEDULE = '1440 minute'  -- Daily
    AS
    DELETE FROM logs WHERE created_at < DATEADD(day, -{{ retention_days }}, CURRENT_DATE());
{% endif %}
```

## Deployment Configuration

### Environment Variables in `.github/deployment-config.yml`

```yaml
environments:
  DEV:
    variables:
      environment: "dev"
      database: "analytics_platform_dev"
      warehouse: "analytics_wh_dev"
      warehouse_size: "SMALL"
      retention_days: 7
      auto_suspend_minutes: 5
  PROD:
    variables:
      environment: "prod"
      database: "analytics_platform"
      warehouse: "analytics_wh"
      warehouse_size: "LARGE"
      retention_days: 90
      auto_suspend_minutes: 60
```

## Deployment Commands

### Manual Deployment via CLI

```bash
# Set up Git repository in Snowflake
snow sql -q "CREATE OR REPLACE GIT REPOSITORY analytics_platform_git_repo
  API_INTEGRATION = git_api_integration
  GIT_CREDENTIALS = git_secret
  ORIGIN = 'https://github.com/your-org/your-repo.git'"

# Fetch latest changes
snow git fetch analytics_platform_git_repo

# Deploy foundation with environment variables
snow git execute '@analytics_platform_git_repo/branches/main/Account/snowflake/schemas/00_database_and_warehouse.sql' \
    -D "environment='dev'" \
    -D "database='analytics_platform_dev'" \
    -D "warehouse='analytics_wh_dev'" \
    -D "warehouse_size='SMALL'" \
    -D "retention_days=7" \
    -D "auto_suspend_minutes=5"

# Deploy schema scripts
snow git execute '@analytics_platform_git_repo/branches/main/Customer/snowflake/monitoring/*' \
    -D "environment='dev'" \
    -D "database='analytics_platform_dev'" \
    -D "retention_days=7"
```

### GitHub Actions Deployment

The pipeline automatically:
1. **Determines environment** based on branch/manual input
2. **Fetches environment variables** from configuration
3. **Sets up Git repository** in Snowflake
4. **Deploys scripts in order** with environment-specific variables

#### Trigger Options

**Manual Deployment:**
```yaml
# Via GitHub Actions UI
target_environment: DEV | STAGING | PROD
load_sample_data: true | false
dry_run: true | false
```

**Automatic Deployment:**
- `feature/*` branches → DEV environment
- `main` branch → STAGING environment
- Pull requests → DEV environment (dry run)

## Benefits of Git Integration Approach

### ✅ **Native Snowflake Integration**
- Leverages Snowflake's built-in Git capabilities
- No need for external file processing or temp directories
- Direct execution from Git repository

### ✅ **Version Control Integration**
- SQL files are version-controlled in Git
- Easy rollbacks to previous versions
- Branch-based development workflow

### ✅ **Jinja Templating Power**
- Environment-specific configurations
- Conditional logic support
- Template inheritance and reuse
- Default value handling

### ✅ **Simplified Deployment Pipeline**
- Reduced from 300+ lines to ~200 lines
- No complex bash scripting for file processing
- Native Snowflake CLI commands
- Clear separation of configuration vs. execution

### ✅ **Declarative Configuration**
- `CREATE OR ALTER` ensures idempotent deployments
- Environment-specific retention, sizing, and features
- Configuration-driven rather than script-driven

## Migration from Legacy Approach

### 1. Update SQL Files
Replace hardcoded values with Jinja templates:
```sql
-- Before
USE DATABASE analytics_platform;
CREATE TABLE my_table (...) data_retention_time_in_days = 7;

-- After
USE DATABASE {{ database }};
CREATE TABLE my_table (...) data_retention_time_in_days = {{ retention_days }};
```

### 2. Set Up Git Integration
- Create API integration in Snowflake
- Configure Git credentials (if needed)
- Test Git repository setup

### 3. Update GitHub Actions
- Switch to new workflow: `snowflake-git-deployment.yml`
- Configure environment secrets
- Test deployment with dry run

### 4. Validate Deployment
- Run dry run first to see planned changes
- Deploy to DEV environment
- Verify all objects created with correct configuration
- Promote to higher environments

## Troubleshooting

### Common Issues

**Git Integration Errors:**
```sql
-- Check API integration
SHOW INTEGRATIONS LIKE 'git_api_integration';

-- Check Git repository status
SHOW GIT REPOSITORIES;

-- Test Git fetch
snow git fetch analytics_platform_git_repo;
```

**Jinja Template Errors:**
- Ensure all variables are defined in configuration
- Use default values for optional parameters: `{{ var | default("value") }}`
- Check template syntax with validation step

**Permission Errors:**
- Verify deployment role has necessary privileges
- Check database/schema ownership
- Ensure USAGE on API integration

## Example: Complete Environment Setup

```bash
# 1. Set up Snowflake Git integration
snow sql -q "
CREATE OR REPLACE API INTEGRATION git_api_integration
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY analytics_platform_git_repo
  API_INTEGRATION = git_api_integration
  ORIGIN = 'https://github.com/your-org/SnowflakeSolutions.git';
"

# 2. Fetch repository
snow git fetch analytics_platform_git_repo

# 3. Deploy to DEV environment
snow git execute '@analytics_platform_git_repo/branches/main/Account/snowflake/schemas/*' \
    -D "environment='dev'" \
    -D "database='analytics_platform_dev'" \
    -D "warehouse='analytics_wh_dev'" \
    -D "warehouse_size='SMALL'" \
    -D "retention_days=7" \
    -D "auto_suspend_minutes=5"

# 4. Verify deployment
snow sql -q "USE DATABASE analytics_platform_dev; SHOW SCHEMAS; SHOW TABLES;"
```

This approach provides a much cleaner, more maintainable, and Snowflake-native solution for environment-specific deployments!