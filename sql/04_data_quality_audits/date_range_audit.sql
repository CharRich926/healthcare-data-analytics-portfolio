-- ============================================================
-- Query: Date Range Audit
-- Business question: Are any date fields out of valid range —
--   future service dates, enrollment dates before the system
--   existed, or load timestamps that predate service dates?
-- Governance dimension: VALIDITY
-- Key concepts:
--   GETDATE() — current timestamp; used to catch future-dated
--     service or enrollment records that shouldn't exist yet
--   DATEADD() — subtracts a fixed number of years from today
--     to define the earliest plausible date for each field.
--     Adjust the interval based on your data retention policy.
--   BETWEEN — inclusive range check; equivalent to
--     >= lower_bound AND <= upper_bound
--   UNION ALL across multiple tables and date columns —
--     single output covers all date validity checks at once
-- Findings from this dataset:
--   All date fields passed — no out-of-range values found
--   across service_date, load_timestamp, or enrollment_date.
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

-- Claims: service_date validity
SELECT
    'claims'            AS table_name,
    'service_date'      AS column_name,
    COUNT(*)            AS invalid_count,
    'future or too old' AS issue_type
FROM dbo.claims
WHERE service_date > GETDATE()
   OR service_date < DATEADD(YEAR, -10, GETDATE())

UNION ALL

-- Claims: load_timestamp validity
SELECT
    'claims',
    'load_timestamp',
    COUNT(*),
    'future dated'
FROM dbo.claims
WHERE load_timestamp > GETDATE()

UNION ALL

-- Members: enrollment_date validity
SELECT
    'members',
    'enrollment_date',
    COUNT(*),
    'future or too old'
FROM dbo.members
WHERE enrollment_date > GETDATE()
   OR enrollment_date < DATEADD(YEAR, -20, GETDATE())

ORDER BY invalid_count DESC;
