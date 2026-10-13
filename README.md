# PRISM — SQL for Analysts

A beginner lab for a new analyst. One small warehouse, ten assignments, and about
120 questions that all have exactly one right answer — which you can check yourself,
because the answer key has the numbers in it.

| | |
| --- | --- |
| **For** | A new analyst intern. No prior SQL required beyond having seen a `SELECT`. |
| **Difficulty** | ⭐ → ⭐⭐⭐⭐ (Q00 is an afternoon; Q07 is the one that separates analysts from query-writers) |
| **Est. total** | ~30 hours · 10 assignments · **about 1 week** with the lab as your only work |
| **Stack** | DuckDB (one data file; the CLI itself is a single no-installer download, with a built-in browser UI) — no separate SQL client required. Oracle dialect notes throughout, because that's what you'll query at work. |
| **Answers** | [`answers/ANSWERS.md`](answers/ANSWERS.md) — every number, with the query that produces it |

## What this lab is actually about

Writing SQL is not the hard part of analysis. The hard part is getting a number that
is **right**, knowing *why* it's right, and being able to say what it does and doesn't
mean when somebody asks.

So every assignment is a set of questions in plain language, and every answer is three
things: a query, a number, and one sentence about what the number means. A query that
runs and returns something plausible is not an answer — this dataset contains four
different ways to overstate revenue, and all four look completely normal in a result grid.

By the end you'll be able to take a vague question from someone in the business, work
out what they actually mean, get the number, and defend it.

## The data

A small retail warehouse: 18 months of orders, 1,200 customers, 180 products, 14 stores.
Nine tables, about 55,000 orders — small enough that every query returns instantly and
you can eyeball whether an answer is sane.

```
dim_date            one row per calendar date (2025-01-01 .. 2026-06-30)
dim_customer        one row per customer VERSION — a customer who changed segment has two
dim_product         one row per product
dim_store           one row per store
dim_promo           one row per promo code
fct_order           one row per order — including cancelled and returned ones
fct_order_item      one row per order line
bridge_order_promo  one row per (order, promo) — an order can carry up to three
raw_customer_list   a hand-maintained spreadsheet export, with all that implies
```

It's a normal star schema, of the kind you'll be handed at work. It is *not* clean:
there are guest orders with no customer, orders that were cancelled, discounts that
weren't recorded, products nobody ever bought, and a store that closed in February. All
of that is deliberate and all of it is discoverable.

## Course map

Do them in order. Each one assumes the SQL from the last.

| # | Assignment | You learn | Est. | ⭐ |
|---|---|---|---|---|
| [Q00](assignments/Q00_first_look.md) | First look | connecting, `SELECT`, exploring a schema you've never seen, working out each table's grain | 2h | ⭐ |
| [Q01](assignments/Q01_filtering.md) | Filtering & sorting | `WHERE`, `AND`/`OR`, `IN`, `BETWEEN`, `LIKE`, `ORDER BY`, `LIMIT`, `DISTINCT` — and what NULL does to all of them | 3h | ⭐⭐ |
| [Q02](assignments/Q02_aggregation.md) | Counting & summing | `COUNT`/`SUM`/`AVG`/`MIN`/`MAX`, `GROUP BY`, `HAVING`, `COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT)` | 3h | ⭐⭐ |
| [Q03](assignments/Q03_joins.md) | Joins | inner vs left, join keys, finding what's missing, and the row-count check that catches a bad join | 4h | ⭐⭐⭐ |
| [Q04](assignments/Q04_dates.md) | Dates & trends | the date dimension, month/quarter/fiscal periods, month-on-month, year-on-year, seasonality | 3h | ⭐⭐⭐ |
| [Q05](assignments/Q05_subqueries_ctes.md) | Subqueries & CTEs | scalar subqueries, `IN`/`EXISTS`, `WITH`, and turning a nested mess into something readable | 3h | ⭐⭐⭐ |
| [Q06](assignments/Q06_windows.md) | Window functions | `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, running totals, top-N per group, deduplication | 4h | ⭐⭐⭐⭐ |
| [Q07](assignments/Q07_traps.md) | Four wrong numbers | the traps: cancelled rows, join fan-out, average of averages, summed distinct counts — and how to catch yourself | 4h | ⭐⭐⭐⭐ |
| [Q08](assignments/Q08_business_questions.md) | Real questions | eight vague requests from real people; restate, define, answer, caveat | 4h | ⭐⭐⭐⭐ |
| [Q09](assignments/Q09_presenting.md) | Making it stick | readable SQL, saved views, an analysis pack, and telling three audiences the same number | 2h | ⭐⭐ |

## Quickstart

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

python datagen/generate.py            # builds data/prism.duckdb in about two seconds
python datagen/selftest.py            # confirms your copy matches the answer key
```

`pip install duckdb` gives you the Python package used above — it does not include the
`duckdb` command-line tool. Get that separately: it's a single executable, no installer,
no admin rights needed. Grab the Windows `duckdb-cli` zip from
[duckdb.org/docs/installation](https://duckdb.org/docs/installation), unzip it anywhere,
and put that folder on your `PATH` (or just `cd` there when you want it). You need this
for both the `duckdb` prompt and the `duckdb -ui` web interface below.

Then query it however you like:

```powershell
# the DuckDB web UI -- opens in your browser, easiest to start with
duckdb -ui data/prism.duckdb

# the DuckDB command line, if you prefer a terminal
duckdb data/prism.duckdb

# or from Python
python -c "import duckdb; print(duckdb.connect('data/prism.duckdb').sql('SELECT count(*) FROM fct_order'))"
```

`duckdb -ui` is built into the CLI executable you just unzipped — no separate app, no
account, no config. It launches a local web UI at `localhost` with a schema browser, a
query editor, and result grids, and it's the easiest way to start this lab. A dedicated
SQL client works too if you'd rather — DBeaver, DataGrip and VS Code all speak DuckDB —
but you don't need to install one just to get going.

Then open [Q00](assignments/Q00_first_look.md).

## How to work through it

1. **Write the query yourself before looking at anything.** Being stuck for ten minutes
   is how the pattern sticks. Being stuck for forty is a message; ask.
2. **Keep every query.** One file per assignment, `answers/q03.sql` style, with the
   question as a comment above each one. You'll reuse them constantly and it's the start
   of your own snippet library.
3. **Check your number against the answer key** *after* you've committed to an answer.
   If it differs, don't just copy the reference query — find out where yours diverges.
   That gap is the entire lesson.
4. **Write the sentence.** Every answer gets one line of plain English about what it
   means. It's the difference between running a query and doing analysis.
5. **Sanity-check everything.** Does the total look like a plausible number for this
   business? Did the row count change when you added that join? Is that average being
   dragged around by one enormous order? This habit is what you're really building.

## Reference

- [`reference/sql_lookup.md`](reference/sql_lookup.md) — links to the DuckDB SQL docs,
  a couple of beginner-friendly external SQL primers, and a one-line-each lookup table
  for every concept in the lab (what `HAVING` does, what a CTE is, etc.) with a pointer
  to the assignment that teaches it properly.
- [`reference/advanced_sql.md`](reference/advanced_sql.md) — optional, past Q06: `PIVOT`
  / `UNPIVOT`, window frames (`RANGE` vs `ROWS`, `EXCLUDE`), set operations (`UNION ALL`,
  `EXCEPT`, `INTERSECT`), and `NULLIF` for a denominator that can be zero. Each section
  is wired into a specific assignment's Stretch goals — not required for any Definition
  of Done.
- [`reference/sql_style.md`](reference/sql_style.md) — how to lay out a query someone
  else can read, and a checklist to run before you send a number to anyone.
- [`reference/oracle_notes.md`](reference/oracle_notes.md) — the dialect differences
  that will bite you when you move from this lab to our Oracle warehouse.

## For your mentor

[SPEC.md](SPEC.md) has the dataset contract, the planted traps with their exact counts,
and what to look for in each review. The natural checkpoints are after **Q03** (joins —
everything later depends on them), after **Q07** (the traps), and a 30-minute review of
the analysis pack at **Q09**.
