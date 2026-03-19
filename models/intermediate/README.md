## Intermediate Layer

The intermediate layer applies business logic to standardized staging models so HeroCoders can reason about customer entities, lifecycle behavior, and product engagement.

What this layer does:
- Resolves company-grain customer entities across Marketplace licenses and Amplitude events.
- Applies lifecycle logic for trial and conversion behavior.
- Aggregates high-volume event data into reusable engagement metrics.
- Preserves unresolved records where identity is incomplete, so they can be explicitly assessed downstream.

What this layer does not do:
- No final presentation metrics or executive KPI definitions.
- No dashboard-ready marts or denormalized consumption schemas.
- No irreversible business rollups that hide raw/intermediate ambiguity.

## Customer Definition

HeroCoders sells Atlassian Marketplace apps (Checklist for Jira and Clockwork for Jira) on a workspace/license basis. In this context, the customer relationship is best represented at the company + product grain, not by individual Amplitude user_id.

Rationale:
- Marketplace purchase and entitlement artifacts are license-centric and linked to company-level account context.
- Amplitude user_id represents end users/seats inside a customer organization.
- Seat-level identity is useful for adoption depth, but not for customer entity identity.
- A single company can hold licenses for multiple HeroCoders products simultaneously, and each product relationship can have distinct adoption and health patterns.

Entity resolution strategy:
- Join key is normalized company name using UPPER(TRIM(company)).
- Marketplace side: stg_marketplace_licenses.company.
- Amplitude side: stg_amplitude_events.user_property_company.
- Product alignment is enforced by joining stg_marketplace_licenses.addon_name to stg_amplitude_events.product.
- match_type is used to make resolution explicit:
  - matched_on_company: marketplace and amplitude successfully joined.
  - marketplace_only: marketplace company exists but has no observed amplitude activity.
  - unresolved: amplitude record has no marketplace company match.
- Both marketplace_only and unresolved states are retained for transparency and later triage.

## Models

### int_customer_entity

What it does:
- Produces one canonical customer record per normalized company + addon_name from marketplace licenses.
- Picks the most recent license record by last_updated as canonical company attributes.
- Joins in per-company + product Amplitude aggregates (distinct users, total events, first_seen, last_seen).
- Retains unmatched Amplitude company + product combinations as unresolved rows.

Key logic decisions:
- Company normalization on both sides uses UPPER(TRIM(...)).
- Canonical marketplace row uses row_number partitioned by company + addon_name, ordered by last_updated desc (with license_id as tie-breaker).
- Unresolved Amplitude rows are unioned in with null marketplace attributes and addon_name populated from Amplitude product.

Assumptions made:
- Most recent license record best represents current company + product customer attributes.
- Company-name normalization plus product-name alignment is sufficient as an initial entity key.
- Unresolved rows should remain visible rather than filtered out.

Data quality issues handled:
- Company names may not align perfectly across systems due to formatting/naming drift.
- Missing/blank company values limit deterministic entity resolution.

### int_trial_lifecycle

What it does:
- Produces one row per license to track evaluation-to-paid lifecycle behavior.
- Derives trial and conversion flags and conversion timing metrics.

Key logic decisions:
- is_trial is true when license_type = EVALUATION or evaluation_start_date is present.
- converted is true when evaluation_sale_date is populated.
- days_to_convert uses datediff(day, evaluation_start_date, evaluation_sale_date).
- Records with null license_type are excluded.

Assumptions made:
- evaluation_start_date can signal trial behavior even when license_type labeling is inconsistent.
- Null license_type rows are too ambiguous for lifecycle interpretation.

Data quality issues handled:
- Incomplete trial timestamps can produce null conversion-duration values.
- Lifecycle interpretation can vary when source status and date fields disagree.

### int_amplitude_feature_usage

What it does:
- Aggregates Amplitude events by normalized company and product.
- Computes engagement breadth, recency, and activity cadence metrics.
- Adds product-specific feature usage counts for Checklist for Jira and Clockwork for Jira.
- Adds lifecycle event signals across all products.

Key logic decisions:
- Excludes known system/QA events (automated_test_run, api_health_check).
- Uses nullif on user_property_company so blanks become unresolved (null) instead of blank-string buckets.
- Keeps unresolved company rows in output for downstream decisioning.

Assumptions made:
- Excluded QA/system events are non-customer behavior and should not influence health/adoption metrics.
- Product-scoped feature counters are retained for every company-product row, including zeros.

Data quality issues handled:
- Non-user/system-generated events are removed from engagement aggregates.
- Missing company identity is preserved as unresolved, not silently dropped.

## Open Questions

1. Should unresolved Amplitude company rows be included in product health scoring, or tracked separately as data-quality backlog?
2. Is UPPER(TRIM(company)) sufficient for entity resolution, or should we adopt stronger keys (cloud_id, entitlement number, domain mapping table)?
3. For canonical customer attributes, is most-recent license by last_updated the correct rule, or should active status/tier precedence be applied?
4. Should direct purchases (no evaluation_license_id) be modeled as a separate lifecycle path from trial conversion?
5. Are there official event taxonomies for Checklist for Jira and Clockwork for Jira that should replace hardcoded event name lists?
6. Do we need product-specific unresolved handling when product is null or mislabeled in Amplitude?
7. Should conversion timing use calendar days or business days for reporting consistency?
