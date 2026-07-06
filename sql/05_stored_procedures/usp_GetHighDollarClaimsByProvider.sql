/* ============================================================================
   Procedure:   usp_GetHighDollarClaimsByProvider
   Author:      Charles Richardson
   Created:     Week 3 - Wednesday

   Business Requirement:
   Utilization review / medical management teams need to identify
   individual high-dollar claims for a specific provider, rather than
   just an aggregate denial trend. High-dollar claims are reviewed for
   miscoding, unbundling, outlier procedures, or case-management
   opportunities (e.g. a patient who should be enrolled in a chronic
   care program). Scrolling raw dbo.claims rows doesn't scale, so this
   proc returns a targeted, sorted list for a single provider.

   Business Questions Answered:
     - Which claims for this provider exceed a dollar threshold worth
       reviewing?
     - What is the clinical context (diagnosis) behind each high-dollar
       claim, so reviewers can triage without a second lookup?
     - Which claims are the biggest dollar outliers for this provider,
       ranked highest first?

   Parameters:
     @provider_id INT      - the provider whose claims to review.
     @threshold   DECIMAL  - billed_amount floor for inclusion.
                             Defaults to 10000.00 to match the same
                             high-dollar threshold used by the
                             HC_Claim_Denial_Alert Power Automate flow,
                             keeping the definition of "high-dollar"
                             consistent across the portfolio.

   Output:
     One row per qualifying claim: claim_id, service_date, billed_amount,
     claim_status, diagnosis_code, diagnosis description, and diagnosis
     category, ordered by billed_amount descending (highest-dollar claims
     surfaced first).

   Revision Note (Week 3, Wednesday):
   Initial test run mixed Approved and Denied claims in the same result
   set. Denial-focused review is already covered by usp_GetDenialSummary,
   so this proc's scope was narrowed to claims that were actually paid
   out — added AND claims.claim_status = 'Approved' to the WHERE clause.
   Deployed via ALTER PROCEDURE.

   Schema Note:
   dbo.diagnosis columns confirmed via SELECT * as: diagnosis_id,
   icd10_code, description, category. Join and SELECT list updated to
   match (initial draft assumed a diagnosis_description column name
   that doesn't exist).
   ============================================================================ */
CREATE OR ALTER PROCEDURE usp_GetHighDollarClaimsByProvider
    @provider_id INT,
    @threshold DECIMAL(10,2) = 10000.00
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        claims.claim_id,
        claims.service_date,
        claims.billed_amount,
        claims.claim_status,
        claims.diagnosis_code,
        diagnosis.description AS diagnosis_description,
        diagnosis.category AS diagnosis_category
    FROM dbo.claims
    LEFT JOIN dbo.diagnosis
        ON claims.diagnosis_code = diagnosis.icd10_code
    WHERE claims.provider_id = @provider_id
        AND claims.billed_amount > @threshold
        AND claims.claim_status = 'Approved'
    ORDER BY claims.billed_amount DESC;
END
