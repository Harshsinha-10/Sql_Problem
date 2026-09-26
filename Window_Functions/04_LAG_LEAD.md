# LAG() and LEAD() - Complete Guide

## Overview

`LAG()` and `LEAD()` are value functions that allow you to access data from **previous** or **following** rows without using self-joins. They're essential for period-over-period comparisons, trend analysis, and time series calculations.

## Syntax

```sql
LAG(column, offset, default) OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)

LEAD(column, offset, default) OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)
```

**Parameters:**
- `column`: The column value to retrieve
- `offset` (optional): Number of rows back/forward (default: 1)
- `default` (optional): Value to return if no row exists (default: NULL)

---

## Understanding LAG()

LAG() looks **backward** in the result set to retrieve values from previous rows.

### Example 1: Basic LAG - Previous Order

```sql
-- Compare each order to the previous order
SELECT 
    order_date,
    order_id,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as previous_order_amount
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | previous_order_amount |
|------------|----------|--------------|----------------------|
| 2026-09-01 | 1001     | 1245.00      | NULL                 | ← First row, no previous
| 2026-09-03 | 1002     | 350.00       | 1245.00              | ← Previous was 1245
| 2026-09-05 | 1003     | 145.00       | 350.00               | ← Previous was 350
| 2026-09-07 | 1004     | 1200.00      | 145.00               |
| 2026-09-10 | 1005     | 40.00        | 1200.00              |
| 2026-09-12 | 1006     | 120.00       | 40.00                |
| 2026-09-15 | 1007     | 25.00        | 120.00               |
```

**Visual Understanding:**
```
Row 1: 1245 → LAG = NULL (no previous row)
Row 2: 350  → LAG = 1245 (from Row 1)
Row 3: 145  → LAG = 350  (from Row 2)
Row 4: 1200 → LAG = 145  (from Row 3)
```

### Example 2: LAG with Default Value

```sql
-- Use 0 instead of NULL for the first row
SELECT 
    order_date,
    total_amount,
    LAG(total_amount, 1, 0) OVER (ORDER BY order_date) as previous_amount
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | total_amount | previous_amount |
|------------|--------------|-----------------|
| 2026-09-01 | 1245.00      | 0.00            | ← Default instead of NULL
| 2026-09-03 | 350.00       | 1245.00         |
| 2026-09-05 | 145.00       | 350.00          |
```

### Example 3: LAG with Different Offsets

```sql
-- Look back 1, 2, and 3 orders
SELECT 
    order_date,
    total_amount,
    LAG(total_amount, 1) OVER (ORDER BY order_date) as prev_1_order,
    LAG(total_amount, 2) OVER (ORDER BY order_date) as prev_2_orders,
    LAG(total_amount, 3) OVER (ORDER BY order_date) as prev_3_orders
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | total_amount | prev_1_order | prev_2_orders | prev_3_orders |
|------------|--------------|--------------|---------------|---------------|
| 2026-09-01 | 1245.00      | NULL         | NULL          | NULL          |
| 2026-09-03 | 350.00       | 1245.00      | NULL          | NULL          |
| 2026-09-05 | 145.00       | 350.00       | 1245.00       | NULL          |
| 2026-09-07 | 1200.00      | 145.00       | 350.00        | 1245.00       |
| 2026-09-10 | 40.00        | 1200.00      | 145.00        | 350.00        |
```

---

## Understanding LEAD()

LEAD() looks **forward** in the result set to retrieve values from following rows.

### Example 4: Basic LEAD - Next Order

```sql
-- Look ahead to the next order
SELECT 
    order_date,
    order_id,
    total_amount,
    LEAD(total_amount) OVER (ORDER BY order_date) as next_order_amount,
    LEAD(order_date) OVER (ORDER BY order_date) as next_order_date
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | next_order_amount | next_order_date |
|------------|----------|--------------|-------------------|-----------------|
| 2026-09-01 | 1001     | 1245.00      | 350.00            | 2026-09-03      |
| 2026-09-03 | 1002     | 350.00       | 145.00            | 2026-09-05      |
| 2026-09-05 | 1003     | 145.00       | 1200.00           | 2026-09-07      |
| 2026-09-07 | 1004     | 1200.00      | 40.00             | 2026-09-10      |
| 2026-09-10 | 1005     | 40.00        | 120.00            | 2026-09-12      |
| 2026-09-12 | 1006     | 120.00       | 25.00             | 2026-09-15      |
| 2026-09-15 | 1007     | 25.00        | NULL              | NULL            | ← Last row
```

---

## Common Use Cases

### Use Case 1: Period-over-Period Change

**Problem:** Calculate change from previous order.

```sql
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as previous_amount,
    total_amount - LAG(total_amount) OVER (ORDER BY order_date) as change,
    ROUND(
        (total_amount - LAG(total_amount) OVER (ORDER BY order_date)) * 100.0 /
        NULLIF(LAG(total_amount) OVER (ORDER BY order_date), 0),
        2
    ) as pct_change
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | total_amount | previous_amount | change   | pct_change |
|------------|--------------|-----------------|----------|------------|
| 2026-09-01 | 1245.00      | NULL            | NULL     | NULL       |
| 2026-09-03 | 350.00       | 1245.00         | -895.00  | -71.89     |
| 2026-09-05 | 145.00       | 350.00          | -205.00  | -58.57     |
| 2026-09-07 | 1200.00      | 145.00          | 1055.00  | 727.59     |
| 2026-09-10 | 40.00        | 1200.00         | -1160.00 | -96.67     |
```

### Use Case 2: Days Between Events

**Problem:** Calculate days between consecutive orders.

```sql
SELECT 
    order_id,
    order_date,
    LAG(order_date) OVER (ORDER BY order_date) as previous_order_date,
    order_date - LAG(order_date) OVER (ORDER BY order_date) as days_since_last_order
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_id | order_date | previous_order_date | days_since_last_order |
|----------|------------|--------------------|-----------------------|
| 1001     | 2026-09-01 | NULL               | NULL                  |
| 1002     | 2026-09-03 | 2026-09-01         | 2                     |
| 1003     | 2026-09-05 | 2026-09-03         | 2                     |
| 1004     | 2026-09-07 | 2026-09-05         | 2                     |
| 1005     | 2026-09-10 | 2026-09-07         | 3                     |
| 1006     | 2026-09-12 | 2026-09-10         | 2                     |
| 1007     | 2026-09-15 | 2026-09-12         | 3                     |
```

### Use Case 3: Customer Purchase Patterns

**Problem:** Analyze each customer's order history.

```sql
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    
    -- Previous order info
    LAG(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_order_date,
    
    LAG(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_order_amount,
    
    -- Days since last purchase
    o.order_date - LAG(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as days_since_last_purchase,
    
    -- Spending trend
    CASE 
        WHEN o.total_amount > LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Increasing'
        WHEN o.total_amount < LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Decreasing'
        WHEN o.total_amount = LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Stable'
        ELSE 'First Order'
    END as spending_trend
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | prev_order_date | prev_order_amount | days_since_last_purchase | spending_trend |
|---------------|------------|--------------|-----------------|-------------------|--------------------------|---------------|
| Alice Johnson | 2026-09-01 | 1245.00      | NULL            | NULL              | NULL                     | First Order   |
| Alice Johnson | 2026-09-05 | 145.00       | 2026-09-01      | 1245.00           | 4                        | Decreasing    |
| Alice Johnson | 2026-09-15 | 25.00        | 2026-09-05      | 145.00            | 10                       | Decreasing    |
| Bob Smith     | 2026-09-03 | 350.00       | NULL            | NULL              | NULL                     | First Order   |
| Bob Smith     | 2026-09-12 | 120.00       | 2026-09-03      | 350.00            | 9                        | Decreasing    |
```

### Use Case 4: Identifying Streaks

**Problem:** Find consecutive days with orders.

```sql
WITH order_gaps AS (
    SELECT 
        order_date,
        LAG(order_date) OVER (ORDER BY order_date) as prev_date,
        order_date - LAG(order_date) OVER (ORDER BY order_date) as gap_days,
        CASE 
            WHEN order_date - LAG(order_date) OVER (ORDER BY order_date) = 1 
            THEN 'Consecutive'
            WHEN order_date - LAG(order_date) OVER (ORDER BY order_date) IS NULL
            THEN 'First'
            ELSE 'Gap'
        END as gap_status
    FROM orders
)
SELECT 
    order_date,
    prev_date,
    gap_days,
    gap_status
FROM order_gaps
ORDER BY order_date;
```

### Use Case 5: Moving Context Window

**Problem:** See previous and next values for context.

```sql
SELECT 
    order_date,
    total_amount,
    
    -- Previous
    LAG(total_amount, 1) OVER (ORDER BY order_date) as prev_order,
    
    -- Next
    LEAD(total_amount, 1) OVER (ORDER BY order_date) as next_order,
    
    -- Average of previous, current, and next
    ROUND(
        (COALESCE(LAG(total_amount) OVER (ORDER BY order_date), 0) +
         total_amount +
         COALESCE(LEAD(total_amount) OVER (ORDER BY order_date), 0)) / 3.0,
        2
    ) as three_order_avg
    
FROM orders
ORDER BY order_date;
```

---

## Advanced Patterns

### Pattern 1: First and Last Values Per Group

```sql
-- Identify customer's first and most recent order
WITH customer_orders AS (
    SELECT 
        c.name,
        o.order_date,
        o.total_amount,
        FIRST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as first_order_amount,
        LAST_VALUE(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
        ) as last_order_amount
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT DISTINCT
    name,
    first_order_amount,
    last_order_amount,
    last_order_amount - first_order_amount as order_value_change
FROM customer_orders;
```

### Pattern 2: Detecting Trend Reversals

**Problem:** Find when spending switches from increasing to decreasing.

```sql
WITH order_trends AS (
    SELECT 
        c.name,
        o.order_date,
        o.total_amount,
        LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as prev_amount,
        LEAD(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as next_amount
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT 
    name,
    order_date,
    total_amount,
    prev_amount,
    next_amount,
    CASE 
        WHEN prev_amount < total_amount AND total_amount > next_amount 
        THEN 'PEAK'
        WHEN prev_amount > total_amount AND total_amount < next_amount 
        THEN 'TROUGH'
        WHEN prev_amount < total_amount AND total_amount < next_amount 
        THEN 'Rising'
        WHEN prev_amount > total_amount AND total_amount > next_amount 
        THEN 'Falling'
        ELSE 'Neutral'
    END as trend_position
FROM order_trends
WHERE prev_amount IS NOT NULL AND next_amount IS NOT NULL
ORDER BY name, order_date;
```

### Pattern 3: Time-Based Windows

**Problem:** Compare to same period last week/month.

```sql
-- Compare to order from 7 days ago (approximate)
SELECT 
    order_date,
    total_amount,
    LAG(total_amount, 7) OVER (ORDER BY order_date) as week_ago_amount,
    total_amount - LAG(total_amount, 7) OVER (ORDER BY order_date) as wow_change
FROM daily_orders
ORDER BY order_date;
```

### Pattern 4: Filling Gaps

**Problem:** Use previous value when current is NULL.

```sql
-- Forward-fill missing values
SELECT 
    order_date,
    product_id,
    quantity,
    COALESCE(
        quantity,
        LAG(quantity) OVER (PARTITION BY product_id ORDER BY order_date)
    ) as quantity_filled
FROM order_items
ORDER BY product_id, order_date;
```

---

## LAG/LEAD vs Self-Join

### The Old Way: Self-Join

```sql
-- ❌ COMPLEX: Using self-join to get previous order
SELECT 
    o1.order_date,
    o1.total_amount,
    o2.total_amount as previous_amount
FROM orders o1
LEFT JOIN orders o2 ON o2.order_date = (
    SELECT MAX(order_date)
    FROM orders
    WHERE order_date < o1.order_date
)
ORDER BY o1.order_date;
```

### The Modern Way: LAG

```sql
-- ✅ SIMPLE: Using LAG
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as previous_amount
FROM orders
ORDER BY order_date;
```

**Benefits of LAG/LEAD:**
- ✅ Simpler syntax
- ✅ Better performance
- ✅ More readable
- ✅ Easy to specify offset (2 rows back, 3 rows forward)

---

## Common Mistakes and Solutions

### Mistake 1: Forgetting PARTITION BY

```sql
-- ❌ WRONG: Mixing data from different customers
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    LAG(o.total_amount) OVER (ORDER BY o.order_date) as prev_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;
-- Bob's first order might show Alice's last order as "previous"

-- ✅ RIGHT: Partition by customer
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    LAG(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_amount
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id;
```

### Mistake 2: Not Handling NULLs

```sql
-- ⚠️ PROBLEM: First row always has NULL
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
    total_amount - LAG(total_amount) OVER (ORDER BY order_date) as change
FROM orders;
-- change will be NULL for first row

-- ✅ SOLUTION 1: Use COALESCE
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
    total_amount - COALESCE(LAG(total_amount) OVER (ORDER BY order_date), 0) as change
FROM orders;

-- ✅ SOLUTION 2: Use default parameter
SELECT 
    order_date,
    total_amount,
    LAG(total_amount, 1, 0) OVER (ORDER BY order_date) as prev_amount
FROM orders;

-- ✅ SOLUTION 3: Filter out NULLs
SELECT 
    order_date,
    total_amount,
    prev_amount,
    total_amount - prev_amount as change
FROM (
    SELECT 
        order_date,
        total_amount,
        LAG(total_amount) OVER (ORDER BY order_date) as prev_amount
    FROM orders
) sub
WHERE prev_amount IS NOT NULL;
```

### Mistake 3: Wrong ORDER BY

```sql
-- ❌ WRONG: Ordered by amount, not date
SELECT 
    order_date,
    total_amount,
    LAG(order_date) OVER (ORDER BY total_amount) as prev_date
FROM orders;
-- "Previous date" doesn't make sense when ordered by amount!

-- ✅ RIGHT: Order by date for time-based comparison
SELECT 
    order_date,
    total_amount,
    LAG(order_date) OVER (ORDER BY order_date) as prev_date
FROM orders;
```

### Mistake 4: Division by Zero

```sql
-- ⚠️ PROBLEM: Previous value might be 0
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
    (total_amount / LAG(total_amount) OVER (ORDER BY order_date)) * 100 as pct_change
FROM orders;
-- ERROR if prev_amount is 0!

-- ✅ SOLUTION: Use NULLIF
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
    ROUND(
        (total_amount * 100.0) / 
        NULLIF(LAG(total_amount) OVER (ORDER BY order_date), 0),
        2
    ) as pct_change
FROM orders;
```

---

## Performance Tips

### 1. Index ORDER BY Columns

```sql
-- Create index for better performance
CREATE INDEX idx_orders_date ON orders(order_date);

-- Query benefits from index
SELECT 
    order_date,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount
FROM orders;
```

### 2. Avoid Repeated Window Definitions

```sql
-- ❌ INEFFICIENT: Repeating the same OVER clause
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
    total_amount - LAG(total_amount) OVER (ORDER BY order_date) as change,
    LEAD(total_amount) OVER (ORDER BY order_date) as next_amount;
-- OVER clause evaluated multiple times

-- ✅ EFFICIENT: Use WINDOW clause (if supported)
SELECT 
    order_date,
    total_amount,
    LAG(total_amount) OVER w as prev_amount,
    total_amount - LAG(total_amount) OVER w as change,
    LEAD(total_amount) OVER w as next_amount
FROM orders
WINDOW w AS (ORDER BY order_date);

-- ✅ EFFICIENT: Use CTE to calculate once
WITH with_lag AS (
    SELECT 
        order_date,
        total_amount,
        LAG(total_amount) OVER (ORDER BY order_date) as prev_amount,
        LEAD(total_amount) OVER (ORDER BY order_date) as next_amount
    FROM orders
)
SELECT 
    order_date,
    total_amount,
    prev_amount,
    total_amount - prev_amount as change,
    next_amount
FROM with_lag;
```

---

## Practice Exercises

### Exercise 1: Basic LAG
Show each order with the previous order's amount and the change.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    order_id,
    total_amount,
    LAG(total_amount) OVER (ORDER BY order_date) as previous_amount,
    total_amount - LAG(total_amount) OVER (ORDER BY order_date) as change
FROM orders
ORDER BY order_date;
```
</details>

### Exercise 2: Customer Order Gaps
Calculate days between each customer's orders.

<details>
<summary>Solution</summary>

```sql
SELECT 
    c.name,
    o.order_date,
    LAG(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as previous_order_date,
    o.order_date - LAG(o.order_date) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as days_since_last_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```
</details>

### Exercise 3: Spending Trends
Identify whether each customer's spending is increasing or decreasing.

<details>
<summary>Solution</summary>

```sql
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    LAG(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_amount,
    CASE 
        WHEN o.total_amount > LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Increasing'
        WHEN o.total_amount < LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Decreasing'
        WHEN o.total_amount = LAG(o.total_amount) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Stable'
        ELSE 'First Order'
    END as trend
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```
</details>

### Exercise 4: Context Window
Show previous, current, and next order values.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    order_id,
    LAG(total_amount) OVER (ORDER BY order_date) as prev_order,
    total_amount as current_order,
    LEAD(total_amount) OVER (ORDER BY order_date) as next_order
FROM orders
ORDER BY order_date;
```
</details>

---

## Summary

**LAG() and LEAD() are essential for:**
- ✅ Period-over-period comparisons
- ✅ Trend analysis
- ✅ Time series calculations
- ✅ Gap detection
- ✅ Pattern identification

**Key Points:**
1. LAG() looks backward, LEAD() looks forward
2. Both require ORDER BY clause
3. First row LAG and last row LEAD are NULL (unless default specified)
4. Use PARTITION BY to keep groups separate
5. Much simpler and faster than self-joins

**Remember:**
- Always use PARTITION BY when analyzing groups separately
- Handle NULLs explicitly (COALESCE or default parameter)
- Use NULLIF to avoid division by zero
- Order matters! ORDER BY determines which row is "previous" or "next"

---

**Next:** Learn about FIRST_VALUE() and LAST_VALUE() for accessing boundary values!
