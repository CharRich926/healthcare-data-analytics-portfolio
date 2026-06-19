-- ============================================================
-- Procedure: dbo.usp_GetMemberClaims
-- Purpose: Returns all claims for a given member, with optional
--          date range filtering. Designed for member-level
--          claim history lookups in a payer or portal context.
-- Key concepts:
--   Optional parameters with defaults — @StartDate and @EndDate
--     both default to NULL; ISNULL() then applies a wide date
--     range so callers don't have to pass dates if not needed
--   BETWEEN for date range filtering on service_date
--   Multi-table JOIN across claims, members, providers
-- Parameters:
--   @MemberID  INT  — required; the member to look up
--   @StartDate DATE — optional; defaults to '2000-01-01'
--   @EndDate   DATE — optional; defaults to GETDATE()
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

USE HealthcarePractice;
GO

CREATE PROCEDURE dbo.usp_GetMemberClaims
    @MemberID  INT,
    @StartDate DATE = NULL,
    @EndDate   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Apply defaults if no dates supplied
    SET @StartDate = ISNULL(@StartDate, '2000-01-01');
    SET @EndDate   = ISNULL(@EndDate,   GETDATE());

    SELECT
        c.claim_id,
        m.member_name,
        p.provider_name,
        p.specialty,
        c.service_date,
        c.diagnosis_code,
        c.procedure_code,
        c.billed_amount,
        c.paid_amount,
        c.claim_status,
        c.denial_reason
    FROM dbo.claims    c
    JOIN dbo.members   m ON c.member_id   = m.member_id
    JOIN dbo.providers p ON c.provider_id = p.provider_id
    WHERE c.member_id    = @MemberID
      AND c.service_date BETWEEN @StartDate AND @EndDate
    ORDER BY c.service_date DESC;
END;
GO

-- ============================================================
-- Test: all claims for member 1
-- ============================================================
EXEC dbo.usp_GetMemberClaims @MemberID = 1;

-- ============================================================
-- Test: claims for member 1 within a date range
-- ============================================================
EXEC dbo.usp_GetMemberClaims
    @MemberID  = 1,
    @StartDate = '2024-01-01',
    @EndDate   = '2024-12-31';
