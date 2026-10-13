# Q03 — Joins

**Est. time:** 4h · **Difficulty:** ⭐⭐⭐ · **Requires:** Q02

## Why this matters

Joins are where analysts do the most damage, because a bad join doesn't error — it changes
your numbers. Two failure modes, both silent:

- **Rows disappear.** An inner join to `dim_customer` drops all 840 guest orders and
  259,126.99 of revenue. Your total is now wrong and looks fine.
- **Rows multiply.** Joining orders to `bridge_order_promo` turns one order into up to
  three, and the same revenue gets counted up to three times. Your total is now 34% too
  high and still looks fine.

There is one habit that catches both, and it is the most valuable thing in this lab:
**count the rows before the join and after it, and be able to explain any difference.**

## What you need to know

**`INNER JOIN`** keeps rows that match on both sides. **`LEFT JOIN`** keeps every row from
the left table and fills the right side with NULL when there's no match. That's it — those
two cover nearly all analytical work. (`RIGHT JOIN` is a `LEFT JOIN` written backwards;
`FULL OUTER` is occasionally useful for reconciliation.)

**The join key must be the right column.** `fct_order.customer_sk = dim_customer.customer_sk`
is correct. Joining on `customer_id` — which exists in `dim_customer` but not in
`fct_order` — would require going through the surrogate key anyway, and joining a fact to
a *versioned* dimension on the business id fans out. Q07 quantifies that.

**Fan-out.** If the right-hand table has more than one matching row per left-hand row, the
left row is duplicated. Any `SUM` of a left-hand column is then inflated. The two defences:
aggregate the right side to one row per key *before* joining, or carry an allocation factor
(the bridge table has one — `allocation_factor` sums to 1.0 per order).

**Finding what's missing (anti-join).** Two idioms:

```sql
-- LEFT JOIN + IS NULL
SELECT p.sku FROM dim_product p
LEFT JOIN fct_order_item i ON i.product_sk = p.product_sk
WHERE i.product_sk IS NULL;

-- NOT EXISTS  (usually clearer, and NULL-safe unlike NOT IN)
SELECT p.sku FROM dim_product p
WHERE NOT EXISTS (SELECT 1 FROM fct_order_item i WHERE i.product_sk = p.product_sk);
```

**Aliases.** Always alias your tables (`fct_order o`) and always qualify your columns
(`o.order_total`). With four tables in a query, unqualified column names are a guessing
game for whoever reads it next — including you, next week.

## Questions

For every question, **record the row count before and after each join.**

1. Join `fct_order` to `dim_store`. How many rows? Now do it as a `LEFT JOIN`. Same
   number? Why?
2. Join `fct_order` to `dim_customer` on `customer_sk`, inner. Then left. **The two
   numbers differ — by how much, and what are the missing rows?**
3. Completed revenue by store country. Which country is largest?
4. Completed revenue by customer segment, joining through `customer_sk`.
5. Completed revenue by product category — this needs three tables: `fct_order`,
   `fct_order_item`, `dim_product`.
6. Which products have never been sold? How many are there? (Use both anti-join idioms and
   confirm they agree.)
7. Which current customers have never placed an order? How many?
8. Join `fct_order` to `bridge_order_promo` and sum `order_total`. Compare with the plain
   completed revenue from Q02. **Explain the difference before reading on.** Then compute
   the promo-attributed revenue *correctly* using `allocation_factor`.
9. Revenue per promo code, correctly allocated, for completed orders. Which code is
   biggest?
10. Join `dim_customer` (current rows only) to `raw_customer_list` on `customer_id`. You
    have 1,200 current customers — how many rows come back? Explain.
11. For each store: store code, region, completed order count, completed revenue, and the
    date of its last order. Which store stopped?
12. List the 10 customers with the most completed orders: customer id, name, segment, order
    count, total revenue.

## Check yourself

| # | Expected |
|---|---|
| 1 | 55,423 both ways — every order has a valid store |
| 2 | inner **54,583** · left **55,423** · difference **840** guest orders |
| 3 | BE **4,853,938.40** · NL 4,081,234.45 · VN 3,253,732.66 · DE 1,011,677.57 · FR 1,001,026.05 |
| 5 | computing 4,016,974.03 · home 3,287,179.27 · audio 2,883,682.28 · outdoor 2,847,136.47 |
| 6 | **9** products never sold |
| 7 | **40** current customers with no orders |
| 8 | naive join **5,075,682.37** · allocated **3,787,250.73** — the naive figure is **34% too high** |
| 9 | **BUNDLE15** at 494,884.03, then FREESHIP 489,954.52, SPRING10 487,095.21 |
| 10 | **1,269** rows from 1,200 customers — the list has 69 duplicates |
| 11 | store **ST09**, last order **2026-02-28** |

## Common beginner mistakes

- Not counting rows before and after. Everything below is a symptom of this.
- Inner-joining a fact to a dimension and losing the rows with no key. If the question is
  "total revenue", the guest orders belong in it, so `LEFT JOIN` and put them in an
  "Unknown" bucket rather than dropping them.
- Summing a fact measure after joining to a bridge or any one-to-many table.
- Joining to a versioned dimension without `is_current` (or a date condition) and getting
  each order counted once per customer version.
- The opposite mistake, which is easier to miss: joining on `customer_sk` **with**
  `c.is_current = 'Y'` when you want a customer's full order history (question 12).
  `customer_sk` is 1:1 with a dimension row, so there's no fan-out — but a versioned
  customer's *older* orders reference their *old*, non-current `customer_sk`, and
  `is_current = 'Y'` silently excludes every one of them. If the question is "how many
  orders has this customer ever placed," aggregate by the stable `customer_id` across
  **all** of their `customer_sk` values, not by filtering to the current one.
- `WHERE c.segment = 'smb'` on a `LEFT JOIN` — the `WHERE` runs after the join and throws
  away the unmatched rows, quietly turning your left join back into an inner one. Conditions
  on the *right* table of a left join belong in the `ON` clause.
- Joining `fct_order` to `fct_order_item` and then summing `order_total`: the order total is
  repeated on every line. Sum `line_amount` at line grain, or `order_total` at order grain.
  Never mix.
- Forgetting that `dim_date` joins on `date_key`, not on a date.

## Oracle note

Standard `JOIN ... ON` syntax works identically. You will still meet Oracle's older comma
syntax with `(+)` for outer joins in inherited queries — `WHERE a.id = b.id(+)` is a left
join — and you should be able to read it, though never write it. Oracle supports
`USING (order_id)` as here. Two practical notes: Oracle's optimizer is generally very good
at reordering joins, so write for clarity first; and when joining a fact to a large
dimension, whether the columns' types match exactly (`VARCHAR2(20)` vs `NUMBER`) can be the
difference between an index scan and a full table scan — a conversation to have with a data
engineer rather than to solve yourself.

## Stretch

1. Build one query that returns revenue by category **and** includes the never-sold
   products with zero. You'll need the join direction to start from `dim_product`.
2. Question 8 the hard way: instead of using `allocation_factor`, aggregate the bridge to
   one row per order (count of promos) and join that. Confirm the row count no longer
   changes, and say what you lost by doing it that way.
3. Reconcile order grain against line grain: for completed orders, `SUM(order_total)`
   versus `SUM(line_amount)`. They differ, and the difference is made of discounts,
   shipping and something else. Find out what — Q07 finishes this story.
