# Q05 — Journal

## What I learned

A CTE has to be followed directly by the SELECT that uses it. A semicolon in between kills it, and in DuckDB it also doesn't carry over to the next statement. I ran `SELECT COUNT(*) FROM completed_orders` on its own and got "table does not exist". Each query needs its own `WITH`.

Scalar subquery vs JOIN: a scalar subquery must return exactly one row. In Q4 both CTEs had one row per segment (3 rows), so `(SELECT ... FROM cte)` errors. Once the two CTEs share a column (segment), the right tool is a JOIN on it. Result: 37.54 / 35.33 / 31.39 orders per customer.

Q6 gave 40 with NOT EXISTS and 0 with NOT IN. fct_order.customer_sk has NULLs (guest orders), and one NULL in the list makes NOT IN return nothing. No error, just an empty result that looks like an answer. I also started that query from fct_order instead of dim_customer, which answers a different question.

Q11 gives 27 when grouped by customer_sk, which matches the key, and 0 when grouped by customer_id. All 27 are existing customers who changed segment in 2026, so they are new versions, not new people.

## What was hard

Reading what a row is at each step. Several wrong queries ran fine and returned plausible numbers (1,160 in Q7, the top 10 in Q8). Also the trailing comma before FROM, which I made again and again.
