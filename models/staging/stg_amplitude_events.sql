with source as (
    select *
    from {{ source('public', 'AMPLITUDE_EVENTS') }}
),

renamed as (
    select
        nullif(trim(cast(event_id as varchar)), '') as event_id,
        nullif(trim(cast(event_type as varchar)), '') as event_type,
        cast(event_time as timestamp_ntz) as event_time,
        nullif(trim(cast(user_id as varchar)), '') as user_id,
        nullif(trim(cast(device_id as varchar)), '') as device_id,
        nullif(trim(cast(platform as varchar)), '') as platform,
        nullif(trim(cast(event_source as varchar)), '') as event_source,
        upper(trim(product)) as product,
        nullif(trim(cast(event_properties as varchar)), '') as event_properties,
        nullif(trim(cast(user_property_company as varchar)), '') as user_property_company,
        nullif(trim(cast(user_property_plan as varchar)), '') as user_property_plan,
        nullif(trim(cast(user_property_tier as varchar)), '') as user_property_tier,
        cast(session_id as number) as session_id,
        nullif(trim(cast(country as varchar)), '') as country,
        nullif(trim(cast(region as varchar)), '') as region

        -- DATA QUALITY: addon_name/product normalized to uppercase to prevent
        -- duplicate groupings from casing inconsistencies across sources
        -- DATA QUALITY: event_properties appears to be a JSON-like blob stored as text; keep raw in staging.
        -- ASSUMPTION: JSON parsing and schema enforcement for event_properties belongs in intermediate models.
    from source
)

select *
from renamed
