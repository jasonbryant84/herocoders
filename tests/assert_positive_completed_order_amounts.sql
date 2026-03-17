-- Assert that no completed order has a non-positive amount
select
    order_id,
    amount,
    status
from {{ ref('fct_orders') }}
where status = 'completed'
  and amount <= 0
