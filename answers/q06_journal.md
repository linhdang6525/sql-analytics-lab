# Q06 — Journal

## What I learned

Window functions keep every row and add a column next to it, where GROUP BY collapses rows. In dedup (Q2) the three parts do three different jobs: PARTITION BY makes the groups, ORDER BY decides which row is number 1, and `WHERE rn = 1` throws the rest away. That filter has to sit outside a CTE, because window functions run after WHERE.

The ORDER BY inside OVER matters more than I expected. For dedup, `ORDER BY customer_id` does nothing, since every row in the group has the same customer_id and the row it keeps is arbitrary. `ORDER BY customer_name` is worse: capital letters sort first, so it keeps the ALL-CAPS row in all 69 pairs. I had to look at the duplicates to see that they only differ in letter case.

Moving average (Q8) went wrong two ways. `3 PRECEDING` is 4 rows, so three months is `2 PRECEDING`. And `ORDER BY month` (or `month, year`) lines up Jan 2025 next to Jan 2026 instead of three consecutive months. With the wrong ordering 13 of 18 values were wrong, and the Dec 2025 peak that drags Jan and Feb 2026 up disappeared. Year first, then month.

Q6 had a parenthesis bug: `(current - previous / previous) * 100`. The division runs first, previous/previous is always 1, and Jan 2026 came out as 67 million instead of -2.0%. Year-on-year is flat (-7.8% to +5.1%) and month-on-month for Jan 2026 is -39.7%, same data. So the Q12 drop is seasonality after the December peak, not a problem.

`LAG(x, 12)` is only right because the series has 18 months in a row with no gaps. With a missing month it would compare the wrong months.

Q4: adding `is_current = 'Y'` dropped about 595K of revenue (orders under old customer_sk values), and only 7 of the top 10 customers were the same. Group by customer_id and don't filter on is_current. Same idea in Q10, where I partition by customer_id so a customer's order history doesn't restart after a segment change.

Q4 also showed RANK, DENSE_RANK and ROW_NUMBER give the same top 10 here because nobody ties. With a tie, RANK skips a number (1,2,2,4), DENSE_RANK doesn't (1,2,2,3), ROW_NUMBER picks one.

Q9 gave 14.49% for the top decile when I group by customer_id (1,160 customers). The key says 15.5%, which is what you get by grouping by customer_sk (1,258 rows). Same thing as Q05 question 11: the answer depends on whether a customer is a person or a version of one.

## What was hard

Getting the order and frame inside OVER right. The wrong versions ran without errors and still returned plausible numbers. Also the trailing comma before FROM, again.

## Going forward

For anything over time, write ORDER BY year, month, and say out loud how many rows the frame covers. Before trusting a window result, check one customer or one month by hand. For "customer", decide whether it means customer_id or customer_sk before grouping.