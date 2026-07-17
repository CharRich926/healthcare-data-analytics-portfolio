SELECT
	c1.claim_id AS claim_id_1,
	c2.claim_id AS claim_id_2,
	c1.member_id,
	c1.service_date AS service_date_1,
	c2.service_date AS service_date_2,
	ABS(DATEDIFF(day, c1.service_date, c2.service_date)) AS days_apart,
	c1.provider_id AS provider_id_1,
	c2.provider_id AS provider_id_2,
	c1.billed_amount as billed_amount_1,
	c2.billed_amount AS billed_amount_2
FROM claims c1
JOIN claims c2
	ON c1.member_id = c2.member_id
	AND c1.claim_id < c2.claim_id
	AND ABS(DATEDIFF(day, c1.service_date, c2.service_date)) <= 7
ORDER BY c1.member_id, days_apart;

SELECT
	CASE WHEN c1.provider_id = c2.provider_id THEN 'Same Provider' ELSE 'Different Provider' END AS provider_match,
	COUNT(*) AS pair_count
FROM claims c1
JOIN claims c2
	ON c1.member_id = c2.member_id
	AND c1.claim_id < c2.claim_id
	AND ABS(DATEDIFF(day, c1.service_date, c2.service_date)) <= 7
GROUP BY CASE WHEN c1.provider_id = c2.provider_id THEN 'Same Provider' ELSE 'Different Provider' END;

SELECT
    c1.claim_id AS claim_id_1,
    c2.claim_id AS claim_id_2,
    c1.member_id,
    c1.provider_id,
    c1.service_date AS service_date_1,
    c2.service_date AS service_date_2,
    ABS(DATEDIFF(day, c1.service_date, c2.service_date)) AS days_apart,
    c1.billed_amount AS billed_amount_1,
    c2.billed_amount AS billed_amount_2
FROM claims c1
JOIN claims c2
    ON c1.member_id = c2.member_id
    AND c1.claim_id < c2.claim_id
    AND c1.provider_id = c2.provider_id
    AND ABS(DATEDIFF(day, c1.service_date, c2.service_date)) <= 7
ORDER BY c1.member_id;