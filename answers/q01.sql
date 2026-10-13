-- 1. How many orders have status `completed`? 
SELECT COUNT(*) AS completed_order_count FROM fct_order WHERE status = 'completed';

-- 2. How many completed orders have an `order_total` over 1,000?
SELECT COUNT(*) AS completed_order_count_over_1000 FROM fct_order WHERE status ='completed' AND order_total > 1000;

-- 3. How many orders were placed through the `web` or `app` channel? Write it with `IN`.
 SELECT COUNT(*) AS order_count_placed_on_the_web_or_app FROM fct_order WHERE channel IN('app', 'web'); 
-- IN is more readable and easier to maintain than a chain of OR conditions, especially with many values to check against.

-- 4. How many orders have `discount_amount` greater than zero? How many have exactly zero?
--    Add those two numbers together and compare with the total row count of `fct_order`.
--    **Explain the gap** — this is the whole point of the question.
SELECT 
    COUNT(CASE WHEN discount_amount > 0 THEN 1 END) AS orders_with_discount, 
    COUNT(CASE WHEN discount_amount = 0 THEN 1 END) AS orders_without_discount,
    COUNT (*) AS total_orders
FROM fct_order;
-- Explain the gap: The sum of orders with discount and orders without discount may not equal the total number of orders 
-- because there could be orders with NULL values in the `discount_amount` column, which are not counted in either category.

-- 5. How many rows in `dim_customer` have no city recorded? How many have no email?
SELECT 
    COUNT(CASE WHEN city IS NULL THEN 1 END) AS customers_without_city,
    COUNT(CASE WHEN email IS NULL THEN 1 END) AS customers_without_email
FROM dim_customer;

-- 6. Write a filter that finds customers with no city, then run the same query with
--    `WHERE city = NULL` instead. Explain the difference in one sentence.
SELECT * FROM dim_customer WHERE city IS NULL;
SELECT COUNT(*) FROM dim_customer WHERE city IS NULL;

SELECT * FROM dim_customer WHERE city = NULL;
-- city IS NULL checks for the absence of data and returns the missing rows, while city = NULL fails and returns zero rows 
--because NULL represents an unknown state rather than a concrete value to compare with =.

-- 7. How many current (`is_current = 'Y'`) customers are in the `enterprise` segment in
--    Germany (`country_code = 'DE'`)?
SELECT COUNT(*) FROM dim_customer WHERE is_current = 'Y' AND segment = 'enterprise' AND country_code = 'DE';

-- 8. List the 10 largest completed orders: order id, total, status, channel. Highest first.
SELECT order_id, order_total, status, channel FROM fct_order WHERE status = 'completed' ORDER BY order_total DESC LIMIT 10;

-- 9. How many products have `Laptop` in their name? How many are discontinued?
-- Laptop in name:
SELECT COUNT(*) FROM dim_product WHERE product_name LIKE '%Laptop%'; 
-- Discontinued products:
SELECT COUNT(*) FROM dim_product WHERE is_discontinued = 'Y';

-- 10. Find all orders placed on 2025-12-24. (`fct_order` has `date_key` as an integer like
--     `20251224`, and `ordered_at` as a timestamp — try both, and note which is easier.)
SELECT * FROM fct_order WHERE date_key = 20251224; -- date_key

SELECT * FROM fct_order -- ordered_at
WHERE ordered_at >= '2025-12-24'
  AND ordered_at < '2025-12-25';

-- 11. Which orders have no customer attached at all? How many are there, and what do you think they are?
SELECT * FROM fct_order WHERE customer_sk IS NULL;
SELECT COUNT (*) AS order_without_customer FROM fct_order WHERE customer_sk IS NULL; 
-- There are 840 orders do not have customer information, because they are maybe guest orders
-- buying products without accessing an account.
 
SELECT status, COUNT(*) FROM fct_order WHERE customer_sk IS NULL GROUP BY status;
--Most (704/840) are status = completed, not cancelled/broken,likely guest orders — customers who checked out without logging into an account.
-- If it were a data issue, we'd expect more of these to be cancelled/pending, not completed.

--12. List every distinct combination of `channel` and `status`. How many rows do you get,
--  and what would you have expected?

SELECT DISTINCT channel, status FROM fct_order ORDER BY channel, status;
SELECT COUNT(*) AS distinct_combination FROM (SELECT DISTINCT channel, status FROM fct_order);
-- 4 status x 4 channel = 16 combinations max (if every status appears in every channel)