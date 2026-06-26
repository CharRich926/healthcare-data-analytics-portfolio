# Python — Data Quality Framework

## Overview

Reusable, parameterized Python data quality functions built to mirror the SQL audit queries in [`sql/04_data_quality_audits/`](../sql/04_data_quality_audits/). Functions accept any pandas DataFrame and column name, run the check, and return a results dictionary. All five checks are compiled into a consolidated pass/fail report at a configurable threshold.

Built and executed in Databricks Community Edition (PySpark + pandas). Designed as a standalone module — functions are independent of Databricks and can run in any Python environment.

---

## File

### `data_quality_functions.py`

5 parameterized functions covering the four standard data quality dimensions plus JSON schema validation:

| Function | Dimension | SQL Equivalent |
|---|---|---|
| `check_completeness(df, column)` | Completeness | `SUM(CASE WHEN col IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*)` |
| `check_uniqueness(df, column)` | Uniqueness | `COUNT(DISTINCT col) * 100.0 / COUNT(*)` |
| `check_validity(df, column, valid_values)` | Validity | `SUM(CASE WHEN col IN (...) THEN 1 ELSE 0 END) * 100.0 / COUNT(*)` |
| `check_integrity(df, fk_column, valid_ids)` | Integrity | FK JOIN to reference table — matched rows / total rows |
| `validate_json_schema(path, required_fields)` | Schema | No SQL equivalent — per-record field presence check |
| `run_quality_report(df, known_member_ids)` | All dimensions | Runs all 4 metric checks, returns consolidated DataFrame |

---

## Usage

```python
import pandas as pd
from data_quality_functions import (
    check_completeness,
    check_uniqueness,
    check_validity,
    check_integrity,
    run_quality_report
)

# Load your DataFrame
df = pd.read_csv("claims.csv")

# Run individual checks
print(check_completeness(df, "claim_id"))
print(check_validity(df, "claim_status", ["Approved", "Denied", "Pending"]))

# Run consolidated report
known_member_ids = list(df["member_id"].dropna().unique())
report = run_quality_report(df, known_member_ids)
print(report)
```

---

## Consolidated Report Output

```
=== HealthcarePractice Data Quality Report ===
   Check Type          Column  Score (%)  Pass
0  Completeness        claim_id    100.0  True
1  Completeness  procedure_code    100.0  True
2    Uniqueness        claim_id    100.0  True
3      Validity    claim_status    100.0  True
4     Integrity       member_id    100.0  True
```

**Pass threshold:** 95.0% — matches the Power BI Data Quality Scorecard KPI card standard.

---

## Design Principles

- **Parameterized** — every function accepts any DataFrame and column name; not hardcoded to the claims table
- **SQL-equivalent comments** — each function documents its T-SQL equivalent inline for clarity
- **Consistent output** — every function returns a dict with the same structure; easy to compile into a DataFrame
- **Threshold-configurable** — `run_quality_report()` accepts a `pass_threshold` parameter (default 95.0)
- **JSON validation** — `validate_json_schema()` addresses semi-structured data quality that SQL constraints can't catch upstream

---

## Stack

`Python` `pandas` `Databricks` `PySpark` `JSON`
