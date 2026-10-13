# Q04 — Journal

## What I learned

Fell into the exact same bug twice in one assignment: GROUP BY month without year silently merges Jan 2025 and Jan 2026 into one bucket. First time was question 11 — concluded "no months below 700k" when the real answer is 4 months, because merging two Januaries together pushed the combined total above the threshold. Second time was the average-month calculation for question 6 — got a completely different average (1.18M vs the real 789k) depending on whether year was in the GROUP BY. Same root cause both times: month numbers (1-12) repeat every year, so they're not a unique identifier on their own.

Question 9 taught me something I didn't expect: summing revenue for 10 holiday days vs 536 non-holiday days and comparing totals is meaningless — of course 536 days adds up to more. Had to divide by day count to get a fair "average per day" comparison, same fix as question 8 already required. Once I did that, the conclusion actually flipped: holidays average higher per day, not lower like the raw sum suggested.

H1 vs H1 (question 3) was a good contrast with just comparing full years (question 1) — 2026 only has 6 months of data, so comparing it to all of 2025 would always look like a decline. Comparing matching half-years gave a fair answer: basically flat, -0.3%.

Self-join for month-over-month (question 12) made sense once I stopped thinking of it as "joining two different tables" and started thinking of it as "the same table, read twice, lined up one month apart."

## What was hard

Catching that GROUP BY month alone silently merges years. It doesn't error, doesn't warn, just quietly gives a wrong number that still looks plausible — the exact kind of bug this whole lab keeps warning about.
