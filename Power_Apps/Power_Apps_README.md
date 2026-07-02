# Power Apps — HC_ClaimLookup

## Overview

HC_ClaimLookup is a Canvas App built in Microsoft Power Apps that provides real-time claim status lookup against the HealthcarePractice Azure SQL Database. A user enters a Claim ID or Member ID (via a toggle), the app queries the claims table directly, and returns matching claim status and billed amount instantly — no report refresh, no SQL access required.

This app demonstrates the Power Platform pattern of giving business users self-service access to operational data through a no-code interface backed by a live cloud database. The search mode toggle and input validation added in this enhancement pass also demonstrate handling a one-to-many data relationship (one member can have multiple claims) and defensive UX patterns (blank input handling, empty-result messaging).

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

1. User selects search mode via the `toggleSearchMode` toggle — Claim ID (default) or Member ID
2. User enters a value in the text input box (hint text updates dynamically based on toggle state)
3. User clicks **Search**
4. The `OnSelect` formula first checks for a blank input — if blank, an error message displays and no query runs
5. If a value is present, `ClearCollect` + `Filter` queries the `claims` table on either `claim_id` or `member_id`, depending on toggle state
6. If zero rows are returned, an error message displays ("No matching claim found.")
7. If rows are returned, the Gallery displays each result: **ID | Status | Billed Amount** — Member ID searches can return multiple rows, since one member may have several claims

### Core Formula (Search Button OnSelect)
```
If(
    IsBlank(txtClaimID.Text),
    UpdateContext({showError: true, errorMsg: "Please enter a search value."}),
    ClearCollect(
        ClaimResults,
        If(
            toggleSearchMode.Value,
            Filter(claims, member_id = Value(txtClaimID.Text)),
            Filter(claims, claim_id = Value(txtClaimID.Text))
        )
    );
    If(
        CountRows(ClaimResults) = 0,
        UpdateContext({showError: true, errorMsg: "No matching claim found."}),
        UpdateContext({showError: false, errorMsg: ""})
    )
)
```

### Toggle Label Formulas
```
TrueText:  "Search by Member ID"
FalseText: "Search by Claim ID"
```

### Dynamic Hint Text (txtClaimID)
```
If(toggleSearchMode.Value, "Enter Member ID", "Enter Claim ID")
```

### Error Label Formulas (lblError)
```
Text:    errorMsg
Visible: showError
Color:   RGBA(255, 0, 0, 1)
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
| `toggleSearchMode` | Toggle | Switches search mode between Claim ID and Member ID |
| `txtClaimID` | Text Input | User enters the claim ID or member ID to search (hint text updates dynamically) |
| `btnSearch` | Button | Triggers validation, ClearCollect filter query, and empty-result check |
| `lblError` | Label | Displays validation and no-match error messages (red text, conditionally visible) |
| `galClaimResults` | Vertical Gallery | Displays matching claim records — supports multiple rows for Member ID searches |

---

## Screenshots

| Screenshot | Description |
|---|---|
| `PowerApps_HC_ClaimLookup_ClaimID_Result.png` | Search by Claim ID mode returning a single result |
| `PowerApps_HC_ClaimLookup_MemberID_MultiResult.png` | Search by Member ID mode returning multiple claims for one member |
| `PowerApps_HC_ClaimLookup_BlankValidation.png` | Error message shown when search is submitted with a blank input |
| `PowerApps_HC_ClaimLookup_NoMatchError.png` | Error message shown when no matching record is found |

---

## Verified Results

**Claim ID search:**

| Claim ID | Status | Billed Amount |
|---|---|---|
| 2 | Approved | $180.00 |
| 3 | Denied | $1,200.00 |
| 5 | Denied | $1,200.00 |

**Member ID search (member_id = 5, returns multiple claims):**

| Claim Status | Billed Amount |
|---|---|
| Approved | $250.00 |
| Approved | $250.00 |
| Approved | $778.19 |
| Approved | $6,321.98 |
| Denied | $6,274.02 |

**Error handling:**

| Scenario | Result |
|---|---|
| Blank input submitted | "Please enter a search value." |
| No matching record (e.g. member_id 9999) | "No matching claim found." |

---

## Interview Talking Points

- **Pattern demonstrated:** Input → Filter formula → Gallery display. This is the core Power Apps canvas app pattern used across most business lookup and data entry apps.
- **No-code data access:** Business users can look up claim status without SQL access, Power BI access, or report refresh cycles.
- **Live connection:** The app connects directly to Azure SQL via the SQL Server connector — results reflect the current state of the database at query time.
- **One-to-many relationship handling:** The Member ID search mode demonstrates that a single member can have multiple claims — the Gallery renders all matching rows, not just one, which is a more realistic pattern than a strict 1:1 lookup.
- **Input validation and error states:** The app checks for blank input before querying and distinguishes between "no input" and "no matching record" with separate, specific error messages — a defensive UX pattern that prevents wasted queries and gives users clear feedback.
- **Record shape consistency in Power Fx:** Building the error-handling logic required keeping the `UpdateContext()` record shape consistent across all branches of the `If()` — mismatched fields between branches (e.g. one branch setting `errorMsg` and another omitting it) throws a type error. A small but real language-level nuance a developer needs to know when working in Power Fx.
- **Power Platform fit:** This app is one component of a broader Power Platform implementation that includes Power BI dashboards, Power Automate flows for alerts and notifications, and this Canvas App for operational self-service.

---

## Stack

`Power Apps` `Canvas App` `Azure SQL Database` `SQL Server Connector` `ClearCollect` `Filter` `Power Platform`
