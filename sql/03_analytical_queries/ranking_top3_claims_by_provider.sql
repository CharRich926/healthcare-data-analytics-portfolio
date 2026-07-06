-- Week 4, Monday — Ranking / Nth-value exercise
-- Top 3 claims per provider by billed_amount
SELECT 
	provider_id,
	claim_id,
	billed_amount,
	rnk
FROM (
	SELECT 
		provider_id,
		claim_id,
		billed_amount,
		RANK() OVER (PARTITION BY provider_id ORDER BY billed_amount DESC) AS rnk
	FROM dbo.claims
) ranked
WHERE rnk <=3
ORDER BY provider_id, rnk;

-- 2nd highest billed_amount overall (DENSE_RANK avoids skipping ties)
SELECT billed_amount
FROM (
	SELECT 
		billed_amount,
		DENSE_RANK() OVER (ORDER BY billed_amount DESC) AS rnk
	FROM dbo.claims
) ranked
WHERE rnk = 2;