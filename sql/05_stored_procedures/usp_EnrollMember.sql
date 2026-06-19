-- ============================================================
-- Procedure: dbo.usp_EnrollMember
-- Purpose: Inserts a new member record and returns the
--          system-generated member ID back to the caller.
-- Key concepts:
--   OUTPUT parameter — @NewMemberID is passed by reference;
--     the caller declares a variable and reads it after EXEC
--   SCOPE_IDENTITY() — captures the identity value generated
--     by the INSERT in the current scope (safer than @@IDENTITY
--     which can be affected by triggers)
--   RETURN values as error codes — RETURN 0 signals success;
--     RETURN -1 / -2 signal specific validation failures;
--     this mirrors a common stored procedure contract pattern
--   Input validation with RAISERROR — gender and plan type are
--     validated against whitelists before any data is written
-- Parameters:
--   @MemberName   VARCHAR(100) — full member name
--   @DateOfBirth  DATE         — member date of birth
--   @Gender       CHAR(1)      — M, F, or U
--   @PlanType     CHAR(20)     — HMO, PPO, or EPO
--   @State        CHAR(2)      — two-character state code
--   @NewMemberID  INT OUTPUT   — receives the new member_id
-- Return values:
--    0 = success
--   -1 = invalid gender code
--   -2 = invalid plan type
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE PROCEDURE dbo.usp_EnrollMember
    @MemberName  VARCHAR(100),
    @DateOfBirth DATE,
    @Gender      CHAR(1),
    @PlanType    CHAR(20),
    @State       CHAR(2),
    @NewMemberID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate gender
    IF @Gender NOT IN ('M', 'F', 'U')
    BEGIN
        RAISERROR('Invalid gender code. Use M, F, or U.', 16, 1);
        RETURN -1;
    END

    -- Validate plan type
    IF @PlanType NOT IN ('HMO', 'PPO', 'EPO')
    BEGIN
        RAISERROR('Invalid plan type. Use HMO, PPO, or EPO.', 16, 1);
        RETURN -2;
    END

    INSERT INTO dbo.members (member_name, date_of_birth, gender, plan_type, state, enrollment_date)
    VALUES (@MemberName, @DateOfBirth, @Gender, @PlanType, @State, GETDATE());

    SET @NewMemberID = SCOPE_IDENTITY(); -- capture the auto-generated ID

    RETURN 0; -- 0 = success
END;
GO

-- ============================================================
-- Test: enroll a new member and capture the returned ID
-- ============================================================
DECLARE @NewID      INT;
DECLARE @ReturnCode INT;

EXEC @ReturnCode = dbo.usp_EnrollMember
    @MemberName  = 'Test Member',
    @DateOfBirth = '1990-05-15',
    @Gender      = 'M',
    @PlanType    = 'PPO',
    @State       = 'TX',
    @NewMemberID = @NewID OUTPUT;

SELECT
    @ReturnCode AS return_code,
    @NewID      AS new_member_id;
