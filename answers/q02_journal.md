# Q02 — Journal
## What I learned

Redid % difference from Q01 — the denominator has to be completed_revenue (the number sent to the stakeholder), not all_status. Got it backwards once, had to slow down and think it through with a plain example.

Used scalar subqueries '(SELECT ...)' a lot this time — % difference, revenue share by channel, avg lines per order. Once I saw it as "compute one number first, then use it in the outer calc," it made sense.

Q4: average sat way closer to the min than the max. Turns out most orders are small, a few are huge, and AVG gets pulled toward wherever most of the data actually is — not the middle of min/max.

Also confirmed INNER JOIN + WHERE isn't redundant. ON decides how tables match, WHERE filters after — different jobs.

## What was hard

Lots of small syntax mistakes with subqueries — misplaced AS, wrong IN syntax, forgetting GROUP BY needs every non-aggregated column.