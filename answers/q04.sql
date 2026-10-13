-- 1. Completed revenue by calendar year. Why is 2026 so much lower? (Look at `dim_date`
-- before you answer.)
   SELECT 
        dd.year, 
        SUM(fo.order_total) AS "completed revenue"
   FROM fct_order fo
   INNER JOIN dim_date dd ON fo.date_key = dd.date_key
   WHERE fo.status = 'completed'
   GROUP BY dd.year;
-- The reason 2026 is so much lower is because the data of 2026 only covers the firrst half of the year (January to June).

-- 2. Completed revenue by year and month, ordered chronologically. Which month is the
--   highest?
    SELECT 
        dd.year,
        dd.month,
        SUM(fo.order_total) AS "completed revenue"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.year, dd.month
    ORDER BY dd.year, dd.month;
-- The highest month is December 2025, with a completed revenue of 1 123 529.39

-- 3. Completed revenue for 2025 H1 versus 2026 H1. Is the business growing?
-- H1: first half of the year (January to June)
-- H1 2025:
    SELECT 
        dd.year,
        SUM(fo.order_total)     AS "completed revenue H1 2025"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE 
    fo.status = 'completed'
    AND dd.date_key >= 20250101 AND dd.date_key <= 20250630
    GROUP BY dd.year;

-- H1 2026:
    SELECT 
        dd.year,
        SUM(fo.order_total)     AS "completed revenue H1 2026"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE 
    fo.status = 'completed'
    AND dd.date_key >= 20260101 AND dd.date_key <= 20260630
    GROUP BY dd.year;

-- H1 2025 vs H1 2026:
    SELECT
        CASE WHEN dd.date_key >= 20250101 AND dd.date_key <= 20250630 THEN 'H1 2025'
             WHEN dd.date_key >= 20260101 AND dd.date_key <= 20260630 THEN 'H1 2026'
        END AS "half year",
        SUM(fo.order_total) AS "completed revenue"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE 
    fo.status = 'completed'
    GROUP BY "half year";
-- H1 2025: 4,476,125.75 | H1 2026: 4,464,733.48
-- Is the business growing? No, essentially flat — revenue is down about 0.3%,
-- a change small enough to be noise rather than a real trend.

-- 4. Completed revenue by quarter, with the year, for the whole window.
    SELECT 
        dd.quarter, 
        dd.year, 
        SUM(fo.order_total) AS "completed revenue"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.year, dd.quarter
    ORDER BY dd.year, dd.quarter;

-- 5. Completed revenue by fiscal year. How many days of each fiscal year does the data
--    actually cover, and what does that do to the comparison?
    SELECT  
        dd.fiscal_year, 
        SUM(fo.order_total) AS "completed revenue"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.fiscal_year
    ORDER BY dd.fiscal_year;

    SELECT 
        dd.fiscal_year, 
        COUNT(DISTINCT dd.date_key) AS "number of days covered"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.fiscal_year
    ORDER BY dd.fiscal_year;
-- the data covers 181 days of fiscal year 2025 and 365 days of fiscal year 2026. 
-- This means that the comparison of completed revenue between the two fiscal years is not fair, as fiscal year 2025 
-- only has half the number of days compared to fiscal year 2026.

-- 6. Completed revenue for December 2025. How does it compare with the average month across
--    the whole window?
    SELECT 
        dd.year, 
        dd.month, 
        SUM(fo.order_total) AS "completed revenue of December 2025"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    AND dd.year = 2025
    AND dd.month = 12
    GROUP BY dd.year, dd.month;

    SELECT AVG(monthly_revenue) AS "average monthly revenue" FROM(
        SELECT 
        dd.year,
        dd.month, 
        SUM(fo.order_total) AS monthly_revenue
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY dd.month, dd.year
    );

-- 7. What share of completed revenue happens at the weekend?
    SELECT 
        SUM(CASE WHEN dd.is_weekend = 'Y' THEN fo.order_total END)
        /
        SUM(fo.order_total) * 100 AS "weekend revenue share %"
    FROM fct_order fo 
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed';

-- 8. Which day of the week has the highest average revenue *per day*? (Careful: there are
--    more of some weekdays than others in the window — divide by the number of days, don't
--    just sum.)
    SELECT 
        dd.day_name, 
        ROUND(SUM(fo.order_total) / COUNT(DISTINCT dd.date_key),2) AS "average revenue per day"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    GROUP BY day_name
    ORDER BY "average revenue per day" DESC;

-- 9. How many public holidays are in `dim_date`? List them. Then: is revenue on a holiday
--    higher or lower than on a comparable non-holiday? Say why your comparison is or isn't
--    fair.
-- How many?
    SELECT COUNT(DISTINCT date_key) AS "number of public holidays" 
    FROM dim_date
    WHERE is_holiday = 'Y';

-- List them.
    SELECT DISTINCT date_key AS "public holiday dates"
    FROM dim_date
    WHERE is_holiday = 'Y';

-- the revenue on publc holidays. -- 10 days
    SELECT SUM(fo.order_total) / COUNT(DISTINCT dd.date_key) AS "completed revenue on public holidays" 
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    AND dd.is_holiday = 'Y'; 
-- nếu muốn xem doanh thu theo ngày thì nên chia tổng doanh thu cho tổng số ngày, để có được trung bình ngày đúng nhất.
-- nếu chỉ SUM đơn giản rồi so sánh thì sẽ không chính xác vì số ngày lễ ít hơn số ngày thường, nên doanh thu trung bình
-- trên mỗi ngày lễ sẽ cao hơn.   
-- the revenue on non-public holidays. -- 536 days 
    SELECT SUM(fo.order_total) / COUNT(DISTINCT dd.date_key) AS "completed revenue on non-public holidays"
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed'
    AND dd.is_holiday = 'N'; 
-- the revenue on pubic holidays is higher than on non-public holidays. 

-- 10. Orders placed on 2025-12-24 — count and revenue. Write the filter three ways
--    (`date_key`, `dim_date.full_date`, and a half-open range on `ordered_at`) and confirm
--    all three agree.
-- date_key filter:
    SELECT 
        COUNT(*)                AS "number of orders",
        SUM(fo.order_total)     AS "total revenue"
    FROM fct_order fo
    LEFT JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE dd.date_key = 20251224;

-- dim_date.full_date filter:
    SELECT 
        COUNT(*)                AS "number of orders",
        SUM(fo.order_total)     AS "total revenue"
    FROM fct_order fo
    LEFT JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE dd.full_date = '2025-12-24';

-- half-open range on ordered_at filter:
    SELECT 
        COUNT(*)                AS "number of orders",
        SUM(fo.order_total)     AS "total revenue"
    FROM fct_order fo
    LEFT JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.ordered_at >= '2025-12-24 00:00:00' 
    AND fo.ordered_at < '2025-12-25 00:00:00';

-- 11. Which months had completed revenue below 700,000? Is there a pattern?
SELECT 
    dd.month, 
    dd.year,
    SUM(fo.order_total) AS "completed revenue"
FROM fct_order fo
INNER JOIN dim_date dd ON fo.date_key = dd.date_key
WHERE fo.status = 'completed'  
GROUP BY dd.month, dd.year
HAVING SUM(fo.order_total) < 700000
ORDER BY dd.month, dd.year;
-- There are 4 months with completed revenue below 700,000. January 2025 and January 2026, February 2025 and February 2026.

-- 12. For each month of 2026, revenue and the change versus the previous month, in currency
--    and as a percentage. (You can do this with a self-join now, or wait for `LAG` in Q06 —
--    try the self-join, then compare.) 
WITH monthly AS (
    SELECT dd.month, dd.year, SUM(fo.order_total) AS revenue
    FROM fct_order fo
    INNER JOIN dim_date dd ON fo.date_key = dd.date_key
    WHERE fo.status = 'completed' AND dd.year = 2026
    GROUP BY dd.month, dd.year
)
SELECT 
    m1.month, 
    m1.revenue, 
    (m1.revenue - m2.revenue) AS "change in currency", 
    ROUND((m1.revenue - m2.revenue) / m2.revenue * 100, 2) AS "change in percentage"
FROM monthly m1
LEFT JOIN monthly m2 ON m2.month = m1.month - 1
ORDER BY m1.month;