-- 1. Dana (COO): "Simple question — is the business growing?"
-- Careful. There are three defensible comparisons in this data and one of them is badly misleading. 
-- Give her the right one, and say why you didn't give her the other.

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

--  H1_2025: 4476125.75   │    H1_2026: 4464733.48    │ pct_growth: -0.25 
-- The business was essentially flat in H1 2026, with completed revenue declining 
-- slightly by 0.25% compared with H1 2025.
-- This comparison covers equal six-month periods, making it more meaningful than comparing 
-- calendar-year 2025 revenue with only the first six months of 2026. That unequal-period comparison 
-- would make revenue appear to have fallen sharply simply because 2026 covers fewer months. 
-- The result describes revenue, not profitability or overall business performance.

-- 2. Marc (CFO): "What was our revenue last year? I need one number for the board."
-- "Last year" is not one thing here. Give the number he needs, name the period explicitly, 
-- and flag the one comparison he must not make with it.
-- tính doanh thu năm ngoái, tính order_total từ 20250101 đến 20251231
SELECT 
    dd.year,
    SUM(fo.order_total) AS 'last year revenue'
FROM dim_date dd 
INNER JOIN fct_order fo ON dd.date_key = fo.date_key
WHERE fo.status = 'completed' AND dd.year = '2025'
GROUP BY dd.year;
-- the last year revenue is 9736875.65, that computed by year calender 2025 with 365 days.
-- otherwise, the fiscal year 2025 only covers 181 days not reflect the whole year.

-- 3. Ingrid (Head of Retail): "Which store is our worst performer? I'm making a decision about 
-- it next week."
-- The obvious query gives an answer that is arguably unfair to one store. Find out why, and give 
-- her both figures with a recommendation.
-- tính doanh thu cho từng store, số ngày hoạt động, doanh thu trên ngày hoạt động, sau đó mới biết store nào tệ
-- ngày mở cửa đầu tiên với ngày mở cửa cuối cùng. 
WITH revenue_store AS (
    SELECT 
        ds.store_code    AS store_code,
        ds.store_name    AS store_name,
        SUM(order_total) AS store_rev
    FROM dim_store ds
    INNER JOIN fct_order fo ON ds.store_sk = fo.store_sk
    WHERE fo.status = 'completed'
    GROUP BY store_code, store_name
),
gap_active_day AS (
    SELECT 
        store_code,
        store_name,
        opened_date,
        COALESCE(closed_date, '2026-06-30') AS close_date,
        (close_date - opened_date) AS gap_day
    FROM dim_store
)
SELECT 
    rs.store_code,
    rs.store_name,
    rs.store_rev,
    gap.opened_date,
    gap.close_date,
    gap.gap_day,
    ROUND((rs.store_rev / gap.gap_day), 2) AS rev_per_active_day
FROM revenue_store rs
JOIN gap_active_day gap ON rs.store_code = gap.store_code
ORDER BY rev_per_active_day ASC; 
-- ST13 has the lowest revenue per active day (347.26).
-- However, one store closed on 2026-02-28, so compare revenue per active day
-- over the same analysis period before recommending a closure.

-- 4. Femi (Marketing): "Which promo code drove the most revenue? We're deciding what to run again."
-- You met this in Q07. Give him a number he can act on, and one sentence on what "drove" can and cannot 
-- mean from this data.
-- mã giảm giá nào thức đẩy doanh thu nhiều nhất, quyết định lại cái promo đó
SELECT 
    dpr.promo_code,
    ROUND(SUM(fo.order_total * bop.allocation_factor), 2) AS rev_by_promo_code
FROM dim_promo dpr 
INNER JOIN bridge_order_promo bop ON dpr.promo_code = bop.promo_code
INNER JOIN fct_order fo ON bop.order_id = fo.order_id 
WHERE fo.status = 'completed'
GROUP BY dpr.promo_code
ORDER BY rev_by_promo_code DESC;
-- the BUNDLE15 code has the highest revenue, 


-- 5. Sara (Merchandising): "Which category makes us the most money?"
-- There are two honest answers and they're different categories. Give both and explain the distinction
-- in a sentence a merchandiser would use.
-- loại sản phẩm nào cho chúng nhiều tiền nhất 
-- revenue:
SELECT 
    dp.category,
    SUM(oi.line_amount) AS rev_category
FROM dim_product dp 
INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
INNER JOIN fct_order fo ON oi.order_id = fo.order_id
WHERE fo.status = 'completed'
GROUP BY dp.category
ORDER BY rev_category DESC;

-- margin revenue = rev - cost / rev * 100
SELECT 
    dp.category,
    SUM(oi.line_amount)             AS rev_category,
    SUM(oi.quantity * dp.unit_cost) AS cost_category,
    ROUND((rev_category - cost_category) / rev_category * 100, 2) AS margin_revenue
FROM dim_product dp 
INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
INNER JOIN fct_order fo ON oi.order_id = fo.order_id
WHERE fo.status = 'completed'
GROUP BY dp.category
ORDER BY rev_category DESC;
-- Computing has the highest total revenue at 4,016,974.03,
-- while Outdoor has the highest profit margin at 44.27%.
-- Computing drives sales volume, while Outdoor retains a higher
-- percentage of revenue as profit.


-- 6. Tomas (Customer Service): "How bad is our returns problem? Is it getting worse?"
-- Two questions in one. Answer both, and be careful with the second — Q04's lesson applies.
-- tính lượt hàng trả về theo quý?
WITH 
count_returned AS (
    SELECT 
        dd.year,
        dd.quarter,
        COUNT(*) AS count_returned_order
    FROM dim_date dd 
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'returned'
    GROUP BY dd.year, dd.quarter
),
count_overall_quarter AS (
    SELECT 
        dd.year,
        dd.quarter,
        COUNT(*) AS count_category
    FROM dim_date dd
    JOIN fct_order fo ON dd.date_key = fo.date_key
    GROUP BY dd.year, dd.quarter
)
SELECT 
    cr.year,
    cr.quarter,
    coq.count_category,
    cr.count_returned_order,
    ROUND((cr.count_returned_order / coq.count_category) * 100, 2) AS pct_returned
FROM count_returned cr
JOIN count_overall_quarter coq ON cr.year = coq.year AND cr.quarter = coq.quarter;
-- The return rate fluctuated between 4.77% and 5.34% across the observed quarters.
-- It decreased in Q4 2025, rose in Q1 2026, then fell to 4.77% in Q2 2026.
-- Therefore, the return rate does not show a consistent worsening trend.

-- 7. Sven (Sales): "Can you give me a list of customers who've stopped buying from us? 
-- I want to call them."
-- Run it. Then read the result and decide what you actually tell Sven. 
-- There is a real answer here and it is not the list he asked for.
WITH 
completed_25 AS (
    SELECT DISTINCT dc.customer_sk
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed' AND dd.year = '2025'
),
completed_26 AS (
    SELECT DISTINCT dc.customer_sk
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed' AND dd.year = '2026'
)
SELECT c25.customer_sk
FROM completed_25 c25 
LEFT JOIN completed_26 c26 ON c25.customer_sk = c26.customer_sk
WHERE c26.customer_sk IS NULL
ORDER BY c25.customer_sk;
-- Chỉ cần có ít nhất 1 đơn hàng completed trong năm 2025 là khách được đưa vào danh sách completed_25.
-- Identify customers who had at least one completed order in 2025
-- but no completed orders in 2026.
-- DISTINCT ensures each customer_sk appears only once,
-- regardless of how many completed orders they had.
-- LEFT JOIN keeps all customers from 2025, while unmatched
-- customers in 2026 are identified by NULL.
-- Note: This identifies potential inactive customers, not confirmed churn.

-- 8. Nadia (Finance): "How much did we give away in discounts last year?"
-- The obvious query understates it, and you know exactly why from Q07. Give her a number, 
-- the adjustment, and the sentence about data quality that she needs to hear before she uses it.
WITH 
discounted_order AS (
    SELECT
        dd.year,
        SUM(fo.discount_amount) AS recorded_discount_amount, -- tổng tiền discount without NULL
        COUNT(fo.discount_amount) AS orders_with_recorded_discount -- đếm số dòng discount without NULL
    FROM dim_date dd
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE dd.year = '2025'
    AND fo.status = 'completed'
    GROUP BY dd.year
),
missing_discounted AS (
    SELECT
        SUM(fo.gross_amount - fo.order_total + fo.shipping_fee) AS estimated_missing_discount_amount, -- tổng tiền của các NULL
        COUNT(*) AS orders_with_null_discount -- đếm số NULL (do có filter IS NULL)
    FROM fct_order fo
    INNER JOIN dim_date dd
        ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
      AND dd.year = '2025'
      AND fo.discount_amount IS NULL
),
total_discount AS (
    SELECT
        COUNT(*) AS total_completed_orders -- đếm tất cả các discount có bao gồm NULL
    FROM fct_order fo
    INNER JOIN dim_date dd
        ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
      AND dd.year = '2025'
)

SELECT
    d.recorded_discount_amount,
    d.orders_with_recorded_discount,
    m.orders_with_null_discount,
    m.estimated_missing_discount_amount,
    t.total_completed_orders,
    d.recorded_discount_amount + m.estimated_missing_discount_amount 
        AS estimated_total_discount_amount -- tính tổng with & without NULL
FROM discounted_order d
CROSS JOIN missing_discounted m
CROSS JOIN total_discount t; 
-- Recorded discounts total 491,678.94 across completed orders in 2025.
-- An estimated 22,312.40 in discounts may be missing across 1,275 orders
-- where discount_amount is NULL, based on the inferred order-total formula.
-- Estimated total discounts: 513,991.34.
-- Data quality warning: Missing discount values may cause recorded totals
-- to understate actual discounts. The estimated adjustment has not been verified.