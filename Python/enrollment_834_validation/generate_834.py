"""
generate_834.py

Generates a synthetic, structurally valid X12 834 (Benefit Enrollment and
Maintenance) file from a batch of synthetic member records.

This is the upstream stage of the pipeline: real inbound enrollment data
arrives as X12 EDI, not CSV. This script produces that raw X12 file so the
downstream parser (parse_834.py) and validator (validate_enrollment_834.py)
have something real to work against, instead of a pre-flattened CSV.

Segment reference (the ones used here):
    ISA  Interchange Control Header       - outermost envelope, fixed-width
    GS   Functional Group Header          - groups transactions of one type (BE = enrollment)
    ST   Transaction Set Header           - marks start of one 834 transaction
    BGN  Beginning Segment                - transaction date/purpose
    N1   Name (loop)                      - identifies payer (P5) and sponsor (IN)
    INS  Member Level Detail              - core segment: subscriber flag, relationship,
                                             maintenance type code (030=new enrollment,
                                             001=change, 024=termination)
    REF  Reference Identification         - member ID (0F), group/plan (1L),
                                             here also carrying a LOB reference (17)
    DTP  Date/Time Period                 - coverage effective (348) / term (349) dates
    NM1  Individual/Org Name              - member name
    N3   Address                          - street
    N4   Geographic Location              - city/state/zip
    PER  Administrative Communications    - phone contact
    HD   Health Coverage                  - plan code detail
    SE   Transaction Set Trailer          - segment count for this ST...SE block
    GE   Functional Group Trailer
    IEA  Interchange Control Trailer

Output: a single .834 text file, segment-terminated with '~', element-separated with '*'.
"""

import random
from datetime import date, timedelta

random.seed(42)  # same seed as validate_enrollment_834.py for a consistent demo batch

LINES_OF_BUSINESS = {
    "Medicaid": "MCD",
    "Medicare": "MCR",
    "Marketplace": "MKP",
    "Duals": "DUL",
}
PLAN_CODES = ["HMO-100", "PPO-200", "HMO-150", "PPO-250", ""]  # "" = ambiguous
TODAY = date(2026, 8, 8)

SEGMENT_TERM = "~"
ELEMENT_SEP = "*"


# ---------------------------------------------------------------------------
# 1. Synthetic member batch (same shape/seeding logic as the CSV version,
#    reused here so the same categories of real-world issues show up as
#    genuine X12 anomalies instead of blank CSV cells)
# ---------------------------------------------------------------------------

def generate_synthetic_batch(n=25):
    records = []

    for i in range(1, n + 1):
        member_id = f"M{1000 + i}"
        first_name = f"FIRSTNAME{i}"
        last_name = f"LASTNAME{i}"
        lob = random.choice(list(LINES_OF_BUSINESS.keys()))
        plan_code = random.choice(PLAN_CODES)
        phone = f"7135551{str(random.randint(0, 999)).zfill(3)}"  # digits only, EDI style
        coverage_effective = TODAY - timedelta(days=random.randint(0, 400))
        term_date = coverage_effective + timedelta(days=random.randint(180, 500))

        record = {
            "member_id": member_id,
            "first_name": first_name,
            "last_name": last_name,
            "line_of_business": lob,
            "plan_code": plan_code,
            "phone": phone,
            "coverage_effective_date": coverage_effective,
            "term_date": term_date,
            "maintenance_type": "030",  # 030 = new enrollment (all records in this batch)
        }

        # --- Same seeded issue categories as the CSV version, translated
        #     into real EDI-shaped anomalies rather than blank cells ---
        roll = random.random()
        if roll < 0.08:
            record["member_id"] = ""  # -> REF*0F segment omitted entirely (missing member ID)
        elif roll < 0.16:
            record["line_of_business"] = "Unspecified"  # -> REF*17 carries an unroutable code
        elif roll < 0.24:
            record["coverage_effective_date_invalid"] = True  # -> DTP*348 malformed date string
        elif roll < 0.30:
            record["phone"] = ""  # -> PER segment omitted (missing phone)
        elif roll < 0.36:
            record["plan_code"] = ""  # -> REF*1L segment omitted (ambiguous plan)
        elif roll < 0.42:
            record["term_date"] = TODAY - timedelta(days=5)  # -> DTP*349 in the past

        records.append(record)

    return records


# ---------------------------------------------------------------------------
# 2. Segment builders
# ---------------------------------------------------------------------------

def seg(*elements):
    """Joins elements with '*' and terminates with '~', matching X12 syntax."""
    return ELEMENT_SEP.join(elements) + SEGMENT_TERM


def build_envelope_header(control_number):
    isa = seg(
        "ISA", "00", " " * 10, "00", " " * 10, "ZZ", "MOLINASENDER".ljust(15),
        "ZZ", "MOLINARECEIVER".ljust(15), TODAY.strftime("%y%m%d"), "0930",
        "^", "00501", control_number.zfill(9), "0", "P", ":"
    )
    gs = seg("GS", "BE", "MOLINASENDER", "MOLINARECEIVER", TODAY.strftime("%Y%m%d"),
              "0930", "1", "X", "005010X220A1")
    st = seg("ST", "834", "0001")
    bgn = seg("BGN", "00", control_number, TODAY.strftime("%Y%m%d"), "0930", "", "", "", "4")
    n1_payer = seg("N1", "P5", "MOLINA HEALTHCARE", "FI", "123456789")
    n1_sponsor = seg("N1", "IN", "SYNTHETIC EMPLOYER GROUP", "FI", "987654321")
    return isa + gs + st + bgn + n1_payer + n1_sponsor


def build_member_loop(record):
    segments = []

    # INS - member level detail: subscriber (Y), self (18), maintenance type, active (A)
    segments.append(seg("INS", "Y", "18", record["maintenance_type"], "XN", "A", "E", "N"))

    # REF*0F - member ID (omitted entirely if missing -> real-world critical error)
    if record["member_id"]:
        segments.append(seg("REF", "0F", record["member_id"]))

    # REF*17 - line of business reference (portfolio simplification: real 834s usually
    # derive LOB from the group/plan number rather than a dedicated REF; used here so the
    # validation rule has a real segment to check against)
    lob_code = LINES_OF_BUSINESS.get(record["line_of_business"], record["line_of_business"])
    segments.append(seg("REF", "17", lob_code))

    # REF*1L - plan/group code (omitted if ambiguous -> warning)
    if record["plan_code"]:
        segments.append(seg("REF", "1L", record["plan_code"]))

    # DTP*348 - coverage effective date (deliberately malformed for seeded bad records)
    if record.get("coverage_effective_date_invalid"):
        segments.append(seg("DTP", "348", "D8", "20261345"))  # invalid: month 13, day 45
    else:
        segments.append(seg("DTP", "348", "D8", record["coverage_effective_date"].strftime("%Y%m%d")))

    # DTP*349 - term date
    segments.append(seg("DTP", "349", "D8", record["term_date"].strftime("%Y%m%d")))

    # NM1 - member name. ZZ qualifier + member_id used as the identifier (mutually defined)
    # instead of SSN (qualifier 34) -- deliberate: see README on SSN exclusion.
    id_qualifier = "ZZ" if record["member_id"] else ""
    id_value = record["member_id"] if record["member_id"] else ""
    segments.append(seg("NM1", "IL", "1", record["last_name"], record["first_name"],
                         "", "", "", id_qualifier, id_value))

    # N3 / N4 - synthetic address, Houston TX
    segments.append(seg("N3", f"{100 + int(record['member_id'][1:]) if record['member_id'] else 100} MAIN ST"))
    segments.append(seg("N4", "HOUSTON", "TX", "77001"))

    # PER - phone contact (omitted if missing -> warning)
    if record["phone"]:
        segments.append(seg("PER", "IP", "", "TE", record["phone"]))

    # HD - health coverage detail
    plan = record["plan_code"] if record["plan_code"] else "UNSPECIFIED"
    segments.append(seg("HD", "030", "", "HLT", plan))

    return segments


def build_envelope_trailer(segment_count, control_number):
    se = seg("SE", str(segment_count), "0001")
    ge = seg("GE", "1", "1")
    iea = seg("IEA", "1", control_number.zfill(9))
    return se + ge + iea


# ---------------------------------------------------------------------------
# 3. Assemble the full file
# ---------------------------------------------------------------------------

def build_834_file(records, control_number="000000001"):
    header = build_envelope_header(control_number)

    body_segments = []
    for record in records:
        body_segments.extend(build_member_loop(record))
    body = "".join(body_segments)

    # SE01 = count of all segments from ST through SE, inclusive.
    # header contains ISA, GS, ST, BGN, N1, N1 = 6 segments; ST..SE count excludes ISA/GS.
    st_through_se_count = 1 + 1 + 2 + len(body_segments) + 1  # ST + BGN + 2 N1 + body + SE
    trailer = build_envelope_trailer(st_through_se_count, control_number)

    return header + body + trailer


def main():
    records = generate_synthetic_batch(n=25)
    file_content = build_834_file(records)

    output_path = "enrollment_834_sample.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write(file_content)

    print(f"Generated {output_path} with {len(records)} member records.")
    print(f"File size: {len(file_content)} characters")
    print()
    print("--- First member loop (preview) ---")
    preview_segments = build_envelope_header("000000001") + "".join(build_member_loop(records[0]))
    print(preview_segments.replace(SEGMENT_TERM, SEGMENT_TERM + "\n"))


if __name__ == "__main__":
    main()
