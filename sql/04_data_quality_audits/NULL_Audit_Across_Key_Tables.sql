-- ============================================================
-- Query: NULL Audit Across Key Tables
-- Business question: Where is data incomplete? Which columns
--   have NULLs, and at what rate?
-- Governance dimension: COMPLETENESS
-- Key concepts:
--   UNION ALL — stacks results from multiple tables into a
--     single output without deduplication (UNION would be
--     wrong here; we want every row regardless of duplicates)
--   Conditional SUM with CASE WHEN IS NULL — counts NULLs
--     without a WHERE clause so total_rows and null_count
--     always reflect the same denominator
--   null_pct — NULLIF prevents divide-by-zero on empty tables;
--     * 1.0 forces float division before CAST
--   ORDER BY null_pct DESC — worst completeness issues first
-- Findings from this dataset:
--   denial_reason NULLs are expected — non-denied claims
--   legitimately have no denial reason. All other audited
--   columns returned 0% NULL — data is clean.
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    'claims'            AS table_name,
    'diagnosis_code'    AS column_name,
    COUNT(*)            AS total_rows,
    SUM(CASE WHEN diagnosis_code IS NULL THEN 1 ELSE 0 END)     AS null_count,
    CAST(SUM(CASE WHEN diagnosis_code IS NULL THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))            AS null_pct
FROM dbo.claims

UNION ALL

SELECT
    'claims',
    'denial_reason',
    COUNT(*),
    SUM(CASE WHEN denial_reason IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN denial_reason IS NULL THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))
FROM dbo.claims

UNION ALL

SELECT
    'claims',
    'payer_id',
    COUNT(*),
    SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN payer_id IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))
FROM dbo.claims

UNION ALL

SELECT
    'members',
    'plan_type',
    COUNT(*),
    SUM(CASE WHEN plan_type IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN plan_type IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))
FROM dbo.members

UNION ALL

SELECT
    'members',
    'enrollment_date',
    COUNT(*),
    SUM(CASE WHEN enrollment_date IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN enrollment_date IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))
FROM dbo.members

UNION ALL

SELECT
    'providers',
    'specialty',
    COUNT(*),
    SUM(CASE WHEN specialty IS NULL THEN 1 ELSE 0 END),
    CAST(SUM(CASE WHEN specialty IS NULL THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100 AS DECIMAL(5,2))
FROM dbo.providers

ORDER BY null_pct DESC;
