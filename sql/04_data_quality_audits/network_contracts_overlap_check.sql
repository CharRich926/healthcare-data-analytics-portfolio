SELECT 
    nc1.provider_id,
    nc1.start_date as contract_nc1_start,
    nc1.end_date as contract_nc1_end,
    nc2.start_date as contract_nc2_start,
    nc2.end_date as contract_nc2_end
FROM network_contracts nc1
JOIN network_contracts nc2
    ON nc1.provider_id = nc2.provider_id
    AND nc1.contract_id < nc2.contract_id
WHERE nc1.start_date <= ISNULL(nc2.end_date, '9999-12-31')
    AND nc2.start_date <= ISNULL(nc2.end_date, '9999-12-31');