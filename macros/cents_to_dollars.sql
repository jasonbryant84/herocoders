{#
  cents_to_dollars(column_name, scale=2)

  Converts an integer cents value to a decimal dollars value.

  Arguments:
    column_name (str) : The column expression holding the value in cents.
    scale       (int) : Number of decimal places to retain (default: 2).

  Returns:
    A numeric expression: column_name / 100.0, rounded to `scale` decimals.

  Example:
    {{ cents_to_dollars('price_cents') }}  --> (price_cents / 100.0)::numeric(16, 2)
#}
{% macro cents_to_dollars(column_name, scale=2) %}
    ({{ column_name }} / 100.0)::numeric(16, {{ scale }})
{% endmacro %}
