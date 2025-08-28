-- Snowflake Performance Optimization
-- Uses clustering keys and search optimization instead of traditional indexes

USE DATABASE analytics_platform;
USE SCHEMA raw_data;

-- ============================================
-- CLUSTERING KEYS (Snowflake's way of optimization)
-- ============================================

-- Cluster jobs table by status and created_at for efficient filtering
ALTER TABLE jobs CLUSTER BY (status, created_at);

-- Cluster customers by customer_tier and is_active for segmentation queries
ALTER TABLE customers CLUSTER BY (customer_tier, is_active);

-- Cluster products by category and is_active for catalog queries
ALTER TABLE products CLUSTER BY (category, is_active);

-- Cluster orders by customer_id and order_date for time-series and customer analysis
ALTER TABLE orders CLUSTER BY (customer_id, order_date);

-- Cluster order_items by order_id for join performance
ALTER TABLE order_items CLUSTER BY (order_id);

-- ============================================
-- SEARCH OPTIMIZATION SERVICE (for point lookups)
-- ============================================

-- Enable search optimization for tables with frequent point lookups
-- This is Snowflake's equivalent to indexes for specific use cases

-- Enable for customers table (email lookups)
ALTER TABLE customers ADD SEARCH OPTIMIZATION;

-- Enable for products table (product_id and name searches)
ALTER TABLE products ADD SEARCH OPTIMIZATION;

-- Enable for jobs table (job_id and status lookups)
ALTER TABLE jobs ADD SEARCH OPTIMIZATION;

-- ============================================
-- COMMENTS ON OPTIMIZATION STRATEGY
-- ============================================

-- Add comments explaining the optimization strategy
COMMENT ON TABLE jobs IS 'Clustered by (status, created_at) for efficient job monitoring and time-based queries. Search optimization enabled for job_id lookups.';

COMMENT ON TABLE customers IS 'Clustered by (customer_tier, is_active) for customer segmentation. Search optimization enabled for email lookups.';

COMMENT ON TABLE products IS 'Clustered by (category, is_active) for product catalog queries. Search optimization enabled for product searches.';

COMMENT ON TABLE orders IS 'Clustered by (customer_id, order_date) for customer analysis and time-series reporting.';

COMMENT ON TABLE order_items IS 'Clustered by (order_id) for efficient order detail queries and joins.';