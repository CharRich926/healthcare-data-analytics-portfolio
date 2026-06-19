-- ============================================================
-- Script: 03_seed_data.sql
-- Database: HealthcarePractice
-- Purpose: Inserts seed data for all core tables.
--          Provides a realistic healthcare claims dataset
--          covering 8 members, 7 providers, 6 network contracts,
--          16 claims across multiple statuses, and 8 authorizations.
-- Run after: 01_create_tables.sql, 02_create_indexes.sql
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================
-- Dataset characteristics:
--   Members:        8 (HMO, PPO, EPO mix; TX state)
--   Providers:      7 (6 in-network, 1 out-of-network)
--   Specialties:    Cardiology, Primary Care, Oncology,
--                   Neurology, Orthopedics, Psychiatry
--   Claims:         16 (PAID, DENIED, PENDING, ADJUSTED)
--   Denial reasons: 'Not medically necessary',
--                   'Prior auth required'
--   Authorizations: 8 (Approved, Denied, Pending)
-- ============================================================

USE HealthcarePractice;
GO

-- ============================================================
-- Members
-- ============================================================
INSERT INTO dbo.members (member_name, date_of_birth, gender, plan_type, state, enrollment_date, disenroll_date)
VALUES
    ('Alice Carter',  '1985-03-12', 'F', 'HMO', 'TX', '2021-01-01', NULL),
    ('Brian Torres',  '1978-07-22', 'M', 'PPO', 'TX', '2020-06-01', NULL),
    ('Carol White',   '1990-11-05', 'F', 'EPO', 'TX', '2022-03-01', '2024-06-30'),
    ('David Kim',     '1965-04-30', 'M', 'HMO', 'TX', '2019-01-01', NULL),
    ('Elena Nguyen',  '1992-09-18', 'F', 'PPO', 'TX', '2023-01-01', NULL),
    ('Frank Okafor',  '1955-12-01', 'M', 'HMO', 'TX', '2018-01-01', NULL),
    ('Grace Liu',     '2000-02-14', 'F', 'EPO', 'TX', '2023-07-01', NULL),
    ('Henry Adams',   '1975-06-06', 'M', 'PPO', 'TX', '2021-09-01', NULL);
GO

-- ============================================================
-- Providers
-- Note: provider_id 4 (Dr. Michael Green) has network_status
--       'OUT' — used in network status impact analysis
-- ============================================================
INSERT INTO dbo.providers (npi, provider_name, specialty, network_status, tax_id, group_name, effective_date, term_date)
VALUES
    ('1234567890', 'Dr. Sarah Mitchell', 'Cardiology',   'IN',  '123456789', 'Heart Partners',    '2020-01-01', NULL),
    ('9876543210', 'Dr. Luis Herrera',   'Primary Care', 'IN',  '987654321', 'CareFirst Medical', '2019-06-01', NULL),
    ('1111111111', 'Dr. Joan Baker',     'Oncology',     'IN',  '111111111', 'Oncology Assoc.',   '2021-01-01', NULL),
    ('2222222222', 'Dr. Michael Green',  'Neurology',    'OUT', '222222222', 'Neuro Specialists', '2020-03-01', NULL),
    ('3333333333', 'Dr. Amy Patel',      'Primary Care', 'IN',  '333333333', 'CareFirst Medical', '2022-01-01', NULL),
    ('4444444444', 'Dr. Robert Singh',   'Orthopedics',  'IN',  '444444444', 'OrthoTX Group',     '2021-06-01', NULL),
    ('5555555555', 'Dr. Linda Chow',     'Psychiatry',   'IN',  '555555555', 'MindCare Network',  '2023-01-01', NULL);
GO

-- ============================================================
-- Network contracts
-- Note: provider 4 (out-of-network) has no contract row —
--       LEFT JOIN in vw_ActiveProviders handles this correctly
-- ============================================================
INSERT INTO dbo.network_contracts (provider_id, contract_type, rate_modifier, start_date, end_date)
VALUES
    (1, 'Value-Based', 0.9200, '2020-01-01', NULL),
    (2, 'FFS',         0.8500, '2019-06-01', NULL),
    (3, 'Capitated',   1.0000, '2021-01-01', NULL),
    (5, 'FFS',         0.8800, '2022-01-01', NULL),
    (6, 'FFS',         0.9000, '2021-06-01', NULL),
    (7, 'FFS',         0.8700, '2023-01-01', NULL);
GO

-- ============================================================
-- Claims
-- Note: payer_id column is included in the table schema but
--       was not present in the original seed INSERT — add
--       payer_id values here once payer rows are inserted.
--       claim_status values: PAID, DENIED, PENDING, ADJUSTED
-- ============================================================
INSERT INTO dbo.claims (member_id, provider_id, service_date, admit_date, discharge_date,
                        diagnosis_code, procedure_code, billed_amount, allowed_amount, paid_amount,
                        claim_status, denial_reason)
VALUES
    (1, 1, '2024-01-15', '2024-01-15', '2024-01-17', 'I21.0',   '99213',  4200.00, 3800.00, 3496.00, 'PAID',     NULL),
    (1, 2, '2024-02-10', NULL,         NULL,          'Z00.00',  '99213',   180.00,  153.00,  130.05, 'PAID',     NULL),
    (2, 1, '2024-01-20', '2024-01-20', '2024-01-25', 'I21.0',   '99223',  9500.00, 8200.00, 7544.00, 'PAID',     NULL),
    (2, 6, '2024-03-05', NULL,         NULL,          'M54.5',   '27447',   600.00,  540.00,  486.00, 'PAID',     NULL),
    (3, 3, '2024-01-08', NULL,         NULL,          'C50.911', '99214',  1200.00,    0.00,    0.00, 'DENIED',   'Not medically necessary'),
    (4, 1, '2024-02-28', '2024-02-28', '2024-03-02', 'I50.9',   '99223',  7800.00, 7100.00, 6532.00, 'PAID',     NULL),
    (4, 5, '2024-03-15', NULL,         NULL,          'Z00.00',  '99213',   190.00,  161.50,  161.50, 'PAID',     NULL),
    (5, 7, '2024-02-01', NULL,         NULL,          'F32.1',   '90837',   250.00,  212.50,  184.88, 'PAID',     NULL),
    (5, 7, '2024-03-01', NULL,         NULL,          'F32.1',   '90837',   250.00,  212.50,  184.88, 'PAID',     NULL),
    (6, 3, '2024-01-12', NULL,         NULL,          'C34.11',  '99215',  3100.00,    0.00,    0.00, 'DENIED',   'Prior auth required'),
    (6, 4, '2023-12-20', NULL,         NULL,          'G20',     '99214',   320.00,  288.00,    0.00, 'PENDING',  NULL),
    (7, 5, '2024-04-01', NULL,         NULL,          'Z00.00',  '99213',   175.00,  148.75,  148.75, 'PAID',     NULL),
    (8, 2, '2024-01-30', NULL,         NULL,          'Z00.00',  '99213',   180.00,  153.00,  130.05, 'PAID',     NULL),
    (8, 6, '2024-04-10', '2024-04-10', '2024-04-12', 'M16.11',  '27447',  5200.00, 4680.00, 4212.00, 'ADJUSTED', 'Billed amount corrected'),
    (1, 1, '2024-04-22', NULL,         NULL,          'I25.10',  '99214',   350.00,  315.00,  289.80, 'PAID',     NULL),
    (3, 2, '2023-10-05', NULL,         NULL,          'Z00.00',  '99213',   180.00,  153.00,  130.05, 'PAID',     NULL);
GO

-- ============================================================
-- Authorizations
-- ============================================================
INSERT INTO dbo.authorizations (member_id, provider_id, auth_type, requested_date, decision_date,
                                decision, units_requested, units_approved, denial_reason)
VALUES
    (1, 1, 'Inpatient',  '2024-01-13', '2024-01-14', 'Approved', 5, 3,    NULL),
    (2, 1, 'Inpatient',  '2024-01-18', '2024-01-19', 'Approved', 7, 5,    NULL),
    (3, 3, 'Outpatient', '2024-01-06', '2024-01-07', 'Denied',   1, 0,    'Not medically necessary'),
    (4, 1, 'Inpatient',  '2024-02-26', '2024-02-27', 'Approved', 5, 4,    NULL),
    (5, 7, 'Specialist', '2024-01-29', '2024-01-30', 'Approved', 8, 8,    NULL),
    (6, 3, 'Outpatient', '2024-01-10', '2024-01-11', 'Denied',   1, 0,    'Prior auth required'),
    (6, 4, 'Specialist', '2023-12-18', '2023-12-19', 'Pending',  4, NULL, NULL),
    (8, 6, 'Inpatient',  '2024-04-08', '2024-04-09', 'Approved', 3, 2,    NULL);
GO
