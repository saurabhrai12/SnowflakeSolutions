# Snowflake Cloning: What Gets Copied for Snowpipes and Streams

The short answer is **NO for Snowpipes** and **DEPENDS for Streams**. Let me explain exactly what happens during cloning operations.

## What Gets Cloned vs What Doesn't

### ❌ **Snowpipes - NOT CLONED**

Snowpipes are **never** cloned, whether you clone a table, schema, or database:

```sql
-- Original setup
CREATE OR REPLACE PIPE raw.customer_pipe
AUTO_INGEST = TRUE
AS
COPY INTO raw.customers
FROM @s3_stage/customers/
FILE_FORMAT = (TYPE = 'CSV');

-- Clone the schema
CREATE SCHEMA raw_clone CLONE raw;

-- Result: raw_clone schema exists but WITHOUT the customer_pipe
-- You must recreate pipes manually
```

### ⚠️ **Streams - PARTIALLY CLONED**

Streams behavior depends on the type of clone:

```sql
-- Original stream
CREATE OR REPLACE STREAM customer_changes ON TABLE customers;

-- SCENARIO 1: Clone individual table
CREATE TABLE customers_clone CLONE customers;
-- Result: Stream is NOT cloned (streams aren't part of table definition)

-- SCENARIO 2: Clone schema containing stream
CREATE SCHEMA raw_clone CLONE raw;
-- Result: Stream IS cloned, but it's RESET (no change data)

-- SCENARIO 3: Clone database
CREATE DATABASE dev_db_clone CLONE dev_db;
-- Result: Streams ARE cloned but RESET to current state
```

## Detailed Breakdown of Cloning Behavior

### Database/Schema Clone - Full Object List

```sql
-- What GETS cloned:
✅ Tables (structure + data)
✅ Views
✅ Stored Procedures
✅ User-Defined Functions (UDFs)
✅ Sequences
✅ File Formats
✅ Streams (but reset - see details below)
✅ Tasks (but in SUSPENDED state)
✅ External Tables

-- What DOES NOT get cloned:
❌ Pipes (Snowpipes)
❌ Stages (external stages)
❌ Integrations
❌ Network Policies
❌ Resource Monitors
❌ Shares
❌ Grants/Privileges (unless COPY GRANTS used)
```

## Stream Cloning Specifics

### Stream State After Cloning

```sql
-- Original table with stream
CREATE OR REPLACE TABLE customers (
    id NUMBER,
    name VARCHAR,
    updated_at TIMESTAMP
);

CREATE OR REPLACE STREAM customer_stream ON TABLE customers;

-- Insert some data
INSERT INTO customers VALUES (1, 'John', CURRENT_TIMESTAMP());
INSERT INTO customers VALUES (2, 'Jane', CURRENT_TIMESTAMP());

-- Stream shows changes
SELECT * FROM customer_stream; -- Shows 2 inserts

-- Clone the schema
CREATE SCHEMA schema_clone CLONE public;

-- Check cloned stream
SELECT * FROM schema_clone.customer_stream; 
-- Result: EMPTY! Stream is reset, offset points to clone time
```

### Recreating Stream History

```sql
-- You CANNOT preserve stream offset during clone
-- Workaround: Capture stream data before cloning

-- Before cloning, preserve stream data
CREATE OR REPLACE TABLE stream_backup AS 
SELECT * FROM customer_stream;

-- After cloning, you have the data but not as an active stream
-- Must process it differently
```

## Handling Snowpipes in CI/CD

Since Snowpipes aren't cloned, you need to manage them explicitly:

### Option 1: Script-Based Recreation

```sql
CREATE OR REPLACE PROCEDURE clone_with_pipes(
    source_db VARCHAR,
    target_db VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    pipe_list RESULTSET;
    pipe_def VARCHAR;
BEGIN
    -- Clone the database
    CREATE OR REPLACE DATABASE IDENTIFIER(:target_db) CLONE IDENTIFIER(:source_db);
    
    -- Get all pipe definitions from source
    pipe_list := (
        SELECT 
            'CREATE OR REPLACE PIPE ' || :target_db || '.' || 
            pipe_schema || '.' || pipe_name || ' ' ||
            'AUTO_INGEST = ' || auto_ingest || ' AS ' || definition
        FROM 
            IDENTIFIER(:source_db || '.INFORMATION_SCHEMA.PIPES')
    );
    
    -- Recreate each pipe
    FOR pipe_rec IN pipe_list DO
        EXECUTE IMMEDIATE pipe_rec.pipe_def;
    END FOR;
    
    RETURN 'Database cloned with pipes recreated';
END;
$$;
```

### Option 2: Metadata-Driven Approach

```sql
-- Maintain pipe definitions in a table
CREATE OR REPLACE TABLE pipe_definitions (
    pipe_name VARCHAR,
    schema_name VARCHAR,
    stage_name VARCHAR,
    table_name VARCHAR,
    file_format VARCHAR,
    auto_ingest BOOLEAN,
    pattern VARCHAR
);

-- Procedure to recreate pipes from metadata
CREATE OR REPLACE PROCEDURE recreate_pipes_from_metadata(
    target_database VARCHAR
)
RETURNS VARCHAR
AS
$$
DECLARE
    c1 CURSOR FOR SELECT * FROM pipe_definitions;
BEGIN
    FOR rec IN c1 DO
        LET sql_cmd := 'CREATE OR REPLACE PIPE ' || 
            :target_database || '.' || rec.schema_name || '.' || rec.pipe_name ||
            ' AUTO_INGEST = ' || rec.auto_ingest ||
            ' AS COPY INTO ' || rec.table_name ||
            ' FROM @' || rec.stage_name || 
            ' FILE_FORMAT = ' || rec.file_format ||
            CASE WHEN rec.pattern IS NOT NULL 
                THEN ' PATTERN = ''' || rec.pattern || ''''
                ELSE '' 
            END;
            
        EXECUTE IMMEDIATE :sql_cmd;
    END FOR;
    
    RETURN 'Pipes recreated successfully';
END;
$$;
```

## Best Practices for CI/CD with Cloning

### 1. Complete Environment Setup

```sql
CREATE OR REPLACE PROCEDURE setup_complete_environment(
    source_env VARCHAR,
    target_env VARCHAR
)
AS
$$
BEGIN
    -- Step 1: Clone database
    CREATE OR REPLACE DATABASE IDENTIFIER(:target_env) CLONE IDENTIFIER(:source_env);
    
    -- Step 2: Recreate pipes
    CALL recreate_pipes_from_metadata(:target_env);
    
    -- Step 3: Resume tasks if needed
    LET tasks := (
        SELECT 'ALTER TASK ' || :target_env || '.' || 
               schema_name || '.' || task_name || ' RESUME'
        FROM IDENTIFIER(:target_env || '.INFORMATION_SCHEMA.TASKS')
    );
    
    FOR task_rec IN tasks DO
        EXECUTE IMMEDIATE task_rec;
    END FOR;
    
    -- Step 4: Reset streams if needed
    -- Streams are cloned but might need initialization
    
    -- Step 5: Validate setup
    CALL validate_environment(:target_env);
    
    RETURN 'Environment setup complete';
END;
$$;
```

### 2. Environment Comparison Tool

```sql
CREATE OR REPLACE PROCEDURE compare_environments(
    env1 VARCHAR,
    env2 VARCHAR
)
RETURNS TABLE (
    object_type VARCHAR,
    object_name VARCHAR,
    exists_in_env1 BOOLEAN,
    exists_in_env2 BOOLEAN
)
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    res := (
        -- Compare pipes
        SELECT 
            'PIPE' as object_type,
            COALESCE(e1.pipe_name, e2.pipe_name) as object_name,
            e1.pipe_name IS NOT NULL as exists_in_env1,
            e2.pipe_name IS NOT NULL as exists_in_env2
        FROM 
            (SELECT pipe_catalog || '.' || pipe_schema || '.' || pipe_name as pipe_name 
             FROM IDENTIFIER(:env1 || '.INFORMATION_SCHEMA.PIPES')) e1
        FULL OUTER JOIN
            (SELECT pipe_catalog || '.' || pipe_schema || '.' || pipe_name as pipe_name 
             FROM IDENTIFIER(:env2 || '.INFORMATION_SCHEMA.PIPES')) e2
        ON e1.pipe_name = e2.pipe_name
        
        UNION ALL
        
        -- Compare streams
        SELECT 
            'STREAM' as object_type,
            COALESCE(e1.stream_name, e2.stream_name) as object_name,
            e1.stream_name IS NOT NULL as exists_in_env1,
            e2.stream_name IS NOT NULL as exists_in_env2
        FROM 
            (SELECT table_catalog || '.' || table_schema || '.' || table_name as stream_name 
             FROM IDENTIFIER(:env1 || '.INFORMATION_SCHEMA.TABLES')
             WHERE table_type = 'STREAM') e1
        FULL OUTER JOIN
            (SELECT table_catalog || '.' || table_schema || '.' || table_name as stream_name 
             FROM IDENTIFIER(:env2 || '.INFORMATION_SCHEMA.TABLES')
             WHERE table_type = 'STREAM') e2
        ON e1.stream_name = e2.stream_name
    );
    
    RETURN TABLE(res);
END;
$$;
```

## Key Takeaways

1. **Snowpipes are NEVER cloned** - Must be recreated manually or via automation
2. **Streams ARE cloned with database/schema** but reset to empty state
3. **Tasks are cloned but SUSPENDED** - Need manual resumption
4. **External stages aren't cloned** - Must be recreated
5. **For complete environment replication**, you need additional scripting beyond simple CLONE commands

This is critical for CI/CD pipelines - a simple CLONE operation isn't sufficient for a complete environment copy when using Snowpipes and Streams.