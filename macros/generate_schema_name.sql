{#
  generate_schema_name(custom_schema_name, node)

  Overrides DBT's default schema naming to always prefix the target schema.
  When a model specifies a custom +schema, the resulting schema will be
  "<target.schema>_<custom_schema_name>" (e.g. "public_staging", "public_marts").
  When no custom schema is set the model lands in the default target schema.

  Arguments:
    custom_schema_name (str | none) : The +schema value configured on the model.
    node               (dict)       : The DBT node context object (unused here).
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
