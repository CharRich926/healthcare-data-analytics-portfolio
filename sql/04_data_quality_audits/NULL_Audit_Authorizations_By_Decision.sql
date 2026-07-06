/*
    NULL_Audit_Authorizations_By_Decision.sql

    Purpose:
    Full-column NULL audit against dbo.authorizations, broken out by
    decision status, to separate business-rule-expected NULLs (e.g. no
    decision_date on a still-open Pending authorization) from genuine
    data-quality anomalies.

    Finding (Week 3, Thursday):
    auth_id 7 carries decision = 'Pending' but has a populated
    decision_date, while units_approved remains NULL. A truly pending
    authorization should have neither decision_date nor units_approved
    populated. This is a partial-decision state inconsistent with normal
    business rules. Confirmed identically present across local SQL
    Server, Azure SQL, and the Fabric Lakehouse copy, ruling out a
    stale-sync explanation.

    Recommended fix: a check constraint enforcing
    decision_date IS NULL when decision = 'Pending'.
*/

SELECT
    decision,
    COUNT(*) AS total_rows,
    SUM(CASE WHEN decision_date IS NULL THEN 1 ELSE 0 END) AS null_decision_date,
    SUM(CASE WHEN units_approved IS NULL THEN 1 ELSE 0 END) AS null_units_approved,
    SUM(CASE WHEN denial_reason IS NULL THEN 1 ELSE 0 END) AS null_denial_reason
FROM dbo.authorizations
GROUP BY decision;