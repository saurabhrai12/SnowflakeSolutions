# Snowflake CI/CD Pipeline with CREATE OR ALTER Commands

## Repository Structure (Mono-repo)

```
snowflake-data-platform/
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── cd-dev.yml
│       ├── cd-staging.yml
│       └── cd-prod.yml
├── databases/
│   ├── analytics/
│   │   ├── schemas/
│   │   │   ├── raw/
│   │   │   ├── staging/
│   │   │   └── marts/
│   │   ├── tables/
│   │   ├── views/
│   │   ├── functions/
│   │   └── procedures/
│   └── finance/
│       └── (similar structure)
├── shared/
│   ├── warehouses/
│   ├── roles/
│   ├── users/
│   └── resource_monitors/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── data_quality/
├── scripts/
│   ├── deploy.py
│   ├── rollback.py
│   └── validate.py
├── config/
│   ├── dev.yml
│   ├── staging.yml
│   └── prod.yml
├── dbt_project.yml (if using dbt)
├── requirements.txt
└── README.md
```

## GitHub Actions Workflow

### 1. Continuous Integration (.github/workflows/ci.yml)

```yaml
name: Snowflake CI Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
  SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
  SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
  SNOWFLAKE_ROLE: ${{ secrets.SNOWFLAKE_ROLE }}
  SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}

jobs:
  lint-and-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install sqlfluff pre-commit
      
      - name: SQL Linting
        run: |
          sqlfluff lint databases/ --dialect snowflake
      
      - name: Validate SQL Syntax
        run: |
          python scripts/validate.py --check-syntax
      
      - name: Security Scan
        run: |
          python scripts/validate.py --security-scan

  unit-tests:
    runs-on: ubuntu-latest
    needs: lint-and-validate
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Run Unit Tests
        run: |
          python -m pytest tests/unit/ -v
      
      - name: Test CREATE OR ALTER Statements
        run: |
          python scripts/validate.py --test-create-or-alter

  deploy-to-dev:
    runs-on: ubuntu-latest
    needs: [lint-and-validate, unit-tests]
    if: github.ref == 'refs/heads/main'
    environment: development
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Deploy to Development
        run: |
          python scripts/deploy.py --environment dev --use-create-or-alter
        env:
          SNOWFLAKE_DATABASE: DEV_DATABASE
      
      - name: Run Integration Tests
        run: |
          python -m pytest tests/integration/ -v --env=dev
      
      - name: Data Quality Tests
        run: |
          python -m pytest tests/data_quality/ -v --env=dev
```

### 2. Continuous Deployment - Staging (.github/workflows/cd-staging.yml)

```yaml
name: Deploy to Staging

on:
  workflow_run:
    workflows: ["Snowflake CI Pipeline"]
    types:
      - completed
    branches: [main]

env:
  SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
  SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
  SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
  SNOWFLAKE_ROLE: ${{ secrets.SNOWFLAKE_ROLE }}
  SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    environment: staging
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Deploy to Staging
        run: |
          python scripts/deploy.py --environment staging --use-create-or-alter
        env:
          SNOWFLAKE_DATABASE: STAGING_DATABASE
      
      - name: Run Staging Tests
        run: |
          python -m pytest tests/integration/ -v --env=staging
          python -m pytest tests/data_quality/ -v --env=staging
      
      - name: Performance Tests
        run: |
          python scripts/validate.py --performance-test --env=staging
```

### 3. Production Deployment (.github/workflows/cd-prod.yml)

```yaml
name: Deploy to Production

on:
  workflow_dispatch:
    inputs:
      confirm_deployment:
        description: 'Type "DEPLOY" to confirm production deployment'
        required: true
        default: ''

env:
  SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
  SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
  SNOWFLAKE_PASSWORD: ${{ secrets.SNOWFLAKE_PASSWORD }}
  SNOWFLAKE_ROLE: ${{ secrets.SNOWFLAKE_ROLE }}
  SNOWFLAKE_WAREHOUSE: ${{ secrets.SNOWFLAKE_WAREHOUSE }}

jobs:
  deploy-production:
    runs-on: ubuntu-latest
    if: github.event.inputs.confirm_deployment == 'DEPLOY'
    environment: production
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: pip install -r requirements.txt
      
      - name: Pre-deployment Validation
        run: |
          python scripts/validate.py --pre-prod-check --env=production
      
      - name: Create Backup
        run: |
          python scripts/deploy.py --create-backup --environment production
      
      - name: Deploy to Production
        run: |
          python scripts/deploy.py --environment production --use-create-or-alter
        env:
          SNOWFLAKE_DATABASE: PROD_DATABASE
      
      - name: Post-deployment Tests
        run: |
          python -m pytest tests/integration/ -v --env=production
          python scripts/validate.py --post-deployment-check --env=production
      
      - name: Rollback on Failure
        if: failure()
        run: |
          python scripts/rollback.py --environment production
```

## Deployment Script (scripts/deploy.py)

```python
#!/usr/bin/env python3
"""
Snowflake deployment script using CREATE OR ALTER commands
"""

import os
import argparse
import yaml
import snowflake.connector
from pathlib import Path
import logging
from typing import Dict, List, Tuple

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class SnowflakeDeployer:
    def __init__(self, config: Dict):
        self.config = config
        self.connection = None
        
    def connect(self):
        """Establish Snowflake connection"""
        try:
            self.connection = snowflake.connector.connect(
                account=os.getenv('SNOWFLAKE_ACCOUNT'),
                user=os.getenv('SNOWFLAKE_USER'),
                password=os.getenv('SNOWFLAKE_PASSWORD'),
                role=os.getenv('SNOWFLAKE_ROLE'),
                warehouse=os.getenv('SNOWFLAKE_WAREHOUSE'),
                database=self.config['database']
            )
            logger.info(f"Connected to Snowflake database: {self.config['database']}")
        except Exception as e:
            logger.error(f"Failed to connect to Snowflake: {e}")
            raise
            
    def execute_sql_file(self, file_path: Path) -> bool:
        """Execute SQL file using CREATE OR ALTER pattern"""
        try:
            with open(file_path, 'r') as file:
                sql_content = file.read()
                
            # Split multiple statements
            statements = [stmt.strip() for stmt in sql_content.split(';') if stmt.strip()]
            
            cursor = self.connection.cursor()
            for statement in statements:
                if statement:
                    # Convert CREATE statements to CREATE OR ALTER where applicable
                    statement = self.convert_to_create_or_alter(statement)
                    logger.info(f"Executing: {statement[:100]}...")
                    cursor.execute(statement)
                    
            cursor.close()
            logger.info(f"Successfully executed: {file_path}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to execute {file_path}: {e}")
            return False
            
    def convert_to_create_or_alter(self, statement: str) -> str:
        """Convert CREATE statements to CREATE OR ALTER where supported"""
        statement_upper = statement.upper().strip()
        
        # Objects that support CREATE OR ALTER in Snowflake
        supported_objects = [
            'TABLE', 'VIEW', 'MATERIALIZED VIEW', 'STREAM', 'TASK',
            'STAGE', 'FILE FORMAT', 'FUNCTION', 'PROCEDURE', 'SCHEMA',
            'DATABASE', 'WAREHOUSE', 'RESOURCE MONITOR'
        ]
        
        for obj_type in supported_objects:
            if statement_upper.startswith(f'CREATE {obj_type}'):
                statement = statement.replace(f'CREATE {obj_type}', f'CREATE OR ALTER {obj_type}', 1)
                break
                
        return statement
        
    def deploy_databases(self) -> bool:
        """Deploy database objects in dependency order"""
        deployment_order = [
            'databases',
            'shared/warehouses',
            'shared/roles',
            'shared/resource_monitors',
            'databases/*/schemas',
            'databases/*/tables',
            'databases/*/views',
            'databases/*/functions',
            'databases/*/procedures'
        ]
        
        success = True
        for pattern in deployment_order:
            sql_files = list(Path('.').glob(f'{pattern}/**/*.sql'))
            for sql_file in sorted(sql_files):
                if not self.execute_sql_file(sql_file):
                    success = False
                    
        return success
        
    def create_backup(self):
        """Create backup of current state"""
        cursor = self.connection.cursor()
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        
        # Clone database for backup
        backup_db = f"{self.config['database']}_BACKUP_{timestamp}"
        cursor.execute(f"CREATE DATABASE {backup_db} CLONE {self.config['database']}")
        
        logger.info(f"Backup created: {backup_db}")
        cursor.close()

def main():
    parser = argparse.ArgumentParser(description='Deploy Snowflake objects')
    parser.add_argument('--environment', required=True, choices=['dev', 'staging', 'production'])
    parser.add_argument('--use-create-or-alter', action='store_true', help='Use CREATE OR ALTER statements')
    parser.add_argument('--create-backup', action='store_true', help='Create backup before deployment')
    
    args = parser.parse_args()
    
    # Load environment config
    with open(f'config/{args.environment}.yml', 'r') as file:
        config = yaml.safe_load(file)
    
    deployer = SnowflakeDeployer(config)
    deployer.connect()
    
    if args.create_backup:
        deployer.create_backup()
    
    success = deployer.deploy_databases()
    
    if success:
        logger.info("Deployment completed successfully")
        exit(0)
    else:
        logger.error("Deployment failed")
        exit(1)

if __name__ == "__main__":
    main()
```

## Example SQL Files Using CREATE OR ALTER

### Database Schema (databases/analytics/schemas/raw.sql)
```sql
-- Create or alter database
CREATE OR ALTER DATABASE ANALYTICS_DB;

-- Create or alter schema
CREATE OR ALTER SCHEMA ANALYTICS_DB.RAW
    COMMENT = 'Raw data ingestion layer';

-- Set default schema properties
ALTER SCHEMA IF EXISTS ANALYTICS_DB.RAW 
SET DATA_RETENTION_TIME_IN_DAYS = 7;
```

### Table Definition (databases/analytics/tables/customers.sql)
```sql
USE SCHEMA ANALYTICS_DB.RAW;

CREATE OR ALTER TABLE customers (
    customer_id NUMBER(38,0) NOT NULL,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    email VARCHAR(100),
    phone VARCHAR(20),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    is_active BOOLEAN DEFAULT TRUE,
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
)
COMMENT = 'Customer master data table';

-- Add or modify table properties
ALTER TABLE IF EXISTS customers 
SET DATA_RETENTION_TIME_IN_DAYS = 30;
```

### View Definition (databases/analytics/views/active_customers.sql)
```sql
USE SCHEMA ANALYTICS_DB.MARTS;

CREATE OR ALTER VIEW active_customers AS
SELECT 
    customer_id,
    first_name,
    last_name,
    email,
    phone,
    created_at,
    updated_at
FROM ANALYTICS_DB.RAW.customers
WHERE is_active = TRUE
COMMENT = 'View of active customers only';
```

## Configuration Files

### Development Config (config/dev.yml)
```yaml
database: DEV_ANALYTICS_DB
warehouse: DEV_WH
role: DEV_ROLE
environment: development
data_retention_days: 7
auto_suspend_minutes: 5

features:
  create_or_alter: true
  backup_before_deploy: false
  run_tests: true

notifications:
  slack_webhook: ${SLACK_WEBHOOK_DEV}
```

### Production Config (config/prod.yml)
```yaml
database: PROD_ANALYTICS_DB
warehouse: PROD_WH
role: PROD_ROLE
environment: production
data_retention_days: 90
auto_suspend_minutes: 10

features:
  create_or_alter: true
  backup_before_deploy: true
  run_tests: true

notifications:
  slack_webhook: ${SLACK_WEBHOOK_PROD}
  email_alerts: true
```

## Requirements (requirements.txt)
```
snowflake-connector-python>=3.7.0
PyYAML>=6.0
pytest>=7.0.0
sqlfluff>=2.0.0
pre-commit>=3.0.0
requests>=2.28.0
```

## Key Features

### Modern Engineering Principles
1. **Single Branch Strategy**: All changes go through main branch with proper CI/CD gates
2. **Mono-repo Structure**: All Snowflake objects organized in a single repository
3. **Infrastructure as Code**: All database objects defined in version-controlled SQL files
4. **CREATE OR ALTER Pattern**: Idempotent deployments using Snowflake's new commands
5. **Automated Testing**: Unit, integration, and data quality tests
6. **Progressive Deployment**: Dev → Staging → Production pipeline
7. **Rollback Capability**: Automated rollback on deployment failures

### CREATE OR ALTER Benefits
- **Idempotent Operations**: Safe to run multiple times
- **Zero Downtime**: Alters existing objects without dropping
- **Simplified Logic**: No need for complex DROP/CREATE scripts
- **Better Change Management**: Preserves object history and dependencies

### Security & Compliance
- Environment-specific configurations
- Secrets management through GitHub Actions
- Backup creation before production deployments
- Audit logging of all changes
- Role-based access control

This pipeline provides a robust, modern approach to managing Snowflake data warehouses with automated deployments, comprehensive testing, and the latest CREATE OR ALTER functionality.