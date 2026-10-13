-- 1. How many orders are there in total? How many have a recorded discount? How many
--   distinct customers appear in `fct_order`?
-- How many orders are there in total?
SELECT COUNT(order_total) AS 'order total' FROM fct_order;
SELECT COUNT(*) FROM fct_order; 
-- Both results are equal 55423 so order_total does not have any NULLs.
-- There are 55423 orders in total.

-- How many have a recorded discount?
SELECT COUNT(discount_amount) FROM fct_order;-- đếm số dòng của cột discount_amount, nó sẽ không đếm các giá trị NULL
-- There are 53170 orders recorded discount. 

--How many distinct customers appear in `fct_order`?
SELECT COUNT(DISTINCT customer_sk) FROM fct_order; 

-- 2. Total revenue (`order_total`) for completed orders. Then for all statuses. **What is the
--   percentage difference, and which number would you send to a stakeholder?**
SELECT status, SUM(order_total) AS revenue
FROM fct_order
GROUP BY status
ORDER BY status;
-- I would send the completed-orders revenue to the stakeholder because it represents revenue from completed orders 
-- and excludes cancelled, returned, and pending orders.

SELECT 
    (((SELECT SUM(order_total) FROM fct_order) 
    -
    (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed')) 
    /
   (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed')) *100 
   AS pct_difference;


SELECT 
    (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed') AS completed_revenue,
    (SELECT SUM(order_total) FROM fct_order) AS all_status_revenue,
    ROUND(
        ((SELECT SUM(order_total) FROM fct_order) - 
         (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed')) 
        / (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed') * 100, 
        2
    ) AS pct_difference;


-- 3. Count, revenue, and average order value **by status**, largest revenue first.
SELECT status, 
    COUNT(order_total) AS "count order values by status",
    SUM(order_total) AS "revenue by status",
    AVG(order_total) AS "average order value by status"
FROM fct_order
GROUP BY status
ORDER BY SUM(order_total) DESC;

-- 4. Average, minimum and maximum `order_total` for completed orders. Does the average sit
-- where you'd expect between the min and max? Why not?
SUMMARIZE SELECT order_total FROM fct_order WHERE status = 'completed';
SELECT 
    AVG(order_total) AS "the average total order of completed orders", 
    MIN(order_total) AS "the minimum total order of completed orders", 
    MAX(order_total) AS "the maximum total order of completed orders" 
FROM fct_order 
WHERE status = 'completed';
-- Does the average sit where you'd expect between the min and max? Why not?
-- The average is between the minimum and maximum, as expected, but it is much closer to the minimum than the maximum. 
-- This suggests a right-skewed distribution, where most orders are relatively small while a small number of very large 
-- orders increase the maximum substantially.

-- 5. Revenue by channel for completed orders. What share of revenue is `web`?
SELECT 
    channel,
    SUM(order_total) AS revenue,
    ROUND(SUM(order_total) / (SELECT SUM(order_total) FROM fct_order WHERE status = 'completed') * 100, 2) 
    AS "revenue share %"
FROM fct_order
WHERE status = 'completed'
GROUP BY channel
ORDER BY revenue DESC;
-- The revenue of web channel is 6 428 313.68 and share of revenue is 45.26%

-- 6. Revenue by product category for completed orders (you'll need `fct_order_item` joined to
--   `dim_product` — Q03 covers joins properly, but try it now).
SELECT 
    COUNT(*)                        AS "total rows",
    COUNT(DISTINCT product_sk)      AS "distinct values of product_sk",
    COUNT(*) - COUNT(product_sk)    AS "null counts"
FROM dim_product;
-- The product_sk column in dim_product does not have any NULLs and total rows equal distinct value (180=180) 
-- -> product_sk is primary key in dim_product table. Satisfy join condition with foreign key "product_sk" of fct_order_item.

SELECT 
    COUNT(*)                        AS "total rows",
    COUNT(DISTINCT order_id)        AS "distinct values of product_sk",
    COUNT(*) - COUNT(order_id)      AS "null counts"
FROM fct_order;
-- The order_id column in fct_order does not have any NULLs and total rows equal distinct value (55423=55423) 
-- -> order_id is primary key in fct_order table. Satisfy join condition with foreign key "order_id" of fct_order_item

SELECT dp.category , SUM(oi.quantity*oi.unit_price) AS "Revenue by product"
FROM fct_order_item oi
INNER JOIN dim_product dp ON oi.product_sk = dp.product_sk
INNER JOIN fct_order fo ON oi.order_id = fo.order_id
WHERE fo.status = 'completed'
GROUP BY dp.category
ORDER BY dp.category;

-- 7. Which categories have more than 2 million in completed revenue? Use `HAVING`.
SELECT dp.category, SUM(oi.quantity * oi.unit_price) AS "revenue by product"
FROM fct_order_item oi
INNER JOIN dim_product dp ON oi.product_sk = dp.product_sk
INNER JOIN fct_order fo ON oi.order_id = fo.order_id
WHERE fo.status = 'completed'
GROUP BY dp.category
HAVING SUM(oi.quantity*oi.unit_price) > 2000000 --HAVING used to filter values after GROUP BY clause.
ORDER BY dp.category;

-- 8. Average number of lines per completed order. Careful — this is a ratio of two different
--   grains, so think about the numerator and denominator separately.
-- với mỗi đơn hàng 'completed' thì có trung bình bao nhiêu dòng (sản phẩm)?, tử số sẽ là tổng số dòng sản phẩm của tất cả 
-- các đơn hàng 'completed', mẫu số sẽ là số đơn hàng 'completed'; ví dụ dễ hiểu là order1 5 dòng, order2 6 dòng, order3 5 dòng
-- -> trung bình số dòng cho mỗi đơn hàng 'completed' = (5+6+5)/3 = 5.33333
-- đếm tổng số dòng sản phẩm của đơn hàng thành công ở oi và số đơn hàng thành công của fo, sau đó chia cho nhau
SELECT --subquery
    (SELECT COUNT(*) FROM fct_order_item oi
    LEFT JOIN fct_order fo ON oi.order_id = fo.order_id
    WHERE fo.status = 'completed')
    /
    (SELECT COUNT(*) FROM fct_order WHERE status = 'completed') AS "average lines completed orders";

-- 9. How many current customers are in each segment? Then: how many *distinct customers* have
--   ever placed a completed order, by segment. **These two sets of numbers disagree. Note it
--   down and move on — Q07 explains it.**
-- How many current customers are in each segment?
SELECT segment, COUNT(*) FROM dim_customer 
WHERE is_current = 'Y'
GROUP BY segment
ORDER BY COUNT(*);

-- How many *distinct customers* have ever placed a completed order, by segment?
SELECT c.segment, COUNT(DISTINCT c.customer_id) AS "distinct customer"
FROM dim_customer c
INNER JOIN fct_order fo ON c.customer_sk = fo.customer_sk 
-- giữ lại phần chung của cả hai bảng ở đây là completed order là điểm chung.
WHERE fo.status = 'completed' 
GROUP BY c.segment
ORDER BY COUNT(DISTINCT c.customer_id);

-- 10. Average `discount_amount` for completed orders, computed two ways: as SQL gives it by
--    default, and treating unrecorded discounts as zero. Report both and say which one you'd
--    label "average discount".
-- default way:
SELECT AVG(discount_amount) AS "avg by default way" FROM fct_order WHERE status = 'completed'; 
-- AVG (giống SUM, COUNT(col)) sẽ tự động bỏ qua NULL khi tính — tức nó chỉ chia 
-- cho số dòng có giá trị thật, không chia cho tổng số dòng.
-- treat unrecorded discount as zero
SELECT AVG(COALESCE(discount_amount, 0)) AS "avg after treating null as zero" FROM fct_order WHERE status = 'completed';
-- avg_default: 15.95 (over 44559 rows with recorded discount)
-- avg_treating_null_as_zero: 15.29 (over all 46460 rows)
-- I'd label "average discount" = avg_default. NULL means unknown, not 
-- confirmed zero — treating it as 0 assumes something we don't actually know.
-- avg_default only covers ~96% of completed orders (1901 unrecorded).

-- 11. For each month of 2026, the number of completed orders and their revenue. (Join
--    `dim_date` — or use `date_key / 100` as a shortcut and note why that's a hack.)
-- date_key // 100
SELECT 
    date_key // 100      AS "year month", -- chia lấy phần nguyên // , chia lấy cả phần dư / 
    COUNT(*)             AS "total completed orders", 
    SUM(order_total)     AS "revenue"
FROM fct_order
WHERE status = 'completed'
    AND date_key >= 20260101
    AND date_key <= 20261231
GROUP BY date_key//100
ORDER BY "year month";

-- JOIN date_key
SELECT 
    dd.month_name,  
    COUNT(*)               AS "total completed orders",
    SUM(fo.order_total)    AS "revenue"
FROM fct_order fo
INNER JOIN dim_date dd ON fo.date_key = dd.date_key
WHERE fo.status = 'completed'
      AND dd.date_key >= 20260101
      AND dd.date_key <= 20261231
GROUP BY dd.month_name, dd.month
ORDER BY dd.month;
 
-- 12. The 5 products with the highest completed revenue: SKU, category, revenue.
SELECT dp.SKU, dp.category, SUM(oi.line_amount) AS "revenue for each type of product"
FROM dim_product dp
INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
INNER JOIN fct_order fo ON oi.order_id = fo.order_id 
WHERE fo.status = 'completed'
GROUP BY dp.category, dp.SKU
ORDER BY SUM(oi.line_amount) DESC
LIMIT 5;
