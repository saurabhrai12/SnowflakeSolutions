-- Sample Data (DML) for Analytics Platform
-- Uses modern INSERT with MERGE for idempotent operations

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- Insert sample customers using MERGE for idempotency
MERGE INTO customers AS target
USING (
    SELECT 
        customer_id, customer_name, email, phone, 
        PARSE_JSON(address_str) AS address,
        customer_tier, lifetime_value, is_active,
        PARSE_JSON(tags_str) AS tags, profile_score
    FROM VALUES
        ('CUST001', 'Acme Corporation', 'contact@acme.com', '+1-555-0101', 
         '{"street": "123 Main St", "city": "New York", "state": "NY", "zip": "10001"}',
         'ENTERPRISE', 150000.00, TRUE, '["B2B", "Enterprise", "Technology"]', 95),
        ('CUST002', 'Global Tech Solutions', 'info@globaltech.com', '+1-555-0102',
         '{"street": "456 Tech Blvd", "city": "San Francisco", "state": "CA", "zip": "94102"}',
         'ENTERPRISE', 275000.00, TRUE, '["B2B", "Enterprise", "Solutions"]', 92),
        ('CUST003', 'Startup Innovations', 'hello@startup.com', '+1-555-0103',
         '{"street": "789 Innovation Dr", "city": "Austin", "state": "TX", "zip": "73301"}',
         'PREMIUM', 45000.00, TRUE, '["B2B", "Startup", "Innovation"]', 87),
        ('CUST004', 'Retail Chain Plus', 'orders@retailchain.com', '+1-555-0104',
         '{"street": "321 Commerce Ave", "city": "Chicago", "state": "IL", "zip": "60601"}',
         'STANDARD', 85000.00, TRUE, '["B2B", "Retail", "Chain"]', 78),
        ('CUST005', 'Manufacturing Corp', 'procurement@manufacturing.com', '+1-555-0105',
         '{"street": "654 Industrial Way", "city": "Detroit", "state": "MI", "zip": "48201"}',
         'ENTERPRISE', 320000.00, TRUE, '["B2B", "Manufacturing", "Industrial"]', 88),
        ('CUST006', 'Healthcare Systems Inc', 'admin@healthsys.com', '+1-555-0106',
         '{"street": "987 Medical Center Dr", "city": "Boston", "state": "MA", "zip": "02115"}',
         'ENTERPRISE', 425000.00, TRUE, '["B2B", "Healthcare", "Systems"]', 98),
        ('CUST007', 'Education Network', 'support@ednet.edu', '+1-555-0107',
         '{"street": "246 Campus Rd", "city": "Seattle", "state": "WA", "zip": "98195"}',
         'PREMIUM', 78000.00, TRUE, '["B2B", "Education", "Network"]', 85),
        ('CUST008', 'Financial Services Group', 'contact@fingroup.com', '+1-555-0108',
         '{"street": "135 Wall St", "city": "New York", "state": "NY", "zip": "10005"}',
         'ENTERPRISE', 680000.00, TRUE, '["B2B", "Financial", "Banking"]', 96),
        ('CUST009', 'Media & Entertainment Co', 'info@mediaent.com', '+1-555-0109',
         '{"street": "468 Hollywood Blvd", "city": "Los Angeles", "state": "CA", "zip": "90028"}',
         'PREMIUM', 195000.00, TRUE, '["B2B", "Media", "Entertainment"]', 82),
        ('CUST010', 'Small Business Solutions', 'hello@smallbiz.com', '+1-555-0110',
         '{"street": "753 Main St", "city": "Denver", "state": "CO", "zip": "80202"}',
         'STANDARD', 32000.00, TRUE, '["B2B", "Small Business", "Solutions"]', 73)
    AS source(customer_id, customer_name, email, phone, address_str, customer_tier, lifetime_value, is_active, tags_str, profile_score)
) AS source
ON target.customer_id = source.customer_id
WHEN MATCHED THEN UPDATE SET
    customer_name = source.customer_name,
    email = source.email,
    phone = source.phone,
    address = source.address,
    customer_tier = source.customer_tier,
    lifetime_value = source.lifetime_value,
    is_active = source.is_active,
    tags = source.tags,
    profile_score = source.profile_score,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    customer_id, customer_name, email, phone, address, customer_tier, 
    lifetime_value, is_active, tags, profile_score
) VALUES (
    source.customer_id, source.customer_name, source.email, source.phone, 
    source.address, source.customer_tier, source.lifetime_value, source.is_active, source.tags, source.profile_score
);

-- Insert sample products
MERGE INTO products AS target
USING (
    SELECT 
        product_id, product_name, category, price, cost, description, is_active,
        inventory_count,
        PARSE_JSON(supplier_info_str) AS supplier_info,
        PARSE_JSON(specifications_str) AS specifications
    FROM VALUES
        ('PROD001', 'Analytics Platform Pro', 'Software', 5000.00, 1500.00, 'Enterprise analytics solution',
         TRUE, 100, '{"vendor": "TechCorp", "support_level": "Premium"}',
         '{"cpu_cores": 8, "memory_gb": 32, "storage_gb": 1000}'),
        ('PROD002', 'Data Visualization Suite', 'Software', 2500.00, 800.00, 'Advanced data visualization tools',
         TRUE, 150, '{"vendor": "VizCorp", "support_level": "Standard"}',
         '{"charts": 50, "dashboards": 20, "users": 100}'),
        ('PROD003', 'Machine Learning Toolkit', 'Software', 7500.00, 2000.00, 'ML and AI development platform',
         TRUE, 75, '{"vendor": "MLCorp", "support_level": "Premium"}',
         '{"algorithms": 200, "models": 50, "api_calls": 1000000}'),
        ('PROD004', 'Business Intelligence Basic', 'Software', 1200.00, 400.00, 'Basic BI reporting tools',
         TRUE, 300, '{"vendor": "BICorp", "support_level": "Basic"}',
         '{"reports": 25, "users": 25, "data_sources": 10}'),
        ('PROD005', 'Data Integration Hub', 'Software', 3500.00, 1000.00, 'ETL and data pipeline management',
         TRUE, 120, '{"vendor": "DataCorp", "support_level": "Standard"}',
         '{"connectors": 100, "pipelines": 50, "throughput_gb": 1000}'),
        ('PROD006', 'Cloud Security Suite', 'Security', 4800.00, 1200.00, 'Comprehensive cloud security platform',
         TRUE, 90, '{"vendor": "SecureCorp", "support_level": "Premium"}',
         '{"vulnerabilities_scanned": 50000, "compliance_frameworks": 15, "threat_detection": true}'),
        ('PROD007', 'Database Management Pro', 'Software', 6200.00, 1800.00, 'Advanced database administration tools',
         TRUE, 60, '{"vendor": "DBCorp", "support_level": "Premium"}',
         '{"databases_supported": 25, "backup_automation": true, "performance_monitoring": true}'),
        ('PROD008', 'API Gateway Enterprise', 'Infrastructure', 3800.00, 900.00, 'Enterprise API management solution',
         TRUE, 110, '{"vendor": "APICorp", "support_level": "Standard"}',
         '{"api_calls_per_month": 10000000, "rate_limiting": true, "analytics": true}'),
        ('PROD009', 'Mobile Development Kit', 'Software', 2200.00, 600.00, 'Cross-platform mobile development tools',
         TRUE, 200, '{"vendor": "MobileCorp", "support_level": "Standard"}',
         '{"platforms": ["iOS", "Android", "Web"], "components": 500, "themes": 20}'),
        ('PROD010', 'IoT Data Platform', 'Platform', 8500.00, 2500.00, 'Industrial IoT data collection and analysis',
         TRUE, 45, '{"vendor": "IoTCorp", "support_level": "Premium"}',
         '{"devices_supported": 100000, "protocols": 20, "real_time_processing": true}')
    AS source(product_id, product_name, category, price, cost, description, is_active, 
              inventory_count, supplier_info_str, specifications_str)
) AS source
ON target.product_id = source.product_id
WHEN MATCHED THEN UPDATE SET
    product_name = source.product_name,
    category = source.category,
    price = source.price,
    cost = source.cost,
    description = source.description,
    is_active = source.is_active,
    inventory_count = source.inventory_count,
    supplier_info = source.supplier_info,
    specifications = source.specifications,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    product_id, product_name, category, price, cost, description, is_active,
    inventory_count, supplier_info, specifications
) VALUES (
    source.product_id, source.product_name, source.category, source.price, source.cost,
    source.description, source.is_active, source.inventory_count, source.supplier_info,
    source.specifications
);

-- Insert sample orders
MERGE INTO orders AS target
USING (
    SELECT 
        order_id, customer_id, order_date, total_amount, status,
        PARSE_JSON(shipping_address_str) AS shipping_address,
        payment_method, discount_amount, tax_amount
    FROM VALUES
        ('ORD001', 'CUST001', '2024-01-15 10:30:00'::TIMESTAMP_NTZ, 12500.00, 'COMPLETED',
         '{"street": "123 Main St", "city": "New York", "state": "NY", "zip": "10001"}',
         'Credit Card', 0.00, 1250.00),
        ('ORD002', 'CUST002', '2024-01-20 14:15:00'::TIMESTAMP_NTZ, 10000.00, 'COMPLETED',
         '{"street": "456 Tech Blvd", "city": "San Francisco", "state": "CA", "zip": "94102"}',
         'Wire Transfer', 500.00, 950.00),
        ('ORD003', 'CUST003', '2024-02-01 09:45:00'::TIMESTAMP_NTZ, 7500.00, 'PROCESSING',
         '{"street": "789 Innovation Dr", "city": "Austin", "state": "TX", "zip": "73301"}',
         'Credit Card', 0.00, 750.00),
        ('ORD004', 'CUST004', '2024-02-05 16:20:00'::TIMESTAMP_NTZ, 6000.00, 'SHIPPED',
         '{"street": "321 Commerce Ave", "city": "Chicago", "state": "IL", "zip": "60601"}',
         'Net 30', 300.00, 570.00),
        ('ORD005', 'CUST005', '2024-02-10 11:00:00'::TIMESTAMP_NTZ, 14000.00, 'PENDING',
         '{"street": "654 Industrial Way", "city": "Detroit", "state": "MI", "zip": "48201"}',
         'Purchase Order', 700.00, 1330.00),
        ('ORD006', 'CUST006', '2024-02-12 13:30:00'::TIMESTAMP_NTZ, 18500.00, 'COMPLETED',
         '{"street": "987 Medical Center Dr", "city": "Boston", "state": "MA", "zip": "02115"}',
         'Wire Transfer', 925.00, 1665.00),
        ('ORD007', 'CUST007', '2024-02-14 10:15:00'::TIMESTAMP_NTZ, 5400.00, 'SHIPPED',
         '{"street": "246 Campus Rd", "city": "Seattle", "state": "WA", "zip": "98195"}',
         'Credit Card', 270.00, 486.00),
        ('ORD008', 'CUST008', '2024-02-16 15:45:00'::TIMESTAMP_NTZ, 25000.00, 'PROCESSING',
         '{"street": "135 Wall St", "city": "New York", "state": "NY", "zip": "10005"}',
         'ACH Transfer', 1250.00, 2250.00),
        ('ORD009', 'CUST009', '2024-02-18 12:00:00'::TIMESTAMP_NTZ, 8700.00, 'COMPLETED',
         '{"street": "468 Hollywood Blvd", "city": "Los Angeles", "state": "CA", "zip": "90028"}',
         'Credit Card', 435.00, 783.00),
        ('ORD010', 'CUST010', '2024-02-20 09:30:00'::TIMESTAMP_NTZ, 3400.00, 'PENDING',
         '{"street": "753 Main St", "city": "Denver", "state": "CO", "zip": "80202"}',
         'Net 15', 170.00, 306.00)
    AS source(order_id, customer_id, order_date, total_amount, status, 
              shipping_address_str, payment_method, discount_amount, tax_amount)
) AS source
ON target.order_id = source.order_id
WHEN MATCHED THEN UPDATE SET
    customer_id = source.customer_id,
    order_date = source.order_date,
    total_amount = source.total_amount,
    status = source.status,
    shipping_address = source.shipping_address,
    payment_method = source.payment_method,
    discount_amount = source.discount_amount,
    tax_amount = source.tax_amount,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    order_id, customer_id, order_date, total_amount, status,
    shipping_address, payment_method, discount_amount, tax_amount
) VALUES (
    source.order_id, source.customer_id, source.order_date, source.total_amount,
    source.status, source.shipping_address, source.payment_method,
    source.discount_amount, source.tax_amount
);

-- Insert sample order items
MERGE INTO order_items AS target
USING (
    SELECT * FROM VALUES
        ('OI001', 'ORD001', 'PROD001', 2, 5000.00, 10000.00),
        ('OI002', 'ORD001', 'PROD002', 1, 2500.00, 2500.00),
        ('OI003', 'ORD002', 'PROD001', 2, 5000.00, 10000.00),
        ('OI004', 'ORD003', 'PROD003', 1, 7500.00, 7500.00),
        ('OI005', 'ORD004', 'PROD002', 1, 2500.00, 2500.00),
        ('OI006', 'ORD004', 'PROD004', 3, 1200.00, 3600.00),
        ('OI007', 'ORD005', 'PROD001', 1, 5000.00, 5000.00),
        ('OI008', 'ORD005', 'PROD003', 1, 7500.00, 7500.00),
        ('OI009', 'ORD005', 'PROD004', 1, 1200.00, 1200.00),
        ('OI010', 'ORD006', 'PROD006', 2, 4800.00, 9600.00),
        ('OI011', 'ORD006', 'PROD007', 1, 6200.00, 6200.00),
        ('OI012', 'ORD006', 'PROD002', 1, 2500.00, 2500.00),
        ('OI013', 'ORD007', 'PROD008', 1, 3800.00, 3800.00),
        ('OI014', 'ORD007', 'PROD009', 1, 2200.00, 2200.00),
        ('OI015', 'ORD008', 'PROD010', 2, 8500.00, 17000.00),
        ('OI016', 'ORD008', 'PROD001', 1, 5000.00, 5000.00),
        ('OI017', 'ORD008', 'PROD003', 1, 7500.00, 7500.00),
        ('OI018', 'ORD009', 'PROD006', 1, 4800.00, 4800.00),
        ('OI019', 'ORD009', 'PROD008', 1, 3800.00, 3800.00),
        ('OI020', 'ORD010', 'PROD009', 1, 2200.00, 2200.00),
        ('OI021', 'ORD010', 'PROD004', 1, 1200.00, 1200.00)
    AS source(order_item_id, order_id, product_id, quantity, unit_price, total_price)
) AS source
ON target.order_item_id = source.order_item_id
WHEN MATCHED THEN UPDATE SET
    order_id = source.order_id,
    product_id = source.product_id,
    quantity = source.quantity,
    unit_price = source.unit_price,
    total_price = source.total_price
WHEN NOT MATCHED THEN INSERT (
    order_item_id, order_id, product_id, quantity, unit_price, total_price
) VALUES (
    source.order_item_id, source.order_id, source.product_id,
    source.quantity, source.unit_price, source.total_price
);

-- Insert sample job records
MERGE INTO jobs AS target
USING (
    SELECT 
        job_id, job_name, job_type, status, created_by, created_at, updated_at,
        PARSE_JSON(input_data_str) AS input_data,
        output_location, error_message, execution_time_seconds,
        priority, retry_count, max_retries,
        PARSE_JSON(tags_str) AS tags,
        PARSE_JSON(metadata_str) AS metadata
    FROM VALUES
        ('JOB001', 'Daily Sales Report', 'REPORT', 'COMPLETED', 'system',
         '2024-02-01 08:00:00'::TIMESTAMP_NTZ, '2024-02-01 08:05:00'::TIMESTAMP_NTZ,
         '{"date_range": "2024-01-31", "format": "PDF"}',
         's3://reports-bucket/daily/2024-02-01-sales.pdf',
         NULL, 45.2, 1, 0, 3,
         '["daily", "sales", "automated"]',
         '{"schedule": "daily", "recipients": ["manager@company.com"]}'),
        ('JOB002', 'Customer Analysis', 'ANALYSIS', 'COMPLETED', 'analyst1',
         '2024-02-02 10:30:00'::TIMESTAMP_NTZ, '2024-02-02 10:45:00'::TIMESTAMP_NTZ,
         '{"customer_segment": "enterprise", "metrics": ["ltv", "churn"]}',
         's3://reports-bucket/analysis/2024-02-02-customer-analysis.xlsx',
         NULL, 125.7, 2, 0, 3,
         '["analysis", "customer", "enterprise"]',
         '{"analyst": "analyst1", "department": "marketing"}'),
        ('JOB003', 'Inventory Update', 'DATA_SYNC', 'RUNNING', 'system',
         '2024-02-03 14:00:00'::TIMESTAMP_NTZ, CURRENT_TIMESTAMP(),
         '{"source": "ERP", "target": "warehouse"}',
         NULL, NULL, NULL, 3, 0, 3,
         '["sync", "inventory", "automated"]',
         '{"schedule": "hourly", "source_system": "SAP_ERP"}'),
        ('JOB004', 'Weekly Performance Report', 'REPORT', 'COMPLETED', 'analyst2',
         '2024-02-04 07:00:00'::TIMESTAMP_NTZ, '2024-02-04 07:25:00'::TIMESTAMP_NTZ,
         '{"date_range": "2024-01-28_to_2024-02-03", "format": "Excel"}',
         's3://reports-bucket/weekly/2024-02-04-performance.xlsx',
         NULL, 95.3, 2, 0, 3,
         '["weekly", "performance", "manual"]',
         '{"analyst": "analyst2", "department": "operations"}'),
        ('JOB005', 'Data Quality Check', 'VALIDATION', 'FAILED', 'system',
         '2024-02-05 02:00:00'::TIMESTAMP_NTZ, '2024-02-05 02:15:00'::TIMESTAMP_NTZ,
         '{"tables": ["customers", "orders"], "rules": "standard"}',
         NULL, 'Duplicate records found in customers table', 67.8, 1, 2, 3,
         '["validation", "quality", "automated"]',
         '{"schedule": "daily", "threshold": 0.01}'),
        ('JOB006', 'Customer Segmentation', 'ANALYSIS', 'PROCESSING', 'analyst3',
         '2024-02-06 11:15:00'::TIMESTAMP_NTZ, CURRENT_TIMESTAMP(),
         '{"algorithm": "kmeans", "features": ["ltv", "frequency", "recency"]}',
         NULL, NULL, NULL, 2, 0, 3,
         '["analysis", "segmentation", "ml"]',
         '{"analyst": "analyst3", "department": "marketing"}'),
        ('JOB007', 'Backup Database', 'MAINTENANCE', 'COMPLETED', 'system',
         '2024-02-07 00:00:00'::TIMESTAMP_NTZ, '2024-02-07 01:45:00'::TIMESTAMP_NTZ,
         '{"database": "analytics_platform", "compression": true}',
         's3://backup-bucket/2024-02-07/analytics_platform.sql.gz',
         NULL, 6300.0, 3, 0, 3,
         '["backup", "maintenance", "automated"]',
         '{"schedule": "daily", "retention_days": 30}')
    AS source(job_id, job_name, job_type, status, created_by, created_at, updated_at,
              input_data_str, output_location, error_message, execution_time_seconds,
              priority, retry_count, max_retries, tags_str, metadata_str)
) AS source
ON target.job_id = source.job_id
WHEN MATCHED THEN UPDATE SET
    job_name = source.job_name,
    job_type = source.job_type,
    status = source.status,
    created_by = source.created_by,
    input_data = source.input_data,
    output_location = source.output_location,
    error_message = source.error_message,
    execution_time_seconds = source.execution_time_seconds,
    priority = source.priority,
    retry_count = source.retry_count,
    max_retries = source.max_retries,
    tags = source.tags,
    metadata = source.metadata,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    job_id, job_name, job_type, status, created_by, created_at, updated_at,
    input_data, output_location, error_message, execution_time_seconds,
    priority, retry_count, max_retries, tags, metadata
) VALUES (
    source.job_id, source.job_name, source.job_type, source.status, source.created_by,
    source.created_at, source.updated_at, source.input_data, source.output_location,
    source.error_message, source.execution_time_seconds, source.priority,
    source.retry_count, source.max_retries, source.tags, source.metadata
);

-- Insert sample sales metrics
MERGE INTO processed_data.sales_metrics AS target
USING (
    SELECT * FROM VALUES
        ('SM001', '2024-01-31'::DATE, 12500.00, 1, 1, 12500.00, 'Analytics Platform Pro', 'Software'),
        ('SM002', '2024-02-01'::DATE, 10000.00, 1, 1, 10000.00, 'Analytics Platform Pro', 'Software'),
        ('SM003', '2024-02-02'::DATE, 7500.00, 1, 1, 7500.00, 'Machine Learning Toolkit', 'Software'),
        ('SM004', '2024-02-05'::DATE, 6000.00, 1, 1, 6000.00, 'Data Visualization Suite', 'Software'),
        ('SM005', '2024-02-10'::DATE, 14000.00, 1, 1, 14000.00, 'Analytics Platform Pro', 'Software'),
        ('SM006', '2024-02-12'::DATE, 18500.00, 1, 1, 18500.00, 'Cloud Security Suite', 'Security'),
        ('SM007', '2024-02-14'::DATE, 5400.00, 1, 1, 5400.00, 'API Gateway Enterprise', 'Infrastructure'),
        ('SM008', '2024-02-16'::DATE, 25000.00, 1, 1, 25000.00, 'IoT Data Platform', 'Platform'),
        ('SM009', '2024-02-18'::DATE, 8700.00, 1, 1, 8700.00, 'Cloud Security Suite', 'Security'),
        ('SM010', '2024-02-20'::DATE, 3400.00, 1, 1, 3400.00, 'Mobile Development Kit', 'Software'),
        ('SM011', '2024-02-21'::DATE, 15600.00, 2, 2, 7800.00, 'Data Visualization Suite', 'Software'),
        ('SM012', '2024-02-22'::DATE, 22300.00, 3, 2, 11150.00, 'Machine Learning Toolkit', 'Software')
    AS source(metric_id, metric_date, total_sales, total_orders, unique_customers,
              average_order_value, top_product, top_category)
) AS source
ON target.metric_id = source.metric_id
WHEN MATCHED THEN UPDATE SET
    metric_date = source.metric_date,
    total_sales = source.total_sales,
    total_orders = source.total_orders,
    unique_customers = source.unique_customers,
    average_order_value = source.average_order_value,
    top_product = source.top_product,
    top_category = source.top_category,
    updated_at = CURRENT_TIMESTAMP()
WHEN NOT MATCHED THEN INSERT (
    metric_id, metric_date, total_sales, total_orders, unique_customers,
    average_order_value, top_product, top_category
) VALUES (
    source.metric_id, source.metric_date, source.total_sales, source.total_orders,
    source.unique_customers, source.average_order_value, source.top_product,
    source.top_category
);

-- Verify data insertion
SELECT 'customers' as table_name, COUNT(*) as record_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'jobs', COUNT(*) FROM jobs
UNION ALL
SELECT 'sales_metrics', COUNT(*) FROM processed_data.sales_metrics;