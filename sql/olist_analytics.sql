-- Olist analytics queries

-- Schema

CREATE TABLE customers (
    customer_id VARCHAR PRIMARY KEY,
    customer_unique_id VARCHAR,
    customer_zip_code_prefix VARCHAR,
    customer_city VARCHAR,
    customer_state VARCHAR
);

CREATE TABLE orders (
    order_id VARCHAR PRIMARY KEY,
    customer_id VARCHAR REFERENCES customers(customer_id),
    order_status VARCHAR,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id VARCHAR,
    order_item_id INT,
    product_id VARCHAR,
    seller_id VARCHAR,
    shipping_limit_date TIMESTAMP,
    price NUMERIC,
    freight_value NUMERIC
);

CREATE TABLE order_payments (
    order_id VARCHAR,
    payment_sequential INT,
    payment_type VARCHAR,
    payment_installments INT,
    payment_value NUMERIC
);

CREATE TABLE order_reviews (
    review_id VARCHAR,
    order_id VARCHAR,
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

CREATE TABLE products (
    product_id VARCHAR PRIMARY KEY,
    product_category_name VARCHAR,
    product_name_length NUMERIC,
    product_description_length NUMERIC,
    product_photos_qty NUMERIC,
    product_weight_g NUMERIC,
    product_length_cm NUMERIC,
    product_height_cm NUMERIC,
    product_width_cm NUMERIC
);

CREATE TABLE sellers (
    seller_id VARCHAR PRIMARY KEY,
    seller_zip_code_prefix VARCHAR,
    seller_city VARCHAR,
    seller_state VARCHAR
);

CREATE TABLE category_translation (
    product_category_name VARCHAR,
    product_category_name_english VARCHAR
);

-- revenue by month, only counting delivered orders since cancelled/returned
-- ones would inflate the numbers

SELECT 
    DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
    SUM(p.payment_value) AS revenue,
    COUNT(DISTINCT o.order_id) AS total_orders
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY 1;

-- same as above but with mom growth, using LAG to pull the previous
-- month's revenue into the same row so i can calculate % change directly

WITH monthly AS (
    SELECT 
        DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
        SUM(p.payment_value) AS revenue
    FROM orders o
    JOIN order_payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
)
SELECT 
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(((revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month)) * 100, 2) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- which categories bring in the most money. category names in the raw
-- data are in portuguese so joining the translation table to get english names
SELECT 
    ct.product_category_name_english AS category,
    SUM(oi.price) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
JOIN category_translation ct ON p.product_category_name = ct.product_category_name
GROUP BY 1
ORDER BY total_revenue DESC
LIMIT 15;

-- rfm view, one row per customer with their last order date, how many
-- orders they've placed, and total spend. feeds into the repeat purchase
-- query below and gets reused in powerbi for the customer segments
CREATE VIEW vw_customer_rfm AS
SELECT 
    c.customer_unique_id,
    MAX(o.order_purchase_timestamp) AS last_order_date,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(p.payment_value) AS monetary
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id;

-- what % of customers actually come back and order again
SELECT 
    COUNT(*) FILTER (WHERE frequency > 1) AS repeat_customers,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) FILTER (WHERE frequency > 1)::NUMERIC / COUNT(*) * 100, 2) AS repeat_rate_pct
FROM vw_customer_rfm;

-- delivery days = gap between purchase and actual delivery to customer.
-- filtering out nulls since orders that never got delivered obviously
-- don't have a delivery date
CREATE VIEW vw_delivery_review AS
SELECT 
    o.order_id,
    EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) AS delivery_days,
    r.review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
AND o.order_delivered_customer_date IS NOT NULL;

-- bucketing delivery speed to see if slower delivery = worse reviews
SELECT 
    CASE 
        WHEN delivery_days <= 7 THEN 'Fast (<=7 days)'
        WHEN delivery_days <= 14 THEN 'Medium (8-14 days)'
        ELSE 'Slow (>14 days)'
    END AS delivery_bucket,
    ROUND(AVG(review_score), 2) AS avg_review_score,
    COUNT(*) AS order_count
FROM vw_delivery_review
GROUP BY 1
ORDER BY 2 DESC;

-- cohort retention. first CTE finds each customer's first order month
-- (their cohort), second CTE tags every order they place with that
-- cohort + how many months since. month_number = months since first
-- purchase, so 0 = the month they first bought
CREATE VIEW vw_cohort_retention AS
WITH first_purchase AS (
    SELECT 
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),
orders_with_cohort AS (
    SELECT 
        c.customer_unique_id,
        fp.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS order_month
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN first_purchase fp ON c.customer_unique_id = fp.customer_unique_id
    WHERE o.order_status = 'delivered'
)
SELECT 
    cohort_month,
    order_month,
    EXTRACT(YEAR FROM AGE(order_month, cohort_month)) * 12 + EXTRACT(MONTH FROM AGE(order_month, cohort_month)) AS month_number,
    COUNT(DISTINCT customer_unique_id) AS customers
FROM orders_with_cohort
GROUP BY 1, 2, 3;

SELECT * FROM vw_cohort_retention ORDER BY cohort_month, month_number;

-- sanity check after importing csvs, comparing these against the actual row counts on kaggle to make
-- sure nothing got dropped during import
SELECT 'customers' AS tbl, COUNT(*) FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation;
