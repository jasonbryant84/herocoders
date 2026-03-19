with source as (
    select
        lm.company_normalized as company,
        lm.cloud_id,
        lm.cloud_site_hostname,
        lm.tech_contact_email,
        lm.addon_name,
        lm.status,
        lm.license_type,
        lm.tier,
        lm.hosting,
        aa.distinct_users,
        aa.total_events,
        aa.first_seen,
        aa.last_seen,
        case
            when aa.company_normalized is not null then 'matched_on_company'
            else 'marketplace_only'
        end as match_type
    from (
        select
            upper(trim(company)) as company_normalized,
            cloud_id,
            cloud_site_hostname,
            tech_contact_email,
            addon_name,
            status,
            license_type,
            tier,
            hosting,
            last_updated,
            license_id,
            row_number() over (
                partition by upper(trim(company)), addon_name
                order by last_updated desc nulls last, license_id desc nulls last
            ) as company_recency_rank
        from {{ ref('stg_marketplace_licenses') }}
        where nullif(trim(company), '') is not null
    ) as lm
    left join (
        select
            upper(trim(nullif(user_property_company, ''))) as company_normalized,
            nullif(trim(product), '') as product,
            count(distinct user_id) as distinct_users,
            count(*) as total_events,
            min(event_time) as first_seen,
            max(event_time) as last_seen
        from {{ ref('stg_amplitude_events') }}
        group by 1, 2
    ) as aa
        on lm.company_normalized = aa.company_normalized
       and nullif(trim(lm.addon_name), '') = aa.product
    where lm.company_recency_rank = 1

    union all

    select
        aa.company_normalized as company,
        null as cloud_id,
        null as cloud_site_hostname,
        null as tech_contact_email,
        aa.product as addon_name,
        null as status,
        null as license_type,
        null as tier,
        null as hosting,
        aa.distinct_users,
        aa.total_events,
        aa.first_seen,
        aa.last_seen,
        'unresolved' as match_type
    from (
        select
            upper(trim(nullif(user_property_company, ''))) as company_normalized,
            nullif(trim(product), '') as product,
            count(distinct user_id) as distinct_users,
            count(*) as total_events,
            min(event_time) as first_seen,
            max(event_time) as last_seen
        from {{ ref('stg_amplitude_events') }}
        group by 1, 2
    ) as aa
    left join (
        select distinct
            upper(trim(company)) as company_normalized,
            nullif(trim(addon_name), '') as addon_name
        from {{ ref('stg_marketplace_licenses') }}
        where nullif(trim(company), '') is not null
    ) as lm_keys
        on aa.company_normalized = lm_keys.company_normalized
       and aa.product = lm_keys.addon_name
    where lm_keys.company_normalized is null
),

transformed as (
    select
        company,
        cloud_id,
        cloud_site_hostname,
        tech_contact_email,
        addon_name,
        status,
        license_type,
        tier,
        hosting,
        distinct_users,
        total_events,
        first_seen,
        last_seen,
        match_type

        -- DATA QUALITY: company-name matching can miss customers with inconsistent legal/trade naming across systems.
        -- ASSUMPTION: most recent license by last_updated is the best canonical company record for customer attributes.
        -- ASSUMPTION: customer grain is company + product. A company using both
        -- Checklist and Clockwork is two customer relationships, not one.
        -- ASSUMPTION: unresolved amplitude rows are retained with null marketplace attributes for downstream triage.
        -- ASSUMPTION: marketplace records without amplitude activity are intentionally labeled marketplace_only.
    from source
)

select *
from transformed
