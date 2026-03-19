with source as (
    select *
    from {{ source('public', 'MARKETPLACE_LICENSES') }}
),

renamed as (
    select
        nullif(trim(cast(addon_license_id as varchar)), '') as addon_license_id,
        nullif(trim(cast(license_id as varchar)), '') as license_id,
        nullif(trim(cast(app_entitlement_number as varchar)), '') as app_entitlement_number,
        nullif(trim(cast(host_license_id as varchar)), '') as host_license_id,
        nullif(trim(cast(host_entitlement_number as varchar)), '') as host_entitlement_number,
        nullif(trim(cast(cloud_id as varchar)), '') as cloud_id,
        nullif(trim(cast(cloud_site_hostname as varchar)), '') as cloud_site_hostname,
        nullif(trim(cast(addon_key as varchar)), '') as addon_key,
        nullif(trim(cast(addon_name as varchar)), '') as addon_name,
        nullif(trim(cast(hosting as varchar)), '') as hosting,
        cast(last_updated as date) as last_updated,
        nullif(trim(cast(license_type as varchar)), '') as license_type,
        cast(maintenance_start_date as date) as maintenance_start_date,
        cast(maintenance_end_date as date) as maintenance_end_date,
        nullif(trim(cast(status as varchar)), '') as status,
        nullif(trim(cast(tier as varchar)), '') as tier,
        nullif(trim(cast(company as varchar)), '') as company,
        nullif(trim(cast(country as varchar)), '') as country,
        nullif(trim(cast(region as varchar)), '') as region,
        nullif(trim(cast(tech_contact_email as varchar)), '') as tech_contact_email,
        nullif(trim(cast(tech_contact_name as varchar)), '') as tech_contact_name,
        nullif(trim(cast(evaluation_opportunity_size as varchar)), '') as evaluation_opportunity_size,
        nullif(trim(cast(evaluation_license as varchar)), '') as evaluation_license_id,
        cast(days_to_convert_eval as number) as days_to_convert_eval,
        cast(evaluation_start_date as date) as evaluation_start_date,
        cast(evaluation_end_date as date) as evaluation_end_date,
        cast(evaluation_sale_date as date) as evaluation_sale_date,
        nullif(trim(cast(channel as varchar)), '') as channel,
        nullif(trim(cast(campaign_name as varchar)), '') as campaign_name,
        nullif(trim(cast(campaign_source as varchar)), '') as campaign_source,
        nullif(trim(cast(campaign_medium as varchar)), '') as campaign_medium,
        nullif(trim(cast(campaign_content as varchar)), '') as campaign_content,
        nullif(trim(cast(referrer_domain as varchar)), '') as referrer_domain

        -- DATA QUALITY: evaluation_opportunity_size is typed as text and may represent numeric/categorical tiers; validate distinct values downstream.
        -- DATA QUALITY: column name implied boolean but values are license ID references (e.g. 100884, 100242)
        -- ASSUMPTION: treating as FK to originating evaluation license record, renamed to evaluation_license_id for clarity
        -- ASSUMPTION: addon_license_id is standardized to varchar to align join keys with marketplace transactions staging.
    from source
)

select *
from renamed
