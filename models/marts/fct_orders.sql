with orders as (
    select * from {{ ref('stg_orders') }}
),

users as (
    select * from {{ ref('stg_users') }}
),

final as (
    select
        o.order_id,
        o.user_id,
        u.user_name,
        u.user_email,
        o.product_name,
        o.amount,
        o.status,
        o.ordered_at
    from orders o
    left join users u using (user_id)
)

select * from final
