-- ============================================================
-- Query: Orphaned Records Check
-- Business question: Are there claims referencing lookup values
--   that don't exist in their parent tables? Broken foreign
--   key relationships that would cause JOIN drops or bad totals.
-- Governance dimension: REFERENTIAL INTEGRITY
-- Key concepts:
--   NOT EXISTS — for each claim row, checks whether a matching
--     row exists in the referenced table. More readable and
--     often faster than LEFT JOIN / IS NULL on large datasets
--     because it short-circuits on first match found.
--   UNION ALL — stacks four separate integrity checks into one
--     output; each row names the issue and its count
--   Four checks: providers, payer, members, diagnosis — covers
--     all foreign key relationships on dbo.claims
-- Findings from this dataset:
--   20 claims have no matching diagnosis code. Root cause:
--   dbo.diagnosis has only 8 rows but claims references 20+
--   distinct ICD-10 codes. This is a data gap in the lookup
--   table, not a claims data error. All other checks = 0.
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    'claims with no matching provider'  AS issue,
    COUNT(*)                            AS orphan_count
FROM dbo.claims c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.providers p WHERE p.provider_id = c.provider_id
)

UNION ALL

SELECT
    'claims with no matching payer',
    COUNT(*)
FROM dbo.claims c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.payer py WHERE py.payer_id = c.payer_id
)

UNION ALL

SELECT
    'claims with no matching member',
    COUNT(*)
FROM dbo.claims c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.members m WHERE m.member_id = c.member_id
)

UNION ALL

SELECT
    'claims with no matching diagnosis',
    COUNT(*)
FROM dbo.claims c
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.diagnosis d WHERE d.icd10_code = c.diagnosis_code
);
