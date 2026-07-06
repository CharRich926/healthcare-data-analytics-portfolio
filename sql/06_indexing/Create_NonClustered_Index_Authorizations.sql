CREATE NONCLUSTERED INDEX IX_Authorizations_ProviderID
ON dbo.authorizations (provider_id)
INCLUDE (requested_date, decision_date);