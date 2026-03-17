with source as (
    select * from {{ ref('raw_orders') }}
),

staged as (
    select
        id                          as order_id,
        user_id,
        product_name,
        cast(amount as numeric)     as amount,
        lower(status)               as status,
        cast(ordered_at as date)    as ordered_at
    from source
)

select * from staged
