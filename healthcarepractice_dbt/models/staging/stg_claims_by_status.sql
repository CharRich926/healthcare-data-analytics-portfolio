select
    claim_status,
    count(*) as claim_count,
    sum(billed_amount) as total_billed_amount
from {{ ref('stg_claims') }}
group by claim_status
