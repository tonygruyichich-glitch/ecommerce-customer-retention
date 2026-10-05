/*
===============================================================================
Script: 02_cohort_retention_matrix.sql
Project: E-Commerce Customer Retention & Operational Churn Analysis
Description:
    Computes customer acquisition cohorts (M0) and measures subsequent
    monthly retention rates across a multi-month lifecycle.
Author: Tony Gruyichich
Database: DuckDB
===============================================================================
*/

-- ----------------------------------------------------------------------------
-- Monthly Cohort Retention Matrix
-- Methodology:
--   1. customer_cohort: Identify first purchase date per unique customer (M0).
--   2. cohort_count: Measure monthly active customers grouped by month offset.
--   3. Final Query: Compute retention percentage normalized by initial cohort size.
-- Key Findings:
--   - Baseline M1 retention across steady-state cohorts (2017+) hovers around 0.2% - 0.5%.
--   - The platform operates primarily as an episodic, transactional marketplace.
-- ----------------------------------------------------------------------------
WITH customer_cohort AS (
    SELECT
        c.customer_unique_id,
        DATE_TRUNC('month', MIN(o.order_purchase_timestamp)) AS cohort_month
    FROM customers c
             JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

     cohort_count AS (
         SELECT
             cc.cohort_month,
             date_diff('month', cc.cohort_month, DATE_TRUNC('month', o.order_purchase_timestamp)) AS month_offset,
             COUNT(DISTINCT c.customer_unique_id) AS active_customers
         FROM orders o
                  JOIN customers c ON o.customer_id = c.customer_id
                  JOIN customer_cohort cc ON c.customer_unique_id = cc.customer_unique_id
         WHERE o.order_status = 'delivered'
         GROUP BY cc.cohort_month, month_offset
     )

SELECT
    cohort_month,
    month_offset,
    active_customers,
    FIRST_VALUE(active_customers) OVER(
        PARTITION BY cohort_month
        ORDER BY month_offset ASC
    ) AS cohort_size,
    ROUND(
            active_customers * 100.0 / FIRST_VALUE(active_customers) OVER(
            PARTITION BY cohort_month
            ORDER BY month_offset ASC
        ),
            2
    ) AS retention_rate
FROM cohort_count
ORDER BY cohort_month ASC, month_offset ASC;