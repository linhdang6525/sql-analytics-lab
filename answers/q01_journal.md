# Q01 — Journal
## What I learned
Q4: orders with discount (26596) + without (26574) = 53170, but total is 55423. Missing 2253 rows have NULL discount_amount — not >0, not =0, just not counted in either unless you check for NULL directly.
Tried 'city = NULL' on purpose — returns 0 rows always, regardless of actual data. Have to use 'IS NULL'.
Said IN is "more efficient" than OR in Q3, got corrected — planner treats them the same, the real benefit is readability not speed.
Q10: same 2025-12-24 lookup works with 'date_key = 20251224' or a range on 'ordered_at', both give 150 rows. date_key is simpler — no range, no timezone to think about.