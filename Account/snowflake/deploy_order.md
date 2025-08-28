# Snowflake Deployment Order

Execute these SQL files in the following order for proper deployment:

## 1. Foundation Setup
```sql
-- Execute first
@schemas/00_database_and_warehouse.sql
```

## 2. Monitoring Schema (MUST be created before other procedures)
```sql
-- Execute early to ensure monitoring tables exist
@schemas/monitoring/tables.sql
@schemas/monitoring/stored_procedures.sql
```

## 3. Raw Data Schema
```sql
-- Execute in order
@schemas/raw_data/tables.sql
@schemas/raw_data/clustering_optimization.sql
@schemas/raw_data/comments.sql
@schemas/raw_data/stored_procedures.sql
@schemas/raw_data/data_pipeline_streams.sql
@schemas/raw_data/pipeline_monitoring_procedures.sql
@schemas/raw_data/tasks_and_streams.sql
@schemas/raw_data/data_pipeline_tasks.sql
@schemas/raw_data/task_management.sql
@schemas/raw_data/data_pipeline_management.sql
```

## 4. Processed Data Schema
```sql
-- Execute in order
@schemas/processed_data/tables.sql
@schemas/processed_data/stored_procedures.sql
@schemas/processed_data/data_pipeline_procedures.sql
```

## 5. Reporting Schema
```sql
-- Execute last for views
@schemas/reporting/views.sql
```

## 6. Security and Permissions
```sql
-- Execute after all objects are created
@schemas/permissions.sql
```

## 7. Sample Data
```sql
-- Execute after all schema objects are in place
@02_sample_data.sql
```

## Notes
- Each file uses CREATE OR ALTER statements for idempotent deployments
- Files can be re-run safely without dropping existing objects
- Ensure proper Snowflake context (database, schema, warehouse) before execution
- Test in development environment before production deployment