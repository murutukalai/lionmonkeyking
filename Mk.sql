SELECT order_id, total_cost, discount, (total_cost - discount) AS discounted_cost
FROM orders;
