# =============================================================================
# HealthcarePractice — Data Quality Functions
# Author: Charles Richardson
# Date: June 24, 2026
# Environment: Databricks Community Edition (PySpark + pandas)
# Notebook: HC_Practice_Week2_Thursday
# =============================================================================
#
# Reusable parameterized data quality functions that mirror the SQL audit
# queries built in Week 1/2. Each function accepts a pandas DataFrame plus
# a column name, runs the check, and returns a results dictionary.
#
# SQL equivalents are noted inline for each function.
#
# Usage:
#   results = [
#       check_completeness(df, "claim_id"),
#       check_uniqueness(df, "claim_id"),
#       check_validity(df, "claim_status", ["Approved", "Denied", "Pending"]),
#       check_integrity(df, "member_id", known_member_ids),
#   ]
#   quality_report = pd.DataFrame(results)[["check", "column", "score_pct"]]
#   quality_report["Pass"] = quality_report["score_pct"] >= 95.0
# =============================================================================

import pandas as pd
import json


# -----------------------------------------------------------------------------
# 1. COMPLETENESS CHECK
#    SQL equivalent:
#    SELECT SUM(CASE WHEN column IS NOT NULL THEN 1 ELSE 0 END) * 100.0
#           / COUNT(*) AS completeness_pct
#    FROM table
# -----------------------------------------------------------------------------
def check_completeness(df, column_name):
    """
    Returns the percentage of non-null values in a column.

    Parameters:
        df          : pandas DataFrame
        column_name : str — column to evaluate

    Returns:
        dict with check type, column, row counts, and score
    """
    total    = len(df)
    non_null = df[column_name].notna().sum()
    score    = round((non_null / total) * 100, 2)

    return {
        "check":        "Completeness",
        "column":       column_name,
        "total_rows":   total,
        "non_null_rows": int(non_null),
        "score_pct":    score
    }


# -----------------------------------------------------------------------------
# 2. UNIQUENESS CHECK
#    SQL equivalent:
#    SELECT COUNT(DISTINCT column) * 100.0 / COUNT(*) AS uniqueness_pct
#    FROM table
# -----------------------------------------------------------------------------
def check_uniqueness(df, column_name):
    """
    Returns the percentage of distinct values relative to total rows.

    Parameters:
        df          : pandas DataFrame
        column_name : str — column to evaluate

    Returns:
        dict with check type, column, distinct count, and score
    """
    total    = len(df)
    distinct = df[column_name].nunique()
    score    = round((distinct / total) * 100, 2)

    return {
        "check":           "Uniqueness",
        "column":          column_name,
        "total_rows":      total,
        "distinct_values": int(distinct),
        "score_pct":       score
    }


# -----------------------------------------------------------------------------
# 3. VALIDITY CHECK
#    SQL equivalent:
#    SELECT SUM(CASE WHEN column IN ('val1','val2') THEN 1 ELSE 0 END) * 100.0
#           / COUNT(*) AS validity_pct
#    FROM table
# -----------------------------------------------------------------------------
def check_validity(df, column_name, valid_values):
    """
    Returns the percentage of rows where the column value is in an allowed set.

    Parameters:
        df           : pandas DataFrame
        column_name  : str — column to evaluate
        valid_values : list — allowed values

    Returns:
        dict with check type, column, valid values, valid row count, and score
    """
    total       = len(df)
    valid_count = df[column_name].isin(valid_values).sum()
    score       = round((valid_count / total) * 100, 2)

    return {
        "check":        "Validity",
        "column":       column_name,
        "valid_values": valid_values,
        "valid_rows":   int(valid_count),
        "score_pct":    score
    }


# -----------------------------------------------------------------------------
# 4. INTEGRITY CHECK (Foreign Key)
#    SQL equivalent:
#    SELECT SUM(CASE WHEN t.fk_col IN (SELECT id FROM ref_table)
#               THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS integrity_pct
#    FROM table t
# -----------------------------------------------------------------------------
def check_integrity(df, fk_column, valid_ids):
    """
    Returns the percentage of FK values that exist in a reference ID set.

    Parameters:
        df         : pandas DataFrame
        fk_column  : str — foreign key column to evaluate
        valid_ids  : list — valid reference IDs (e.g. from members or providers table)

    Returns:
        dict with check type, column, matched row count, and score
    """
    total   = len(df)
    matched = df[fk_column].isin(valid_ids).sum()
    score   = round((matched / total) * 100, 2)

    return {
        "check":        "Integrity",
        "column":       fk_column,
        "total_rows":   total,
        "matched_rows": int(matched),
        "score_pct":    score
    }


# -----------------------------------------------------------------------------
# 5. JSON SCHEMA VALIDATION
#    No direct SQL equivalent — Python-native check for semi-structured data.
#    Reads a newline-delimited JSON file, validates each record has all
#    required fields, and returns a summary DataFrame.
# -----------------------------------------------------------------------------
def validate_json_schema(json_path, required_fields):
    """
    Reads a newline-delimited JSON file and validates each record contains
    all required fields. Flags missing fields per record.

    Parameters:
        json_path       : str — path to .json file (newline-delimited)
        required_fields : list — field names that must be present in every record

    Returns:
        pandas DataFrame with one row per record showing pass/fail and
        any missing fields
    """
    with open(json_path, "r") as f:
        records = [json.loads(line) for line in f if line.strip()]

    results = []
    for i, record in enumerate(records):
        missing = [field for field in required_fields if field not in record]
        results.append({
            "record_index":   i,
            "has_all_fields": len(missing) == 0,
            "missing_fields": missing if missing else "None"
        })

    valid_count = sum(1 for r in results if r["has_all_fields"])
    print(f"Validated {len(records)} records — "
          f"{valid_count} passed, {len(records) - valid_count} failed")

    return pd.DataFrame(results)


# -----------------------------------------------------------------------------
# CONSOLIDATED QUALITY REPORT
# Run all checks and compile into a single pass/fail DataFrame.
# Threshold: 95.0% — matches the Power BI KPI card standard.
# -----------------------------------------------------------------------------
def run_quality_report(df, known_member_ids, pass_threshold=95.0):
    """
    Runs all 4 metric checks and returns a consolidated quality report.

    Parameters:
        df               : pandas DataFrame
        known_member_ids : list — valid member IDs for integrity check
        pass_threshold   : float — minimum score to pass (default 95.0)

    Returns:
        pandas DataFrame — one row per check with Pass/Fail column
    """
    results = [
        check_completeness(df, "claim_id"),
        check_completeness(df, "procedure_code"),
        check_uniqueness(df, "claim_id"),
        check_validity(df, "claim_status", ["Approved", "Denied", "Pending"]),
        check_integrity(df, "member_id", known_member_ids),
    ]

    report = pd.DataFrame(results)[["check", "column", "score_pct"]]
    report.columns = ["Check Type", "Column", "Score (%)"]
    report["Pass"] = report["Score (%)"] >= pass_threshold

    return report
