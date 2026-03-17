with source as (
    select * from {{ ref('raw_users') }}
),

staged as (
    select
        id                          as user_id,
        name                        as user_name,
        email                       as user_email,
        cast(created_at as date)    as created_at
    from source
)

select * from staged
