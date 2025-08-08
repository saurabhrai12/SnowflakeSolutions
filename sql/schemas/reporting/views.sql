-- Reporting Schema Views
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE analytics_platform;
USE SCHEMA reporting;

-- Customer 360 view with enriched data
CREATE OR ALTER VIEW customer_360 AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.email,
    c.phone,
    c.customer_tier,
    c.lifetime_value,
    c.is_active,
    c.created_at as customer_since,
    c.tags as customer_tags,
    c.profile_score,
    
    -- Order metrics
    COUNT(DISTINCT o.order_id) as total_orders,
    COALESCE(SUM(o.total_amount), 0) as total_spent,
    COALESCE(AVG(o.total_amount), 0) as avg_order_value,
    MAX(o.order_date) as last_order_date,
    MIN(o.order_date) as first_order_date,
    
    -- Product preferences
    ARRAY_AGG(DISTINCT p.category) WITHIN GROUP (ORDER BY p.category) as preferred_categories,
    ARRAY_AGG(DISTINCT p.product_name) WITHIN GROUP (ORDER BY p.product_name) as purchased_products,
    
    -- Calculated fields
    DATEDIFF('day', MAX(o.order_date), CURRENT_DATE()) as days_since_last_order,
    CASE 
        WHEN DATEDIFF('day', MAX(o.order_date), CURRENT_DATE()) <= 30 THEN 'Active'
        WHEN DATEDIFF('day', MAX(o.order_date), CURRENT_DATE()) <= 90 THEN 'At Risk'
        ELSE 'Inactive'
    END as customer_status,
    
    -- Address information
    c.address:street::STRING as street,
    c.address:city::STRING as city,
    c.address:state::STRING as state,
    c.address:zip::STRING as zip_code
    
FROM raw_data.customers c
LEFT JOIN raw_data.orders o ON c.customer_id = o.customer_id
LEFT JOIN raw_data.order_items oi ON o.order_id = oi.order_id
LEFT JOIN raw_data.products p ON oi.product_id = p.product_id
WHERE c.is_active = TRUE
GROUP BY 
    c.customer_id, c.customer_name, c.email, c.phone, c.customer_tier,
    c.lifetime_value, c.is_active, c.created_at, c.tags, c.address, c.profile_score;

-- Sales performance view
CREATE OR ALTER VIEW sales_performance AS
SELECT 
    DATE_TRUNC('month', o.order_date) as sales_month,
    DATE_TRUNC('quarter', o.order_date) as sales_quarter,
    DATE_TRUNC('year', o.order_date) as sales_year,
    
    -- Revenue metrics
    COUNT(DISTINCT o.order_id) as total_orders,
    COUNT(DISTINCT o.customer_id) as unique_customers,
    SUM(o.total_amount) as total_revenue,
    AVG(o.total_amount) as avg_order_value,
    SUM(o.discount_amount) as total_discounts,
    SUM(o.tax_amount) as total_tax,
    
    -- Product metrics
    COUNT(DISTINCT oi.product_id) as unique_products_sold,
    SUM(oi.quantity) as total_items_sold,
    
    -- Top performers
    MODE(p.product_name) as top_selling_product,
    MODE(p.category) as top_selling_category,
    MODE(c.customer_tier) as dominant_customer_tier,
    
    -- Growth metrics
    LAG(SUM(o.total_amount), 1) OVER (ORDER BY DATE_TRUNC('month', o.order_date)) as prev_month_revenue,
    SUM(o.total_amount) - LAG(SUM(o.total_amount), 1) OVER (ORDER BY DATE_TRUNC('month', o.order_date)) as revenue_growth,
    
    -- Calculated percentages
    ROUND(
        (SUM(o.total_amount) - LAG(SUM(o.total_amount), 1) OVER (ORDER BY DATE_TRUNC('month', o.order_date))) / 
        NULLIF(LAG(SUM(o.total_amount), 1) OVER (ORDER BY DATE_TRUNC('month', o.order_date)), 0) * 100, 2
    ) as revenue_growth_pct

FROM raw_data.orders o
JOIN raw_data.order_items oi ON o.order_id = oi.order_id
JOIN raw_data.products p ON oi.product_id = p.product_id
JOIN raw_data.customers c ON o.customer_id = c.customer_id
WHERE o.status IN ('COMPLETED', 'SHIPPED')
GROUP BY 
    DATE_TRUNC('month', o.order_date),
    DATE_TRUNC('quarter', o.order_date),
    DATE_TRUNC('year', o.order_date)
ORDER BY sales_month DESC;

-- Product performance view
CREATE OR ALTER VIEW product_performance AS
SELECT 
    p.product_id,
    p.product_name,
    p.category,
    p.price,
    p.cost,
    p.price - p.cost as gross_margin,
    ROUND((p.price - p.cost) / NULLIF(p.price, 0) * 100, 2) as margin_percentage,
    
    -- Sales metrics
    COUNT(DISTINCT oi.order_id) as orders_containing_product,
    SUM(oi.quantity) as total_quantity_sold,
    SUM(oi.total_price) as total_revenue,
    AVG(oi.quantity) as avg_quantity_per_order,
    
    -- Customer metrics
    COUNT(DISTINCT o.customer_id) as unique_customers,
    COUNT(DISTINCT CASE WHEN c.customer_tier = 'ENTERPRISE' THEN o.customer_id END) as enterprise_customers,
    
    -- Time-based metrics
    MIN(o.order_date) as first_sale_date,
    MAX(o.order_date) as last_sale_date,
    DATEDIFF('day', MIN(o.order_date), MAX(o.order_date)) as sale_period_days,
    
    -- Inventory and specifications
    p.inventory_count,
    p.supplier_info:vendor::STRING as vendor,
    p.supplier_info:support_level::STRING as support_level,
    p.specifications,
    p.popularity_score,
    
    -- Rankings
    RANK() OVER (ORDER BY SUM(oi.total_price) DESC) as revenue_rank,
    RANK() OVER (ORDER BY SUM(oi.quantity) DESC) as quantity_rank,
    RANK() OVER (PARTITION BY p.category ORDER BY SUM(oi.total_price) DESC) as category_revenue_rank

FROM raw_data.products p
LEFT JOIN raw_data.order_items oi ON p.product_id = oi.product_id
LEFT JOIN raw_data.orders o ON oi.order_id = o.order_id
LEFT JOIN raw_data.customers c ON o.customer_id = c.customer_id
WHERE p.is_active = TRUE
GROUP BY 
    p.product_id, p.product_name, p.category, p.price, p.cost,
    p.inventory_count, p.supplier_info, p.specifications, p.popularity_score
ORDER BY total_revenue DESC NULLS LAST;

-- Job monitoring view
CREATE OR ALTER VIEW job_monitoring AS
SELECT 
    j.job_id,
    j.job_name,
    j.job_type,
    j.status,
    j.created_by,
    j.created_at,
    j.updated_at,
    j.execution_time_seconds,
    j.priority,
    j.retry_count,
    j.max_retries,
    j.error_message,
    j.output_location,
    j.tags,
    
    -- Calculated fields
    DATEDIFF('minute', j.created_at, COALESCE(j.updated_at, CURRENT_TIMESTAMP())) as total_runtime_minutes,
    CASE 
        WHEN j.status = 'COMPLETED' THEN 'Success'
        WHEN j.status = 'FAILED' AND j.retry_count >= j.max_retries THEN 'Failed (Max Retries)'
        WHEN j.status = 'FAILED' THEN 'Failed (Will Retry)'
        WHEN j.status = 'RUNNING' AND DATEDIFF('hour', j.created_at, CURRENT_TIMESTAMP()) > 2 THEN 'Long Running'
        WHEN j.status = 'RUNNING' THEN 'In Progress'
        ELSE j.status
    END as job_health_status,
    
    -- Input/Output parsing
    j.input_data:report_type::STRING as report_type,
    j.input_data:date_range::STRING as date_range,
    j.input_data:format::STRING as output_format,
    j.metadata:schedule::STRING as schedule_type,
    j.metadata:department::STRING as requesting_department,
    
    -- Time-based grouping
    DATE_TRUNC('hour', j.created_at) as created_hour,
    DATE_TRUNC('day', j.created_at) as created_date

FROM raw_data.jobs j
ORDER BY j.created_at DESC;

-- Executive dashboard view
CREATE OR ALTER VIEW executive_dashboard AS
SELECT 
    -- Time period
    CURRENT_DATE() as report_date,
    'YTD' as period_type,
    
    -- Revenue metrics
    (SELECT SUM(total_amount) FROM raw_data.orders 
     WHERE YEAR(order_date) = YEAR(CURRENT_DATE()) AND status IN ('COMPLETED', 'SHIPPED')) as ytd_revenue,
    (SELECT SUM(total_amount) FROM raw_data.orders 
     WHERE YEAR(order_date) = YEAR(CURRENT_DATE()) - 1 AND status IN ('COMPLETED', 'SHIPPED')) as last_year_revenue,
    
    -- Customer metrics
    (SELECT COUNT(DISTINCT customer_id) FROM raw_data.customers WHERE is_active = TRUE) as total_active_customers,
    (SELECT COUNT(DISTINCT customer_id) FROM raw_data.orders 
     WHERE YEAR(order_date) = YEAR(CURRENT_DATE())) as customers_with_orders_ytd,
    
    -- Product metrics
    (SELECT COUNT(*) FROM raw_data.products WHERE is_active = TRUE) as active_products,
    (SELECT COUNT(DISTINCT product_id) FROM raw_data.order_items oi 
     JOIN raw_data.orders o ON oi.order_id = o.order_id
     WHERE YEAR(o.order_date) = YEAR(CURRENT_DATE())) as products_sold_ytd,
    
    -- Order metrics
    (SELECT COUNT(*) FROM raw_data.orders 
     WHERE YEAR(order_date) = YEAR(CURRENT_DATE()) AND status IN ('COMPLETED', 'SHIPPED')) as orders_ytd,
    (SELECT AVG(total_amount) FROM raw_data.orders 
     WHERE YEAR(order_date) = YEAR(CURRENT_DATE()) AND status IN ('COMPLETED', 'SHIPPED')) as avg_order_value_ytd,
    
    -- Job metrics
    (SELECT COUNT(*) FROM raw_data.jobs WHERE DATE(created_at) = CURRENT_DATE()) as jobs_today,
    (SELECT COUNT(*) FROM raw_data.jobs 
     WHERE DATE(created_at) = CURRENT_DATE() AND status = 'COMPLETED') as jobs_completed_today,
    (SELECT COUNT(*) FROM raw_data.jobs 
     WHERE DATE(created_at) = CURRENT_DATE() AND status = 'FAILED') as jobs_failed_today;

-- Real-time operational view
CREATE OR ALTER VIEW operational_status AS
SELECT 
    -- Current time info
    CURRENT_TIMESTAMP() as last_updated,
    
    -- Active jobs
    COUNT(CASE WHEN j.status = 'RUNNING' THEN 1 END) as jobs_running,
    COUNT(CASE WHEN j.status = 'PENDING' THEN 1 END) as jobs_pending,
    COUNT(CASE WHEN j.status = 'FAILED' AND j.retry_count < j.max_retries THEN 1 END) as jobs_retrying,
    
    -- Recent activity (last 24 hours)
    COUNT(CASE WHEN j.created_at >= DATEADD('hour', -24, CURRENT_TIMESTAMP()) THEN 1 END) as jobs_last_24h,
    COUNT(CASE WHEN o.order_date >= DATEADD('hour', -24, CURRENT_TIMESTAMP()) THEN 1 END) as orders_last_24h,
    
    -- Data freshness
    MAX(j.updated_at) as last_job_update,
    MAX(o.created_at) as last_order_created,
    MAX(sm.updated_at) as last_metrics_update,
    
    -- System health indicators
    CASE 
        WHEN COUNT(CASE WHEN j.status = 'FAILED' AND j.created_at >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 1 END) > 5 
        THEN 'UNHEALTHY'
        WHEN COUNT(CASE WHEN j.status = 'FAILED' AND j.created_at >= DATEADD('hour', -1, CURRENT_TIMESTAMP()) THEN 1 END) > 0 
        THEN 'WARNING'
        ELSE 'HEALTHY'
    END as system_health_status

FROM raw_data.jobs j
CROSS JOIN raw_data.orders o
CROSS JOIN processed_data.sales_metrics sm;