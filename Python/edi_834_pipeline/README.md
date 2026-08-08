# EDI 834 Pipeline — Generate → Parse → Validate → Databricks → Power BI

## Overview

An end-to-end simulation of a payer-side 834 enrollment pipeline: a synthetic X12 834 file is generated, parsed back into structured records, run through severity-based validation, landed as a Delta table in Databricks, and connected live to Power BI for reporting.

Built to demonstrate the specific stack a Molina-style Enrollment Research & Data Analytics role calls for — enrollment/eligibility data, EDI 834 structure, Advanced SQL, Azure Databricks, and Power BI — as one connected pipeline rather than disconnected exercises.

**On real vs. simulated 834 experience:** real hands-on EDI 834 work (Empyrean, Alight/Aon) involved the source enrollment data feeding a dedicated generation tool (Meridian, HRO Workbench) — not hand-building X12 segments. This pipeline goes a level deeper than that day-to-day role required, building both the generation and parsing logic that specialized EDI teams typically own, specifically to demonstrate structural fluency with the format itself.

---

## Pipeline

```
generate_834.py  →  raw X12 834 file  →  parse_834.py  →  validate_enrollment_834.py  →  Databricks Delta table  →  Power BI
```

### 1. Generate — `generate_834.py`
Builds a synthetic 25-member enrollment batch and writes it out as a real, structurally valid X12 834 file (`sample_input/enrollment_834_sample.txt`) — proper ISA/GS/ST envelope, member-level INS/REF/DTP/NM1/N3/N4/PER/HD loops, SE/GE/IEA trailers with an accurate segment count.

Deliberately seeds the same categories of real-world issues used in validation, expressed as genuine EDI anomalies rather than blank CSV cells: a missing member ID means the `REF*0F` segment is absent entirely, not blank.

### 2. Parse — `parse_834.py`
Reads the raw segment stream and reconstructs each member into a structured record. This is the harder half of the two: parsing has to be defensive about segments that may or may not be present, where generating one from clean source data doesn't. Every field extraction uses a `safe_get()` pattern rather than assuming a segment exists.

Deliberately does **not** fix or reject bad data at the parsing stage — a malformed date (`20261345`) is reconstructed faithfully as `2026-13-45`, not corrected. That's a separation of concerns: the parser's job is faithful reconstruction, the validator's job is judging what's valid.

### 3. Validate — `validate_enrollment_834.py`
Unchanged from the original CSV-based version — parsed records are handed straight to the existing `validate_record()`/`process_batch()` logic with zero modification, since the parser was built to produce exactly the shape the validator already expects. Severity-based load control (critical = rejected, warning = loaded + flagged) runs identically regardless of whether the source was a CSV or a real EDI file.

### 4. Land — Databricks
Loaded records are landed as a Delta table (`workspace.default.enrollment_834`) in Unity Catalog, verified queryable via SQL.

### 5. Report — Power BI
Power BI Desktop connects live to the Databricks SQL Warehouse (ADBC driver, PAT auth) and reads the Delta table directly — not a flat-file export.

---

## Segment Glossary

The segments this pipeline actually generates and parses:

| Segment | Name | Carries |
|---|---|---|
| `ISA` | Interchange Control Header | Outermost envelope — sender/receiver IDs, control number |
| `GS` | Functional Group Header | Groups transactions of one type (`BE` = benefit enrollment) |
| `ST` | Transaction Set Header | Marks the start of one 834 transaction |
| `BGN` | Beginning Segment | Transaction date and purpose |
| `N1` | Name Loop | Identifies payer (`P5`) and sponsor/employer (`IN`) |
| `INS` | Member Level Detail | Core segment — subscriber flag, relationship, **maintenance type code** (`030`=new enrollment, `001`=change, `024`=termination) |
| `REF` | Reference Identification | Member ID (`0F`), plan/group (`1L`); this pipeline also uses `17` for a line-of-business reference (a portfolio simplification — production systems typically derive LOB from the group number instead) |
| `DTP` | Date/Time Period | Coverage effective date (`348`), term date (`349`) |
| `NM1` | Individual Name | Member first/last name |
| `N3` / `N4` | Address | Street / city-state-zip |
| `PER` | Administrative Communications | Phone contact |
| `HD` | Health Coverage | Plan code detail |
| `SE` / `GE` / `IEA` | Trailers | Segment counts and control totals closing each envelope level |

---

## Known Simplifications

- Simplified relative to a full production 834: no COB segments, no multi-plan HD splits (dental/vision as separate lines), single N1 sponsor loop
- `REF*17` for line-of-business is not a standard production pattern — used here to give the LOB validation rule a real segment to check against
- No SSN anywhere in the pipeline — `member_id` is the working identifier throughout, consistent with the industry shift away from SSN-based identifiers (e.g., CMS's move from HICN to the Medicare Beneficiary Identifier)
- Not validated against the official 005010X220A1 implementation guide via an external X12 schema validator — built to match known segment patterns, not machine-certified

---

## Design Principles

- **Faithful reconstruction over silent correction** — the parser never "fixes" bad data; it hands the validator exactly what the file said, malformed or not
- **Severity-based load control** — critical errors reject a record; warnings load it flagged for review, mirroring real source-file validation patterns
- **Audit-first** — every record's full issue list is logged regardless of outcome
- **Zero coupling between stages beyond the shared record shape** — `parse_834.py` and the original CSV path both feed the same unmodified validator

---

## Stack

`Python` `X12 EDI` `Databricks` `PySpark` `Delta Lake` `Unity Catalog` `Power BI` `SQL`
