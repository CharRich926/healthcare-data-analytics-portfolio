# healthcarepractice_dbt

dbt Core project layered on top of the `HealthcarePractice` Azure SQL Database, part of the broader [healthcare-data-analytics-portfolio](../README.md).

## Status

**Hands-on model-building work is currently paused.** Two staging models were built early on (see below); further hands-on work — schema tests, `ref()`-based model chaining, `dbt docs generate` — resumes after completing DataCamp's "Introduction to dbt" course. This was a deliberate decision: environment setup produced several friction points (stale virtual environment, a missing `DBT_SQL_PASSWORD` variable, a connection string error) alongside some syntax/formula unfamiliarity, so rather than push forward without a solid foundation, the course is being completed first.

**Positioning for interviews:** "Built a small dbt project, understand the core concepts" — not a specialization. SQL Server, SSIS, T-SQL, and Power BI remain the primary technical differentiators for this portfolio; dbt is a deliberately expanding skill, not a claimed area of depth.

## What's here

| Path | Contents |
|---|---|
| [`models/staging/stg_claims.sql`](models/staging/stg_claims.sql) | Staging model, materialized as a view in Azure SQL |
| [`models/staging/stg_claims_by_status.sql`](models/staging/stg_claims_by_status.sql) | Staging model, materialized as a view in Azure SQL, aggregates claims by `claim_status` |
| [`models/staging/sources.yml`](models/staging/sources.yml) | Source table definitions for the staging layer |

Both staging models are deployed and resume-credible as of Week 3.

## Roadmap

| Week | Focus |
|---|---|
| Week 3 (current) | Coursework first (DataCamp "Introduction to dbt"), then schema tests, a second chained model via `ref()`, and `dbt docs generate` |
| Week 4 | Schema tests (`not_null`, `unique`, `accepted_values`), documentation, `ref()` chaining — carries forward if not finished in Week 3 |
| Week 5 | SCD Type 2 via `dbt snapshot`, incremental materialization, Fabric Data Pipelines as orchestrator |
| Week 6 | dbt Cloud setup, job scheduling, GitHub Actions integration |

## Environment

- dbt Core, Python 3.13, `dbt-sqlserver` adapter
- Target: Azure SQL Database (`sql-healthcarepractice-cr.database.windows.net`)
- `profiles.yml` is excluded from this repo — no credentials are committed
