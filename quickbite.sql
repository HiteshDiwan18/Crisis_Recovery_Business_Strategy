Monthly Orders: Compare total orders across pre-crisis (Jan–May 2025) vs crisis 
(Jun–Sep 2025). How severe is the decline?

SELECT
  CASE
    WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31'
      THEN 'Pre-Crisis (Jan–May 2025)'
    WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
      THEN 'Crisis (Jun–Sep 2025)'
  END AS period,
  COUNT(order_id) AS total_orders
FROM fact_orders
WHERE order_timestamp BETWEEN '2025-01-01' AND '2025-09-30'
GROUP BY period;

Used SQL CTEs to compare pre-crisis vs crisis periods, quantifying a 69% decline in orders, indicating a severe business disruption.

Which top 5 city groups experienced the highest percentage decline in orders
during the crisis period compared to the pre-crisis period?

 SELECT
        dim_customer.city,
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31' THEN 1 END) AS pre_orders,
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END) AS crisis_orders
    FROM fact_orders
    join dim_customer
		on fact_orders.customer_id = dim_customer.customer_id
    GROUP BY city;
    
    WITH order_counts AS (
 SELECT
        dim_customer.city,
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31' THEN 1 END) AS pre_orders,
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END) AS crisis_orders
    FROM fact_orders
    join dim_customer
		on fact_orders.customer_id = dim_customer.customer_id
    GROUP BY city)
SELECT
    pre_orders,
    crisis_orders,
    ROUND(
        ((pre_orders - crisis_orders) * 100.0 / pre_orders),
        2
    ) AS percentage_decline
FROM order_counts;
Among restaurants with at least 50 pre-crisis orders, which top 10 high-volume 
restaurants experienced the largest percentage decline in order counts during 
the crisis period?
WITH restaurant_orders AS (
    SELECT
        r.restaurant_name,
        COUNT(CASE WHEN o.order_timestamp BETWEEN '2025-01-01' AND '2025-05-31' THEN 1 END) AS pre_orders,
        COUNT(CASE WHEN o.order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END) AS crisis_orders
    FROM fact_orders o
    JOIN dim_restaurant r ON o.restaurant_id = r.restaurant_id
    GROUP BY r.restaurant_name
)
SELECT
    restaurant_name,
    pre_orders,
    crisis_orders,
    ROUND(((pre_orders - crisis_orders) * 100.0 / pre_orders), 2) AS decline_pct
FROM restaurant_orders
WHERE pre_orders >= 50
ORDER BY decline_pct DESC
LIMIT 10;


Cancellation Analysis: What is the cancellation rate trend pre-crisis vs crisis, 
and which cities are most affected?
Cancellation Rate by Period
SELECT
    CASE
        WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31' THEN 'Pre-Crisis'
        WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 'Crisis'
    END AS period,
    ROUND(
        COUNT(CASE WHEN is_Cancelled = 'Y' THEN 1 END) * 100.0 / COUNT(*),
        2
    ) AS cancellation_rate
FROM fact_orders
GROUP BY period;

Cities with Highest Cancellation Increase

SELECT
    city,
    ROUND(
        COUNT(CASE WHEN is_Cancelled = 'Y'
              AND order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END) * 100.0 /
        COUNT(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30' THEN 1 END),
        2
    ) AS crisis_cancel_rate
FROM fact_orders
join dim_customer
	on fact_orders.customer_id = dim_customer.customer_id
GROUP BY city
ORDER BY crisis_cancel_rate Desc;

8. Revenue Impact: Estimate revenue loss from pre-crisis vs crisis (based on 
subtotal, discount, and delivery fee).

SELECT
    SUM(CASE WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31'
        THEN subtotal_amount - discount_amount + delivery_fee END) AS pre_revenue,
    SUM(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
        THEN subtotal_amount - discount_amount + delivery_fee END) AS crisis_revenue,
    SUM(CASE WHEN order_timestamp BETWEEN '2025-01-01' AND '2025-05-31'
        THEN subtotal_amount - discount_amount + delivery_fee END)
    -
    SUM(CASE WHEN order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
        THEN subtotal_amount - discount_amount + delivery_fee END) AS revenue_loss
FROM fact_orders;


10.Customer Lifetime Decline: Which high-value customers (top 5% by total 
spend before the crisis) showed the largest drop in order frequency and ratings 
during the crisis? What common patterns (e.g., location, cuisine preference, 
delivery delays) do they share?

WITH top_customers AS (
    SELECT
        customer_id,
        SUM(subtotal_amount) AS total_spend
    FROM fact_orders
    WHERE order_timestamp BETWEEN '2025-01-01' AND '2025-05-31'
    GROUP BY customer_id
    ORDER BY total_spend DESC
    )
SELECT
    c.customer_id,
    COUNT(o.order_id) AS crisis_orders,
    ROUND(AVG(rating), 2) AS crisis_rating,
    cu.city,
    dim_restaurant.cuisine_type
FROM top_customers c
LEFT JOIN fact_orders o
    ON c.customer_id = o.customer_id
    AND o.order_timestamp BETWEEN '2025-06-01' AND '2025-09-30'
JOIN dim_customer cu ON c.customer_id = cu.customer_id
JOIN dim_restaurant ON o.restaurant_id = dim_restaurant.restaurant_id
join fact_ratings on o.order_id = fact_ratings.order_id
GROUP BY c.customer_id, cu.city, dim_restaurant.cuisine_type
ORDER BY crisis_orders ASC;
