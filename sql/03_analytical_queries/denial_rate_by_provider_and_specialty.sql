-- ============================================================
-- Query: Denial Rate by Provider Ranked Within Specialty
-- Business question: How does each provider's denial rate
--   compare to peers in the same specialty?
-- Key concepts:
--   RANK() OVER (PARTITION BY specialty) — resets rank counter
--     per specialty group; rank 1 = highest denial rate in that
--     specialty. PARTITION BY is what makes this peer comparison
--     rather than a global ranking.
--   Conditional aggregation with CASE WHEN — counts denied
--     claims without a subquery or second pass over the data
--   NULLIF(COUNT(...), 0) — prevents divide-by-zero if a
--     provider has zero claims
--   CAST AS DECIMAL(5,2) — consistent two-decimal display
--   ORDER BY inside OVER — defines ranking criteria independently
--     from the outer ORDER BY that controls result set sort
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    p.provider_name,
    p.specialty,
    COUNT(c.claim_id)                                               AS total_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END)     AS denied_claims,
    CAST(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(c.claim_id), 0) * 100
    AS DECIMAL(5,2))                                                AS denial_rate_pct,
    RANK() OVER (
        PARTITION BY p.specialty
        ORDER BY
            SUM(CASE WHEN c.claim_status = 'Denied' THEN 1.0 ELSE 0 END)
            / NULLIF(COUNT(c.claim_id), 0) DESC
    )                                                               AS rank_within_specialty

FROM dbo.claims    c
JOIN dbo.providers p ON p.provider_id = c.provider_id

GROUP BY
    p.provider_name,
    p.specialty

ORDER BY
    p.specialty,
    rank_within_specialty;
