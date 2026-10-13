# PRISM — SPEC (mentor-facing)

The dataset contract, the planted traps with exact counts, and what to look for in
review. The student may read this — it spoils nothing that the answer key doesn't — but
they don't need to.

## 1. Purpose and level

A first SQL lab for an analyst. The syntax coverage is deliberately conventional:
filtering, aggregation, joins, dates, subqueries, CTEs, window functions. What makes it
a *lab* rather than a tutorial is that every question has one correct number, the data
contains normal-looking traps that produce wrong ones, and the student is asked to say
what each number means.

**Level target.** By Q09, an analyst who can take an ambiguous business question, choose
the grain and filters that answer it, produce the number, and state its caveats without
being prompted. In the career-paths ladder that is level 2 with review, edging to level 3
on the SQL itself.

**Anti-goals.** No modeling (they consume the model, they don't build it), no pipelines,
no performance tuning, no dbt. If a question needs anything other than SQL and judgement,
it doesn't belong here.

## 2. Stack

DuckDB, because a single 20 MB file removes every setup obstacle and returns every query
instantly, and because its SQL is close enough to standard that the habits transfer.
Every assignment ends with an **Oracle note** where the dialect differs, since the real
warehouse is Oracle — that mapping is a genuine part of the training, not decoration.

## 3. The dataset

Deterministic: `generate.py` always produces byte-identical data, so every number in
`answers/ANSWERS.md` stays correct forever. Window: **2025-01-01 → 2026-06-30** (546 days).

| Table | Rows | Grain |
|---|---|---|
| `dim_date` | 546 | one calendar date |
| `dim_customer` | **1,302** | one *version* of one customer (1,200 customers; 102 have two) |
| `dim_product` | 180 | one product |
| `dim_store` | 14 | one store |
| `dim_promo` | 8 | one promo code |
| `fct_order` | **55,423** | one order |
| `fct_order_item` | **96,883** | one order line |
| `bridge_order_promo` | **19,572** | one (order, promo) pair |
| `raw_customer_list` | 1,269 | one row of a hand-maintained spreadsheet |

Headline figures the assignments quote:

- Orders by status: **completed 46,460 · cancelled 3,354 · returned 2,812 · pending 2,797**.
- Completed revenue (`sum(order_total)`): **14,201,609.13** across **46,460** orders,
  average **305.67**.
- Revenue including every status: **16,922,496.96**. Each status combination gives a
  different number, which is the point of Q07.
- Calendar 2025 completed revenue **9,736,875.65**; 2025 H1 **4,476,125.75** against 2026 H1
  **4,464,733.48** — flat, and the comparison Q08 question 1 turns on.

## 4. The planted traps

Each one is discoverable, each one produces a plausible wrong number, and each has an
exact count so you can tell whether the student found it or got lucky.

| # | Trap | Where | Exact effect |
|---|---|---|---|
| 1 | **Cancelled, pending and returned orders** in the fact | `fct_order.status` | Including all statuses overstates completed revenue by **19.2%** (16,922,496.96 vs 14,201,609.13) |
| 2 | **Promo bridge fan-out** | `bridge_order_promo` | Joining orders to promos without allocation gives **5,075,682.37** where the allocated figure is **3,787,250.73** — a **34%** overstatement |
| 3 | **SCD2 fan-out** | `dim_customer` (102 two-version customers) | Joining on `customer_id` instead of `customer_sk`, or forgetting `is_current`, turns 54,583 order rows into **59,307** — **+8.7%** |
| 4 | **Average of averages** | any category rollup | Mean of the five per-category average line amounts is **244.17**; the true average line is **183.49** — a **33%** overstatement, because `computing` is 3× the price and a tenth of the volume |
| 5 | **Guest orders** | `fct_order.customer_sk IS NULL` | **840** orders worth **259,126.99** vanish from any inner join to `dim_customer` |
| 6 | **`NOT IN` with NULLs** | `fct_order.customer_sk` | "Customers who never ordered" via `NOT IN (SELECT customer_sk FROM fct_order)` returns **0** rows; the true answer is **40** |
| 7 | **Unrecorded discounts** | `fct_order.discount_amount IS NULL` | **2,253** orders; the discount was applied (it's in `order_total`) but not recorded, so `SUM(discount_amount)` understates and `COUNT(discount_amount)` ≠ `COUNT(*)` |
| 8 | **Order-level adjustments** | `fct_order.order_total` | **2,218** orders don't reconcile to their own lines: **1,147** because of trap 7, **1,071** because of a genuine order-level adjustment. Two causes, one symptom |
| 9 | **Never-sold products** | `dim_product.is_discontinued` | **9** products have no sales; an inner join hides them, so "worst-selling product" is wrong unless you `LEFT JOIN` |
| 10 | **A closed store** | `dim_store` store 9 (`ST09`) | Closed 2026-02-28, last order that day. Any "revenue by store, last 3 months" comparison shows it at zero and it is not a data error |
| 11 | **Duplicate rows** | `raw_customer_list` | **69** customer_ids appear twice, with different casing and padding; a join to it fans out |
| 12 | **Missing contact details** | `dim_customer` | **53** rows with no city, **22** with no email — so `COUNT(city)` ≠ `COUNT(*)` and a `GROUP BY city` has a NULL bucket |

## 5. Per-assignment scope and what to look for

**Q00 — First look.** Connect, list tables, `SELECT`, `LIMIT`, `DESCRIBE`/`SUMMARIZE`,
row counts, and a written grain sentence per table. *Look for:* they worked out that
`dim_customer` has more rows than customers, and asked why, before anyone told them.

**Q01 — Filtering & sorting.** `WHERE`, comparison and logical operators, `IN`,
`BETWEEN`, `LIKE`, `IS NULL`, `ORDER BY`, `LIMIT`, `DISTINCT`. Traps 5, 7 and 12 all
appear here. *Look for:* they can explain why `WHERE discount_amount <> 0` silently drops
2,253 rows, and why `city = NULL` returns nothing.

**Q02 — Counting & summing.** Aggregate functions, `GROUP BY`, `HAVING` vs `WHERE`,
`COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT col)`, rounding. Traps 1, 4, 7, 12. *Look
for:* they noticed `AVG` ignores NULLs rather than treating them as zero, and can say
which behaviour the business wanted.

**Q03 — Joins.** Inner vs left, multi-table joins, anti-joins, and the discipline of
checking row counts before and after. Traps 2, 3, 5, 9, 11. *Look for:* they check the
row count after every join as a reflex. This is the single most valuable habit in the lab.

**Q04 — Dates & trends.** Joining `dim_date`, grouping by month/quarter/fiscal period,
month-on-month and year-on-year, seasonality, weekday vs weekend, and gaps. *Look for:*
they compared like periods (2026 H1 against 2025 H1, not against all of 2025) without
being told.

**Q05 — Subqueries & CTEs.** Scalar subqueries, `IN`/`EXISTS`/`NOT EXISTS`, correlated
subqueries, `WITH`. Trap 6 lives here. *Look for:* they reach for a CTE to make a query
readable rather than to show off, and can rewrite one of their own earlier queries more
clearly.

**Q06 — Window functions.** `ROW_NUMBER` for dedup and top-N-per-group, `RANK` vs
`DENSE_RANK`, `LAG`/`LEAD` for period-on-period, `SUM() OVER` for running totals,
`PARTITION BY`/`ORDER BY` semantics. Trap 11 gets solved properly here. *Look for:* they
can say in one sentence why a window function beats a self-join for month-on-month growth.

**Q07 — Four wrong numbers.** The assignment builds each wrong number on purpose, next
to the right one, with the size of the error. Traps 1–4 and 8. *Look for:* they can state
the check that would have caught each mistake. Producing the four errors is worth less
than naming the four checks.

**Q08 — Real questions.** Eight requests phrased the way people actually phrase them,
three of them materially ambiguous. Deliverable per question: the restated question, the
metric definition, the query, the number, one sentence of meaning, and any caveat. *Look
for:* they asked about the ambiguous ones instead of picking an interpretation quietly.

**Q09 — Making it stick.** Query formatting, comments that say *why*, saved views, a
five-question analysis pack, and the same number explained to three audiences. *Look for:*
the pack's numbers are traceable — a reader can tell which filters produced each one.

## 6. Review guidance

Three checkpoints, 20–30 minutes each: after **Q03**, after **Q07**, and the analysis pack
at **Q09**.

At each one, ask them to talk you through one query line by line, then ask *"what would
make this number wrong?"*. An analyst who can answer that question about their own work is
ready for real requests; one who can't will produce confident wrong numbers no matter how
good their syntax is.

Two answers are acceptable throughout: *"here's the number and here's what it excludes"*
and *"the question is ambiguous, here are the two readings and what each would give."* One
is not: a number with no statement of what it covers.
