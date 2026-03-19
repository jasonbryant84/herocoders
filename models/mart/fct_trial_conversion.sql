with source as (
    select
        trial_start_date,
        addon_name,
        is_trial,
        converted,
        days_to_convert
    from {{ ref('int_trial_lifecycle') }}
),

transformed as (
    select
        date_trunc('month', trial_start_date)::date as month,
        addon_name,
        count_if(is_trial) as trials_started,
        count_if(is_trial and converted) as trials_converted,
        count_if(is_trial and converted)::float / nullif(count_if(is_trial), 0) as conversion_rate,
        avg(case when converted then days_to_convert end) as avg_days_to_convert,
        percentile_cont(0.5) within group (
            order by case when converted then days_to_convert end
        ) as median_days_to_convert

        -- ASSUMPTION: conversion is attributed to the month trial started (cohort view), not conversion month.
        -- DATA QUALITY: records missing trial_start_date are excluded from monthly cohorting.
    from source
    where trial_start_date is not null
    group by 1, 2
)

select *
from transformed
