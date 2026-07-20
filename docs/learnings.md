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
- **Fabric's native Git integration is Azure DevOps-first** — in Workspace Settings → Git integration, Azure DevOps is selectable but GitHub appears grayed out by default. GitHub support exists in Fabric but requires tenant-level enablement (Admin Portal → Tenant Settings) and/or a capacity tier beyond trial. Relevant for any team using GitHub as their primary repo and planning a Fabric migration — native version control doesn't "just work" out of the box the way it might be assumed to.
- **Fabric governance has two distinct layers that don't substitute for each other:** (1) data access control — e.g., "Authenticate with OneLake user-delegated SAS tokens" (Workspace Settings → Delegated Settings → OneLake settings), off by default, which governs whether apps can authenticate directly against OneLake storage using short-lived delegated tokens rather than the normal Fabric permission model; and (2) AI feature governance — e.g., "Only show approved items in standalone Copilot" (Delegated Settings → Copilot and Azure OpenAI Service), off by default, which curates what appears in the standalone Copilot experience. Important nuance: Copilot item usage is always subject to user permissions regardless of this toggle — the approval setting is a curation/UX control, not itself a security boundary.
- **The Fabric SQL analytics endpoint lags behind Delta table writes** made via Notebook/Spark (and, separately, after a source Azure subscription is disabled/re-enabled) — sometimes by several minutes. A `spark.table(...).count()` run directly in a Notebook reads the Delta transaction log and is authoritative immediately; the SQL analytics endpoint (used by SSMS and the Fabric portal's SQL query view) maintains a separate metadata cache that syncs asynchronously. Seeing stale row counts in the SQL endpoint right after a write is expected async behavior, not a failed write — verify against the Notebook/Delta layer directly if the numbers don't match.
- **The Fabric SQL analytics endpoint is read-only for DML, not just DDL** — `INSERT`/`UPDATE`/`DELETE` against a Lakehouse table fail through that connection. Deduplicating or otherwise modifying rows in a Lakehouse Delta table requires a Notebook (PySpark), e.g. `df.dropDuplicates(["key_col"]).write.format("delta").mode("overwrite").saveAsTable("table")`. This is a real, load-bearing distinction between Lakehouse (Delta files behind a read-only SQL endpoint) and Warehouse (full read/write T-SQL) — confirmed the hard way today rather than just read about it.
- **`dropDuplicates([col])` keys on the named column(s) only** — any row sharing that value is treated as a duplicate and all but one copy is dropped. Passing no arguments instead requires a full-row exact match across every column. Which duplicate row survives is otherwise arbitrary unless the DataFrame is explicitly ordered first (e.g., by a load timestamp) before calling it — irrelevant when duplicates are byte-for-byte identical (as today's were), but essential to get right in a real upsert/merge scenario where "duplicate key, different values" is possible.
- **A rolling "last N days from MAX(date)" watermark is not a safe incremental-load filter on its own** — it has no memory of what was already loaded, so re-running the same pipeline re-pulls and re-appends rows that are already present, producing primary-key duplicate violations downstream (surfaced today as a Power BI load error on `claims[claim_id]`). A real incremental pattern needs a control mechanism — e.g., a watermark table storing the last-loaded key/date — so the source query filters strictly to what hasn't been loaded yet, not just "recent" by some floating definition. Tightening the filter to a fixed cutoff date (`WHERE service_date > 'X'`) worked as a same-day stopgap; the watermark-table fix is a named follow-up.
- **The watermark-table follow-up above was completed (Week 5 Wednesday)**, and building it surfaced a genuine architectural bug worth its own entry: a 4-activity chain (`LU_Get_Watermark` → `LU_Get_New_Max_Date` → Copy Data → `SCR_Update_Watermark`) reads the last-loaded date from a control table, uses it to find the true new max date, copies the incremental rows, then writes the new watermark back — closing the loop the fixed-cutoff stopgap couldn't. The first build attempt failed with **"Cannot insert the value NULL into column 'last_loaded_date'"** because the watermark-update step's `SELECT MAX(service_date) FROM claims` query ran against the **Warehouse's** copy of `claims` — a static snapshot from an earlier week that was never touched by this pipeline (the pipeline's Copy Data activity writes to the **Lakehouse**, not the Warehouse) — so the filtered query matched zero rows and `MAX()` returned NULL. The fix was adding a dedicated Lookup activity (`LU_Get_New_Max_Date`) that queries **Azure SQL** directly — the actual source of truth for `claims` — rather than either Fabric copy. General lesson: in an environment with the same logical table name existing in multiple physical stores (Azure SQL source, Lakehouse, Warehouse), every read needs to be deliberate about *which* copy it's hitting; "a table called `claims`" is not a single unambiguous reference once a project has more than one landing zone for it.
- **Registering a connection under "Registered Servers" in SSMS** (`View → Registered Servers` → right-click "Local Server Groups" → New Server Registration) gives it a permanent friendly alias for future connecting — but Object Explorer itself always displays the real server address once connected, never the alias. Registered Servers is a launcher, not a renamer.
- **A Fabric Warehouse Copy Data activity's "Auto create table" destination option infers schema directly from the source query** (column names, data types, nullability, and lengths) — no manual `CREATE TABLE` DDL needed for a first-time load. Combined with **"Upsert" write behavior and a specified key column**, this gives a clean full-reload pattern for static/reference tables (e.g., `providers`, `network_contracts`) without a separate truncate step: re-running the pipeline updates existing rows and inserts new ones by key, rather than appending duplicates the way plain "Insert" would. This is a different — and simpler — pattern than the incremental-watermark approach needed for a transactional table like `claims`, since reference data has no natural "new since last load" boundary to filter on.
- **Fabric Warehouse's `CREATE TABLE` has a narrower T-SQL surface than Azure SQL/on-prem SQL Server in several DDL areas**, discovered across three separate errors while building a `pipeline_watermark` control table: (1) `DEFAULT` constraints are not supported at the column-definition level (previously documented, Week 2); (2) the `PRIMARY KEY` keyword is rejected — uniqueness must be enforced at the application/pipeline logic layer instead of the schema layer; (3) `DATETIME2` requires an explicit precision argument (e.g. `DATETIME2(3)`) rather than accepting the bare type the way SQL Server does. None of these are documented as a single consolidated list anywhere obvious — each surfaces individually as a runtime error only when attempted, making this a "learned it by hitting it" finding rather than something read in advance. Directly relevant to a Fabric migration conversation: schema/DDL scripts written against Azure SQL or on-prem SQL Server are not guaranteed to run unmodified against a Fabric Warehouse target.
- **A fourth Fabric Warehouse DDL gap, found while drilling a throwaway self-join exercise table: `IDENTITY` columns must be typed `BIGINT`, not `INT`.** `IDENTITY(1,1)` on an `INT` column fails with `Identity column 'employee_id' must be of data type BIGINT` — a distinct, separate constraint from the already-documented lack of `PRIMARY KEY` support. Switching to `BIGINT` requires matching the type on any referencing column too (e.g. a self-referencing `manager_id`), since comparing mismatched integer types in a join, while often implicitly tolerated, isn't reliable practice. The simpler fix for a small, manually-populated table is to skip `IDENTITY` entirely and assign IDs directly in the `INSERT` statement.
- **`.write.format("delta").mode("overwrite")` merges the incoming schema with the existing table's schema by default rather than replacing it outright**, and fails with `[DELTA_FAILED_TO_MERGE_FIELDS]` if the two don't reconcile cleanly (e.g. a subtle type mismatch on a column like an ID field). Adding `.option("overwriteSchema", "true")` tells Delta to fully replace the schema along with the data — necessary any time the write is meant to be a genuine full replacement, not just a row-level refresh. `.option()` arguments are always passed as string key/value pairs (`"overwriteSchema"`, `"true"`), even for what's conceptually a boolean — a Spark API convention, not a Python typing choice.

---

## Azure Subscription & Connection Management

- **An Azure free trial's billing ownership belongs to the personal Microsoft Account (MSA) that originally created it, not the Entra ID admin account built afterward for daily work.** When the trial subscription showed zero billing scopes and zero subscriptions under the everyday Entra ID login (`charles@cerjr2yahoo.onmicrosoft.com`), the actual owner turned out to be the personal MSA (`cerjr2@yahoo.com`) used at initial signup. This is normal Azure structure, not a misconfiguration — worth checking first, before assuming access was lost or revoked, if a normally-working account suddenly shows no subscriptions.
- **A disabled/expired Azure subscription takes every resource under it offline identically across every client** — Fabric pipeline, SSMS, everything — producing SQL error 40925 ("cannot connect to the database in its current state"). This is a platform-level outage, not a firewall or credential problem, and firewall/networking settings should be checked only after subscription status is confirmed healthy.
- **After reactivating a subscription, database connectivity can return with a different error entirely** — SQL error 40613 ("not currently available, please retry") — reflecting normal warm-up/propagation delay, distinct from 40925's hard platform-level block. If 40613 persists well beyond a reasonable warm-up window, the more likely cause is a stale cached credential in the connecting tool (see below), not continued unavailability.
- **A connection's saved credential can go stale after the underlying subscription is disabled and re-enabled**, even though the password itself hasn't changed — manifesting as a `WebRequestTimeout` (the request hangs and never gets a response, rather than failing fast with an auth error). Fix: open the connection's Edit dialog and retype the password from scratch, even though the masked field appears unchanged. A visually identical masked password can still be holding a stale token underneath.

---

## Power BI & DAX

- **DAX measures must be formatted at the measure level** (Modeling ribbon) for consistent display across all visuals.
- `LEFT JOIN` on diagnosis is essential — some ICD-10 codes in claims don't exist in the diagnosis lookup table. Always validate join coverage before filtering on a lookup join.
- **Always validate sample size before drawing conclusions** — e.g., 31 out-of-network claims vs. 521 in-network is not a statistically meaningful basis for rate comparison.
- **`RELATED()` in DAX can fail** despite existing relationships — `NOT ISBLANK()` is a reliable workaround for checking cross-table values.
- **`NULLIF` pattern for safe division in DAX:** `DIVIDE([numerator], [denominator])` is the preferred DAX equivalent of `NULLIF` — handles zero denominators without errors.
- **Filter context, demonstrated live:** built a table visual (`providers[provider_name]` + a `RANKX` measure) next to a `claim_status` slicer. Toggling the slicer between Denied/Pending/Approved/All produced four completely different provider rankings from the exact same, unedited DAX formula. This is the concrete behavior "filter context" refers to — a measure re-evaluates based on whatever's currently filtering the visual around it, without the formula itself changing. Confirms the "build it live and observe" approach is the right way to internalize this over memorizing the definition.
- **`RANKX(ALL(providers[provider_name]), CALCULATE(SUM(claims[billed_amount])), ,DESC, Dense)`** — `ALL()` only clears filters on the exact column(s) named inside it. It did not clear the `claim_status` slicer filter (a different column), which is exactly why the ranking still correctly responded to the slicer in the demo above. Easy to misread `ALL()` as "clear everything" — it's scoped to what's passed in.
- **`CALCULATE(SUM(...))` inside `RANKX` triggers context transition** — each row RANKX evaluates gets treated as its own temporary filter context (equivalent to a slicer click for just that one row), which is what makes the `SUM` compute a per-provider total instead of summing indiscriminately across the whole table. This is the same context-transition mechanism behind `CALCULATE` generally, seen here in a second, concrete application beyond the original time-intelligence measures.
- **`SWITCH(TRUE(), condition1, result1, condition2, result2, ..., default)`** is required (over the simpler `SWITCH(expression, value1, result1, ...)` form) whenever any branch needs an arbitrary boolean test — e.g. `ISBLANK(...)` or set membership via `IN {...}` — rather than a plain equality check. The repeated `SELECTEDVALUE(...)` calls across branches can be eliminated by capturing it once in a `VAR` and referencing the variable in each condition; DAX's `IN {...}` operator (SQL's `IN` equivalent) can also collapse multiple equality branches that share the same result into one condition.
- **DAX line breaks are cosmetic only** — `SWITCH(...)` (and any DAX function) is a single comma-separated argument list; formatting each `condition, result` pair on its own line is purely for human readability, not a syntactic requirement the way SQL's clause structure is.
- **`ALLEXCEPT` requires a minimum of two arguments — a table and at least one column to preserve.** Calling it with just a table name (intending to clear every filter on that table) throws `Too few arguments were passed to the ALLEXCEPT function`. `ALL(table)` is the correct function when the goal is to clear every filter on a table with nothing preserved; `ALLEXCEPT(table, column)` is for the case where one or more specific columns should keep respecting their current filter while everything else on that table is cleared. Built `Denial Rate % of Total` (`CALCULATE([Denial Rate %], ALL(providers))`) as a working example — every row shows the same company-wide rate regardless of which provider, specialty, or network status filters are active, while date/payer slicers (on separate tables) continue to apply normally.

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

- **`claims.denial_reason`'s 81.34% NULL rate is structurally expected**, not a data quality gap — Pending and most Approved claims correctly have no reason. However, one Approved claim (claim_id 14) has `denial_reason` populated with non-denial text ("Billed amount corrected"), revealing the column is overloaded to also capture general claim adjustments. See `docs/denial_reason_null_investigation.md` for full methodology. Implication: `denial_reason IS NOT NULL` is not a reliable proxy for "this claim was denied" in this schema.

- **Top denial reason:** Duplicate Claim — 24 denials (23.5% of all denials). An operational submission issue, not a clinical or coding error.
- **Second denial driver:** Coding Error — 22 denials (21.6%).
- **Orphaned records:** 20 claims reference ICD-10 codes with no match in the diagnosis lookup table (8 rows vs. 20+ distinct codes in claims) — a known data gap, not a query bug.
- **Zero true duplicate claim records** found via `GROUP BY` + `HAVING COUNT(*) > 1`, despite duplicate claims being the top denial reason — confirms payer adjudication catches near-duplicates upstream of the database.
- **Claims summary (Week 2):** Approved — 6 claims, $29,730 total billed; Denied — 4 claims, $11,260 total billed.
- **Same-member claim pairs within 7 days of each other:** 77 pairs (~14% of claims), of which only 5 (6.5%) share the same provider — the group actually worth duplicate-billing scrutiny. None of those 5 show matching or near-identical billed amounts, ruling out exact duplicate billing; one pair (claims 176/181) shares a same-day, same-provider service date with different amounts, most consistent with two distinct services billed separately. No true duplicate claims found — the self-join screening query functions as a triage tool, not a duplicate list. See `docs/claims_near_duplicate_investigation.md`.
- **Two live data-quality issues caught in the Lakehouse mid-week, both fixed via PySpark before reaching a published artifact.** (1) `payer` had never been re-synced after Azure SQL's payer names were scrubbed to fictional labels — the Lakehouse copy still held the original real company names, surfaced only when a routine refresh was run ahead of publishing a Power BI App. Fixed with a full `overwrite` write of the corrected 8-row reference set. (2) The same refresh then failed with a `claim_id` uniqueness violation — `claim_id 1319` had four fully identical duplicate rows in the Lakehouse `claims` table (likely from a watermark pipeline re-run edge case around the same date boundary documented above), fixed via `dropDuplicates()`. General lesson: a scheduled/routine refresh is a real data-quality checkpoint in its own right, not just a mechanical step — both issues were pre-existing and silent until a refresh forced them to surface.
