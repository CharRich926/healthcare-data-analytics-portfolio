# Database Setup

Run these scripts in order against an empty `HealthcarePractice` database.

| Order | File | What it does |
|---|---|---|
| 1 | `01_create_tables.sql` | Creates all 9 tables in FK dependency order |
| 2 | `02_create_indexes.sql` | Adds 4 non-clustered indexes to `dbo.claims` |
| 3 | `03_seed_data.sql` | Inserts 8 members, 7 providers, 16 claims, 8 authorizations |
| 4 | `04_alter_claims_add_payer.sql` | Seeds payer table, adds `payer_id` to claims, populates FK, seeds diagnosis lookup |

> **Note:** Script 4 documents post-insert ALTER TABLE changes made after the initial build — the pattern of ADD column (nullable) → UPDATE to populate → ADD CONSTRAINT is intentional and required when altering a table that already has rows.

## Table dependency order

Tables must be created in this order so foreign key constraints resolve correctly:

```
Tier 1 (no FKs):    members, providers, payer, diagnosis, dim_date, audit_log
Tier 2 (FK → T1):   claims, network_contracts, authorizations
Tier 3 (FK → T2):   claim_lines
```

## Schema note

`dbo.diagnosis.icd10_code` joins to `dbo.claims.diagnosis_code` — these are the same value with different column names across tables. Always write the join as:

```sql
JOIN dbo.diagnosis d ON d.icd10_code = c.diagnosis_code
```
