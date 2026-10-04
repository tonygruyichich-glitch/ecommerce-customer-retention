/*
===============================================================================
Script: 01_data_hygiene_and_sanity_checks.sql
Project: E-Commerce Customer Retention & Operational Churn Analysis
Description:
    Validates data integrity, entity granularity, and timestamp consistency
    across raw Olist dataset tables prior to downstream retention modeling.
Author: Tony Gruyichich
Database: DuckDB / Google BigQuery
===============================================================================
*/

-- ----------------------------------------------------------------------------
-- 1. Entity Granularity Check: Order Tokens vs. Unique Customers
-- Objective:
--   Verify whether customer_id represents discrete orders or unique human entities.
-- Key Finding:
--   Total orders (99,441) exceed unique customers (96,096) by 3,345 records.
-- Decision Rule:
--   Must join and aggregate on `customer_unique_id` for retention modeling,
--   as `customer_id` is an order-level surrogate key.
-- ----------------------------------------------------------------------------
SELECT
    COUNT(customer_id) AS total_purchases,
    COUNT(DISTINCT customer_unique_id) AS total_unique_customers,
    COUNT(customer_id) - COUNT(DISTINCT customer_unique_id) AS difference
FROM customers;


-- ----------------------------------------------------------------------------
-- 2. Order Status Breakdown & Revenue Viability
-- Objective:
--   Identify non-viable order states (canceled, unavailable) that distort
--   retention cohorts and monetary transactions.
-- Decision Rule:
--   Downstream cohort and RFM analyses will restrict records to:
--   WHERE order_status = 'delivered'
-- ----------------------------------------------------------------------------
SELECT
    order_status AS status,
    COUNT(*) AS total_orders,
    ROUND(
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2
    ) AS percentage
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- ----------------------------------------------------------------------------
-- 3. Chronological Consistency Check (Timestamp Sanity Audit)
-- Objective:
--   Detect corrupted timestamps where carrier dispatch or customer delivery
--   precedes the purchase timestamp.
-- Key Finding:
--   165 records (0.17% of delivered orders) contain inverted timestamps.
-- Decision Rule:
--   Exclude these records from logistics duration models:
--   WHERE order_delivered_customer_date >= order_purchase_timestamp
-- ----------------------------------------------------------------------------
SELECT
    COUNT(*) AS corrupted_delivery_timestamps
FROM orders
WHERE order_status = 'delivered'
  AND (
    order_delivered_customer_date < order_purchase_timestamp
        OR order_delivered_carrier_date < order_purchase_timestamp
    );