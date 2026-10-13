-- 1. Join `fct_order` to `dim_store`. How many rows? Now do it as a `LEFT JOIN`. Same
--   number? Why?
SELECT COUNT(*)
FROM fct_order fo
INNER JOIN dim_store ds ON ds.store_sk = fo.store_sk; 
có bao nhiêu đơn hàng có store_sk khớp được với 1 cửa hàng thật sự tồn tại trong dim_store
-- There are 55423 rows when using INNER JOIN for both table.
SELECT COUNT(*)
FROM fct_order fo
LEFT JOIN dim_store ds ON ds.store_sk = fo.store_sk; -- giữ lại tất cả các order kể cả những order không có store_sk

-- 2. Join `fct_order` to `dim_customer` on `customer_sk`, inner. Then left. **The two
--   numbers differ — by how much, and what are the missing rows?**
SELECT COUNT(*) 
FROM fct_order fo
INNER JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk; -- 54583
-- giữ lại những đơn hàng có customer_sk còn những đơn hàng nào không có customer_sk thì sẽ bị loại bỏ. 
-- số lượng dòng ở INNER JOIN có thể ít hơn so với LEFT JOIN
SELECT COUNT(*) 
FROM fct_order fo
LEFT JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk; -- 55423
-- giữ lại tất cả các đơn hàng dù cho nó không có customer_sk, những đơn không có customer_sk trong fo sẽ được xem là khách
-- vãng lai vì họ có thể mua và không để lại bất cứ thông tin gì.
SELECT 
    (SELECT COUNT(*) 
    FROM fct_order fo
    LEFT JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk) 
    -
    (SELECT COUNT(*) 
    FROM fct_order fo
    INNER JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk) AS "the missing rows"; -- 840 rows does not have customer_sk

-- 3. Completed revenue by store country. Which country is largest?
SELECT  
    ds.country_code, 
    SUM(fo.order_total) AS "revenue of completed orders"
FROM fct_order fo
INNER JOIN dim_store ds ON fo.store_sk = ds.store_sk 
WHERE fo.status = 'completed'
GROUP BY ds.country_code
ORDER BY SUM(fo.order_total) DESC;
-- The country_code BE has the largest revenue of the completed orders with  4 853 938.40

-- 4. Completed revenue by customer segment, joining through `customer_sk`.
SELECT 
    COALESCE(dc.segment, 'unknown') AS segment, 
    SUM(fo.order_total) AS "revenue of completed orders"
FROM fct_order fo 
LEFT JOIN dim_customer dc ON fo.customer_sk = dc.customer_sk -- sử dụng LEFT JOIN để giữ lại tất cả các đơn hàng kể cả không có customer_sk
WHERE fo.status = 'completed'
GROUP BY segment
ORDER BY SUM(fo.order_total) DESC;

-- 5. Completed revenue by product category — this needs three tables: `fct_order`,
--   `fct_order_item`, `dim_product`.
-- doanh thu của những đơn hàng có trạng thái thàng công được nhóm theo loại sản phẩm
-- do order_total ở bảng fo sẽ là tổng số tiền của tất cả các item theo order đó (sẽ không được chi tiết theo từng loại sản phẩm)
-- nên join cái gì đó từ bảng oi ta sẽ có chi tiết giá cho từng sản phẩm và từ đó tính doanh thu chính xác hơn cho từng loại sản phẩm.
SELECT COUNT(*) FROM fct_order_item;             -- trước join
SELECT COUNT(*) FROM fct_order_item oi
INNER JOIN dim_product dp ON oi.product_sk = dp.product_sk;   -- sau join

SELECT COUNT(DISTINCT fo.order_id)
FROM fct_order fo
INNER JOIN fct_order_item oi ON fo.order_id = oi.order_id;
-- 55,423 = tổng số đơn trong fct_order → không đơn nào bị mất

SELECT COUNT(*)
FROM fct_order_item oi
LEFT JOIN fct_order fo ON oi.order_id = fo.order_id
WHERE fo.order_id IS NULL;
-- 0 → không có item nào trỏ tới đơn không tồn tại

SELECT 
    dp.category, 
    SUM(oi.line_amount) AS "revenue of completed order by product category"
FROM fct_order fo 
INNER JOIN fct_order_item oi ON fo.order_id = oi.order_id
INNER JOIN dim_product dp ON oi.product_sk = dp.product_sk
WHERE 
    fo.status = 'completed'
GROUP BY dp.category
ORDER BY SUM(oi.line_amount) DESC;

-- 6. Which products have never been sold? How many are there? (Use both anti-join idioms and
--   confirm they agree.)

-- LEFT JOIN + IS NULL
-- giữ lại tất cả các sản phẩm trong bảng dim_product và sau đó ghép với bảng đơn hàng chi tiết sản phẩm, 
-- nếu bảng chi tiết sản phẩm không có sản phẩm đó thì sau khi JOIN ngay tại dòng đó mã sản phẩm vẫn hiện ra nhưng cột 
-- order_id tại dòng đó sẽ được gán là NULL, lệnh này giúp ta tìm được các sản phẩm không bao giờ được bán. 
SELECT COUNT(p.sku) AS "count the products have never been sold" FROM dim_product p
LEFT JOIN fct_order_item i ON i.product_sk = p.product_sk
WHERE i.product_sk IS NULL;

SELECT p.sku AS "the products have never been sold" FROM dim_product p
LEFT JOIN fct_order_item i ON i.product_sk = p.product_sk
WHERE i.product_sk IS NULL;

-- NOT EXISTS  (usually clearer, and NULL-safe unlike NOT IN)
SELECT COUNT(p.sku) AS "the products have never been sold1" FROM dim_product p
WHERE NOT EXISTS (SELECT 1 FROM fct_order_item i WHERE i.product_sk = p.product_sk);
-- ví dụ đơn hàng đó có tồn tại thì điều kiện tại WHERE sẽ skip đi.
-- 2 idioms have the same result, but NOT EXISTS is usually clearer and NULL-safe unlike NOT IN.

-- 7. Which current customers have never placed an order? How many?
-- Which current customers have never placed an order?
SELECT dc.customer_id AS "customer_id with no order"
FROM dim_customer dc
WHERE dc.is_current = 'Y'
AND NOT EXISTS (SELECT 1 FROM fct_order fo WHERE dc.customer_sk = fo.customer_sk);

-- How many?
SELECT COUNT(dc.customer_id) AS "customers have no order"
FROM dim_customer dc
WHERE dc.is_current = 'Y'
AND NOT EXISTS (SELECT 1 FROM fct_order fo WHERE dc.customer_sk = fo.customer_sk);
-- fct_order: One row of fct_order is one order - including cancalled and returned ones.
-- dòng trong bảng fct_order fo là 1 đơn hàng nên khi JOIN/WHERE như này thì đồng nghĩa đơn xét order luôn rồi.
-- Bạn không thấy chữ "order" xuất hiện tường minh, nhưng hành động join/kiểm tra tồn tại trên bảng fct_order chính 
-- là cách SQL biểu đạt khái niệm "có đơn hàng". So khớp customer_sk không phải là "so sánh cho có" — nó chính là cách 
-- duy nhất để biết 1 khách hàng có xuất hiện trong bảng đơn hàng hay không, và "xuất hiện trong bảng đơn hàng" đồng nghĩa 
-- với "có đặt đơn hàng".

-- 8. Join `fct_order` to `bridge_order_promo` and sum `order_total`. Compare with the plain
--   completed revenue from Q02. **Explain the difference before reading on.** Then compute
--   the promo-attributed revenue *correctly* using `allocation_factor`.
-- navie revenue: sum of order_total for completed orders that have at least one promo code applied.
SELECT SUM(fo.order_total) AS "naive"
FROM fct_order fo
INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
WHERE fo.status = 'completed';

-- correct revenue: sum of order_total for completed orders, correctly allocated to each promo code using allocation_factor.
SELECT SUM(fo.order_total * bop.allocation_factor) AS "total revenue"
FROM fct_order fo
INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
WHERE fo.status = 'completed';
-- cột allocation_factor, cho biết mỗi mã chiếm bao nhiêu % giá trị đơn khi đơn dùng nhiều mã cùng lúc. 
-- Với đơn A (2 mã), mỗi dòng sẽ có allocation_factor = 0.5, cộng lại đúng bằng 1.

SELECT 
    ROUND((SUM(fo.order_total) - SUM(fo.order_total * bop.allocation_factor)) / SUM(fo.order_total * bop.allocation_factor) * 100, 2)
    AS "pct_difference"
    FROM fct_order fo
    INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
    WHERE fo.status = 'completed';

-- 9. Revenue per promo code, correctly allocated, for completed orders. Which code is
--   biggest?
-- doanh thu cho mỗi promo code (nhóm theo promo code), tính với những đơn hàng hoàn thành và xác định mã nào có doanh thu cao nhất
SELECT 
    bop.promo_code, 
    SUM(fo.order_total * bop.allocation_factor) AS "revenue for per promo code"
FROM fct_order fo 
INNER JOIN bridge_order_promo bop ON fo.order_id = bop.order_id
WHERE fo.status = 'completed'
GROUP BY bop.promo_code
ORDER BY SUM(fo.order_total * bop.allocation_factor) DESC;

-- 10. Join `dim_customer` (current rows only) to `raw_customer_list` on `customer_id`. You
--    have 1,200 current customers — how many rows come back? Explain.
SELECT COUNT(*) AS "count customer"
FROM dim_customer dc
LEFT JOIN raw_customer_list rcl ON dc.customer_id = rcl.customer_id
WHERE dc.is_current = 'Y';

SELECT COUNT(*) FROM dim_customer WHERE is_current = 'Y';
-- 1269 rows, from 1200 current customers.
-- raw_customer_list has 69 customer_id values that appear more than once (it's a hand-maintained spreadsheet, 
-- prone to data entry duplicates). Each duplicate causes that customer to match multiple rows in the join,
-- inflating 1200 -> 1269. This is fan-out from a many-side table, same pattern as bridge_order_promo in question 8.

-- 11. For each store: store code, region, completed order count, completed revenue, and the
--    date of its last order. Which store stopped?
SELECT 
    ds.store_code, 
    ds.region, 
    COUNT(*)                AS "completed order count", 
    SUM(fo.order_total)     AS "completed revenue", 
    MAX(fo.ordered_at)      AS "the last order"
FROM fct_order fo
INNER JOIN dim_store ds ON fo.store_sk = ds.store_sk
WHERE fo.status = 'completed'
GROUP BY ds.store_code, ds.region
ORDER BY "the last order";

-- 12. List the 10 customers with the most completed orders: customer id, name, segment, order
--    count, total revenue.
-- liệt kê ra 10 khách hàng có số lượng đơn hàng hoàn thành nhiều nhất và show các thông tin:
-- customer id, name, segment, order count, total revenue.
SELECT 
    dc.customer_id,
    MAX(dc.customer_name)                                   AS "name",
    MAX(CASE WHEN dc.is_current = 'Y' THEN dc.segment END)  AS "segment",
    COUNT(fo.order_id)                                      AS "order count",
    SUM(fo.order_total)                                     AS "total revenue"
FROM dim_customer dc
INNER JOIN fct_order fo ON dc.customer_sk = fo.customer_sk
WHERE fo.status = 'completed'
GROUP BY dc.customer_id
ORDER BY COUNT(order_id) DESC
LIMIT 10;