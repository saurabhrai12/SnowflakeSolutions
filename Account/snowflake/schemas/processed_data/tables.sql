-- Processed Data Schema Tables
-- Uses CREATE OR ALTER for idempotent deployments

USE DATABASE {{ database }};
USE SCHEMA processed_data;

-- Create or alter sales metrics table for reporting
CREATE OR ALTER TABLE sales_metrics (
    metric_id STRING PRIMARY KEY,
    metric_date DATE NOT NULL,
    total_sales NUMBER(15,2),
    total_orders NUMBER(10,0),
    unique_customers NUMBER(10,0),
    average_order_value NUMBER(10,2),
    top_product STRING,
    top_category STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create or alter customer analytics table
CREATE OR ALTER TABLE customer_analytics (
    analytics_id STRING PRIMARY KEY,
    customer_id STRING NOT NULL,
    analysis_date DATE NOT NULL,
    total_orders NUMBER(10,0),
    total_spent NUMBER(12,2),
    avg_order_value NUMBER(10,2),
    days_since_last_order NUMBER(10,0),
    customer_status STRING,
    predicted_ltv NUMBER(12,2),
    churn_risk_score NUMBER(3,2),
    preferred_categories ARRAY,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create or alter product analytics table
CREATE OR ALTER TABLE product_analytics (
    analytics_id STRING PRIMARY KEY,
    product_id STRING NOT NULL,
    analysis_date DATE NOT NULL,
    total_quantity_sold NUMBER(10,0),
    total_revenue NUMBER(12,2),
    profit_margin NUMBER(10,2),
    inventory_turnover NUMBER(5,2),
    demand_trend STRING,
    seasonality_factor NUMBER(3,2),
    recommendation STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create or alter aggregated daily metrics
CREATE OR ALTER TABLE daily_metrics (
    metric_date DATE PRIMARY KEY,
    total_revenue NUMBER(15,2),
    total_orders NUMBER(10,0),
    unique_customers NUMBER(10,0),
    new_customers NUMBER(10,0),
    returning_customers NUMBER(10,0),
    average_order_value NUMBER(10,2),
    products_sold NUMBER(10,0),
    top_selling_product STRING,
    top_selling_category STRING,
    jobs_completed NUMBER(8,0),
    jobs_failed NUMBER(8,0),
    system_health_score NUMBER(3,2),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);