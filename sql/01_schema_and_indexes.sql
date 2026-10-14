-- Create Database
--CREATE DATABASE olist_db;
--SELECT oid, datname FROM pg_database WHERE datname = 'olist_db';

-- 1. Customers
DROP TABLE IF EXISTS raw_customers CASCADE;
CREATE TABLE raw_customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state VARCHAR(5)
);

-- 2. Orders
DROP TABLE IF EXISTS raw_orders CASCADE;
CREATE TABLE raw_orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20),
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

-- 3. Order Items
DROP TABLE IF EXISTS raw_order_items CASCADE;
CREATE TABLE raw_order_items (
    order_id VARCHAR(32),
    order_item_id INT,
    product_id VARCHAR(32),
    seller_id VARCHAR(32),
    shipping_limit_date TIMESTAMP,
    price NUMERIC(10, 2),
    freight_value NUMERIC(10, 2),
    PRIMARY KEY (order_id, order_item_id)
);

-- 4. Order Payments
DROP TABLE IF EXISTS raw_order_payments CASCADE;
CREATE TABLE raw_order_payments (
    order_id VARCHAR(32),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value NUMERIC(10, 2)
);

-- 5. Order Reviews
DROP TABLE IF EXISTS raw_order_reviews CASCADE;
CREATE TABLE raw_order_reviews (
    review_id VARCHAR(32),
    order_id VARCHAR(32),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- 6. Products
DROP TABLE IF EXISTS raw_products CASCADE;
CREATE TABLE raw_products (
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g NUMERIC(10, 2),
    product_length_cm NUMERIC(10, 2),
    product_height_cm NUMERIC(10, 2),
    product_width_cm NUMERIC(10, 2)
);

-- 7. Sellers
DROP TABLE IF EXISTS raw_sellers CASCADE;
CREATE TABLE raw_sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(5)
);

-- 8. Category Translation
DROP TABLE IF EXISTS raw_category_translation CASCADE;
CREATE TABLE raw_category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
);

SELECT tablename 
FROM pg_catalog.pg_tables 
WHERE schemaname = 'public';

-- Load CSV Data  
--\copy raw_customers FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true);
--\copy raw_orders FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true);
--\copy raw_order_items FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true);
--\copy raw_order_payments FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true);
--\copy raw_order_reviews FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ',');
--\copy raw_products FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_products_dataset.csv' WITH (FORMAT csv, HEADER true);
--\copy raw_sellers FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, ENCODING 'UTF8', DELIMITER ',');
--\copy raw_category_translation FROM 'C:\Users\username\OneDrive\Desktop\Brazilian E-Commerce Dataset\product_category_name_translation.csv' WITH (FORMAT csv, HEADER true);

-- Build Index to speed up join
CREATE INDEX idx_orders_cust ON raw_orders(customer_id);
CREATE INDEX idx_orders_timestamp ON raw_orders(order_purchase_timestamp);
CREATE INDEX idx_cust_unique ON raw_customers(customer_unique_id);
CREATE INDEX idx_items_order ON raw_order_items(order_id);
CREATE INDEX idx_items_seller ON raw_order_items(seller_id);
CREATE INDEX idx_reviews_order ON raw_order_reviews(order_id);