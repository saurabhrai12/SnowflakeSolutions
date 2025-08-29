# Configuration-Driven Snowflake Deployment

This directory contains the configuration-driven deployment system for Snowflake schemas and objects.

## Files

### `deployment-config.yml`
Master configuration file that defines:
- **Environment mappings** (DEV, STAGING, PROD) with database/warehouse names
- **Domain-based deployment order** (foundation → account → shared → permissions)  
- **Object type deployment order** within each schema (tables → functions → views → streams → tasks, etc.)
- **Deployment modes** (FULL, INCREMENTAL, SCHEMA_SPECIFIC)
- **File patterns** and replacements

### `scripts/deploy.sh`
Configuration-driven deployment script that:
- Parses YAML configuration using `yq`
- Processes SQL files with environment-specific database names
- Deploys domains and schemas in the correct dependency order
- Handles different deployment modes
- Supports object-type ordering within schemas

## Usage

### Local Deployment
```bash
# Install yq for YAML parsing
brew install yq

# Run deployment
.github/scripts/deploy.sh <ENVIRONMENT> <MODE> [TARGET_SCHEMAS]

# Examples:
.github/scripts/deploy.sh DEV FULL
.github/scripts/deploy.sh STAGING SCHEMA_SPECIFIC "monitoring,raw_data"
.github/scripts/deploy.sh PROD INCREMENTAL
```

### CI/CD Integration
The GitHub Actions workflow automatically uses this configuration:
- Installs `yq` for YAML parsing
- Sets environment variables based on target environment
- Runs the deployment script with appropriate parameters

## Configuration Structure

### Environment Mapping
```yaml
environments:
  DEV:
    database: "analytics_platform_dev"
    warehouse: "analytics_wh_dev"
  PROD:
    database: "analytics_platform"
    warehouse: "analytics_wh"
```

### Domain-Based Deployment
```yaml
domains:
  - name: "foundation"
    files: ["Account/snowflake/schemas/00_database_and_warehouse.sql"]
  - name: "account"
    schemas:
      - name: "monitoring"
        path: "Customer/snowflake/monitoring"
      - name: "raw_data"  
        path: "Account/snowflake/schemas/raw_data"
```

### Object Type Ordering
Objects within each schema are deployed in dependency order:
1. `tables.sql` - Base tables and data structures
2. `file_formats.sql` - File format definitions
3. `functions.sql` - User-defined functions
4. `stored_procedures.sql` - Business logic
5. `views.sql` - Views and virtual tables
6. `*stream*.sql` - Change data capture streams
7. `*task*.sql` - Scheduled tasks
8. And more...

## Benefits

### ✅ **Simplified Maintenance**
- Single configuration file instead of scattered hardcoded logic
- Easy to add new environments or change deployment order
- Clear separation of configuration vs. execution logic

### ✅ **Environment Consistency**
- Automatic database name replacement based on target environment
- Consistent warehouse and retention policies per environment
- No more hardcoded database references in SQL files

### ✅ **Dependency Management**
- Domain-based deployment ensures proper schema dependencies
- Object-type ordering respects Snowflake object dependencies
- Foundation → Monitoring → Data Schemas → Reporting → Permissions

### ✅ **Flexible Deployment Modes**
- **FULL**: Deploy everything in order
- **INCREMENTAL**: Deploy only changed files (with dependencies)
- **SCHEMA_SPECIFIC**: Deploy specific schemas only

### ✅ **Reduced Code Complexity**
- 200+ lines of deployment logic → ~50 lines + configuration
- Configuration-driven instead of procedural
- Easier to understand and modify

## Comparison: Before vs After

### Before (Hardcoded Approach)
```bash
# 200+ lines of bash with hardcoded paths and logic
for file in Account/snowflake/schemas/raw_data/*.sql; do
  if [ -f "$file" ]; then
    sed -i "s/analytics_platform/$DATABASE/g" "$file"
    snow sql -f "$file" --connection default
  fi
done
# Repeated for every schema...
```

### After (Configuration-Driven)
```bash
# Simple configuration-driven deployment
.github/scripts/deploy.sh "$ENVIRONMENT" "$DEPLOYMENT_MODE" "$TARGET_SCHEMAS"
```

```yaml
# Clear, maintainable configuration
domains:
  - name: "account"
    schemas:
      - name: "raw_data"
        path: "Account/snowflake/schemas/raw_data"
```

## Migration Notes

The new system is backward compatible with existing SQL files. The deployment script automatically:
- Replaces hardcoded `analytics_platform` references with environment-specific database names
- Maintains existing file structure and naming conventions
- Processes all existing SQL files in dependency order

No changes to SQL files are required - the environment-specific replacements happen automatically during deployment.