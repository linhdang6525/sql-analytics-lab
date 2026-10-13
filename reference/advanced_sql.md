# Advanced SQL toolkit

Everything in the main course (Q00–Q09) is what you'll use in nine requests out of
ten. This page is the other one in ten: features that don't get their own assignment
but show up often enough at work to be worth meeting once, deliberately, against data
you already understand.

Nothing here is required for any Definition of Done. Each section says which
assignment's **Stretch** goals put it to use — do those once you've finished that
assignment's numbered questions, not before. The pattern throughout the lab holds
here too: get it working, then check your result against a second, independent way of
computing the same thing.

DuckDB reference: [SQL introduction](https://duckdb.org/docs/sql/introduction) ·
[Function overview](https://duckdb.org/docs/sql/functions/overview) ·
[Window functions](https://duckdb.org/docs/sql/window_functions) ·
[PIVOT](https://duckdb.org/docs/sql/statements/pivot) ·
[Set operations](https://duckdb.org/docs/sql/query_syntax/setops)

---

## PIVOT and UNPIVOT — rows to columns and back

**Used in:** [Q08 stretch](../assignments/Q08_business_questions.md).

Every query so far has produced a *long* table: one row per (group, group, ...).
People reading a report often want a *wide* one instead — one row per store, one
column per month — because that's the shape a human scans fastest.

```sql
-- long: one row per (store, month)
WITH store_month AS (
    SELECT s.store_code, d.month, sum(o.order_total) AS revenue
    FROM fct_order o
    JOIN dim_store s ON s.store_sk = o.store_sk
    JOIN dim_date d ON d.date_key = o.date_key
    WHERE o.status = 'completed' AND d.year = 2026
    GROUP BY s.store_code, d.month
)
-- wide: one row per store, one column per month
PIVOT store_month ON month USING sum(revenue)
ORDER BY store_code;
```

`PIVOT` needs three things: the table (or CTE) to reshape, which column's *distinct
values* become new column headers (`ON month`), and how to fill each cell when more
than one row could land there (`USING sum(revenue)` — here there's exactly one row per
store/month already, but the aggregate is still required syntax).

`UNPIVOT` does the reverse — turn columns back into rows, which is how you'd get a
wide report (built by someone else, or by you a week ago) back into a shape you can
`GROUP BY` again:

```sql
UNPIVOT wide_store_month
ON COLUMNS(* EXCLUDE (store_code))
INTO NAME month VALUE revenue;
```

**The self-check this lab always asks for:** pivot a result, then unpivot it, and
confirm you get back exactly the rows (same count, same values) you started with. If
you don't, the `USING` aggregate in your `PIVOT` was silently combining rows you
didn't mean to combine.

**Caution:** a report a stakeholder can read at a glance is *not* the same table you
should compute further metrics from. Keep the long form as your source of truth;
pivot only at the last step, for presentation.

---

## Window frames: `RANGE` vs `ROWS`, and `EXCLUDE`

**Used in:** [Q06 stretch](../assignments/Q06_windows.md).

Q06's moving average used `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` — "the two rows
before this one, whatever dates they happen to fall on." `RANGE` instead means "rows
within this many units of the *current row's value* on the `ORDER BY` column" — for a
date column, that's calendar days, gaps and all. They agree only when there are no
gaps in the series.

ST01 is missing a handful of trading days across the window (a day with zero
completed orders isn't a data error — it happens). Around one of those gaps:

```sql
WITH st01_daily AS (
    SELECT d.full_date, sum(o.order_total) AS revenue
    FROM fct_order o
    JOIN dim_store s ON s.store_sk = o.store_sk
    JOIN dim_date d ON d.date_key = o.date_key
    WHERE o.status = 'completed' AND s.store_code = 'ST01'
    GROUP BY d.full_date
)
SELECT full_date, revenue,
       count(*) OVER (ORDER BY full_date
                       RANGE BETWEEN INTERVAL 6 DAYS PRECEDING AND CURRENT ROW) AS n_range,
       count(*) OVER (ORDER BY full_date
                       ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS n_rows
FROM st01_daily
WHERE full_date BETWEEN DATE '2025-02-13' AND DATE '2025-02-20'
ORDER BY full_date;
```

On 2025-02-20, `n_range` is 6 (only 6 calendar dates actually fall in the trailing
7-day window, because 2025-02-16 has no row) while `n_rows` is 7 (it always grabs the
6 preceding *rows*, reaching back an extra day to compensate for the gap). A "7-day
trailing average" built with `ROWS` on a series with gaps is quietly averaging more
than 7 calendar days of history. `RANGE` is the one that means what it says.

`EXCLUDE` narrows the frame further — useful when you want a row compared against its
*neighbours*, not against itself:

```sql
-- each month vs the average of the two months either side of it, excluding itself
SELECT year, month, revenue,
       avg(revenue) OVER (ORDER BY year, month
                           ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
                           EXCLUDE CURRENT ROW) AS avg_of_neighbors
FROM monthly_revenue;
```

`EXCLUDE CURRENT ROW` / `EXCLUDE TIES` / `EXCLUDE GROUP` control whether the current
row (or its ties, under `RANK`-style ordering) count toward the frame. Without
`EXCLUDE`, "how does this month compare to the months around it" always includes the
month being compared, which pulls the answer toward "no difference" by construction.

---

## Set operations: `UNION ALL`, `UNION`, `EXCEPT`, `INTERSECT`

**Used in:** [Q07 stretch](../assignments/Q07_traps.md) and
[Q09 stretch](../assignments/Q09_presenting.md).

These combine or compare two result sets that have the same number of columns, in the
same order, with compatible types. They don't need a shared key the way a `JOIN` does
— they work on rows, not on columns matched by name.

| Operator | Keeps |
|---|---|
| `UNION ALL` | every row from both sides, duplicates included |
| `UNION` | every row from both sides, duplicates removed (slower — it has to sort/hash to dedup) |
| `INTERSECT` | rows present in **both** sides |
| `EXCEPT` | rows in the first side with **no match** in the second (Oracle calls this `MINUS`) |

**Building one audit result from several unrelated queries** (Q07's "all four wrong
numbers side by side" stretch is exactly this — always use `UNION ALL` here, never
plain `UNION`, since there's no reason to deduplicate metric rows and `UNION` would
silently collapse two metrics that happened to produce the same number):

```sql
SELECT 'all-status revenue' AS metric,
       (SELECT sum(order_total) FROM fct_order) AS wrong_value,
       (SELECT sum(order_total) FROM fct_order WHERE status = 'completed') AS correct_value
UNION ALL
SELECT 'naive promo join revenue',
       (SELECT sum(o.order_total) FROM fct_order o
        JOIN bridge_order_promo b ON b.order_id = o.order_id WHERE o.status = 'completed'),
       (SELECT round(sum(o.order_total * b.allocation_factor), 2) FROM fct_order o
        JOIN bridge_order_promo b ON b.order_id = o.order_id WHERE o.status = 'completed');
```

**Proving two queries are actually equivalent** — stronger than eyeballing that a
count or a sum matches, because it checks every row:

```sql
-- if both of these return zero rows, the two queries produce identical row sets
(SELECT * FROM my_q03_version) EXCEPT (SELECT * FROM my_q05_cte_rewrite)
UNION ALL
(SELECT * FROM my_q05_cte_rewrite) EXCEPT (SELECT * FROM my_q03_version);
```

Q05 and Q09 both ask you to rewrite an earlier query and "verify the numbers match" —
until now that's meant checking one or two aggregate figures. `EXCEPT` checks *every*
row, which catches a rewrite that happens to agree on the total but silently drops or
duplicates a handful of rows that cancel out in the sum.

---

## `NULLIF` — the deliberate, controlled NULL

**Used in:** [Q07 stretch](../assignments/Q07_traps.md).

`NULLIF(a, b)` returns `NULL` if `a = b`, otherwise returns `a`. It exists for exactly
one purpose: turning a value you don't want to divide by into a `NULL` on purpose,
*before* the division runs — because unlike most languages, dividing by zero in SQL
does not raise an error. In DuckDB it silently returns `inf` (a real number ÷ 0) or
`nan` (`0 ÷ 0`), and both propagate quietly through every calculation downstream.

Concretely: how many returned lines did each category have on each day, and what was
their average value? Most category/day combinations have zero returns — that's normal,
returns are only ~3.4% of all lines — but "zero returns" is a real, common case your
query has to survive:

```sql
SELECT p.category, d.full_date,
       coalesce(sum(i.line_amount) FILTER (WHERE i.is_returned = 'Y'), 0) AS returned_revenue,
       count(*) FILTER (WHERE i.is_returned = 'Y') AS returned_lines,
       coalesce(sum(i.line_amount) FILTER (WHERE i.is_returned = 'Y'), 0)
         / NULLIF(count(*) FILTER (WHERE i.is_returned = 'Y'), 0) AS avg_returned_line
FROM fct_order_item i
JOIN fct_order o ON o.order_id = i.order_id
JOIN dim_product p ON p.product_sk = i.product_sk
JOIN dim_date d ON d.date_key = o.date_key
GROUP BY p.category, d.full_date;
```

Drop the `NULLIF` and every zero-return day silently reports `nan` instead of "no
returns that day, no average to report." `nan` is worse than a crash: it looks like a
number, sorts unpredictably, and compares as neither greater than, less than, nor
equal to anything (including itself) — so a downstream `WHERE avg_returned_line > 100`
quietly drops those rows with no error, and a `nan` that reaches a chart renders as a
gap or a zero depending on the tool, with no indication anything went wrong.

`NULLIF` pairs naturally with `COALESCE` (met back in Q01): `COALESCE` supplies a
value when one is missing; `NULLIF` removes one deliberately before it can cause
damage. The general pattern for a rate that can have a zero denominator is
`numerator / NULLIF(denominator, 0)`, then decide separately — with `COALESCE` on the
*result*, if you want one — what a reader should see instead of a blank: "no returns
that day," not a missing cell that could just as easily mean the query broke.
