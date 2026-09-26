# Aggregate Window Functions (SUM, AVG, COUNT, MIN, MAX) - Complete Guide

## Overview

Aggregate window functions apply familiar aggregate operations (SUM, AVG, COUNT, MIN, MAX) **without collapsing rows**. This is the fundamental difference between window functions and GROUP BY.

## The Key Insight

```sql
-- GROUP BY: Collapses to one row per group
SELECT 
    category,
    AVG(price) as avg_price
FROM products
GROUP BY category;
-- Result: 3 rows (one per category)

-- Window Function: Keeps all rows, adds aggregate info
SELECT 
    category,
    product_name,
    price,
    AVG(price) OVER (PARTITION BY category) as avg_category_price
FROM products;
-- Result: 5 rows (all products) with category average added
```

---

## Syntax

```sql
{SUM | AVG | COUNT | MIN | MAX}(expression) OVER (
    [PARTITION BY partition_expression]
    [ORDER BY sort_expression]
    [frame_specification]
)
```

---

## SUM() OVER - Running and Total Sums

### Example 1: Total Sum (All Rows)

```sql
-- Each order shows total company revenue
SELECT 
    order_id,
    order_date,
    total_amount,
    SUM(total_amount) OVER () as total_revenue,
    ROUND(total_amount * 100.0 / SUM(total_amount) OVER (), 2) as pct_of_total
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_id | order_date | total_amount | total_revenue | pct_of_total |
|----------|------------|--------------|---------------|--------------|
| 1001     | 2026-09-01 | 1245.00      | 3125.00       | 39.84        |
| 1002     | 2026-09-03 | 350.00       | 3125.00       | 11.20        |
| 1003     | 2026-09-05 | 145.00       | 3125.00       | 4.64         |
| 1004     | 2026-09-07 | 1200.00      | 3125.00       | 38.40        |
| 1005     | 2026-09-10 | 40.00        | 3125.00       | 1.28         |
| 1006     | 2026-09-12 | 120.00       | 3125.00       | 3.84         |
| 1007     | 2026-09-15 | 25.00        | 3125.00       | 0.80         |
```

### Example 2: Running Total (ORDER BY)

```sql
-- Cumulative revenue over time
SELECT 
    order_date,
    order_id,
    total_amount,
    SUM(total_amount) OVER (ORDER BY order_date, order_id) as running_total
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | running_total |
|------------|----------|--------------|---------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00       |
| 2026-09-03 | 1002     | 350.00       | 1595.00       | ← 1245 + 350
| 2026-09-05 | 1003     | 145.00       | 1740.00       | ← 1595 + 145
| 2026-09-07 | 1004     | 1200.00      | 2940.00       | ← 1740 + 1200
| 2026-09-10 | 1005     | 40.00        | 2980.00       |
| 2026-09-12 | 1006     | 120.00       | 3100.00       |
| 2026-09-15 | 1007     | 25.00        | 3125.00       | ← Total reached
```

**Understanding:** Each row's running_total includes all previous orders plus the current order.

### Example 3: Running Total Per Group

```sql
-- Running total per customer
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as customer_running_total
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | customer_running_total |
|---------------|------------|--------------|------------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 1245.00                |
| Alice Johnson | 2026-09-05 | 145.00       | 1390.00                | ← Resets per customer
| Alice Johnson | 2026-09-15 | 25.00        | 1415.00                |
| Bob Smith     | 2026-09-03 | 350.00       | 350.00                 | ← Starts fresh
| Bob Smith     | 2026-09-12 | 120.00       | 470.00                 |
| Carol White   | 2026-09-07 | 1200.00      | 1200.00                |
| David Brown   | 2026-09-10 | 40.00        | 40.00                  |
```

---

## AVG() OVER - Averages and Moving Averages

### Example 4: Overall Average

```sql
-- Compare each order to the average order value
SELECT 
    order_id,
    total_amount,
    ROUND(AVG(total_amount) OVER (), 2) as avg_order_value,
    ROUND(total_amount - AVG(total_amount) OVER (), 2) as diff_from_avg,
    CASE 
        WHEN total_amount > AVG(total_amount) OVER () THEN 'Above Average'
        WHEN total_amount < AVG(total_amount) OVER () THEN 'Below Average'
        ELSE 'Average'
    END as classification
FROM orders
ORDER BY total_amount DESC;
```

**Result:**
```
| order_id | total_amount | avg_order_value | diff_from_avg | classification |
|----------|--------------|-----------------|---------------|----------------|
| 1001     | 1245.00      | 446.43          | 798.57        | Above Average  |
| 1004     | 1200.00      | 446.43          | 753.57        | Above Average  |
| 1002     | 350.00       | 446.43          | -96.43        | Below Average  |
| 1003     | 145.00       | 446.43          | -301.43       | Below Average  |
| 1006     | 120.00       | 446.43          | -326.43       | Below Average  |
| 1005     | 40.00        | 446.43          | -406.43       | Below Average  |
| 1007     | 25.00        | 446.43          | -421.43       | Below Average  |
```

### Example 5: Running Average

```sql
-- Average of all orders up to this point
SELECT 
    order_date,
    total_amount,
    ROUND(AVG(total_amount) OVER (ORDER BY order_date), 2) as running_avg
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | total_amount | running_avg |
|------------|--------------|-------------|
| 2026-09-01 | 1245.00      | 1245.00     | ← Just first order
| 2026-09-03 | 350.00       | 797.50      | ← Avg of 1245 and 350
| 2026-09-05 | 145.00       | 580.00      | ← Avg of first 3
| 2026-09-07 | 1200.00      | 735.00      | ← Avg of first 4
| 2026-09-10 | 40.00        | 596.00      | ← Avg of first 5
| 2026-09-12 | 120.00       | 516.67      | ← Avg of first 6
| 2026-09-15 | 25.00        | 446.43      | ← Avg of all 7
```

### Example 6: Moving Average (3-period)

```sql
-- 3-order moving average
SELECT 
    order_date,
    order_id,
    total_amount,
    ROUND(AVG(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_3
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | moving_avg_3 |
|------------|----------|--------------|--------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00      | ← Only 1 row
| 2026-09-03 | 1002     | 350.00       | 797.50       | ← 2 rows
| 2026-09-05 | 1003     | 145.00       | 580.00       | ← 3 rows (1245+350+145)/3
| 2026-09-07 | 1004     | 1200.00      | 565.00       | ← Last 3: (350+145+1200)/3
| 2026-09-10 | 1005     | 40.00        | 461.67       | ← Last 3: (145+1200+40)/3
| 2026-09-12 | 1006     | 120.00       | 453.33       | ← Last 3: (1200+40+120)/3
| 2026-09-15 | 1007     | 25.00        | 61.67        | ← Last 3: (40+120+25)/3
```

---

## COUNT() OVER - Counting Rows

### Example 7: Total Count

```sql
-- Show total number of orders on each row
SELECT 
    order_id,
    order_date,
    total_amount,
    COUNT(*) OVER () as total_orders,
    ROUND(100.0 / COUNT(*) OVER (), 2) as pct_of_orders
FROM orders
ORDER BY order_date;
```

### Example 8: Running Count

```sql
-- Count orders placed so far
SELECT 
    order_date,
    order_id,
    COUNT(*) OVER (ORDER BY order_date, order_id) as orders_so_far
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | orders_so_far |
|------------|----------|---------------|
| 2026-09-01 | 1001     | 1             |
| 2026-09-03 | 1002     | 2             |
| 2026-09-05 | 1003     | 3             |
| 2026-09-07 | 1004     | 4             |
| 2026-09-10 | 1005     | 5             |
| 2026-09-12 | 1006     | 6             |
| 2026-09-15 | 1007     | 7             |
```

### Example 9: Count Per Group

```sql
-- Number of orders per customer, shown on each order
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    COUNT(*) OVER (PARTITION BY c.customer_id) as customer_order_count
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | customer_order_count |
|---------------|------------|--------------|----------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 3                    |
| Alice Johnson | 2026-09-05 | 145.00       | 3                    |
| Alice Johnson | 2026-09-15 | 25.00        | 3                    |
| Bob Smith     | 2026-09-03 | 350.00       | 2                    |
| Bob Smith     | 2026-09-12 | 120.00       | 2                    |
| Carol White   | 2026-09-07 | 1200.00      | 1                    |
| David Brown   | 2026-09-10 | 40.00        | 1                    |
```

---

## MIN() and MAX() OVER - Minimum and Maximum

### Example 10: Overall Min/Max

```sql
-- Compare each order to company's smallest and largest
SELECT 
    order_id,
    total_amount,
    MIN(total_amount) OVER () as smallest_order,
    MAX(total_amount) OVER () as largest_order,
    total_amount - MIN(total_amount) OVER () as above_smallest,
    MAX(total_amount) OVER () - total_amount as below_largest
FROM orders
ORDER BY total_amount;
```

**Result:**
```
| order_id | total_amount | smallest_order | largest_order | above_smallest | below_largest |
|----------|--------------|----------------|---------------|----------------|---------------|
| 1007     | 25.00        | 25.00          | 1245.00       | 0.00           | 1220.00       |
| 1005     | 40.00        | 25.00          | 1245.00       | 15.00          | 1205.00       |
| 1006     | 120.00       | 25.00          | 1245.00       | 95.00          | 1125.00       |
| 1003     | 145.00       | 25.00          | 1245.00       | 120.00         | 1100.00       |
| 1002     | 350.00       | 25.00          | 1245.00       | 325.00         | 895.00        |
| 1004     | 1200.00      | 25.00          | 1245.00       | 1175.00        | 45.00         |
| 1001     | 1245.00      | 25.00          | 1245.00       | 1220.00        | 0.00          |
```

### Example 11: Running Min/Max

```sql
-- Track highest and lowest order values seen so far
SELECT 
    order_date,
    order_id,
    total_amount,
    MIN(total_amount) OVER (ORDER BY order_date, order_id) as lowest_so_far,
    MAX(total_amount) OVER (ORDER BY order_date, order_id) as highest_so_far,
    CASE 
        WHEN total_amount = MAX(total_amount) OVER (ORDER BY order_date, order_id)
        THEN '🏆 New Record High!'
        ELSE ''
    END as record_flag
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | lowest_so_far | highest_so_far | record_flag          |
|------------|----------|--------------|---------------|----------------|---------------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00       | 1245.00        | 🏆 New Record High! |
| 2026-09-03 | 1002     | 350.00       | 350.00        | 1245.00        |                     |
| 2026-09-05 | 1003     | 145.00       | 145.00        | 1245.00        |                     |
| 2026-09-07 | 1004     | 1200.00      | 145.00        | 1245.00        |                     |
| 2026-09-10 | 1005     | 40.00        | 40.00         | 1245.00        |                     |
| 2026-09-12 | 1006     | 120.00       | 40.00         | 1245.00        |                     |
| 2026-09-15 | 1007     | 25.00        | 25.00         | 1245.00        |                     |
```

### Example 12: Min/Max Per Category

```sql
-- Compare each product to category extremes
SELECT 
    category,
    product_name,
    price,
    MIN(price) OVER (PARTITION BY category) as category_min,
    MAX(price) OVER (PARTITION BY category) as category_max,
    CASE 
        WHEN price = MAX(price) OVER (PARTITION BY category) THEN 'Most Expensive'
        WHEN price = MIN(price) OVER (PARTITION BY category) THEN 'Least Expensive'
        ELSE 'Mid-Range'
    END as price_position
FROM products
ORDER BY category, price DESC;
```

---

## Combining Multiple Aggregates

### Example 13: Comprehensive Statistics

```sql
-- Show all key statistics for each customer
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    
    -- Count
    COUNT(*) OVER (PARTITION BY c.customer_id) as total_orders,
    
    -- Sum
    SUM(o.total_amount) OVER (PARTITION BY c.customer_id) as lifetime_value,
    
    -- Average
    ROUND(AVG(o.total_amount) OVER (PARTITION BY c.customer_id), 2) as avg_order_value,
    
    -- Min and Max
    MIN(o.total_amount) OVER (PARTITION BY c.customer_id) as smallest_order,
    MAX(o.total_amount) OVER (PARTITION BY c.customer_id) as largest_order,
    
    -- Running total
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as running_total
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

---

## Common Use Cases

### Use Case 1: Contribution Analysis

```sql
-- What percentage does each category contribute to total sales?
WITH category_sales AS (
    SELECT 
        p.category,
        SUM(p.price * oi.quantity) as category_revenue
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.category
)
SELECT 
    category,
    category_revenue,
    SUM(category_revenue) OVER () as total_revenue,
    ROUND(category_revenue * 100.0 / SUM(category_revenue) OVER (), 2) as pct_of_total
FROM category_sales
ORDER BY category_revenue DESC;
```

### Use Case 2: Year-to-Date Calculations

```sql
-- YTD revenue per customer
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id, EXTRACT(YEAR FROM o.order_date)
        ORDER BY o.order_date
    ) as ytd_spending
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

### Use Case 3: Cumulative Percentage

```sql
-- Cumulative percentage of total revenue
WITH ordered_orders AS (
    SELECT 
        order_id,
        order_date,
        total_amount,
        SUM(total_amount) OVER (ORDER BY order_date) as cumulative_revenue,
        SUM(total_amount) OVER () as total_revenue
    FROM orders
)
SELECT 
    order_id,
    order_date,
    total_amount,
    cumulative_revenue,
    ROUND(cumulative_revenue * 100.0 / total_revenue, 2) as cumulative_pct
FROM ordered_orders
ORDER BY order_date;
```

---

## Practice Exercises

### Exercise 1: Percentage of Total
Show each order with its percentage of total sales.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_id,
    total_amount,
    SUM(total_amount) OVER () as total_sales,
    ROUND(total_amount * 100.0 / SUM(total_amount) OVER (), 2) as pct_of_total
FROM orders
ORDER BY total_amount DESC;
```
</details>

### Exercise 2: Running Average
Calculate running average order value.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    order_id,
    total_amount,
    ROUND(AVG(total_amount) OVER (ORDER BY order_date, order_id), 2) as running_avg
FROM orders
ORDER BY order_date;
```
</details>

### Exercise 3: Customer Statistics
Show comprehensive statistics for each customer's orders.

<details>
<summary>Solution</summary>

```sql
SELECT 
    c.name,
    COUNT(*) OVER (PARTITION BY c.customer_id) as order_count,
    SUM(o.total_amount) OVER (PARTITION BY c.customer_id) as total_spent,
    ROUND(AVG(o.total_amount) OVER (PARTITION BY c.customer_id), 2) as avg_order,
    MIN(o.total_amount) OVER (PARTITION BY c.customer_id) as min_order,
    MAX(o.total_amount) OVER (PARTITION BY c.customer_id) as max_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name;
```
</details>

---

## Summary

**Aggregate window functions provide:**
- ✅ Row-level detail + aggregate context
- ✅ No need for self-joins or subqueries
- ✅ Running totals and averages
- ✅ Contribution analysis
- ✅ Moving averages

**Key Differences from GROUP BY:**
- GROUP BY: Collapses rows → summary only
- Window Functions: Keeps rows → detail + summary

**Remember:**
- `OVER ()` = all rows
- `OVER (ORDER BY ...)` = running calculation
- `OVER (PARTITION BY ...)` = separate calculations per group
- Frame specifications control the exact window size

---

**Next:** Explore ranking functions (ROW_NUMBER, RANK, DENSE_RANK, NTILE)!
