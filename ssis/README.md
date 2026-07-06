# ETL Pipeline — SSIS

**Tool:** SQL Server Integration Services (SSIS), developed in Visual Studio
**Deployment:** Integration Services Catalogs on both the local SQL Server instance and the Azure SQL Database instance

## Package: Load_NewClaims

### Control Flow
![Control Flow](LoadNewClaims_Control_Flow.PNG)

### Data Flow
![Data Flow](LoadNewClaims_Data_Flow.PNG)

## Known Issues / Troubleshooting

**Silent row loss on unconnected error output** — A test load revealed 2 of
15 source rows disappearing with no error and no audit trail. Root cause:
one of two Lookup transformations had its "no match" output left
unconnected in the Data Flow, so SSIS silently dropped rows sent there
instead of erroring or logging them. Fixed by adding a Union All to merge
both lookups' no-match outputs into the existing reject path. Full
write-up, root cause analysis, and row-count validation:
[`SSIS_Troubleshooting_Load_NewClaims.md`](SSIS_Troubleshooting_Load_NewClaims.md)

## Files

| File | Description |
|---|---|
| [`Load_NewClaims.dtsx`](Load_NewClaims.dtsx) | SSIS package file |
| [`LoadNewClaims_Control_Flow.PNG`](LoadNewClaims_Control_Flow.PNG) | Control flow screenshot |
| [`LoadNewClaims_Data_Flow.PNG`](LoadNewClaims_Data_Flow.PNG) | Data flow screenshot |
| [`SSIS_Troubleshooting_Load_NewClaims.md`](SSIS_Troubleshooting_Load_NewClaims.md) | Root cause analysis and fix for the silent row-loss bug |
