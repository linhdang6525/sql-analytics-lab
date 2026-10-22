-- 1 — Clean up one query (20 min)
-- Take the worst-formatted query you wrote in Q02–Q06. Reformat it to the style
-- guide, add a definition block, and put the before and after side by side in
-- answers/q09.sql. Write one line on what a reader gains.

-- TASK 1: BEFORE
-- Original query, preserved for comparison.

WITH info AS (
    SELECT 
        dd.year             AS year,
        dd.month            AS month,
        SUM(fo.order_total) AS total_revenue
    FROM dim_date dd
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.year, dd.month
),
lag_rev_month AS (
    SELECT 
        year, 
        month, 
        total_revenue                                     AS current_rev,
        LAG(total_revenue, 12) OVER (ORDER BY year, month) AS previous_year_rev 
    FROM info
)
SELECT 
    year,
    month,
    current_rev,
    previous_year_rev,
    (current_rev - previous_year_rev) AS diff,
    ROUND(
        (current_rev - previous_year_rev) / previous_year_rev * 100,
        2
    ) AS pct_diff
FROM lag_rev_month
WHERE year = 2026
ORDER BY month;


-- TASK 1: AFTER
/*
   Question: Compare monthly completed revenue in 2026 with the same
             months in the previous year.
   Grain:     One row per year and month before filtering; one row per
              month in 2026 in the final result.
   Measure:   Sum of order_total for completed orders.
   Period:    Uses all years available in dim_date to calculate LAG;
              displays only months in 2026.
   Caveat:    LAG(..., 12) assumes each year-month has one row and
              consecutive months are present. A missing month can
              make the comparison misalign.
*/

WITH monthly_revenue AS (
    SELECT
        dd.year AS year,
        dd.month AS month,
        SUM(fo.order_total) AS total_revenue
    FROM dim_date dd
    INNER JOIN fct_order fo
        ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed'
    GROUP BY
        dd.year,
        dd.month
),
revenue_with_previous_year AS (
    SELECT
        year,
        month,
        total_revenue AS current_revenue,
        LAG(total_revenue, 12) OVER (
            ORDER BY year, month
        ) AS previous_year_revenue
    FROM monthly_revenue
)
SELECT
    year,
    month,
    current_revenue,
    previous_year_revenue,
    current_revenue - previous_year_revenue AS revenue_difference,
    ROUND(
        (current_revenue - previous_year_revenue)
        / NULLIF(previous_year_revenue, 0) * 100,
        2
    ) AS percentage_change
FROM revenue_with_previous_year
WHERE year = 2026
ORDER BY
    year,
    month;

-- TASK 2:
-- v_completed_orders — completed orders joined to dim_date, with the status filter and a comment saying why.
-- v_completed_orer: lọc những đơn hàng có trạng thái hoàn thành và gán thêm cột ngày, năm,...
CREATE OR REPLACE VIEW v_completed_orders AS
SELECT
    fo.*,
    dd.full_date,
    dd.year,
    dd.month,
    dd.fiscal_year
FROM fct_order fo
JOIN dim_date dd USING (date_key)
WHERE fo.status = 'completed';

-- v_order_lines — line grain, joined to product and date, with category and subcategory.
order_id,line_no,product_sk,quantity,unit_price,line_amount,is_returned
CREATE OR REPLACE VIEW v_order_lines AS
SELECT 
    oi.*,
    dp.category,
    dp.subcategory,
    dp.product_name,
    dd.full_date,
    dd.year,
    dd.month
FROM fct_order_item oi
JOIN dim_product dp USING (product_sk)
JOIN fct_order fo USING (order_id)
JOIN dim_date dd USING (date_key);

SELECT
    COUNT(*) 
FROM v_order_lines;
    
-- v_customer_current — one row per customer, current version only. Getting this right means 
-- nobody downstream can hit the SCD2 trap.
CREATE OR REPLACE VIEW v_customer_current AS
SELECT *
FROM dim_customer
WHERE is_current = 'Y';

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customers
FROM v_customer_current;

-- Q08
-- 2. Marc (CFO): "What was our revenue last year? I need one number for the board."
-- "Last year" is not one thing here. Give the number he needs, name the period explicitly, 
-- BEFORE:
SELECT 
    dd.year,
    SUM(fo.order_total) AS 'last year revenue'
FROM dim_date dd 
INNER JOIN fct_order fo ON dd.date_key = fo.date_key
WHERE fo.status = 'completed' AND dd.year = '2025'
GROUP BY dd.year;

-- AFTER:
SELECT 
    year,
    SUM(order_total) AS rev
FROM v_completed_orders
WHERE year = 2025
GROUP BY year;

-- 1. Dana (COO): "Simple question — is the business growing?"
-- Careful. There are three defensible comparisons in this data and one of them is badly misleading. 
-- Give her the right one, and say why you didn't give her the other.
-- BEFORE:
WITH rev_25 AS (
    SELECT
        dd.year,
        SUM(fo.order_total) AS 'H1_2025'
    FROM dim_date dd 
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed'
    AND dd.date_key >= 20250101 AND dd.date_key <= 20250630 
    GROUP BY dd.year
),
rev_26 AS (
    SELECT
        dd.year,
        SUM(fo.order_total) AS 'H1_2026'
    FROM dim_date dd 
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed'
    AND dd.date_key >= 20260101 AND dd.date_key <= 20260630 
    GROUP BY dd.year
)
SELECT 
    (SELECT H1_2025 FROM rev_25) AS 'H1_2025',
    (SELECT H1_2026 FROM rev_26) AS 'H1_2026',
    ROUND(((SELECT H1_2026 FROM rev_26) - (SELECT H1_2025 FROM rev_25)) 
    / (SELECT H1_2025 FROM rev_25) * 100, 2) AS pct_growth;

-- AFTER:
WITH rev_25 AS (
    SELECT
        year,
        SUM(order_total) AS 'H1_2025'
    FROM v_completed_orders
    WHERE date_key >= 20250101 AND date_key <= 20250630 
    GROUP BY year
),
rev_26 AS (
    SELECT
        year,
        SUM(order_total) AS 'H1_2026'
    FROM v_completed_orders
    WHERE date_key >= 20260101 AND date_key <= 20260630 
    GROUP BY year
)
SELECT 
    (SELECT H1_2025 FROM rev_25) AS 'H1_2025',
    (SELECT H1_2026 FROM rev_26) AS 'H1_2026',
    ROUND(((SELECT H1_2026 FROM rev_26) - (SELECT H1_2025 FROM rev_25)) 
    / (SELECT H1_2025 FROM rev_25) * 100, 2) AS pct_growth;
