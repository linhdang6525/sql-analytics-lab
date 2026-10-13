# Q08 — Real questions

**Est. time:** 4h · **Difficulty:** ⭐⭐⭐⭐ · **Requires:** Q07, including your five checks

## Why this matters

Nobody at work will ask you for "completed revenue by category for 2026 H1, excluding
cancelled orders". They will ask "which category makes us the most money?" and then look
at you.

The gap between those two sentences is the job. This assignment is eight real requests,
phrased the way people actually phrase them. Three of them are ambiguous in a way that
changes the answer materially, one has a trap you met in Q07, and one has an honest answer
of "that's zero, and here's why that's worth knowing".

## The format

For each question, produce all six of these. The query is the least of them.

1. **The restated question** — what you think they mean, in one sentence, specific enough
   to argue with. ("Revenue means completed orders only, comparing 2026 H1 with 2025 H1.")
2. **The metric definition** — which table, which filter, which measure, what's excluded.
3. **The query** — saved in `answers/q08.sql`, with the question number as a comment.
4. **The number.**
5. **One sentence of meaning** — what it tells the person who asked.
6. **The caveat** — what the number does not cover, or what you had to assume. If there
   genuinely isn't one, say "none" and be ready to defend that.

Put all of it in `answers/q08_answers.md`. This document is your deliverable and the thing
your mentor will review.

## The requests

> **1. Dana (COO):** *"Simple question — is the business growing?"*

Careful. There are three defensible comparisons in this data and one of them is badly
misleading. Give her the right one, and say why you didn't give her the other.

> **2. Marc (CFO):** *"What was our revenue last year? I need one number for the board."*

"Last year" is not one thing here. Give the number he needs, name the period explicitly,
and flag the one comparison he must not make with it.

> **3. Ingrid (Head of Retail):** *"Which store is our worst performer? I'm making a
> decision about it next week."*

The obvious query gives an answer that is arguably unfair to one store. Find out why, and
give her both figures with a recommendation.

> **4. Femi (Marketing):** *"Which promo code drove the most revenue? We're deciding what
> to run again."*

You met this in Q07. Give him a number he can act on, and one sentence on what "drove"
can and cannot mean from this data.

> **5. Sara (Merchandising):** *"Which category makes us the most money?"*

There are two honest answers and they're different categories. Give both and explain the
distinction in a sentence a merchandiser would use.

> **6. Tomas (Customer Service):** *"How bad is our returns problem? Is it getting worse?"*

Two questions in one. Answer both, and be careful with the second — Q04's lesson applies.

> **7. Sven (Sales):** *"Can you give me a list of customers who've stopped buying from
> us? I want to call them."*

Run it. Then read the result and decide what you actually tell Sven. There is a real answer
here and it is not the list he asked for.

> **8. Nadia (Finance):** *"How much did we give away in discounts last year?"*

The obvious query understates it, and you know exactly why from Q07. Give her a number, the
adjustment, and the sentence about data quality that she needs to hear before she uses it.

## Check yourself

Only after you've committed to your own answers.

| # | Key figures |
|---|---|
| 1 | 2025 H1 **4,476,125.75** → 2026 H1 **4,464,733.48** = **−0.3%**, essentially flat. Calendar 2025 (14.2M for 12 months) against 2026 (4.46M for 6) is the misleading comparison |
| 2 | Calendar 2025 completed revenue **9,736,875.65**; FY2025 in this data covers only **181 days** and is not a year |
| 3 | By total revenue **ST09** is last at **767,215.57** — but it closed on 2026-02-28 and had only **422** active days. Per active day it is **1,818.05**, which is mid-pack; the genuine laggard by that measure is **ST05** at **1,816.72** |
| 4 | Allocated: **BUNDLE15 494,884.03**, FREESHIP 489,954.52, SPRING10 487,095.21. The un-allocated join would have said 34% more |
| 5 | Highest revenue: **computing 4,016,974.03**. Highest margin: **outdoor at 44.3%** (computing is 42.4%) |
| 6 | Returned line revenue **605,959.72** = **3.41%** of line revenue. By category: home 3.70% down to computing 2.87% |
| 7 | Customers who ordered in 2025 but not 2026: **0**. Customers who have never ordered at all: **40** |
| 8 | Recorded discounts, calendar 2025 completed: check your own figure — total across the window is **710,532.11** (4.76% of gross), and **1,147** orders had a discount applied but recorded as NULL, so the true figure is higher |

## What good looks like

A strong answer to question 3 reads something like:

> **Restated:** worst-performing store, measured as completed revenue per day the store was
> actually trading, over the whole window.
> **Number:** by total revenue ST09 is last (767,216), but it closed on 2026-02-28 and only
> traded 422 of 546 days. Per trading day it makes 1,818 — thirteenth of fourteen, and
> within 5% of the pack. The lowest per-day performer is ST05 at 1,817.
> **Means:** there is no clear laggard; the spread between stores is under 30% and mostly
> explained by ST01 being unusually strong rather than anyone being weak.
> **Caveat:** revenue per trading day ignores store size and local market; if a decision
> hangs on this, we need floor area or headcount to normalise properly.

Note what that does: it answers the question, corrects the framing, refuses to name a
scapegoat the data doesn't support, and says what it would take to do better. That's the
whole job.

## Common beginner mistakes

- Answering the question as asked when the question as asked is ambiguous. Picking quietly
  is the failure; asking, or stating your assumption prominently, is the fix.
- Giving Dana the calendar-year comparison. It's a 54% "decline" that doesn't exist.
- Naming ST09 the worst store. Someone might act on that.
- Reporting the fan-out promo number.
- Answering "which category makes the most money" with revenue and never mentioning margin.
- Reporting the returns trend from month-on-month noise.
- Sending Sven an empty list with no explanation, or worse, sending him the 40 customers who
  never ordered as though they'd lapsed.
- Giving Nadia the recorded discount total with no caveat. It's understated, you know it's
  understated, and she's going to put it in a report.
- A number with no period attached. "Revenue is 14.2 million" is not an answer to anything.

## Oracle note

Nothing new syntactically — this assignment is about judgement. One practical Oracle habit
worth starting now: when you save these queries for reuse, put the metric definition in a
comment block at the top of each one, including the status filter and the period. In an
Oracle shop these queries end up in views or in a reporting tool, and the definition
travels with them or gets lost. `COMMENT ON TABLE`/`COMMENT ON COLUMN` exists for the same
reason and almost nobody uses it; being the analyst who does makes you noticeably easier to
work with.

## Stretch

1. Pick the two questions you found most ambiguous and write the actual message you'd send
   to that person to clarify — two sentences, specific, offering options rather than asking
   an open question.
2. Answer question 1 a fourth way: rolling twelve months. Does it change the story?
3. For question 6, build the returns trend properly — quarterly, year-on-year where
   possible — and decide whether you'd tell Tomas it's getting worse. Then write what
   evidence would change your mind.
4. **Build the grid Ingrid would actually want to see.** Question 3's per-store,
   per-trading-day figures are a strong finding, but they're wasted as one row per
   store per month. `PIVOT` your per-store-per-month revenue into one row per store,
   one column per month, so the seasonal pattern (and ST09's gap after it closed) is
   visible at a glance. Then `UNPIVOT` your own result back to long format and confirm
   you get exactly the rows you started with — if you don't, your `PIVOT`'s aggregate
   silently combined rows you meant to keep separate.
   [`reference/advanced_sql.md`](../reference/advanced_sql.md#pivot-and-unpivot--rows-to-columns-and-back)
   has the syntax.
