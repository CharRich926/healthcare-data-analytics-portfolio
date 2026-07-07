# Architecture

This environment was built to mirror a real healthcare data platform's lifecycle: on-premises database design, cloud migration, analytics layer integration, and automation — with an ETL pipeline and orchestration layer running throughout.

---

## Overview

```
┌──────────────────────┐        ┌───────────────────────┐        ┌────────────────────────────┐
│  ON-PREMISES           │  ADF   │  AZURE SQL DATABASE     │ Connect │  MICROSOFT FABRIC            │
│  SQL Server (local)    │ ─────► │  (cloud, live)            │ ─────► │  Lakehouse + Warehouse        │
│                         │ migr. │  sql-healthcarepractice-cr │        │  + SQL endpoint                │
│  • 9 tables              │       │  .database.windows.net     │        │  + semantic model              │
│  • 3 views                │       │                             │        │  + Power BI                    │
│  • stored procedures       │       │                             │        │                                │
│  • 4 non-clustered indexes  │       │                             │        │  • 10 named queries              │
└──────────────────────┘        └───────────────────────┘        └────────────────────────────┘
          ▲                                                                        ▲
          │                                                                        │
          │  SSIS ETL Pipeline                                     Power Automate (3 flows)
          │  Integration Services Catalogs                         • File trigger → email notification
          │  deployed on local + Azure SQL                         • Weekly summary email
          │                                                         • Daily Power BI dataset refresh
   ┌──────────────┐
   │  Inbound       │                        ┌─────────────────────────────────────┐
   │  claims files   │                        │  DATABRICKS (Community Edition)      │
   └──────────────┘                        │  Unity Catalog volume                 │
                                            │  PySpark notebooks + Delta Lake        │
                                            │  Jobs scheduled daily 6AM Central      │
                                            │  → feeds Power BI refresh at 7AM       │
                                            └─────────────────────────────────────┘
```

---

## Stage 1 — On-Premises Database Design and Build

The `HealthcarePractice` database was designed and built from scratch on a local SQL Server instance using SSMS:

- 9 tables modeling claims, providers, payers, members, diagnoses, and supporting reference/audit data
- 3 views encapsulating common reporting logic (denial analysis, active providers, provider claim summary)
- Stored procedures for reusable data access patterns
- 4 non-clustered indexes added to the `claims` table to support analytical query patterns (`claim_status`, `payer_id`, `provider_id`, `service_date`)
- SQL Server ledger tables were evaluated for tamper-evident audit logging and later dropped — not required for this use case, but explored to understand the feature

---

## Stage 2 — Cloud Migration via Azure Data Factory

Azure Data Factory (ADF) was used to migrate the complete on-premises database — tables, views, and stored procedures — to a live Azure SQL Database instance (`sql-healthcarepractice-cr.database.windows.net`).

This stage validates a core data engineering skill: moving a working on-prem schema to the cloud without breaking referential integrity or query logic.

---

## Stage 3 — Analytics Integration via Microsoft Fabric

The same Azure SQL cloud instance was connected to Microsoft Fabric as the analytics layer. Two Fabric compute surfaces were built:

**Lakehouse (`HealthcarePractice_Lakehouse`)**
- 12 tables / 3,883 rows loaded via Copy Job from Azure SQL
- Semantic model with 5 relationships
- Power BI report in Direct Lake mode (`HealthcarePractice_Fabric`)
- Named query library of 13 queries saved against the SQL analytics endpoint

**Warehouse (`HealthcarePractice_Warehouse`)**
- Full read/write T-SQL compute layer — separate from the Lakehouse
- `dbo.claims_summary` table built via T-SQL (`CREATE TABLE` + `INSERT`)
- Power BI connected directly to Warehouse semantic model (`HealthcarePractice_Warehouse_Model`)
- Verified end-to-end: Approved $29,730 / Denied $11,260 rendering correctly in Power BI

**Key constraint discovered:** Direct Lake mode does not support SQL views — only Delta tables stored in OneLake. Import mode in Power BI Desktop was used as the practical workaround under Fabric trial (F2) capacity limits.

---

## Stage 4 — ETL Layer (SSIS)

An SSIS ETL pipeline (`Load_NewClaims.dtsx`) was built in Visual Studio for inbound claims file processing:

- File validation via Script Task (`SCR_CheckFileExists`)
- Lookup transforms for member and provider referential integrity — unmatched rows routed to reject file
- Audit logging via VB.NET Script Task (`SCR_WriteAuditLog`) — writes run timestamp, rows inserted, and rows rejected to `dbo.audit_log` after each execution
- Archive task moves processed files to `Claims/Archive/` with date-stamped filename
- Integration Services Catalogs deployed on both local and Azure SQL instances

---

## Stage 5 — Automation & Orchestration (Week 2)

**Databricks (Community Edition)**
- Unity Catalog volume: `/Volumes/workspace/default/hc_practice_data/`
- PySpark notebooks for data ingestion, transformation, and Delta table writes
- Delta table `workspace.default.claims` created via `saveAsTable()`
- Job `HC_WeeklyClaims_DataLoad` scheduled daily at 6AM (America/Chicago)

**Power Automate (3 cloud flows)**
- `HC_NewClaims_File_Trigger` — event-driven; fires when a file lands in OneDrive folder, sends Outlook.com email with dynamic filename
- `HC_Weekly_Claims_Summary` — scheduled every Monday; sends claims summary email with `formatDateTime()` dynamic date in subject
- `HC_Refresh_PowerBI_Dataset` — scheduled daily at 7AM; refreshes `HealthcarePractice_SemanticModel` in Power BI

**Pipeline sequencing:** Databricks Job at 6AM → Power BI refresh at 7AM — ensures the semantic model always reflects the latest data.

**Python data quality framework**
- 5 parameterized functions (`check_completeness`, `check_uniqueness`, `check_validity`, `check_integrity`, `validate_json_schema`)
- Output: consolidated pandas DataFrame with Pass/Fail at 95% threshold — mirrors the Power BI KPI scorecard standard
- See [`Python/data_quality_functions.py`](../Python/data_quality_functions.py)

---

## Result: One Database, Multiple Environments

The same Azure SQL database is accessible from:

| Tool | Role |
|---|---|
| SSMS | Direct query access — on-prem and cloud connections side by side |
| ADF | Migration and pipeline layer |
| Fabric Lakehouse | Analytics layer — Delta tables, SQL endpoint, named queries |
| Fabric Warehouse | Full read/write T-SQL layer — claims summary, Power BI semantic model |
| Databricks | PySpark transformation and Delta Lake writes |
| Power BI | Reporting layer — connects to both Fabric semantic models |
| Power Automate | Orchestration — file triggers, scheduled emails, dataset refresh |

No data is duplicated across environments — each tool connects to the same underlying Azure SQL source.

## HC_Load_Claims_FromAzureSQL (Fabric Data Pipeline)

**Purpose:** Loads claims data from Azure SQL Database into the Fabric Warehouse layer, replacing the ADF-based approach originally planned (ADF permanently dropped due to persistent Microsoft account access blocks).

**Source:** Azure SQL Database — sql-healthcarepractice-cr.database.windows.net / HealthcarePractice / dbo.claims

**Destination:** HealthcarePractice_Warehouse (Fabric Warehouse) / dbo.claims

**Load type:** Full copy (entire table reloaded each run, not incremental)

**Trigger:** Manual only — no schedule currently configured

**Last verified run:** 6/30/2026, 46 sec duration, 552 rows read / 552 rows written, succeeded

**Notes:** Single Copy job activity (Copy job_e01) wrapped in the pipeline. No transformations applied in-flight — straight table-to-table copy; any shaping happens downstream in Warehouse views/stored procedures. Adding a schedule is a candidate follow-up if this pipeline needs to run on a recurring cadence going forward.
