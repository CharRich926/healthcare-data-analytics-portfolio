# Fabric

Microsoft Fabric artifacts for the HealthcarePractice simulation — Data Pipelines, Warehouse, and Lakehouse layer.

## Pipelines

- **HC_Load_Claims_FromAzureSQL** — Copies `dbo.claims` from Azure SQL into `HealthcarePractice_Warehouse`. Manual trigger only (no schedule configured).
- **HC_Load_Authorizations_FromAzureSQL / CopyJob_Authorizations** — Copies `dbo.authorizations` from Azure SQL into `HealthcarePractice_Warehouse`. Scheduled every 24 hours (Fabric's Copy Job scheduler only supports "By the minute" and "Hourly" cadences — no native Daily option).
- **HC_Load_Claims_Incremental** (Week 5 Monday, watermark fix Week 5 Wednesday) — Copy Data activity that appends new/changed rows from Azure SQL `dbo.claims` into `HealthcarePractice_Lakehouse.dbo.claims`, in Append mode rather than Overwrite. Manual trigger only. Built as the Fabric-native equivalent of the SSIS `Load_NewClaims.dtsx` check-load-archive-audit pattern, adapted to a live database source rather than a dropped file.

  **Source query (current):** dynamic, watermark-driven — no hardcoded date. The pipeline is a 4-activity chain: `LU_Get_Watermark` (reads `last_loaded_date` from a `dbo.pipeline_watermark` control table in `HealthcarePractice_Warehouse`) → `LU_Get_New_Max_Date` (queries Azure SQL directly for `MAX(service_date)` among rows newer than the watermark) → the Copy Data activity itself (source query built with `@concat(...)`, filtering strictly to rows after the watermark) → `SCR_Update_Watermark` (writes the new max date back to the control table). Re-running the pipeline correctly pulls only what's new since the last successful run — no manual date-tightening required, and no duplicate-key risk from re-pulling already-loaded rows.

  **Evolution of this pipeline's source filter, for the record:** (1) originally a rolling `DATEADD(DAY, -30, MAX(service_date))` window — caused duplicate `claim_id` values on a second run, since it had no memory of what was already loaded; (2) tightened same-day to a manually-set fixed cutoff date as a stopgap; (3) replaced Week 5 Wednesday with the true watermark-table pattern described above. See `docs/learnings.md` (Microsoft Fabric section) for the full failure modes and fixes at each stage, including an architectural bug hit while building stage 3 — the watermark-update step initially queried the Warehouse's stale copy of `claims` instead of the live Azure SQL source, returning NULL and failing the control-table update.

  **Verified outcome:** confirmed end-to-end twice — first (Monday) by running the pipeline against 3 newly inserted Azure SQL rows and observing Power BI's `Denial Drivers` page Total Claims move from 552 → 555 (and Denied 102 → 103) on refresh; second (Wednesday) by confirming the full 4-activity chain succeeds end-to-end and `dbo.pipeline_watermark.last_loaded_date` correctly advances (2024-12-28 → 2024-12-31) after a run.

- **HC_Load_Warehouse_Reference_Tables** (Week 5 Wednesday) — Two Copy Data activities (`CD_Load_Providers`, `CD_Load_Network_Contracts`) bringing `dbo.providers` and `dbo.network_contracts` from Azure SQL into `HealthcarePractice_Warehouse`, closing a gap where those two tables existed in the Lakehouse but not the Warehouse. Manual trigger only. Uses "Auto create table" (schema inferred from source) with "Upsert" write behavior keyed on `provider_id` / `contract_id` respectively — a simpler full-reload pattern than the claims watermark approach above, appropriate since these are static reference/dimension tables with no natural "new since last load" boundary. Verified via table metadata post-run: `providers` (20 rows, 9 columns) and `network_contracts` (6 rows, 6 columns), both non-zero with correctly inferred schema.

## Data Source Change (Week 5 Monday)

The `HealthcarePractice` Power BI report (Report 2 in `power-bi/README.md`) was repointed from Azure SQL Database directly to the `HealthcarePractice_Lakehouse` SQL analytics endpoint. Previously the report bypassed the Lakehouse entirely, which meant pipeline writes into the Lakehouse had no visible downstream effect — this was corrected as part of validating `HC_Load_Claims_Incremental` above.

## Known Fabric Behaviors (see `docs/learnings.md` for full detail)

- The SQL analytics endpoint is read-only — DML (`INSERT`/`UPDATE`/`DELETE`) against Lakehouse tables requires a Notebook (PySpark), not the SQL endpoint.
- The SQL analytics endpoint's metadata can lag several minutes behind actual Delta table writes (via Notebook or after a source subscription is disabled/re-enabled) — treat a Notebook's direct `spark.table(...).count()` as authoritative if the two disagree.

## Screenshots

`Fabric/screenshots/` — pipeline configuration and execution-proof screenshots for each pipeline above. Includes `warehouse_providers_table_verification.PNG` and `warehouse_network_contracts_table_verification.PNG` (Week 5 Wednesday, `HC_Load_Warehouse_Reference_Tables` verification).
