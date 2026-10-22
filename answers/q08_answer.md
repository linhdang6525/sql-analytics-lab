
Q08 — Real Questions: Answers

1. Dana (COO): Is the business growing?
Restated question: Is completed-order revenue in H1 2026 higher or lower than in the same six-month period of 2025?

Metric definition: SUM(fct_order.order_total) for orders with status = 'completed', comparing 1 January–30 June 2025 with 1 January–30 June 2026. Non-completed orders are excluded.

Query: 
```
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
```

Number: H1 2025 = 4,476,125.75; H1 2026 = 4,464,733.48; change = −0.25% (approximately −0.3%).

Meaning: Completed revenue was essentially flat year over year in the first half, with a very small decline.

Caveat: This measures revenue, not profit or the overall health of the business. Comparing all of calendar 2025 with only H1 2026 is misleading because the periods have different lengths.

2. Marc (CFO): What was our revenue last year?
Restated question: What was completed-order revenue for calendar year 2025, from 1 January through 31 December?

Metric definition: SUM(fct_order.order_total) for status = 'completed' with order date in calendar 2025. Non-completed orders are excluded.

Query: 
```
    SELECT 
        dd.year,
        SUM(fo.order_total) AS 'last year revenue'
    FROM dim_date dd 
    INNER JOIN fct_order fo ON dd.date_key = fo.date_key
    WHERE fo.status = 'completed' AND dd.year = '2025'
    GROUP BY dd.year;
```
Number: 9,736,875.65 for calendar 2025.

Meaning: This is the completed revenue recorded for the full 2025 calendar-year window in the dataset.

Caveat: Do not compare this full-year figure directly with the first six months of 2026 as if both periods were a full year. The lab notes that its fiscal-year 2025 window covers only 181 days; it is not the same as calendar 2025.

3. Ingrid (Head of Retail): Which store is our worst performer?
Restated question: Which store has the lowest completed revenue per active trading day over the analysis window, and does total revenue tell the same story?

Metric definition: First compare total order_total for completed orders by store. Then divide by the store's active days, using its opening date through closing date, or through 30 June 2026 if no closing date is recorded.

Query: 
```
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
```
Number: By total revenue, ST09 (Store 9) ranks last at 767,215.57. It closed on 28 February 2026 and was active for 848 calendar days according to the current query, giving revenue per active day of 904.74. By revenue per active day, ST13 ranks lowest at 347.26, followed by ST08 at 348.30.

Meaning: ST09 has the lowest total revenue partly because it operated for a shorter period, but it is not the weakest store when performance is measured by revenue per active day. ST13 has the lowest daily revenue among the stores in the query output.

Caveat: Revenue per active day does not account for store size, staffing, local market conditions, or whether the store traded every calendar day. The current query's day-count convention should also be checked before using the figures for a closure decision.

4. Femi (Marketing): Which promo code drove the most revenue?
Restated question: Which promotion receives the largest share of completed order revenue when orders linked to multiple promotions are allocated using the recorded allocation factors?

Metric definition: Sum order_total * allocation_factor by promo code for completed orders, using bridge_order_promo to allocate revenue rather than counting an entire order under every linked promotion.

Query: 
```
    SELECT 
        dpr.promo_code,
        ROUND(SUM(fo.order_total * bop.allocation_factor), 2) AS rev_by_promo_code
    FROM dim_promo dpr 
    INNER JOIN bridge_order_promo bop ON dpr.promo_code = bop.promo_code
    INNER JOIN fct_order fo ON bop.order_id = fo.order_id 
    WHERE fo.status = 'completed'
    GROUP BY dpr.promo_code
    ORDER BY rev_by_promo_code DESC;
```
Number: BUNDLE15: 494,884.03 allocated revenue; FREESHIP: 489,954.52; SPRING10: 487,095.21.

Meaning: BUNDLE15 has the highest allocated revenue among the listed promotion codes.

Caveat: “Drove” cannot be interpreted as causal impact from these tables alone. Allocated revenue is associated with a promo code; it does not prove that the promotion caused incremental sales. A non-allocated join would overstate the attributed amount (the key says by about 34%).

5. Sara (Merchandising): Which category makes us the most money?
Restated question: Which category has the highest total sales revenue, and which has the highest gross margin percentage?

Metric definition: Revenue is SUM(fct_order_item.line_amount) for items in completed orders, grouped by product category. Gross margin percentage is (revenue - estimated product cost) / revenue, where estimated product cost is SUM(quantity * unit_cost).

Query: 
```
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
```
Number: Highest revenue: Computing, 4,016,974.03. Highest margin: Outdoor, 44.27% (about 44.3%); Computing is 42.4%.

Meaning: Computing brings in the most sales dollars, while Outdoor keeps a higher percentage of its revenue after estimated product cost.

Caveat: This margin is not full net profit: it may exclude operating costs, labour, shipping, discounts, and other costs not represented by unit_cost.

6. Tomas (Customer Service): How bad are returns? Is it getting worse?
Restated question: What share of line revenue is associated with returned orders, and does the quarterly pattern show a sustained increase?

Metric definition: Returned line revenue divided by total line revenue, grouped by the order date's year and quarter. This uses fct_order.status = 'returned' to identify returned orders.

Query: 
```
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
```
Number: Returned line revenue = 605,959.72, equal to 3.41% of line revenue. Across the observed quarters, the order-based return rate fluctuated between 4.77% and 5.34% in the working analysis.

Meaning: Returns are a measurable cost.

Caveat: The date is the order date, not necessarily the date the return was processed. Month-to-month or quarter-to-quarter changes can reflect mix and timing; a proper year-on-year comparison of equivalent quarters is stronger evidence before claiming the problem is getting worse. The 3.41% line-revenue metric and the 4.77%–5.34% order-count rates are different metrics and should not be presented as if they were the same measure.

7. Sven (Sales): Which customers have stopped buying?
Restated question: Which customers had at least one completed order in calendar 2025 but no completed order in calendar 2026?

Metric definition: Count distinct customers with at least one completed order in 2025 and no completed orders in 2026.

Query: 
```
    WITH 
    completed_25 AS (
        SELECT DISTINCT dc.custdiscounted_orderomer_sk
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
```
Number: 76 customers ordered in 2025 but had no completed orders in 2026. The lab key separately reports 40 customers who have never ordered.

Meaning: The query identifies 76 customers who may need follow-up, but it does not prove they have permanently stopped buying.

Caveat: The 2026 data is incomplete, and the 40 customers who never ordered are a different group. The query result (76) does not match the lab key (0), so the discrepancy should be checked before reporting to Sven.

8. Nadia (Finance): How much did we give away in discounts?
Restated question: What discount amount was recorded on completed orders in calendar 2025, and what evidence indicates that this total is understated?

Metric definition: Recorded discount is SUM(fct_order.discount_amount) for completed orders dated in calendar 2025. SUM ignores NULL values. A NULL discount amount is not automatically proof that a discount was applied.

Query: 
```
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
```
Number: The answer key says recorded discounts for completed orders in calendar 2025 total 710,532.11, equal to 4.76% of gross, and 1,147 orders had a discount applied but the amount was recorded as NULL. The current local query instead returns recorded discounts of 491,678.94, with 1,275 completed orders having discount_amount IS NULL; an inferred formula estimates 22,312.40 missing and a total of 513,991.34. These local figures do not match the answer key and must not be reported as final.

Meaning: The recorded total may understate the actual discount given because some orders known to have received a discount have no recorded discount amount. The answer key does not provide a verified monetary adjustment for those missing amounts.

Caveat: Do not assume every NULL row had a discount applied. Do not treat gross_amount - order_total + shipping_fee as a confirmed discount formula until it is validated against rows with known discount amounts and the order-total definition. The discrepancy between the local output and the answer key must be resolved before giving Finance a final adjusted number.

Stretch: two clarification messages
For Dana (growth): “When you say ‘growing,’ would you like me to compare completed revenue for H1 2026 with H1 2025, or compare rolling 12-month revenue? I recommend equal six-month periods for a clean year-on-year comparison, and I can add rolling 12 months as a second view.”

For Ingrid (worst store): “Should ‘worst performer’ mean lowest total revenue or lowest revenue per active trading day? I recommend looking at both, then normalising for store size or staffing before making a closure decision.”

Stretch: rolling 12 months
A rolling-12-month comparison should use the latest complete 12-month window and the immediately preceding 12-month window, with the same completed-order filter and metric. The supplied figures do not include a computed rolling-12-month result, so no number or conclusion is claimed here.

Stretch: return trend
The supplied analysis supports saying that the observed order-based quarterly return rate fluctuated between 4.77% and 5.34%, without a consistent rise. Before saying returns are worsening, I would want equivalent-quarter year-on-year rates and the actual return-processing date. A sustained increase over several comparable quarters, using the same denominator and definition, would change that assessment.

Stretch: store-by-month grid
The store-month PIVOT/UNPIVOT exercise is not executed in this answer document because the precise month columns and the lab's reference/advanced_sql.md syntax were not included in the supplied text. Implement it against the local schema, then confirm that the unpivoted row count and store-month keys match the pre-pivot result.

