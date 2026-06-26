# Databricks — PySpark Notebooks & Delta Lake

## Overview

Two PySpark notebooks built in Databricks Community Edition demonstrating data ingestion, transformation, analytical queries, and a Python data quality framework — all against the HealthcarePractice claims dataset. Notebooks are self-contained (each cell re-declares its Spark context) to work reliably on Databricks Serverless compute.

---

## Environment

| Property | Value |
|---|---|
| Platform | Databricks Community Edition |
| Compute | Serverless (no persistent cluster) |
| Catalog | Unity Catalog |
| Volume path | `/Volumes/workspace/default/hc_practice_data/` |
| Delta table | `workspace.default.claims` |
| Scheduled job | `HC_WeeklyClaims_DataLoad` — daily 6AM America/Chicago |
| Language | Python (PySpark + pandas) |

---

## Notebooks

### HC_Practice_Week2_Monday.ipynb

**Focus:** Data ingestion, DataFrame exploration, PySpark analytical queries

| Cell | What It Does | SQL Equivalent |
|---|---|---|
| 1 | `spark.read.csv()` from Unity Catalog volume — load claims into Spark DataFrame | `SELECT * FROM claims` |
| 2 | `df.show()`, `df.printSchema()`, `df.describe()` — data profiling | `sp_help`, `SELECT TOP 10` |
| 3 | `df.filter()` — count denied claims | `SELECT COUNT(*) WHERE claim_status = 'Denied'` |
| 4 | `groupBy().agg()` — denial rate by provider | `GROUP BY provider_id` with aggregates |
| 5 | `countDistinct()` + `Window.partitionBy()` — member utilization | `COUNT(DISTINCT member_id) PARTITION BY plan_type` |

**Key pattern:** Self-contained cells — `spark.read.csv()` is re-declared in each cell because Databricks Serverless compute does not persist variables across cells.

---

### HC_Practice_Week2_Thursday.ipynb

**Focus:** Reusable Python data quality functions + JSON schema validation

| Cell | Function | SQL Equivalent |
|---|---|---|
| 1 | Imports + load data | Setup |
| 2 | `check_completeness(df, column)` | `SUM(CASE WHEN col IS NOT NULL ...)` |
| 3 | `check_uniqueness(df, column)` | `COUNT(DISTINCT col) / COUNT(*)` |
| 4 | `check_validity(df, column, valid_values)` | `SUM(CASE WHEN col IN (...) ...)` |
| 5 | `check_integrity(df, fk_column, valid_ids)` | FK JOIN to reference table |
| 6 | `validate_json_schema(path, required_fields)` | No SQL equivalent |
| 7 | Consolidated quality report — pandas DataFrame with Pass/Fail at 95% threshold | — |

**Results:** All 5 checks scored 100% — Completeness (claim_id, procedure_code), Uniqueness (claim_id), Validity (claim_status), Integrity (member_id). Full function library: [`../Python/data_quality_functions.py`](../Python/data_quality_functions.py)

---

## Delta Lake

The `workspace.default.claims` Delta table was created from the claims CSV via `saveAsTable()`:

```python
df.write.format("delta").mode("overwrite").saveAsTable("workspace.default.claims")
```

This registers the DataFrame as a permanent Delta table in Unity Catalog — the equivalent of `CREATE TABLE AS SELECT` in T-SQL — making it queryable from Databricks SQL Editor, notebooks, and external tools.

---

## Databricks SQL Editor

A summary query was saved in the SQL Editor as `HC_Claims_Summary_By_Status`:

```sql
SELECT
    claim_status,
    COUNT(*)        AS total_claims,
    SUM(billed_amount) AS total_billed
FROM workspace.default.claims
GROUP BY claim_status
ORDER BY total_claims DESC
```

**Results:** Approved — 6 claims, $29,730 total billed | Denied — 4 claims, $11,260 total billed

---

## Scheduled Job

`HC_WeeklyClaims_DataLoad` runs the `HC_Practice_Week2_Monday` notebook daily at 6AM (America/Chicago) — the Databricks equivalent of a SQL Agent job. Sequenced to complete before the Power Automate flow refreshes the Power BI semantic model at 7AM.

---

## Screenshots

| File | Description |
|---|---|
| `Databricks_PySpark_Consolidated_quality_report.PNG` | Cell 7 output — consolidated pass/fail quality report DataFrame |
| `Databricks_spark_denial_rate_by_provider_and_specialty.PNG` | groupBy().agg() denial rate analysis output |

---

## Key Learnings

- **Serverless compute doesn't persist variables** — each cell must be self-contained; re-declare `spark.read.csv()` in every cell that needs the DataFrame
- **`saveAsTable()`** registers a permanent Delta table in Unity Catalog — survives cluster restarts
- **Databricks Jobs** are the equivalent of SQL Agent jobs — scheduled notebook execution with configurable timezone
- **No matplotlib** — visualization belongs in Power BI; Databricks is for data engineering and transformation only

---

## Stack

`Databricks` `PySpark` `Python` `pandas` `Delta Lake` `Unity Catalog` `Databricks SQL` `Databricks Jobs`
