## Mart Layer

The mart layer provides final, business-facing datasets that answer specific performance questions for HeroCoders across acquisition, conversion, retention, feature adoption, and customer health.

What this layer does:
- Turns intermediate entities and events into reporting-ready facts at monthly and customer-product grains.
- Encodes business metric formulas (active customers, conversion rate, churn rate, NRR, health score).
- Produces stable model outputs designed for BI and recurring performance reviews.

What this layer does not do:
- No raw source cleanup or key normalization.
- No entity resolution logic (handled in intermediate).
- No ad hoc exploration logic; this layer is opinionated and metric-driven.

## Dimensions

### dim_customers

- Grain: one row per company + product.
- The stable, queryable customer dimension for use in BI tools and ad-hoc analysis.
- match_type indicates data completeness:
  - matched_on_company: present in both Marketplace and Amplitude.
  - marketplace_only: paying customer with no Amplitude activity.
  - unresolved: Amplitude activity with no matching Marketplace license.

## Models

### fct_active_customers

Business question it answers:
- How many active customers do we have per product per month, and how is that changing month-over-month?

Primary customer source:
- dim_customers

Metric definitions:
- active_customer_count: distinct company count where status = ACTIVE and maintenance_end_date covers the month end.
- new_customers: companies whose first maintenance_start_date for that product falls in the month.
- churned_customers: companies with maintenance_end_date in the month and no subsequent active license.
- mom_change: active_customer_count minus prior month active_customer_count by product.

Assumptions made:
- Active customer definition requires both active status and non-expired maintenance.
- Monthly grain is the right level for trend readability and data volume.

### fct_trial_conversion

Business question it answers:
- What is trial-to-paid conversion rate by product and cohort month, and how long does conversion take?

Metric definitions:
- trials_started: count of trial records where is_trial = true.
- trials_converted: count where is_trial = true and converted = true.
- conversion_rate: trials_converted / trials_started.
- avg_days_to_convert: average days_to_convert for converted trials.
- median_days_to_convert: median days_to_convert for converted trials.

Assumptions made:
- Conversion is attributed to trial start month (cohort logic), not conversion month.

### fct_churn_and_nrr

Business question it answers:
- What are monthly churn rate and Net Revenue Retention (NRR) by product?

Primary customer source:
- dim_customers

Metric definitions:
- mrr: sum(vendor_amount) for sale_type in New, Renewal, Upgrade.
- churned_mrr: sum of vendor_amount proxy where refunds occur or subscription_cancelled signal exists.
- expansion_mrr: sum(vendor_amount) for Upgrade.
- contraction_mrr: sum(vendor_amount) for Downgrade.
- beginning_mrr: prior month mrr by product.
- nrr: (beginning_mrr + expansion_mrr - contraction_mrr - churned_mrr) / beginning_mrr.
- churn_rate: churned_mrr / beginning_mrr.

Assumptions made:
- vendor_amount is the best revenue proxy for what HeroCoders actually receives.
- NRR formula follows beginning + expansion - contraction - churn over beginning baseline.
- Cancellation events are mapped to monthly transaction value as a churned revenue proxy.

### fct_feature_adoption

Business question it answers:
- Which product features are most used by converted vs churned vs active-trial customers?

Metric definitions:
- outcome:
  - converted: company-product has converted trial signal.
  - churned: company-product has inactive status signal or app_uninstalled > 0.
  - active_trial: otherwise.
- Includes all feature event counters from int_amplitude_feature_usage.
- Includes outcome-level window averages by product:
  - avg_checklist_items_created
  - avg_checklist_items_completed
  - avg_timesheets_submitted
  - avg_time_logged
  - avg_days_active
  - avg_distinct_users

Assumptions made:
- Outcome is determined using latest available status/signals at analysis time.
- Outcome-level averages are included as window metrics on each company-product row for flexible slicing.

### fct_customer_health

Business question it answers:
- What does a practical, explainable customer health score look like at company-product level?

Primary customer source:
- dim_customers

Metric definitions:
- recency_score (0-25): based on last event recency windows (30/60/90 days).
- engagement_score (0-25): distinct_users relative to tier-based seat-limit proxy, capped at 25.
- feature_adoption_score (0-25): up to 5 used feature types, 5 points each.
- license_health_score (0-25): active + maintenance horizon weighting.
- health_score: sum of four component scores.
- health_tier:
  - healthy: score >= 75
  - at_risk: score >= 40 and < 75
  - critical: score < 40

Assumptions made:
- Equal weighting (25 points each) is an initial baseline, not a final calibrated model.
- marketplace_only relationships score 0 on usage-derived dimensions due no amplitude telemetry.
- Tier labels are mapped to user-limit proxies and should be validated with product/commercial teams.

## Key Metrics Glossary

- Active Customer: A company-product relationship with ACTIVE license status and maintenance coverage through month-end.
- MRR: Monthly recurring revenue proxy based on vendor_amount for qualifying recurring sale types.
- Churn Rate: churned_mrr divided by beginning_mrr for a product-month.
- NRR: Net Revenue Retention = (beginning_mrr + expansion_mrr - contraction_mrr - churned_mrr) / beginning_mrr.
- Health Score: Composite 0-100 score combining recency, engagement breadth, feature adoption, and license health.
- Conversion Rate: trial cohorts converted divided by trial cohorts started.

## Open Questions

1. Should active customer trending use a complete calendar month spine (including zero-activity months) rather than only months present in license starts?
2. For churned_mrr, should cancellation events map to a dedicated contract value source instead of transaction-month vendor_amount proxy?
3. Do we want NRR reported as a percentage format or retained as decimal in marts?
4. Is outcome precedence in feature adoption correct (converted before churned), or should churn signals override conversion?
5. Can HeroCoders provide authoritative tier-to-seat-limit mappings so engagement scoring is not proxy-based?
6. Should health score exclude unresolved relationships by default in executive reporting?
7. What guardrails (minimum volume thresholds, confidence flags) are needed before productionizing per-product conversion/churn reporting?
