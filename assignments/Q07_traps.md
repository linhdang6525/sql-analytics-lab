# Q07 — Four wrong numbers

**Est. time:** 4h · **Difficulty:** ⭐⭐⭐⭐ · **Requires:** Q06

## Why this matters

Everything so far taught you to get an answer. This assignment teaches you to distrust one.

The four mistakes below are the ones that actually happen. They share three properties:
the query runs, the result looks plausible, and nobody catches them for months. In this
lab you will produce all four **on purpose**, next to the correct figure, and measure how
far wrong each one is. Then you'll write down the check that would have caught it.

The checks are the deliverable. Anyone can be told "watch out for fan-out"; the useful
thing is having four specific habits that make it impossible to ship these silently.

## Wrong number 1 — the rows that shouldn't be there

`fct_order` contains 3,354 cancelled and 2,797 pending orders. Nothing in the table's name
warns you.

1. Compute total revenue with no status filter. Then completed only. Report both and the
   percentage difference.
2. Which is right? It depends on the question — and "revenue" in a business conversation
   almost always means money you actually got. Write the one-line definition you would put
   next to the number in a report.
3. Now the harder case: should `returned` orders count? Argue both sides in two sentences,
   then pick one and say what you'd tell Finance.

**The check:** before aggregating any fact table, run
`SELECT status, count(*) FROM fct_order GROUP BY 1` — or the equivalent for whatever
categorical column it has. Every time. It takes four seconds and it is the highest-value
four seconds in analytics.

## Wrong number 2 — fan-out

4. Join completed orders to `bridge_order_promo` and sum `order_total`. Record the number.
5. Compute the correct promo-attributed revenue using `allocation_factor`.
6. Record: the row count of completed orders, the row count after the join, and the ratio.
   Explain the ratio in terms of promos per order.
7. Do the same thing with the SCD2 trap: join `fct_order` to `dim_customer` **without**
   `is_current` and count rows. Then with. Report both.

**The check:** count rows before and after every join, and be able to explain any change.
A join that multiplies rows is not always wrong — but it is always a decision, and if you
didn't make it deliberately, it made it for you.

## Wrong number 3 — the average of averages

8. Compute the average line amount per category. Then average those five numbers.
9. Compute the true average line amount across all lines.
10. Report both, the difference, and the reason — look at the volume of each category
    alongside its average.
11. Write the general rule in one sentence: when is it legitimate to average an average?

**The check:** never average a column that is itself an average. Keep the numerator and
the denominator, sum both, divide once at the end.

## Wrong number 4 — distinct counts that don't add up

12. Count distinct customers who placed a completed order, by segment. Sum those three
    numbers. Now count distinct customers who placed a completed order overall. **The
    numbers disagree** — find out why. (Hint: `dim_customer` has 1,302 rows for 1,200
    customers.)
13. Fix it two ways: by counting `customer_id` instead of `customer_sk`, and by filtering
    to `is_current = 'Y'`. Do the two fixes agree? Should they?
14. Write down which of the two you'd use for "how many customers bought from us in 2026",
    and which for "how many enterprise customers bought from us in 2026". They may not be
    the same choice.

**The check:** a distinct count is not additive. If your segment counts sum to more than
your total, you have a grain problem, not a rounding problem. Always sanity-check that the
parts sum to the whole — and when they don't, find out why before you publish either.

**Go back and check three earlier answers.** This exact trap — the versioned `customer_sk`
standing in for a person — was hiding, unlabeled, in three questions you already answered:
Q03 question 12 (top 10 customers by order count), Q05 question 4 (average orders per
customer by segment), and Q06 question 10 (days between a customer's orders). None of those
three told you anything was wrong. Open your saved queries for all three now — did you
group or partition by `customer_sk`, or by `customer_id`? If it was `customer_sk`, your
numbers there under- or over-counted exactly the way this section just demonstrated. Fix
the ones that need it before moving on; this is the whole lesson of the assignment, applied
to your own prior work instead of a fresh example.

## The fifth thing: reconciliation

15. For completed orders, compute `SUM(order_total)` and `SUM(line_amount)`. They differ.
    Account for the difference: discounts, shipping, and one more thing.
16. Find the orders where `order_total ≠ SUM(line_amount) − discount + shipping`. How many
    are there? There are **two different causes** and roughly half the rows belong to each.
    Identify both.
17. Write the sentence you'd put in a report footnote about which figure you used for
    revenue and why.

## Check yourself

| # | Expected |
|---|---|
| 1 | all statuses **16,922,496.96** · completed **14,201,609.13** → **+19.2%** overstatement |
| 4–5 | naive promo join **5,075,682.37** · allocated **3,787,250.73** → **+34%** |
| 6 | completed orders 46,460 → after the bridge join **12,296 orders become 16,528 rows** |
| 7 | orders joined to `dim_customer` without `is_current`: **59,307** vs **54,583** with the correct key → **+8.7%** |
| 8–9 | average of category averages **244.17** · true average line **183.49** → **+33%** |
| 12 | segment distinct counts 839 + 281 + 138 = **1,258**; distinct customers overall = **1,258** by `customer_sk` but **1,200** by `customer_id` |
| 16 | **2,218** orders don't reconcile: **1,147** because the discount was applied but recorded as NULL, **1,071** because of a genuine order-level adjustment |

## Your deliverable

A file `answers/q07_checks.md` containing five checks, written as things you *do*, not
things you know:

1. …before aggregating a fact table.
2. …before and after every join.
3. …whenever a metric is a ratio or an average.
4. …whenever a number is broken down into parts.
5. …before publishing any revenue figure.

Keep this file. It's the most portable thing you'll produce in this lab — it applies to
every warehouse you ever touch, and re-reading it before a deadline is a two-minute habit
that will save you from the one wrong number that would otherwise define your first six
months.

## Common beginner mistakes

- Producing the four wrong numbers, seeing they're wrong, and not writing the checks. The
  numbers are the exercise; the checks are the point.
- Assuming a 19% error would be obvious. It isn't. 14.2 million and 16.9 million both look
  like plausible annual revenue for this business.
- Deciding the naive promo number is "close enough". It's 34% out and it's the number
  someone will use to renew a promo programme.
- Treating the returned-orders question as technical. It's a definition question, and the
  answer belongs to Finance, not to you. Your job is to notice it needs asking.
- Fixing the distinct-count problem with `SELECT DISTINCT` somewhere and moving on without
  understanding that the dimension is versioned.

## Oracle note

Every trap here is dialect-independent, because none of them is about syntax. Two Oracle
specifics worth carrying: `SUM()` over a fan-out join is exactly as wrong there, and
Oracle's `NUMBER` type is decimal rather than binary floating point, so you will not see
the tiny rounding drift that catches people out in engines using floats — reconciliations
in Oracle usually tie to the cent, which means a difference of 0.01 there is a real
difference and worth chasing rather than shrugging at. Also, an Oracle warehouse very
often has an `is_current`-style flag *and* `valid_from`/`valid_to` dates on its dimensions,
and using the dates gives you the point-in-time answer while the flag gives you the
current-attribute answer. Those are different questions; ask which one is wanted.

## Stretch

1. Build one query that returns all four wrong numbers and their correct counterparts side
   by side, as a four-row "audit" result — `UNION ALL` the four independent metric queries
   together (never plain `UNION`; there's nothing to deduplicate, and it would hide two
   metrics that happened to land on the same number). Save it; run it any time you inherit
   somebody else's revenue query.
2. Find a fifth trap in this dataset that isn't listed here, quantify it, and write its
   check. (There are several. The closed store and the nine never-sold products are two
   places to look.)
3. Take any query from Q02–Q06 and try to break it deliberately — remove a filter, change a
   join. Note which of your five checks would have caught it. If none would, add a sixth.
4. **A sixth wrong number: the one that doesn't error.** Group returned line revenue by
   category and by day, and compute the average value of a returned line
   (`returned_revenue / returned_lines`). Most category/day combinations have zero returns
   — find one. What does your query return for it, and is it a number or `nan`? Fix it with
   `NULLIF(returned_lines, 0)` in the denominator, and add a sixth check to your list:
   *"does this ratio have a real denominator, or could it legitimately be zero?"*
   [`reference/advanced_sql.md`](../reference/advanced_sql.md#nullif--the-deliberate-controlled-null)
   has the full worked example.
