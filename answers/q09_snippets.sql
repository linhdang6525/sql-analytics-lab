-- 1. TOP-N PER GROUP
-- Use when retrieving the top N records within each group.
-- Example: Find the top 3 products by revenue in each category.

WITH ranked_products AS (
    SELECT
        category,
        product_name,
        revenue,
        -- Restart ranking for each category, from highest to lowest revenue.
        ROW_NUMBER() OVER (
            PARTITION BY category
            ORDER BY revenue DESC
        ) AS rn
    FROM product_revenue
)
SELECT
    category,
    product_name,
    revenue
FROM ranked_products
-- Keep only the first three products in each category.
WHERE rn <= 3;


-- 2. MONTH-OVER-MONTH COMPARISON WITH LAG
-- Use when comparing each month's value with the previous month's value.

WITH monthly_revenue AS (
    SELECT
        year,
        month,
        -- Aggregate revenue to one row per month.
        SUM(order_total) AS current_revenue
    FROM completed_orders
    GROUP BY year, month
)
SELECT
    year,
    month,
    current_revenue,
    -- Retrieve the revenue from the previous month.
    LAG(current_revenue) OVER (
        ORDER BY year, month
    ) AS previous_month_revenue
FROM monthly_revenue;


-- 3. DEDUPLICATION WITH ROW_NUMBER
-- Use when keeping one preferred record per business key.
-- Example: Keep the latest record for each customer.

WITH ranked_customers AS (
    SELECT
        *,
        -- Assign rank 1 to the most recently updated record per customer.
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY updated_at DESC
        ) AS rn
    FROM raw_customers
)
SELECT *
FROM ranked_customers
-- Retain only the preferred record for each customer.
WHERE rn = 1;


-- 4. ANTI-JOIN WITH NOT EXISTS
-- Use when finding records that have no matching record in another table.
-- Example: Find customers who have never placed an order.

SELECT
    c.customer_id
FROM customers AS c
WHERE NOT EXISTS (
    -- Return TRUE when no matching order exists for this customer.
    SELECT 1
    FROM orders AS o
    WHERE o.customer_id = c.customer_id
);


-- 5. HALF-OPEN DATE RANGE
-- Use when filtering a time period without including the next period's boundary.
-- Example: Retrieve all records from January 2026, including timestamps.

SELECT
    order_id,
    order_total
FROM orders
WHERE order_date >= DATE '2026-01-01' -- Include the start date.
  AND order_date <  DATE '2026-02-01'; -- Exclude the next period's start.


-- 6. SAFE DISTINCT COUNT
-- Use when counting unique entities instead of total rows.

SELECT
    -- Count each non-NULL customer ID only once.
    COUNT(DISTINCT customer_id) AS distinct_customer_count
FROM orders;


-- 7. UNION ALL AUDIT ROWS
-- Use when comparing summary results from multiple sources.
-- Example: Compare row counts between a source and a target table.

SELECT
    'source' AS record_type,
    COUNT(*) AS row_count
FROM source_table

UNION ALL

SELECT
    'target' AS record_type,
    COUNT(*) AS row_count
FROM target_table;

-- UNION ALL appends rows and preserves duplicates.
-- Both queries must return compatible columns.


-- 8. EXCEPT-BASED EQUIVALENCE CHECK
-- Use when checking for differences between two query results.

(
    -- Find rows present in the source but missing from the target.
    SELECT customer_id, order_total
    FROM source_table

    EXCEPT

    SELECT customer_id, order_total
    FROM target_table
)
UNION ALL
(
    -- Find rows present in the target but missing from the source.
    SELECT customer_id, order_total
    FROM target_table

    EXCEPT

    SELECT customer_id, order_total
    FROM source_table
);

-- An empty result indicates set equivalence for the selected columns.
-- EXCEPT removes duplicates, so it does not validate duplicate counts.


-- 9. SAFE RATIO WITH NULLIF
-- Use when the denominator might be zero.

SELECT
    -- Return NULL when order_count is zero to avoid division by zero.
    revenue / NULLIF(order_count, 0) AS revenue_per_order
FROM revenue_summary;


-- 10. TOP-N WITH RANK
-- Use when tied values should share the same rank.
-- Unlike ROW_NUMBER, this pattern may return more than N rows.

WITH ranked_stores AS (
    SELECT
        store_id,
        revenue,
        -- Assign the same rank to stores with equal revenue.
        RANK() OVER (
            ORDER BY revenue DESC
        ) AS revenue_rank
    FROM store_revenue
)
SELECT
    store_id,
    revenue
FROM ranked_stores
-- Include all stores whose rank is within the top three.
WHERE revenue_rank <= 3;


-- Note: Table and column names are illustrative placeholders.
-- Replace them with actual lab tables and columns before execution.