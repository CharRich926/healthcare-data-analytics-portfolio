## Data Quality Investigation: `claims.denial_reason` NULL Rate

**Date:** Week 4 Thursday
**Trigger:** 81.34% NULL rate on `claims.denial_reason` surfaced during Week 3's broader NULL audit, flagged for follow-up rather than investigated at the time.

### Question
Is the high NULL rate a genuine data quality gap, or expected behavior given the column's purpose?

### Method

**Step 1 — Baseline breakdown by claim_status:**

```sql
SELECT
    claim_status,
    COUNT(*) AS total_claims,
    SUM(CASE WHEN denial_reason IS NULL THEN 1 ELSE 0 END) AS null_denial_reason,
    SUM(CASE WHEN denial_reason IS NOT NULL THEN 1 ELSE 0 END) AS has_denial_reason
FROM claims
GROUP BY claim_status
ORDER BY claim_status;
```

| claim_status | total_claims | null_denial_reason | has_denial_reason |
|---|---|---|---|
| Approved | 395 | 394 | 1 |
| Denied | 102 | 0 | 102 |
| Pending | 55 | 55 | 0 |

**Step 2 — Check for Denied claims missing a reason (the true data-quality risk):**

```sql
SELECT COUNT(*) AS denied_but_missing_reason
FROM claims
WHERE claim_status = 'Denied' AND denial_reason IS NULL;
```

Result: **0**. Every Denied claim has a reason populated — no gap on that front.

**Step 3 — Check the flip side: any non-Denied claim with a reason populated?**

```sql
SELECT claim_id, provider_id, claim_status, denial_reason, billed_amount
FROM claims
WHERE claim_status = 'Approved' AND denial_reason IS NOT NULL;
```

Result: **1 row** — `claim_id 14`, provider 6, Approved, billed_amount $5,200.00, `denial_reason = "Billed amount corrected"`.

### Finding

The 81.34% NULL rate is **structurally expected**, not a genuine gap — Pending claims (not yet adjudicated) and the vast majority of Approved claims correctly have no denial reason.

However, one Approved claim (claim_id 14) has `denial_reason` populated with text unrelated to denial ("Billed amount corrected"). This reveals that `denial_reason` is not a strictly single-purpose field — it appears to double as a general adjustment/note field, populated in at least one case for a non-denial billing correction rather than an actual denial explanation.

### Implication

Any analysis that treats `denial_reason IS NOT NULL` as synonymous with "this claim was denied" is technically fragile — this one row would be miscounted. In a production schema, denial explanations and general claim adjustment notes should live in separate columns (e.g., `denial_reason` reserved exclusively for Denied claims, with a distinct `adjustment_note` or `claim_note` field for corrections/annotations on claims of any status) to keep denial-rate and denial-reason reporting reliable.
