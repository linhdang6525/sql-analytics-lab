# Q02 — Counting & summing

**Est. time:** 3h · **Difficulty:** ⭐⭐ · **Requires:** Q01

## Why this matters

"How many customers do we have?" has at least four correct answers in this database and
they differ by hundreds. Not because the data is broken — because "customer" and "have"
both need defining, and the SQL you write encodes a definition whether you thought about
it or not.

This assignment is where you learn that an aggregate is a *claim*, and that the difference
between `COUNT(*)`, `COUNT(col)` and `COUNT(DISTINCT col)` is the difference between three
different claims that all look like "how many".

## What you need to know

**The five aggregates:** `COUNT`, `SUM`, `AVG`, `MIN`, `MAX`.

**Three kinds of count:**

- `COUNT(*)` — rows. Always. Never skips anything.
- `COUNT(col)` — rows where `col` is **not NULL**. This is why `COUNT(discount_amount)` is
  2,253 lower than `COUNT(*)` here.
- `COUNT(DISTINCT col)` — distinct non-NULL values.

**NULLs are skipped, not zeroed.** `SUM` and `AVG` ignore them. So the average discount is
the average *of the recorded discounts*, over 53,170 orders, not over all 55,423. That may
be what you want or may badly overstate it; you have to decide, and say which.

**`GROUP BY`** collapses rows into groups. Every column in your `SELECT` must either be in
the `GROUP BY` or wrapped in an aggregate — this rule is annoying until you understand that
the alternative is meaningless output.

**`WHERE` vs `HAVING`.** `WHERE` filters rows *before* grouping; `HAVING` filters groups
*after*. "Completed orders only" is `WHERE`. "Categories with more than 2 million in
revenue" is `HAVING`. Putting a `WHERE` condition in `HAVING` usually still works and is
slower and harder to read; putting a `HAVING` condition in `WHERE` doesn't work at all.

**Averages lie by default.** `AVG(order_total)` is an average per order; an average of
per-category averages is not an average — it's a number with no interpretation, and Q07
shows you exactly how far wrong it goes here (33%).

## Questions

1. How many orders are there in total? How many have a recorded discount? How many
   distinct customers appear in `fct_order`?
2. Total revenue (`order_total`) for completed orders. Then for all statuses. **What is the
   percentage difference, and which number would you send to a stakeholder?**
3. Count, revenue, and average order value **by status**, largest revenue first.
4. Average, minimum and maximum `order_total` for completed orders. Does the average sit
   where you'd expect between the min and max? Why not?
5. Revenue by channel for completed orders. What share of revenue is `web`?
6. Revenue by product category for completed orders (you'll need `fct_order_item` joined to
   `dim_product` — Q03 covers joins properly, but try it now).
7. Which categories have more than 2 million in completed revenue? Use `HAVING`.
8. Average number of lines per completed order. Careful — this is a ratio of two different
   grains, so think about the numerator and denominator separately.
9. How many current customers are in each segment? Then: how many *distinct customers* have
   ever placed a completed order, by segment. **These two sets of numbers disagree. Note it
   down and move on — Q07 explains it.**
10. Average `discount_amount` for completed orders, computed two ways: as SQL gives it by
    default, and treating unrecorded discounts as zero. Report both and say which one you'd
    label "average discount".
11. For each month of 2026, the number of completed orders and their revenue. (Join
    `dim_date` — or use `date_key / 100` as a shortcut and note why that's a hack.)
12. The 5 products with the highest completed revenue: SKU, category, revenue.

## Check yourself

| # | Expected |
|---|---|
| 1 | rows **55,423** · recorded discount **53,170** · distinct customers in orders **1,258** |
| 2 | completed **14,201,609.13** · all statuses **16,922,496.96** → all-statuses is **+19.2%** |
| 3 | completed 46,460 / 14,201,609.13 / 305.67 · cancelled 3,354 / 1,025,328.71 / 305.70 · returned 2,812 / 837,032.80 / 297.66 · pending 2,797 / 858,526.32 / 306.95 |
| 4 | avg **305.67** · min **-7.91** · max **6,166.61** — yes, a negative minimum is correct, not a bug in your query |
| 5 | web **6,428,313.68** of 14,201,609.13 = **45.3%** |
| 6 | computing **4,016,974.03** · home 3,287,179.27 · audio 2,883,682.28 · outdoor 2,847,136.47 · wearables the rest |
| 7 | four categories clear 2 million; wearables does not |
| 8 | **1.747** lines per completed order |
| 9 | current: consumer 800 · smb 270 · enterprise 130 — but by orders you'll see 839 / 281 / 138 |
| 12 | top SKU is **SKU-0016** (computing) at **331,876.85** |

## Common beginner mistakes

- `COUNT(*)` when the question said "customers". Rows are not customers, especially in
  `fct_order` where one customer has dozens.
- `COUNT(DISTINCT customer_sk)` when the question meant people: 1,258 surrogate keys, but
  fewer actual humans, because a customer who changed segment has two keys. This is the
  Q07 trap arriving early.
- Forgetting `WHERE status = 'completed'`, so cancelled orders inflate everything by ~19%.
- Reporting an average without saying what it's an average *of* — per order, per line, per
  customer, per day?
- `AVG(discount_amount)` and calling it "average discount per order" when 2,253 orders had
  no value recorded.
- `SELECT category, sum(...)` with no `GROUP BY` — an error in most databases, and in a few
  it silently returns one arbitrary category.
- Rounding in the middle of a calculation instead of at the end. Round once, when you
  present.

## Oracle note

`COUNT`, `SUM`, `AVG`, `GROUP BY` and `HAVING` are identical. Two things differ. First,
integer division: `SELECT 7/2` gives 3.5 in both, but be careful with `COUNT(*)/COUNT(*)`
patterns in other engines — the habit of multiplying by `1.0` is cheap insurance. Second,
Oracle has `NVL(x, 0)` as well as the standard `COALESCE(x, 0)`; both work, `COALESCE` is
portable and takes more than two arguments, so prefer it. Oracle also gives you
`GROUP BY ROLLUP(...)` and `GROUPING SETS`, which produce subtotal rows in one pass — worth
knowing once you're comfortable, because analysts reach for it constantly. And Oracle's
`AVG` skips NULLs exactly as here, so that lesson transfers unchanged.

## Stretch

1. Produce one row per channel with: orders, revenue, average order value, and the
   percentage of total revenue. The percentage needs a total — try a scalar subquery
   (`(SELECT SUM(...) FROM ...)`), which is Q05 material.
2. Which single day had the highest completed revenue? Does the date make sense?
3. Compute the return rate by category — returned line amount over total line amount. It
   ranges from 2.87% to 3.70%; get the same answer, then say whether that spread is worth
   telling anyone about.
