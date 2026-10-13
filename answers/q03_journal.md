# Q03 — Journal

## What I learned

Q1: LEFT JOIN and INNER JOIN gave the same count (55423) — not because they're the same thing, but because every order happens to have a valid store_sk. Good reminder that "same result" doesn't mean "same logic," it can just mean the data is clean.

Q4 vs Q12 taught me there's no single "always use LEFT JOIN" rule. Q4 (revenue by segment) needs LEFT JOIN + COALESCE so guest-order revenue doesn't vanish. Q12 (top 10 customers) is fine with INNER JOIN, because customers with zero completed orders were never going to rank in a top 10 anyway — dropping them changes nothing.

Q12 also had a sneaky bug I didn't catch myself at first: GROUP BY customer_id, segment splits a customer into two rows if they changed segment (SCD2 again), because a single person then has two different segment values across their two dim_customer rows. Fixed it by grouping only on customer_id, and pulling segment separately with MAX(CASE WHEN is_current='Y' THEN segment END) — the CASE turns the non-current row into NULL, and MAX just picks the one real value left.

Q8 was the one I got most wrong. I used LEFT JOIN on bridge_order_promo without filtering to completed orders — totally different question than what was asked, so my numbers (18M naive / 14M "real") didn't match the answer key at all (should've been ~5M / ~3.8M). The actual question only cares about orders that used a promo code at all, so INNER JOIN + WHERE completed was right.
## What was hard

Realizing "LEFT JOIN vs INNER JOIN" isn't a fixed choice per table pair — it depends on the actual question being asked about that join, every time.