# ETL Pipeline — SSIS

**Tool:** SQL Server Integration Services (SSIS), developed in Visual Studio
**Deployment:** Integration Services Catalogs on both the local SQL Server instance and the Azure SQL Database instance

## Overview

An SSIS package handles inbound claims file processing for the `HealthcarePractice` environment. The pipeline is deployed to Integration Services Catalogs on **both** the on-premises and Azure SQL instances, supporting the same dual-environment pattern used for the rest of the stack (see [`docs/architecture.md`](../docs/architecture.md)).

## Planned enhancement — Project 4: Audit Logging

**Status:** 🔲 Planned

Add a Script Task to the claims-loading package to log run metadata to `dbo.audit_log`:

- Run date / timestamp
- Row counts processed
- Rejected record counts

This turns the pipeline from a "fire and forget" load process into one with operational visibility — a standard requirement in production healthcare ETL, where claim load failures or partial loads need to be caught and traced.

## Files

> Add `.dtsx` package files or package screenshots here once exported from Visual Studio.
