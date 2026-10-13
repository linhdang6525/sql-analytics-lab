# Q00 — First look

**Est. time:** 2h · **Difficulty:** ⭐ · **Requires:** nothing but a working install

## Why this matters

You will be handed a database you've never seen and asked a question about it within the
hour. The instinct to start writing the query immediately is the wrong one — you'll get an
answer that's confidently wrong because you didn't know what one row of the table meant.

Fifteen minutes of looking around first saves an afternoon of explaining a bad number.

## What you need to know'

**A star schema.** Facts and dimensions. A **fact** table holds things that happened —
orders, order lines — and is usually long and narrow, mostly numbers and keys. A
**dimension** table describes the things involved — customers, products, dates — and is
usually short and wide, mostly text. You join facts to dimensions to turn keys into words:
`fct_order` says `store_sk = 9`, and `dim_store` tells you that's Store 9 in NL-Central.

**Grain** is the single most useful idea in this lab. The grain of a table is what one row
means. `fct_order`'s grain is one order; `fct_order_item`'s is one line of one order. Get
this wrong and every number you produce is wrong in a way that's hard to see — you'll count
orders when you meant products, or double-count revenue and not notice.

**Surrogate keys.** `customer_sk` (a warehouse-generated number) is not `customer_id` (the
business's own identifier). They look interchangeable. They are not, and Q03 is where that
matters.

## Setup

If you haven't already (see the repo [README](../README.md#quickstart)), grab the
`duckdb` command-line executable — a single unzip, no installer — and generate the data:

```powershell
python datagen/generate.py       # ~2 seconds
python datagen/selftest.py       # confirms your data matches the answer key
duckdb -ui data/prism.duckdb     # opens a query editor in your browser
```

Prefer a terminal? `duckdb data/prism.duckdb` drops you at a `D>` prompt instead. Both
talk to the same file, so switch freely.

Useful DuckDB commands, in either one: `SHOW TABLES;` · `DESCRIBE fct_order;` ·
`SUMMARIZE fct_order;` (CLI only: `.quit` to exit).

Forgot what a keyword does, or want the full DuckDB SQL reference?
[`reference/sql_lookup.md`](../reference/sql_lookup.md) has links and a one-line
lookup table for everything in this lab.

Start a file `answers/q00.sql` and keep every query you write in it, with the question
number as a comment above it. Do this from the first assignment; you'll thank yourself in
Q08.

## Questions

Write a query for each. The answers are at the bottom — try first.

1. How many tables are in the database, and what are they called?
2. How many rows are in each of the nine tables?
3. What columns does `fct_order` have, and what type is each one?
4. Show the first 10 rows of `fct_order`. Then the first 10 *ordered by* `order_total`,
   largest first.
5. What are the earliest and latest dates in `dim_date`? How many days is that?
6. What distinct values appear in `fct_order.status`? In `fct_order.channel`?
7. How many distinct `customer_id` values are in `dim_customer`? How many rows does the
   table have? **They are not the same number — write down your best guess as to why.**
8. Pick one order id. Show that order, then its lines from `fct_order_item`, then its promo
   codes from `bridge_order_promo`. How many rows in each?
9. `SUMMARIZE fct_order_item;` — read the output. What's the largest `quantity` anyone
   ordered? Now do the same for `fct_order` — which column(s) have NULLs there, and
   roughly what share of rows?
10. Which columns would you use to join `fct_order` to `dim_customer`, `dim_store` and
    `dim_date`? Write the join conditions down without running them yet.

## The grain exercise

In `answers/q00_grain.md`, write one sentence per table: **"One row of X is one ..."**.
Nine sentences. Rules: no sentence contains the word "and" joining two different things,
and each sentence should be specific enough that someone reading only your sentence could
tell whether `SELECT count(*)` from that table answers "how many orders were there".

This takes twenty minutes and it's the most valuable thing you'll write today.

## Check yourself

| | Expected |
|---|---|
| Tables | **9** |
| `dim_date` rows / date range | **546** · 2025-01-01 to 2026-06-30 |
| `dim_customer` rows / distinct `customer_id` | **1,302** / **1,200** |
| `fct_order` rows | **55,423** |
| `fct_order_item` rows | **96,883** |
| `bridge_order_promo` rows | **19,572** |
| `dim_product` / `dim_store` / `dim_promo` / `raw_customer_list` | 180 / 14 / 8 / 1,269 |
| Distinct `status` / `channel` values | **4** / **4** |
| `fct_order_item` largest `quantity` | **5** (and no column in this table has any NULLs at all — that's a real finding, not a mistake) |
| `fct_order` NULL columns | `customer_sk` (840 rows, ~1.5%) and `discount_amount` (2,253 rows, ~4%) |

If your numbers differ, re-run `datagen/generate.py` — the data is deterministic, so
identical commands give identical data.

## Common beginner mistakes

- Writing the query before knowing what a row means. Everything else in this list is a
  consequence of this one.
- Assuming `fct_order` and `fct_order_item` are interchangeable because both have
  `order_id`.
- Treating `customer_sk` and `customer_id` as the same column with two names.
- `SELECT *` on a fact table with no `LIMIT`. Harmless here at 55k rows; at work it's how
  you get a call from a DBA.
- Not writing the grain sentences because they feel obvious. They're obvious right up to
  the moment you join two tables at different grains.

## Oracle note

`SHOW TABLES` becomes `SELECT table_name FROM user_tables;` (or `all_tables` for other
schemas). `DESCRIBE` works in SQL*Plus and SQL Developer; the portable version is
`SELECT column_name, data_type, nullable FROM user_tab_columns WHERE table_name = 'FCT_ORDER'`
— and note the table name is **upper case** there, because Oracle folds unquoted
identifiers to upper case. There's no `SUMMARIZE`; you profile by hand with `COUNT`,
`MIN`, `MAX` and `COUNT(DISTINCT ...)`, which is Q02. Instead of `LIMIT 10`, Oracle uses
`FETCH FIRST 10 ROWS ONLY` (12c and later) or `WHERE ROWNUM <= 10` (older, and it applies
*before* `ORDER BY`, which is a classic way to get the wrong ten rows).

## Stretch

1. Draw the schema on paper: boxes for tables, lines for joins, and write the grain inside
   each box. Photograph it into your notes. You'll refer to it for the rest of the lab.
2. `SUMMARIZE` every table and skim all nine. Note anything that looks odd — a NULL count
   you didn't expect, a minimum of zero, a maximum that seems too large. You're building
   the list of questions the rest of the lab answers.
