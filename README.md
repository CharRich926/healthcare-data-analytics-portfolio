# Healthcare Data Analytics Portfolio

**Charles Richardson** | Healthcare Claims & Payer Analytics | June 2026

End-to-end healthcare data analytics environment — designed, built, and migrated from scratch. This repo contains the database architecture, SQL query library, ETL pipeline, Python data quality framework, Databricks notebooks, Power Automate flows, Power Apps canvas app, and Power BI reporting layer behind a claims denial analysis platform modeled on real payer/provider analytics workflows.

> **Note on Data:** All data used in this portfolio (claims, members, providers, diagnoses, authorizations, etc.) is synthetically generated for demonstration purposes only. No real patient, member, or provider information is used anywhere in this project. The goal of this portfolio is to demonstrate hands-on technical capability across the SQL Server, SSIS, Azure, Fabric, and Power BI stack — not to represent real healthcare analytics findings.

---

## What's in this repo

| Folder | Contents |
|---|---|
| [`sql/01_database_setup`](sql/01_database_setup) | Table DDL, indexes, schema design |
| [`sql/02_views`](sql/02_views) | 3 views — active providers, in-network filter, provider claim summary |
| [`sql/03_analytical_queries`](sql/03_analytical_queries) | Window functions, CTEs, peer benchmarking, utilization analysis, authorization approval rates |
| [`sql/04_data_quality_audits`](sql/04_data_quality_audits) | NULL audits, orphan record checks, duplicate detection, date validity |
| [`sql/05_stored_procedures`](sql/05_stored_procedures) | Stored procedures — member enrollment, claim filtering, provider termination, claim history, denial summary, high-dollar claim review |
| [`sql/06_indexing`](sql/06_indexing) | Non-clustered covering index on `authorizations`, plus verification script |
| [`sql/07_window_functions`](sql/07_window_functions) | `RANK()`/`DENSE_RANK()` ranking exercises |
| [`power-bi`](power-bi) | Dashboard screenshots, DAX measures, report description |
| [`ssis`](ssis) | ETL pipeline description, package notes, troubleshooting log |
| [`docs`](docs) | Schema diagram, architecture diagram, key technical learnings |
| [`Databricks`](Databricks) | PySpark notebooks — data ingestion, transformation, Delta table writes, Jobs & Pipelines |
| [`Python`](Python) | Reusable data quality functions — completeness, uniqueness, validity, integrity, JSON schema validation |
| [`Power_Automate`](Power_Automate) | Cloud flows — file trigger, weekly claims summary email, Power BI dataset refresh, data quality score email, refresh confirmation |
| [`Power_Apps`](Power_Apps) | HC_ClaimLookup canvas app — real-time claim status lookup connected live to Azure SQL 
| [`healthcarepractice_dbt`](healthcarepractice_dbt) | dbt exploration — present but not actively maintained; superseded by the Fabric/PySpark transformation approach used elsewhere in this repo |

---

## Architecture

The environment was built in three stages, mirroring how a real healthcare data platform moves from on-premises infrastructure to a modern cloud analytics stack:

```
┌─────────────────────┐        ┌──────────────────────┐        ┌───────────────────────┐
│   ON-PREMISES        │        │   AZURE SQL DATABASE  │ Connect │   MICROSOFT FABRIC     │
│   SQL Server (local) │ ─────► │   (cloud, live)        │ ─────► │   Lakehouse + Warehouse │
│   - 9 tables          │       │   sql-healthcarepractice│        │   + SQL endpoint         │
│   - 3 views            │       │   -cr.database.windows │        │   + Power BI              │
│   - stored procedures  │       │   .net                 │        │   semantic model           │
└─────────────────────┘        └──────────────────────┘        └───────────────────────┘
        ▲                                                                    ▲
        │ SSIS ETL                                              Power Automate (flows)
        │ (Integration Services)                                Databricks → Delta Lake
                                                                  Fabric Data Pipelines
```

**1. Database design & build (on-premises)**
Designed and built the `HealthcarePractice` database from scratch on a local SQL Server instance: 9 tables (`claims`, `claim_lines`, `providers`, `payer`, `diagnosis`, `members`, `dim_date`, `authorizations`, `network_contracts`, `audit_log`), 3 views, and stored procedures.

**2. Cloud migration to Azure SQL**
Migrated the on-prem database to a live Azure SQL Database (`sql-healthcarepractice-cr.database.windows.net`). Azure Data Factory was used for the initial migration but has since been retired from the ongoing portfolio due to persistent account access issues on the trial tenant; all further pipeline and orchestration work uses Fabric Data Pipelines instead.

**3. Analytics integration via Microsoft Fabric**
Connected Azure SQL to Microsoft Fabric as the analytics layer — Lakehouse (Delta tables, SQL endpoint, semantic model) and Warehouse (full read/write T-SQL, `claims_summary` table). Power BI connects to both via live semantic models. Fabric Data Pipelines now handle the pipeline/orchestration work previously scoped to ADF.

**4. Automation & orchestration (Week 2)**
- **Databricks:** PySpark notebooks for data ingestion, transformation, and Delta table writes. Jobs scheduled daily at 6AM (America/Chicago) to run before Power BI refresh.
- **Power Automate:** Cloud flows — event-driven file trigger, weekly claims summary email, and daily Power BI dataset refresh at 7AM.
- **Python:** Reusable data quality functions that mirror SQL audit queries, parameterized to accept any table/column, output consolidated pass/fail DataFrame.

**Result:** one Azure SQL database, accessible from SSMS, Fabric, Databricks, and Power BI — without duplicating data.

See [`docs/architecture.md`](docs/architecture.md) for more detail and [`docs/schema.md`](docs/schema.md) for the full table/column reference.

---

## Portfolio Projects

| # | Project | Status |
|---|---|---|
| 1 | [Claims Denial Analysis Dashboard](power-bi/README.md) | ✅ Complete |
| 2 | Member Analysis Report | ✅ Complete |
| 3 | Data Quality Scorecard | ✅ Complete |
| 4 | SSIS Enhancement — Audit Logging | ✅ Complete |
| 5 | Fabric Warehouse Build | ✅ Complete |
| 6 | Power Apps — HC_ClaimLookup Canvas App | ✅ Complete |
| 7 | Authorizations — Indexing, Audit Log Root-Cause & Cross-Environment Data Quality | ✅ Complete |
| 8 | Power BI & Fabric Deepening — Time Intelligence, Governance, Data Quality | ✅ Complete |
| 9 | Fabric ETL Depth, DAX Expansion & App Publish | ✅ Complete |

### Project 1 — Claims Denial Analysis Dashboard

Built a full-stack denial analytics solution: SQL view → Fabric named query → published Power BI report with DAX measures.

- **Top denial reason:** Duplicate Claim (24 denials, 23.5%)
- **Second driver:** Coding Error (22 denials, 21.6%)
- DAX measures: `Denial Rate %`, `Total Denied Amount`, `MoM Denial Change`, `Top Denial Reason`, `Rolling 3-Month Denial Rate`
- Report published to the `HealthcarePractice` Fabric workspace, two pages (Denial Analysis, Denial Reasons), payer/provider slicers

Full writeup and screenshots: [`power-bi/README.md`](power-bi/README.md)

### Project 2 — Member Analysis Report

3-page Power BI report covering Claims Overview, Provider Performance, and Member Analysis. Built on a star schema with DAX measures. Row-level security implemented for Provider and Executive roles. Published to Fabric with scheduled daily refresh at 6AM Central.

### Project 3 — Data Quality Scorecard

4 KPI cards in Power BI (Completeness, Integrity, Uniqueness, Validity) built from SQL audit queries and DAX measures. Published to Fabric workspace. Python equivalents built in Databricks — see [`Python/data_quality_functions.py`](Python/data_quality_functions.py).

### Project 4 — SSIS Enhancement — Audit Logging

Enhanced the `Load_NewClaims` SSIS package with a VB.NET Script Task (`SCR_WriteAuditLog`) that writes run metadata (timestamp, rows inserted, rows rejected) to a pipeline audit log table after each execution. Package includes file validation, Lookup transforms for member/provider integrity, and reject routing. See [`ssis/README.md`](ssis/README.md) for a documented troubleshooting case involving a silent row-loss bug and its fix.

### Project 5 — Fabric Warehouse Build

Created a Fabric Warehouse (`HealthcarePractice_Warehouse`) alongside the existing Lakehouse to demonstrate the architectural difference: the Lakehouse uses Delta files via a read-only SQL endpoint; the Warehouse provides full read/write T-SQL. Built `claims_summary` table via T-SQL, connected Power BI directly to the Warehouse semantic model, and verified end-to-end data flow.

### Project 7 — Authorizations: Indexing, Audit Log Root-Cause & Cross-Environment Data Quality

A single day's work spanning four layers of the stack, tied together by the `authorizations` table:

- **SSMS:** Built a provider-grouped authorization turnaround-time baseline query, then added a non-clustered covering index (`IX_Authorizations_ProviderID` on `provider_id`, including `requested_date`/`decision_date`) so the query can be satisfied entirely from the index without a lookup to the base table. See [`sql/06_indexing`](sql/06_indexing).
- **SSIS:** Reviewed `pipeline_audit_log` and found a logged run that didn't match a prior day's documented reconciliation. Root-caused to the audit-logging Script Task being a pure pass-through of SSIS variables rather than an independent recount — the real fix lived in the Data Flow's row-count wiring, not the logging code. Validated by generating an independently constructed 15-row test batch (rather than replaying the original file, which risked a primary-key collision) and confirming an exact predicted 4-inserted/11-rejected split, correctly logged. Full writeup: [`ssis/SSIS_Troubleshooting_Load_NewClaims.md`](ssis/SSIS_Troubleshooting_Load_NewClaims.md).
- **Fabric:** Ran a NULL audit against `authorizations`, grouped by `decision` status to separate business-rule-expected NULLs from genuine anomalies. Found one row (`auth_id 7`) with `decision = 'Pending'` but a populated `decision_date` and NULL `units_approved` — a partial-decision state inconsistent with normal business rules. Confirmed the same finding identically across local SQL Server, Azure SQL, and the Fabric Lakehouse copy, ruling out stale sync as an explanation. See [`sql/04_data_quality_audits/NULL_Audit_Authorizations_By_Decision.sql`](sql/04_data_quality_audits/NULL_Audit_Authorizations_By_Decision.sql).
- **Power BI:** Added `authorizations` to the `HealthcarePractice.pbix` semantic model, correcting an initial relationship misconfiguration (cardinality was set to One-to-one instead of Many-to-one; cross-filter direction was set to Both instead of Single) before applying. Built and validated an `Avg Turnaround Days` DAX measure that explicitly excludes the known-bad Pending row, returning 1.00 days — matching the SQL baseline.

**Interview talking point:** A single data-quality finding, followed end-to-end — caught in a NULL audit, confirmed across three separate environments to rule out a sync issue, and reflected consistently in a downstream DAX measure that was deliberately written to exclude the bad record rather than let it silently skew a KPI.

### Project 8 — Power BI & Fabric Deepening: Time Intelligence, Governance, Data Quality

A full week focused on Power BI/DAX depth and Microsoft Fabric governance, with SQL treated as a daily non-negotiable regardless of theme — string cleanup, aggregation/data-quality, and existence/comparison patterns were rotated in alongside the primary Power BI/Fabric work rather than dropped for it.

- **Time intelligence & validation:** Built `Billed Amount PY` (`SAMEPERIODLASTYEAR`) and `Total Billed YTD` (`TOTALYTD`) DAX measures against a physical `dim_date` table (marked as Date Table, active relationship on `claims[service_date]`). Cross-checked both against manual SQL queries with matching results — same validation rigor as the Rolling 3-Month Denial Rate measure. A dedicated "Time Intelligence Validation" report page embeds the SQL alongside the DAX output as self-contained proof.
- **CALCULATE context transition:** Deliberately built a context-transition example (`payer_display` calculated column, a hardcoded-filter test measure) to demonstrate the difference between row context and filter context live in the model, rather than only explaining it verbally.
- **AI visual — Decomposition Tree:** Added a Decomposition Tree to the Denial Analysis page (`Denial Drivers`), closing a flagged PL-300 gap. Live drill path: Total Claims (552) → claim_status (Denied: 102) → payer_name → provider_name, giving an interactive "why are claims denied and where" narrative rather than a static chart.
- **Authorizations report page:** Closed a gap flagged in Week 3 — added the `authorizations` → `providers` relationship (many-to-one, previously only linked to `members`) and built/validated an `Avg Turnaround Days` DAX measure (`AVERAGEX` + `NOT ISBLANK` filter on `decision_date`) against a manual SQL cross-check. Both returned 1.00 days exactly.
- **Fabric Warehouse vs. Lakehouse comparison:** Ran an identical aggregate query against both `HealthcarePractice_Warehouse` and the Lakehouse SQL analytics endpoint. Results matched exactly (20 rows, identical values); the Lakehouse endpoint completed faster on this single-run test, though not treated as a definitive performance conclusion. Documented the architectural difference: the Lakehouse SQL endpoint is technically a read-only mirrored-warehouse layer over Delta tables (`/mirroredwarehouses/` in its URL path), not a first-class warehouse compute engine. Full writeup: [`Fabric/warehouse_vs_lakehouse_comparison.md`](Fabric/warehouse_vs_lakehouse_comparison.md).
- **Fabric governance exploration:** Investigated a previously flagged PL-300 gap — workspace/sharing governance settings not yet explored. Found Fabric's native Git integration is Azure DevOps-first (GitHub is grayed out by default, requiring tenant-level enablement). Found two distinct governance layers under Delegated Settings: OneLake user-delegated SAS token authentication (data-access control, off by default) and standalone Copilot item approval (AI-feature governance, off by default) — with the important nuance that Copilot usage is always subject to user permissions regardless of that toggle.
- **`denial_reason` NULL investigation:** Followed up on an 81.34% NULL rate flagged during a prior week's broader NULL audit. Confirmed structurally expected (Pending and most Approved claims correctly have no reason) via a `claim_status`-grouped breakdown, and confirmed zero Denied claims are missing a reason. Found one genuine anomaly: an Approved claim (`claim_id 14`) with `denial_reason` populated as "Billed amount corrected" — revealing the column is overloaded to also capture general claim adjustments, not exclusively denial explanations. Full writeup: [`docs/denial_reason_null_investigation.md`](docs/denial_reason_null_investigation.md).
- **Data cleanliness checks:** [`provider_name_whitespace_check`](sql/04_data_quality_audits/provider_name_whitespace_check.sql) (`TRIM`/`UPPER` whitespace check on `provider_name`) and [`network_contracts_overlap_check`](sql/04_data_quality_audits/network_contracts_overlap_check.sql) (overlapping-date-range self-join against `network_contracts`) both returned zero rows — verified-clean findings, documented as such rather than treated as failed exercises.

**Interview talking point:** The `denial_reason` investigation is a good example of a data-quality check that starts as "is this NULL rate a problem?" and ends up finding a subtler issue — a column serving two purposes — that a simple NULL-percentage audit alone wouldn't surface. It also demonstrates why `column IS NOT NULL` is a fragile proxy for a business condition unless explicitly verified.

### Project 9 — Fabric ETL Depth, DAX Expansion & App Publish

A week built around a real Fabric pipeline with a visible downstream dashboard effect, deeper DAX beyond time intelligence, and a report taken through to a published, curated Power BI App — punctuated by an unplanned Azure outage, a genuine platform-boundary discovery in Power Automate, and two live data-quality bugs caught and fixed with PySpark before they reached the published App.

- **Monday — Azure outage, root-caused and fixed:** An Azure SQL connection failure (error 40925) traced back to an **expired Azure free trial subscription** — and the fix surfaced a structural discovery: Azure free trials are owned by the personal Microsoft Account (MSA) that created them, not the Entra ID admin account used for daily work, which is very likely the same root cause that had permanently blocked Azure Data Factory a month earlier. Reactivated under the correct MSA, resolved a stale-credential connection failure that followed, and set up permanent SSMS Registered Server connections. Built `HC_Load_Claims_Incremental`, hit a real duplicate-key failure from a rolling watermark with no memory of already-loaded rows, fixed via a Lakehouse notebook `dropDuplicates(["claim_id"])` (the SQL endpoint being read-only forced this to Spark, not T-SQL), and discovered the Power BI report had been pointed at Azure SQL instead of the Lakehouse the entire time — repointed it, the architecturally correct fix. Verified outcome: Total Claims moved 552 → 555 and Denied 102 → 103 on refresh, directly attributable to the pipeline. DAX side: `Denial Category` (`SWITCH(TRUE(), ...)`) and `Provider Rank by Billed Amount` (`RANKX`), demonstrated live against a `claim_status` slicer to show the same unedited measure produce four different rankings — a concrete, build-it-live approach to the standing CALCULATE/context-transition interview weak point.
- **Tuesday — Power Automate boundary + VAR/RETURN refactor:** Built `providers_no_active_contract.sql` using `NOT EXISTS`, correcting on the fly for a schema discovery (no `status` column — "active" is date-range-governed). Found and documented that **Power Automate has no native Fabric Data Pipeline connector** — confirmed by exhausting the Power BI connector list and checking whether Fabric Apps (Preview) filled the gap (it doesn't; that's a separate app-building platform). Scoped `HC_Nightly_Pipeline_Refresh` to refresh the Power BI dataset directly instead, with the limitation documented in the flow's own email body rather than only in session notes. Refactored `Denial Rate %` to `VAR`/`RETURN`, reusing existing measures and adding a safe-division fallback; output unchanged at 555 claims, 103 denied, 0.21 overall.
- **Wednesday — near-duplicate detection & real watermark pipeline:** Self-join screening query found 77 same-member claim pairs within 7 days (~14% of claims), only 5 sharing a provider, none true duplicates. Replaced Monday's fixed-cutoff watermark stopgap with a genuine 4-activity pipeline chain (`LU_Get_Watermark` → `LU_Get_New_Max_Date` → Copy Data → `SCR_Update_Watermark`) backed by a new `pipeline_watermark` control table, debugging a live NULL-insert failure caused by the update step querying the Warehouse's stale `claims` copy instead of live Azure SQL. Documented three Fabric Warehouse DDL gaps hit while building the control table: no `DEFAULT`, no `PRIMARY KEY` keyword, `DATETIME2` requires explicit precision.
- **Thursday — ALLEXCEPT/ALL and App publish:** Built `Denial Rate % of Total` using `CALCULATE([Denial Rate %], ALL(providers))` — `ALL` rather than `ALLEXCEPT`, since `ALLEXCEPT` requires at least one preserved-column argument and can't take just a table name. Published the first curated Power BI App from the workspace, selecting 6 of 8 report pages and excluding two dev/QA-only pages (DAX Validation, Data Quality Scorecard) from viewer-facing content.
- **Data quality catch mid-publish:** Found the Lakehouse's `payer` table still held real, unscrubbed company names despite Azure SQL's copy being correctly scrubbed — corrected via a PySpark `overwrite` write, hitting and resolving a Delta schema-merge conflict with `overwriteSchema`. The subsequent refresh surfaced a second issue: `claim_id 1319` had four fully identical duplicate rows violating the one-to-many relationship constraint, fixed via `dropDuplicates()`. Both caught and resolved before the App shipped, not after.
- **Friday — SQL rapid-fire & Fabric workspace clean-up:** Ranking window-function review (`RANK` vs. `DENSE_RANK`), manager-hierarchy self-join drilled against a throwaway table. Reorganized the Fabric workspace from 18 loose root-level items into 4 folders (`Lake_and_Ware_House`, `Notebooks`, `Pipeline_CopyJobs`, `Reports_SemanticModels`); deleted 4 stale/duplicate report-and-semantic-model pairs across two workspaces — including one nearly two months stale, still showing real unscrubbed payer names; renamed generic items to match naming convention.

**Interview talking point:** Monday's Azure outage is a strong operational-troubleshooting story on its own — an auth failure that looked like an access loss turned out to be an account-ownership structure issue (MSA vs. Entra ID), and diagnosing it correctly retroactively explained a separate tool (ADF) written off weeks earlier for the wrong reason. Combined with Tuesday's documented Power Automate/Fabric connector gap and Thursday's live payer/claims data-quality catch, the week is less "everything worked" and more "here's how I diagnose and fix things when they don't" — a stronger signal than a clean build-out would have been.

---

## SQL Query Library

Production-style queries, organized by purpose. Each file is commented with the business question it answers and the SQL technique it demonstrates.

| Query | Technique | Business Question |
|---|---|---|
| [`vw_denial_analysis`](sql/02_views/vw_denial_analysis.sql) | Multi-table JOIN, CASE WHEN, NULLIF | What's the denial rate by payer and provider? |
| [`denial_rate_by_provider_and_specialty`](sql/03_analytical_queries/denial_rate_by_provider_and_specialty.sql) | `RANK() OVER (PARTITION BY)` | How does each provider rank against peers in their specialty? |
| [`claim_turnaround_time`](sql/03_analytical_queries/claim_turnaround_time.sql) | `DATEDIFF`, AVG/MIN/MAX | How fast are claims processed by provider-payer combination? |
| [`member_utilization`](sql/03_analytical_queries/member_utilization.sql) | `COUNT(DISTINCT)` | How many unique members are utilizing services by plan type? |
| [`denial_reason_trend_by_month`](sql/03_analytical_queries/denial_reason_trend_by_month.sql) | CTE + `LAG()` | Are denial reasons trending up or down month-over-month? |
| [`provider_network_status_impact`](sql/03_analytical_queries/provider_network_status_impact.sql) | Conditional aggregation | Do out-of-network claims deny at a different rate? |
| [`auth_approval_rate_by_provider`](sql/03_analytical_queries/auth_approval_rate_by_provider.sql) | JOIN, CASE WHEN, NULLIF | What is the authorization approval rate by provider? |
| [`network_contracts_expiring_90_days`](sql/03_analytical_queries/network_contracts_expiring_90_days.sql) | DATEADD, BETWEEN, NULL handling | Which provider contracts are expiring within 90 days? |
| [`auth_approval_rate_cte`](sql/03_analytical_queries/auth_approval_rate_cte.sql) | CTE, DATEDIFF, avg_decision_days | Authorization approval rate by type with average decision time |
| [`NULL_Audit_Across_Key_Tables`](sql/04_data_quality_audits/NULL_Audit_Across_Key_Tables.sql) | `UNION ALL`, CASE WHEN IS NULL | Where is data incomplete? |
| [`Orphaned_Records_Check`](sql/04_data_quality_audits/Orphaned_Records_Check.sql) | `NOT EXISTS` | Are there claims referencing missing diagnosis codes? |
| [`Duplicate_Claims_Check`](sql/04_data_quality_audits/Duplicate_Claims_Check.sql) | `GROUP BY` + `HAVING COUNT(*) > 1` | Are there true duplicate claim records? |
| [`date_range_audit`](sql/04_data_quality_audits/date_range_audit.sql) | `GETDATE()`, `DATEADD()` | Are any date fields out of valid range? |
| [`NULL_Audit_Authorizations_By_Decision`](sql/04_data_quality_audits/NULL_Audit_Authorizations_By_Decision.sql) | `GROUP BY`, CASE WHEN IS NULL | Are NULLs in `authorizations` business-rule-expected, or genuine anomalies, by decision status? |
| [`denial_reason_null_investigation`](docs/denial_reason_null_investigation.md) | `GROUP BY`, conditional `SUM(CASE WHEN...)`, flip-side anomaly check | Is the 81.34% NULL rate on `denial_reason` a genuine gap or expected behavior — and is there any row where it's populated incorrectly? |
| [`network_contracts_overlap_check`](sql/04_data_quality_audits/network_contracts_overlap_check.sql) | Self-join, `ISNULL` for open-ended ranges | Does any provider have two `network_contracts` with overlapping date ranges? (Result: none found) |
| [`provider_name_whitespace_check`](sql/04_data_quality_audits/provider_name_whitespace_check.sql) | `TRIM`, `UPPER`, `LEN` comparison | Does `provider_name` contain leading/trailing whitespace? (Result: none found) |
| [`network_contracts_rank_by_type`](sql/07_window_functions/network_contracts_rank_by_type.sql) | `RANK() OVER (PARTITION BY)`, `DENSE_RANK()` | How do contracts rank by rate_modifier within each contract type? |
| [`providers_no_active_contract`](sql/04_data_quality_audits/providers_no_active_contract.sql) | `NOT EXISTS`, date-range logic | Which providers have no currently active network contract? |
| [`claims_near_duplicate_self_join`](sql/04_data_quality_audits/claims_near_duplicate_self_join.sql) | Self-join, `ABS(DATEDIFF())` | Are there near-duplicate claims for the same member within 7 days? |

### Indexing

| Script | Technique | Purpose |
|---|---|---|
| [`Create_NonClustered_Index_Authorizations`](sql/06_indexing/Create_NonClustered_Index_Authorizations.sql) | Non-clustered covering index, `INCLUDE` columns | Speed up provider-grouped turnaround-time queries on `authorizations` without a base-table lookup |
| [`IndexCheck`](sql/06_indexing/IndexCheck.sql) | `sys.indexes`, `DB_NAME()` | Verify the index exists and confirm the correct database/session context |

### Views

| View | Technique | Purpose |
|---|---|---|
| [`vw_ActiveProviders`](sql/02_views/vw_ActiveProviders.sql) | LEFT JOIN, `GETDATE()` filtering, multi-condition join | Active providers with current contract terms |
| [`vw_InNetworkProviders`](sql/02_views/vw_InNetworkProviders.sql) | `WITH CHECK OPTION` | In-network provider filter with update protection |
| [`vw_ProviderClaimSummary`](sql/02_views/vw_ProviderClaimSummary.sql) | Conditional aggregation, `NULLIF`, `CAST AS DECIMAL` | Claim volume, billed/paid totals, denial rate per provider |

### Stored Procedures

| Procedure | Technique | Purpose |
|---|---|---|
| [`usp_TerminateProvider`](sql/05_stored_procedures/usp_TerminateProvider.sql) | `TRY/CATCH`, transaction, `@@ROWCOUNT`, `THROW`, audit log | Terminate a provider atomically with contract close and audit trail |
| [`usp_FilterClaims`](sql/05_stored_procedures/usp_FilterClaims.sql) | Dynamic SQL, `sp_executesql`, `QUOTENAME`, column whitelist | SQL-injection-safe dynamic claim filtering by column and value |
| [`usp_GetMemberClaims`](sql/05_stored_procedures/usp_GetMemberClaims.sql) | Optional parameters, `ISNULL` defaults, `BETWEEN` | Member claim history lookup with optional date range |
| [`usp_EnrollMember`](sql/05_stored_procedures/usp_EnrollMember.sql) | `OUTPUT` parameter, `SCOPE_IDENTITY()`, `RETURN` codes | Enroll a new member and pass the generated ID back to the caller |
| [`usp_GetDenialSummary`](sql/05_stored_procedures/usp_GetDenialSummary.sql) | Conditional aggregation, `NULLIF`, adjudicated-claims denominator | Per-payer denial rate, denied billed amount, and adjudication mix |
| [`usp_GetHighDollarClaimsByProvider`](sql/05_stored_procedures/usp_GetHighDollarClaimsByProvider.sql) | Default parameter value, `LEFT JOIN`, `ORDER BY ... DESC` | High-dollar approved claims for a provider, with diagnosis context |

---

## Databricks Notebooks

| Notebook | Contents |
|---|---|
| [`HC_Practice_Week2_Monday`](Databricks/HC_Practice_Week2_Monday.ipynb) | PySpark data ingestion from Unity Catalog volume, DataFrame exploration (`show`, `printSchema`, `describe`), filtered counts, denial rate by provider using `groupBy().agg()`, member utilization using `countDistinct()` |
| [`HC_Practice_Week2_Thursday`](Databricks/HC_Practice_Week2_Thursday.ipynb) | 5 parameterized Python data quality functions, JSON schema validator, consolidated pass/fail quality report as pandas DataFrame — all 5 checks scored 100% against 95% threshold |

**Databricks environment:** Community Edition, Unity Catalog volume at `/Volumes/workspace/default/hc_practice_data/`. Delta table `workspace.default.claims` created via `saveAsTable()`. Job `HC_WeeklyClaims_DataLoad` scheduled daily at 6AM Central.

---

## Python Data Quality Framework

[`Python/data_quality_functions.py`](Python/data_quality_functions.py)

5 reusable parameterized functions that mirror the SQL audit queries, built to run in Databricks against a pandas DataFrame:

| Function | SQL Equivalent | Check |
|---|---|---|
| `check_completeness(df, column)` | `SUM(CASE WHEN col IS NOT NULL ...)` | % non-null values |
| `check_uniqueness(df, column)` | `COUNT(DISTINCT col) / COUNT(*)` | % distinct values |
| `check_validity(df, column, valid_values)` | `SUM(CASE WHEN col IN (...) ...)` | % values in allowed set |
| `check_integrity(df, fk_column, valid_ids)` | FK JOIN to reference table | % FK values matched |
| `validate_json_schema(path, required_fields)` | No SQL equivalent | Missing field detection per record |

Output: consolidated pandas DataFrame with Pass/Fail at configurable threshold (default 95%).

---

## Power Automate Flows

| Flow | Trigger | Action |
|---|---|---|
| `HC_NewClaims_File_Trigger` | File lands in OneDrive folder | Sends Outlook.com email with dynamic filename |
| `HC_Weekly_Claims_Summary` | Every Monday (scheduled) | Sends claims summary email with `formatDateTime()` dynamic date in subject |
| `HC_Refresh_PowerBI_Dataset` | Daily at 7AM (scheduled) | Refreshes `HealthcarePractice_SemanticModel` in Power BI |
| `HC_HighDollarClaims_Alert` | Manual trigger against Azure SQL (OData filter) | Alerts on high-dollar claims (billed_amount > $10,000) — documented as a known trial-tenant Premium license limitation |
| `HC_DataQuality_Score_Email` | Daily at 8AM (scheduled) | Reads latest data quality scores, sends pass/fail summary email |
| `HC_PowerBI_Refresh_Confirm` | Fires after Power BI dataset refresh completes | Sends confirmation email with timestamp |

Screenshots: [`Power_Automate/`](Power_Automate/)

**Pipeline sequencing:** Databricks Job runs at 6AM → Power BI refresh runs at 7AM, ensuring the semantic model always reflects the latest data.

---

## Power Apps

[`Power_Apps/`](Power_Apps/) — [`README`](Power_Apps/Power_Apps_README.md)

**HC_ClaimLookup** is a Canvas App that provides real-time claim status lookup against the HealthcarePractice Azure SQL Database. A user enters a Claim ID or Member ID (toggle between search modes), the app queries the `claims` table directly, and returns the claim status and billed amount instantly, with input validation and empty-result handling.

| Control | Purpose |
|---|---|
| `txtClaimID` — Text Input | User enters the claim ID or member ID to search |
| `btnSearch` — Button | Triggers `ClearCollect(ClaimResults, Filter(claims, claim_id = Value(txtClaimID.Text)))` |
| `galClaimResults` — Vertical Gallery | Displays Claim ID, Status, and Billed Amount from query results |

**Verified results:** Claim 2 → Approved \| $180.00 · Claim 5 → Denied \| $1,200.00

Screenshots: [`Power_Apps/`](Power_Apps/)

---

## Key Technical Learnings

A few of the architectural and SQL principles applied throughout this build — full list in [`docs/learnings.md`](docs/learnings.md):

- **CTEs are a readability tool, not a performance optimizer** — SQL Server inlines them before generating execution plans
- **Fabric's SQL analytics endpoint is read-only** — views are saved via "Save as view" in the UI; named queries are the practical equivalent for Power BI consumption
- **Direct Lake mode requires exact data type matches** on relationship columns — mismatches silently break relationships
- **Fabric Warehouse does not support DEFAULT constraints** in `CREATE TABLE` — hardcoded values required
- **`NOT EXISTS` outperforms `LEFT JOIN / IS NULL`** for orphan-record checks on large datasets
- **Databricks Serverless compute** does not persist variables across cells — each cell must be self-contained with `spark.read.csv()` re-declared
- **Power Automate on M365 trial tenants** does not fully provision OneDrive for Business or Office 365 Outlook connectors — standard OneDrive + Outlook.com connectors (Yahoo account) required
- **SSIS error/no-match outputs must each be explicitly wired** to a reject path — an unconnected output silently drops rows with no error or log entry (see [`ssis/README.md`](ssis/README.md))
- **Denial rate should be calculated against adjudicated claims only** (denied + approved), not total claims — pending/unresolved claims in the denominator understate the true rate
- **Always confirm `DB_NAME()` when a database object doesn't appear as expected** — multiple open SSMS tabs connected to different sessions/databases can create the illusion of a failed operation that actually succeeded
- **An audit-logging script can be entirely correct and still report wrong numbers** if it simply passes through values from upstream variables — the real fix has to happen at the source of those values (e.g., a Row Count component's position relative to a merge point), not in the logging code itself
- **A flat NULL count can miss logical inconsistencies that only surface when grouped by a related status column** — cross-referencing `decision` against `decision_date`/`units_approved` caught an issue a column-by-column NULL audit alone would have missed
- **Confirming a data-quality finding across every environment it lives in** (local, cloud database, Fabric) before writing it up rules out stale sync as an alternative explanation and materially strengthens the finding
- **Power BI relationship cardinality and cross-filter direction are not always correct on creation** and should be explicitly checked — a mismatched cardinality or an unnecessary bidirectional filter can silently produce wrong numbers on visuals with no error raised
- **A column can be "mostly correct" and still be a fragile analytical proxy** — `denial_reason IS NOT NULL` looked like a safe stand-in for "this claim was denied" until one Approved row with an unrelated note surfaced; treating the column as overloaded (denial explanation + general adjustment note) rather than single-purpose is the more accurate model
- **Fabric's native Git integration defaults to Azure DevOps** — GitHub requires tenant-level enablement and isn't available out of the box on a trial capacity, which matters for any GitHub-based team planning a Fabric migration
- **Fabric governance is not one setting** — data-access control (OneLake delegated SAS tokens) and AI-feature governance (Copilot item approval) are separate layers that don't substitute for each other; Copilot's own item-approval toggle explicitly does not override underlying user permissions
- **Azure free trial subscriptions are owned by the personal Microsoft Account (MSA) that created them**, not the Entra ID admin account used for daily work — a subscription that appears to vanish is often just invisible to the wrong login, not actually lost
- **`ALLEXCEPT` requires at least one column argument** — it cannot be called with only a table name; `ALL(table)` is the correct function when clearing every filter on a table with nothing preserved
- **Fabric Warehouse `IDENTITY` columns must be typed `BIGINT`**, not `INT` — a distinct constraint from the separately-documented lack of `PRIMARY KEY` support
- **Delta `.write().mode("overwrite")` merges schemas by default rather than replacing them** — `.option("overwriteSchema", "true")` is required when the incoming schema doesn't exactly match the existing table
- **Power Automate has no native connector for triggering a Fabric Data Pipeline** as of this build — only dataset/report/scorecard-level Power BI actions exist; confirmed by exhausting the connector list rather than assuming

---

## Stack

`SQL Server` `Azure SQL Database` `Microsoft Fabric` `Fabric Data Pipelines` `Power BI` `DAX` `SSIS` `T-SQL` `Databricks` `PySpark` `Python` `pandas` `Delta Lake` `Power Automate` `Power Apps`

---

## Contact

Charles Richardson — open to healthcare data analytics and data engineering roles in Houston, TX.

- **LinkedIn:** [linkedin.com/in/cerichardsonba](https://www.linkedin.com/in/cerichardsonba)
- **Email:** cerjr2@gmail.com
