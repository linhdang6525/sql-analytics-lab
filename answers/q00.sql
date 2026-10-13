-- 1. How many tables are in the database, and what are they called?
    SHOW TABLES; 

-- 2. How many rows are in each of the nine tables?
    SELECT 'bridge_order_promo' AS table_name, COUNT(*) AS row_count FROM bridge_order_promo
    UNION ALL SELECT 'dim_customer' AS table_name, COUNT(*) AS row_count FROM dim_customer
    UNION ALL SELECT 'dim_date' AS table_name, COUNT(*) AS row_count FROM dim_date
    UNION ALL SELECT 'dim_product' AS table_name, COUNT(*) AS row_count FROM dim_product
    UNION ALL SELECT 'dim_store' AS table_name, COUNT(*) AS row_count FROM dim_store
    UNION ALL SELECT 'fct_order' AS table_name, COUNT(*) AS row_count FROM fct_order
    UNION ALL SELECT 'fct_order_item' AS table_name, COUNT(*) AS row_count FROM fct_order_item
    UNION ALL SELECT 'dim_promo' AS table_name, COUNT(*) AS row_count FROM dim_promo
    UNION ALL SELECT 'raw_customer_list' AS table_name, COUNT(*) AS row_count FROM raw_customer_list;

-- 3. What columns does `fct_order` have, and what type is each one?
    DESCRIBE fct_order;

-- 4. Show the first 10 rows of `fct_order`. Then the first 10 *ordered by* `order_total`, largest first.
    SELECT * FROM fct_order ORDER BY order_id LIMIT 10; -- the first 10 rows of 'fct_order'
    SELECT * FROM fct_order  ORDER BY order_total DESC LIMIT 10; -- the first 10 rows of 'fct_order' ordered by 'order_total', largest first.

-- 5. What are the earliest and latest dates in `dim_date`? How many days is that?
    SELECT MAX (full_date) AS "the latest date" FROM dim_date;
    SELECT MIN (full_date) AS "the earliest date" FROM dim_date;
    SELECT DATEDIFF('d', MIN(full_date), MAX(full_date)) AS "The number of days between the earliest day and the latest day"
    FROM dim_date;


-- 6. What distinct values appear in `fct_order.status`? In `fct_order.channel`?
SELECT DISTINCT status FROM fct_order;
SELECT DISTINCT channel FROM fct_order;

-- 7. How many distinct `customer_id` values are in `dim_customer`? How many rows does the
--    table have? **They are not the same number — write down your best guess as to why.**
SELECT COUNT(DISTINCT(customer_id)) AS distinct_customer_count FROM dim_customer; 
SELECT COUNT(*) AS total_row_count FROM dim_customer; 
-- dim_customer stores one row per customer version, not per customer.
-- A customer who changed segment gets a new row instead of overwriting the old one

-- 8. Pick one order id. Show that order, then its lines from `fct_order_item`, then its promo
--    codes from `bridge_order_promo`. How many rows in each?
-- Show all information about the order with order_id = 'O0000596'.
SELECT * FROM fct_order WHERE order_id = 'O0000596';
SELECT * FROM fct_order_item WHERE order_id = 'O0000596';
SELECT * FROM bridge_order_promo WHERE order_id = 'O0000596';

-- Count the number of rows in each table for the order with order_id = 'O0000596'.
SELECT COUNT(*) AS row_count FROM fct_order WHERE order_id = 'O0000596'
UNION ALL SELECT COUNT(*) AS row_count FROM fct_order_item WHERE order_id = 'O0000596'
UNION ALL SELECT COUNT(*) AS row_count FROM bridge_order_promo WHERE order_id = 'O0000596';


-- 9. `SUMMARIZE fct_order_item;` — read the output. What's the largest `quantity` anyone
--    ordered? Now do the same for `fct_order` — which column(s) have NULLs there, and
--    roughly what share of rows?
SUMMARIZE fct_order_item; -- The largest quantity anyone ordered is 5. No columns in fct_order_item have NULLs.
SUMMARIZE fct_order;
SELECT 
    COUNT(*) - COUNT(customer_sk)     AS customer_sk_null_count,
    COUNT(*) - COUNT(discount_amount) AS discount_amount_null_count,
    COUNT(*)                          AS total_rows
FROM fct_order;
-- The columns with NULLs in "fct_order" are: customer_sk, discount_amount.
-- The share of rows with NULLs in customer_sk is 1.52%, and the share of rows with NULLs in discount_amount is 4.07%.

-- 10. Which columns would you use to join fct_order to dim_customer, dim_store and dim_date?
--     Write the join conditions down without running them yet.

-- fct_order.customer_sk  → dim_customer.customer_sk
-- fct_order.store_sk     → dim_store.store_sk
-- fct_order.date_key     → dim_date.date_key

-- Join conditions:
-- fct_order.customer_sk = dim_customer.customer_sk
-- AND fct_order.store_sk = dim_store.store_sk
-- AND fct_order.date_key = dim_date.date_key

-- Cách hoạt động của Surrogate Key (khóa thay thế / khóa nhân tạo)
-- Ngày 2024-03-15: Đơn O100 được tạo
--  → ETL tra dim_customer, thấy C0019 đang có customer_sk=12 (is_current=Y)
--  → Gán fct_order.customer_sk = 12 cho đơn O100
--  → Ghi vào fct_order, XONG, không đổi nữa.

-- Ngày 2025-06-01: Khách C0019 đổi segment
--  → dim_customer: đóng dòng customer_sk=12 (is_current=N)
--  → dim_customer: thêm dòng mới customer_sk=15 (is_current=Y)
--  → fct_order KHÔNG bị đụng vào gì cả — O100 vẫn giữ customer_sk=12

-- Ngày 2025-08-20: Đơn O200 được tạo
--  → ETL tra dim_customer, thấy C0019 hiện đang có customer_sk=15 (is_current=Y)
--  → Gán fct_order.customer_sk = 15 cho đơn O200
