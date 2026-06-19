-- ============================================================
-- Query: Claim Turnaround Time by Provider and Payer
-- Business question: How many days elapse between service date
--   and claim load by provider-payer combination? Which
--   combinations are slowest?
-- Key concepts:
--   DATEDIFF(DAY, start, end) — calculates integer day count
--     between service_date and load_timestamp; wrapping in
--     AVG/MIN/MAX gives the distribution, not just the average
--   Three-table JOIN — claims linked to both providers and
--     payer to surface the provider-payer pairing
--   ORDER BY avg_days_to_load DESC — surfaces slowest
--     combinations first for operational triage
-- Note: load_timestamp is used as a proxy for adjudication
--   date in this dataset; in production this would typically
--   be a separate paid_date or adjudication_date column
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    p.provider_name,
    p.specialty,
    py.payer_name,
    COUNT(c.claim_id)                                       AS total_claims,
    AVG(DATEDIFF(DAY, c.service_date, c.load_timestamp))    AS avg_days_to_load,
    MIN(DATEDIFF(DAY, c.service_date, c.load_timestamp))    AS min_days,
    MAX(DATEDIFF(DAY, c.service_date, c.load_timestamp))    AS max_days

FROM  dbo.claims    c
JOIN  dbo.providers p  ON p.provider_id = c.provider_id
JOIN  dbo.payer     py ON py.payer_id   = c.payer_id

GROUP BY
    p.provider_name,
    p.specialty,
    py.payer_name

ORDER BY
    avg_days_to_load DESC;
