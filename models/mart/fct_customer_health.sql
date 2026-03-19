with source as (
    select
        ice.company,
        ice.addon_name,
        ice.match_type,
        coalesce(ice.status, tls.current_status) as current_status,
        ice.tier,
        iafu.last_event_date,
        coalesce(iafu.distinct_users, 0) as distinct_users,
        iafu.checklist_items_created,
        iafu.checklist_items_completed,
        iafu.templates_applied,
        iafu.checklists_exported,
        iafu.checklists_shared,
        iafu.timesheets_submitted,
        iafu.timesheets_approved,
        iafu.time_logged,
        iafu.timers_started,
        iafu.reports_generated,
        tls.latest_trial_end_date as maintenance_end_date
    from {{ ref('dim_customers') }} as ice
    left join {{ ref('int_amplitude_feature_usage') }} as iafu
        on ice.company = iafu.company
       and nullif(trim(ice.addon_name), '') = nullif(trim(iafu.product), '')
    left join (
        select
            company,
            addon_name,
            max(current_status) as current_status,
            max(trial_end_date) as latest_trial_end_date
        from {{ ref('int_trial_lifecycle') }}
        group by 1, 2
    ) as tls
        on ice.company = tls.company
       and nullif(trim(ice.addon_name), '') = nullif(trim(tls.addon_name), '')
    where nullif(trim(ice.addon_name), '') is not null
),

transformed as (
    with scored_inputs as (
        select
            company,
            addon_name,
            match_type,
            current_status,
            tier,
            last_event_date,
            distinct_users,
            maintenance_end_date,
            case
                when tier is null then null
                when upper(tier) like '%FREE%' then 10
                when upper(tier) like '%STANDARD%' then 25
                when upper(tier) like '%PRO%' then 50
                when upper(tier) like '%PREMIUM%' then 100
                when upper(tier) like '%ENTERPRISE%' then 250
                else 50
            end as tier_user_limit,
            iff(coalesce(checklist_items_created, 0) > 0, 1, 0)
                + iff(coalesce(checklist_items_completed, 0) > 0, 1, 0)
                + iff(coalesce(templates_applied, 0) > 0, 1, 0)
                + iff(coalesce(checklists_exported, 0) > 0, 1, 0)
                + iff(coalesce(checklists_shared, 0) > 0, 1, 0)
                + iff(coalesce(timesheets_submitted, 0) > 0, 1, 0)
                + iff(coalesce(timesheets_approved, 0) > 0, 1, 0)
                + iff(coalesce(time_logged, 0) > 0, 1, 0)
                + iff(coalesce(timers_started, 0) > 0, 1, 0)
                + iff(coalesce(reports_generated, 0) > 0, 1, 0) as feature_types_used
        from source
    ),

    scored as (
        select
            company,
            addon_name,
            match_type,
            case
                when last_event_date >= dateadd(day, -30, current_date) then 25
                when last_event_date >= dateadd(day, -60, current_date) then 15
                when last_event_date >= dateadd(day, -90, current_date) then 5
                else 0
            end as recency_score,
            case
                when tier_user_limit is null then 10
                else least(25, (distinct_users::float / nullif(tier_user_limit, 0)) * 25)
            end as engagement_score,
            least(feature_types_used, 5) * 5 as feature_adoption_score,
            case
                when upper(coalesce(current_status, '')) = 'ACTIVE'
                     and maintenance_end_date > dateadd(day, 30, current_date) then 25
                when upper(coalesce(current_status, '')) = 'ACTIVE'
                     and maintenance_end_date <= dateadd(day, 30, current_date) then 15
                else 0
            end as license_health_score
        from scored_inputs
    )

    select
        company,
        addon_name,
        match_type,
        recency_score,
        engagement_score,
        feature_adoption_score,
        license_health_score,
        recency_score + engagement_score + feature_adoption_score + license_health_score as health_score,
        case
            when recency_score + engagement_score + feature_adoption_score + license_health_score >= 75 then 'healthy'
            when recency_score + engagement_score + feature_adoption_score + license_health_score >= 40 then 'at_risk'
            else 'critical'
        end as health_tier

        -- ASSUMPTION: equal 25pt weighting across recency, engagement, adoption, and license health is a starting point.
        -- ASSUMPTION: marketplace_only customers score 0 on event-based dimensions because they lack amplitude usage data.
        -- ASSUMPTION: tier labels are mapped to proxy seat limits for breadth scoring and should be calibrated with product teams.
        -- DATA QUALITY: maintenance_end_date is approximated from trial_end_date in int_trial_lifecycle due intermediate model availability.
    from scored
)

select *
from transformed
