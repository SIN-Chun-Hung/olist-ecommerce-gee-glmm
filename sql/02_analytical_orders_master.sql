CREATE OR REPLACE VIEW analytical_orders_master AS
WITH aggregated_items AS (
    SELECT 
        oi.order_id,
        COUNT(oi.order_item_id) AS total_items,
        COUNT(DISTINCT oi.seller_id) AS distinct_sellers_count,
        MAX(oi.seller_id) AS primary_seller_id, 
        SUM(oi.price) AS total_order_price,
        SUM(oi.freight_value) AS total_freight_value,
        MAX(p.product_category_name_english) AS primary_category_en
    FROM raw_order_items oi
    LEFT JOIN raw_products pr ON oi.product_id = pr.product_id
    LEFT JOIN raw_category_translation p ON pr.product_category_name = p.product_category_name
    GROUP BY oi.order_id
),
aggregated_reviews AS (
    SELECT 
        order_id,
        MIN(review_score) AS min_review_score,
        AVG(review_score) AS avg_review_score,
        COUNT(review_id) AS total_reviews
    FROM raw_order_reviews
    GROUP BY order_id
),
aggregated_payments AS (
    SELECT
        order_id,
        MAX(payment_installments) AS max_installments,
        COUNT(payment_sequential) AS payment_splits_count
    FROM raw_order_payments
    GROUP BY order_id
)
SELECT 
    o.order_id,
    c.customer_unique_id,
    c.customer_state,
    s.seller_state,
    (c.customer_state != s.seller_state)::INT AS is_cross_state,
    o.order_purchase_timestamp,
    o.order_status,
    
    
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400.0 AS actual_delivery_days,
    EXTRACT(EPOCH FROM (o.order_estimated_delivery_date - o.order_purchase_timestamp)) / 86400.0 AS estimated_delivery_days,
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date)) / 86400.0 AS delivery_delay_days,
    
    
    ai.total_items,
    ai.distinct_sellers_count,
    ai.primary_seller_id,
    ai.total_order_price,
    ai.total_freight_value,
    CASE 
        WHEN (ai.total_order_price + ai.total_freight_value) > 0 
        THEN ai.total_freight_value / (ai.total_order_price + ai.total_freight_value)
        ELSE 0 
    END AS freight_ratio,
    COALESCE(ai.primary_category_en, 'others') AS product_category,
    
    
    COALESCE(ap.max_installments, 1) AS max_installments,
    
    
    ar.min_review_score,
    CASE WHEN ar.min_review_score <= 2 THEN 1 ELSE 0 END AS is_complaint_review

FROM raw_orders o
JOIN raw_customers c ON o.customer_id = c.customer_id
JOIN aggregated_items ai ON o.order_id = ai.order_id
LEFT JOIN raw_sellers s ON ai.primary_seller_id = s.seller_id
LEFT JOIN aggregated_reviews ar ON o.order_id = ar.order_id
LEFT JOIN aggregated_payments ap ON o.order_id = ap.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL;