# Healthcare Data Analytics Portfolio

**Charles Richardson** | Healthcare Claims & Payer Analytics | June 2026

End-to-end healthcare data analytics environment — designed, built, and migrated from scratch. This repo contains the database architecture, SQL query library, ETL pipeline, and Power BI reporting layer behind a claims denial analysis platform modeled on real payer/provider analytics workflows.

---

## What's in this repo

| Folder | Contents |
|---|---|
| [`sql/01_database_setup`](sql/01_database_setup) | Table DDL, indexes, schema design |
| [`sql/02_views`](sql/02_views) | 3 views — active providers, in-network filter, provider claim summary |
| [`sql/03_analytical_queries`](sql/03_analytical_queries) | Window functions, CTEs, peer benchmarking, utilization analysis |
| [`sql/04_data_quality_audits`](sql/04_data_quality_audits) | NULL audits, orphan record checks, duplicate detection, date validity |
| [`sql/05_stored_procedures`](sql/05_stored_procedures) | 4 stored procedures — member enrollment, claim filtering, provider termination, claim history |
| [`power-bi`](power-bi) | Dashboard screenshots, DAX measures, report description |
| [`ssis`](ssis) | ETL pipeline description and package notes |
| [`docs`](docs) | Schema diagram, architecture diagram, key technical learnings |

---

## Architecture

The environment was built in three stages, mirroring how a real healthcare data platform moves from on-premises infrastructure to a modern cloud analytics stack:

```
┌─────────────────────┐        ┌──────────────────────┐        ┌───────────────────────┐
│   ON-PREMISES        │  ADF   │   AZURE SQL DATABASE  │ Connect │   MICROSOFT FABRIC     │
│   SQL Server (local) │ ─────► │   (cloud, live)        │ ─────► │   Lakehouse + SQL       │
│   - 9 tables          │ migr. │   sql-healthcarepractice│        │   endpoint + Power BI   │
│   - 3 views            │       │   -cr.database.windows │        │   semantic model         │
│   - stored procedures  │       │   .net                 │        │                          │
└─────────────────────┘        └──────────────────────┘        └───────────────────────┘
        ▲
        │ SSIS ETL
        │ (Integration Services Catalogs
        │  on local + Azure instances)
```

**1. Database design & build (on-premises)**
Designed and built the `HealthcarePractice` database from scratch on a local SQL Server instance: 9 tables (`claims`, `claim_lines`, `providers`, `payer`, `diagnosis`, `members`, `dim_date`, `authorizations`, `network_contracts`, `audit_log`), 3 views, and stored procedures. Also evaluated SQL Server ledger tables for tamper-evident audit logging (later dropped after evaluation — not needed for this use case).

**2. Cloud migration via Azure Data Factory**
Used ADF to migrate the full on-prem database — tables, views, and stored procedures — to a live Azure SQL Database (`sql-healthcarepractice-cr.database.windows.net`).

**3. Analytics integration via Microsoft Fabric**
Connected the same Azure SQL instance to Microsoft Fabric as the analytics layer, with a named query library feeding Power BI in Import mode.

**Result:** one Azure SQL database, accessible from three environments — SSMS, ADF, and Fabric — without duplicating data.

See [`docs/architecture.md`](docs/architecture.md) for more detail and [`docs/schema.md`](docs/schema.md) for the full table/column reference.

---

## Portfolio Projects

| # | Project | Status |
|---|---|---|
| 1 | [Claims Denial Analysis Dashboard](power-bi/README.md) | ✅ Complete |
| 2 | Member Enrollment Aging Report | 🔲 Planned |
| 3 | Data Quality Scorecard | 🔲 Planned |
| 4 | SSIS Enhancement — Audit Logging | 🔲 Planned |
| 5 | Fabric Warehouse Build | 🔲 Planned |

### Project 1 — Claims Denial Analysis Dashboard

Built a full-stack denial analytics solution: SQL view → Fabric named query → published Power BI report with DAX measures.

- **Top denial reason:** Duplicate Claim (24 denials, 23.5%) — an operational submission issue, not a clinical or coding error
- **Second driver:** Coding Error (22 denials, 21.6%)
- DAX measures: `Denial Rate %`, `Total Denied Amount`, `MoM Denial Change`, `Top Denial Reason`
- Report published to the `HealthcarePractice` Fabric workspace, two pages (Denial Analysis, Denial Reasons), payer/provider slicers

Full writeup and screenshots: [`power-bi/README.md`](power-bi/README.md)

---

## SQL Query Library

10 production-style queries, organized by purpose. Each file is commented with the business question it answers and the SQL technique it demonstrates.

| Query | Technique | Business Question |
|---|---|---|
| [`vw_denial_analysis`](sql/02_views/vw_denial_analysis.sql) | Multi-table JOIN, CASE WHEN, NULLIF | What's the denial rate by payer and provider? |
| [`denial_rate_by_provider_and_specialty`](sql/03_analytical_queries/denial_rate_by_provider_and_specialty.sql) | `RANK() OVER (PARTITION BY)` | How does each provider rank against peers in their specialty? |
| [`claim_turnaround_time`](sql/03_analytical_queries/claim_turnaround_time.sql) | `DATEDIFF`, AVG/MIN/MAX | How fast are claims processed by provider-payer combination? |
| [`member_utilization`](sql/03_analytical_queries/member_utilization.sql) | `COUNT(DISTINCT)` | How many unique members are utilizing services by plan type? |
| [`denial_reason_trend_by_month`](sql/03_analytical_queries/denial_reason_trend_by_month.sql) | CTE + `LAG()` | Are denial reasons trending up or down month-over-month? |
| [`provider_network_status_impact`](sql/03_analytical_queries/provider_network_status_impact.sql) | Conditional aggregation | Do out-of-network claims deny at a different rate? |
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

## Key Technical Learnings

A few of the architectural and SQL principles applied throughout this build — full list in [`docs/learnings.md`](docs/learnings.md):

- **CTEs are a readability tool, not a performance optimizer** — SQL Server inlines them before generating execution plans
- **Fabric's SQL analytics endpoint is read-only** — views are saved via "Save as view" in the UI, not `CREATE VIEW` DDL; named queries are the practical equivalent of views for Power BI consumption
- **Direct Lake mode doesn't support SQL views**, only Delta tables in OneLake — Import mode in Power BI was the practical workaround under Fabric trial (F2) capacity limits
- **`NOT EXISTS` outperforms `LEFT JOIN` / `IS NULL`** for orphan-record checks on large datasets
- **Window functions don't collapse rows** — unlike `GROUP BY`, `RANK() OVER` keeps every row and adds a ranking column alongside it

---

## Stack

`SQL Server` `Azure Data Factory` `Azure SQL Database` `Microsoft Fabric` `Power BI` `DAX` `SSIS` `T-SQL`

---

## Contact

Charles Richardson — open to healthcare data analytics roles.
