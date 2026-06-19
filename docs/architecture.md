# Architecture

This environment was built to mirror a real healthcare data platform's lifecycle: on-premises database design, cloud migration, and analytics layer integration — with an ETL pipeline running throughout.

## Overview

```
┌──────────────────────┐        ┌───────────────────────┐        ┌────────────────────────┐
│  ON-PREMISES           │  ADF   │  AZURE SQL DATABASE     │ Connect │  MICROSOFT FABRIC        │
│  SQL Server (local)    │ ─────► │  (cloud, live)            │ ─────► │  Lakehouse + SQL          │
│                         │ migr. │  sql-healthcarepractice-cr │        │  endpoint + semantic      │
│  • 9 tables              │       │  .database.windows.net     │        │  model + Power BI          │
│  • 3 views                │       │                             │        │                            │
│  • stored procedures       │       │                             │        │  • 10 named queries          │
│  • 4 non-clustered indexes  │       │                             │        │  • Import mode reporting      │
└──────────────────────┘        └───────────────────────┘        └────────────────────────┘
          ▲
          │
          │  SSIS ETL Pipeline
          │  Integration Services Catalogs
          │  deployed on BOTH local + Azure SQL
          │
   ┌──────────────┐
   │  Inbound       │
   │  claims files   │
   └──────────────┘
```

## Stage 1 — On-premises database design and build

The `HealthcarePractice` database was designed and built from scratch on a local SQL Server instance using SSMS:

- 9 tables modeling claims, providers, payers, members, diagnoses, and supporting reference/audit data
- 3 views encapsulating common reporting logic (denial analysis, active providers, provider claim summary)
- Stored procedures for reusable data access
- 4 non-clustered indexes added to the `claims` table to support analytical query patterns (`claim_status`, `payer_id`, `provider_id`, `service_date`)
- SQL Server ledger tables were evaluated for tamper-evident audit logging and later dropped — not required for this use case, but explored to understand the feature

## Stage 2 — Cloud migration via Azure Data Factory

Azure Data Factory (ADF) was used to migrate the complete on-premises database — tables, views, and stored procedures — to a live Azure SQL Database instance (`sql-healthcarepractice-cr.database.windows.net`).

This stage validates a core data engineering skill: moving a working on-prem schema to the cloud without breaking referential integrity or query logic.

## Stage 3 — Analytics integration via Microsoft Fabric

The same Azure SQL cloud instance was connected to Microsoft Fabric. Because the Fabric SQL analytics endpoint is read-only, views could not be created via `CREATE VIEW` DDL directly in Fabric — instead, a **named query library** of 10 SELECT statements was built and saved against the endpoint, functioning as the practical equivalent of views for Power BI consumption.

**Key constraint discovered:** Direct Lake mode in Fabric does not support SQL views — only Delta tables stored in OneLake. Given Fabric trial (F2) capacity limits on Spark compute, **Import mode in Power BI Desktop** was used as the practical workaround rather than materializing Delta tables via PySpark.

## Result: one database, three environments

The same Azure SQL database is accessible from:

1. **SSMS** — direct query access, on-prem and cloud connections side by side
2. **ADF** — the migration/pipeline layer
3. **Fabric** — the analytics layer feeding Power BI

No data is duplicated across environments — each tool connects to the same underlying source.

## ETL layer — SSIS

An SSIS ETL pipeline was built in Visual Studio for inbound claims file processing, with Integration Services Catalogs deployed on **both** the local and Azure SQL instances. This supports the audit logging enhancement planned in Project 4 (logging run date, row counts, and rejected records for each pipeline execution).
