-- ============================================================
-- Query: Member Utilization by Plan Type
-- Business question: How does claim volume and cost compare
--   across HMO, PPO, and EPO plan types? What is the average
--   utilization rate (claims per member) per plan?
-- Key concepts:
--   COUNT(DISTINCT c.member_id) — counts unique members, not
--     claim rows; essential because one member can have many
--     claims. COUNT(member_id) without DISTINCT would overcount.
--   claims_per_member — derived metric: total claims divided by
--     unique member count. NULLIF prevents divide-by-zero if a
--     plan type somehow has members but no claims.
--   CAST(... * 1.0 AS DECIMAL(5,2)) — the * 1.0 forces integer
--     division to floating point before the CAST; without it,
--     integer / integer truncates to a whole number.
--   ORDER BY total_billed DESC — surfaces highest-cost plan
--     types first for actuarial and utilization review
-- Named query saved in: Microsoft Fabric SQL endpoint
-- ============================================================

SELECT
    m.plan_type,
    COUNT(DISTINCT c.member_id)                     AS member_count,
    COUNT(c.claim_id)                               AS total_claims,
    SUM(c.billed_amount)                            AS total_billed,
    CAST(AVG(c.billed_amount) AS DECIMAL(10,2))     AS avg_billed_per_claim,
    CAST(COUNT(c.claim_id) * 1.0
        / NULLIF(COUNT(DISTINCT c.member_id), 0)
    AS DECIMAL(5,2))                                AS claims_per_member

FROM  dbo.claims  c
JOIN  dbo.members m ON m.member_id = c.member_id

GROUP BY
    m.plan_type

ORDER BY
    total_billed DESC;
