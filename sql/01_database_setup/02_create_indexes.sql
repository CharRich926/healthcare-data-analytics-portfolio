-- ============================================================
-- Script: 02_create_indexes.sql
-- Database: HealthcarePractice
-- Purpose: Non-clustered indexes on dbo.claims to support
--          analytical query patterns.
-- Key concepts:
--   Non-clustered indexes speed up reads on the indexed columns
--   but add overhead to INSERT/UPDATE/DELETE operations. Index
--   columns that appear in WHERE, JOIN, and ORDER BY clauses.
--   At small data volumes, the SQL Server query optimizer may
--   still choose a full table scan over an index seek — index
--   value scales with data volume.
-- Run after: 01_create_tables.sql
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================

USE HealthcarePractice;
GO

-- Supports: WHERE c.claim_status = 'DENIED' (denial queries,
--           audit queries, all conditional aggregations)
CREATE NONCLUSTERED INDEX IX_claims_claim_status
    ON dbo.claims (claim_status);
GO

-- Supports: JOIN dbo.payer py ON py.payer_id = c.payer_id
--           GROUP BY payer_id (turnaround time, payer analysis)
CREATE NONCLUSTERED INDEX IX_claims_payer_id
    ON dbo.claims (payer_id);
GO

-- Supports: JOIN dbo.providers p ON p.provider_id = c.provider_id
--           GROUP BY provider_id (denial rate, network analysis)
CREATE NONCLUSTERED INDEX IX_claims_provider_id
    ON dbo.claims (provider_id);
GO

-- Supports: WHERE service_date BETWEEN @StartDate AND @EndDate
--           ORDER BY service_date DESC (member history, trends)
CREATE NONCLUSTERED INDEX IX_claims_service_date
    ON dbo.claims (service_date);
GO
