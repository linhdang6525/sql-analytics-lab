Wrong number 1 
-- the rows that shouldn't be there fct_order contains 3,354 cancelled and 2,797 pending orders. Nothing in the table's name warns you.

-- 1.Compute total revenue with no status filter. Then completed only. Report both and the percentage difference.

WITH 
overall_rev AS (
    SELECT SUM(order_total) AS total_revenue FROM fct_order
),
completed_rev AS (
    SELECT SUM(order_total) AS completed_total_rev 
    FROM fct_order WHERE status = 'completed'
)
SELECT 
    (SELECT total_revenue FROM overall_rev) AS total_rev,
    (SELECT completed_total_rev FROM completed_rev) AS completed_rev,
    ROUND(((SELECT total_revenue FROM overall_rev) - (SELECT completed_total_rev FROM completed_rev)) 
    / (SELECT completed_total_rev FROM completed_rev) * 100, 2) AS pct_diff;
-- total revenue without filter status has 16922496.96. While with filtering completed status has 14201609.13 
-- if we don't filter status the percentage difference is 19.16%

-- 2.Which is right? It depends on the question — and "revenue" in a business conversation almost always means money you actually got. 
-- Write the one-line definition you would put next to the number in a report.
-- In my opinion, I will send stakeholder the completed revenue, due to revenue be actually what we got.

-- 3.Now the harder case: should returned orders count? Argue both sides in two sentences, then pick one and say what you'd tell Finance.

-- The check: before aggregating any fact table, run SELECT status, count(*) FROM fct_order GROUP BY 1 — or the equivalent for 
-- whatever categorical column it has. Every time. It takes four seconds and it is the highest-value four seconds in analytics.
SELECT status, count(*) FROM fct_order GROUP BY 1

-- On one hand, returned orders should remain in the dataset because they help the company understand return behavior, identify 
-- product quality issues, customer-related reasons, and external factors that may lead to returns.
-- On the othẻ hand, returned orders should not automatically be included in recognized revenue because the returned amount may 
-- need to be deducted or adjusted, depending on the company's accounting policy and whether the refund has been processed.
-- In my opinion, I would retain all order statuses for operational analysis, report revenue using a clearly defined business rule to 
-- Finance, and provide return and cancellation metrics to the Inventory/Warehouse team to investigate causes and improve operations.

Wrong number 2 — fan-out
-- 4.Join completed orders to bridge_order_promo and sum order_total. Record the number. -- 5.08 million

SELECT SUM(fo.order_total) AS total_revenue
FROM fct_order fo 
INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
WHERE fo.status = 'completed';

-- 5.Compute the correct promo-attributed revenue using allocation_factor. -- 3.79 million

SELECT SUM(fo.order_total * bop.allocation_factor) AS total_revenue
FROM fct_order fo 
INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
WHERE fo.status = 'completed';

-- 6.Record: the row count of completed orders, the row count after the join, and the ratio. Explain the ratio in terms of promos per order.

WITH 
before_joining AS ( -- 46460: all orders included with and without promo code
    SELECT COUNT(*) AS count_before_joining FROM fct_order WHERE status = 'completed'
),
after_joining AS ( -- 16507: only orders with promo code
    SELECT COUNT(*) AS count_after_joining FROM fct_order fo 
    INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
    WHERE fo.status = 'completed'
),
distinct_order AS (
    SELECT COUNT(DISTINCT fo.order_id) AS count_distinct FROM fct_order fo 
    INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
    WHERE fo.status = 'completed'
)
SELECT 
    (SELECT count_before_joining FROM before_joining) AS before_join,
    (SELECT count_after_joining FROM after_joining) AS after_join,
    (SELECT count_distinct FROM distinct_order) AS distinct_value, 
    ROUND((SELECT count_after_joining FROM after_joining) / (SELECT count_distinct FROM distinct_order), 2) AS ratio;
-- Ratio 1.34 nghĩa là mỗi đơn hàng có promo xuất hiện trung bình 1.34 dòng sau JOIN.
-- Không có nghĩa mọi đơn đều sử dụng 1.34 promo.

-- 7.Do the same thing with the SCD2 trap: join fct_order to dim_customer without is_current and count rows. Then with. Report both.

WITH
without_current_filter AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT fo.order_id) AS order_count
    FROM fct_order fo
    JOIN dim_customer dc
        ON fo.customer_sk = dc.customer_sk
    WHERE fo.status = 'completed'
),
with_current_filter AS (
    SELECT
        COUNT(*) AS row_count,
        COUNT(DISTINCT fo.order_id) AS order_count
    FROM fct_order fo
    JOIN dim_customer dc
        ON fo.customer_sk = dc.customer_sk
    WHERE fo.status = 'completed'
      AND dc.is_current = 'Y'
)
SELECT
    w.row_count AS rows_without_filter,
    w.order_count AS orders_without_filter,
    c.row_count AS rows_with_filter,
    c.order_count AS orders_with_filter
FROM without_current_filter w
CROSS JOIN with_current_filter c;

-- The check: count rows before and after every join, and be able to explain any change. A join that multiplies rows is not always wrong 
-- but it is always a decision, and if you didn't make it deliberately, it made it for you.

Wrong number 3 — the average of averages
-- 8.Compute the average line amount per category. Then average those five numbers.

SELECT
        dp.category                     AS category,
        ROUND(AVG(oi.line_amount), 2)   AS avg_volume
    FROM dim_product dp
    LEFT JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
    GROUP BY dp.category;

WITH line_volume AS (
    SELECT
        dp.category                     AS category,
        ROUND(AVG(oi.line_amount), 2)   AS avg_volume
    FROM dim_product dp
    LEFT JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
    GROUP BY dp.category
)
SELECT 
    ROUND(AVG(avg_volume), 2) AS avg_5_category
FROM line_volume;

-- 9.Compute the true average line amount across all lines.

SELECT ROUND(AVG(line_amount), 2) AS true_avg_line
FROM fct_order_item;

-- 10.Report both, the difference, and the reason — look at the volume of each category alongside its average.

WITH 
line_volume AS (
    SELECT
        dp.category                     AS category,
        ROUND(AVG(oi.line_amount), 2)   AS avg_volume
    FROM dim_product dp
    LEFT JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
    GROUP BY dp.category
), 
average_5_category AS (
    SELECT 
        ROUND(AVG(avg_volume), 2) AS avg_5_category
    FROM line_volume
),
true_average AS (
    SELECT ROUND(AVG(line_amount), 2) AS true_avg_line
    FROM fct_order_item
)
SELECT
    lv.category,
    lv.avg_volume,
    a5.avg_5_category,
    ta.true_avg_line,
    ROUND(a5.avg_5_category - ta.true_avg_line, 2) AS difference
FROM line_volume lv
CROSS JOIN average_5_category a5 -- đưa một kết quả tổng hợp từ CTE khác vào từng dòng
CROSS JOIN true_average ta
ORDER BY lv.category;

-- window function:
WITH line_volume AS (
    SELECT
        dp.category,
        AVG(oi.line_amount) AS avg_volume
    FROM dim_product dp
    LEFT JOIN fct_order_item oi
        ON dp.product_sk = oi.product_sk
    GROUP BY dp.category
)
SELECT
    category,
    ROUND(avg_volume, 2) AS avg_volume,
    ROUND(AVG(avg_volume) OVER (), 2) AS avg_5_category,
    (SELECT ROUND(AVG(line_amount), 2) FROM fct_order_item) AS true_avg_line
FROM line_volume
ORDER BY category;
-- 11.Write the general rule in one sentence: when is it legitimate to average an average?
-- Averaging averages is legitimate only when each average represents an equally weighted group; 
-- otherwise, sum the numerators and denominators across groups and divide once at the end.
-- The check: never average a column that is itself an average. Keep the numerator and the denominator, 
-- sum both, divide once at the end.

Wrong number 4 — distinct counts that dont add up
-- 12.Count distinct customers who placed a completed order, by segment. Sum those three numbers. 
-- Now count distinct customers who placed a completed order overall. The numbers disagree — find out why. 
-- (Hint: dim_customer has 1,302 rows for 1,200 customers.)
SELECT 
    dc.segment,
    COUNT (DISTINCT dc.customer_id) AS distinct_customer
FROM dim_customer dc
INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
WHERE fo.status = 'completed'
GROUP BY dc.segment;

SELECT 
    segment,
    COUNT (DISTINCT customer_id) AS distinct_customer
FROM dim_customer
GROUP BY segment;

SELECT 
    (SELECT -- 1160
        COUNT (DISTINCT dc.customer_id) 
    FROM dim_customer dc
    INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
    WHERE fo.status = 'completed') AS distinct_customer_with_filter,
    (SELECT -- 1200
        COUNT (DISTINCT customer_id) 
    FROM dim_customer) AS distinct_customer_without_filter;

SELECT COUNT(DISTINCT dc.customer_id) AS customers_without_completed_order
FROM dim_customer dc
WHERE NOT EXISTS (
    SELECT 1
    FROM dim_customer dcc
    JOIN fct_order fo
        ON fo.customer_sk = dcc.customer_sk
    WHERE dcc.customer_id = dc.customer_id
      AND fo.status = 'completed'
);
-- 40 customers don't have any completed order.

SELECT
    COUNT(DISTINCT dc.customer_sk) AS customers_by_sk,
    COUNT(DISTINCT dc.customer_id) AS customers_by_id
FROM dim_customer dc
JOIN fct_order fo
    ON dc.customer_sk = fo.customer_sk
WHERE fo.status = 'completed';
-- 13.Fix it two ways: by counting customer_id instead of customer_sk, and by filtering to is_current = 'Y'.
-- Do the two fixes agree? Should they?
SELECT
    COUNT(DISTINCT dc_current.customer_id) AS count_enterprise_customer
FROM dim_date dd
JOIN fct_order fo ON dd.date_key = fo.date_key
JOIN dim_customer dc_order ON fo.customer_sk = dc_order.customer_sk 
JOIN dim_customer dc_current ON dc_order.customer_id = dc_current.customer_id  
WHERE fo.status = 'completed'
AND dc_current.segment = 'enterprise';

SELECT
    COUNT(DISTINCT dc_current.customer_id) AS count_enterprise_customer
FROM dim_date dd
JOIN fct_order fo ON dd.date_key = fo.date_key
JOIN dim_customer dc_order ON fo.customer_sk = dc_order.customer_sk -- tìm đúng phiên bản được đơn hàng tham chiếu?
-- loại thông tin khác nhau có sự thay đổi
JOIN dim_customer dc_current ON dc_order.customer_id = dc_current.customer_id AND dc_current.is_current = 'Y' -- lọc ra đúng ID có trạng thái Y
WHERE fo.status = 'completed'
  AND dc_current.segment = 'enterprise';
-- Fix 1: COUNT(DISTINCT customer_id) để mỗi khách hàng chỉ được đếm một lần
-- trong từng segment, nhưng một khách hàng vẫn có thể xuất hiện ở nhiều segment
-- nếu thông tin segment thay đổi theo thời gian.

-- Fix 2: Lọc is_current = 'Y' để chỉ xét phiên bản hiện tại.
-- Tuy nhiên, JOIN bằng customer_sk có thể bỏ sót khách hàng có đơn hàng
-- tham chiếu phiên bản cũ. Muốn đếm theo segment hiện tại, cần JOIN dim_customer
-- lần hai bằng customer_id. 

-- 14.Write down which of the two you'd use for "how many customers bought from us in 2026", and 
-- which for "how many enterprise customers bought from us in 2026". They may not be the same choice.
-- "how many customers bought from us in 2026":
SELECT
    COUNT(DISTINCT dc.customer_id) AS count_customer
FROM dim_date dd
JOIN fct_order fo
    ON dd.date_key = fo.date_key
JOIN dim_customer dc
    ON fo.customer_sk = dc.customer_sk
WHERE dd.year = 2026
  AND fo.status = 'completed';

-- how many enterprise customers bought from us in 2026
SELECT 
    dd.year,
    COUNT(DISTINCT dc.customer_id) AS count_customer -- distinct là vì một khách maybe có 2 trạng thái current khác nhau (do SCD type 2)
FROM dim_date dd 
LEFT JOIN fct_order fo ON dd.date_key = fo.date_key 
LEFT JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk -- nếu như này thì maybe nó vô tình đếm đúng thui chứ không có xác minh rõ ràng
WHERE dd.year = 2026 AND dc.segment = 'enterprise' AND dc.is_current = 'Y' AND fo.status = 'completed'
GROUP BY dd.year;

SELECT
    COUNT(DISTINCT dc_current.customer_id) AS count_enterprise_customer
FROM dim_date dd
JOIN fct_order fo ON dd.date_key = fo.date_key
JOIN dim_customer dc_order ON fo.customer_sk = dc_order.customer_sk -- tìm đúng phiên bản được đơn hàng tham chiếu?
-- loại thông tin khác nhau có sự thay đổi
JOIN dim_customer dc_current ON dc_order.customer_id = dc_current.customer_id AND dc_current.is_current = 'Y' -- lọc ra đúng ID có trạng thái Y
WHERE dd.year = 2026
  AND fo.status = 'completed'
  AND dc_current.segment = 'enterprise';

-- dc_order: Khách hàng ở thời điểm phát sinh đơn hàng là ai, thuộc phiên bản nào?
-- dc_current: Hiện tại khách hàng đó thuộc phân khúc nào?

-- The check: a distinct count is not additive. If your segment counts sum to more than your total, 
--you have a grain problem, not a rounding problem. Always sanity-check that the parts sum to the whole 
-- — and when they don't, find out why before you publish either.

-- Go back and check three earlier answers. This exact trap — the versioned customer_sk standing in for 
-- a person — was hiding, unlabeled, in three questions you already answered: Q03 question 12 
-- (top 10 customers by order count), Q05 question 4 (average orders per customer by segment), 
-- and Q06 question 10 (days between a customer's orders). None of those three told you anything was wrong. 
-- Open your saved queries for all three now — did you group or partition by customer_sk, or 
-- by customer_id? If it was customer_sk, your numbers there under- or over-counted exactly 
-- the way this section just demonstrated. Fix the ones that need it before moving on; 
-- this is the whole lesson of the assignment, applied to your own prior work instead of a fresh example.

The fifth thing: reconciliation
-- 15.For completed orders, compute SUM(order_total) and SUM(line_amount). They differ. 
-- Account for the difference: discounts, shipping, and one more thing.

SELECT
    (SELECT 
        SUM(order_total) 
    FROM fct_order 
    WHERE status = 'completed') AS adjust_total_rev,
    (SELECT
        SUM(oi.line_amount) 
    FROM fct_order fo
    INNER JOIN fct_order_item oi ON fo.order_id = oi.order_id
    WHERE fo.status = 'completed') AS raw_total_rev;
-- SUM(order_total) = adjust_total_rev has less than SUM(line_amount) = raw_total_rev that means order_total
-- has promo code to discount, shipping fee?

-- 16.Find the orders where order_total ≠ SUM(line_amount) − discount + shipping. How many are there? 
-- There are two different causes and roughly half the rows belong to each. Identify both.
-- 2 CTE: 1 là lôi cái order_total theo từng cái order_id (GROUP BY), 2 là tính như này
-- SUM(line_amount) − discount + shipping, sau đó sẽ so sánh với các cột có thể NULL sẽ đổi thành 0
WITH 
line_total AS ( -- tính tổng line_amount cho từng đơn hàng
    SELECT 
        order_id,
        SUM(line_amount) AS total_line_amount
    FROM fct_order_item
    GROUP BY order_id
),
reconciliation AS ( -- đối soát thông tin tính ra tổng đơn thuần tuý - discount + ship
    SELECT
        fo.order_id,
        fo.order_total,
        lt.total_line_amount,
        fo.discount_amount,
        fo.shipping_fee,
        lt.total_line_amount - COALESCE(fo.discount_amount, 0) + COALESCE(fo.shipping_fee, 0) 
            AS calculated_total
    FROM fct_order fo
    JOIN line_total lt ON fo.order_id = lt.order_id
),
mismatched_order AS ( -- lọc ra các đơn có sự chênh lệch giá delta khác nhau là > 0.01 thì lọc ra
    SELECT *
    FROM reconciliation
    WHERE ABS(order_total - calculated_total) > 0.01
)
SELECT * FROM mismatched_order;

-- 17.Write the sentence you'd put in a report footnote about which figure you used for revenue and why.
-- Revenue is calculated using completed orders only, based on order_total, to ensure consistent revenue 
-- reporting. Cancelled and pending orders are excluded, while discrepancies between order-level totals 
-- and line-item amounts are acknowledged due to missing discount records and order-level adjustments.