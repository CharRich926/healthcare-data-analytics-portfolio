# Power BI Reports — HealthcarePractice

Two published reports in the `HealthcarePractice` Fabric workspace, plus a curated Power BI App published from Report 2 (Week 5 Thursday).

**Data source note (Week 5 Monday):** Report 2 was originally built via Import mode directly against the Azure SQL Database. As of Week 5 Monday, its data source was repointed to the `HealthcarePractice_Lakehouse` SQL analytics endpoint — the architecturally correct setup, since the Lakehouse is the intended Fabric-native analytics layer fed by ETL from Azure SQL, not a duplicate of the source system itself. Report 1 remains on the Fabric SQL endpoint as originally built (see Report 1 below).

---

## Report 1 — HC_Practice_DenialAnalysis_BI_Report

**Status:** ✅ Complete — Published to Fabric workspace
**Pages:** 2 (Denial Analysis, Denial Reasons)
**Source:** `dbo.vw_denial_analysis` via Fabric SQL endpoint

### Pages

**1. Denial Analysis**
- Denial Rate by Provider (horizontal bar chart)
- Denied Claims by Diagnosis Category (treemap)
- Denial Rate Trend over time (line chart)
- KPI cards: Sum of Denied Claims, Denial Rate %, Total Denied Amount
- Payer name slicer for cross-filtering

**2. Denial Reasons**
- Sum of denied_claims by denial_reason (bar chart)
- Denial reason distribution (donut chart)
- Denied claims by denial_reason and payer_name (stacked bar)
- Provider name dropdown slicer

### DAX Measures

| Measure | Logic |
|---|---|
| `Denial Rate %` | Denied claims ÷ adjudicated claims (Denied + Approved only) — see note below |
| `Total Denied Amount` | SUM of billed amount where claim is denied |
| `MoM Denial Change` | Month-over-month change in denial volume |
| `Top Denial Reason` | `FIRSTNONBLANK` + `TOPN` — surfaces leading denial reason dynamically |

**Denominator correction:** `Denial Rate %` was originally calculated as denied claims ÷ total claims, which understated the true rate whenever Pending (unadjudicated) claims were present in the denominator. Corrected to denied ÷ (denied + approved) only, consistent with the same fix applied to [`usp_GetDenialSummary`](../sql/05_stored_procedures/usp_GetDenialSummary.sql) in the SQL layer — same business rule applied at both the database and reporting layer.

### Key Findings

- **Duplicate Claim** is the top denial reason — 24 denials (23.5% of all denials). An operational submission issue, not a clinical or coding problem.
- **Coding Error** is the second-leading cause — 22 denials (21.6%).

### Live Report

🔗 **[View Interactive Report in Microsoft Fabric](https://app.fabric.microsoft.com/links/MhZdbtvaK5?ctid=8fedba72-8759-44af-bedb-7ef18463552a&pbi_source=linkShare&bookmarkGuid=dfce8455-987c-4cfc-bccc-87bfaf41c78f)**

### Screenshots

![Denial Analysis](Denial_Rate_Analysis.png)
![Denial Reasons](Claims_Denial_Reasons.PNG)
![Published in Fabric](Claims_Denial_Published_In_Fabric.PNG)

### How it was built

1. Base denial query and aggregation query written and debugged in SSMS
2. `dbo.vw_denial_analysis` created in SQL Server, mirrored as a named query in the Fabric SQL endpoint
3. Power BI Desktop connected via Import mode (Direct Lake doesn't support views — see [`docs/architecture.md`](../docs/architecture.md))
4. DAX measures authored and formatted at the measure level
5. Visuals built, slicers added, report published to Fabric workspace

---

## Report 2 — HealthcarePractice (Multi-Page Claims & Provider Report)

**Status:** ✅ Complete — Published to Fabric workspace; curated App published Week 5 Thursday
**Pages:** 8 (Claims Overview, Provider Performance, Member Analysis, Data Quality Scorecard, Denial Analysis, Time Intelligence Validation, Authorizations, Denial Drivers)
**Source:** `HealthcarePractice_Lakehouse` (see data source note above) — all core tables via Import mode

### NPI Registry API Integration

This report includes a **live REST API integration** with the CMS NPI Registry (`npiregistry.cms.hhs.gov/api`) built in Power Query M.

A custom M function (`fnGetNPIData`) was written to call the NPI Registry API for each provider, passing the NPI number and returning enriched provider data:

```
= (npi_number as text) =>
let
    url = "https://npiregistry.cms.hhs.gov/api/?version=2.1&number=" & npi_number,
    source = Json.Document(Web.Contents(url)),
    results = source[results],
    hasResults = List.Count(results) > 0,
    firstResult = if hasResults then results{0} else null,
    basic = if hasResults then firstResult[basic] else null,
    taxonomies = if hasResults then firstResult[taxonomies] else {},
    firstTaxonomy = if List.Count(taxonomies) > 0 then taxonomies{0} else null,
    addresses = if hasResults then firstResult[addresses] else {},
    filteredAddresses = List.Select(addresses, each _[address_purpose] = "LOCATION"),
    locationAddress = if List.Count(filteredAddresses) > 0 then filteredAddresses{0} else null,
    credential = if basic = null then null else Record.FieldOrDefault(basic, "credential", null),
    status   = if basic = null then null else Record.FieldOrDefault(basic, "status", null),
    city     = if locationAddress = null then null else Record.FieldOrDefault(locationAddress, "city", null),
    state    = if locationAddress = null then null else Record.FieldOrDefault(locationAddress, "state", null),
    specialty = if firstTaxonomy = null then null else Record.FieldOrDefault(firstTaxonomy, "desc", null)
in
    [
        NPI_Credential = credential,
        NPI_Status     = status,
        NPI_City       = city,
        NPI_State      = state,
        NPI_Specialty  = specialty
    ]
```

The function was invoked against the `providers` table, expanding the NPI API response into five new columns (`NPI_Credential`, `NPI_Status`, `NPI_City`, `NPI_State`, `NPI_Specialty`) merged alongside the existing provider records. This enriches provider data with real, live credentialing information from the national NPI database.

**Why this matters:** The NPI Registry is the authoritative source for provider credentialing in the US healthcare system. Integrating it directly into Power BI via API removes the need to maintain a separate provider reference file and ensures credentials and taxonomy classifications are always sourced from CMS.

### Pages

**1. Claims Overview**
- KPI cards: 555 Total Claims (confirmed post-dedup, Week 5 Thursday — see Data Quality note below), $4.10M Total Billed, $1.84M Total Paid
- Total Billed by Year and Month (line chart, monthly grain — 2023 vs 2024 comparison)
- Total Claims by claim_status (bar chart: Approved, Denied, Pending)
- Total Billed by payer_name (horizontal bar chart)

**2. Provider Performance**
- Full provider table with: specialty, network_status, total claims, total billed, total paid, denial rate %, NPI_Credential (from API)
- Total Billed by provider_name (bar chart)
- Denial Rate % by specialty (bar chart)
- NPI_Status slicer

**3. Member Analysis**
- Member detail table: member_name, plan_type, state, total claims, total billed
- Total Claims by gender (donut chart)
- Total Billed by plan_type (bar chart — HMO, PPO, HDHP, EPO)
- Total Claims by state (bar chart)

**4. Data Quality Scorecard**
- KPI cards: Completeness Score, Integrity Score, Uniqueness Score, Validity Score

**5. Denial Analysis**
- Rolling 3-Month Denial Rate Trend (line chart, built with `DATESINPERIOD` against a proper `dim_date` date table)
- Denial Rate % KPI card (point-in-time, adjudicated-claims basis)
- Total Claims by claim_status (bar chart)
- Denial rate by payer_name (table: Total Claims, Total Denied Claims, Denial Rate %)

This page pairs a point-in-time denial rate with a smoothed rolling trend so both "where things stand now" and "which direction things are moving" are visible together — the rolling measure exists specifically to reduce month-to-month noise that a single snapshot rate doesn't show.

**6. Time Intelligence Validation**
- Self-contained validation page pairing DAX time-intelligence output (`Billed Amount PY`, `Total Billed YTD`) with the equivalent hand-written SQL query, embedded directly on the page as proof the two agree — a dedicated check page rather than a viewer-facing analytical page, and one of two pages deliberately excluded from the published App (see below).

**7. Authorizations**
- Built on the `authorizations` → `providers` relationship (many-to-one)
- `Avg Turnaround Days` DAX measure (`AVERAGEX` + `NOT ISBLANK` filter on `decision_date`), cross-validated against a manual SQL query — both return 1.00 days exactly

**8. Denial Drivers**
- Decomposition Tree (AI visual): Total Claims → claim_status → payer_name → provider_name, drilling from the top-level claim count down to individual provider-level denial detail
- Serves as the live validation surface for the Fabric incremental pipeline (`HC_Load_Claims_Incremental`) — a successful pipeline run should produce a visible, traceable shift in Total Claims and the Denied count on this page after refresh

### DAX Measures (Report 2)

| Measure | Logic |
|---|---|
| `Denial Rate %` | `VAR`/`RETURN` refactor (Week 5 Tuesday) — `AdjudicatedClaims` isolated as a named variable via `CALCULATE([Total Claims], claims[claim_status] IN {"Denied", "Approved"})`, then `DIVIDE([Total Denied Claims], AdjudicatedClaims, 0)` with a safe-division fallback. Reuses existing measures rather than rewriting raw `CALCULATE(COUNTROWS(...))` logic. Output unchanged after the refactor — 555 total claims, 103 denied, 0.21 overall. |
| `Rolling 3-Month Denial Rate` | `DATESINPERIOD` over the trailing 3 months, denied ÷ adjudicated claims within that window |
| `Denial Category` | `SWITCH(TRUE(), ...)` bucketing raw `denial_reason` text into higher-level categories (Clinical, Authorization, Administrative, Financial, Other) for cleaner grouping on the Denial Drivers decomposition tree |
| `Provider Rank by Billed Amount` | `RANKX` over all providers by total billed amount, using `ALL(providers[provider_name])` to remove provider-level filtering while still respecting other active filters (e.g. claim_status) — the live filter-context demo above uses this measure |
| `Avg Turnaround Days` | `AVERAGEX` over `authorizations`, filtered with `NOT ISBLANK(decision_date)` to exclude an in-progress row from skewing the average |
| `Denial Rate % of Total` | (Week 5 Thursday) — `CALCULATE([Denial Rate %], ALL(providers))`. `ALL` rather than `ALLEXCEPT`, since `ALLEXCEPT` requires at least one preserved-column argument and can't be called with just a table name. Every row shows the same company-wide rate (0.21) regardless of which provider, specialty, or network status the row belongs to, while date/payer slicers on separate tables continue to apply normally — a working "% of total, ignoring one specific filter" pattern. |

All denial rate measures share the same adjudicated-claims-only denominator convention used in the SQL stored procedures, so the definition of "denial rate" stays consistent across the SQL, Power BI, and reporting layers of the portfolio.

### Data Quality — Lakehouse Payer/Claims Correction (Week 5 Thursday)

Ahead of the App publish, a routine refresh surfaced two pre-existing data-quality issues in the Lakehouse copy of the data, both caught and fixed before either reached a published, viewer-facing artifact:

1. **Stale `payer` table:** the Lakehouse's `payer` table still held the original real company names, never re-synced after Azure SQL's copy was scrubbed to the fictional labels used throughout this portfolio (see Note on Payer Names below). Corrected via a PySpark `overwrite` write of the 8-row corrected reference set, resolving a Delta schema-merge conflict along the way with `.option("overwriteSchema", "true")`.
2. **Duplicate claim row:** the same refresh then failed with a `claim_id` uniqueness violation — `claim_id 1319` had four fully identical duplicate rows in the Lakehouse `claims` table. Fixed via `dropDuplicates()` in the same PySpark session; confirmed Total Claims correctly reads 555 post-fix.

### Power BI App (Week 5 Thursday)

Published the first curated **App** from the `HealthcarePractice` workspace, selecting 6 of the report's 8 pages for the viewer-facing package:

**Included:** Claims Overview, Provider Performance, Member Analysis, Denial Analysis, Authorizations, Denial Drivers
**Excluded:** Data Quality Scorecard, Time Intelligence Validation — both are dev/QA-oriented check pages rather than business-facing analytics, deliberately kept workspace-only rather than shipped to viewers

Audience scoped to specific users rather than the entire organization, appropriate for a portfolio/trial-tenant environment.

### Live Report

🔗 **[View Interactive Report in Microsoft Fabric](https://app.fabric.microsoft.com/links/wAjvlTxf5t?ctid=8fedba72-8759-44af-bedb-7ef18463552a&pbi_source=linkShare)**

### Screenshots

![Claims Overview](HealthcarePractice_Claims.PNG)
![Provider Performance](HealthcarePractice_Provider_Performance.PNG)
![Member Analysis](HealthcarePractice_Member_Analysis.PNG)

*Denial Analysis page screenshot for this report pending.*

### How it was built

1. Power BI Desktop connected to Azure SQL Database via Import mode
2. Custom M function `fnGetNPIData` written in Power Query Advanced Editor
3. Function invoked against `providers` table — NPI number passed per row, API response expanded and merged
4. NPI-enriched provider columns (`NPI_Credential`, `NPI_Status`, `NPI_City`, `NPI_State`, `NPI_Specialty`) added to data model
5. DAX measures built for claims KPIs, denial rate, billed/paid aggregations
6. `dim_date` confirmed and marked as a proper Date Table, actively related to `claims[service_date]` → `dim_date[full_date]`, enabling correct time-intelligence measures
7. Multi-page report built with cross-filtering slicers, including a dedicated Denial Analysis page pairing point-in-time and rolling denial rate measures
8. Report published to HealthcarePractice Fabric workspace
9. **(Week 5 Monday)** Fabric Data Pipeline `HC_Load_Claims_Incremental` built to append new/changed claims from Azure SQL into the Lakehouse `claims` table; verified end-to-end by confirming a pipeline run produces a visible, traceable shift in this report's Total Claims and Denied counts on refresh
10. **(Week 5 Monday)** Report's data source repointed from Azure SQL Database directly to the `HealthcarePractice_Lakehouse` SQL analytics endpoint, so the report reflects pipeline-loaded data rather than bypassing the Lakehouse entirely
11. **(Week 5 Monday)** `Denial Category` (SWITCH) and `Provider Rank by Billed Amount` (RANKX) measures added; RANKX paired with a live filter-context demonstration (`filter_context_demo.PNG`) to validate the measure's behavior under different slicer states before considering it done
12. **(Week 5 Tuesday)** `Denial Rate %` refactored to `VAR`/`RETURN` for readability and safe division; output validated unchanged before and after
13. **(Week 5 Thursday)** `Denial Rate % of Total` (`ALL`) measure added; two live Lakehouse data-quality issues (stale `payer` names, duplicate `claim_id 1319` rows) found and fixed via PySpark ahead of publish; first curated Power BI App published from the workspace

---

## Note on Payer Names

Payer names shown throughout both reports (e.g., "Meridian Health Plan," "Harborview Insurance," "Federal Senior Care Program") are entirely fictional labels used for realistic sample data. Earlier versions of this data used real healthcare company names as placeholder labels; these were replaced to avoid any impression that the fabricated denial rates, claim volumes, or dollar figures in this portfolio reflect the actual performance of any real company or government program.

**Note (Week 5 Thursday):** the scrub described above was applied to the Azure SQL source but had not propagated to the Lakehouse copy of `payer`, which silently retained the original real company names until a routine refresh surfaced the mismatch. See the Data Quality subsection above for the fix — flagged here as a reminder that a data-quality correction made at one layer of a multi-copy architecture (Azure SQL → Lakehouse → Warehouse) isn't automatically reflected everywhere else without an explicit re-sync.
