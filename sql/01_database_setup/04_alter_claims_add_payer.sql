-- ============================================================
-- Script: 04_alter_claims_add_payer.sql
-- Database: HealthcarePractice
-- Purpose: Post-insert schema corrections applied after the
--          initial table creation and seed data load.
--          Documents changes made via ALTER that were not
--          captured in the original CREATE TABLE scripts.
-- Run after: 03_seed_data.sql
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================
-- Changes documented here:
--   1. dbo.payer — seed data (required before FK can be added)
--   2. dbo.claims — added payer_id column
--   3. dbo.claims — populated payer_id from existing claim data
--   4. dbo.claims — added FK constraint to dbo.payer
--   5. dbo.claims — added load_timestamp column (if not present)
--   6. dbo.diagnosis — seed data for ICD-10 lookup rows
-- ============================================================
-- Note: ALTER TABLE to add a NOT NULL column with no DEFAULT
--   to a table with existing rows will fail. The pattern used
--   here is: ADD column as NULL → UPDATE to populate →
--   then optionally add NOT NULL constraint if required.
-- ============================================================

USE HealthcarePractice;
GO

-- ============================================================
-- Step 1: Seed the payer table (must exist before FK is added)
-- ============================================================
INSERT INTO dbo.payer (payer_name)
VALUES
    ('BlueCross BlueShield'),
    ('Aetna'),
    ('UnitedHealthcare'),
    ('Cigna'),
    ('Humana');
GO

-- ============================================================
-- Step 2: Add payer_id column to claims (nullable first)
-- ============================================================
ALTER TABLE dbo.claims
    ADD payer_id INT NULL;
GO

-- ============================================================
-- Step 3: Populate payer_id on existing claim rows
-- Update with the actual payer assignments for your dataset.
-- Example pattern — adjust claim_id ranges to match your data:
-- ============================================================
-- BlueCross BlueShield (payer_id = 1) — members 1, 4 (HMO)
UPDATE dbo.claims SET payer_id = 1
WHERE member_id IN (1, 4);

-- Aetna (payer_id = 2) — members 2, 8 (PPO)
UPDATE dbo.claims SET payer_id = 2
WHERE member_id IN (2, 8);

-- UnitedHealthcare (payer_id = 3) — members 3, 7 (EPO)
UPDATE dbo.claims SET payer_id = 3
WHERE member_id IN (3, 7);

-- Cigna (payer_id = 4) — members 5, 6 (PPO, HMO)
UPDATE dbo.claims SET payer_id = 4
WHERE member_id IN (5, 6);
GO

-- ============================================================
-- Step 4: Add FK constraint now that all rows are populated
-- ============================================================
ALTER TABLE dbo.claims
    ADD CONSTRAINT FK_claims_payer
    FOREIGN KEY (payer_id) REFERENCES dbo.payer(payer_id);
GO

-- ============================================================
-- Step 5: Add load_timestamp if not present from CREATE TABLE
-- (load_timestamp tracks when each claim record was loaded —
--  used in claim_turnaround_time query via DATEDIFF)
-- ============================================================
ALTER TABLE dbo.claims
    ADD load_timestamp DATETIME DEFAULT GETDATE();
GO

-- Backfill load_timestamp for existing rows using service_date
-- as a proxy (adjust to actual load dates if known)
UPDATE dbo.claims
SET load_timestamp = DATEADD(DAY, 3, service_date)
WHERE load_timestamp IS NULL;
GO

-- ============================================================
-- Step 6: Seed diagnosis lookup table
-- (Only 8 rows — known gap vs 20+ distinct codes in claims.
--  See Orphaned_Records_Check.sql for the referential integrity
--  audit that surfaces this gap.)
-- ============================================================
INSERT INTO dbo.diagnosis (icd10_code, description)
VALUES
    ('I21.0',   'ST elevation myocardial infarction of anterior wall'),
    ('I50.9',   'Heart failure, unspecified'),
    ('I25.10',  'Atherosclerotic heart disease, unspecified'),
    ('Z00.00',  'Encounter for general adult medical examination'),
    ('C50.911', 'Malignant neoplasm of unspecified site of right female breast'),
    ('C34.11',  'Malignant neoplasm of upper lobe, right bronchus or lung'),
    ('F32.1',   'Major depressive disorder, single episode, moderate'),
    ('G20',     'Parkinson disease');
GO

-- ============================================================
-- Verification queries — run after to confirm changes applied
-- ============================================================

-- Confirm payer_id is populated on all claims
SELECT
    payer_id,
    COUNT(*) AS claim_count
FROM dbo.claims
GROUP BY payer_id
ORDER BY payer_id;

-- Confirm no NULL payer_id rows remain
SELECT COUNT(*) AS null_payer_count
FROM dbo.claims
WHERE payer_id IS NULL;

-- Confirm FK constraint exists
SELECT
    fk.name             AS constraint_name,
    tp.name             AS parent_table,
    tr.name             AS referenced_table
FROM sys.foreign_keys fk
JOIN sys.tables tp ON fk.parent_object_id  = tp.object_id
JOIN sys.tables tr ON fk.referenced_object_id = tr.object_id
WHERE tp.name = 'claims';
