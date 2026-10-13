# Q05 — Subqueries & CTEs

**Est. time:** 3h · **Difficulty:** ⭐⭐⭐ · **Requires:** Q04

## Why this matters

Some questions can't be answered in one pass: "customers who spent more than average",
"the best-selling product in each category", "orders larger than that customer's own
typical order". They need a query inside a query.

The syntax is easy. What matters is that you write it so someone else can read it — because
the query you write today gets pasted into a report, and in four months somebody (you) has
to work out whether it's still right.

## What you need to know

**Scalar subquery** — returns exactly one value, usable anywhere a value goes:

```sql
SELECT order_id, order_total,
       order_total - (SELECT AVG(order_total) FROM fct_order WHERE status = 'completed') AS vs_avg
FROM fct_order WHERE status = 'completed';
```

**`IN` / `NOT IN`** — membership against a list of values from another query.

> **The NULL trap.** `x NOT IN (SELECT col FROM t)` returns **no rows at all** if `col`
> contains a single NULL, because "x ≠ unknown" is unknown, not true. `fct_order.customer_sk`
> has 840 NULLs, so `NOT IN` on it is a trap you will walk into in question 6. Use
> `NOT EXISTS` instead, always.

**`EXISTS` / `NOT EXISTS`** — asks whether a matching row exists. Correlated: the inner
query references the outer one. Usually clearer than `IN`, and NULL-safe.

**Derived table** — a subquery in `FROM`, which must be aliased:

```sql
SELECT segment, AVG(order_count) FROM (
  SELECT customer_sk, COUNT(*) AS order_count FROM fct_order GROUP BY customer_sk
) t JOIN ... ;
```

**CTE (`WITH`)** — the same thing, named, at the top:

```sql
WITH per_customer AS (
    SELECT customer_sk, COUNT(*) AS order_count, SUM(order_total) AS revenue
    FROM fct_order WHERE status = 'completed' AND customer_sk IS NOT NULL
    GROUP BY customer_sk
)
SELECT ... FROM per_customer ...;
```

CTEs are how readable analytical SQL is written. Each one is a named step; the final
`SELECT` reads like a sentence. Three shallow CTEs beat one query nested three deep every
time — not for performance, for the person reading it.

## Questions

1. What is the average completed order value? Now list the 10 completed orders furthest
   *above* that average, showing the order total and the difference.
2. How many completed orders are above the overall average order value? What percentage is
   that? (It won't be 50% — explain why in one sentence.)
3. Which customers have spent more than 20,000 in completed orders? Show customer id, name,
   and total. Use a CTE.
4. For each segment, the average *number of completed orders per customer*. This needs two
   steps: per-customer counts, then average by segment.
5. Which products have sold more than 900 units (completed orders only)? How many products
   are there in total with any completed sales — and how does that compare with the 180 rows
   in `dim_product`?
6. Which current customers have never placed an order? Answer it **twice** — once with
   `NOT IN (SELECT customer_sk FROM fct_order)` and once with `NOT EXISTS`. **The two
   answers differ. Explain why before reading the answer key.**
7. Which orders are larger than the average order for *that customer*? Count them.
   (Correlated subquery, or a CTE plus a join — try both.)
8. For each category, the single best-selling product by revenue. Do it with a CTE and a
   `MAX` — then keep the query, because Q06 does it in three lines with a window function.
9. Rewrite one of your Q03 or Q04 queries using CTEs to make it clearer. Put both versions
   in your file and write one line on what improved.
10. How many completed orders used each promo code? The eight codes are suspiciously even —
    say in one sentence what that tells you about how promos were assigned.
11. Customers whose *first* completed order was in 2026. How many are there?
12. Take the ugliest query you've written so far in this lab. Rewrite it with CTEs, verify
    the numbers match exactly, and note how long the rewrite took.

## Check yourself

| # | Expected |
|---|---|
| 1 | average completed order value **305.67** |
| 2 | above-average orders **15,433** = **33.2%** — the distribution is right-skewed, so most orders sit below the mean |
| 3 | **10** customers over 20,000 |
| 5 | **35** products over 900 units · **171** products have any completed sales, out of **180** rows in `dim_product` |
| 6 | `NOT EXISTS` gives **40**; `NOT IN` gives **0** |
| 10 | between **2,020** and **2,116** orders per code — eight codes, near-identical volumes |
| 11 | **27** customers whose first completed order was in 2026 |

## Common beginner mistakes

- `NOT IN` on a nullable column. It's not that you get a wrong number — you get *zero rows*
  and conclude the answer is "none".
- A correlated subquery in the `SELECT` list running once per row over a large table. Fine
  at 55k rows, painful at 55 million; know that you're doing it.
- Nesting three levels deep in `FROM` because you didn't know about `WITH`.
- A CTE per line of thought, so twelve CTEs answer one question. Aim for two to four named
  steps, each of which you could describe out loud.
- Repeating the same filter in every CTE and one of them drifting. Filter once, as early as
  makes sense, and note where.
- Assuming a CTE is a temporary table you can index or reuse cheaply. In some engines it's
  materialized, in others it's inlined; write for clarity and don't reason about it.

## Oracle note

`WITH` works from Oracle 9i onwards and is used everywhere in Oracle shops, so this
transfers directly. `EXISTS`, `NOT EXISTS`, `IN`, scalar subqueries: identical, including
the `NOT IN` NULL behaviour — it is a SQL rule, not a DuckDB quirk. Oracle also has
`WITH ... AS ( ... ) /*+ MATERIALIZE */` hints and recursive `WITH` for hierarchies. One
Oracle-specific pleasure worth knowing early: `SELECT ... FROM t WHERE rownum = 1` looks
like "give me one row" and is a common source of non-deterministic results, since it
applies before `ORDER BY`. Use `FETCH FIRST 1 ROW ONLY` with an explicit `ORDER BY`, or a
window function.

## Stretch

1. Question 7, but return each customer's *share* of their own average — a ratio, one row
   per order. Watch out for customers with a single order.
2. Write a query that returns the top 3 products per category. With subqueries this is
   genuinely awkward; get it working, then time how long Q06's version takes you.
3. Find customers who ordered in 2025 but not in 2026 (a lapsed-customer list). Then check
   your answer against the 40 who never ordered at all — are any of them in your list?
   They shouldn't be.
