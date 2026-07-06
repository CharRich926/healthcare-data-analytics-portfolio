/* ============================================================================
   Procedure:   usp_GetDenialSummary
   Author:      Charles Richardson
   Created:     Week 3 - Wednesday

   Business Requirement:
   Revenue cycle and finance stakeholders need a per-payer view of claim
   denial performance to prioritize appeals work, support payer contract
   negotiations, and quantify revenue at risk. Ad hoc row-level queries
   against dbo.claims don't scale across dozens of payers, so this proc
   provides a repeatable, parameterized summary callable for any single
   payer_id.

   Business Questions Answered:
     - How many claims did this payer process, broken out by approved,
       denied, and pending outcome?
     - What is the payer's denial rate (a KPI used to flag problem payers)?
     - How many billed dollars are tied up in denied claims (revenue at
       risk, not just claim count)?
     - What service date range does this summary cover?

   Parameters:
     @payer_id INT - the payer to summarize. Denial behavior varies
                     significantly by payer, so summaries are always
                     scoped to one payer rather than run in aggregate.

   Output:
     One row per payer_id containing total claim count; denied, approved,
     and pending claim counts; denial_rate (decimal); denied_billed_amount;
     and earliest/latest service_date in the claim set.

   Revision Note (Week 3, Wednesday):
   Initial version calculated denial_rate as denied_claims / total_claims.
   Validation against payer_id 5 showed total_claims (69) did not equal
   denied_claims + approved_claims (61) — an 8-claim gap. A GROUP BY on
   claim_status revealed a third status value, 'Pending', which the
   original query silently excluded from the numerator but still included
   in the denominator, understating the true denial rate. Corrected by
   (1) adding pending_claims as its own output column for transparency,
   and (2) redefining denial_rate as denied / (denied + approved) so the
   rate reflects only adjudicated claims, consistent with standard RCM
   denial-rate definitions. Deployed via ALTER PROCEDURE rather than
   drop/recreate to preserve existing permissions on the object.
   ============================================================================ */
CREATE OR ALTER PROCEDURE usp_GetDenialSummary
    @payer_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        payer_id,
        COUNT(*) AS total_claims,
        SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS denied_claims,
        SUM(CASE WHEN claim_status = 'Approved' THEN 1 ELSE 0 END) AS approved_claims,
        SUM(CASE WHEN claim_status = 'Pending' THEN 1 ELSE 0 END) AS pending_claims,
        CAST(SUM(CASE WHEN claim_status = 'Denied' THEN 1 ELSE 0 END) AS DECIMAL(10,2))
            / NULLIF(SUM(CASE WHEN claim_status IN ('Denied','Approved') THEN 1 ELSE 0 END), 0) AS denial_rate,
        SUM(CASE WHEN claim_status = 'Denied' THEN billed_amount ELSE 0 END) AS denied_billed_amount,
        MIN(service_date) AS earliest_service_date,
        MAX(service_date) AS latest_service_date
    FROM dbo.claims
    WHERE payer_id = @payer_id
    GROUP BY payer_id;
END
