/*Business Context: The inventory team wants to identify the best-performing product in each category to optimize stock levels and featured
 promotions.
 
 Task: For each product category, find the product with the highest total revenue. Return category, product_name, and total_revenue. Order by        
 category alphabetically.
 */

WITH ranked_products AS (
      SELECT
          p.category,
          p.product_name,
          SUM(oi.quantity * p.price) AS total_revenue,
          ROW_NUMBER() OVER (
              PARTITION BY p.category     -- Separate ranking for each category
              ORDER BY SUM(oi.quantity * p.price) DESC    -- Highest revenue first
          ) AS rank
      FROM products p
      JOIN order_items oi ON p.product_id = oi.product_id
      GROUP BY p.product_id, p.product_name, p.category  -- Group by product
  )
  SELECT
      category,
      product_name,
      total_revenue
  FROM ranked_products
  WHERE rank = 1
  ORDER BY category;