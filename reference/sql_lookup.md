# Where to look things up

This lab teaches each concept properly, once, in the assignment that needs it — that's
what the "What you need to know" section at the top of every `assignments/QNN_*.md` is
for. This page is not another explanation. It's what to open when you've forgotten a
keyword mid-question and don't want to re-read a whole assignment to find it.

## DuckDB SQL documentation

The official docs are good, example-driven, and worth bookmarking now:

- **[SQL introduction](https://duckdb.org/docs/sql/introduction)** — overall syntax
  and statement types.
- **[Query syntax](https://duckdb.org/docs/sql/query_syntax/select)** — `SELECT`,
  `FROM`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT`, in full.
- **[Function overview](https://duckdb.org/docs/sql/functions/overview)** — every
  built-in function, searchable. If you're wondering "does DuckDB have a function for
  this", it's here.
- **[Window functions](https://duckdb.org/docs/sql/window_functions)** — the full
  reference for `OVER`, `PARTITION BY`, `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`, frames —
  the Q06 material, in more depth than one assignment can cover.
- **["Friendly SQL"](https://duckdb.org/docs/guides/sql_features/friendly_sql)** —
  DuckDB-specific conveniences used throughout this lab: `SUMMARIZE`, `FILTER`,
  trailing commas, `GROUP BY ALL`.

When you're stuck on *syntax* (which order do the clauses go in, what's this function
called), these are faster than asking someone. When you're stuck on *what query to
write* — that's what the assignment and your mentor are for.

## If SQL itself is still new

The lab assumes you've seen a `SELECT` before but doesn't assume much past that. If a
concept in an assignment's "What you need to know" section moves too fast, these are
solid independent primers for the underlying idea before you come back:

- **[Mode's SQL tutorial](https://mode.com/sql-tutorial/)** — a full beginner course,
  free, runs in the browser.
- **[W3Schools SQL](https://www.w3schools.com/sql/)** — quick, example-per-page
  reference for individual keywords; good for "remind me what `LIKE` does" rather than
  a from-scratch course.

## Concept lookup

One line each, and which assignment teaches it properly. Look here for "what does this
even do", then go to the assignment for "how do I use it correctly, and what mistakes
does it invite."

| Concept | One line | Taught in |
|---|---|---|
| `SELECT` / `FROM` / `WHERE` | Pick columns, pick a table, filter rows | [Q00](../assignments/Q00_first_look.md), [Q01](../assignments/Q01_filtering.md) |
| `COUNT` / `SUM` / `AVG` / `MIN` / `MAX` | The five aggregate functions — collapse many rows into one number | [Q02](../assignments/Q02_aggregation.md) |
| `COUNT(*)` vs `COUNT(col)` vs `COUNT(DISTINCT col)` | Rows, vs non-NULL values, vs distinct non-NULL values — three different claims | [Q02](../assignments/Q02_aggregation.md) |
| `GROUP BY` | Collapse rows into one row per distinct value (or combination) | [Q02](../assignments/Q02_aggregation.md) |
| `HAVING` vs `WHERE` | `WHERE` filters rows before grouping; `HAVING` filters groups after | [Q02](../assignments/Q02_aggregation.md) |
| `ORDER BY` / `LIMIT` | Sort the result; cap how many rows come back | [Q00](../assignments/Q00_first_look.md), [Q01](../assignments/Q01_filtering.md) |
| `DISTINCT` | Remove duplicate rows (or duplicate combinations, if you select several columns) | [Q01](../assignments/Q01_filtering.md) |
| `IS NULL` / `COALESCE` | NULL means "unknown" — it isn't equal to anything, including itself; `COALESCE` substitutes a value for it | [Q01](../assignments/Q01_filtering.md) |
| `INNER JOIN` / `LEFT JOIN` | Keep only matching rows, vs keep every left row and fill unmatched right-side columns with NULL | [Q03](../assignments/Q03_joins.md) |
| Anti-join (`NOT EXISTS`) | Find rows on one side with no match on the other — the NULL-safe way (never `NOT IN`) | [Q03](../assignments/Q03_joins.md) |
| Subquery (scalar, `IN`, `EXISTS`) | A query nested inside another, used as a value, a list, or a yes/no test | [Q05](../assignments/Q05_subqueries_ctes.md) |
| CTE (`WITH`) | Name a subquery as a readable step before your main query uses it | [Q05](../assignments/Q05_subqueries_ctes.md) |
| Window functions (`OVER`, `PARTITION BY`, `ROW_NUMBER`, `RANK`, `LAG`/`LEAD`) | Compute a value across related rows without collapsing them the way `GROUP BY` does | [Q06](../assignments/Q06_windows.md) |
| `CASE WHEN ... END` | Inline if/else logic inside a `SELECT` | used from [Q01](../assignments/Q01_filtering.md) stretch onward |
| Date functions (`DATE_TRUNC`, half-open ranges) | Grouping and filtering by calendar period correctly | [Q04](../assignments/Q04_dates.md) |
