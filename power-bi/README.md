# Project 1 — Claims Denial Analysis Dashboard

**Status:** ✅ Complete
**Tool:** Power BI Desktop (Import mode) → published to Microsoft Fabric workspace `HealthcarePractice`
**Report name:** `HC_Practice_DenialAnalysis_BI_Report`

## Overview

A two-page Power BI report analyzing claim denials by payer, provider, and denial reason, built on top of `dbo.vw_denial_analysis` and the Fabric named query library.

## Pages

### 1. Denial Analysis
High-level denial metrics with payer and provider slicers for cross-filtering.

### 2. Denial Reasons
Breakdown of denial reasons with four visuals: bar chart, donut chart, stacked bar, and KPI card. Includes a provider name dropdown slicer.

## DAX Measures

| Measure | Logic |
|---|---|
| `Denial Rate %` | Denied claims ÷ total claims |
| `Total Denied Amount` | SUM of billed amount where claim is denied |
| `MoM Denial Change` | Month-over-month change in denial volume |
| `Top Denial Reason` | `FIRSTNONBLANK` + `TOPN` to surface the leading denial reason dynamically |

## Key Findings

- **Duplicate Claim** is the top denial reason — 24 denials (23.5% of all denials). This is an operational submission issue, not a clinical or coding problem.
- **Coding Error** is the second-leading cause — 22 denials (21.6%).

## Screenshots

> Add report screenshots here, e.g.:
> - `denial-analysis-page.png`
> - `denial-reasons-page.png`

To add: export each page as an image from Power BI Desktop (File → Export → Image, or a screenshot), drop the files in this folder, and reference them below:

```markdown
![Denial Analysis Page](denial-analysis-page.png)
![Denial Reasons Page](denial-reasons-page.png)
```

## How it was built

1. Base denial query and aggregation query written and debugged in SSMS
2. `dbo.vw_denial_analysis` created in SQL Server, mirrored as a named query in the Fabric SQL endpoint
3. Power BI Desktop connected via Import mode (Direct Lake doesn't support views — see [`docs/architecture.md`](../docs/architecture.md))
4. DAX measures authored and formatted at the measure level
5. Visuals built, slicers added, report published to the Fabric workspace
