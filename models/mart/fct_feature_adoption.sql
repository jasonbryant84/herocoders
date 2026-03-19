with source as (
    select
        iafu.company,
        nullif(trim(iafu.product), '') as addon_name,
        iafu.total_events,
        iafu.distinct_users,
        iafu.distinct_sessions,
        iafu.first_event_date,
        iafu.last_event_date,
        iafu.active_days,
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
        iafu.onboarding_completed,
        iafu.onboarding_started,
        iafu.subscription_activated,
        iafu.subscription_cancelled,
        iafu.app_uninstalled,
        ls.has_converted,
        ls.has_inactive_status
    from {{ ref('int_amplitude_feature_usage') }} as iafu
    left join (
        select
            company,
            addon_name,
            max(case when converted then 1 else 0 end) as has_converted,
            max(case when upper(current_status) = 'INACTIVE' then 1 else 0 end) as has_inactive_status
        from {{ ref('int_trial_lifecycle') }}
        group by 1, 2
    ) as ls
        on iafu.company = ls.company
       and nullif(trim(iafu.product), '') = nullif(trim(ls.addon_name), '')
),

transformed as (
    with classified as (
        select
            company,
            addon_name,
            case
                when coalesce(has_converted, 0) = 1 then 'converted'
                when coalesce(has_inactive_status, 0) = 1 or app_uninstalled > 0 then 'churned'
                else 'active_trial'
            end as outcome,
            total_events,
            distinct_users,
            distinct_sessions,
            first_event_date,
            last_event_date,
            active_days,
            checklist_items_created,
            checklist_items_completed,
            templates_applied,
            checklists_exported,
            checklists_shared,
            timesheets_submitted,
            timesheets_approved,
            time_logged,
            timers_started,
            reports_generated,
            onboarding_completed,
            onboarding_started,
            subscription_activated,
            subscription_cancelled,
            app_uninstalled
        from source
    )

    select
        company,
        addon_name,
        outcome,
        total_events,
        distinct_users,
        distinct_sessions,
        first_event_date,
        last_event_date,
        active_days,
        checklist_items_created,
        checklist_items_completed,
        templates_applied,
        checklists_exported,
        checklists_shared,
        timesheets_submitted,
        timesheets_approved,
        time_logged,
        timers_started,
        reports_generated,
        onboarding_completed,
        onboarding_started,
        subscription_activated,
        subscription_cancelled,
        app_uninstalled,
        avg(checklist_items_created) over (partition by addon_name, outcome) as avg_checklist_items_created,
        avg(checklist_items_completed) over (partition by addon_name, outcome) as avg_checklist_items_completed,
        avg(timesheets_submitted) over (partition by addon_name, outcome) as avg_timesheets_submitted,
        avg(time_logged) over (partition by addon_name, outcome) as avg_time_logged,
        avg(active_days) over (partition by addon_name, outcome) as avg_days_active,
        avg(distinct_users) over (partition by addon_name, outcome) as avg_distinct_users

        -- ASSUMPTION: outcome is derived from current lifecycle status at analysis time, not full point-in-time history.
        -- ASSUMPTION: group-level averages are exposed as window metrics on each company+product row for easier downstream slicing.
    from classified
)

select *
from transformed
