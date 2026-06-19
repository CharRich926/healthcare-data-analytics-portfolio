-- ============================================================
-- Query: Duplicate Claims Check
-- Business question: Are there true duplicate claim records
--   in the database — same member, date, diagnosis, procedure,
--   and billed amount submitted more than once?
-- Governance dimension: UNIQUENESS
-- Key concepts:
--   GROUP BY on composite business key — groups on the five
--     fields that together define a logically unique claim.
--     claim_id is excluded intentionally: we want to find rows
--     where everything except the system ID is identical.
--   HAVING COUNT(*) > 1 — filters to groups with more than
--     one row after aggregation. This cannot be written as
--     WHERE COUNT(*) > 1 because WHERE runs before GROUP BY;
--     HAVING runs after.
--   ORDER BY duplicate_count DESC — worst offenders first
-- Findings from this dataset:
--   Zero true duplicates found. Despite "Duplicate Claim"
--   being the top denial reason (24 denials, 23.5%), no
--   duplicate records exist at the database level — the payer's
--   adjudication system catches near-duplicates before they
--   create actual duplicate rows in the source data.
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    member_id,
    service_date,
    diagnosis_code,
    procedure_code,
    billed_amount,
    COUNT(*)    AS duplicate_count
FROM dbo.claims
GROUP BY
    member_id,
    service_date,
    diagnosis_code,
    procedure_code,
    billed_amount
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
