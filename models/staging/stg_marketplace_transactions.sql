with source as (
    select *
    from {{ source('public', 'MARKETPLACE_TRANSACTIONS') }}
),

renamed as (
    select
        nullif(trim(cast(transaction_id as varchar)), '') as transaction_id,
        nullif(trim(cast(addon_license_id as varchar)), '') as addon_license_id,
        nullif(trim(cast(license_id as varchar)), '') as license_id,
        nullif(trim(cast(app_entitlement_number as varchar)), '') as app_entitlement_number,
        nullif(trim(cast(addon_key as varchar)), '') as addon_key,
        nullif(trim(cast(addon_name as varchar)), '') as addon_name,
        nullif(trim(cast(hosting as varchar)), '') as hosting,
        cast(sale_date as date) as sale_date,
        nullif(trim(cast(sale_type as varchar)), '') as sale_type,
        cast(purchase_price as number) as purchase_price,
        cast(vendor_amount as number) as vendor_amount,
        nullif(trim(cast(billing_period as varchar)), '') as billing_period,
        nullif(trim(cast(tier as varchar)), '') as tier,
        cast(maintenance_start_date as date) as maintenance_start_date,
        cast(maintenance_end_date as date) as maintenance_end_date,
        nullif(trim(cast(sale_channel as varchar)), '') as sale_channel,
        nullif(trim(cast(parent_product_name as varchar)), '') as parent_product_name,
        nullif(trim(cast(parent_product_edition as varchar)), '') as parent_product_edition,
        cast(loyalty_discount as number) as loyalty_discount,
        cast(marketplace_promotion_discount as number) as marketplace_promotion_discount,
        cast(expert_discount as number) as expert_discount,
        cast(manual_discount as number) as manual_discount

        -- DATA QUALITY: addon_license_id is numeric in raw transactions but text in raw licenses; cast to varchar in both staging models for key consistency.
        -- ASSUMPTION: preserving numeric discount and amount fields as number avoids premature rounding.
    from source
)

select *
from renamed
