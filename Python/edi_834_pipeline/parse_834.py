"""
parse_834.py

Parses a raw X12 834 file (as produced by generate_834.py, or any file
following the same segment layout) back into structured member records.

This is the piece that actually proves 834 fluency: generating a well-formed
file is straightforward once you know the segment layout, but parsing has to
be defensive -- real inbound files have missing optional segments, malformed
dates, and unroutable reference codes, and a parser has to reconstruct a
usable record without crashing on any of that.

Loop structure:
    Everything before the first INS segment is envelope/header data
    (ISA, GS, ST, BGN, N1 loops) -- not member-specific, skipped here.

    Each INS segment starts a new member loop. All segments between one
    INS and the next (or the SE trailer) belong to that member.

Output: a list of dicts in the exact shape validate_enrollment_834.py's
validate_record() expects -- member_id, first_name, last_name,
line_of_business, plan_code, phone, coverage_effective_date, term_date --
so parsed output can be validated with zero changes to the existing
validation logic.
"""

import csv
from validate_enrollment_834 import validate_record, process_batch, write_csv

SEGMENT_TERM = "~"
ELEMENT_SEP = "*"

# Reverse of the code map used in generate_834.py, so a parsed REF*17 code
# maps back to a readable LOB name. Any code NOT in this map (e.g. a typo'd
# or unroutable code) is passed through as-is -- that's deliberate, since
# validate_record() already treats an unrecognized LOB as a critical error.
LOB_CODE_TO_NAME = {
    "MCD": "Medicaid",
    "MCR": "Medicare",
    "MKP": "Marketplace",
    "DUL": "Duals",
}


# ---------------------------------------------------------------------------
# 1. Segment-level parsing
# ---------------------------------------------------------------------------

def read_segments(filepath):
    """Reads a raw X12 file and returns a flat list of segments, each split
    into its elements. Handles files written with or without newlines after
    the '~' terminator (both are valid X12 -- the terminator is what
    matters, not the presence of a line break)."""
    with open(filepath, "r", encoding="utf-8") as f:
        raw = f.read()

    raw_segments = [s.strip() for s in raw.split(SEGMENT_TERM)]
    segments = []
    for raw_seg in raw_segments:
        raw_seg = raw_seg.strip()
        if not raw_seg:
            continue
        elements = raw_seg.split(ELEMENT_SEP)
        segments.append(elements)

    return segments


def group_member_loops(segments):
    """Splits the full segment list into per-member loops. Each loop starts
    at an INS segment and runs until the next INS, or until a trailer
    segment (SE/GE/IEA) ends the transaction."""
    loops = []
    current_loop = None

    for elements in segments:
        seg_id = elements[0]

        if seg_id == "INS":
            if current_loop is not None:
                loops.append(current_loop)
            current_loop = [elements]
        elif seg_id in ("SE", "GE", "IEA"):
            if current_loop is not None:
                loops.append(current_loop)
                current_loop = None
        else:
            if current_loop is not None:
                current_loop.append(elements)
            # else: envelope/header segment before the first INS -- skip

    if current_loop is not None:
        loops.append(current_loop)

    return loops


# ---------------------------------------------------------------------------
# 2. Field extraction (defensive -- every field may be missing)
# ---------------------------------------------------------------------------

def safe_get(elements, index, default=""):
    """Returns elements[index] if it exists and is non-empty, else default.
    Real segments frequently have trailing empty elements (e.g. NM1's unused
    middle-name/suffix slots) -- indexing directly without this would either
    throw or silently return a blank when a real value was intended."""
    if index < len(elements):
        value = elements[index]
        return value if value else default
    return default


def format_date(raw_date):
    """Converts an X12 DTP date (YYYYMMDD) into ISO format (YYYY-MM-DD).
    Deliberately does NOT validate the date here -- a malformed date like
    '20261345' becomes '2026-13-45', which is exactly the kind of string
    that should fail downstream in validate_record()'s date.fromisoformat()
    check. The parser's job is to reconstruct the record faithfully, not to
    pre-filter bad data -- that's the validator's responsibility."""
    if len(raw_date) == 8:
        return f"{raw_date[0:4]}-{raw_date[4:6]}-{raw_date[6:8]}"
    return raw_date  # already malformed / wrong length -- pass through as-is


def parse_member_loop(loop):
    """Extracts one structured member record from a list of segments
    belonging to a single INS...next-INS loop."""
    record = {
        "member_id": "",
        "first_name": "",
        "last_name": "",
        "line_of_business": "",
        "plan_code": "",
        "phone": "",
        "coverage_effective_date": "",
        "term_date": "",
    }

    for elements in loop:
        seg_id = elements[0]

        if seg_id == "REF":
            qualifier = safe_get(elements, 1)
            if qualifier == "0F":
                record["member_id"] = safe_get(elements, 2)
            elif qualifier == "17":
                lob_code = safe_get(elements, 2)
                record["line_of_business"] = LOB_CODE_TO_NAME.get(lob_code, lob_code)
            elif qualifier == "1L":
                record["plan_code"] = safe_get(elements, 2)

        elif seg_id == "DTP":
            qualifier = safe_get(elements, 1)
            raw_date = safe_get(elements, 3)
            if qualifier == "348":
                record["coverage_effective_date"] = format_date(raw_date)
            elif qualifier == "349":
                record["term_date"] = format_date(raw_date)

        elif seg_id == "NM1":
            record["last_name"] = safe_get(elements, 3)
            record["first_name"] = safe_get(elements, 4)

        elif seg_id == "PER":
            record["phone"] = safe_get(elements, 4)

    return record


# ---------------------------------------------------------------------------
# 3. Full file parse
# ---------------------------------------------------------------------------

def parse_834_file(filepath):
    """Reads a raw X12 834 file and returns a list of structured member
    records, ready to hand directly to validate_record()."""
    segments = read_segments(filepath)
    loops = group_member_loops(segments)
    records = [parse_member_loop(loop) for loop in loops]
    return records


def main():
    input_path = "sample_input/enrollment_834_sample.txt"
    records = parse_834_file(input_path)

    print(f"Parsed {len(records)} member records from {input_path}")
    print()
    print("--- First 3 parsed records ---")
    for r in records[:3]:
        print(r)

    # Quick sanity check: how many records came back with a missing field,
    # purely from parsing -- before any validation logic runs at all.
    missing_member_id = sum(1 for r in records if not r["member_id"])
    missing_plan_code = sum(1 for r in records if not r["plan_code"])
    missing_phone = sum(1 for r in records if not r["phone"])
    print()
    print(f"Records with missing member_id: {missing_member_id}")
    print(f"Records with missing plan_code: {missing_plan_code}")
    print(f"Records with missing phone:     {missing_phone}")

    # Write parsed output to CSV for inspection / as an intermediate artifact
    output_path = "sample_output/parsed_834_output.csv"
    fieldnames = ["member_id", "first_name", "last_name", "line_of_business",
                  "plan_code", "phone", "coverage_effective_date", "term_date"]
    with open(output_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(records)
    print()
    print(f"Parsed output written to {output_path}")

    # --- Phase 3: hand parsed records straight to the existing validator.
    # No changes needed to validate_record()/process_batch() -- the parser
    # was built to produce exactly the record shape they already expect. ---
    print()
    print("=== Running parsed records through severity-based validation ===")
    loaded, rejected, audit_rows = process_batch(records)

    enrollment_fields = fieldnames + ["load_status", "flagged_for_review"]
    audit_fields = ["member_id", "severity", "field", "issue", "outcome"]

    write_csv(loaded, "sample_output/enrollment_loaded_from_834.csv", enrollment_fields)
    write_csv(rejected, "sample_output/enrollment_rejected_from_834.csv", enrollment_fields)
    write_csv(audit_rows, "sample_output/audit_log_from_834.csv", audit_fields)

    flagged_count = sum(1 for r in loaded if r["flagged_for_review"] == "YES")
    print(f"Loaded:               {len(loaded)}  ({flagged_count} flagged for review)")
    print(f"Rejected (critical):  {len(rejected)}")
    print(f"Audit log rows:       {len(audit_rows)}")


if __name__ == "__main__":
    main()
