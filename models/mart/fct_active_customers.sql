with source as (
    select
        upper(trim(sl.company)) as company,
        nullif(trim(sl.addon_name), '') as addon_name,
        sl.status,
        sl.maintenance_start_date,
        sl.maintenance_end_date
    from {{ ref('stg_marketplace_licenses') }} as sl
        inner join {{ ref('dim_customers') }} as ice
        on upper(trim(sl.company)) = ice.company
       and nullif(trim(sl.addon_name), '') = nullif(trim(ice.addon_name), '')
    where nullif(trim(sl.company), '') is not null
      and nullif(trim(sl.addon_name), '') is not null
      and sl.maintenance_start_date is not null
),

transformed as (
    with month_spine as (
        select distinct
            date_trunc('month', maintenance_start_date)::date as month
        from source
    ),

    license_months as (
        select
            s.company,
            s.addon_name,
            m.month,
            last_day(m.month)::date as month_end,
            s.status,
            s.maintenance_start_date,
            s.maintenance_end_date
        from source as s
        inner join month_spine as m
            on s.maintenance_start_date <= last_day(m.month)
           and coalesce(s.maintenance_end_date, '2999-12-31'::date) >= m.month
    ),

    active_by_month as (
        select
            month,
            addon_name,
            count(distinct company) as active_customer_count
        from license_months
        where upper(status) = 'ACTIVE'
          and coalesce(maintenance_end_date, '2999-12-31'::date) >= month_end
        group by 1, 2
    ),

    first_license as (
        select
            company,
            addon_name,
            min(maintenance_start_date) as first_license_start_date
        from source
        group by 1, 2
    ),

    new_customers as (
        select
            date_trunc('month', first_license_start_date)::date as month,
            addon_name,
            count(distinct company) as new_customers
        from first_license
        group by 1, 2
    ),

    churned_customers as (
        select
            date_trunc('month', s.maintenance_end_date)::date as month,
            s.addon_name,
            count(distinct s.company) as churned_customers
        from source as s
        where s.maintenance_end_date is not null
          and not exists (
              select 1
              from source as s_next
              where s_next.company = s.company
                and s_next.addon_name = s.addon_name
                and s_next.maintenance_start_date > s.maintenance_end_date
                and upper(s_next.status) = 'ACTIVE'
                and coalesce(s_next.maintenance_end_date, '2999-12-31'::date) >= s_next.maintenance_start_date
          )
        group by 1, 2
    ),

    combined as (
        select
            abm.month,
            abm.addon_name,
            abm.active_customer_count,
            coalesce(nc.new_customers, 0) as new_customers,
            coalesce(cc.churned_customers, 0) as churned_customers
        from active_by_month as abm
        left join new_customers as nc
            on abm.month = nc.month
           and abm.addon_name = nc.addon_name
        left join churned_customers as cc
            on abm.month = cc.month
           and abm.addon_name = cc.addon_name
    )

    select
        month,
        addon_name,
        active_customer_count,
        new_customers,
        churned_customers,
        active_customer_count
            - lag(active_customer_count) over (
                partition by addon_name
                order by month
            ) as mom_change

        -- ASSUMPTION: active = status is 'active' AND maintenance has not expired.
        -- ASSUMPTION: month grain is sufficient for trend analysis given data volume.
        -- DATA QUALITY: month spine is derived from maintenance_start_date months present in source data.
    from combined
)

select *
from transformed
