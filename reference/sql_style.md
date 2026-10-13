# SQL style, and the checklist before you send a number

Two short documents in one. The style guide is about the query; the checklist is about the
number. Both exist because your work gets inherited — by a colleague, by a report, and by
you in four months, when you will remember nothing.

---

## Style

### Layout

Keywords at the left margin, columns indented, one clause per line:

```sql
SELECT
    d.year,
    d.month,
    count(*)                AS order_count,
    round(sum(o.order_total), 2) AS revenue
FROM fct_order o
JOIN dim_date  d USING (date_key)
WHERE o.status = 'completed'
GROUP BY d.year, d.month
ORDER BY d.year, d.month;
```

You can read the shape of that from across the room. A one-line version of the same query
is not shorter to *understand*, which is the only length that matters.

### Rules worth being pedantic about

1. **Alias every table, meaningfully.** `fct_order o`, `dim_customer c`. Not `t1`, `t2`.
2. **Qualify every column** when there's more than one table. `o.order_total`, not
   `order_total`. When someone later adds a column with the same name to the other table,
   unqualified SQL breaks in a way that's hard to find.
3. **Name every computed column.** `AS revenue`, not a column header reading
   `round(sum(o.order_total), 2)`.
4. **CTEs for steps, named for contents.** `completed_orders`, `revenue_by_month`. Never
   `cte1`, never `temp`.
5. **Two to four CTEs.** More than that and you've written a program; consider whether it
   belongs in a view.
6. **Explicit joins.** `JOIN ... ON`, never a comma join with conditions in `WHERE`.
7. **Half-open date ranges.** `>= '2025-01-01' AND < '2025-02-01'`. Never `BETWEEN` on
   anything that might have a time component.
8. **Round once, at the end.** Rounding mid-calculation compounds.
9. **`ORDER BY` on anything anyone will read.** Unordered output invites the reader to
   assume an order that isn't there.
10. **No `SELECT *` in anything you save.** Fine while exploring; a liability the moment
    someone adds a column.

### Comments say why

```sql
-- Revenue definition agreed with Finance 2026-03-02: completed orders only.
-- Cancelled and pending are excluded; returned orders are INCLUDED because the
-- money was received and the refund lands in a different period.
WHERE o.status = 'completed'
```

Compare with `-- filter on status`, which tells the reader what they can already see and
nothing they need.

### The definition block

At the top of every saved query:

```sql
/* Monthly revenue by channel
   Question:  Femi (Marketing), 2026-03-04 — channel mix trend for the H1 review
   Grain:     one row per month per channel
   Measure:   sum(order_total) for status = 'completed'
   Excludes:  cancelled, pending, returned; guest orders included (no customer join)
   Period:    2025-01-01 to 2026-06-30
   Caveats:   order-level figure; will not tie to line-level product analysis
*/
```

Eight lines. It is the difference between a query somebody can trust and a query somebody
rewrites.

---

## The checklist

Run this before any number leaves your hands. It takes two minutes and it is the difference
between an analyst people trust and one they double-check.

**About the rows**

- [ ] Did I filter the fact table's status? (`SELECT status, count(*) ... GROUP BY 1`)
- [ ] Do I know the row count before and after every join, and can I explain any change?
- [ ] Did an inner join silently drop rows with no key — guest orders, unknown products?
- [ ] Is there a versioned dimension in here that needs `is_current` or a date condition?

**About the measure**

- [ ] Am I summing a measure at its own grain? (order totals at order grain, line amounts at
      line grain, never mixed)
- [ ] If this is a ratio or an average, did I sum the numerator and denominator separately
      and divide once?
- [ ] Is this an average of averages? (If yes: stop.)
- [ ] Are there NULLs in the column I'm aggregating, and did I decide what they mean?

**About the period**

- [ ] Does the number have a period attached, in writing?
- [ ] If I'm comparing, are the periods the same length and the same shape? (H1 vs H1, not
      H1 vs a full year)
- [ ] Is any period partial — the start of the data, the current month?

**About the claim**

- [ ] If this breaks into parts, do the parts sum to the whole? If not, do I know why?
- [ ] Is this number plausible for this business? (If revenue per customer is 12,000 a year
      for a consumer retailer, something is wrong.)
- [ ] Can I say in one sentence what this number excludes?
- [ ] Can I answer "what would make this wrong?" without looking anything up?

**Before sending**

- [ ] Is the definition written down somewhere other than my head?
- [ ] Would the recipient be able to act without asking me a follow-up I could have
      anticipated?

If you can't tick "do the parts sum to the whole" and "what would make this wrong", the
number isn't ready, however good the SQL is.
