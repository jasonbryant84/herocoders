with source as (
    select
        upper(trim(nullif(user_property_company, ''))) as company,
        product,
        event_type,
        user_id,
        session_id,
        event_time
    from {{ ref('stg_amplitude_events') }}
    where event_type not in ('automated_test_run', 'api_health_check')

    -- DATA QUALITY: excluding system/QA events, not real user activity
),

transformed as (
    select
        company,
        product,
        count(*) as total_events,
        count(distinct user_id) as distinct_users,
        count(distinct session_id) as distinct_sessions,
        min(event_time::date) as first_event_date,
        max(event_time::date) as last_event_date,
        count(distinct event_time::date) as active_days,

        count_if(product = 'Checklist for Jira' and event_type = 'checklist_item_created') as checklist_items_created,
        count_if(product = 'Checklist for Jira' and event_type = 'checklist_item_completed') as checklist_items_completed,
        count_if(product = 'Checklist for Jira' and event_type = 'checklist_template_applied') as templates_applied,
        count_if(product = 'Checklist for Jira' and event_type = 'checklist_exported') as checklists_exported,
        count_if(product = 'Checklist for Jira' and event_type = 'checklist_shared') as checklists_shared,

        count_if(product = 'Clockwork for Jira' and event_type = 'timesheet_submitted') as timesheets_submitted,
        count_if(product = 'Clockwork for Jira' and event_type = 'timesheets_approved') as timesheets_approved,
        count_if(product = 'Clockwork for Jira' and event_type = 'time_logged') as time_logged,
        count_if(product = 'Clockwork for Jira' and event_type = 'timer_started') as timers_started,
        count_if(product = 'Clockwork for Jira' and event_type = 'report_generated') as reports_generated,

        count_if(event_type = 'onboarding_completed') as onboarding_completed,
        count_if(event_type = 'onboarding_started') as onboarding_started,
        count_if(event_type = 'subscription_activated') as subscription_activated,
        count_if(event_type = 'subscription_cancelled') as subscription_cancelled,
        count_if(event_type = 'app_uninstalled') as app_uninstalled

        -- ASSUMPTION: null company values represent unresolved entities and remain in output for downstream handling.
        -- ASSUMPTION: product-scoped feature counts are retained as zero for non-matching products to simplify downstream consumption.
    from source
    group by 1, 2
)

select *
from transformed
