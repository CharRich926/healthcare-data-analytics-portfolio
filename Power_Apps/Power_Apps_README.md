# Power Apps — HC_ClaimLookup

## Overview

HC_ClaimLookup is a Canvas App built in Microsoft Power Apps that provides real-time claim status lookup against the HealthcarePractice Azure SQL Database. A user enters a Claim ID, the app queries the claims table directly, and returns the claim status and billed amount instantly — no report refresh, no SQL access required.

This app demonstrates the Power Platform pattern of giving business users self-service access to operational data through a no-code interface backed by a live cloud database.

---

## App Details

| Property | Value |
|---|---|
| App name | HC_ClaimLookup |
| App type | Canvas App — Tablet layout |
| Data source | Azure SQL Database (HealthcarePractice) |
| Connection type | SQL Server Authentication — Connect directly (cloud services) |
| Tables connected | `dbo.claims`, `dbo.members` |
| Environment | Power Apps Default Directory |

---

## How It Works

1. User enters a Claim ID in the text input box
2. User clicks **Search**
3. The `ClearCollect` + `Filter` formula queries the `claims` table for the matching claim ID
4. The Gallery displays the result: **Claim ID | Status | Billed Amount**

### Core Formula (Search Button OnSelect)
```
ClearCollect(
    ClaimResults,
    Filter(claims, claim_id = Value(txtClaimID.Text))
)
```

### Gallery Subtitle Formula
```
ThisItem.claim_status & " | $" & Text(ThisItem.billed_amount, "###,##0.00")
```

---

## Controls

| Control | Type | Purpose |
|---|---|---|
| `lblHeader` | Label | App title — "HC Claim Lookup" |
| `txtClaimID` | Text Input | User enters the claim ID to search |
| `btnSearch` | Button | Triggers ClearCollect filter query |
| `galClaimResults` | Vertical Gallery | Displays matching claim records |

---

## Screenshots

| Screenshot | Description |
|---|---|
| `PowerApps_HC_ClaimLookup_Approved.png` | Search result for an Approved claim |
| `PowerApps_HC_ClaimLookup_Denied.png` | Search result for a Denied claim |
| `PowerApps_HC_ClaimLookup_Approved_BilledAmount.png` | Approved claim with billed amount displayed |
| `PowerApps_HC_ClaimLookup_Denied_BilledAmount.png` | Denied claim with billed amount displayed |

---

## Verified Results

| Claim ID | Status | Billed Amount |
|---|---|---|
| 2 | Approved | $180.00 |
| 5 | Denied | $1,200.00 |

---

## Interview Talking Points

- **Pattern demonstrated:** Input → Filter formula → Gallery display. This is the core Power Apps canvas app pattern used across most business lookup and data entry apps.
- **No-code data access:** Business users can look up claim status without SQL access, Power BI access, or report refresh cycles.
- **Live connection:** The app connects directly to Azure SQL via the SQL Server connector — results reflect the current state of the database at query time.
- **Power Platform fit:** This app is one component of a broader Power Platform implementation that includes Power BI dashboards, Power Automate flows for alerts and notifications, and this Canvas App for operational self-service.

---

## Stack

`Power Apps` `Canvas App` `Azure SQL Database` `SQL Server Connector` `ClearCollect` `Filter` `Power Platform`
