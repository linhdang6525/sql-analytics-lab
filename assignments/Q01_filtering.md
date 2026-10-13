# Q01 — Filtering & sorting

**Est. time:** 3h · **Difficulty:** ⭐⭐ · **Requires:** Q00, including the grain sentences

## Why this matters

Nearly every wrong number an analyst produces comes from a `WHERE` clause — either a row
that should have been excluded and wasn't, or one that should have been included and got
filtered out silently. This dataset has 3,354 cancelled orders in it. Nobody will remind
you.

The other half of this assignment is NULL, which behaves unlike anything else in SQL and
breaks filters in a way that produces no error and no warning.

## What you need to know

**The operators.** `=` `<>` `<` `>` `<=` `>=`, combined with `AND`, `OR`, `NOT`. Use
brackets when you mix `AND` and `OR` — `A AND B OR C` does not mean what most people
assume, and being explicit costs you two characters.

**Shorthands.** `IN ('web','app')` beats a chain of `OR`s. `BETWEEN 100 AND 200` is
inclusive at both ends — worth knowing exactly, because "between 100 and 200" in English
is ambiguous and in SQL it isn't. `LIKE 'Lap%'` matches a prefix, `'%top%'` matches
anywhere, `_` matches exactly one character.

**NULL is not a value.** It means *unknown*. So:

- `city = NULL` is never true. Not even for rows where city is NULL. Use `IS NULL`.
- `discount_amount <> 0` excludes NULL rows, because "unknown ≠ 0" is unknown, not true.
  That's 2,253 orders quietly gone.
- `NULL + 5` is NULL. `SUM` skips NULLs; `COUNT(col)` skips them too. Q02 covers this.
- To treat NULL as a value, convert it: `COALESCE(discount_amount, 0)`.

**Sorting.** `ORDER BY x DESC`, multiple keys `ORDER BY a, b DESC`. NULLs sort last in
DuckDB by default when ascending — `NULLS FIRST`/`NULLS LAST` makes it explicit, and being
explicit matters when the answer is a top-10 list someone will act on.

**`DISTINCT`** removes duplicate *rows*, not duplicate values in one column — 
`SELECT DISTINCT status, channel` gives you distinct *combinations*.

## Questions

1. How many orders have status `completed`?
2. How many completed orders have an `order_total` over 1,000?
3. How many orders were placed through the `web` or `app` channel? Write it with `IN`.
4. How many orders have `discount_amount` greater than zero? How many have exactly zero?
   Add those two numbers together and compare with the total row count of `fct_order`.
   **Explain the gap** — this is the whole point of the question.
5. How many rows in `dim_customer` have no city recorded? How many have no email?
6. Write a filter that finds customers with no city, then run the same query with
   `WHERE city = NULL` instead. Explain the difference in one sentence.
7. How many current (`is_current = 'Y'`) customers are in the `enterprise` segment in
   Germany (`country_code = 'DE'`)?
8. List the 10 largest completed orders: order id, total, status, channel. Highest first.
9. How many products have `Laptop` in their name? How many are discontinued?
10. Find all orders placed on 2025-12-24. (`fct_order` has `date_key` as an integer like
    `20251224`, and `ordered_at` as a timestamp — try both, and note which is easier.)
11. Which orders have no customer attached at all? How many are there, and what do you
    think they are?
12. List every distinct combination of `channel` and `status`. How many rows do you get,
    and what would you have expected?

## Check yourself

| # | Expected |
|---|---|
| 1 | **46,460** completed orders |
| 2 | **1,930** completed orders over 1,000 |
| 3 | web + app orders: **41,011** |
| 4 | `> 0`: **26,596** · `= 0`: **26,574** · total rows 55,423 → **2,253 rows are NULL** |
| 5 | no city: **53** · no email: **22** |
| 7 | **27** current enterprise customers in DE |
| 9 | `Laptop` in name: **12** · discontinued products: **9** |
| 11 | **840** orders with no `customer_sk` |
| 12 | **16** combinations (4 channels × 4 statuses) |

## Common beginner mistakes

- `WHERE status = 'Completed'` — string comparison is case-sensitive here, and returns
  zero rows with no complaint. Check the actual values (Q00 question 6) rather than
  guessing the capitalization.
- `WHERE discount_amount <> 0` when you meant "orders with no discount recorded or a
  discount of zero". The NULLs are not in either bucket until you say what to do with them.
- `WHERE city = NULL` or `WHERE city != NULL`. Both return nothing, forever.
- Mixing `AND` and `OR` without brackets: `WHERE status = 'completed' AND channel = 'web'
  OR channel = 'app'` includes every app order regardless of status. Ask yourself whether
  that's what you meant.
- `BETWEEN '2025-01-01' AND '2025-01-31'` on a *timestamp* column: an order at 14:30 on the
  31st is excluded, because the range ends at midnight. On a date column it's fine. This is
  the most common date bug in analytics, and Q04 comes back to it.
- Filtering on `order_total > 1000` without also filtering status, so a cancelled order for
  1,200 counts as a large sale.

## Oracle note

Almost all of this is identical. Differences that matter: Oracle treats an empty string
`''` **as NULL**, so `WHERE city = ''` finds nothing and `WHERE city IS NULL` finds both
the blanks and the genuine unknowns — a distinction you simply cannot make in Oracle once
the data has landed. String comparison is case-sensitive by default there too. `LIMIT`
becomes `FETCH FIRST n ROWS ONLY`. For dates, avoid string comparison entirely and use
`DATE '2025-12-24'` or `TO_DATE('2025-12-24','YYYY-MM-DD')`; comparing a `DATE` column to a
string works by accident until someone changes a session setting.

## Stretch

1. Write one query that returns, for each status, whether any of its orders have a NULL
   `discount_amount`. You'll need `GROUP BY` from Q02 — read ahead if you want.
2. Take question 4 and rewrite it so that the three buckets (positive, zero, unrecorded)
   are three columns in one row. Hint: `COUNT(CASE WHEN ... THEN 1 END)`.
3. Find the order with the largest gap between `gross_amount` and `order_total`. What
   happened to that order?
