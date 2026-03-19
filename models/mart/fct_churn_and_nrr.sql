with source as (
    select
        mt.sale_date,
        date_trunc('month', mt.sale_date)::date as month,
        nullif(trim(mt.addon_name), '') as addon_name,
        upper(trim(sl.company)) as company,
        upper(trim(mt.sale_type)) as sale_type,
        mt.vendor_amount
    from {{ ref('stg_marketplace_transactions') }} as mt
    left join {{ ref('stg_marketplace_licenses') }} as sl
        on mt.license_id = sl.license_id
       and nullif(trim(mt.addon_name), '') = nullif(trim(sl.addon_name), '')
    inner join {{ ref('dim_customers') }} as ice
        on upper(trim(sl.company)) = ice.company
       and nullif(trim(mt.addon_name), '') = nullif(trim(ice.addon_name), '')
    where mt.sale_date is not null
      and mt.vendor_amount is not null
      and nullif(trim(mt.addon_name), '') is not null
      and nullif(trim(sl.company), '') is not null
),

transformed as (
    with cancellation_events as (
        select
            date_trunc('month', event_time)::date as month,
            upper(trim(nullif(user_property_company, ''))) as company,
            nullif(trim(product), '') as addon_name,
            count(*) as subscription_cancelled_events
        from {{ ref('stg_amplitude_events') }}
        where event_type = 'subscription_cancelled'
        group by 1, 2, 3
    ),

    customer_monthly as (
        select
            s.month,
            s.addon_name,
            s.company,
            sum(case when s.sale_type in ('NEW', 'RENEWAL', 'UPGRADE') then s.vendor_amount else 0 end) as mrr,
            sum(case when s.sale_type = 'UPGRADE' then s.vendor_amount else 0 end) as expansion_mrr,
            sum(case when s.sale_type = 'DOWNGRADE' then s.vendor_amount else 0 end) as contraction_mrr,
            sum(case when s.sale_type = 'REFUND' then s.vendor_amount else 0 end) as refund_mrr,
            sum(s.vendor_amount) as total_vendor_amount,
            coalesce(ce.subscription_cancelled_events, 0) as subscription_cancelled_events
        from source as s
        left join cancellation_events as ce
            on s.month = ce.month
           and s.company = ce.company
           and s.addon_name = ce.addon_name
        group by 1, 2, 3, 9
    ),

    rolled as (
        select
            month,
            addon_name,
            sum(mrr) as mrr,
            sum(
                case
                    when refund_mrr > 0 or subscription_cancelled_events > 0
                        then total_vendor_amount
                    else 0
                end
            ) as churned_mrr,
            sum(expansion_mrr) as expansion_mrr,
            sum(contraction_mrr) as contraction_mrr
        from customer_monthly
        group by 1, 2
    )

    select
        month,
        addon_name,
        mrr,
        churned_mrr,
        expansion_mrr,
        contraction_mrr,
        lag(mrr) over (partition by addon_name order by month) as beginning_mrr,
        (
            lag(mrr) over (partition by addon_name order by month)
            + expansion_mrr
            - contraction_mrr
            - churned_mrr
        ) / nullif(lag(mrr) over (partition by addon_name order by month), 0) as nrr,
        churned_mrr / nullif(lag(mrr) over (partition by addon_name order by month), 0) as churn_rate

        -- ASSUMPTION: vendor_amount is the revenue proxy for HeroCoders net receipts.
        -- ASSUMPTION: NRR = (beginning MRR + expansion - contraction - churn) / beginning MRR.
        -- DATA QUALITY: transaction rows are mapped to company using license_id + addon_name, which may miss imperfect key alignments.
        -- DATA QUALITY: subscription_cancelled events have no native monetary field; churned_mrr uses month-level vendor_amount proxy.
    from rolled
)

select *
from transformed
