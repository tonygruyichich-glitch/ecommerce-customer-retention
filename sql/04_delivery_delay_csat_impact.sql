/*
===============================================================================
Script: 04_delivery_delay_csat_impact.sql
Project: E-Commerce Customer Retention & Operational Churn Analysis
Description:
    Quantifies the relationship between delivery delays (SLA breaches) and
    customer satisfaction (CSAT), identifying the operational tipping point
    where severe churn risk occurs.
Author: Tony Gruyichich
Database: DuckDB
===============================================================================
*/

-- ----------------------------------------------------------------------------
-- Fulfillment Delay Tipping Point vs. Review Score (CSAT)
-- Methodology:
--   1. buckets: Compute net variance in days between delivered and estimated dates.
--      Categorize orders into operational delay intervals (On-Time, 1-3d, 4-7d, 8d+).
--   2. Final Aggregation: Join with order_reviews, measuring average CSAT,
--      one-star share, and five-star share across each delay tier.
-- Key Findings:
--   - On-time orders average 4.29 CSAT with only 6.63% 1-star reviews.
--   - Delays of 1-3 days cause a nearly 4x surge in 1-star reviews (25.16%).
--   - Severe delays (4+ days) trigger catastrophic CSAT collapse (>58% 1-star).
-- ----------------------------------------------------------------------------
WITH buckets AS (
    SELECT
        order_id,
        CASE
            WHEN date_diff('day', order_estimated_delivery_date, order_delivered_customer_date) <= 0 THEN 'On Time or Early'
            WHEN date_diff('day', order_estimated_delivery_date, order_delivered_customer_date) <= 3 THEN 'Days Late 1-3'
            WHEN date_diff('day', order_estimated_delivery_date, order_delivered_customer_date) <= 7 THEN 'Days Late 4-7'
            ELSE 'Late 8+'
            END AS delay_buckets
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date >= order_purchase_timestamp
      AND order_estimated_delivery_date IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
)

SELECT
    delay_buckets,
    COUNT(*) AS total_orders,
    ROUND(SUM(review_score) / COUNT(*), 2) AS avg_review_score,
    ROUND(SUM(CASE WHEN review_score = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS one_star_pct,
    ROUND(SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS five_star_pct
FROM reviews r
         JOIN buckets b ON r.order_id = b.order_id
GROUP BY delay_buckets
ORDER BY total_orders DESC;