# Single Branch Strategy for Snowflake CREATE OR ALTER Deployments

A single branch (trunk-based) strategy can actually be **excellent** for Snowflake deployments with CREATE OR ALTER, but it depends on your team's maturity and requirements. Let me explain when it works best and how to implement it safely.

## When Single Branch Strategy Works Well

### Ideal Scenarios
- **Small to medium teams** (2-10 developers)
- **High deployment frequency** (multiple times per day)
- **Mature CI/CD practices** with comprehensive automated testing
- **CREATE OR ALTER's idempotent nature** makes it particularly suitable
- **Teams prioritizing simplicity** over complex branching

### Key Advantages with CREATE OR ALTER

```sql
-- CREATE OR ALTER is naturally idempotent - perfect for single branch
CREATE OR ALTER TABLE customers (
    customer_id NUMBER,
    email VARCHAR(255),
    created_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
    -- Safe to run multiple times without conflicts
);

-- Changes are additive and non-breaking
CREATE OR ALTER TABLE customers ADD COLUMN IF NOT EXISTS 
    loyalty_status VARCHAR(50) DEFAULT 'BRONZE';
```

## Recommended Single Branch Implementation

### 1. Environment Progression Model

```sql
-- Single branch, multiple environments
-- main branch → DEV → STG → PROD

-- Automated progression with Git integration
CREATE OR ALTER DATABASE dev_db FROM @database_repo/branches/main;

-- After automated tests pass
CREATE OR ALTER DATABASE stg_db CLONE dev_db;

-- After staging validation
CREATE OR ALTER DATABASE prod_db CLONE stg_db;
```

### 2. Feature Toggle Pattern

```sql
-- Use feature flags instead of branches
CREATE OR ALTER TABLE feature_flags (
    feature_name VARCHAR(100),
    environment VARCHAR(20),
    enabled BOOLEAN DEFAULT FALSE,
    enabled_date TIMESTAMP_NTZ
);

-- New features controlled by flags
CREATE OR ALTER PROCEDURE get_customer_data()
RETURNS TABLE
AS
$$
DECLARE
    new_schema_enabled BOOLEAN;
BEGIN
    SELECT enabled INTO :new_schema_enabled 
    FROM feature_flags 
    WHERE feature_name = 'NEW_CUSTOMER_SCHEMA'
    AND environment = CURRENT_DATABASE();
    
    IF (new_schema_enabled) THEN
        RETURN TABLE(SELECT * FROM customers_v2);
    ELSE
        RETURN TABLE(SELECT * FROM customers);
    END IF;
END;
$$;
```

### 3. Progressive Deployment Pipeline

```sql
-- Deployment orchestration procedure
CREATE OR ALTER PROCEDURE progressive_deploy(
    git_commit_hash VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    deployment_status VARCHAR;
BEGIN
    -- Step 1: Deploy to DEV
    ALTER GIT REPOSITORY database_repo FETCH;
    CREATE OR ALTER DATABASE dev_db FROM @database_repo/branches/main;
    
    -- Step 2: Run automated tests
    CALL run_schema_tests('dev_db');
    CALL run_data_quality_checks('dev_db');
    
    -- Step 3: Clone to staging after 1 hour bake time
    CALL SYSTEM$WAIT(60*60);
    CREATE OR ALTER DATABASE stg_db CLONE dev_db;
    
    -- Step 4: Run staging validation
    CALL run_integration_tests('stg_db');
    
    -- Step 5: Blue-green deployment to production
    CREATE OR ALTER DATABASE prod_db_green CLONE stg_db;
    ALTER DATABASE prod_db_green SWAP WITH prod_db;
    
    RETURN 'Deployment successful: ' || :git_commit_hash;
END;
$$;
```

### 4. Safety Mechanisms

```sql
-- Automated rollback capability
CREATE OR ALTER PROCEDURE auto_rollback_on_error()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Monitor error rates
    LET error_count := (
        SELECT COUNT(*) 
        FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
        WHERE error_code IS NOT NULL
        AND start_time > DATEADD(minute, -5, CURRENT_TIMESTAMP())
    );
    
    IF (error_count > 10) THEN
        -- Rollback using time travel
        CREATE OR ALTER DATABASE prod_db CLONE prod_db AT(OFFSET => -300);
        RETURN 'Rolled back due to errors';
    END IF;
    
    RETURN 'System healthy';
END;
$$;

-- Continuous monitoring task
CREATE OR ALTER TASK monitor_deployment
    WAREHOUSE = monitoring_wh
    SCHEDULE = '1 MINUTE'
AS
    CALL auto_rollback_on_error();
```

## Single Branch Best Practices

### 1. Enforce Non-Breaking Changes Only

```sql
-- Good: Additive changes
CREATE OR ALTER TABLE orders ADD COLUMN IF NOT EXISTS 
    delivery_instructions VARCHAR(500);

-- Avoid: Breaking changes (handle with care)
-- Don't drop columns directly
-- Instead, deprecate and migrate
CREATE OR ALTER VIEW orders_compatible AS
SELECT 
    order_id,
    customer_id,
    order_date,
    -- Old column name maintained for compatibility
    delivery_notes AS delivery_instructions,
    delivery_notes  -- Deprecated, will remove after migration
FROM orders;
```

### 2. Implement Comprehensive Testing

```sql
CREATE OR ALTER PROCEDURE pre_deployment_validation()
RETURNS BOOLEAN
AS
$$
DECLARE
    all_tests_passed BOOLEAN DEFAULT TRUE;
BEGIN
    -- Schema compatibility check
    EXECUTE IMMEDIATE $$
        SELECT COUNT(*) FROM dev_db.INFORMATION_SCHEMA.COLUMNS
        MINUS
        SELECT COUNT(*) FROM prod_db.INFORMATION_SCHEMA.COLUMNS
    $$ INTO :schema_drift;
    
    IF (schema_drift > 0) THEN
        all_tests_passed := FALSE;
    END IF;
    
    -- Data quality gates
    EXECUTE IMMEDIATE $$
        SELECT COUNT(*) FROM dev_db.raw.customers
        WHERE email IS NULL OR customer_id IS NULL
    $$ INTO :data_issues;
    
    IF (data_issues > 0) THEN
        all_tests_passed := FALSE;
    END IF;
    
    RETURN all_tests_passed;
END;
$$;
```

### 3. Use Database Cloning for Safety

```sql
-- Zero-downtime deployment pattern
CREATE OR ALTER PROCEDURE safe_production_deploy()
AS
$$
BEGIN
    -- Create production candidate
    CREATE OR ALTER DATABASE prod_candidate CLONE stg_db;
    
    -- Smoke test the candidate
    CALL run_smoke_tests('prod_candidate');
    
    -- Atomic swap
    ALTER DATABASE prod_db RENAME TO prod_db_old;
    ALTER DATABASE prod_candidate RENAME TO prod_db;
    
    -- Keep old version for quick rollback
    -- Drop after successful validation period
    RETURN 'Deployment complete with rollback available';
END;
$$;
```

## Comparison: Single Branch vs Multi-Branch

| Aspect | Single Branch | Multi-Branch |
|--------|--------------|--------------|
| **Complexity** | Low - one branch to manage | Higher - multiple branches to sync |
| **Deployment Speed** | Very fast (multiple per day) | Slower (PR reviews, merging) |
| **Rollback** | Use Snowflake time travel/cloning | Git revert/branch rollback |
| **Testing Requirements** | Very high - must be automated | Can have manual testing gates |
| **Team Coordination** | Requires excellent communication | Isolation through branches |
| **CREATE OR ALTER Fit** | Perfect - idempotent operations | Good, but more complex |

## Recommendation

**Use single branch strategy when:**
- Your team can commit to backwards-compatible changes only
- You have strong automated testing
- You deploy frequently (daily or more)
- You want maximum simplicity
- Your team is co-located or communicates well

**Consider multi-branch when:**
- You need long-running feature development
- Multiple teams work independently  
- You require manual approval gates
- Breaking changes are common
- You need isolated testing environments per feature

The single branch strategy with CREATE OR ALTER can be simpler and faster, but requires more discipline and better testing. It's increasingly popular for teams practicing continuous deployment.