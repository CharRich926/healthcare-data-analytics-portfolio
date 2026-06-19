-- ============================================================
-- View: dbo.vw_ProviderClaimSummary
-- Purpose: Aggregates claim volume, billed/paid amounts, and
--          denial rate per provider for reporting and benchmarking.
-- Key concepts: LEFT JOIN (preserves providers with zero claims),
--               conditional aggregation with CASE WHEN,
--               NULLIF to prevent divide-by-zero on denial rate,
--               CAST AS DECIMAL(5,2) for consistent display
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE VIEW dbo.vw_ProviderClaimSummary AS
SELECT
    p.provider_id,
    p.provider_name,
    p.specialty,
    p.network_status,
    COUNT(c.claim_id)                               AS total_claims,
    SUM(c.billed_amount)                            AS total_billed,
    SUM(c.paid_amount)                              AS total_paid,
    SUM(CASE WHEN c.claim_status = 'DENIED'
             THEN 1 ELSE 0 END)                     AS denied_claims,
    CAST(
        SUM(CASE WHEN c.claim_status = 'DENIED'
                 THEN 1.0 ELSE 0 END)
        / NULLIF(COUNT(c.claim_id), 0) * 100
        AS DECIMAL(5,2))                            AS denial_rate_pct
FROM dbo.providers p
LEFT JOIN dbo.claims c ON p.provider_id = c.provider_id
GROUP BY
    p.provider_id, p.provider_name, p.specialty, p.network_status;
GO
