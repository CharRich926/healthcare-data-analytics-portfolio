-- ============================================================
-- Query: Denial Reason Trend by Month (Month-over-Month)
-- Business question: Are denial reasons trending up or down
--   month-over-month? Which denial reasons are growing?
-- Key concepts:
--   CTE (WITH monthly_denials AS) — separates the aggregation
--     step from the window function step. The CTE does the
--     "dirty work" (GROUP BY, FORMAT, COUNT); the outer SELECT
--     does the analysis (LAG, subtraction). This makes the
--     window function ORDER BY readable as a column alias
--     rather than a repeated expression.
--   FORMAT(service_date, 'yyyy-MM') — produces a sortable
--     string like '2024-03' that groups and orders correctly
--     without needing a date dimension table
--   LAG(denial_count) OVER (PARTITION BY denial_reason
--     ORDER BY service_month) — returns the previous month's
--     count for the same denial reason. PARTITION BY resets
--     the window per denial reason so LAG doesn't bleed
--     across reason categories.
--   LAG() returns NULL for the first month of each denial
--     reason — expected behavior, not an error
--   month_over_month_change — simple subtraction; positive =
--     denial reason is growing, negative = improving
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

WITH monthly_denials AS (
    SELECT
        FORMAT(c.service_date, 'yyyy-MM')   AS service_month,
        c.denial_reason,
        COUNT(c.claim_id)                   AS denial_count
    FROM dbo.claims c
    WHERE c.claim_status = 'Denied'
    GROUP BY
        FORMAT(c.service_date, 'yyyy-MM'),
        c.denial_reason
)
SELECT
    service_month,
    denial_reason,
    denial_count,
    LAG(denial_count) OVER (
        PARTITION BY denial_reason
        ORDER BY service_month
    )                                       AS prior_month_count,
    denial_count - LAG(denial_count) OVER (
        PARTITION BY denial_reason
        ORDER BY service_month
    )                                       AS month_over_month_change
FROM monthly_denials
ORDER BY
    denial_reason,
    service_month;
