# From DuckDB to Oracle

This lab runs on DuckDB. Our warehouse is Oracle. About 90% of what you learn transfers
untouched; this is the other 10%, in the order you'll trip over it.

## The five that will bite you first

**1. Empty string is NULL.** In Oracle, `''` and `NULL` are the same thing. So
`WHERE city = ''` finds nothing, ever, and a column that arrived with blanks is
indistinguishable from one with genuine unknowns. There is no fix after the fact — if the
distinction matters, it has to be captured before the data lands, which is a conversation
with a data engineer.

**2. `LIMIT` doesn't exist.** Use `FETCH FIRST 10 ROWS ONLY` (12c and later):

```sql
SELECT * FROM fct_order ORDER BY order_total DESC FETCH FIRST 10 ROWS ONLY;
```

You'll also meet `WHERE ROWNUM <= 10` in older code. It applies **before** `ORDER BY`, so
it gives you ten arbitrary rows and then sorts them — a classic wrong-top-10. If you must
use it, sort in a subquery first.

**3. Dates carry a time.** Oracle's `DATE` includes hours, minutes and seconds even when it
displays as a date. So `WHERE order_date BETWEEN DATE '2025-01-01' AND DATE '2025-01-31'`
excludes everything after midnight on the 31st. Use half-open ranges and stop thinking
about it:

```sql
WHERE order_date >= DATE '2025-01-01'
  AND order_date <  DATE '2025-02-01'
```

**4. Identifiers are upper case.** Unquoted names fold to upper case, so the data
dictionary holds `FCT_ORDER`:

```sql
SELECT column_name, data_type, nullable
FROM   user_tab_columns
WHERE  table_name = 'FCT_ORDER';   -- upper case, or you get nothing
```

**5. String concatenation is `||`.** `'a' || 'b'`. There's also `CONCAT`, but it takes only
two arguments in Oracle, so `||` is what everyone uses.

## Function translation

| DuckDB / standard | Oracle |
|---|---|
| `LIMIT n` | `FETCH FIRST n ROWS ONLY` |
| `COALESCE(x, 0)` | `COALESCE(x, 0)` or `NVL(x, 0)` — prefer `COALESCE`, it's portable and takes n arguments |
| `DATE_TRUNC('month', d)` | `TRUNC(d, 'MM')` |
| `d + INTERVAL 1 MONTH` | `ADD_MONTHS(d, 1)` |
| date difference in months | `MONTHS_BETWEEN(a, b)` |
| end of month | `LAST_DAY(d)` |
| `now()` / `current_date` | `SYSDATE`, `SYSTIMESTAMP`, `TRUNC(SYSDATE)` for today at midnight |
| `strftime(d, '%Y-%m')` | `TO_CHAR(d, 'YYYY-MM')` |
| `CAST('2025-01-01' AS DATE)` | `TO_DATE('2025-01-01', 'YYYY-MM-DD')` or `DATE '2025-01-01'` |
| `x::INTEGER` | `CAST(x AS NUMBER)` |
| `CASE WHEN ... END` | same — and Oracle also has `DECODE(x, a, b, c)`, which you'll read but shouldn't write |
| `SUMMARIZE t` | no equivalent; profile by hand with `COUNT`, `MIN`, `MAX`, `COUNT(DISTINCT ...)` |
| `SHOW TABLES` | `SELECT table_name FROM user_tables` |
| `string_agg(x, ',')` | `LISTAGG(x, ',') WITHIN GROUP (ORDER BY x)` |
| `MEDIAN(x)` | `MEDIAN(x)` — Oracle has it, and also `PERCENTILE_CONT` |

## What's identical

Everything structural, which is most of the lab:

`SELECT` / `WHERE` / `GROUP BY` / `HAVING` / `ORDER BY`, all the join types with
`JOIN ... ON` and `USING`, `IN` / `EXISTS` / `NOT EXISTS` and the `NOT IN` NULL trap (it is
a SQL rule, not a DuckDB behaviour), scalar subqueries, `WITH` (CTEs), `UNION` / `UNION ALL`
/ `INTERSECT` / `EXCEPT` (Oracle calls the last one `MINUS`, though `EXCEPT` works in
23c+), `CASE`, and the whole window-function family: `ROW_NUMBER`, `RANK`, `DENSE_RANK`,
`LAG`, `LEAD`, `NTILE`, `SUM() OVER`, frames.

Oracle's window functions are excellent and predate most competitors'. Nothing you learned
in Q06 is wasted.

## Things Oracle gives you that DuckDB doesn't

Worth knowing they exist, because Oracle analysts use them constantly:

- **`GROUP BY ROLLUP(a, b)`** — subtotal and total rows in one pass, with `GROUPING_ID()` to
  tell a subtotal row from a detail row. This is the single biggest quality-of-life feature
  for an analyst writing reports.
- **`RATIO_TO_REPORT(x) OVER (PARTITION BY ...)`** — share-of-total in one function, which
  is Q06 question 11 for free.
- **`LISTAGG`** — collapse a group into a delimited string.
- **`CONNECT BY` / recursive `WITH`** — hierarchies (org charts, product trees).
- **`LAG(x, 1, 0)`** — a default value for the first row, which saves a `COALESCE`.

## Habits that matter more in Oracle than here

**Your query runs on a shared production database.** In this lab a bad query costs you two
seconds. There, it competes with everyone else's work. So:

- Filter early, and filter on indexed columns where you can.
- Never `SELECT *` on a large fact table.
- Ask before running something you expect to be heavy, especially during business hours or a
  batch window.
- If a query takes minutes, don't tune it by guessing — ask a data engineer to look at the
  plan with you. You'll learn more in ten minutes than in an afternoon of rewriting.

**Read-only means read-only.** As an analyst you generally won't have `CREATE VIEW` rights
in the warehouse. The Q09 discipline still applies: keep one definition per metric in a
shared `.sql` file in the team's repository, with the definition block at the top. One
definition in one place, whatever holds it.
