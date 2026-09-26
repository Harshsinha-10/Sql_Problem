# FIRST_VALUE() and LAST_VALUE() - Complete Guide

## Overview

`FIRST_VALUE()` and `LAST_VALUE()` return the first or last value in an ordered set of values within a window frame. They're essential for accessing boundary values without complex subqueries.

## Syntax

```sql
FIRST_VALUE(column) OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
    [frame_specification]
)

LAST_VALUE(column) OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
    [frame_specification]
)
```

---

## Key Characteristics

- ✅ Access first or last value in the window
- ✅ Requires ORDER BY clause
- ⚠️ **LAST_VALUE requires explicit frame specification** (common gotcha!)
- ✅ Useful for comparisons to initial/final values
- ✅ Avoids complex self-joins or subqueries

---

## Understanding FIRST_VALUE()

### Example 1: Basic FIRST_VALUE

```sql
-- Compare each order to the first order ever placed
SELECT 
    order_date,
    order_id,
    total_amount,
    FIRST_VALUE(total_amount) OVER (ORDER BY order_date) as first_order_amount,
    total_amount - FIRST_VALUE(total_amount) OVER (ORDER BY order_date) as diff_from_first
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | first_order_amount | diff_from_first |
|------------|----------|--------------|--------------------|-----------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00            | 0.00            |
| 2026-09-03 | 1002     | 350.00       | 1245.00            | -895.00         |
| 2026-09-05 | 1003     | 145.00       | 1245.00            | -1100.00        |
| 2026-09-07 | 1004     | 1200.00      | 1245.00            | -45.00          |
| 2026-09-10 | 1005     | 40.00        | 1245.00            | -1205.00        |
| 2026-09-12 | 1006     | 120.00       | 1245.00            | -1125.00        |
| 2026-09-15 | 1007     | 25.00        | 1245.00            | -1125.00        |
```

**Understanding:** Every row shows the same first_order_amount (1245.00) because it's the first value when ordered by date.

### Example 2: FIRST_VALUE with PARTITION BY

```sql
-- Compare each customer's orders to their first order
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as first_order_amount,
    FIRST_VALUE(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as first_order_date,
    o.order_date - FIRST_VALUE(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as days_since_first_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | first_order_amount | first_order_date | days_since_first_order |
|---------------|------------|--------------|--------------------|-----------------|-----------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 1245.00            | 2026-09-01      | 0                     |
| Alice Johnson | 2026-09-05 | 145.00       | 1245.00            | 2026-09-01      | 4                     |
| Alice Johnson | 2026-09-15 | 25.00        | 1245.00            | 2026-09-01      | 14                    |
| Bob Smith     | 2026-09-03 | 350.00       | 350.00             | 2026-09-03      | 0                     |
| Bob Smith     | 2026-09-12 | 120.00       | 350.00             | 2026-09-03      | 9                     |
| Carol White   | 2026-09-07 | 1200.00      | 1200.00            | 2026-09-07      | 0                     |
| David Brown   | 2026-09-10 | 40.00        | 40.00              | 2026-09-10      | 0                     |
```

**Understanding:** Each customer's partition has its own "first value". Alice's first order is 1245.00, Bob's is 350.00, etc.

---

## Understanding LAST_VALUE() - THE GOTCHA!

### ⚠️ The Default Frame Problem

**This is the #1 mistake with LAST_VALUE:**

```sql
-- ❌ WRONG: This doesn't work as expected!
SELECT 
    order_date,
    order_id,
    total_amount,
    LAST_VALUE(total_amount) OVER (ORDER BY order_date) as last_order_amount
FROM orders
ORDER BY order_date;
```

**Unexpected Result:**
```
| order_date | order_id | total_amount | last_order_amount |
|------------|----------|--------------|-------------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00           | ← Not the last order!
| 2026-09-03 | 1002     | 350.00       | 350.00            | ← Not the last order!
| 2026-09-05 | 1003     | 145.00       | 145.00            | ← Not the last order!
| 2026-09-07 | 1004     | 1200.00      | 1200.00           | ← Not the last order!
```

**Why?** The default frame with ORDER BY is:
```sql
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

So "last value" means "last value up to and including the current row" = the current row itself!

### ✅ The Correct Way

```sql
-- ✅ RIGHT: Specify the full frame
SELECT 
    order_date,
    order_id,
    total_amount,
    LAST_VALUE(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as last_order_amount
FROM orders
ORDER BY order_date;
```

**Correct Result:**
```
| order_date | order_id | total_amount | last_order_amount |
|------------|----------|--------------|-------------------|
| 2026-09-01 | 1001     | 1245.00      | 25.00             | ← Now correct!
| 2026-09-03 | 1002     | 350.00       | 25.00             | ← Same for all
| 2026-09-05 | 1003     | 145.00       | 25.00             |
| 2026-09-07 | 1004     | 1200.00      | 25.00             |
| 2026-09-10 | 1005     | 40.00        | 25.00             |
| 2026-09-12 | 1006     | 120.00       | 25.00             |
| 2026-09-15 | 1007     | 25.00        | 25.00             | ← Last order
```

**Understanding:** `UNBOUNDED FOLLOWING` tells SQL to look at all rows up to the end of the partition, not just up to the current row.

---

## Visual Frame Understanding

```
Rows:  [1] [2] [3] [4] [5]
               ↑
         Current Row

Default frame (with ORDER BY):
RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
[1] [2] [3]
      ↑
   LAST_VALUE returns row 3 (current)

Correct frame for true last:
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
[1] [2] [3] [4] [5]
               ↑
         LAST_VALUE returns row 5 (actual last)
```

---

## Common Use Cases

### Use Case 1: Growth from First to Current

```sql
-- Compare each order to the first order
SELECT 
    order_date,
    total_amount,
    FIRST_VALUE(total_amount) OVER (ORDER BY order_date) as baseline_amount,
    ROUND(
        ((total_amount - FIRST_VALUE(total_amount) OVER (ORDER BY order_date)) * 100.0) /
        FIRST_VALUE(total_amount) OVER (ORDER BY order_date),
        2
    ) as pct_change_from_baseline
FROM orders
ORDER BY order_date;
```

### Use Case 2: Compare to Best/Worst

```sql
-- Compare each product to the best and worst sellers
WITH product_sales AS (
    SELECT 
        p.product_name,
        p.category,
        SUM(oi.quantity) as units_sold
    FROM products p
    LEFT JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT 
    product_name,
    category,
    units_sold,
    
    -- Best seller
    FIRST_VALUE(units_sold) OVER (ORDER BY units_sold DESC) as best_seller_units,
    
    -- Worst seller
    FIRST_VALUE(units_sold) OVER (ORDER BY units_sold ASC) as worst_seller_units,
    
    -- How far from best
    FIRST_VALUE(units_sold) OVER (ORDER BY units_sold DESC) - units_sold as units_behind_leader
    
FROM product_sales
ORDER BY units_sold DESC;
```

### Use Case 3: Customer Lifecycle Analysis

```sql
-- Compare customer's behavior: first vs current vs last order
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    
    -- First order
    FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as first_order_amount,
    
    -- Last order
    LAST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as last_order_amount,
    
    -- Customer evolution
    CASE 
        WHEN o.order_date = FIRST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) THEN 'First Order'
        WHEN o.order_date = LAST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) THEN 'Most Recent Order'
        ELSE 'Middle Order'
    END as order_position
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | first_order_amount | last_order_amount | order_position     |
|---------------|------------|--------------|--------------------|-----------------|--------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 1245.00            | 25.00           | First Order        |
| Alice Johnson | 2026-09-05 | 145.00       | 1245.00            | 25.00           | Middle Order       |
| Alice Johnson | 2026-09-15 | 25.00        | 1245.00            | 25.00           | Most Recent Order  |
```

### Use Case 4: Price Range Analysis

```sql
-- Compare each product's price to the category's min and max
SELECT 
    category,
    product_name,
    price,
    
    -- Category's cheapest (order ASC, take first)
    FIRST_VALUE(price) OVER (
        PARTITION BY category 
        ORDER BY price ASC
    ) as category_min_price,
    
    -- Category's most expensive (order DESC, take first)
    FIRST_VALUE(price) OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as category_max_price,
    
    -- Position in range (0 = cheapest, 1 = most expensive)
    ROUND(
        (price - FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price ASC)) /
        NULLIF(
            FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price DESC) -
            FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price ASC),
            0
        ),
        2
    ) as price_position_in_range
    
FROM products
ORDER BY category, price;
```

### Use Case 5: Retention Analysis

```sql
-- Track customer value from first order to most recent
WITH customer_lifetime AS (
    SELECT 
        c.customer_id,
        c.name,
        COUNT(o.order_id) as total_orders,
        SUM(o.total_amount) as lifetime_value,
        
        FIRST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as first_order_value,
        
        LAST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as last_order_value,
        
        FIRST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as first_order_date,
        
        LAST_VALUE(o.order_date) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as last_order_date
        
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, o.order_date, o.total_amount
)
SELECT DISTINCT
    name,
    total_orders,
    lifetime_value,
    first_order_value,
    last_order_value,
    first_order_date,
    last_order_date,
    last_order_date - first_order_date as customer_lifespan_days,
    CASE 
        WHEN last_order_value > first_order_value THEN 'Growing'
        WHEN last_order_value < first_order_value THEN 'Declining'
        ELSE 'Stable'
    END as customer_trend
FROM customer_lifetime;
```

---

## Advanced Patterns

### Pattern 1: Boundary Comparison

```sql
-- Compare each value to both boundaries
SELECT 
    product_name,
    price,
    
    FIRST_VALUE(price) OVER w as min_price,
    LAST_VALUE(price) OVER w as max_price,
    
    -- Distance from boundaries
    price - FIRST_VALUE(price) OVER w as above_min,
    LAST_VALUE(price) OVER w - price as below_max,
    
    -- Relative position (0 to 1)
    ROUND(
        (price - FIRST_VALUE(price) OVER w) /
        NULLIF(LAST_VALUE(price) OVER w - FIRST_VALUE(price) OVER w, 0),
        2
    ) as position_in_range
    
FROM products
WINDOW w AS (
    ORDER BY price
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
);
```

### Pattern 2: Anchored Growth Rate

```sql
-- Track growth from a fixed baseline (first month)
WITH monthly_sales AS (
    SELECT 
        DATE_TRUNC('month', order_date) as month,
        SUM(total_amount) as monthly_total
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT 
    month,
    monthly_total,
    FIRST_VALUE(monthly_total) OVER (ORDER BY month) as baseline_month,
    ROUND(
        ((monthly_total - FIRST_VALUE(monthly_total) OVER (ORDER BY month)) * 100.0) /
        FIRST_VALUE(monthly_total) OVER (ORDER BY month),
        2
    ) as growth_pct_from_baseline
FROM monthly_sales
ORDER BY month;
```

### Pattern 3: High-Water Mark

```sql
-- Track the highest value seen so far (running maximum)
SELECT 
    order_date,
    total_amount,
    FIRST_VALUE(total_amount) OVER (
        ORDER BY total_amount DESC, order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as all_time_high,
    CASE 
        WHEN total_amount = FIRST_VALUE(total_amount) OVER (
            ORDER BY total_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) THEN 'NEW RECORD!'
        ELSE ''
    END as record_flag
FROM orders
ORDER BY order_date;
```

### Pattern 4: Category Leaders

```sql
-- Show the leader (highest price) in each category
SELECT 
    category,
    product_name,
    price,
    
    -- Leader product name
    FIRST_VALUE(product_name) OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as category_leader,
    
    -- Leader price
    FIRST_VALUE(price) OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as leader_price,
    
    -- Am I the leader?
    CASE 
        WHEN product_name = FIRST_VALUE(product_name) OVER (
            PARTITION BY category ORDER BY price DESC
        ) THEN '👑 Leader'
        ELSE ''
    END as status
    
FROM products
ORDER BY category, price DESC;
```

---

## FIRST_VALUE vs MIN/MAX

### When to Use Each

```sql
-- Both find the same value, but different use cases
SELECT 
    product_name,
    price,
    
    -- FIRST_VALUE: Get the value AND control ordering
    FIRST_VALUE(product_name) OVER (ORDER BY price ASC) as cheapest_product,
    FIRST_VALUE(price) OVER (ORDER BY price ASC) as cheapest_price,
    
    -- MIN/MAX: Just the numeric value
    MIN(price) OVER () as min_price,
    MAX(price) OVER () as max_price
    
FROM products;
```

**Use FIRST_VALUE when:**
- ✅ You need non-numeric columns (names, dates) from the first/last row
- ✅ You want specific ordering (ORDER BY multiple columns)
- ✅ You need context from the "first" row (e.g., first customer's name)

**Use MIN/MAX when:**
- ✅ You only need the numeric minimum/maximum
- ✅ Simpler syntax is preferred
- ✅ You don't care which row it came from

---

## Common Mistakes and Solutions

### Mistake 1: Forgetting Frame Specification for LAST_VALUE

```sql
-- ❌ WRONG: Returns current row, not last row
LAST_VALUE(amount) OVER (ORDER BY date)

-- ✅ RIGHT: Explicitly specify full frame
LAST_VALUE(amount) OVER (
    ORDER BY date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

### Mistake 2: Using with Wrong Frame Type

```sql
-- ⚠️ RANGE can cause unexpected results with duplicate values
LAST_VALUE(amount) OVER (
    ORDER BY date
    RANGE BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)

-- ✅ BETTER: Use ROWS for predictable behavior
LAST_VALUE(amount) OVER (
    ORDER BY date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

### Mistake 3: Not Using PARTITION BY When Needed

```sql
-- ❌ WRONG: Mixing first values across customers
SELECT 
    customer_name,
    order_date,
    amount,
    FIRST_VALUE(amount) OVER (ORDER BY order_date) as first_order
FROM customer_orders;
-- Shows first order OVERALL, not first per customer

-- ✅ RIGHT: Partition by customer
SELECT 
    customer_name,
    order_date,
    amount,
    FIRST_VALUE(amount) OVER (
        PARTITION BY customer_id 
        ORDER BY order_date
    ) as first_order
FROM customer_orders;
```

### Mistake 4: Redundant Calculations

```sql
-- ❌ INEFFICIENT: Repeating same window function
SELECT 
    product_name,
    price,
    FIRST_VALUE(price) OVER (ORDER BY price) as min_p,
    price - FIRST_VALUE(price) OVER (ORDER BY price) as diff,
    FIRST_VALUE(price) OVER (ORDER BY price) * 0.8 as discount
FROM products;

-- ✅ EFFICIENT: Use CTE to calculate once
WITH with_first AS (
    SELECT 
        product_name,
        price,
        FIRST_VALUE(price) OVER (ORDER BY price) as min_p
    FROM products
)
SELECT 
    product_name,
    price,
    min_p,
    price - min_p as diff,
    min_p * 0.8 as discount
FROM with_first;
```

---

## Practice Exercises

### Exercise 1: First Order Comparison
Show each customer's orders compared to their first order.

<details>
<summary>Solution</summary>

```sql
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as first_order_amount,
    o.total_amount - FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as change_from_first
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```
</details>

### Exercise 2: Price Range Position
Show where each product falls in its category's price range.

<details>
<summary>Solution</summary>

```sql
SELECT 
    category,
    product_name,
    price,
    FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price) as cat_min,
    LAST_VALUE(price) OVER (
        PARTITION BY category 
        ORDER BY price
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as cat_max,
    ROUND(
        (price - FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price)) * 100.0 /
        NULLIF(
            LAST_VALUE(price) OVER (
                PARTITION BY category ORDER BY price
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            ) - 
            FIRST_VALUE(price) OVER (PARTITION BY category ORDER BY price),
            0
        ),
        2
    ) as pct_of_range
FROM products
ORDER BY category, price;
```
</details>

### Exercise 3: Customer Trend
Identify if customers are growing or declining in order value.

<details>
<summary>Solution</summary>

```sql
WITH customer_boundaries AS (
    SELECT 
        c.customer_id,
        c.name,
        FIRST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as first_order,
        LAST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT DISTINCT
    name,
    first_order,
    last_order,
    last_order - first_order as change,
    CASE 
        WHEN last_order > first_order THEN 'Growing'
        WHEN last_order < first_order THEN 'Declining'
        ELSE 'Stable'
    END as trend
FROM customer_boundaries;
```
</details>

---

## Summary

**FIRST_VALUE() and LAST_VALUE() are perfect for:**
- ✅ Comparing to baseline/benchmark values
- ✅ Tracking growth from first observation
- ✅ Customer lifecycle analysis
- ✅ Price range positioning
- ✅ Boundary comparisons

**Critical Points:**
1. **LAST_VALUE requires explicit frame specification!**
2. Use `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`
3. FIRST_VALUE is straightforward, LAST_VALUE is tricky
4. Can access any column (not just numeric)
5. Use with PARTITION BY for group-level first/last values

**Remember:**
- FIRST_VALUE: Usually works as expected
- LAST_VALUE: **Always specify the full frame!**
- Use MIN/MAX for simple numeric comparisons
- Use FIRST/LAST_VALUE when you need context from the boundary rows

---

**Next:** Learn about frame specifications and moving averages!
