# NTILE() - Complete Guide

## Overview

`NTILE(n)` divides rows into `n` approximately equal groups (buckets) and assigns a group number (1 to n) to each row. It's perfect for creating quartiles, percentiles, or any equal-sized segments of your data.

## Syntax

```sql
NTILE(n) OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)
```

**Parameters:**
- `n`: Number of buckets to create (must be a positive integer)

**Returns:** Integer from 1 to n indicating which bucket the row belongs to

---

## Key Characteristics

- ✅ Divides rows into approximately equal groups
- ✅ If rows don't divide evenly, first buckets get one extra row
- ✅ Requires ORDER BY clause (mandatory)
- ✅ Perfect for customer segmentation, performance bands, A/B testing
- ✅ Group numbers are consecutive: 1, 2, 3, ..., n

---

## Basic Usage

### Example 1: Quartiles (4 Groups)

```sql
-- Divide customers into 4 equal groups by spending
WITH customer_spending AS (
    SELECT 
        c.name,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) as quartile
FROM customer_spending
ORDER BY quartile, total_spent DESC;
```

**Result (with 4 customers):**
```
| name          | total_spent | quartile |
|---------------|-------------|----------|
| Alice Johnson | 1415.00     | 1        | ← Top 25% (Q1)
| Carol White   | 1200.00     | 2        | ← Second 25% (Q2)
| Bob Smith     | 470.00      | 3        | ← Third 25% (Q3)
| David Brown   | 40.00       | 4        | ← Bottom 25% (Q4)
```

**Understanding:** With 4 customers and 4 quartiles, each customer gets one quartile. Perfect distribution!

### Example 2: Uneven Distribution

```sql
-- What happens with 7 rows divided into 4 groups?
SELECT 
    order_id,
    total_amount,
    NTILE(4) OVER (ORDER BY total_amount DESC) as quartile
FROM orders
ORDER BY quartile, total_amount DESC;
```

**Result (7 orders ÷ 4 groups):**
```
| order_id | total_amount | quartile |
|----------|--------------|----------|
| 1001     | 1245.00      | 1        | ← Group 1: 2 rows
| 1004     | 1200.00      | 1        |
| 1002     | 350.00       | 2        | ← Group 2: 2 rows
| 1003     | 145.00       | 2        |
| 1006     | 120.00       | 3        | ← Group 3: 2 rows
| 1005     | 40.00        | 3        |
| 1007     | 25.00        | 4        | ← Group 4: 1 row
```

**Distribution Logic:**
- 7 rows ÷ 4 groups = 1.75 rows per group
- First 3 groups get 2 rows (rounded up)
- Last group gets 1 row
- Formula: First groups get `CEILING(total_rows / n)`, remaining groups get `FLOOR(total_rows / n)`

---

## Common Use Cases

### Use Case 1: Customer Segmentation

**Problem:** Divide customers into High/Medium/Low value tiers.

```sql
WITH customer_totals AS (
    SELECT 
        c.customer_id,
        c.name,
        c.city,
        SUM(o.total_amount) as lifetime_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, c.city
)
SELECT 
    name,
    city,
    lifetime_value,
    NTILE(3) OVER (ORDER BY lifetime_value DESC) as value_tier,
    CASE NTILE(3) OVER (ORDER BY lifetime_value DESC)
        WHEN 1 THEN 'High Value - VIP'
        WHEN 2 THEN 'Medium Value - Standard'
        WHEN 3 THEN 'Low Value - New/Casual'
    END as segment_name
FROM customer_totals
ORDER BY lifetime_value DESC;
```

**Result:**
```
| name          | city          | lifetime_value | value_tier | segment_name              |
|---------------|---------------|----------------|------------|---------------------------|
| Alice Johnson | Seattle       | 1415.00        | 1          | High Value - VIP          |
| Carol White   | Seattle       | 1200.00        | 1          | High Value - VIP          |
| Bob Smith     | Portland      | 470.00         | 2          | Medium Value - Standard   |
| David Brown   | San Francisco | 40.00          | 3          | Low Value - New/Casual    |
```

### Use Case 2: Product Pricing Tiers

**Problem:** Classify products into budget/mid-range/premium tiers.

```sql
SELECT 
    product_name,
    category,
    price,
    NTILE(3) OVER (ORDER BY price) as price_tier,
    CASE NTILE(3) OVER (ORDER BY price)
        WHEN 1 THEN 'Budget'
        WHEN 2 THEN 'Mid-Range'
        WHEN 3 THEN 'Premium'
    END as price_category
FROM products
ORDER BY price;
```

**Result:**
```
| product_name         | category    | price   | price_tier | price_category |
|---------------------|-------------|---------|------------|---------------|
| USB-C Cable         | Accessories | 15.00   | 1          | Budget        |
| Wireless Mouse      | Accessories | 25.00   | 1          | Budget        |
| Keyboard Mechanical | Accessories | 120.00  | 2          | Mid-Range     |
| Monitor 27"         | Displays    | 350.00  | 2          | Mid-Range     |
| Laptop Pro          | Computers   | 1200.00 | 3          | Premium       |
```

### Use Case 3: A/B/C Testing Groups

**Problem:** Divide orders into 3 equal test groups for pricing experiments.

```sql
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    NTILE(3) OVER (ORDER BY order_id) as test_group,
    CASE NTILE(3) OVER (ORDER BY order_id)
        WHEN 1 THEN 'Group A - Current Pricing'
        WHEN 2 THEN 'Group B - 10% Discount'
        WHEN 3 THEN 'Group C - Free Shipping'
    END as experiment_group
FROM orders
ORDER BY order_id;
```

### Use Case 4: Performance Deciles (Top 10%, etc.)

**Problem:** Identify top 10% performers.

```sql
WITH product_performance AS (
    SELECT 
        p.product_name,
        SUM(oi.quantity) as units_sold,
        SUM(oi.quantity * p.price) as revenue
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name
)
SELECT 
    product_name,
    units_sold,
    revenue,
    NTILE(10) OVER (ORDER BY revenue DESC) as decile,
    CASE 
        WHEN NTILE(10) OVER (ORDER BY revenue DESC) = 1 THEN 'Top 10%'
        WHEN NTILE(10) OVER (ORDER BY revenue DESC) <= 3 THEN 'Top 30%'
        WHEN NTILE(10) OVER (ORDER BY revenue DESC) <= 5 THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END as performance_band
FROM product_performance
ORDER BY revenue DESC;
```

### Use Case 5: Workload Distribution

**Problem:** Distribute customer accounts equally among 5 sales reps.

```sql
SELECT 
    customer_id,
    name,
    city,
    NTILE(5) OVER (ORDER BY customer_id) as assigned_rep,
    CASE NTILE(5) OVER (ORDER BY customer_id)
        WHEN 1 THEN 'Sarah Johnson'
        WHEN 2 THEN 'Mike Chen'
        WHEN 3 THEN 'Emily Davis'
        WHEN 4 THEN 'James Wilson'
        WHEN 5 THEN 'Lisa Martinez'
    END as sales_rep_name
FROM customers
ORDER BY assigned_rep, customer_id;
```

---

## With PARTITION BY

### Example 3: Segments Within Categories

```sql
-- Divide products into price tiers WITHIN each category
SELECT 
    category,
    product_name,
    price,
    NTILE(3) OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as category_price_tier,
    CASE NTILE(3) OVER (PARTITION BY category ORDER BY price DESC)
        WHEN 1 THEN 'High-End'
        WHEN 2 THEN 'Mid-Range'
        WHEN 3 THEN 'Entry-Level'
    END as tier_name
FROM products
ORDER BY category, price DESC;
```

**Result:**
```
| category    | product_name         | price   | category_price_tier | tier_name   |
|-------------|---------------------|---------|---------------------|-------------|
| Accessories | Keyboard Mechanical | 120.00  | 1                   | High-End    |
| Accessories | Wireless Mouse      | 25.00   | 2                   | Mid-Range   |
| Accessories | USB-C Cable         | 15.00   | 3                   | Entry-Level |
| Computers   | Laptop Pro          | 1200.00 | 1                   | High-End    |
| Displays    | Monitor 27"         | 350.00  | 1                   | High-End    |
```

**Understanding:** Each category gets its own tier distribution. Even though "Monitor 27" ($350) is cheaper than "Keyboard" ($120) overall, it's "High-End" within its category.

### Example 4: Customer Segments Per City

```sql
-- Rank customers within each city
WITH customer_city_spending AS (
    SELECT 
        c.city,
        c.name,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.city, c.name
)
SELECT 
    city,
    name,
    total_spent,
    NTILE(2) OVER (
        PARTITION BY city 
        ORDER BY total_spent DESC
    ) as city_segment,
    CASE NTILE(2) OVER (PARTITION BY city ORDER BY total_spent DESC)
        WHEN 1 THEN 'Top Half in City'
        WHEN 2 THEN 'Bottom Half in City'
    END as city_performance
FROM customer_city_spending
ORDER BY city, total_spent DESC;
```

---

## Advanced Patterns

### Pattern 1: Dynamic Bucketing

**Problem:** Create different numbers of buckets based on data volume.

```sql
-- More buckets for categories with more products
WITH category_counts AS (
    SELECT 
        category,
        COUNT(*) as product_count
    FROM products
    GROUP BY category
),
products_with_buckets AS (
    SELECT 
        p.product_name,
        p.category,
        p.price,
        c.product_count,
        CASE 
            WHEN c.product_count >= 10 THEN 5  -- 5 tiers for large categories
            WHEN c.product_count >= 5 THEN 3   -- 3 tiers for medium
            ELSE 2                              -- 2 tiers for small
        END as bucket_count
    FROM products p
    JOIN category_counts c ON p.category = c.category
)
SELECT 
    category,
    product_name,
    price,
    -- Note: NTILE doesn't accept variables, would need dynamic SQL
    NTILE(3) OVER (PARTITION BY category ORDER BY price DESC) as price_tier
FROM products_with_buckets;
```

### Pattern 2: Percentile-Based Filtering

**Problem:** Get orders in the top 25% by value.

```sql
WITH quartiled_orders AS (
    SELECT 
        order_id,
        order_date,
        total_amount,
        NTILE(4) OVER (ORDER BY total_amount DESC) as value_quartile
    FROM orders
)
SELECT 
    order_id,
    order_date,
    total_amount
FROM quartiled_orders
WHERE value_quartile = 1  -- Top 25%
ORDER BY total_amount DESC;
```

### Pattern 3: Balanced Team Assignment

**Problem:** Distribute high-value and low-value customers evenly across teams.

```sql
-- Alternate assignment: high-value to team 1, next high to team 2, etc.
WITH ranked_customers AS (
    SELECT 
        c.customer_id,
        c.name,
        SUM(o.total_amount) as total_spent,
        NTILE(3) OVER (ORDER BY SUM(o.total_amount) DESC) as team_assignment
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    team_assignment,
    CASE team_assignment
        WHEN 1 THEN 'Team Alpha'
        WHEN 2 THEN 'Team Beta'
        WHEN 3 THEN 'Team Gamma'
    END as team_name
FROM ranked_customers
ORDER BY total_spent DESC;
```

### Pattern 4: Comparative Bucketing

**Problem:** Show how a value compares to others in its bucket.

```sql
WITH bucketed_orders AS (
    SELECT 
        order_id,
        total_amount,
        NTILE(4) OVER (ORDER BY total_amount) as quartile
    FROM orders
)
SELECT 
    quartile,
    COUNT(*) as orders_in_bucket,
    MIN(total_amount) as min_amount,
    MAX(total_amount) as max_amount,
    ROUND(AVG(total_amount), 2) as avg_amount
FROM bucketed_orders
GROUP BY quartile
ORDER BY quartile;
```

**Result:**
```
| quartile | orders_in_bucket | min_amount | max_amount | avg_amount |
|----------|------------------|------------|------------|------------|
| 1        | 2                | 25.00      | 40.00      | 32.50      |
| 2        | 2                | 120.00     | 145.00     | 132.50     |
| 3        | 2                | 350.00     | 1200.00    | 775.00     |
| 4        | 1                | 1245.00    | 1245.00    | 1245.00    |
```

---

## Understanding Distribution Rules

### Rule 1: Remainder Goes to First Buckets

```sql
-- 10 rows, 3 buckets
-- 10 ÷ 3 = 3.33...
-- Distribution: 4, 3, 3
```

**Formula:**
```
bucket_size = CEILING(total_rows / n)
first_k_buckets_get = bucket_size rows
remaining_buckets_get = bucket_size - 1 rows

where k = total_rows % n (remainder)
```

**Examples:**

| Total Rows | Buckets | Distribution | Explanation |
|------------|---------|--------------|-------------|
| 7          | 4       | 2,2,2,1      | 7÷4=1.75, first 3 get 2, last gets 1 |
| 10         | 3       | 4,3,3        | 10÷3=3.33, first gets 4, others get 3 |
| 12         | 5       | 3,3,2,2,2    | 12÷5=2.4, first 2 get 3, others get 2 |
| 100        | 4       | 25,25,25,25  | Perfect division |

### Rule 2: ORDER BY Determines Distribution

```sql
-- Different ORDER BY = different assignments
SELECT 
    customer_id,
    name,
    total_spent,
    NTILE(3) OVER (ORDER BY total_spent DESC) as by_spending,
    NTILE(3) OVER (ORDER BY customer_id) as by_id
FROM customer_totals;
```

The same customer gets different bucket numbers based on the ordering!

---

## Comparison with Other Functions

### NTILE vs RANK vs ROW_NUMBER

```sql
SELECT 
    order_id,
    total_amount,
    ROW_NUMBER() OVER (ORDER BY total_amount DESC) as row_num,
    RANK() OVER (ORDER BY total_amount DESC) as rank,
    NTILE(3) OVER (ORDER BY total_amount DESC) as tertile
FROM orders;
```

**Result (7 orders):**
```
| order_id | total_amount | row_num | rank | tertile |
|----------|--------------|---------|------|---------|
| 1001     | 1245.00      | 1       | 1    | 1       |
| 1004     | 1200.00      | 2       | 2    | 1       |
| 1002     | 350.00       | 3       | 3    | 1       | ← First tertile ends
| 1003     | 145.00       | 4       | 4    | 2       |
| 1006     | 120.00       | 5       | 5    | 2       |
| 1005     | 40.00        | 6       | 6    | 3       | ← Third tertile
| 1007     | 25.00        | 7       | 7    | 3       |
```

**Key Differences:**
- **ROW_NUMBER**: Position (1,2,3,4,5,6,7)
- **RANK**: Ordinal ranking (handles ties)
- **NTILE**: Group membership (1,1,1,2,2,3,3)

---

## Common Mistakes and Solutions

### Mistake 1: Expecting Exact Equal Buckets

```sql
-- ❌ MISUNDERSTANDING: "NTILE(3) creates 3 buckets of exact same size"
-- Reality: Only approximately equal, difference at most 1

WITH bucketed AS (
    SELECT 
        order_id,
        NTILE(3) OVER (ORDER BY order_id) as bucket
    FROM orders  -- 7 orders
)
SELECT 
    bucket,
    COUNT(*) as size
FROM bucketed
GROUP BY bucket;

-- Result: 3,2,2 or 3,3,1 (not 2.33,2.33,2.33)
```

**Solution:** Accept that buckets may differ by 1 row.

### Mistake 2: Using NTILE Without ORDER BY

```sql
-- ❌ WRONG: Missing ORDER BY
SELECT 
    customer_id,
    NTILE(4) OVER () as quartile  -- ERROR!
FROM customers;

-- ✅ RIGHT: Always specify ORDER BY
SELECT 
    customer_id,
    NTILE(4) OVER (ORDER BY customer_id) as quartile
FROM customers;
```

### Mistake 3: Assuming Bucket Boundaries Match Values

```sql
-- ⚠️ MISUNDERSTANDING
SELECT 
    total_amount,
    NTILE(4) OVER (ORDER BY total_amount) as quartile
FROM orders;

-- Bucket 1 doesn't mean "amount < 25th percentile value"
-- It means "first 25% of ROWS when ordered by amount"
```

**Key Insight:** NTILE divides **rows**, not **value ranges**.

```
Value-based quartile:    Row-based quartile (NTILE):
$0-$250: Q1             First 25% of rows: Q1
$251-$500: Q2           Next 25% of rows: Q2
$501-$1000: Q3          Next 25% of rows: Q3
$1001+: Q4              Last 25% of rows: Q4
```

### Mistake 4: Using NTILE for Exact Percentiles

```sql
-- ❌ WRONG: NTILE(100) doesn't give exact percentiles
SELECT 
    customer_name,
    total_spent,
    NTILE(100) OVER (ORDER BY total_spent) as percentile
FROM customers;
-- With 50 customers, each bucket has 1 row, but that's not a true percentile

-- ✅ RIGHT: Use PERCENT_RANK() for exact percentiles
SELECT 
    customer_name,
    total_spent,
    ROUND(PERCENT_RANK() OVER (ORDER BY total_spent) * 100, 2) as percentile
FROM customers;
```

---

## Performance Tips

### 1. Index ORDER BY Columns

```sql
-- Create index for better sorting performance
CREATE INDEX idx_orders_amount ON orders(total_amount);

SELECT 
    order_id,
    total_amount,
    NTILE(4) OVER (ORDER BY total_amount) as quartile
FROM orders;
```

### 2. Materialize for Repeated Use

```sql
-- If using the same bucketing multiple times, store it
CREATE TEMP TABLE customer_segments AS
SELECT 
    customer_id,
    name,
    total_spent,
    NTILE(3) OVER (ORDER BY total_spent DESC) as segment
FROM customer_totals;

-- Now reuse without recalculating
SELECT * FROM customer_segments WHERE segment = 1;
SELECT * FROM customer_segments WHERE segment = 2;
```

---

## Practice Exercises

### Exercise 1: Basic Quartiles
Divide customers into 4 equal groups by total spending.

<details>
<summary>Solution</summary>

```sql
WITH customer_spending AS (
    SELECT 
        c.name,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) as quartile
FROM customer_spending
ORDER BY quartile, total_spent DESC;
```
</details>

### Exercise 2: Tertiles Per Category
Divide products into 3 price tiers within each category.

<details>
<summary>Solution</summary>

```sql
SELECT 
    category,
    product_name,
    price,
    NTILE(3) OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as price_tier,
    CASE NTILE(3) OVER (PARTITION BY category ORDER BY price DESC)
        WHEN 1 THEN 'Premium'
        WHEN 2 THEN 'Standard'
        WHEN 3 THEN 'Budget'
    END as tier_name
FROM products
ORDER BY category, price_tier;
```
</details>

### Exercise 3: Top 20% Analysis
Identify orders in the top 20% by value.

<details>
<summary>Solution</summary>

```sql
WITH quintiles AS (
    SELECT 
        order_id,
        order_date,
        total_amount,
        NTILE(5) OVER (ORDER BY total_amount DESC) as quintile
    FROM orders
)
SELECT 
    order_id,
    order_date,
    total_amount,
    'Top 20%' as performance_band
FROM quintiles
WHERE quintile = 1
ORDER BY total_amount DESC;
```
</details>

### Exercise 4: Balanced Assignment
Distribute customers equally among 3 sales teams.

<details>
<summary>Solution</summary>

```sql
SELECT 
    customer_id,
    name,
    city,
    NTILE(3) OVER (ORDER BY customer_id) as team_number,
    CASE NTILE(3) OVER (ORDER BY customer_id)
        WHEN 1 THEN 'Team North'
        WHEN 2 THEN 'Team Central'
        WHEN 3 THEN 'Team South'
    END as team_name
FROM customers
ORDER BY team_number, customer_id;
```
</details>

---

## Summary

**NTILE(n) is perfect for:**
- ✅ Customer segmentation (VIP, Standard, New)
- ✅ Product tiering (Premium, Mid, Budget)
- ✅ A/B/C/D testing groups
- ✅ Performance bands (Top 10%, 20%, etc.)
- ✅ Workload distribution (equal assignment)

**Key Points:**
1. Divides rows into n approximately equal groups
2. Returns group number (1 to n)
3. First groups may have 1 extra row if uneven distribution
4. Requires ORDER BY clause
5. ORDER BY determines which rows go in which bucket

**Remember:**
- NTILE divides **rows**, not **value ranges**
- Use NTILE(4) for quartiles, NTILE(10) for deciles
- Buckets differ by at most 1 row in size
- For exact percentiles, use PERCENT_RANK() instead

---

**Next:** Learn about LAG() and LEAD() for accessing previous/next row values!
