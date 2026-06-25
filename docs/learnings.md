# Key Technical Learnings

Principles learned, tested, and applied while building this environment — not copied from documentation.

---

## SQL Architecture & Query Design

- **SQL logical processing order:** `FROM` → `WHERE` → `GROUP BY` → `HAVING` → `SELECT` → `ORDER BY`. SELECT aliases cannot be referenced within the same SELECT clause — only in `ORDER BY` — because aliases are resolved after the SELECT list is evaluated.
- **CTEs are a readability tool, not a performance optimizer** — SQL Server inlines them before generating execution plans. Flat queries and CTEs compile to equivalent execution plans.
- **CTE design principle:** the CTE does the "dirty work" (aggregation, `CASE WHEN` logic, calculations); the main `SELECT` does the analysis (ranking, filtering, joining). This separation makes complex queries self-documenting.
- `HAVING` filters on aggregated results after `GROUP BY`; `WHERE` filters rows before aggregation. `WHERE COUNT(*) > 1` is invalid — it must be `HAVING COUNT(*) > 1`.
- `NOT EXISTS` is cleaner than `LEFT JOIN / IS NULL` for orphan-record checks, and often performs better on large datasets.
- `NULLIF(COUNT(col), 0)` prevents divide-by-zero errors — the `COUNT` argument must be a single expression.

---

## Window Functions

- `RANK() OVER (PARTITION BY col ORDER BY expr DESC)` — `PARTITION BY` resets the rank per group; `ORDER BY` inside `OVER` defines the ranking criteria.
- **Window functions don't collapse rows** — unlike `GROUP BY`, `RANK() OVER` keeps all rows intact and adds a ranking column alongside existing columns.
- `LAG()` returns NULL for the first row in each partition — expected behavior, not an error.
- `COUNT(DISTINCT col)` counts unique values — essential when one member can have multiple claims.

---

## Microsoft Fabric

- **The Fabric SQL analytics endpoint is read-only** — views are created via "Save as view" in the UI after selecting query text, not via `CREATE VIEW` DDL.
- **Direct Lake mode does not support SQL views** — only Delta tables stored in OneLake. Workaround: PySpark `saveAsTable()` or Import mode in Power BI.
- **Direct Lake requires exact data type matches** on relationship columns — mismatches silently break relationships without throwing an error.
- **Fabric Warehouse does not support DEFAULT constraints** in `CREATE TABLE` — hardcoded values are required in INSERT statements instead.
- **Lakehouse vs Warehouse:** the Lakehouse uses Delta files accessible via a read-only SQL endpoint; the Warehouse provides full read/write T-SQL — closer to a traditional SQL database. Both can feed Power BI via live semantic models.
- **Fabric trial SKU (F2)** has limited Spark compute — PySpark notebooks may hit capacity limits; Import mode is the practical fallback.

---

## Power BI & DAX

- **DAX measures must be formatted at the measure level** (Modeling ribbon) for consistent display across all visuals.
- `LEFT JOIN` on diagnosis is essential — some ICD-10 codes in claims don't exist in the diagnosis lookup table. Always validate join coverage before filtering on a lookup join.
- **Always validate sample size before drawing conclusions** — e.g., 31 out-of-network claims vs. 521 in-network is not a statistically meaningful basis for rate comparison.
- **`RELATED()` in DAX can fail** despite existing relationships — `NOT ISBLANK()` is a reliable workaround for checking cross-table values.
- **`NULLIF` pattern for safe division in DAX:** `DIVIDE([numerator], [denominator])` is the preferred DAX equivalent of `NULLIF` — handles zero denominators without errors.

---

## SSIS & ETL

- **SSIS Lookup transform routing:** the blue arrow (not orange) opens the Input Output Selection dialog for Match/No Match/Error path routing — the orange arrow routes to the default error output only.
- **SSIS Script Task language** must be set to VB.NET before clicking Edit Script — the language cannot be changed from C# after the VSTA editor opens.
- **VB.NET Imports** (`System.Windows.Forms`, `System.Data.SqlClient`) must be declared in the file-level Imports block above the class declaration, not inside `Sub Main()`.

---

## Databricks & PySpark

- **Databricks Serverless compute does not persist variables across cells** — each cell must be self-contained with `spark.read.csv()` re-declared. Classic compute is unavailable in Community Edition.
- **`saveAsTable()`** registers a DataFrame as a permanent Delta table in Unity Catalog — equivalent to `CREATE TABLE AS SELECT` in SQL.
- **Databricks Jobs** are the equivalent of SQL Agent jobs — scheduled notebook execution with configurable timezone and pipeline sequencing.
- **Pipeline sequencing pattern:** Databricks Job at 6AM (America/Chicago) → Power BI dataset refresh at 7AM — ensures the semantic model always reflects the latest data load.
- **`groupBy().agg()`** is the PySpark equivalent of `GROUP BY` with aggregate functions. `countDistinct(col)` maps to `COUNT(DISTINCT col)`.
- **`spark.read.json()`** reads newline-delimited JSON files into a Spark DataFrame — nested fields are flattened using `col("field.subfield")` or `explode()`.

---

## Python & Data Quality

- **Parameterized quality functions** accept any DataFrame, table name, and column name — the same 4 dimensions (Completeness, Uniqueness, Validity, Integrity) as the SQL audit queries, now reusable across any dataset.
- **JSON schema validation has no SQL equivalent** — Python's `required_fields` check per record flags missing fields before data enters the pipeline, catching structural issues that SQL constraints can't catch upstream.
- **Pass/fail threshold:** 95% was used as the standard across both the Power BI KPI scorecard and the Python consolidated quality report — consistent governance across tools.

---

## Power Automate

- **Event-driven vs scheduled triggers:** event-driven (file arrival) is the no-code equivalent of an SSIS file watcher / `SCR_CheckFileExists` task; scheduled triggers are equivalent to SQL Agent jobs.
- **M365 trial tenants** do not fully provision OneDrive for Business or Office 365 Outlook connectors — use the standard OneDrive connector (personal account) and Outlook.com connector instead.
- **Third-party cookie blocking** was the root cause of all OAuth authentication failures in Power Automate — enabling third-party cookies in Chrome resolved every connection issue.
- **`formatDateTime(utcNow(), 'MM/dd/yyyy')`** produces a dynamic date string for email subjects — the expression runs at trigger time, not authoring time.

---

## Data Quality & Governance

- **Four dimensions of data validation:** Completeness (NULLs), Referential Integrity (orphaned records via `NOT EXISTS`), Uniqueness (`HAVING COUNT(*) > 1`), and Validity (date range checks via `GETDATE()`/`DATEADD()`). All four implemented in both T-SQL and Python.
- **Duplicate claim denials** in the payer system don't necessarily mean duplicate records in the database — the payer's adjudication logic may catch and deny near-duplicate submissions before they create true database-level duplication.
- **Indexes speed up reads but slow down writes.** Index columns used in `WHERE`, `JOIN`, and `ORDER BY`. At small data volumes, the optimizer may still prefer a full table scan over an index seek.

---

## Findings from This Dataset

- **Top denial reason:** Duplicate Claim — 24 denials (23.5% of all denials). An operational submission issue, not a clinical or coding error.
- **Second denial driver:** Coding Error — 22 denials (21.6%).
- **Orphaned records:** 20 claims reference ICD-10 codes with no match in the diagnosis lookup table (8 rows vs. 20+ distinct codes in claims) — a known data gap, not a query bug.
- **Zero true duplicate claim records** found via `GROUP BY` + `HAVING COUNT(*) > 1`, despite duplicate claims being the top denial reason — confirms payer adjudication catches near-duplicates upstream of the database.
- **Claims summary (Week 2):** Approved — 6 claims, $29,730 total billed; Denied — 4 claims, $11,260 total billed.
