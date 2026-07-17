# Fabric Warehouse vs. Lakehouse SQL Endpoint — Comparison Note

**Date:** Week 4 Wednesday
**Purpose:** Deferred from Tuesday's plan — run the same query against both HealthcarePractice_Warehouse and the Lakehouse SQL analytics endpoint, note behavior differences.

## Test Query

```sql
SELECT provider_id, COUNT(*) AS claim_count, AVG(billed_amount) AS avg_billed
FROM dbo.claims
GROUP BY provider_id
ORDER BY provider_id;
```

## Results

| | Warehouse | Lakehouse SQL Endpoint |
|---|---|---|
| Rows returned | 20 | 20 |
| Values (provider_id, claim_count, avg_billed) | Match | Match |
| Execution time | 5.966s | 2.258s |
| URL path | `/warehouses/` | `/mirroredwarehouses/` |

Data was identical across every row checked — same claim counts and average billed amounts per provider. No drift between the two engines for this dataset.

## Key Observations

- **Lakehouse SQL endpoint is technically a mirrored warehouse layer over Delta tables**, not a native warehouse compute engine. The URL path (`mirroredwarehouses`) reflects this — it's a read-only SQL surface on top of the Lakehouse's underlying files, not a first-class warehouse.
- **Warehouse supports full T-SQL read/write**; the Lakehouse SQL endpoint is read-only (writes there happen via Spark/notebooks or pipelines, not direct T-SQL).
- **Speed**: Lakehouse endpoint ran faster on this single test (2.258s vs. 5.966s). Not treating this as a definitive performance conclusion — single-run timing can be affected by caching or cold start on either side. Worth re-testing if a real performance comparison is ever needed.
- **Practical takeaway**: for this portfolio, both surfaces returned consistent results, confirming the pipeline-loaded data is accurate in both destinations. The meaningful architectural difference is read/write capability, not raw query results.
