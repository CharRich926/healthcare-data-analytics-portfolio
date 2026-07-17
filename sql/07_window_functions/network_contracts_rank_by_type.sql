-- network_contracts_rank_by_type.sql
-- Rank each contract's rate_modifier within its contract_type
-- First use of network_contracts for window-function ranking (Week 5 Monday)
-- Demonstrates RANK vs DENSE_RANK syntax (no ties in current data,
-- but partition logic is the interview-relevant part)

SELECT
    contract_id,
    provider_id,
    contract_type,
    rate_modifier,
    RANK() OVER (PARTITION BY contract_type ORDER BY rate_modifier DESC) AS rate_modifier_rank,
    DENSE_RANK() OVER (PARTITION BY contract_type ORDER BY rate_modifier DESC) AS rate_modifier_dense_rank
FROM network_contracts
ORDER BY contract_type, rate_modifier_rank;
