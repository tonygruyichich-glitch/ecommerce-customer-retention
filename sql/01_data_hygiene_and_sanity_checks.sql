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