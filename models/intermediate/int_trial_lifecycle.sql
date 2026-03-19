with source as (
    select
        upper(trim(company)) as company,
        addon_name,
        license_id,
        evaluation_license_id,
        license_type,
        evaluation_start_date,
        evaluation_end_date,
        evaluation_sale_date,
        status
    from {{ ref('stg_marketplace_licenses') }}
    where license_type is not null
),

transformed as (
    select
        company,
        addon_name,
        license_id,
        evaluation_license_id,
        (
            upper(license_type) = 'EVALUATION'
            or evaluation_start_date is not null
        ) as is_trial,
        (evaluation_sale_date is not null) as converted,
        datediff(day, evaluation_start_date, evaluation_sale_date) as days_to_convert,
        evaluation_start_date as trial_start_date,
        evaluation_end_date as trial_end_date,
        evaluation_sale_date as converted_date,
        status as current_status

        -- DATA QUALITY: evaluation_sale_date may exist without evaluation_start_date, producing null days_to_convert.
        -- ASSUMPTION: either explicit EVALUATION type or populated evaluation_start_date indicates trial behavior.
        -- ASSUMPTION: license_type null records are excluded because lifecycle interpretation is ambiguous.
    from source
)

select *
from transformed
