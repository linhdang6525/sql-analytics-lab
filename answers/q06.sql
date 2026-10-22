-- 1.List completed orders with a ROW_NUMBER() per customer, ordered by order date. Show 
-- one customer's rows and check the numbering restarts.
-- ASC: đơn cũ nhất là số 1.
-- DESC: đơn mới nhất là số 1.
SELECT 
    dc.customer_id,
    dc.customer_name,
    fo.ordered_at,
    ROW_NUMBER() OVER(
        PARTITION BY dc.customer_id 
        ORDER BY fo.ordered_at ASC) AS rn
FROM fct_order fo 
INNER JOIN dim_customer dc 
    ON fo.customer_sk = dc.customer_sk
WHERE fo.status = 'completed'
ORDER BY dc.customer_id ASC, fo.ordered_at ASC;

-- 2. Deduplicate raw_customer_list to one row per customer_id. How many rows should you end up with, 
-- and how many did you drop?
-- lọc những dòng trùng và chỉ giữ 1 dòng cho mỗi customer_id
-- bao nhiêu dòng giữ lại, bao nhiêu dòng drop
SELECT COUNT(*) FROM raw_customer_list; -- 1269
SELECT COUNT(DISTINCT customer_id) AS count_customer FROM dim_customer; -- 1200

WITH 
numbered AS (
    SELECT *,
           ROW_NUMBER() OVER (
                PARTITION BY customer_id 
                ORDER BY CASE WHEN customer_name = UPPER(customer_name) THEN 1 ELSE 0 END
                ) AS rn
-- Điều cần để ý: điểm 0/1 của CASE không xuất hiện thành cột nào. Nó chỉ được dùng 
-- ngầm bên trong OVER (...) để quyết định thứ tự, rồi bỏ đi. Cột duy nhất được thêm vào là rn.
    FROM raw_customer_list
),
dedup AS (
    SELECT customer_name FROM numbered WHERE rn = 1
)
SELECT
    (SELECT COUNT(*) FROM dedup) AS row_kept, 
    (SELECT COUNT(*) FROM raw_customer_list) - (SELECT COUNT(*) FROM dedup) AS row_dropped;

-- 3.The top 3 products by completed revenue within each category — category, sku, revenue, rank. 
-- Compare the effort with your Q05 stretch attempt.
-- top 3 sản phẩm bởi doanh thu của các đơn hoàn thành trong mỗi phân loại, và bảng kết quả cuối cùng 
-- bao gồm category, sku, revenue, rank.
-- status, line_amount, category, product_name
-- tính doanh thu và gán lại cho đúng sản phẩm đó
WITH 
revenue AS (
    SELECT -- revenue
        dp.category         AS category,
        dp.product_name     AS product_name,
        dp.sku              AS sku,
        SUM(oi.line_amount) AS product_revenue
    FROM dim_product dp
    INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk 
    INNER JOIN fct_order fo ON oi.order_id = fo.order_id
    WHERE fo.status = 'completed'
    GROUP BY dp.category, dp.product_name, dp.sku
),
ranked AS (
    SELECT 
        category, 
        product_name, 
        sku,
        product_revenue,
        RANK() OVER ( PARTITION BY category ORDER BY product_revenue DESC) AS rnk
    FROM revenue
)
SELECT category, sku, product_name, product_revenue, rnk FROM ranked WHERE rnk <= 3;
-- It's quickly than Q05

-- 4.Rank customers by total completed revenue. Show the top 10 with their rank. Then swap RANK() for 
-- DENSE_RANK() and ROW_NUMBER() — do the results differ here, and would they if two customers tied?
-- xếp hạng khách hàng theo tổng doanh thu đơn hàng hoàn thành của họ, show top10
-- tính doanh thu của mỗi khách hàng và gán lại đúng vào tên của họ ở bảng dim_customer
-- order_total, customer_id, status

-- RANK()
WITH info AS (
    SELECT 
        dc.customer_id          AS ID,
        dc.customer_name        AS customer_name,
        SUM(fo.order_total)     AS total_revenue
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    WHERE fo.status = 'completed'
    GROUP BY ID, customer_name
),
ranked AS (
    SELECT ID, customer_name, total_revenue,
    RANK() OVER (ORDER BY total_revenue DESC) AS rnk
    FROM info
)
SELECT ID, customer_name, total_revenue, rnk FROM ranked WHERE rnk <= 10 ORDER BY rnk;

-- DENSE_RANK()
WITH info AS (
    SELECT 
        dc.customer_id          AS ID,
        dc.customer_name        AS customer_name,
        SUM(fo.order_total)     AS total_revenue
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    WHERE fo.status = 'completed'
    GROUP BY ID, customer_name
),
ranked AS (
    SELECT ID, customer_name, total_revenue,
    DENSE_RANK() OVER (ORDER BY total_revenue DESC) AS rnk
    FROM info
)
SELECT ID, customer_name, total_revenue, rnk FROM ranked WHERE rnk <= 10 ORDER BY rnk;

-- ROW_NUMBER()
WITH info AS (
    SELECT 
        dc.customer_id          AS ID,
        dc.customer_name        AS customer_name,
        SUM(fo.order_total)     AS total_revenue
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    WHERE fo.status = 'completed'
    GROUP BY ID, customer_name
),
ranked AS (
    SELECT ID, customer_name, total_revenue,
    ROW_NUMBER() OVER (ORDER BY total_revenue DESC, ID ASC) AS rn
    FROM info
)
SELECT ID, customer_name, total_revenue, rn FROM ranked WHERE rn <= 10 ORDER BY rn;

-- 5.Monthly completed revenue for the whole window, with the previous month's revenue alongside it (LAG),
-- the change in currency, and the change as a percentage.
-- tính doanh thu tháng các đơn hàng hoàn thành cho toàn bộ window (year, month), add thêm doanh thu của tháng trước nó (dùng LAG),
-- thêm diff và pct của pct_diff
-- fct_order và dim_date
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
        LAG(total_revenue, 1) OVER (ORDER BY year, month) AS previous_rev 
    FROM info
)
SELECT 
    year,
    month,
    current_rev,
    previous_rev,
    (current_rev -  previous_rev) AS diff,
    ROUND((current_rev -  previous_rev) / previous_rev * 100, 2) AS pct_diff
FROM lag_rev_month;
    

-- 6.The same, but year-on-year: each month of 2026 against the same month of 2025. 
-- (Hint: LAG(revenue, 12) over a chronological ordering.)
-- doanh thu theo tháng nhưng lag là 12 ví dụ như tháng 1 2025 với tháng 1 2026
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
    (current_rev -  previous_year_rev) AS diff,
    ROUND((current_rev -  previous_year_rev) / previous_year_rev * 100,2) AS pct_diff
FROM lag_rev_month
WHERE year = 2026
ORDER BY month;


-- 7.Running total of completed revenue through 2026, by month. What's the figure at the end of June?
WITH info AS (
    SELECT 
        dd.month            AS month,
        dd. year            AS year,
        SUM(fo.order_total) AS monthly_revenue
    FROM dim_date dd
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed' AND dd.year = 2026
    GROUP BY dd.month, dd.year

)
SELECT month, year, monthly_revenue,
    SUM(monthly_revenue) OVER (ORDER BY month) AS running_total_2026
FROM info;
-- At the end of June the running total is 4 464 733.48

-- 8.Three-month moving average of monthly completed revenue. Which months does it smooth most?
WITH info AS (
    SELECT 
        dd.month            AS month,
        dd. year            AS year,
        SUM(fo.order_total) AS monthly_revenue
    FROM dim_date dd
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.year, dd.month

)
SELECT month, year, monthly_revenue,
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY year, month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS MA,
    ROUND(monthly_revenue - AVG(monthly_revenue) OVER (
        ORDER BY year, month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS gap_vs_ma
FROM info;
-- MA is computed over (year, month) order, 2 PRECEDING + current = 3 months.
-- First two months use fewer than 3 months. Smoothed most: Dec 2025 (peak), Jan and Feb 2026?

-- 9.Split customers into deciles by total completed revenue (NTILE(10)). What share of revenue does the
--  top decile account for?
WITH info AS (
    SELECT
        dc.customer_id      AS ID,
        dc.customer_name    AS customer_name,
        SUM(fo.order_total) AS total_rev_per_customer, -- total_rev per customer 
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    WHERE fo.status = 'completed'
    GROUP BY dc.customer_id, dc.customer_name
),
decile AS (
    SELECT ID, customer_name, total_rev_per_customer, 
        NTILE(10) OVER (ORDER BY total_rev_per_customer DESC) AS revenue_decile
    FROM info
)
SELECT
    SUM (CASE WHEN revenue_decile = 1 THEN total_rev_per_customer ELSE 0 END) AS top_decile_rev,
    SUM(total_rev_per_customer) AS total_revenue_whole_window,
    ROUND(top_decile_rev / total_revenue_whole_window * 100, 2) AS top_decile_rev_pct
FROM decile;
-- By customer_id (1,160 people): top decile = 14.49% of completed revenue.
-- By customer_sk (1,258 versions, the answer key's way): 15.46%.
-- The difference is the 98 customers who changed segment being counted twice.

-- 10. For each order, show the customer's previous order date and the days between them. Then: the average 
-- gap between orders per segment.
-- show ngày đặt đơn mới nhất và một cột ngày của đơn trước đó LAG() và khoảng cách ngày họ quay lại đặt đơn?
-- tính trung bình khoảng cách ngày cho mỗi phân khúc 
-- ngày có đang hàng mới nhất là MAX(date_key) vd: 20250506 
-- còn ordered_at là 2025-11-27 13:57:00

-- show the customer's previous order date and the days between them
WITH date_order AS (
    SELECT 
        dc.customer_id      AS ID,
        dc.customer_name    AS customer_name,
        fo.order_id         AS order_id,
        dc.segment          AS segment,
        fo.ordered_at       AS current_date_order,
        LAG(fo.ordered_at) OVER (
            PARTITION BY dc.customer_id ORDER BY fo.ordered_at ASC) AS previous_date_order
    FROM dim_customer dc
    LEFT JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
),
d_gap AS (
    SELECT ID, customer_name, segment, current_date_order, previous_date_order,
        DATE_DIFF('day', previous_date_order, current_date_order) AS gap_days
    FROM date_order
)
SELECT *
FROM d_gap;

--the average gap between orders per segment
WITH date_order AS (
    SELECT 
        dc.customer_id      AS ID,
        dc.customer_name    AS customer_name,
        fo.order_id         AS order_id,
        dc.segment          AS segment,
        fo.ordered_at       AS current_date_order,
        LAG(fo.ordered_at) OVER (
            PARTITION BY dc.customer_id ORDER BY fo.ordered_at ASC) AS previous_date_order
    FROM dim_customer dc
    LEFT JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
),
d_gap AS (
    SELECT ID, customer_name, segment, current_date_order, previous_date_order,
        DATE_DIFF('day', previous_date_order, current_date_order) AS gap_days
    FROM date_order
)
SELECT segment, AVG(gap_days) AS avg_d_gap
FROM d_gap
GROUP BY segment;

-- 11.For each category, each product's revenue and its share of the category total, on the same row. 
-- One query, no self-join.
WITH rev_product AS (
    SELECT 
        dp.category         AS category,
        dp.product_name     AS product_name,
        SUM(oi.line_amount) AS total_revenue_product, -- doanh thu cho mỗi loại sản phẩm 
    FROM dim_product dp
    INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
    INNER JOIN fct_order fo ON oi.order_id = fo.order_id
    GROUP BY dp.category, dp.product_name
)
SELECT 
    category,
    product_name,
    total_revenue_product,
    SUM(total_revenue_product) OVER (PARTITION BY category) AS overall_revenue, -- doanh thu của whole window
    ROUND((total_revenue_product / overall_revenue * 100), 2) AS share_pct
FROM rev_product;

-- 12.Find the largest month-on-month drop in the whole window. Explain it — the answer is not a business 
-- problem.
-- Tìm ra tháng có chênh lệch nhất (drop = giảm)
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
        LAG(total_revenue, 1) OVER (ORDER BY year, month) AS previous_rev 
    FROM info
),
difference AS (
    SELECT 
        year,
        month,
        current_rev,
        previous_rev,
        (current_rev -  previous_rev) AS diff,
        ROUND((current_rev -  previous_rev) / previous_rev * 100, 2) AS pct_diff
    FROM lag_rev_month
)
SELECT *
FROM difference
WHERE diff = (SELECT MIN(diff) FROM difference);