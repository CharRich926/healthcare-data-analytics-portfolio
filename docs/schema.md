# Database Schema — HealthcarePractice

9 core tables modeling a healthcare payer/provider claims environment. Built on-premises in SQL Server, migrated to Azure SQL Database via Azure Data Factory, and exposed through Microsoft Fabric for analytics.

> **Note:** Column lists below are based on the tables and join logic used throughout the SQL query library in this repo. See [`sql/01_database_setup/`](../sql/01_database_setup/) for the exact `CREATE TABLE` definitions.

---

## Tables

### dbo.claims
Core claims fact table. One row per submitted claim.

Key columns: `claim_id`, `member_id`, `provider_id`, `payer_id`, `diagnosis_code` (joins to `diagnosis.icd10_code`), `service_date`, `claim_status`, `denial_reason`, `billed_amount`, `allowed_amount`, `procedure_code`, `load_timestamp`.

### dbo.claim_lines
Line-item detail for each claim (procedure-level granularity).

### dbo.providers
Provider directory.

Key columns: `provider_id`, `provider_name`, `specialty`, `network_status`, `group_name`.

> **Schema correction:** `provider_type` does not exist in this schema — `network_status` and `group_name` are the correct fields for provider categorization.

### dbo.payer
Payer (insurance company) directory.

Key columns: `payer_id`, `payer_name`.

### dbo.diagnosis
ICD-10 diagnosis code lookup.

Key columns: `icd10_code`, `description`.

> **Known data quality gap:** This lookup table has only 8 rows, while `claims.diagnosis_code` contains 20+ distinct codes — resulting in 20 claims with unmatched diagnosis codes. See [`sql/04_data_quality_audits/Orphaned_Records_Check.sql`](../sql/04_data_quality_audits/Orphaned_Records_Check.sql).

### dbo.members
Member (patient) directory.

Key columns: `member_id`, `plan_type`, `enrollment_date`.

### dbo.dim_date
Date dimension table for time-based reporting.

### dbo.authorizations
Prior authorization records linked to claims.

Key columns: `auth_id`, `member_id`, `provider_id`, `auth_status`, `request_date`, `decision_date`, `auth_type`.

### dbo.network_contracts
Provider-payer network contract terms.

Key columns: `contract_id`, `provider_id`, `payer_id`, `start_date`, `end_date`, `contract_type`.

> **Data gap noted:** All `end_date` values in this table are NULL — network contracts expiring within 90 days query returns 0 rows as expected. Not a query bug.

### dbo.audit_log
Operational audit logging table. Populated by the SSIS `SCR_WriteAuditLog` Script Task after each pipeline run.

Key columns: `log_id`, `run_date`, `rows_inserted`, `rows_rejected`, `source_file`, `load_timestamp`.

---

## Fabric Warehouse Tables

### dbo.claims_summary (HealthcarePractice_Warehouse)
Aggregated claims summary table built directly in the Fabric Warehouse via T-SQL.

Key columns: `claim_status`, `total_claims`, `total_billed`, `total_allowed`, `total_paid`, `avg_billed`, `summary_date`.

Data as of June 24, 2026: Approved — 6 claims / $29,730 total billed; Denied — 4 claims / $11,260 total billed.

---

## Schema Correction Log

Two schema mismatches were identified and corrected during query development:

| Issue | Incorrect | Correct |
|---|---|---|
| Join key naming | `diagnosis.diagnosis_code` | `diagnosis.icd10_code` — joins to `claims.diagnosis_code` |
| Provider categorization | `providers.provider_type` | `providers.network_status` and `providers.group_name` |

---

## Views

| View | Purpose |
|---|---|
| `dbo.vw_denial_analysis` | Denial rate and denied amount aggregation by payer/provider |
| `dbo.vw_ActiveProviders` | Filtered list of currently active providers |
| `dbo.vw_ProviderClaimSummary` | Claim volume and outcome summary per provider |

---

## Indexes

Four non-clustered indexes were added to `dbo.claims` to support analytical query performance:

| Index column | Query pattern supported |
|---|---|
| `claim_status` | Denial rate filters, status aggregations |
| `payer_id` | Payer-level joins and groupings |
| `provider_id` | Provider-level joins and groupings |
| `service_date` | Date range filters, trend queries |

> At small data volumes, the SQL Server query optimizer may still choose a full table scan over an index seek — index design was validated conceptually, not purely by execution plan at this scale.
