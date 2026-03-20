# HeroCoders Analytics — dbt Project

## Overview
This project delivers a layered SQL analytics model designed to answer customer health, retention, and trial conversion questions for HeroCoders products. The pipeline transforms raw operational and behavioral data into business-facing marts that can be consumed directly by analysts and BI tools. The stack uses Snowflake as the warehouse and dbt as the transformation layer, with source data from Atlassian Marketplace and Amplitude. Models are organized into a three-layer structure: staging/, intermediate/, and mart/.

## Architecture

The project follows a standard three-layer dbt architecture to separate data cleaning, business logic, and reporting outputs:

- **Staging** - mirrors raw source tables with light cleaning, type casting, and null handling. No business logic.
  → See [staging/README.md](models/staging/README.md)
- **Intermediate** - entity resolution, business logic, and aggregations that support the mart layer. Not for direct consumption.
  → See [intermediate/README.md](models/intermediate/README.md)
- **Mart** - final, business-facing fact and dimension models answering specific questions. Intended for BI tools and analysis.
  → See [mart/README.md](models/mart/README.md)

```text
raw sources (Snowflake PUBLIC schema)
    └── staging/          stg_*
        └── intermediate/ int_*
            └── mart/     fct_* / dim_*
```

## How to Run

1. Clone this repo
2. Install dbt: `pip install dbt-snowflake`
3. Configure your profile in `~/.dbt/profiles.yml` targeting the HEROCODERS database and your schema
4. Run `dbt build` to execute all models in dependency order

## Deliverables

### 1. SQL Files
Organized in three folders:
- models/staging/ - 3 models (one per source table) + sources.yml
- models/intermediate/ - 3 models (customer entity, trial lifecycle, feature usage)
- models/mart/ - 5 fact models + dim_customers

| Layer | Location | Contents |
| --- | --- | --- |
| Staging | models/staging/ | 3 staging models + sources.yml |
| Intermediate | models/intermediate/ | 3 transformation models |
| Mart | models/mart/ | 5 fact models + 1 dimension model |

### 2. Assumptions Document

#### How I Defined "Customer" and Why
A customer is defined at the **company + product** grain, not the individual user level. Atlassian licenses are purchased per company/workspace, so the natural unit of a paying relationship is the company. A company using both Checklist and Clockwork represents two distinct customer relationships.

Individual Amplitude user_ids are treated as seats within a company, not separate customers. Multiple user_ids per company inform engagement breadth metrics (distinct_users).

Customer identity is resolved across Marketplace and Amplitude using normalized company name (UPPER(TRIM(company))) as the join key - the only reliable common identifier between the two systems. Three match states are tracked via match_type:
- matched_on_company: present in both systems
- marketplace_only: paying customer with no Amplitude activity
- unresolved: Amplitude activity with no matching license

#### Data Quality Issues Found and How I Resolved Them

1. **MARKETPLACE_LICENSES loaded without SKIP_HEADER** - column names appeared as row 1. Resolved by reloading with correct header settings in Snowflake's data loader.

2. **ADDON_LICENSE_ID type mismatch** - TEXT in MARKETPLACE_LICENSES but NUMBER in MARKETPLACE_TRANSACTIONS. Cast both to VARCHAR in staging to ensure clean joins.

3. **EVALUATION_LICENSE misnamed column** - column name implied a boolean flag but actual values were large integers (e.g. 100884) representing FK references to originating evaluation license records. Renamed to evaluation_license_id and cast as VARCHAR.

4. **Product name inconsistency across sources** - Amplitude used short names ('checklist', 'clockwork', 'timesheet') while Marketplace used full names ('Checklist for Jira' etc). Normalized to full names in stg_amplitude_events using a CASE mapping.

5. **addon_name casing inconsistency** - mixed case in raw data caused duplicate product groupings in mart models. Resolved with UPPER(TRIM(addon_name)) in staging.

6. **System events in Amplitude** - automated_test_run and api_health_check events were present in the event stream. Excluded in int_amplitude_feature_usage as they don't represent real user activity.

7. **EVENT_PROPERTIES stored as JSON text** - left unparsed in staging, flagged for intermediate layer parsing if needed. Profiling showed only product-level metadata (item_count, template_id, duration_seconds) - no join keys present.

8. **feature_adoption_score in fct_customer_health** - the feature adoption component of the health score is currently scoring 0 due to a join issue between fct_customer_health and int_amplitude_feature_usage. The remaining three components (recency, engagement, license health) are functioning correctly. Documented as a known limitation.

#### Key Assumptions Made

1. vendor_amount is used as the revenue proxy (HeroCoders' net revenue after Atlassian's cut) rather than purchase_price.
2. NRR formula: (beginning MRR + expansion - contraction - churn) / beginning MRR
3. A customer is "active" if status = 'active' AND maintenance_end_date >= month end.
4. Trial conversion is attributed to the month the trial started (cohort-based), not the month it converted.
5. Health score uses equal 25pt weighting across four dimensions (recency, engagement breadth, feature adoption, license health) as a starting point - weights should be tuned based on known churn predictors.
6. days_to_convert was re-derived from source dates rather than trusting the pre-calculated DAYS_TO_CONVERT_EVAL field. Validated against the raw field - zero discrepancy across all records.
7. marketplace_only customers score 0 on recency, engagement, and feature adoption in the health score - this is intentional and surfaced via match_type.

#### Questions I Would Ask the Data/Product Team

1. Is there a more reliable join key between Amplitude and Marketplace than company name? An Atlassian Account ID or cloud_id passed as an Amplitude user property would dramatically improve entity resolution accuracy.
2. Why do 95 paying customers (14.5%) have zero Amplitude activity? Is this a hosting type issue (server/data center vs cloud)?
3. What is the intended meaning of EVALUATION_OPPORTUNITY_SIZE? It appears to be categorical but the values weren't fully profiled.
4. Are there additional revenue events beyond what's in MARKETPLACE_TRANSACTIONS (e.g. professional services, partner referrals)?
5. What is the expected trial length? Knowing this would improve churn detection logic (a trial expiring naturally vs a customer actively cancelling are different events).
6. Should Timesheet for Jira be treated as a standalone product or is it a legacy version of Clockwork? The data suggests it's separate but the naming implies a relationship.
7. Why do highly engaged customers (high user count, many active days) still churn? Exit survey data would help interpret the feature adoption vs churn finding.

### 3. Key Business Insights

#### Insight 1: Trials Convert Early or Not at All

| Product | Total Trials | Converted | Conversion Rate | Avg Days to Convert |
|---|---|---|---|---|
| Timesheet for Jira | 114 | 47 | 41.2% | 15.8 days |
| Clockwork for Jira | 760 | 273 | 35.9% | 17.9 days |
| Checklist for Jira | 756 | 258 | 34.1% | 17.3 days |

Across all three products, the average time to convert is 15-18 days —
well within a typical 30-day trial window. Notably, most conversion
decisions happen in the first half of the trial period. Companies that
haven't converted by day 20 are unlikely to convert at all. A targeted
intervention around day 10-12 for unconverted trials could meaningfully
improve overall conversion rate.

#### Insight 2: 14.5% of Paying Customers Are Invisible to Analytics

| Match Type | Customers | Avg Health Score | Avg Recency Score |
|---|---|---|---|
| matched_on_company | 537 | 23.3 | 12.6 |
| marketplace_only | 95 | 4.6 | 0.0 |
| unresolved | 23 | 20.7 | 10.7 |

95 of 655 customer-product relationships are marketplace_only — paying
customers generating zero Amplitude events. These customers score 0 on
recency, engagement, and feature adoption in the health model because
they are completely untracked. This is a structural blind spot that
should be investigated before investing further in predictive analytics
infrastructure. Likely cause: server/data center hosting where Amplitude
is not instrumented.

#### Insight 3: High Engagement Doesn't Prevent Churn

| Product | Outcome | Avg Users | Avg Days Active |
|---|---|---|---|
| Checklist for Jira | converted | 7.4 | 154.2 |
| Checklist for Jira | churned | 14.1 | 58.7 |
| Checklist for Jira | active_trial | 1.2 | 24.3 |
| Clockwork for Jira | converted | 6.9 | 140.4 |
| Clockwork for Jira | churned | 14.0 | 59.3 |
| Clockwork for Jira | active_trial | 1.0 | 31.2 |
| Timesheet for Jira | converted | 2.2 | 55.8 |
| Timesheet for Jira | churned | 5.4 | 46.1 |
| Timesheet for Jira | active_trial | 2.6 | 27.2 |

Churned customers consistently show higher user counts than converted
customers across all products (14.1 vs 7.4 for Checklist, 14.0 vs 6.9
for Clockwork) yet they still left. This suggests churn is not driven
by lack of adoption but by other factors — pricing, missing features,
or competitive alternatives. Converted customers show deeper sustained
engagement (154 days active vs 59 for churned), suggesting that
long-term daily habit formation is the key differentiator between
customers who stay and those who leave. Retention efforts should focus
on understanding why engaged customers leave, not on re-engaging
dormant ones.