"""
validate_enrollment_834.py

Simulates the Empyrean-era Python source-file validation pattern:
severity-based load control on an EDI 834-style enrollment batch.

- CRITICAL issues -> record is REJECTED (not loaded downstream)
- WARNING issues  -> record is LOADED, but flagged for review

Output:
    enrollment_loaded.csv    -> records that pass (clean + warning-flagged)
    enrollment_rejected.csv  -> records that failed critical validation
    audit_log.csv            -> one row per record, every issue found + outcome

This output feeds the next stage: upload to Databricks Unity Catalog volume,
then spark.read.csv() -> .saveAsTable() into a Delta table for SQL/Power BI.
"""

import csv
import random
from datetime import date, timedelta

random.seed(42)  # reproducible batches for demo/interview walkthroughs

LINES_OF_BUSINESS = ["Medicaid", "Medicare", "Marketplace", "Duals"]
PLAN_CODES = ["HMO-100", "PPO-200", "HMO-150", "PPO-250", ""]  # "" = ambiguous
TODAY = date(2026, 8, 8)


# ---------------------------------------------------------------------------
# 1. Synthetic batch generation
# ---------------------------------------------------------------------------

def generate_synthetic_batch(n=25):
    """Builds a synthetic 834-style enrollment batch, deliberately seeding
    a mix of clean, warning-level, and critical-level records so the
    validation logic below has something real to catch."""
    records = []

    for i in range(1, n + 1):
        member_id = f"M{1000 + i}"
        first_name = f"FirstName{i}"
        last_name = f"LastName{i}"
        lob = random.choice(LINES_OF_BUSINESS)
        plan_code = random.choice(PLAN_CODES)
        phone = f"713-555-{random.randint(1000, 9999)}"
        coverage_effective = TODAY - timedelta(days=random.randint(0, 400))
        term_date = coverage_effective + timedelta(days=random.randint(180, 500))

        record = {
            "member_id": member_id,
            "first_name": first_name,
            "last_name": last_name,
            "line_of_business": lob,
            "plan_code": plan_code,
            "phone": phone,
            "coverage_effective_date": coverage_effective.isoformat(),
            "term_date": term_date.isoformat(),
        }

        # --- Deliberately seed known issues into ~40% of the batch ---
        roll = random.random()
        if roll < 0.08:
            record["member_id"] = ""  # CRITICAL: missing member ID
        elif roll < 0.16:
            record["line_of_business"] = "Unspecified"  # CRITICAL: invalid/unroutable LOB
        elif roll < 0.24:
            record["coverage_effective_date"] = "13/45/2026"  # CRITICAL: invalid date
        elif roll < 0.30:
            record["phone"] = ""  # WARNING: missing phone
        elif roll < 0.36:
            record["plan_code"] = ""  # WARNING: ambiguous plan code
        elif roll < 0.42:
            # WARNING: term date submitted late relative to "processing today"
            record["term_date"] = (TODAY - timedelta(days=5)).isoformat()

        records.append(record)

    return records


# ---------------------------------------------------------------------------
# 2. Validation rules
# ---------------------------------------------------------------------------

def validate_record(record):
    """Returns a list of (severity, field, message) tuples for a single record.
    severity is either 'CRITICAL' or 'WARNING'."""
    issues = []

    # --- CRITICAL: missing member ID ---
    if not record["member_id"].strip():
        issues.append(("CRITICAL", "member_id", "Member ID is missing."))

    # --- CRITICAL: invalid/unroutable Line of Business ---
    if record["line_of_business"] not in LINES_OF_BUSINESS:
        issues.append(("CRITICAL", "line_of_business",
                        f"Line of Business '{record['line_of_business']}' does not map to a "
                        f"recognized program (Medicaid/Medicare/Marketplace/Duals) and cannot be routed."))

    # --- CRITICAL: invalid coverage effective date ---
    try:
        date.fromisoformat(record["coverage_effective_date"])
    except ValueError:
        issues.append(("CRITICAL", "coverage_effective_date",
                        f"Coverage effective date '{record['coverage_effective_date']}' is not a valid date."))

    # --- WARNING: missing phone number ---
    if not record["phone"].strip():
        issues.append(("WARNING", "phone", "Phone number is missing."))

    # --- WARNING: ambiguous plan code ---
    if not record["plan_code"].strip():
        issues.append(("WARNING", "plan_code", "Plan code is missing or ambiguous."))

    # --- WARNING: late-submitted term date (term date in the past relative to processing date) ---
    try:
        term = date.fromisoformat(record["term_date"])
        if term < TODAY:
            issues.append(("WARNING", "term_date",
                            f"Term date {term.isoformat()} is in the past relative to processing date."))
    except ValueError:
        pass  # malformed term_date not modeled as a separate rule here

    return issues


# ---------------------------------------------------------------------------
# 3. Severity-based load control
# ---------------------------------------------------------------------------

def process_batch(records):
    """Applies validation to every record and routes it to loaded/rejected
    based on severity, same pattern as the Empyrean source-file control logic."""
    loaded, rejected, audit_rows = [], [], []

    for record in records:
        issues = validate_record(record)
        has_critical = any(sev == "CRITICAL" for sev, _, _ in issues)
        has_warning = any(sev == "WARNING" for sev, _, _ in issues)

        outcome = "REJECTED" if has_critical else "LOADED"
        flagged = "YES" if (has_warning and not has_critical) else "NO"

        out_record = dict(record)
        out_record["load_status"] = outcome
        out_record["flagged_for_review"] = flagged

        if has_critical:
            rejected.append(out_record)
        else:
            loaded.append(out_record)

        if issues:
            for sev, field, msg in issues:
                audit_rows.append({
                    "member_id": record["member_id"] or "(missing)",
                    "severity": sev,
                    "field": field,
                    "issue": msg,
                    "outcome": outcome,
                })
        else:
            audit_rows.append({
                "member_id": record["member_id"],
                "severity": "NONE",
                "field": "",
                "issue": "No issues found.",
                "outcome": outcome,
            })

    return loaded, rejected, audit_rows


# ---------------------------------------------------------------------------
# 4. Output
# ---------------------------------------------------------------------------

def write_csv(rows, path, fieldnames):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main():
    batch = generate_synthetic_batch(n=25)
    loaded, rejected, audit_rows = process_batch(batch)

    enrollment_fields = [
        "member_id", "first_name", "last_name", "line_of_business",
        "plan_code", "phone", "coverage_effective_date", "term_date",
        "load_status", "flagged_for_review",
    ]
    audit_fields = ["member_id", "severity", "field", "issue", "outcome"]

    write_csv(loaded, "enrollment_loaded.csv", enrollment_fields)
    write_csv(rejected, "enrollment_rejected.csv", enrollment_fields)
    write_csv(audit_rows, "audit_log.csv", audit_fields)

    flagged_count = sum(1 for r in loaded if r["flagged_for_review"] == "YES")

    print(f"Batch processed: {len(batch)} records")
    print(f"  Loaded:               {len(loaded)}  ({flagged_count} flagged for review)")
    print(f"  Rejected (critical):  {len(rejected)}")
    print(f"  Audit log rows:       {len(audit_rows)}")
    print()
    print("Files written: enrollment_loaded.csv, enrollment_rejected.csv, audit_log.csv")


if __name__ == "__main__":
    main()
