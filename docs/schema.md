# Database Schema — HealthcarePractice

9 core tables modeling a healthcare payer/provider claims environment. Built on-premises in SQL Server, migrated to Azure SQL Database via Azure Data Factory, and exposed through Microsoft Fabric for analytics.

> **Note:** Column lists below are based on the tables and join logic used throughout the SQL query library in this repo. Update with exact `CREATE TABLE` definitions from your environment if you want a fully precise reference (see `sql/01_database_setup/`).

## Tables

### `dbo.claims`
Core claims fact table. One row per submitted claim.

Key columns used across queries: `claim_id`, `member_id`, `provider_id`, `payer_id`, `diagnosis_code` (joins to `diagnosis.icd10_code`), `service_date`, `claim_status`, `denial_reason`, `billed_amount`, `allowed_amount`, `load_timestamp`.

### `dbo.claim_lines`
Line-item detail for each claim (procedure-level granularity).

### `dbo.providers`
Provider directory. Key columns: `provider_id`, `provider_name`, `specialty`, `network_status`, `group_name`.

> Schema correction applied during development: `provider_type` does **not** exist in this schema — `network_status` and `group_name` are the correct fields for provider categorization.

### `dbo.payer`
Payer (insurance company) directory. Key columns: `payer_id`, `payer_name`.

### `dbo.diagnosis`
ICD-10 diagnosis code lookup. Key columns: `icd10_code`, `description`.

> **Known data quality gap:** This lookup table has only 8 rows, while `claims.diagnosis_code` contains 20+ distinct codes — resulting in 20 claims with unmatched diagnosis codes (see `sql/04_data_quality_audits/Orphaned_Records_Check.sql`).

### `dbo.members`
Member (patient) directory. Key columns: `member_id`, `plan_type`, `enrollment_date`.

### `dbo.dim_date`
Date dimension table for time-based reporting.

### `dbo.authorizations`
Prior authorization records linked to claims.

### `dbo.network_contracts`
Provider-payer network contract terms.

### `dbo.audit_log`
Operational audit logging table (designed to support SSIS pipeline run logging — see `ssis/README.md`).

## Schema correction log

Two schema mismatches were identified and corrected during query development:

1. **Join key naming:** `diagnosis.icd10_code` is the correct join key to `claims.diagnosis_code` — these are equivalent fields with different names across tables, not a typo.
2. **Provider categorization:** `provider_type` does not exist in this schema. `network_status` and `group_name` on `dbo.providers` are the correct fields.

## Views

| View | Purpose |
|---|---|
| `dbo.vw_denial_analysis` | Denial rate and denied amount aggregation by payer/provider |
| `dbo.vw_ActiveProviders` | Filtered list of currently active providers |
| `dbo.vw_ProviderClaimSummary` | Claim volume and outcome summary per provider |

## Indexes

Four non-clustered indexes were added to `dbo.claims` to support analytical query performance:

- `claim_status`
- `payer_id`
- `provider_id`
- `service_date`

> At small data volumes, the SQL Server query optimizer may still choose a full table scan over an index seek — index design was validated conceptually, not purely by execution plan at this scale.
