-- ============================================================
-- View: dbo.vw_ActiveProviders
-- Purpose: Returns all currently active providers joined to
--          their active network contract terms.
-- Key concepts: LEFT JOIN, GETDATE() for term date filtering,
--               multi-condition join on contract end_date
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE VIEW dbo.vw_ActiveProviders AS
SELECT
    p.provider_id,
    p.npi,
    p.provider_name,
    p.specialty,
    p.network_status,
    p.group_name,
    p.effective_date,
    nc.contract_type,
    nc.rate_modifier
FROM dbo.providers p
LEFT JOIN dbo.network_contracts nc
    ON p.provider_id = nc.provider_id
    AND (nc.end_date IS NULL OR nc.end_date > GETDATE())
WHERE p.term_date IS NULL OR p.term_date > GETDATE();
GO

-- ============================================================
-- Usage
-- ============================================================
SELECT * FROM dbo.vw_ActiveProviders ORDER BY specialty;
