# Key Technical Learnings

Principles learned, tested, and applied while building this environment — not copied from documentation.

## SQL Architecture & Query Design

- **SQL logical processing order:** `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`. SELECT aliases cannot be referenced within the same SELECT clause — only in `ORDER BY` — because aliases are resolved after the SELECT list is evaluated.
- **CTEs are a readability tool, not a performance optimizer** — SQL Server inlines them before generating execution plans. Flat queries and CTEs compile to equivalent execution plans.
- **CTE design principle:** the CTE does the "dirty work" (aggregation, `CASE WHEN` logic, calculations); the main `SELECT` does the analysis (ranking, filtering, joining). This separation makes complex queries self-documenting.
- **`HAVING` filters on aggregated results after `GROUP BY`**; `WHERE` filters rows before aggregation. `WHERE COUNT(*) > 1` is invalid — it must be `HAVING COUNT(*) > 1`.
- **`NOT EXISTS` is cleaner than `LEFT JOIN` / `IS NULL`** for orphan-record checks, and often performs better on large datasets.
- **`NULLIF(COUNT(col), 0)`** prevents divide-by-zero errors — the `COUNT` argument must be a single expression.

## Window Functions

- **`RANK() OVER (PARTITION BY col ORDER BY expr DESC)`** — `PARTITION BY` resets the rank per group; `ORDER BY` inside `OVER` defines the ranking criteria. Using a CTE alias in `ORDER BY` makes ranking intent immediately clear.
- **Window functions don't collapse rows** — unlike `GROUP BY`, `RANK() OVER` keeps all rows intact and adds a ranking column alongside existing columns.
- **`LAG()` returns NULL for the first row in each partition** — expected behavior, not an error.
- **`COUNT(DISTINCT col)`** counts unique values — essential when one member can have multiple claims.

## Microsoft Fabric

- **The Fabric SQL analytics endpoint is read-only** — views are created via "Save as view" in the UI after selecting query text, not via `CREATE VIEW` DDL.
- **Direct Lake mode does not support SQL views** — only Delta tables stored in OneLake. Workaround: PySpark `saveAsTable()` or Import mode in Power BI.
- **Fabric trial SKU (F2) has limited Spark compute** — PySpark notebooks may hit capacity limits; Import mode is the practical fallback when this happens.

## Power BI & DAX

- **DAX measures must be formatted at the measure level** (Modeling ribbon) for consistent display across all visuals.
- **`LEFT JOIN` on diagnosis is essential** — some ICD-10 codes in claims don't exist in the diagnosis lookup table. Always validate join coverage before filtering on a lookup join.
- **Always validate sample size before drawing conclusions** — e.g., 31 out-of-network claims vs. 521 in-network is not a statistically meaningful basis for rate comparison.

## Data Quality & Governance

- **Four dimensions of data validation:** Completeness (NULLs), Referential Integrity (orphaned records via `NOT EXISTS`), Uniqueness (`HAVING COUNT(*) > 1`), and Validity (date range checks via `GETDATE()`/`DATEADD()`).
- **Duplicate claim *denials* in the payer system don't necessarily mean duplicate *records* in the database** — the payer's adjudication logic may catch and deny near-duplicate submissions before they create true database-level duplication.
- **Indexes speed up reads but slow down writes.** Index columns used in `WHERE`, `JOIN`, and `ORDER BY`. At small data volumes, the optimizer may still prefer a full table scan over an index seek.

## Findings from this dataset

- **Top denial reason:** Duplicate Claim — 24 denials (23.5% of all denials). An operational submission issue, not a clinical or coding error.
- **Second denial driver:** Coding Error — 22 denials (21.6%).
- **Orphaned records:** 20 claims reference ICD-10 codes with no match in the diagnosis lookup table (8 rows vs. 20+ distinct codes in claims) — a known data gap, not a query bug.
- **Zero true duplicate claim records** found via `GROUP BY` + `HAVING COUNT(*) > 1`, despite duplicate claims being the top denial reason — confirms payer adjudication catches near-duplicates upstream of the database.
