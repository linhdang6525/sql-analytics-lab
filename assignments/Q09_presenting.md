# Q09 — Making it stick

**Est. time:** 2h · **Difficulty:** ⭐⭐ · **Requires:** Q08

## Why this matters

Two analysts produce the same number. One writes it in a message, the number gets used, and
three weeks later nobody can reproduce it. The other saves the query with its definition,
publishes the number with what it excludes, and gets asked to do the next piece of work.

The difference isn't SQL. This assignment is the habits that make your work outlive the
afternoon you spent on it.

## What you need to know

**Readable SQL is a professional obligation, not a style preference.** Your queries get
inherited. The full checklist is in
[`reference/sql_style.md`](../reference/sql_style.md); the short version:

- One clause per line, keywords at the left margin, columns indented.
- Alias every table with something meaningful (`o`, `c`, `p` are fine; `t1`, `t2` are not).
- Qualify every column when there's more than one table.
- CTEs for steps, named for what they contain (`completed_orders`, not `cte1`).
- Comments say **why**, not what. `-- excludes cancelled and pending per Finance's
  definition` is useful; `-- filter status` is noise.
- A definition block at the top: what this answers, which filters, which period, who asked.

**A saved view is a definition everyone shares.** If three reports each re-implement
"completed revenue", they will drift. One view, used by all three, cannot.

```sql
CREATE OR REPLACE VIEW v_completed_orders AS
SELECT o.*, d.full_date, d.year, d.month, d.fiscal_year
FROM fct_order o
JOIN dim_date d USING (date_key)
WHERE o.status = 'completed';   -- money we actually took; excludes cancelled/pending/returned
```

**The same number, three audiences.** A stakeholder wants the implication. Another analyst
wants the definition and what worries you. Your manager wants the status and the decision
needed. Same number, three messages — and the test is whether they could act without
asking a follow-up you should have anticipated.

## Tasks

### 1 — Clean up one query *(20 min)*

Take the worst-formatted query you wrote in Q02–Q06. Reformat it to the style guide, add a
definition block, and put the before and after side by side in `answers/q09.sql`. Write one
line on what a reader gains.

### 2 — Build three views *(30 min)*

- `v_completed_orders` — completed orders joined to `dim_date`, with the status filter and
  a comment saying why.
- `v_order_lines` — line grain, joined to product and date, with category and subcategory.
- `v_customer_current` — one row per customer, current version only. Getting this right
  means nobody downstream can hit the SCD2 trap.

Then re-answer two Q08 questions using the views. Note how much shorter the queries get.

**Check:** `SELECT count(*) FROM v_completed_orders` must be **46,460**;
`v_customer_current` must be **1,200**.

### 3 — The analysis pack *(45 min)*

`answers/q09_pack.md` — a one-page document with five numbers, chosen from your Q08 work,
that you would send to the leadership team. For each: the number, the period, the one-line
definition, and one sentence of meaning. Plus a short "what these numbers don't tell you"
section at the end.

Rules: it fits on one page. Every number has a period attached. No number appears without
its definition. If two numbers could be confused with each other, name them so they can't
be.

### 4 — Three audiences *(20 min)*

Pick one finding from Q08 — the flat H1 growth is a good one. Write it three ways, in
`answers/q09_audiences.md`:

- **To Dana (COO)** — three sentences. What it means, what you'd watch next, no SQL.
- **To another analyst** — the definition, the filters, and the one thing that would change
  the number.
- **To your manager** — status, what you need, and any decision that isn't yours to make.

### 5 — Your own reference *(15 min)*

`answers/q09_snippets.sql` — the six to ten patterns from this lab you expect to reuse:
top-N per group, month-on-month with `LAG`, dedup with `ROW_NUMBER`, an anti-join, a
half-open date range, a safe distinct count. One comment line each saying when to reach for
it. If you did any of the Q06–Q08 stretch goals, this is also the natural place for a
`UNION ALL` audit-row pattern, an `EXCEPT`-based equivalence check, and a
`NULLIF(denominator, 0)` safe ratio — three more one-liners worth never re-deriving from
scratch. ([`reference/advanced_sql.md`](../reference/advanced_sql.md) has all three.)

This file is worth more to you in six months than everything else in the lab.

## Definition of done

- [ ] One query reformatted, before and after, with a note on what improved.
- [ ] Three views created; the two check counts match.
- [ ] Two Q08 answers re-derived from the views, same numbers.
- [ ] `q09_pack.md` — five numbers, one page, every number with a period and a definition.
- [ ] `q09_audiences.md` — three versions of one finding.
- [ ] `q09_snippets.sql` — your own patterns, commented.
- [ ] Reviewed with your mentor: 30 minutes, you walk them through the pack.

## The review

Your mentor will pick one number from your pack and ask three things: *where did this come
from*, *what does it exclude*, and *what would make it wrong*. That last question is the one
that matters, and you already have the answer — it's in your Q07 checks.

## Common beginner mistakes

- A pack with numbers and no periods. "Revenue: 14.2M" is not information.
- Two similarly-named numbers that mean different things ("revenue" and "sales") with no
  definition to tell them apart.
- Views that bake in a date filter, so they silently go stale.
- A view called `v_orders` that quietly excludes cancelled orders. Name it for what it
  contains: `v_completed_orders`.
- Comments that narrate the SQL instead of explaining the decision.
- Writing the stakeholder version with the analyst's content — grain, joins and filters in a
  message to a COO.
- Skipping the snippets file because you'll "remember". You won't; that's the point.

## Oracle note

Views work the same way (`CREATE OR REPLACE VIEW`), and in an Oracle shop they're where
metric definitions actually live, so getting into the habit here pays immediately. Two
things to know: a view is just a stored query, so it re-runs each time and inherits the
underlying tables' performance — if it's slow, that's a conversation with a data engineer
about a materialized view rather than something to fix in the view. And if you don't have
`CREATE VIEW` rights in the warehouse — you often won't as an analyst — the equivalent
discipline is a shared `.sql` file per metric in the team's repo, with the same definition
block at the top. The point is one definition in one place, whatever holds it.

## Stretch

1. Add a `v_revenue_monthly` view and rebuild one Q06 window query on top of it. Notice
   that the window function is now the whole query.
2. Write the "metric definitions" page for this business — revenue, order, customer,
   average order value, return rate — one paragraph each. Three of the five have a real
   ambiguity you met in this lab; name them.
3. Hand your pack to somebody who hasn't done the lab. Ask them what one of the numbers
   means. Whatever they get wrong is the sentence you need to rewrite.
4. **Prove a rewrite is equivalent, don't just eyeball it.** Pick any query you rewrote
   during this lab (a Q03 nested join you later redid with a Q05 CTE, say) where you
   checked the two versions agreed by comparing a count or a sum. Now check them
   row-for-row: `(old EXCEPT new) UNION ALL (new EXCEPT old)` should return zero rows.
   If it doesn't, your two versions agree on the aggregate by coincidence, not because
   they're actually the same query — find the diverging rows and explain them.
   [`reference/advanced_sql.md`](../reference/advanced_sql.md#set-operations-union-all-union-except-intersect)
   has the pattern.
