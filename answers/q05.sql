-- 1. What is the average completed order value? Now list the 10 completed orders furthest
--   *above* that average, showing the order total and the difference.

    WITH avg_value AS (
        SELECT AVG(order_total) AS avg_total
        FROM fct_order
        WHERE status = 'completed'
    )
    SELECT *, 
        order_total - (SELECT avg_total FROM avg_value) AS difference
    FROM fct_order
    WHERE status = 'completed'
    AND order_total > (SELECT avg_total FROM avg_value)
    ORDER BY order_total DESC
    LIMIT 10;

-- 2. How many completed orders are above the overall average order value? What percentage is
--   that? (It won't be 50% — explain why in one sentence.)

    WITH 
        avg AS( 
            SELECT AVG(order_total) AS average_total 
            FROM fct_order 
            WHERE status = 'completed'
    ), 
        count_above_average AS (
            SELECT COUNT(*) AS count_above_avg
            FROM fct_order
            WHERE status = 'completed'
            AND order_total > (SELECT average_total FROM avg)
    )
    SELECT 
        (SELECT count_above_avg FROM count_above_average) AS count_completed_order,
        ROUND((SELECT count_above_avg FROM count_above_average)
        / 
        (SELECT COUNT(*) FROM fct_order WHERE status = 'completed') * 100, 2) AS pct
    FROM fct_order
    WHERE status = 'completed'
    GROUP BY status;
-- Only 33.2%, not 50%: order_total is right-skewed (a few very large orders pull the mean up),
-- so most orders sit below the average.
-- 3. Which customers have spent more than 20,000 in completed orders? Show customer id, name,
--   and total. Use a CTE.
    WITH customer_spending AS (
        SELECT 
            SUM(fo.order_total)    AS total_spending,
            dc.customer_id         AS ID,
            dc.customer_name       AS name
        FROM fct_order fo
        INNER JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk
        WHERE fo.status = 'completed'
        GROUP BY dc.customer_id, dc.customer_name
    )
    SELECT ID, name, total_spending 
    FROM customer_spending
    WHERE total_spending > 20000
    ORDER BY total_spending DESC;

-- 4. For each segment, the average *number of completed orders per customer*. This needs two
--   steps: per-customer counts, then average by segment.
    WITH count_customer AS (
        SELECT 
            dc.segment,
            COUNT(DISTINCT dc.customer_id) AS count_customer_by_segment
        FROM dim_customer dc
        INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
        WHERE fo.status = 'completed'
        GROUP BY dc.segment
        ORDER BY count_customer_by_segment DESC
    ),
    count_order AS (
        SELECT 
            dc.segment,
            COUNT(fo.order_id) AS count_order_by_segment
        FROM fct_order fo
        INNER JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk
        WHERE status = 'completed'
        GROUP BY dc.segment
    )
-- vấn đề ở đây là không tính trung bình được cho mỗi segment, ta sẽ join hai CTE này lại vì chúng đều 
-- có chung segment (do tôi tự gán vào)
    SELECT 
        c.segment, 
        ROUND(o.count_order_by_segment / c.count_customer_by_segment, 2) AS avg_completed_order_per_customer
    FROM count_customer c 
    INNER JOIN count_order o ON c.segment = o.segment
    ORDER BY avg_completed_order_per_customer DESC;

-- 5. Which products have sold more than 900 units (completed orders only)? How many products
--   are there in total with any completed sales — and how does that compare with the 180 rows
--   in `dim_product`?
-- những sản phẩm nào đã bán hơn 900 đơn vị
-- list chúng ra

-- which product have been sold above 900 units
    WITH product AS (
        SELECT 
            dp.product_name     AS name,
            dp.product_sk       AS product_sk,
            SUM(oi.quantity)    AS unit_sold
        FROM dim_product dp 
        INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
        INNER JOIN fct_order fo ON oi.order_id = fo.order_id
        WHERE fo.status = 'completed'
        GROUP BY dp.product_name, dp.product_sk
    ) 
    SELECT name, unit_sold
    FROM product
    WHERE unit_sold > 900;

-- How many product have been sold?
    SELECT 
        dp.product_name,
        dp.product_sk,
        SUM(oi.quantity) AS unit_sold
    FROM dim_product dp 
    INNER JOIN fct_order_item oi ON dp.product_sk = oi.product_sk
    INNER JOIN fct_order fo ON oi.order_id = fo.order_id
    WHERE fo.status = 'completed'
    GROUP BY dp.product_name, dp.product_sk;
-- It's exactly 9 products have been never sold in previous assignment.
-- logic như này: sau khi đếm đơn vị của các sản phẩm theo product_sk chúng sẽ được gom lại và gán 
-- đúng với tên sản phẩm của mình hình dung product_sk 4 có 5 unit ở đơn này, đơn nọ có 6 unit, sau 
-- khi SUM ta có 11 unit và được gán đúng với product_sk 4 và từ product_sk 4 máy sẽ dò tìm tên tương ứng.

-- 6. Which current customers have never placed an order? Answer it **twice** — once with
--   `NOT IN (SELECT customer_sk FROM fct_order)` and once with `NOT EXISTS`. **The two
--   answers differ. Explain why before reading the answer key.**

-- NOT EXISTS
    SELECT COUNT(dc.customer_id) AS customer_no_order 
    FROM dim_customer dc 
    WHERE dc.is_current = 'Y'
    AND NOT EXISTS (SELECT 1 FROM fct_order fo WHERE dc.customer_sk = fo.customer_sk);

-- NOT IN
    SELECT COUNT(dc.customer_id) AS customer_no_order 
    FROM dim_customer dc 
    WHERE dc.is_current = 'Y' 
    AND customer_sk NOT IN (SELECT customer_sk FROM fct_order fo);
-- NOT EXISTS = 40, NOT IN = 0. fct_order.customer_sk contains NULLs (guest orders), so
-- "x NOT IN (list with a NULL)" is never true -> zero rows. NOT EXISTS ignores NULLs.

-- 7. Which orders are larger than the average order for *that customer*? Count them.
--   (Correlated subquery, or a CTE plus a join — try both.)
-- So từng đơn với mức trung bình của chính khách đó, rồi đếm số đơn vượt.
-- CTE này là tính trung bình order_total cho mỗi khách
-- ở bảng tạm thời này sẽ có một customer_sk là một giá trị trung bình
-- CTE:
    WITH avg_total_this_customer AS (
        SELECT 
            customer_sk,
            AVG(order_total) AS avg
        FROM fct_order fo
        WHERE status = 'completed'
        GROUP BY customer_sk 
    )
    SELECT COUNT(*) AS count_customer
    FROM fct_order fo
    JOIN avg_total_this_customer a ON fo.customer_sk = a.customer_sk
    WHERE fo.status = 'completed'
    AND fo.order_total > a.avg;

-- correlated:
SELECT COUNT(*) AS count_customer
FROM fct_order fo1
WHERE fo1.status = 'completed'
AND fo1.order_total > (SELECT AVG(fo2.order_total) 
                        FROM fct_order fo2
                        WHERE fo2.status = 'completed' AND fo1.customer_sk = fo2.customer_sk);
-- 8. For each category, the single best-selling product by revenue. Do it with a CTE and a
--   `MAX` — then keep the query, because Q06 does it in three lines with a window function.
-- với mỗi loại sản phẩm (category), thì sản phẩm nào có doanh thu lớn nhất
-- lấy line_amount là bằng unit_price * quantity sau đó nhóm lại theo product_name/ product_sk sẽ được bảng 
-- gồm tên sản phẩm, total_rev cho mỗi loại sản phẩm đó.

WITH rev_each_product AS (
    SELECT 
        dp.category,
        dp.product_name,
        SUM(oi.line_amount) AS total_rev
    FROM fct_order_item oi
    INNER JOIN fct_order fo ON oi.order_id = fo.order_id -- lấy status và line_amount
    INNER JOIN dim_product dp ON oi.product_sk = dp.product_sk -- lấy category và product_name
    WHERE fo.status = 'completed'
    GROUP BY dp.category, dp.product_name -- bảng tạm với phân loại, tên sản phẩm, total rev của nó.
),
max_per_category AS (
    SELECT category, MAX(total_rev) AS max_rev -- max rev của sản phẩm và nhóm theo category 
    FROM rev_each_product
    GROUP BY category -- bảng tạm với max rev và tên category
)
SELECT r.category, r.product_name, r.total_rev
FROM rev_each_product r
INNER JOIN max_per_category m ON r.category = m.category AND r.total_rev = m.max_rev
-- nối lại sẽ có phân loại, tên sản phẩm, total_rev
ORDER BY r.total_rev DESC;


-- 9. Rewrite one of your Q03 or Q04 queries using CTEs to make it clearer. Put both versions
--   in your file and write one line on what improved.
-- Q04 - 06
-- 6. Completed revenue for December 2025. How does it compare with the average month across
--    the whole window?
    WITH rev AS (
        SELECT
            dd.month                AS month,
            dd.year                 AS year,
            SUM(fo.order_total)     AS total_order
        FROM fct_order fo
        INNER JOIN dim_date dd ON fo.date_key = dd.date_key
        WHERE fo.status = 'completed'
        GROUP BY dd.month, dd.year
    )
    SELECT
        (SELECT total_order FROM rev WHERE month = 12 AND year = 2025) AS revenue_December_25,
        (SELECT AVG(total_order) FROM rev) AS monthly_revenue;
-- It's shorter than old one.

-- 10. How many completed orders used each promo code? The eight codes are suspiciously even —
--    say in one sentence what that tells you about how promos were assigned.
-- bao nhiêu đơn hàng có trạng thái hoàn thành đã sử dụng promo code nhóm theo promo code là gán ngược lại cho order_id
-- để biết rõ mỗi order_id nào sử dụng gì, không cần nhân allocation_factor vì nếu một đơn apply 2 mã trở lên thì sẽ xuất
-- hiện 2 dòng
    SELECT
        bop.promo_code,
        COUNT(fo.order_id) AS count_order
    FROM fct_order fo
    INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
    WHERE fo.status = 'completed'
    GROUP BY bop.promo_code
    ORDER BY count_order DESC;
-- 2,020 to 2,116 orders per code: the codes are almost evenly spread, which suggests they
-- were assigned randomly with equal probability, not by customer behaviour or targeting.

-- 11. Customers whose *first* completed order was in 2026. How many are there?
    WITH first_order AS (
        SELECT
            customer_sk,
            MIN(ordered_at) AS first_order_in_2026
        FROM fct_order 
        WHERE status = 'completed' AND customer_sk IS NOT NULL
        GROUP BY customer_sk
    )
    SELECT COUNT(first_order_in_2026) AS count_first_order_in_2026
    FROM first_order
    WHERE EXTRACT(YEAR FROM first_order_in_2026) = 2026;

-- 12. Take the ugliest query you've written so far in this lab. Rewrite it with CTEs, verify
--    the numbers match exactly, and note how long the rewrite took.
-- List the 10 customers with the most completed orders: customer id, name, segment, order
--    count, total revenue.
-- liệt kê ra 10 khách hàng có số lượng đơn hàng hoàn thành nhiều nhất và show các thông tin:
-- customer id, name, segment, order count, total revenue.
    WITH customer AS (
        SELECT
            dc.customer_id,
            COUNT(fo.order_id) AS count_order,
            SUM(fo.order_total) AS rev
        FROM fct_order fo
        INNER JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk
        WHERE fo.status = 'completed'
        GROUP BY dc.customer_id
    ),
    current AS (
        SELECT
            customer_id,
            customer_name AS name,
            segment
        FROM dim_customer
        WHERE is_current = 'Y'
    )
    SELECT
        cus.customer_id,
        cur.name,
        cur.segment,
        cus.count_order,
        cus.rev
    FROM customer cus
    INNER JOIN current cur ON cus.customer_id = cur.customer_id
    ORDER BY cus.count_order DESC
    LIMIT 10;