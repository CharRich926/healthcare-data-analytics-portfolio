-- ============================================================
-- Script: create_tables.sql
-- Database: HealthcarePractice
-- Purpose: Creates all 9 tables for the HealthcarePractice
--          analytics environment in correct dependency order.
--          Tables with no foreign keys are created first;
--          tables with FK references follow.
-- Environment: SQL Server (on-prem) + Azure SQL Database
-- ============================================================
-- Dependency order:
--   Tier 1 (no FKs): members, providers, payer, diagnosis,
--                    dim_date, audit_log
--   Tier 2 (FK to Tier 1): claims, network_contracts,
--                           authorizations
--   Tier 3 (FK to Tier 2): claim_lines
-- ============================================================

USE HealthcarePractice;
GO

-- ============================================================
-- TIER 1 — No foreign key dependencies
-- ============================================================

CREATE TABLE dbo.members (
    member_id       INT IDENTITY(1,1) PRIMARY KEY,
    member_name     VARCHAR(100),
    date_of_birth   DATE,
    gender          CHAR(1),
    plan_type       VARCHAR(20),
    state           CHAR(2),
    enrollment_date DATE,
    disenroll_date  DATE
);
GO

CREATE TABLE dbo.providers (
    provider_id     INT IDENTITY(1,1) PRIMARY KEY,
    npi             VARCHAR(10),
    provider_name   VARCHAR(100),
    specialty       VARCHAR(50),
    network_status  VARCHAR(10),
    tax_id          VARCHAR(9),
    group_name      VARCHAR(100),
    effective_date  DATE,
    term_date       DATE
);
GO

CREATE TABLE dbo.payer (
    payer_id    INT IDENTITY(1,1) PRIMARY KEY,
    payer_name  VARCHAR(100)
);
GO

CREATE TABLE dbo.diagnosis (
    icd10_code  VARCHAR(10) PRIMARY KEY,
    description VARCHAR(255)
);
GO

-- Note: join key naming difference — diagnosis.icd10_code joins
-- to claims.diagnosis_code. These are the same value with
-- different column names across tables. Always use:
--   JOIN dbo.diagnosis d ON d.icd10_code = c.diagnosis_code

CREATE TABLE dbo.dim_date (
    date_key        INT PRIMARY KEY,         -- YYYYMMDD integer key
    full_date       DATE,
    calendar_year   INT,
    calendar_month  INT,
    month_name      VARCHAR(20),
    calendar_quarter INT,
    day_of_week     VARCHAR(20)
);
GO

CREATE TABLE dbo.audit_log (
    log_id      INT IDENTITY(1,1) PRIMARY KEY,
    table_name  VARCHAR(50),
    operation   VARCHAR(10),
    record_id   INT,
    changed_by  VARCHAR(50),
    change_date DATETIME DEFAULT GETDATE(),
    notes       VARCHAR(500)
);
GO

-- ============================================================
-- TIER 2 — Foreign keys to Tier 1 tables
-- ============================================================

CREATE TABLE dbo.claims (
    claim_id        INT IDENTITY(1,1) PRIMARY KEY,
    member_id       INT REFERENCES dbo.members(member_id),
    provider_id     INT REFERENCES dbo.providers(provider_id),
    payer_id        INT REFERENCES dbo.payer(payer_id),
    service_date    DATE,
    admit_date      DATE,
    discharge_date  DATE,
    diagnosis_code  VARCHAR(10),
    procedure_code  VARCHAR(10),
    billed_amount   DECIMAL(10,2),
    allowed_amount  DECIMAL(10,2),
    paid_amount     DECIMAL(10,2),
    claim_status    VARCHAR(15),
    denial_reason   VARCHAR(100),
    load_timestamp  DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE dbo.network_contracts (
    contract_id     INT IDENTITY(1,1) PRIMARY KEY,
    provider_id     INT REFERENCES dbo.providers(provider_id),
    contract_type   VARCHAR(30),
    rate_modifier   DECIMAL(5,4),
    start_date      DATE,
    end_date        DATE
);
GO

CREATE TABLE dbo.authorizations (
    auth_id          INT IDENTITY(1,1) PRIMARY KEY,
    member_id        INT REFERENCES dbo.members(member_id),
    provider_id      INT REFERENCES dbo.providers(provider_id),
    auth_type        VARCHAR(30),
    requested_date   DATE,
    decision_date    DATE,
    decision         VARCHAR(15),
    units_requested  INT,
    units_approved   INT,
    denial_reason    VARCHAR(100)
);
GO

-- ============================================================
-- TIER 3 — Foreign key to claims (Tier 2)
-- ============================================================

CREATE TABLE dbo.claim_lines (
    line_id         INT IDENTITY(1,1) PRIMARY KEY,
    claim_id        INT REFERENCES dbo.claims(claim_id),
    line_number     INT,
    procedure_code  VARCHAR(10),
    diagnosis_code  VARCHAR(10),
    billed_amount   DECIMAL(10,2),
    allowed_amount  DECIMAL(10,2),
    paid_amount     DECIMAL(10,2),
    units           INT,
    service_date    DATE
);
GO
