# Q06 — Window functions

**Est. time:** 4h · **Difficulty:** ⭐⭐⭐⭐ · **Requires:** Q05

## Why this matters

Three of the questions analysts get asked most often — *what changed since last month*,
*what's the top 3 in each category*, *what's the running total* — are painful with joins
and subqueries, and three lines each with window functions.

This is also the assignment where you stop being a beginner. Window functions are the
dividing line between someone who can query a database and someone who can answer questions
with it.

## What you need to know

A window function computes a value **across a set of rows related to the current row**,
without collapsing them. `GROUP BY` gives you one row per group; a window function keeps
every row and adds the group's answer alongside it.

```sql
SELECT category, sku, revenue,
       SUM(revenue)   OVER (PARTITION BY category)                    AS category_total,
       ROW_NUMBER()   OVER (PARTITION BY category ORDER BY revenue DESC) AS rank_in_category
FROM product_revenue;
```

**`PARTITION BY`** is "restart the calculation for each ...". **`ORDER BY`** inside `OVER`
is the order the function walks the rows in — required for anything positional
(`ROW_NUMBER`, `LAG`, running totals) and meaningless for plain `SUM OVER (PARTITION BY x)`.

**The ones you'll actually use:**

| Function | What it gives you |
|---|---|
| `ROW_NUMBER()` | 1, 2, 3 … with no ties. For deduplication and top-N-per-group |
| `RANK()` | ties share a rank and the next rank skips (1, 2, 2, 4) |
| `DENSE_RANK()` | ties share a rank, no skip (1, 2, 2, 3) |
| `LAG(x)` / `LEAD(x)` | the previous / next row's value. Period-on-period comparisons |
| `SUM(x) OVER (ORDER BY ...)` | running total |
| `AVG(x) OVER (ORDER BY ... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` | moving average |
| `NTILE(n)` | splits rows into n buckets — deciles, quartiles |

**Deduplication, the standard idiom.** Number the rows within each key by whatever makes a
row preferable, then keep number 1:

```sql
WITH numbered AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY customer_name) AS rn
  FROM raw_customer_list
)
SELECT * FROM numbered WHERE rn = 1;
```

Note that you cannot filter on a window function in `WHERE` — the window is computed after
`WHERE` runs. That's why the CTE exists. It's the most common error message you'll hit today.

**Frames.** `ROWS BETWEEN ... AND ...` controls how much of the partition the function sees.
The default frame for an ordered aggregate is "everything up to the current row", which is
what makes `SUM() OVER (ORDER BY ...)` a running total. You need explicit frames for moving
averages, and nothing else in this lab.

## Questions

1. List completed orders with a `ROW_NUMBER()` per customer, ordered by order date. Show
   one customer's rows and check the numbering restarts.
2. Deduplicate `raw_customer_list` to one row per `customer_id`. How many rows should you
   end up with, and how many did you drop?
3. The top 3 products by completed revenue **within each category** — category, sku,
   revenue, rank. Compare the effort with your Q05 stretch attempt.
4. Rank customers by total completed revenue. Show the top 10 with their rank. Then swap
   `RANK()` for `DENSE_RANK()` and `ROW_NUMBER()` — do the results differ here, and would
   they if two customers tied?
5. Monthly completed revenue for the whole window, with the previous month's revenue
   alongside it (`LAG`), the change in currency, and the change as a percentage.
6. The same, but year-on-year: each month of 2026 against the same month of 2025. (Hint:
   `LAG(revenue, 12)` over a chronological ordering.)
7. Running total of completed revenue through 2026, by month. What's the figure at the end
   of June?
8. Three-month moving average of monthly completed revenue. Which months does it smooth
   most?
9. Split customers into deciles by total completed revenue (`NTILE(10)`). What share of
   revenue does the top decile account for?
10. For each order, show the customer's *previous* order date and the days between them.
    Then: the average gap between orders per segment.
11. For each category, each product's revenue **and** its share of the category total, on
    the same row. One query, no self-join.
12. Find the largest month-on-month drop in the whole window. Explain it — the answer is
    not a business problem.

## Check yourself

| # | Expected |
|---|---|
| 2 | **1,200** rows kept, **69** dropped |
| 3 | category winners: audio **SKU-0055** · computing **SKU-0016** · home SKU-0047 · outdoor SKU-0048 · wearables SKU-0074 |
| 5 | 2026 MoM: Jan **−39.7%** · Feb −5.8% · Mar +17.7% · Apr +8.3% · May −4.1% · Jun +3.5% |
| 6 | 2026 vs 2025 by month: Jan −2.0% · Feb +5.1% · Mar −7.8% · Apr +2.9% · May −2.5% · Jun +4.1% |
| 7 | running total at end of June 2026: **4,464,733.48** |
| 9 | top decile holds **15.5%** of completed revenue |
| 12 | the biggest drop is **January 2026 at −39.7%**, straight after the December peak — seasonality, not a problem |

Question 12 is the one to think hardest about. A −39.7% month-on-month drop looks alarming
in a dashboard and is completely normal in retail. Notice how much more useful the
year-on-year figure from question 6 is (−2.0%) for answering "is the business shrinking".

## Common beginner mistakes

- `WHERE row_number() = 1` → error. Window functions run after `WHERE`; wrap it in a CTE
  and filter outside.
- `ROW_NUMBER()` with no `ORDER BY` inside `OVER`. The numbering is then arbitrary, so your
  dedup keeps a random row and your results change between runs.
- `PARTITION BY` where you meant `GROUP BY`. If you want one row per category, you want
  `GROUP BY`; if you want every product row plus its category total, you want `PARTITION BY`.
- `RANK()` when you needed exactly one row per group. Ties give you two number-1s and your
  "top product per category" query returns six rows for five categories.
- `LAG` without an `ORDER BY` that matches the meaning of "previous" — over a `year, month`
  result, order by both, not by month.
- `LAG(revenue, 12)` on a series with a missing month: the twelfth row back isn't twelve
  months back. Build the spine first if the series can have gaps.
- `PARTITION BY customer_sk` in question 10 when you meant "per customer." A versioned
  customer has two `customer_sk` values, so partitioning by the surrogate key silently
  starts their order history over at the segment change — their first order after
  changing segments gets `prev_order_date = NULL`, as if it were their very first order
  ever. Partition by `customer_id` instead.
- Comparing month-on-month and reporting it as a trend. See question 12.

## Oracle note

Good news: Oracle has had window functions since 8i and its implementation is excellent —
everything here transfers verbatim, including `ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`,
`LEAD`, `NTILE`, `SUM() OVER` and frame clauses. Oracle also has `FIRST_VALUE`,
`LAST_VALUE`, `RATIO_TO_REPORT` (question 11 in one function) and `LISTAGG` for string
aggregation, all of which analysts in Oracle shops use constantly. `LAG(x, 1, 0)` takes a
default for the first row, which is often nicer than a `COALESCE` afterwards. One
difference to watch: `LAST_VALUE` with the default frame gives the current row, not the
partition's last row — you need
`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`, and that surprises everyone once.

## Stretch

1. Rewrite question 3 for the *bottom* 3 products per category, and include the 9 products
   that never sold. This forces you to think about where the zero rows come from.
2. For each customer, flag their first and last completed order in one query (two window
   functions, one pass).
3. Compute each month's contribution to its year's total, as a percentage, using
   `SUM() OVER (PARTITION BY year)`. Then check the percentages sum to 100 per year — if
   they don't, you have a rounding or a filtering problem, and finding out which is the
   exercise.
4. **Frames beyond the default.** So far every frame has been `ROWS BETWEEN ... AND
   ...`, which counts *rows*, gaps or no gaps. `RANGE BETWEEN INTERVAL 6 DAYS
   PRECEDING AND CURRENT ROW` counts *calendar days* instead — and ST01 has a handful
   of zero-order days across the window, so the two give different answers there. Find
   one of those gap days and show `ROWS` and `RANGE` disagreeing on a 7-day trailing
   count. Then use `EXCLUDE CURRENT ROW` to compare a month against the *average of its
   neighbours*, not including itself. [`reference/advanced_sql.md`](../reference/advanced_sql.md#window-frames-range-vs-rows-and-exclude)
   has both worked examples if you get stuck.
