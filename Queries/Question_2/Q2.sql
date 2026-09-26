-- Question 2
-- Now, marketing wants to run a loyalty promotion targeting high-value customers.

-- Find the top 2 customers who have spent the most money overall across all their orders combined.

-- Return the customer's first name, last name, and their total spending (aliased as total_spent).

-- Sort the results so the highest spender is at the top.


SELECT 
    c.first_name,
    c.last_name,
    SUM(o.total_amount) AS total_spent
FROM 
    customers c
JOIN 
    orders o ON c.customer_id = o.customer_id
GROUP BY 
    c.customer_id, c.first_name, c.last_name
ORDER BY 
    total_spent DESC
LIMIT 2;




