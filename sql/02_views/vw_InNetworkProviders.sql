-- ============================================================
-- View: dbo.vw_InNetworkProviders
-- Purpose: Returns only in-network providers for downstream
--          filtering and reporting use cases.
-- Key concepts: WITH CHECK OPTION — prevents any future UPDATE
--               through this view from making a row disappear
--               (e.g. changing network_status to 'OUT' via the view
--               would be blocked)
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

CREATE VIEW dbo.vw_InNetworkProviders AS
SELECT
    provider_id,
    provider_name,
    specialty,
    network_status,
    npi
FROM dbo.providers
WHERE network_status = 'IN'
WITH CHECK OPTION;
GO
