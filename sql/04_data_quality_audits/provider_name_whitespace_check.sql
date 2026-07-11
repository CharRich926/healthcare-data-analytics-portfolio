SELECT
    provider_id,
    provider_name,
    UPPER(TRIM(provider_name)) AS cleaned_name,
    LEN(provider_name) AS original_length,
    LEN(TRIM(provider_name)) AS trimmed_length
FROM providers
WHERE LEN(provider_name) <> LEN(TRIM(provider_name));