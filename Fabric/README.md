# Fabric

Microsoft Fabric artifacts for the HealthcarePractice simulation — Data Pipelines, Warehouse, Lakehouse, and Power BI App layer.

## Workspace Organization (Week 5 Friday)

The workspace was reorganized from 18 loose root-level items into 4 folders, using Fabric's now-generally-available Workspace Folders feature:

| Folder | Contents |
|---|---|
| `Lake_and_Ware_House` | `HealthcarePractice_Lakehouse`, `HealthcarePractice_Warehouse`, and their SQL analytics endpoints |
| `Notebooks` | `HealthcarePractice_Analytics`, `HC_Payer_Claims_Correction`, `HC_Claims_RowCount_Check` |
| `Pipeline_CopyJobs` | All `HC_Load_*` pipelines and `CopyJob_*` items |
| `Reports_SemanticModels` | `HealthcarePractice` report + semantic model, plus the auto-generated `HealthcarePractice_SemanticModel` and `HealthcarePractice_Warehouse_Model` |

**Clean-up also included:**
- Deleted 4 stale/duplicate report-and-semantic-model pairs across two workspaces: `HC_Practice_DenialAnlysis_BI_Report` (oldest, contained a naming typo), `HealthcarePractice_Fabric` (confirmed stale via a 564 vs. 555 claim-count mismatch against the live report), and a `HealthcarePractice` report + semantic model pair sitting in **My workspace**, confirmed stale (June data, unscrubbed real payer names) and disconnected from the main workspace entirely
- Renamed generic items to match the underscore naming convention: `CopyJob_1` → `CopyJob_Claims_ToWarehouse`, `Notebook 1` → `HC_Payer_Claims_Correction`, `Notebook 2` → `HC_Claims_RowCount_Check`
- Confirmed `HealthcarePractice_SemanticModel` and `HealthcarePractice_Warehouse_Model` are Fabric's auto-generated default semantic models (created automatically alongside the Lakehouse/Warehouse, not user-built) — left in place rather than deleted, since they carry no clutter cost beyond the workspace list itself and deleting a Lakehouse/Warehouse's default model can have unpredictable side effects

## Pipelines

- **HC_Load_Claims_FromAzureSQL** — Copies `dbo.claims` from Azure SQL into `HealthcarePractice_Warehouse`. Manual trigger only (no schedule configured).
- **HC_Load_Authorizations_FromAzureSQL / CopyJob_Authorizations** — Copies `dbo.authorizations` from Azure SQL into `HealthcarePractice_Warehouse`. Scheduled every 24 hours (Fabric's Copy Job scheduler only supports "By the minute" and "Hourly" cadences — no native Daily option).
- **HC_Load_Claims_Incremental** (Week 5 Monday, watermark fix Week 5 Wednesday) — Copy Data activity that appends new/changed rows from Azure SQL `dbo.claims` into `HealthcarePractice_Lakehouse.dbo.claims`, in Append mode rather than Overwrite. Manual trigger only. Built as the Fabric-native equivalent of the SSIS `Load_NewClaims.dtsx` check-load-archive-audit pattern, adapted to a live database source rather than a dropped file.

  **Source query (current):** dynamic, watermark-driven — no hardcoded date. The pipeline is a 4-activity chain: `LU_Get_Watermark` (reads `last_loaded_date` from a `dbo.pipeline_watermark` control table in `HealthcarePractice_Warehouse`) → `LU_Get_New_Max_Date` (queries Azure SQL directly for `MAX(service_date)` among rows newer than the watermark) → the Copy Data activity itself (source query built with `@concat(...)`, filtering strictly to rows after the watermark) → `SCR_Update_Watermark` (writes the new max date back to the control table). Re-running the pipeline correctly pulls only what's new since the last successful run — no manual date-tightening required, and no duplicate-key risk from re-pulling already-loaded rows.

  **Evolution of this pipeline's source filter, for the record:** (1) originally a rolling `DATEADD(DAY, -30, MAX(service_date))` window — caused duplicate `claim_id` values on a second run, since it had no memory of what was already loaded; (2) tightened same-day to a manually-set fixed cutoff date as a stopgap; (3) replaced Week 5 Wednesday with the true watermark-table pattern described above. See `docs/learnings.md` (Microsoft Fabric section) for the full failure modes and fixes at each stage, including an architectural bug hit while building stage 3 — the watermark-update step initially queried the Warehouse's stale copy of `claims` instead of the live Azure SQL source, returning NULL and failing the control-table update.

  **Verified outcome:** confirmed end-to-end twice — first (Monday) by running the pipeline against 3 newly inserted Azure SQL rows and observing Power BI's `Denial Drivers` page Total Claims move from 552 → 555 (and Denied 102 → 103) on refresh; second (Wednesday) by confirming the full 4-activity chain succeeds end-to-end and `dbo.pipeline_watermark.last_loaded_date` correctly advances (2024-12-28 → 2024-12-31) after a run.

  **Known follow-up (Week 5 Thursday):** despite the watermark fix, a routine Thursday refresh found `claim_id 1319` with four fully identical duplicate rows in the Lakehouse — likely a re-run artifact from around the same watermark boundary tested Wednesday. Fixed via a one-off `dropDuplicates()` in a notebook (see Notebooks section below); worth revisiting whether the watermark logic still has an edge case at the boundary date if duplicates recur.

- **HC_Load_Warehouse_Reference_Tables** (Week 5 Wednesday) — Two Copy Data activities (`CD_Load_Providers`, `CD_Load_Network_Contracts`) bringing `dbo.providers` and `dbo.network_contracts` from Azure SQL into `HealthcarePractice_Warehouse`, closing a gap where those two tables existed in the Lakehouse but not the Warehouse. Manual trigger only. Uses "Auto create table" (schema inferred from source) with "Upsert" write behavior keyed on `provider_id` / `contract_id` respectively — a simpler full-reload pattern than the claims watermark approach above, appropriate since these are static reference/dimension tables with no natural "new since last load" boundary. Verified via table metadata post-run: `providers` (20 rows, 9 columns) and `network_contracts` (6 rows, 6 columns), both non-zero with correctly inferred schema.

## Notebooks

- **HC_Payer_Claims_Correction** (Week 5 Thursday, renamed from `Notebook 1`) — PySpark notebook holding the two Lakehouse data-quality fixes found ahead of the Power BI App publish: (1) rebuilt `payer` via a full `overwrite` write of the corrected 8-row scrubbed reference set, resolving a Delta schema-merge conflict with `.option("overwriteSchema", "true")`; (2) deduplicated `claims` via `dropDuplicates()` after finding `claim_id 1319` with four fully identical rows. Both verified with a read-back query in the same session before moving on.
- **HC_Claims_RowCount_Check** (renamed from `Notebook 2`) — standalone row-count validation notebook (`spark.table("claims").count()`), predates Thursday's dedup fix; its last recorded count (552) is now stale and should be rerun for a current figure if reused.
- **HealthcarePractice_Analytics** — general-purpose analytics notebook, ongoing.

## Power BI App (Week 5 Thursday)

Published the first curated **App** from the `HealthcarePractice` workspace off the `HealthcarePractice` report, selecting 6 of the report's 8 pages: Claims Overview, Provider Performance, Member Analysis, Denial Analysis, Authorizations, Denial Drivers. Excluded Data Quality Scorecard and Time Intelligence Validation as dev/QA-oriented pages not meant for viewer-facing content. Audience scoped to specific users. Full detail and screenshots: `power-bi/README.md`.

## Data Source Change (Week 5 Monday)

The `HealthcarePractice` Power BI report (Report 2 in `power-bi/README.md`) was repointed from Azure SQL Database directly to the `HealthcarePractice_Lakehouse` SQL analytics endpoint. Previously the report bypassed the Lakehouse entirely, which meant pipeline writes into the Lakehouse had no visible downstream effect — this was corrected as part of validating `HC_Load_Claims_Incremental` above.

## Known Fabric Behaviors (see `docs/learnings.md` for full detail)

- The SQL analytics endpoint is read-only — DML (`INSERT`/`UPDATE`/`DELETE`) against Lakehouse tables requires a Notebook (PySpark), not the SQL endpoint.
- The SQL analytics endpoint's metadata can lag several minutes behind actual Delta table writes (via Notebook or after a source subscription is disabled/re-enabled) — treat a Notebook's direct `spark.table(...).count()` as authoritative if the two disagree.
- Fabric Warehouse `CREATE TABLE` rejects `PRIMARY KEY`, requires explicit `DATETIME2` precision, and requires `IDENTITY` columns to be typed `BIGINT` rather than `INT`.
- Delta `.write().mode("overwrite")` merges the incoming schema with the existing table's schema by default rather than replacing it — `.option("overwriteSchema", "true")` is required for a genuine full schema replacement.

## Screenshots

`Fabric/screenshots/` — pipeline configuration and execution-proof screenshots for each pipeline above. Includes `warehouse_providers_table_verification.PNG` and `warehouse_network_contracts_table_verification.PNG` (Week 5 Wednesday, `HC_Load_Warehouse_Reference_Tables` verification).
