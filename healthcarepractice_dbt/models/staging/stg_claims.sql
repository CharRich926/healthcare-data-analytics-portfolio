select
    claim_id,
    member_id,
    provider_id,
    claim_status,
    billed_amount
from {{ source('healthcarepractice', 'claims') }}
