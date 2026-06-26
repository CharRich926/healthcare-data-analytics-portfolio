# Healthcare Data Analytics Portfolio

**Charles Richardson** | Healthcare Claims & Payer Analytics | June 2026

End-to-end healthcare data analytics environment — designed, built, and migrated from scratch. This repo contains the database architecture, SQL query library, ETL pipeline, Python data quality framework, Databricks notebooks, Power Automate flows, Power Apps canvas app, and Power BI reporting layer behind a claims denial analysis platform modeled on real payer/provider analytics workflows.

---

## What's in this repo

| Folder | Contents |
|---|---|
| [`sql/01_database_setup`](sql/01_database_setup) | Table DDL, indexes, schema design |
| [`sql/02_views`](sql/02_views) | 3 views — active providers, in-network filter, provider claim summary |
| [`sql/03_analytical_queries`](sql/03_analytical_queries) | Window functions, CTEs, peer benchmarking, utilization analysis, authorization approval rates |
| [`sql/04_data_quality_audits`](sql/04_data_quality_audits) | NULL audits, orphan record checks, duplicate detection, date validity |
| [`sql/05_stored_procedures`](sql/05_stored_procedures) | 4 stored procedures — member enrollment, claim filtering, provider termination, claim history |
| [`power-bi`](power-bi) | Dashboard screenshots, DAX measures, report description |
| [`ssis`](ssis) | ETL pipeline description and package notes |
| [`docs`](docs) | Schema diagram, architecture diagram, key technical learnings |
| [`Databricks`](Databricks) | PySpark notebooks — data ingestion, transformation, Delta table writes, Jobs & Pipelines |
| [`Python`](Python) | Reusable data quality functions — completeness, uniqueness, validity, integrity, JSON schema validation |
| [`Power_Automate`](Power_Automate) | 3 cloud flows — file trigger, weekly claims summary email, Power BI dataset refresh |
| [`Power_Apps`](Power_Apps) | HC_ClaimLookup canvas app — real-time claim status lookup connected live to Azure SQL |

---

## Architecture

The environment was built in three stages, mirroring how a real healthcare data platform moves from on-premises infrastructure to a modern cloud analytics stack:

```
┌─────────────────────┐        ┌──────────────────────┐        ┌───────────────────────┐
│   ON-PREMISES        │  ADF   │   AZURE SQL DATABASE  │ Connect │   MICROSOFT FABRIC     │
│   SQL Server (local) │ ─────► │   (cloud, live)        │ ─────► │   Lakehouse + Warehouse │
│   - 9 tables          │ migr. │   sql-healthcarepractice│        │   + SQL endpoint         │
│   - 3 views            │       │   -cr.database.windows │        │   + Power BI              │
│   - stored procedures  │       │   .net                 │        │   semantic model           │
└─────────────────────┘        └──────────────────────┘        └───────────────────────┘
        ▲                                                                    ▲
        │ SSIS ETL                                              Power Automate (3 flows)
        │ (Integration Services)                                Databricks → Delta Lake
```

**1. Database design & build (on-premises)**
Designed and built the `HealthcarePractice` database from scratch on a local SQL Server instance: 9 tables (`claims`, `claim_lines`, `providers`, `payer`, `diagnosis`, `members`, `dim_date`, `authorizations`, `network_contracts`, `audit_log`), 3 views, and stored procedures.

**2. Cloud migration via Azure Data Factory**
Used ADF to migrate the full on-prem database to a live Azure SQL Database (`sql-healthcarepractice-cr.database.windows.net`).

**3. Analytics integration via Microsoft Fabric**
Connected Azure SQL to Microsoft Fabric as the analytics layer — Lakehouse (Delta tables, SQL endpoint, semantic model) and Warehouse (full read/write T-SQL, `claims_summary` table). Power BI connects to both via live semantic models.

**4. Automation & orchestration (Week 2)**
- **Databricks:** PySpark notebooks for data ingestion, transformation, and Delta table writes. Jobs scheduled daily at 6AM (America/Chicago) to run before Power BI refresh.
- **Power Automate:** 3 cloud flows — event-driven file trigger, weekly claims summary email, and daily Power BI dataset refresh at 7AM.
- **Python:** Reusable data quality functions that mirror SQL audit queries, parameterized to accept any table/column, output consolidated pass/fail DataFrame.

**Result:** one Azure SQL database, accessible from SSMS, ADF, Fabric, Databricks, and Power BI — without duplicating data.

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

### Project 1 — Claims Denial Analysis Dashboard

Built a full-stack denial analytics solution: SQL view → Fabric named query → published Power BI report with DAX measures.

- **Top denial reason:** Duplicate Claim (24 denials, 23.5%)
- **Second driver:** Coding Error (22 denials, 21.6%)
- DAX measures: `Denial Rate %`, `Total Denied Amount`, `MoM Denial Change`, `Top Denial Reason`
- Report published to the `HealthcarePractice` Fabric workspace, two pages (Denial Analysis, Denial Reasons), payer/provider slicers

Full writeup and screenshots: [`power-bi/README.md`](power-bi/README.md)

### Project 2 — Member Analysis Report

3-page Power BI report covering Claims Overview, Provider Performance, and Member Analysis. Built on a star schema with 11 DAX measures. Row-level security implemented for Provider and Executive roles. Published to Fabric with scheduled daily refresh at 6AM Central.

### Project 3 — Data Quality Scorecard

4 KPI cards in Power BI (Completeness, Integrity, Uniqueness, Validity) built from SQL audit queries and DAX measures. Published to Fabric workspace. Python equivalents built in Databricks — see [`Python/data_quality_functions.py`](Python/data_quality_functions.py).

### Project 4 — SSIS Enhancement — Audit Logging

Enhanced the `Load_NewClaims` SSIS package with a VB.NET Script Task (`SCR_WriteAuditLog`) that writes run metadata (timestamp, rows inserted, rows rejected) to the `audit_log` table after each execution. Package includes file validation, Lookup transforms for member/provider integrity, and reject routing.

### Project 5 — Fabric Warehouse Build

Created a Fabric Warehouse (`HealthcarePractice_Warehouse`) alongside the existing Lakehouse to demonstrate the architectural difference: the Lakehouse uses Delta files via a read-only SQL endpoint; the Warehouse provides full read/write T-SQL. Built `claims_summary` table via T-SQL, connected Power BI directly to the Warehouse semantic model, and verified end-to-end data flow.

---

## SQL Query Library

13 production-style queries, organized by purpose. Each file is commented with the business question it answers and the SQL technique it demonstrates.

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

Screenshots: [`Power_Automate/`](Power_Automate/)

**Pipeline sequencing:** Databricks Job runs at 6AM → Power BI refresh runs at 7AM, ensuring the semantic model always reflects the latest data.

---

## Power Apps

[`Power_Apps/`](Power_Apps/) — [`README`](Power_Apps/Power_Apps_README.md)

**HC_ClaimLookup** is a Canvas App that provides real-time claim status lookup against the HealthcarePractice Azure SQL Database. A user enters a Claim ID, the app queries the `claims` table directly, and returns the claim status and billed amount instantly.

| Control | Purpose |
|---|---|
| `txtClaimID` — Text Input | User enters the claim ID to search |
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

---

## Stack

`SQL Server` `Azure Data Factory` `Azure SQL Database` `Microsoft Fabric` `Power BI` `DAX` `SSIS` `T-SQL` `Databricks` `PySpark` `Python` `pandas` `Delta Lake` `Power Automate` `Power Apps`

---

## Contact

Charles Richardson — open to healthcare data analytics and data engineering roles in Houston, TX.
