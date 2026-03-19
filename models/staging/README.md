## Staging Layer

The staging layer standardizes raw HeroCoders source data from Snowflake into clean, analysis-ready base models without applying business logic.

What this layer does:
- Selects fields from raw source tables and keeps naming consistent in snake_case.
- Applies explicit data type casting for predictable downstream behavior.
- Trims whitespace on string fields and converts empty strings to null.
- Documents known data quality issues and modeling assumptions inline.

What this layer does not do:
- No business definitions (for example, revenue logic, customer status logic, or conversion KPIs).
- No heavy transformations such as JSON flattening or multi-table enrichment.
- No aggregation or semantic interpretation beyond basic normalization.

## Source Tables

### AMPLITUDE_EVENTS

What the table represents:
- Event-level product analytics from Amplitude, including who did what and when.

Key fields and their purpose:
- event_id: Event identifier from source telemetry.
- event_type: Action category (for example, install, click, purchase-related events).
- event_time: Event timestamp in TIMESTAMP_NTZ.
- user_id, device_id: User/device identity signals for behavioral analysis.
- session_id: Session grouping key.
- event_properties: Raw event payload likely containing nested attributes.
- user_property_company, user_property_plan, user_property_tier: User context at event time.
- country, region, platform, event_source, product: Geo/platform/source dimensions.

Data quality issues found and how they were resolved:
- DATA QUALITY: event_properties appears to be a JSON-like blob stored as text.
- Resolution in staging: Keep event_properties as normalized text (trimmed + empty-to-null), with no parsing at this layer.

Assumptions made:
- ASSUMPTION: JSON parsing and schema enforcement for event_properties belongs in intermediate models.

### MARKETPLACE_LICENSES

What the table represents:
- License-level records for marketplace customers, including entitlement metadata, maintenance windows, evaluation context, and acquisition fields.

Key fields and their purpose:
- addon_license_id: Primary add-on license key, standardized as varchar for cross-table joining.
- license_id, app_entitlement_number, host_license_id, host_entitlement_number: Entitlement and host linkage identifiers.
- addon_key, addon_name, hosting, license_type, status, tier: Core commercial and product descriptors.
- maintenance_start_date, maintenance_end_date, last_updated: Lifecycle timing fields.
- evaluation_license_id, evaluation_start_date, evaluation_end_date, evaluation_sale_date, days_to_convert_eval: Evaluation journey attributes.
- company, country, region, tech_contact_email, tech_contact_name: Customer and contact attributes.
- channel, campaign_name, campaign_source, campaign_medium, campaign_content, referrer_domain: Marketing attribution fields.

Data quality issues found and how they were resolved:
- DATA QUALITY: evaluation_opportunity_size is typed as text and may represent numeric/categorical tiers.
- Resolution in staging: Preserve as cleaned text (varchar) and defer value interpretation.
- DATA QUALITY: column name implied boolean but values are license ID references (e.g. 100884, 100242).
- Resolution in staging: Rename to evaluation_license_id and cast to varchar identifier.

Assumptions made:
- ASSUMPTION: treating evaluation_license as FK to originating evaluation license record, renamed to evaluation_license_id for clarity.
- ASSUMPTION: addon_license_id is standardized to varchar to align join keys with marketplace transactions staging.

### MARKETPLACE_TRANSACTIONS

What the table represents:
- Transaction-level marketplace sales records, including amounts, discounts, product metadata, and maintenance periods.

Key fields and their purpose:
- transaction_id: Transaction identifier.
- addon_license_id, license_id, app_entitlement_number: Join keys to license/entitlement context.
- sale_date, sale_type, sale_channel: Transaction timing and channel descriptors.
- purchase_price, vendor_amount: Financial amounts.
- loyalty_discount, marketplace_promotion_discount, expert_discount, manual_discount: Discount components.
- addon_key, addon_name, hosting, billing_period, tier, parent_product_name, parent_product_edition: Product/package metadata.
- maintenance_start_date, maintenance_end_date: Coverage window fields.

Data quality issues found and how they were resolved:
- DATA QUALITY: addon_license_id is numeric in raw transactions but text in raw licenses.
- Resolution in staging: Cast addon_license_id to varchar in transactions and licenses for key consistency.

Assumptions made:
- ASSUMPTION: preserving numeric discount and amount fields as number avoids premature rounding.

## Open Questions

1. Should event_properties in AMPLITUDE_EVENTS be modeled as VARIANT in intermediate, and which keys are required for analytics contracts?
2. What is the authoritative domain of evaluation_opportunity_size values (ordered numeric bands vs categorical labels), and should we enforce accepted values via tests?
3. Can the data team confirm cardinality and referential expectations between evaluation_license_id and any originating license/evaluation table?
4. Is addon_license_id guaranteed to be a canonical stringified integer across systems, or are there non-numeric formats we should expect long term?
5. Which fields should be considered mandatory for analytics SLAs (for example, transaction_id, event_id, sale_date), so we can add not_null/unique tests in sources or staging?
6. For financial fields (purchase_price, vendor_amount, discounts), should we enforce fixed precision/scale conventions at staging (for example, number(18,2))?
7. Are there known timezone semantics for event_time and sale_date that require normalization prior to downstream reporting?
