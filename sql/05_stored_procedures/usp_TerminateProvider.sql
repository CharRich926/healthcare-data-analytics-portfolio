-- ============================================================
-- Procedure: dbo.usp_TerminateProvider
-- Purpose: Terminates a provider by setting term_date, closes
--          any open network contracts, and writes an audit log
--          entry — all within a single atomic transaction.
-- Key concepts:
--   BEGIN TRY / BEGIN CATCH — structured error handling
--   BEGIN TRANSACTION / COMMIT / ROLLBACK — atomicity:
--     all three operations succeed together or none do
--   @@ROWCOUNT — validates the UPDATE actually matched a row
--   THROW 50001 — raises a user-defined error with custom message
--   audit_log INSERT — operational change tracking
-- Parameters:
--   @ProviderID  INT         — provider to terminate
--   @TermDate    DATE        — effective termination date
--   @ChangedBy   VARCHAR(50) — user or process making the change
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE PROCEDURE dbo.usp_TerminateProvider
    @ProviderID INT,
    @TermDate   DATE,
    @ChangedBy  VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

            -- Set provider term date
            UPDATE dbo.providers
            SET term_date = @TermDate
            WHERE provider_id = @ProviderID;

            -- Validate: make sure the row actually exists
            IF @@ROWCOUNT = 0
                THROW 50001, 'Provider not found.', 1;

            -- Close any open network contracts for this provider
            UPDATE dbo.network_contracts
            SET end_date = @TermDate
            WHERE provider_id = @ProviderID
                AND (end_date IS NULL OR end_date > @TermDate);

            -- Write audit log entry
            INSERT INTO dbo.audit_log (table_name, operation, record_id, changed_by, notes)
            VALUES ('providers', 'UPDATE', @ProviderID, @ChangedBy,
                    'Provider terminated. Term Date set to ' + CAST(@TermDate AS VARCHAR));

        COMMIT TRANSACTION;
        SELECT 'Provider terminated successfully.' AS result;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;

        SELECT
            ERROR_NUMBER()    AS error_number,
            ERROR_MESSAGE()   AS error_message,
            ERROR_PROCEDURE() AS error_procedure,
            ERROR_LINE()      AS error_line;
    END CATCH;
END;
GO

-- ============================================================
-- Test: valid provider
-- ============================================================
EXEC dbo.usp_TerminateProvider
    @ProviderID = 7,
    @TermDate   = '2025-12-31',
    @ChangedBy  = 'admin';

-- ============================================================
-- Test: invalid provider ID — exercises THROW + CATCH block
-- ============================================================
EXEC dbo.usp_TerminateProvider
    @ProviderID = 999,
    @TermDate   = '2025-12-31',
    @ChangedBy  = 'admin';
