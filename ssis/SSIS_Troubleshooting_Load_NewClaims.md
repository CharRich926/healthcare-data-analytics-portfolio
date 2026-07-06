# SSIS Troubleshooting Log: Load_NewClaims — Silent Row Loss on Unconnected Error Output

**Package:** `Load_NewClaims.dtsx`
**Date Found:** Week 3, Wednesday (2026-07-05)
**Status:** Resolved

## Summary

A test load of 15 new claim records into `dbo.claims` (local SQL Server)
resulted in only 13 rows being accounted for — 1 successful insert and 12
rows correctly captured in the reject path. The remaining 2 rows
disappeared with no error, no destination row, and no entry in the
package's own `dbo.pipeline_audit_log` table.

## Root Cause

The Data Flow contains two Lookup transformations in series:

1. `Lookup_ValidateMember` — validates `member_id` against cached
   reference data. Its "Lookup No Match Output" was correctly wired to
   the reject path (`RejectRowCount` → `Rejected_Claims`).
2. `Lookup_ValidateProvider` — validates `provider_id` against cached
   reference data. Its "Lookup No Match Output" existed as a defined
   output on the component, but **was not connected to anything** in
   the Data Flow.

SSIS does not raise an error, warning, or log entry when a row is
directed to a defined-but-unconnected output. The row is simply
dropped from the pipeline. This is distinct from a validation failure
or a destination-level insert failure — both of which are visible in
the package's execution log. An unconnected output produces no trace
at all.

In this test run, both dropped rows (source `claim_id` 5001 and 5008)
passed `Lookup_ValidateMember` (valid `member_id`) but failed
`Lookup_ValidateProvider` (invalid `provider_id`), and were lost at
that second lookup with no record of the failure.

## How It Was Found

1. Ran `Load_NewClaims` against a 15-row test file.
2. Package reported "1 inserted, 12 rejected" via `dbo.pipeline_audit_log`.
3. Confirmed via direct query that only 1 row existed in `dbo.claims`
   for the test batch, and `rejected_claims.csv` contained exactly 12
   rows — leaving 2 source rows (5001, 5008) unaccounted for in either
   location.
4. Traced the Data Flow diagram and found `Lookup_ValidateProvider`'s
   no-match output had no downstream connection, while
   `Lookup_ValidateMember`'s did.

## Fix

Added a **Union All** transformation to merge the no-match outputs of
both `Lookup_ValidateMember` and `Lookup_ValidateProvider` into a
single stream, which then feeds the existing `RejectRowCount` →
`Rejected_Claims` path. Both lookups now have a defined and connected
failure path.

## Validation

Re-ran the same 15-row test file in debug mode with row counts
visible on each path:

| Stage | Rows |
|---|---|
| Source (`CSV_NewClaims`) | 15 |
| `Lookup_ValidateMember` no match (rejected) | 12 |
| `Lookup_ValidateMember` match (continues) | 3 |
| `Lookup_ValidateProvider` no match (rejected) | 2 |
| `Lookup_ValidateProvider` match (continues) | 1 |
| Union All output → Rejected_Claims | 14 |
| Dest_Claims (successful insert) | 1 |
| **Total accounted for (14 + 1)** | **15** |

15 in, 15 accounted for. No rows lost.

## Lesson

Every transformation in a Data Flow that can redirect rows to an error
or no-match output needs that output connected to *something* —
otherwise SSIS will silently discard the rows with no log entry,
no error, and no way to detect the loss short of manually reconciling
row counts end-to-end. A pipeline can report "success" and still be
quietly dropping data. Row-count reconciliation between source and
all downstream paths (not just the primary destination) should be a
standard validation step after any SSIS package run, not just a
one-time check.

## Follow-Up Validation (Thursday, 2026-07-06)

The fix above was validated a second time, one day later, using an
independently generated test batch rather than a replay of the original
15-row file. Reprocessing the same file was avoided because the one row
that had already loaded successfully would collide on primary key
(`claim_id`) against `dbo.claims`.

**Test batch:** 15 new rows (`claim_id` 6000–6014) with a deliberate mix
of valid and invalid `member_id`/`provider_id` combinations — including
rows with only the member invalid, only the provider invalid, and both
invalid — specifically to exercise both Lookup no-match outputs through
the Union All merge, not just the one caught in the original bug.

**Result:**

| Stage | Rows |
|---|---|
| Source (new batch) | 15 |
| Dest_Claims (successful insert) | 4 |
| Rejected_Claims (Union All merged output) | 11 |
| **Total accounted for (4 + 11)** | **15** |

`dbo.pipeline_audit_log` correctly recorded the run (`log_id 4`, 4
inserted / 11 rejected), confirming that the audit logging mechanism —
itself a simple pass-through of the `User::RowsInserted` /
`User::RowsRejected` SSIS variables — also reflects the fix accurately,
not just the Data Flow routing in isolation.

| log_id | Date | Inserted | Rejected | Total Accounted For | Notes |
|---|---|---|---|---|---|
| 2 | 2026-06-22 | 3 | 5 | 8 of 10 | Pre-fix — silent row loss, undiagnosed at the time |
| 3 | 2026-07-05 | 1 | 12 | 13 of 15 | Captured mid-fix, before Union All fully wired in |
| 4 | 2026-07-06 | 4 | 11 | 15 of 15 | Post-fix, validated on independently generated data |

This closes the loop: the fix holds against data it had never seen
before, not just a repeat of the file that originally exposed the bug.
