-- ============================================================
-- Query: Provider Network Status Impact on Denial and Allowed Rates
-- Business question: Do in-network and out-of-network providers
--   have meaningfully different denial rates and allowed amounts?
-- Key concepts:
--   Two conditional aggregation metrics in one pass:
--     denial_rate_pct — denied claims as % of total claims
--     allowed_rate_pct — total allowed as % of total billed;
--     measures how much of billed amount the payer approves
--   Both use NULLIF to prevent divide-by-zero
--   Single JOIN — claims to providers only; network_status
--     lives on the provider record
--   ORDER BY denial_rate_pct DESC — worst denial rate first
-- Interpretation note: sample size matters here. A large gap
--   between in-network and out-of-network claim counts means
--   rates are not directly comparable without normalization.
--   Always surface total_claims alongside rate metrics.
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    p.network_status,
    COUNT(c.claim_id)                                               AS total_claims,
    SUM(CASE WHEN c.claim_status = 'Denied' THEN 1 ELSE 0 END)     AS denied_claims,
    SUM(c.billed_amount)                                            AS total_billed,
    SUM(c.allowed_amount)                                           AS total_allowed,
    CAST(
        SUM(CASE WHEN c.claim_status = 'Denied' THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(c.claim_id), 0) * 100
    AS DECIMAL(5,2))                                                AS denial_rate_pct,
    CAST(
        SUM(c.allowed_amount)
        / NULLIF(SUM(c.billed_amount), 0) * 100
    AS DECIMAL(5,2))                                                AS allowed_rate_pct

FROM  dbo.claims    c
JOIN  dbo.providers p ON p.provider_id = c.provider_id

GROUP BY
    p.network_status

ORDER BY
    denial_rate_pct DESC;
