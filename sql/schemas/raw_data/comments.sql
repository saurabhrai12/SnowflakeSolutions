-- Raw Data Schema Table Comments
-- Documentation for all tables

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- Add table comments for documentation
ALTER TABLE jobs SET COMMENT = 'Job tracking table with automatic task triggering for external processing';
ALTER TABLE customers SET COMMENT = 'Customer master data with hierarchical information and lifetime value tracking';
ALTER TABLE products SET COMMENT = 'Product catalog with pricing, inventory, and supplier information';
ALTER TABLE orders SET COMMENT = 'Order transactions with full lifecycle tracking and payment details';
ALTER TABLE order_items SET COMMENT = 'Order line items with product details and pricing information';

-- Add column comments using correct Snowflake syntax
COMMENT ON COLUMN jobs.job_id IS 'Unique identifier for each job';
COMMENT ON COLUMN jobs.job_type IS 'Type of job: REPORT, ANALYSIS, DATA_SYNC, etc.';
COMMENT ON COLUMN jobs.status IS 'Current status: PENDING, RUNNING, COMPLETED, FAILED';
COMMENT ON COLUMN jobs.priority IS 'Job priority: 1=High, 2=Medium, 3=Low';
COMMENT ON COLUMN jobs.input_data IS 'JSON payload with job parameters';
COMMENT ON COLUMN jobs.metadata IS 'Additional job metadata and tracking information';

COMMENT ON COLUMN customers.customer_tier IS 'Customer tier: STANDARD, PREMIUM, ENTERPRISE';
COMMENT ON COLUMN customers.lifetime_value IS 'Total lifetime value of customer in USD';
COMMENT ON COLUMN customers.address IS 'JSON object with address components';
COMMENT ON COLUMN customers.tags IS 'Array of customer tags for segmentation';

COMMENT ON COLUMN products.specifications IS 'JSON object with product specifications';
COMMENT ON COLUMN products.supplier_info IS 'JSON object with supplier and support information';

COMMENT ON COLUMN orders.shipping_address IS 'JSON object with shipping address details';
COMMENT ON COLUMN orders.status IS 'Order status: PENDING, PROCESSING, SHIPPED, COMPLETED, CANCELLED';