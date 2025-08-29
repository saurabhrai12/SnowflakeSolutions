# Snowflake SchemaChange Deployment Pipeline

## Overview

This pipeline provides enterprise-grade Snowflake deployments using the **SchemaChange** utility with advanced features including:

- ✅ **Domain-Based Architecture** with dependency management
- ✅ **Automated Versioning** with semantic version control
- ✅ **CREATE OR REPLACE** conversion from CREATE OR ALTER statements
- ✅ **File Versioning** with SchemaChange naming conventions
- ✅ **Multiple Deployment Modes** (single_domain, full_deployment, changed_only)

## Key Features

### 🏗️ **SchemaChange Integration**
- Uses official SchemaChange utility (v3.6.0)
- Automatic change history tracking in `SCHEMACHANGE_HISTORY` table
- Version-based deployment with rollback capabilities
- Compatible with Snowflake's native versioning

### 🔢 **Automated Versioning**
- **Semantic Versioning**: `v1.2.3` format
- **Auto-increment**: Based on branch and deployment type
  - Feature branches → patch increment (v1.0.0 → v1.0.1)
  - Main branch → minor increment (v1.0.0 → v1.1.0) 
  - Manual major → major increment (v1.0.0 → v2.0.0)
- **Force Version**: Override with specific version
- **Git Tagging**: Automatic tagging on PROD deployments

### 🔄 **CREATE OR REPLACE Conversion**
Automatically converts `CREATE OR ALTER` statements to `CREATE OR REPLACE` for:
- Tables, Views, Functions, Procedures
- Streams, Tasks, Pipes, Stages
- File Formats, Databases, Schemas, Warehouses

### 📁 **SchemaChange File Naming**
Files are automatically renamed to SchemaChange conventions:
```
Original: Account/snowflake/raw_data/table/customers.sql
Versioned: V1_2_3__account_Account_snowflake_raw_data_table_customers.sql
```

## Pipeline Workflows

### 🔧 **Manual Deployment (workflow_dispatch)**
```yaml
inputs:
  target_environment: [DEV, STAGING, PROD]
  deployment_mode: [single_domain, full_deployment, changed_only]
  target_domain: [shared, account, asset, customer]
  version_increment: [major, minor, patch]
  force_version: "v1.2.3" (optional)
  dry_run: true/false
```

### ⚡ **Automatic Deployments**
- **Push to main** → STAGING (changed_only, minor version)
- **Feature branches** → DEV (changed_only, patch version)
- **Pull Requests** → DEV (dry_run, patch version)

## Pipeline Jobs

### 1. **Setup** 🔧
- Environment parameter resolution
- Domain dependency resolution
- Version calculation and validation
- Git diff analysis for changed_only mode

### 2. **Process Templates** 📊
- Jinja2 template processing with environment variables
- CREATE OR ALTER → CREATE OR REPLACE conversion
- SchemaChange file versioning and naming
- Version header injection with metadata

### 3. **Deploy** 🚀
- SchemaChange deployment execution
- Domain-based parallel deployment
- Connection configuration from deployment-config.yml
- Git tagging on successful PROD deployments

### 4. **Dry Run** 🔍
- Preview of deployment plan
- List of versioned files to be deployed
- SchemaChange command preview
- No actual database changes

## Configuration

### Environment Variables (deployment-config.yml)
```yaml
environments:
  DEV:
    variables:
      account: "OILZKIQ-ID94597"
      user: "SAURABHMAC"
      database: "analytics_platform_dev"
      warehouse: "analytics_wh_dev"
```

### SchemaChange Settings
```yaml
schemachange:
  version_table: "SCHEMACHANGE_HISTORY"
  version_prefix: "V"
  conversion:
    enabled: true
    objects: ["TABLE", "VIEW", "FUNCTION", ...]
```

## Usage Examples

### Deploy Single Domain to DEV
```bash
# Via GitHub Actions UI
target_environment: DEV
deployment_mode: single_domain  
target_domain: shared
version_increment: patch
dry_run: false
```

### Full Production Deployment
```bash
# Via GitHub Actions UI  
target_environment: PROD
deployment_mode: full_deployment
version_increment: minor
dry_run: false
```

### Force Specific Version
```bash
# Via GitHub Actions UI
target_environment: STAGING
deployment_mode: full_deployment
force_version: "v2.0.0"
```

## File Structure

### Input Files (Your SQL)
```
Account/snowflake/
├── raw_data/
│   ├── table/
│   │   └── customers.sql        # CREATE OR ALTER TABLE customers
│   └── procedure/
│       └── process_data.sql     # CREATE OR ALTER PROCEDURE
```

### Generated Files (SchemaChange)
```
versioned-sql/
├── V1_2_3__account_raw_data_table_customers.sql
└── V1_2_3__account_raw_data_procedure_process_data.sql
```

## Version History Tracking

SchemaChange automatically tracks all deployments in the `SCHEMACHANGE_HISTORY` table:

| VERSION | DESCRIPTION | SCRIPT | CHECKSUM | EXECUTION_TIME | SUCCESS |
|---------|-------------|---------|----------|----------------|---------|
| 1.2.3 | account_raw_data_table_customers | V1_2_3__account... | abc123 | 2023-12-01 10:00:00 | True |

## Benefits Over Standard Pipeline

1. **📊 Version Control**: Complete audit trail of all schema changes
2. **🔄 Rollback Capability**: SchemaChange supports rollbacks to previous versions  
3. **🛡️ Conflict Resolution**: Prevents conflicting deployments
4. **📈 Change Tracking**: Detailed history of what changed when
5. **🔒 Consistency**: Ensures deployment order and dependencies
6. **⚡ Performance**: Optimized for large-scale schema changes

## Migration from Standard Pipeline

1. **Keep Existing**: Standard pipeline remains available
2. **Gradual Migration**: Migrate domains one at a time
3. **Version Sync**: SchemaChange will detect current schema state
4. **No Downtime**: Switch between pipelines as needed

## Best Practices

1. **Use Dry Run**: Always test with dry_run=true first
2. **Version Strategy**: Use semantic versioning consistently
3. **Domain Order**: Deploy shared domain first, then dependents
4. **Environment Progression**: DEV → STAGING → PROD
5. **Change Documentation**: Include meaningful commit messages
6. **Monitor History**: Regularly check SCHEMACHANGE_HISTORY table

## Troubleshooting

### Common Issues
- **Version Conflicts**: Use force_version to override
- **Permission Errors**: Ensure SYSADMIN role has required permissions
- **Template Errors**: Check Jinja2 syntax in validation step
- **Domain Dependencies**: Verify dependency order in configuration

### Debug Commands
```bash
# Check SchemaChange history
SELECT * FROM SCHEMACHANGE_HISTORY ORDER BY INSTALLED_ON DESC;

# View current version
SELECT MAX(VERSION) FROM SCHEMACHANGE_HISTORY;

# Check failed deployments
SELECT * FROM SCHEMACHANGE_HISTORY WHERE SUCCESS = FALSE;
```