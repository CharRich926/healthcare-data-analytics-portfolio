# SSRS Reports

## Overview

Two working SQL Server Reporting Services reports, built in Microsoft Report Builder and connected live to the `HealthcarePractice` database. Both were built through Report Builder's Table/Matrix wizard rather than hand-authored RDL, matching the tool an analyst (rather than a dedicated report developer) would typically use day to day.

---

## Reports

### `rpt_MemberClaimsHistory.rdl`
Flat claim-level list — `claim_id`, `provider_id`, `billed_amount`, `claim_status` — pulled directly from `dbo.claims`.

### `rpt_MonthlyDenialSummary.rdl`
Provider-level denial summary: total claims, denied claims, and denied billed amount per provider, with a grand total row across all providers.

```sql
SELECT
    p.provider_name,
    COUNT(c.claim_id) AS total_claims,
    SUM(CASE WHEN c.claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denied_claims,
    SUM(CASE WHEN c.claim_status = 'DENIED' THEN c.billed_amount ELSE 0 END) AS denied_billed_amount
FROM dbo.claims c
JOIN dbo.providers p ON c.provider_id = p.provider_id
GROUP BY p.provider_name
```

Note: originally scoped as a payer-level summary, but the current `HealthcarePractice` schema has no `payer` table — pivoted to provider-level grouping, which the schema actually supports. Filename kept as-is; the report itself groups by provider, not by month.

---

## Design Notes

- **Row groups vs. Values:** every field that should be summarized per group (claim counts, dollar totals) lives in Values, not Row groups — putting a metric in Row groups causes SSRS to collapse rows that happen to share a value, which is a real, easy-to-make mistake when a metric field ends up on the wrong side of the wizard by default.
- **Grand totals:** used only where a total-across-groups is meaningful (the denial summary's provider-panel total), and deliberately omitted on the flat claims list, where a "Total" row would just be visual clutter with no analytical meaning.
- **Report Builder over Visual Studio:** both reports were built in the standalone Report Builder tool rather than a Visual Studio Reporting Services project. Report Builder is the tool an analyst/business user is expected to work in; the Visual Studio project format is aimed at dedicated report developers managing a full report catalog under source control.

---

## Stack

`SSRS` `Report Builder` `SQL Server` `T-SQL`
