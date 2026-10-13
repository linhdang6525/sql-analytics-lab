# Q04 — Dates & trends

**Est. time:** 3h · **Difficulty:** ⭐⭐⭐ · **Requires:** Q03

## Why this matters

Most questions an analyst gets are about time: is it up or down, versus what, and is
December's peak real or just December. Dates are also where the arithmetic is subtly wrong
most often — off-by-one-day ranges, comparing a part-year against a full one, and
"last month" meaning three different things to three people.

## What you need to know

**Why there's a date dimension.** You could extract month from a timestamp. `dim_date`
exists because it also knows things the timestamp can't: fiscal periods, holidays,
weekends, ISO week numbers. Join to it and those become filters instead of code.

**Joining it.** `fct_order.date_key = dim_date.date_key`, an integer like `20251224`. The
`date_key` trick (`date_key / 100` to get `202512`) works and is a hack: it breaks the
moment somebody wants a fiscal quarter, and it makes the query harder to read. Use the
dimension.

**Date ranges.** Prefer half-open intervals: `>= '2025-01-01' AND < '2025-02-01'`. Compared
with `BETWEEN '2025-01-01' AND '2025-01-31'`, the half-open version is right whether the
column is a date or a timestamp, needs no thought about the last day, and never silently
loses the orders placed at 14:30 on the 31st.

**Period-on-period.** Month-on-month compares adjacent months and is noisy — February is
short and January is post-Christmas. Year-on-year compares the same month a year apart and
cancels most seasonality. Comparing **like periods** is the entire skill: 2026 H1 against
2025 H1, not against all of 2025.

**Fiscal periods.** This business's fiscal year starts 1 July, so FY2026 runs
2025-07-01 → 2026-06-30. `dim_date.fiscal_year` and `fiscal_quarter` are already computed.
Note that the window only contains 181 days of FY2025 — so any FY2025 total is a partial
year, and reporting it next to a full FY2026 is exactly the mistake this assignment is
about.

## Questions

1. Completed revenue by calendar year. Why is 2026 so much lower? (Look at `dim_date`
   before you answer.)
2. Completed revenue by year and month, ordered chronologically. Which month is the
   highest?
3. Completed revenue for 2025 H1 versus 2026 H1. Is the business growing?
4. Completed revenue by quarter, with the year, for the whole window.
5. Completed revenue by fiscal year. How many days of each fiscal year does the data
   actually cover, and what does that do to the comparison?
6. Completed revenue for December 2025. How does it compare with the average month across
   the whole window?
7. What share of completed revenue happens at the weekend?
8. Which day of the week has the highest average revenue *per day*? (Careful: there are
   more of some weekdays than others in the window — divide by the number of days, don't
   just sum.)
9. How many public holidays are in `dim_date`? List them. Then: is revenue on a holiday
   higher or lower than on a comparable non-holiday? Say why your comparison is or isn't
   fair.
10. Orders placed on 2025-12-24 — count and revenue. Write the filter three ways
    (`date_key`, `dim_date.full_date`, and a half-open range on `ordered_at`) and confirm
    all three agree.
11. Which months had completed revenue below 700,000? Is there a pattern?
12. For each month of 2026, revenue and the change versus the previous month, in currency
    and as a percentage. (You can do this with a self-join now, or wait for `LAG` in Q06 —
    try the self-join, then compare.)

## Check yourself

| # | Expected |
|---|---|
| 1 | 2025 has 12 months, 2026 has 6 — the "drop" is calendar, not business |
| 2 | highest month is **2025-12** at **1,123,529.39** |
| 3 | 2025 H1 **4,476,125.75** · 2026 H1 **4,464,733.48** → essentially flat (**−0.3%**) |
| 5 | FY2025 covers only **181** days in this data; FY2026 covers all **365** |
| 6 | Dec 2025 **1,123,529.39** vs an average month of **~788,978** → about **+42%** |
| 7 | weekend share **22.8%** |
| 9 | **10** holidays in the window |
| 10 | 2025-12-24: **150** orders |
| 11 | Jan and Feb in both years: 690,755.96 · 606,791.52 · 677,269.45 · 637,776.58 |

## Common beginner mistakes

- Reporting "2026 revenue is down 54%" when 2026 only has six months of data. This is the
  single most common analytical error in existence and it has cost people their jobs.
- `BETWEEN` on a timestamp column, losing the last day's afternoon.
- Comparing December with November and calling it growth. Compare December with December.
- Averaging daily revenue across a group without dividing by the actual number of days in
  that group.
- Using `date_key / 100` to get a month and then being unable to answer a fiscal-quarter
  question without rewriting everything.
- Assuming the holiday list is complete. It has 10 entries and covers one country's
  holidays; if you're comparing Vietnam and Germany, that list is not doing what you think.
  Say so rather than quietly relying on it.
- Sorting a `year, month` result by `month` alone, so January 2026 appears before December
  2025.

## Oracle note

This is the area where Oracle differs most. `TRUNC(order_date, 'MM')` gives the first of
the month — the closest thing to `DATE_TRUNC('month', x)`. `ADD_MONTHS(d, -1)` and
`MONTHS_BETWEEN(a, b)` handle month arithmetic correctly, including month lengths;
`LAST_DAY(d)` gives the month end. Extracting parts: `EXTRACT(YEAR FROM d)` is standard,
`TO_CHAR(d, 'YYYY-MM')` is the common Oracle idiom for a month label, and `TO_CHAR(d, 'IW')`
gives the ISO week. Oracle's `DATE` type **includes a time component** even when it looks
like a date, which is exactly why `BETWEEN` bites there: a `DATE` of `2025-01-31` is
midnight, so anything later that day is outside the range. Use
`>= DATE '2025-01-01' AND < DATE '2025-02-01'` and stop thinking about it. `SYSDATE` is
Oracle's `now()`, and `TRUNC(SYSDATE)` is today at midnight.

## Stretch

1. Build a month spine from `dim_date` and left-join revenue to it, so a month with no
   sales appears as zero rather than vanishing. There is no such month in this data — prove
   that, which is the point.
2. Rolling 3-month average revenue by month. Self-joins make this painful; that pain is the
   argument for Q06.
3. Compute the same-store like-for-like comparison: 2026 H1 versus 2025 H1, excluding the
   store that closed. Does the flat number in question 3 change?
