-- Data Pipeline Streams for CDC (Change Data Capture)
-- Captures changes from raw_data tables to trigger processing
-- Note: Streams use CREATE STREAM IF NOT EXISTS for idempotency

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- Stream to capture customer changes
CREATE STREAM IF NOT EXISTS customers_stream 
ON TABLE customers
APPEND_ONLY = FALSE
COMMENT = 'Captures customer table changes for processing to analytics tables';

-- Stream to capture product changes
CREATE OR REPLACE STREAM products_stream 
ON TABLE products
APPEND_ONLY = FALSE
COMMENT = 'Captures product table changes for processing to analytics tables';

-- Stream to capture order changes
CREATE STREAM IF NOT EXISTS orders_stream 
ON TABLE orders
APPEND_ONLY = FALSE
COMMENT = 'Captures order table changes for processing to analytics and metrics';

-- Stream to capture order items changes
CREATE STREAM IF NOT EXISTS order_items_stream 
ON TABLE order_items
APPEND_ONLY = FALSE
COMMENT = 'Captures order items changes for processing to analytics';

-- Grant permissions on streams
GRANT SELECT ON STREAM customers_stream TO ROLE PUBLIC;
GRANT SELECT ON STREAM products_stream TO ROLE PUBLIC;
GRANT SELECT ON STREAM orders_stream TO ROLE PUBLIC;
GRANT SELECT ON STREAM order_items_stream TO ROLE PUBLIC;