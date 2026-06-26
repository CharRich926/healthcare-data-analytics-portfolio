# Power Automate — Automated Flows

## Overview

Three cloud flows built in Microsoft Power Automate to automate operational notifications and dataset refresh for the HealthcarePractice analytics environment. The flows cover three trigger patterns: event-driven (file arrival), scheduled (time-based), and API-triggered (Power BI refresh). All flows authenticate via standard OneDrive and Outlook.com connectors using a personal Microsoft account.

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

## Pipeline Sequencing

```
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

---

## Environment Notes

- **Connector limitation:** OneDrive for Business and Office 365 Outlook connectors are not fully provisioned on M365 trial tenants. All three flows use the standard **OneDrive** connector and **Outlook.com** connector authenticated via a personal Yahoo-linked Microsoft account.
- **Root cause of OAuth failures during build:** Third-party cookies were blocked in Chrome, preventing the OAuth popup from completing. Enabling third-party cookies resolved all connection issues.
- **Lesson learned:** Always verify connector provisioning on trial tenants before building flows — the premium/enterprise connectors behave differently from personal connectors.

---

## Screenshots

| File | Description |
|---|---|
| `PowerAutomate_Cloud_Flows.png` | All 3 flows visible in the Power Automate portal |
| `PowerAutomate_HC_NewClaims_File_Trigger.png` | Flow 1 — OneDrive trigger + email action |
| `PowerAutomate_HC_Weekly_Claims_Summary.png` | Flow 2 — Monday recurrence + formatDateTime expression |
| `PowerAutomate_Power_BI_Refresh.png` | Flow 3 — Daily 7AM recurrence + Power BI refresh action |

---

## Stack

`Power Automate` `OneDrive Connector` `Outlook.com Connector` `Power BI Connector` `formatDateTime()` `Recurrence Trigger` `Event Trigger` `Microsoft Power Platform`
