-- providers_no_active_contract.sql
-- Providers with no active network contract
-- "Active" = end_date IS NULL (open-ended) OR end_date is still in the future
-- Uses NOT EXISTS per standing preference over LEFT JOIN / IS NULL

SELECT
    provider_id,
    provider_name
FROM providers
WHERE NOT EXISTS (
    SELECT 1
    FROM network_contracts
    WHERE network_contracts.provider_id = providers.provider_id
      AND (network_contracts.end_date IS NULL
           OR network_contracts.end_date >= CAST(GETDATE() AS date))
);

