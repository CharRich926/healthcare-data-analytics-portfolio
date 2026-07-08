# Fabric

Microsoft Fabric artifacts for the HealthcarePractice simulation — Data Pipelines, Warehouse, and Lakehouse layer.

## Pipelines

- **HC_Load_Claims_FromAzureSQL** — Copies `dbo.claims` from Azure SQL into `HealthcarePractice_Warehouse`. Manual trigger only (no schedule configured).
- **HC_Load_Authorizations_FromAzureSQL / CopyJob_Authorizations** — Copies `dbo.authorizations` from Azure SQL into `HealthcarePractice_Warehouse`. Scheduled every 24 hours (Fabric's Copy Job scheduler only supports "By the minute" and "Hourly" cadences — no native Daily option).

See `docs/architecture.md` for full configuration details, validation notes, and known limitations.

## Screenshots

`Fabric/screenshots/` — pipeline configuration and execution-proof screenshots for each pipeline above.
