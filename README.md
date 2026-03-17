# herocoders

A DBT (Data Build Tool) prototype project demonstrating a simple analytics engineering workflow with staging models, mart models, seed data, macros, and tests.

## Project Structure

```
herocoders/
├── dbt_project.yml          # Main DBT project configuration
├── packages.yml             # DBT package dependencies
├── profiles.yml             # Database connection profiles
├── seeds/
│   ├── raw_users.csv        # Sample user seed data
│   ├── raw_orders.csv       # Sample order seed data
│   └── schema.yml           # Seed column documentation & tests
├── models/
│   ├── staging/
│   │   ├── stg_users.sql    # Staged users (renames + type casts)
│   │   ├── stg_orders.sql   # Staged orders (renames + normalisation)
│   │   └── schema.yml       # Staging model documentation & tests
│   └── marts/
│       ├── dim_customers.sql  # Customer dimension with order metrics
│       ├── fct_orders.sql     # Orders fact table with customer info
│       └── schema.yml         # Mart model documentation & tests
├── macros/
│   ├── cents_to_dollars.sql       # Utility macro for currency conversion
│   └── generate_schema_name.sql   # Custom schema name generation
└── tests/
    └── assert_positive_completed_order_amounts.sql  # Singular test
```

## Data Flow

```
seeds (CSV)
  └── raw_users, raw_orders
        └── staging (views)
              ├── stg_users
              └── stg_orders
                    └── marts (tables)
                          ├── dim_customers
                          └── fct_orders
```

## Prerequisites

- Python 3.8+
- DBT Core with the appropriate adapter (e.g. `dbt-postgres`)

## Setup

1. **Install DBT**

   ```bash
   pip install dbt-postgres
   ```

2. **Install DBT packages**

   ```bash
   dbt deps
   ```

3. **Configure your connection**

   Copy `profiles.yml` to `~/.dbt/profiles.yml` (or set `DBT_PROFILES_DIR`) and set
   the required environment variables:

   | Variable       | Description                   | Default       |
   |----------------|-------------------------------|---------------|
   | `DBT_HOST`     | Database host                 | `localhost`   |
   | `DBT_PORT`     | Database port                 | `5432`        |
   | `DBT_USER`     | Database user                 | –             |
   | `DBT_PASSWORD` | Database password             | –             |
   | `DBT_DBNAME`   | Database name                 | `herocoders`  |
   | `DBT_SCHEMA`   | Target schema                 | `public`      |

## Usage

```bash
# Load seed data
dbt seed

# Run all models
dbt run

# Test all models and seeds
dbt test

# Run seeds, models, and tests in one command
dbt build
```

## Models

### Staging

| Model        | Materialisation | Description                                      |
|--------------|-----------------|--------------------------------------------------|
| `stg_users`  | View            | Users from seed with renamed columns & type casts |
| `stg_orders` | View            | Orders from seed with renamed columns & status normalisation |

### Marts

| Model           | Materialisation | Description                                        |
|-----------------|-----------------|----------------------------------------------------|
| `dim_customers` | Table           | One row per customer with aggregated order metrics |
| `fct_orders`    | Table           | One row per order enriched with customer details   |

## Tests

Generic schema tests (unique, not_null, accepted_values, relationships) are defined
inline in each `schema.yml`. A singular test lives in `tests/`:

- `assert_positive_completed_order_amounts` – ensures no completed order has a
  zero or negative amount.
