# Power Automate — Automated Flows

## Overview

Five cloud flows built in Microsoft Power Automate to automate operational notifications, dataset refresh, and threshold-based alerting for the HealthcarePractice analytics environment. The flows cover five trigger/action patterns: event-driven (file arrival), scheduled (time-based), API-triggered (Power BI refresh), manually-triggered threshold alerting against a live Azure SQL source, and a scheduled Fabric-adjacent refresh flow. All flows authenticate via standard OneDrive and Outlook.com connectors using a personal Microsoft account.

---

## Flows

### Flow 1 — HC_NewClaims_File_Trigger

| Property | Value |
|---|---|
| Trigger | File created in OneDrive folder |
| Action | Send email via Outlook.com |
| Connector | OneDrive (standard) + Outlook.com |
| Dynamic content | File Name token in email body |

**What it does:** When a new claims file lands in the designated OneDrive folder, the flow fires automatically and sends an Outlook.com email notification containing the dynamic filename. This is the no-code equivalent of an SSIS file watcher (`SCR_CheckFileExists` Script Task) — event-driven pipeline triggering without server infrastructure.

**Interview talking point:** Demonstrates event-driven automation — the same architectural pattern as SSIS file watchers, implemented without code or a dedicated server.

---

### Flow 2 — HC_Weekly_Claims_Summary

| Property | Value |
|---|---|
| Trigger | Recurrence — every Monday |
| Action | Send email via Outlook.com |
| Connector | Outlook.com |
| Dynamic content | `formatDateTime(utcNow(), 'MM/dd/yyyy')` in subject line |

**What it does:** Every Monday the flow sends a scheduled claims summary email with a dynamically generated date in the subject line. The `formatDateTime()` expression produces the current date at trigger time — no manual date entry required. This is the no-code equivalent of a SQL Agent scheduled job.

**Interview talking point:** Demonstrates scheduled automation and Power Automate expression language — `formatDateTime(utcNow(), 'MM/dd/yyyy')` is the equivalent of `GETDATE()` in T-SQL, evaluated at runtime.

---

### Flow 3 — HC_Refresh_PowerBI_Dataset

| Property | Value |
|---|---|
| Trigger | Recurrence — daily at 7:00 AM |
| Action | Refresh a Power BI dataset |
| Connector | Power BI |
| Dataset | HealthcarePractice_SemanticModel |

**What it does:** Every morning at 7AM the flow triggers a refresh of the `HealthcarePractice_SemanticModel` in Power BI, ensuring stakeholders always see current data when they open the report. Sequenced to run one hour after the Databricks Job (6AM) so the semantic model reflects the latest data load.

**Interview talking point:** Demonstrates pipeline sequencing — Databricks at 6AM loads the data, Power BI refreshes at 7AM, stakeholders see current numbers without any manual intervention.

---

### Flow 4 — HC_HighDollarClaims_Alert

| Property | Value |
|---|---|
| Trigger | Manual (for testing) |
| Action | Get rows (V2) from Azure SQL with OData filter; send email via Outlook.com |
| Connector | SQL Server (Azure SQL) + Outlook.com |
| Filter | `billed_amount gt 10000` (server-side OData filter) |
| Known limitation | "Get rows (V2)" requires a Power Automate Premium license, not available on the trial tenant — flow is built and documented but not executable in this environment |

**What it does:** Queries `dbo.claims` in Azure SQL directly, filtering server-side for high-dollar claims (billed_amount > $10,000), and sends an Outlook.com email summarizing the results. Originally scoped as a denial-count threshold alert per the Week 3 plan; built instead as a high-dollar claims alert, since it demonstrates the same threshold-based alerting pattern with server-side filtering — arguably a stronger interview example, since the `gt 10000` filter runs in the query itself rather than being evaluated after retrieval.

**Interview talking point:** Demonstrates server-side OData filtering against a live SQL data source from within a low-code tool — the filter reduces data transferred rather than filtering after the fact, the same principle as pushing a `WHERE` clause to the database instead of filtering in application code.

**Known limitation, documented rather than worked around:** The "Get rows (V2)" action requires a Premium connector tier unavailable on this M365 trial tenant. The flow saves successfully and is fully configured, but can't be test-executed in this environment. Documented as a known constraint rather than an unresolved bug.

---

### Flow 5 — HC_Nightly_Pipeline_Refresh (Week 5 Tuesday)

| Property | Value |
|---|---|
| Trigger | Recurrence — every 1 day, starting 7/16/26 at 2:00 AM |
| Action 1 | Power BI — Refresh a dataset (Workspace: HealthcarePractice, Dataset: HealthcarePractice) |
| Action 2 | Outlook.com — Send an email (V2), two recipients, confirmation + limitation note in body |

**What it does:** A nightly recurrence flow intended to sit ahead of the day's Fabric pipeline/dashboard work, refreshing the `HealthcarePractice` semantic model and emailing a confirmation.

**Key finding — Power Automate has no native connector for triggering a Fabric Data Pipeline.** Searched "Fabric" in the connector list (zero results) and exhausted the full Power BI connector list — only dataset/report/scorecard-level actions exist (Refresh a dataset, Add rows to a dataset, Export To File, etc.), nothing that invokes a Fabric Data Pipeline directly. Also checked whether the newly released Fabric Apps (Preview) workload filled this gap — confirmed it does not; Fabric Apps is a separate TypeScript/GraphQL app-building platform (Rayfin SDK) for custom backend/frontend apps on Fabric data, unrelated to pipeline orchestration.

**Scope decision:** the flow refreshes the Power BI dataset directly rather than invoking the pipeline itself, since there's no connector path to do the latter. This limitation is documented in the flow's own email body, not just in session notes — the constraint travels with the artifact itself, not just with whoever built it.

**Troubleshooting notes:**
- SSMS connection to the Warehouse SQL endpoint required **Azure AD - Universal with MFA** authentication, not SQL Server Authentication (Fabric SQL endpoints have no SQL logins).
- Warehouse and Lakehouse are two databases on the same Fabric SQL server — one registered server connection, not two.
- Outlook.com OAuth connection failed on first attempt ("Unauthorized") — resolved on retry; a transient token issue, not a real permissions problem.
- The **To** field for Send an email (V2) auto-tokenizes multiple addresses and visually displays them space-separated, but stores them semicolon-delimited under the hood — confirmed via Code view raw inputs.
- Test run succeeded end-to-end (all 3 steps green, HTTP 200 on send). Delivered cleanly to Gmail; flagged as spam by Yahoo on first send — expected behavior for a brand-new automated sender, not a flow defect.

**Interview talking point:** A genuine platform-boundary discovery, documented rather than silently worked around — knowing what a tool *can't* do, and building the workaround transparently into the artifact itself, is a stronger signal than a flow that happens to work with the limitation hidden.

---

## Pipeline Sequencing

```
2:00 AM — Power Automate Flow 5 (HC_Nightly_Pipeline_Refresh) refreshes the semantic model
6:00 AM — Databricks Job (HC_WeeklyClaims_DataLoad) runs
           ↓ loads latest claims data to Delta table
7:00 AM — Power Automate Flow 3 (HC_Refresh_PowerBI_Dataset) fires
           ↓ refreshes HealthcarePractice_SemanticModel
7:30 AM — Stakeholders open Power BI reports
           ↓ see current data from this morning's load
```

---

## Trigger Pattern Summary

| Flow | Trigger Type | No-Code Equivalent Of |
|---|---|---|
| HC_NewClaims_File_Trigger | Event-driven — file arrival | SSIS file watcher / SCR_CheckFileExists |
| HC_Weekly_Claims_Summary | Scheduled — every Monday | SQL Agent scheduled job |
| HC_Refresh_PowerBI_Dataset | Scheduled — daily 7AM | SQL Agent scheduled job + API call |
| HC_HighDollarClaims_Alert | Manual (threshold-based alerting pattern) | Stored procedure + conditional alerting logic |
| HC_Nightly_Pipeline_Refresh | Scheduled — daily 2AM | SQL Agent job (dataset-level refresh only — no orchestration-layer equivalent exists in Power Automate for Fabric pipelines) |

---

## Environment Notes

- **Connector limitation:** OneDrive for Business and Office 365 Outlook connectors are not fully provisioned on M365 trial tenants. All flows use the standard **OneDrive** connector and **Outlook.com** connector authenticated via a personal Yahoo-linked Microsoft account.
- **Root cause of OAuth failures during build:** Third-party cookies were blocked in Chrome, preventing the OAuth popup from completing. Enabling third-party cookies resolved all connection issues.
- **Premium connector limitation (Flow 4):** The "Get rows (V2)" SQL Server action requires a Power Automate Premium license, not included on the trial tenant. Flow 4 is fully built and configured but cannot be test-executed in this environment — documented as a known limitation rather than worked around.
- **Orchestration limitation (Flow 5):** Power Automate has no native connector for triggering a Fabric Data Pipeline as of this build — only dataset/report/scorecard-level Power BI actions are available. Flow 5 refreshes the semantic model directly instead, with the limitation documented in the flow itself.
- **Lesson learned:** Always verify connector provisioning and licensing tier on trial tenants before building flows — premium/enterprise connectors and actions behave differently from personal/standard connectors, and some premium actions can be configured and saved successfully even when they can't actually run. Similarly, not every orchestration need has a corresponding connector — worth confirming platform capability before assuming a missing feature is a configuration gap.

---

## Screenshots

| File | Description |
|---|---|
| `PowerAutomate_Cloud_Flows.png` | All flows visible in the Power Automate portal |
| `PowerAutomate_HC_NewClaims_File_Trigger.png` | Flow 1 — OneDrive trigger + email action |
| `PowerAutomate_HC_Weekly_Claims_Summary.png` | Flow 2 — Monday recurrence + formatDateTime expression |
| `PowerAutomate_Power_BI_Refresh.png` | Flow 3 — Daily 7AM recurrence + Power BI refresh action |
| `PowerAutomate_HighDollar_GetClaims.png` | Flow 4 — Get rows (V2) action with OData filter (billed_amount gt 10000) |
| `PowerAutomate_HighDollar_SendEmail.png` | Flow 4 — Email action with dynamic content from filtered claims |
| `PowerAutomate_HC_Nightly_Pipeline_Refresh.png` | Flow 5 — Recurrence trigger, dataset refresh, and confirmation email (Week 5 Tuesday) |

---

## Stack

`Power Automate` `OneDrive Connector` `Outlook.com Connector` `Power BI Connector` `SQL Server Connector` `OData Filtering` `formatDateTime()` `Recurrence Trigger` `Event Trigger` `Microsoft Power Platform`
