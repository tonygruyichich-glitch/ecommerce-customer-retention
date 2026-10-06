/*
===============================================================================
Script: 03_rfm_segmentation.sql
Project: E-Commerce Customer Retention & Operational Churn Analysis
Description:
    Computes customer Recency, Frequency, and Monetary (RFM) metrics, applies
    quantile and deterministic scoring, and segments the customer base to
    evaluate revenue concentration (Pareto principle).
Author: Tony Gruyichich
Database: DuckDB
===============================================================================
*/

-- ----------------------------------------------------------------------------
-- Customer RFM Segmentation & GMV Concentration
-- Methodology:
--   1. raw_rfm: Calculate baseline days since last purchase, order counts, and spend.
--   2. rfm_scores: Assign 1-5 scores using NTILE(5) for continuous metrics and
--      deterministic CASE WHEN for tied frequency values.
--   3. customer_segments: Classify users into operational lifecycle buckets.
--   4. Final Aggregation: Measure customer distribution and cumulative GMV share.
-- ----------------------------------------------------------------------------
WITH raw_rfm AS (
    SELECT
        c.customer_unique_id,
        date_diff(
                'day',
                MAX(o.order_purchase_timestamp),
                (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered')
        ) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        ROUND(SUM(p.payment_value), 2) AS monetary
    FROM customers c
             JOIN orders o ON c.customer_id = o.customer_id
             JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

     rfm_scores AS (
         SELECT
             customer_unique_id,
             recency_days,
             frequency,
             monetary,
             NTILE(5) OVER(ORDER BY recency_days DESC) AS r_score,
             CASE
                 WHEN frequency = 1 THEN 1
                 WHEN frequency = 2 THEN 3
                 ELSE 5
                 END AS f_score,
             NTILE(5) OVER(ORDER BY monetary ASC) AS m_score
         FROM raw_rfm
     ),

     customer_segments AS (
         SELECT
             customer_unique_id,
             recency_days,
             frequency,
             monetary,
             r_score,
             f_score,
             m_score,
             CASE
                 WHEN r_score >= 4 AND (f_score >= 3 OR m_score >= 4) THEN 'Champions'
                 WHEN f_score >= 3 AND r_score >= 3 THEN 'Loyal Customers'
                 WHEN f_score >= 3 AND r_score <= 2 THEN 'At Risk'
                 WHEN r_score >= 4 AND f_score = 1 THEN 'Promising / Recent'
                 ELSE 'Hibernating / Lost'
                 END AS segment
         FROM rfm_scores
     )

SELECT
    segment,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS customer_share_pct,
    ROUND(SUM(monetary), 2) AS total_gmv,
    ROUND(SUM(monetary) * 100.0 / SUM(SUM(monetary)) OVER (), 2) AS gmv_share_pct
FROM customer_segments
GROUP BY segment
ORDER BY total_gmv DESC;