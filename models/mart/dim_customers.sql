-- Presentation-ready customer dimension. One row per company + product.
-- Source of truth for customer identity across all fact models.
-- See int_customer_entity for entity resolution logic and match_type documentation.

with source as (
    select * from {{ ref('int_customer_entity') }}
)

select
    company,
    addon_name,
    cloud_id,
    cloud_site_hostname,
    tech_contact_email,
    status,
    license_type,
    tier,
    hosting,
    distinct_users,
    total_events,
    first_seen,
    last_seen,
    match_type
from source
