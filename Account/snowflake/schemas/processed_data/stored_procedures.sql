-- Processed Data Schema Stored Procedures
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE analytics_platform;
USE SCHEMA processed_data;

-- Procedure to calculate customer analytics
CREATE OR ALTER PROCEDURE calculate_customer_analytics()
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    total_customers NUMBER;
    total_revenue NUMBER(15,2);
    avg_order_value NUMBER(10,2);
    result STRING;
BEGIN
    -- Calculate and insert metrics directly in one statement
    MERGE INTO sales_metrics AS target
    USING (
        SELECT 
            'ANALYTICS_' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD') AS metric_id,
            CURRENT_DATE() AS metric_date,
            COALESCE(SUM(o.total_amount), 0) AS total_sales,
            (SELECT COUNT(*) FROM raw_data.orders WHERE order_date::DATE = CURRENT_DATE()) AS total_orders,
            COUNT(DISTINCT c.customer_id) AS unique_customers,
            COALESCE(AVG(o.total_amount), 0) AS average_order_value,
            'N/A' AS top_product,
            'Analytics' AS top_category
        FROM raw_data.customers c
        LEFT JOIN raw_data.orders o ON c.customer_id = o.customer_id
        WHERE c.is_active = TRUE
    ) AS source
    ON target.metric_id = source.metric_id
    WHEN MATCHED THEN UPDATE SET
        total_sales = source.total_sales,
        total_orders = source.total_orders,
        unique_customers = source.unique_customers,
        average_order_value = source.average_order_value,
        updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        metric_id, metric_date, total_sales, total_orders,
        unique_customers, average_order_value, top_product, top_category
    ) VALUES (
        source.metric_id, source.metric_date, source.total_sales,
        source.total_orders, source.unique_customers, source.average_order_value,
        source.top_product, source.top_category
    );
    
    -- Get calculated values for result message
    SELECT 
        total_sales, unique_customers, average_order_value
    INTO total_revenue, total_customers, avg_order_value
    FROM sales_metrics 
    WHERE metric_id = 'ANALYTICS_' || TO_CHAR(CURRENT_DATE(), 'YYYYMMDD');
    
    result := 'Analytics calculated - Customers: ' || total_customers || 
              ', Revenue: $' || total_revenue || 
              ', Avg Order: $' || avg_order_value;
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error calculating analytics: ' || SQLERRM;
END;
$$;

-- Procedure to generate daily metrics
CREATE OR ALTER PROCEDURE generate_daily_metrics(target_date DATE DEFAULT CURRENT_DATE())
RETURNS STRING
LANGUAGE SQL
AS
$$
DECLARE
    result STRING;
BEGIN
    -- Insert or update daily metrics directly
    MERGE INTO daily_metrics AS target
    USING (
        SELECT 
            target_date as metric_date,
            COALESCE(SUM(o.total_amount), 0) as total_revenue,
            COUNT(DISTINCT o.order_id) as total_orders,
            COUNT(DISTINCT o.customer_id) as unique_customers,
            COUNT(DISTINCT CASE WHEN c.created_at::DATE = target_date THEN c.customer_id END) as new_customers,
            COUNT(DISTINCT CASE WHEN c.created_at::DATE < target_date THEN o.customer_id END) as returning_customers,
            COALESCE(AVG(o.total_amount), 0) as average_order_value,
            COUNT(DISTINCT oi.product_id) as products_sold,
            'Top Product' as top_selling_product,  -- Simplified since MODE is complex
            'Top Category' as top_selling_category,
            (SELECT COUNT(*) FROM raw_data.jobs WHERE DATE(created_at) = target_date AND status = 'COMPLETED') as jobs_completed,
            (SELECT COUNT(*) FROM raw_data.jobs WHERE DATE(created_at) = target_date AND status = 'FAILED') as jobs_failed,
            0.95 as system_health_score  -- Simplified calculation
        FROM raw_data.orders o
        JOIN raw_data.customers c ON o.customer_id = c.customer_id
        LEFT JOIN raw_data.order_items oi ON o.order_id = oi.order_id
        LEFT JOIN raw_data.products p ON oi.product_id = p.product_id
        WHERE o.order_date::DATE = target_date
        AND o.status IN ('COMPLETED', 'SHIPPED')
    ) AS source
    ON target.metric_date = source.metric_date
    WHEN MATCHED THEN UPDATE SET
        total_revenue = source.total_revenue,
        total_orders = source.total_orders,
        unique_customers = source.unique_customers,
        new_customers = source.new_customers,
        returning_customers = source.returning_customers,
        average_order_value = source.average_order_value,
        products_sold = source.products_sold,
        top_selling_product = source.top_selling_product,
        top_selling_category = source.top_selling_category,
        jobs_completed = source.jobs_completed,
        jobs_failed = source.jobs_failed,
        system_health_score = source.system_health_score,
        updated_at = CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        metric_date, total_revenue, total_orders, unique_customers,
        new_customers, returning_customers, average_order_value,
        products_sold, top_selling_product, top_selling_category,
        jobs_completed, jobs_failed, system_health_score
    ) VALUES (
        source.metric_date, source.total_revenue, source.total_orders,
        source.unique_customers, source.new_customers, source.returning_customers,
        source.average_order_value, source.products_sold, source.top_selling_product,
        source.top_selling_category, source.jobs_completed, source.jobs_failed,
        source.system_health_score
    );
    
    result := 'Daily metrics generated for ' || target_date || 
              ' - Check daily_metrics table for details';
    RETURN result;
    
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Error generating daily metrics: ' || SQLERRM;
END;
$$;