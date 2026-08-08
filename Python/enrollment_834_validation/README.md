# EDI 834 Enrollment Validation — Python → Databricks → Power BI

## Overview

Simulates the severity-based source-file validation pattern from real Empyrean client-configuration work: an inbound 834-style enrollment batch is validated in Python (critical vs. warning issues), the clean/flagged records are landed as a Delta table in Databricks, and the table is connected live to Power BI for reporting.

Built to demonstrate the specific stack a Molina-style Enrollment Research & Data Analytics role calls for: enrollment/eligibility data, Advanced SQL, Azure Databricks, and Power BI, in one connected pipeline rather than as separate disconnected exercises.

---

## Pipeline

```
Python (validation)  →  Databricks Unity Catalog volume  →  Delta table  →  Power BI (live connection)
```

**1. Python — `validate_enrollment_834.py`**
Generates a synthetic 25-record enrollment batch and validates each record with severity-based load control:

| Severity | Rule | Outcome |
|---|---|---|
| CRITICAL | Missing member ID | Record rejected |
| CRITICAL | Invalid/unroutable Line of Business (doesn't map to Medicaid/Medicare/Marketplace/Duals) | Record rejected |
| CRITICAL | Invalid coverage effective date | Record rejected |
| WARNING | Missing phone number | Loaded, flagged for review |
| WARNING | Ambiguous plan code | Loaded, flagged for review |
| WARNING | Late-submitted term date | Loaded, flagged for review |

Outputs three files to [`sample_output/`](sample_output/): `enrollment_loaded_sample.csv`, `enrollment_rejected_sample.csv`, and `audit_log_sample.csv` (every issue found, per record, tied to outcome).

**Note on fields:** no SSN field is used anywhere in this simulation. `member_id` is the working identifier, consistent with how modern enrollment systems (e.g., CMS's move from SSN-based HICN to the Medicare Beneficiary Identifier) have moved away from SSN as a working key.

**2. Databricks — `HC_Enrollment834_Week6` notebook**
- `enrollment_loaded_sample.csv` uploaded to the existing Unity Catalog volume (`/Volumes/workspace/default/hc_practice_data/`)
- Read via `spark.read.csv()`, inspected (`.show()`, `.printSchema()`, `.groupBy().count()`)
- Written to a Delta table via `.write.mode("overwrite").saveAsTable("workspace.default.enrollment_834")`
- Verified queryable directly via `%sql` against the registered table

**3. Power BI — live Databricks connection**
Power BI Desktop connects directly to the Databricks SQL Warehouse (ADBC driver, Personal Access Token auth) and reads `workspace.default.enrollment_834` live — not a flat-file export. Report build in progress.

---

## Design Principles

- **Severity-based load control** — mirrors the real Empyrean pattern of distinguishing hard-stop errors from soft warnings, rather than a single pass/fail gate
- **Audit-first** — every record's full issue list is logged regardless of outcome, so a rejected record's warnings are still visible, not just the critical error that killed it
- **No PII beyond what's necessary** — SSN deliberately excluded; `member_id` carries the record
- **Self-contained cells** — each Databricks notebook cell re-declares `df` independently, consistent with Community/Free Edition serverless compute not persisting variables across cells

---

## Stack

`Python` `Databricks` `PySpark` `Delta Lake` `Unity Catalog` `Power BI` `SQL`
