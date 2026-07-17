# Claims Near-Duplicate Investigation

## Summary
A self-join screening query flagged 77 pairs of same-member claims with service
dates within 7 days of each other (~14% of all 555 claims). This investigation
breaks down whether these pairs represent genuine duplicate billing or expected
patterns of care.

## Method
Query: `sql/04_data_quality_audits/claims_near_duplicate_self_join.sql`

Three-part screening:
1. Self-join on `member_id`, filtered to claim pairs with `service_date` within
   7 days of each other (`c1.claim_id < c2.claim_id` avoids duplicate/self pairs)
2. Breakdown by whether the pair shares the same `provider_id`
3. Detail view of same-provider pairs only, including billed amounts

## Findings

| Category | Pair Count | % of Total |
|---|---|---|
| Different provider | 72 | 93.5% |
| Same provider | 5 | 6.5% |

**Different-provider pairs (72):** Consistent with normal multi-provider care —
a member seeing more than one provider within a short window is expected
behavior, not a data quality issue.

**Same-provider pairs (5):** The group actually worth scrutiny, since matching
provider plus a close service date is the stronger duplicate-billing signal.
None of the 5 pairs show matching or near-identical billed amounts (closest
was ~$153 apart), ruling out exact duplicate billing.

One pair worth naming specifically: claims 176/181 (member 8, provider 18)
share the *same* service date and provider but different billed amounts
($2,899.48 vs $9,153.82). Most consistent with two distinct services billed
separately during the same visit rather than an erroneous duplicate.

## Conclusion
No true duplicate claims were identified in this dataset. The self-join
screening pattern served its intended purpose as a triage tool — narrowing
555 claims down to 5 pairs worth manual review, rather than functioning as a
duplicate list itself.
