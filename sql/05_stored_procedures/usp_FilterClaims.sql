-- ============================================================
-- Procedure: dbo.usp_FilterClaims
-- Purpose: Dynamically filters the claims result set by a
--          caller-specified column and value — safely.
-- Key concepts:
--   Dynamic SQL with sp_executesql — executes a runtime-built
--     query without concatenating user input into the string
--   QUOTENAME(@FilterColumn) — safely wraps the column name
--     to prevent SQL injection via identifier manipulation
--   Column whitelist (IF NOT IN) — blocks any column name that
--     isn't explicitly approved, even before QUOTENAME runs
--   @val passed as a typed parameter to sp_executesql — the
--     filter value is never string-concatenated into the SQL
-- Parameters:
--   @FilterColumn VARCHAR(50) — 'claim_status' or 'diagnosis_code'
--   @FilterValue  VARCHAR(50) — the value to filter by
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE PROCEDURE dbo.usp_FilterClaims
    @FilterColumn VARCHAR(50),
    @FilterValue  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    -- Whitelist: never trust user-supplied column names directly
    IF @FilterColumn NOT IN ('claim_status', 'diagnosis_code')
    BEGIN
        RAISERROR('Invalid filter column. Allowed: claim_status, diagnosis_code.', 16, 1);
        RETURN;
    END

    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT
            c.claim_id,
            m.member_name,
            p.provider_name,
            c.service_date,
            c.claim_status,
            c.diagnosis_code,
            c.paid_amount
        FROM   dbo.claims    c
        JOIN   dbo.members   m ON c.member_id   = m.member_id
        JOIN   dbo.providers p ON c.provider_id = p.provider_id
        WHERE  ' + QUOTENAME(@FilterColumn) + N' = @val
        ORDER BY c.service_date DESC;';

    -- @val is passed as a proper typed parameter — NOT concatenated
    EXEC sp_executesql @SQL, N'@val VARCHAR(50)', @val = @FilterValue;
END;
GO

-- ============================================================
-- Test: filter by claim status
-- ============================================================
EXEC dbo.usp_FilterClaims
    @FilterColumn = 'claim_status',
    @FilterValue  = 'DENIED';

-- ============================================================
-- Test: filter by diagnosis code
-- ============================================================
EXEC dbo.usp_FilterClaims
    @FilterColumn = 'diagnosis_code',
    @FilterValue  = 'I21.0';
