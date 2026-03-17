with users as (
    select * from {{ ref('stg_users') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

order_summary as (
    select
        user_id,
        count(order_id)                                         as total_orders,
        sum(amount)                                             as total_spend,
        sum(case when status = 'completed' then amount end)     as completed_spend,
        count(case when status = 'completed' then 1 end)        as completed_orders,
        count(case when status = 'returned' then 1 end)         as returned_orders,
        min(ordered_at)                                         as first_order_date,
        max(ordered_at)                                         as last_order_date
    from orders
    group by user_id
),

final as (
    select
        u.user_id,
        u.user_name,
        u.user_email,
        u.created_at                            as customer_since,
        coalesce(o.total_orders, 0)             as total_orders,
        coalesce(o.total_spend, 0)              as total_spend,
        coalesce(o.completed_spend, 0)          as completed_spend,
        coalesce(o.completed_orders, 0)         as completed_orders,
        coalesce(o.returned_orders, 0)          as returned_orders,
        o.first_order_date,
        o.last_order_date
    from users u
    left join order_summary o using (user_id)
)

select * from final
