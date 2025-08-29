-- Raw Data Schema Tables
-- Uses CREATE OR ALTER for idempotent deployments
-- Uses Jinja templating for environment-specific configuration

USE DATABASE {{ database }};
USE SCHEMA raw_data;

-- Create or alter job tracking table with modern features
CREATE OR ALTER TABLE jobs (
    job_id STRING PRIMARY KEY,
    job_name STRING NOT NULL,
    job_type STRING NOT NULL,
    status STRING DEFAULT 'PENDING',
    created_by STRING NOT NULL,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    input_data VARIANT,
    output_location STRING,
    error_message STRING,
    execution_time_seconds NUMBER(10,2),
    priority NUMBER(1,0) DEFAULT 3,
    retry_count NUMBER(2,0) DEFAULT 0,
    max_retries NUMBER(2,0) DEFAULT 3,
    tags ARRAY,
    metadata VARIANT
) data_retention_time_in_days = {{ retention_days | default(30) }}
  {% if environment == 'prod' %}
  cluster by (created_at, status)
  {% endif %};

-- Create or alter customers table
CREATE OR ALTER TABLE customers (
    customer_id STRING PRIMARY KEY,
    customer_name STRING NOT NULL,
    email STRING UNIQUE NOT NULL,
    phone STRING,
    address VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    customer_tier STRING DEFAULT 'STANDARD',
    lifetime_value NUMBER(12,2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    tags ARRAY,
    birth_date DATE,
    preferred_language STRING DEFAULT 'EN',
    loyalty_points NUMBER(10,0) DEFAULT 0,
    marketing_consent BOOLEAN DEFAULT FALSE,
    last_login_date TIMESTAMP_NTZ,
    account_manager STRING,
    company_size STRING,
    industry STRING,
    annual_revenue NUMBER(15,2),
    profile_score NUMBER(3,0) DEFAULT 0 COMMENT 'Customer profile completeness score (0-100)'
);

-- Create or alter products table
CREATE OR ALTER TABLE products (
    product_id STRING PRIMARY KEY,
    product_name STRING NOT NULL,
    category STRING NOT NULL,
    price NUMBER(10,2) NOT NULL,
    cost NUMBER(10,2),
    description STRING,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    is_active BOOLEAN DEFAULT TRUE,
    inventory_count NUMBER(10,0) DEFAULT 0,
    supplier_info VARIANT,
    specifications VARIANT,
    sustainability_rating STRING,
    warranty_months NUMBER(3,0) DEFAULT 12,
    brand STRING,
    popularity_score NUMBER(5,2) DEFAULT 0.0 COMMENT 'Product popularity score based on sales and views',
    rating NUMBER(3,2) DEFAULT 0.0 COMMENT 'Average customer rating (0.00-5.00)',
    review_count NUMBER(10,0) DEFAULT 0 COMMENT 'Total number of customer reviews',
    weight_kg NUMBER(8,3) COMMENT 'Product weight in kilograms',
    dimensions VARIANT COMMENT 'Product dimensions (length, width, height)',
    color_options ARRAY COMMENT 'Available color variations',
    tags ARRAY COMMENT 'Product tags for search and categorization',
    launch_date DATE COMMENT 'Product launch date'
);

-- Create or alter orders table
CREATE OR ALTER TABLE orders (
    order_id STRING PRIMARY KEY,
    customer_id STRING NOT NULL,
    order_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    total_amount NUMBER(12,2) NOT NULL,
    status STRING DEFAULT 'PENDING',
    shipping_address VARIANT,
    payment_method STRING,
    discount_amount NUMBER(10,2) DEFAULT 0,
    tax_amount NUMBER(10,2) DEFAULT 0,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Create or alter order items table
CREATE OR ALTER TABLE order_items (
    order_item_id STRING PRIMARY KEY,
    order_id STRING NOT NULL,
    product_id STRING NOT NULL,
    quantity NUMBER(10,0) NOT NULL,
    unit_price NUMBER(10,2) NOT NULL,
    total_price NUMBER(12,2) NOT NULL,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);