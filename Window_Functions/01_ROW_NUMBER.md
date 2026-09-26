# ROW_NUMBER() - Complete Guide

## Overview

`ROW_NUMBER()` assigns a **unique sequential integer** to each row within a partition, starting at 1. Unlike RANK() or DENSE_RANK(), it never assigns duplicate numbers, even when values are identical.

## Syntax

```sql
ROW_NUMBER() OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)
```

## Key Characteristics

- ✅ Always returns unique numbers (1, 2, 3, 4, ...)
- ✅ Requires ORDER BY clause (mandatory)
- ✅ Ties are broken arbitrarily (but consistently within the same query)
- ✅ Perfect for pagination and "Top N per group" queries

---

## Basic Usage

### Example 1: Simple Row Numbering

```sql
-- Number all orders sequentially
SELECT 
    order_id,
    order_date,
    total_amount,
    ROW_NUMBER() OVER (ORDER BY order_date) as row_num
FROM orders;
```

**Result:**
```
| order_id | order_date | total_amount | row_num |
|----------|------------|--------------|---------|
| 1001     | 2026-09-01 | 1245.00      | 1       |
| 1002     | 2026-09-03 | 350.00       | 2       |
| 1003     | 2026-09-05 | 145.00       | 3       |
| 1004     | 2026-09-07 | 1200.00      | 4       |
| 1005     | 2026-09-10 | 40.00        | 5       |
| 1006     | 2026-09-12 | 120.00       | 6       |
| 1007     | 2026-09-15 | 25.00        | 7       |
```

**Use Case:** Simple sequential numbering for display purposes.

---

## With PARTITION BY

### Example 2: Number Rows Within Groups

```sql
-- Number each customer's orders
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as customer_order_number
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | total_amount | customer_order_number |
|---------------|------------|--------------|----------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 1                    |
| Alice Johnson | 2026-09-05 | 145.00       | 2                    |
| Alice Johnson | 2026-09-15 | 25.00        | 3                    |
| Bob Smith     | 2026-09-03 | 350.00       | 1                    |
| Bob Smith     | 2026-09-12 | 120.00       | 2                    |
| Carol White   | 2026-09-07 | 1200.00      | 1                    |
| David Brown   | 2026-09-10 | 40.00        | 1                    |
```

**Understanding:**
- Numbers reset for each customer (PARTITION BY)
- Within each customer, orders are numbered by date (ORDER BY)
- Alice has 3 orders → numbered 1, 2, 3
- Bob has 2 orders → numbered 1, 2
- Carol and David each have 1 order → numbered 1

---

## Handling Ties

### Example 3: When Values Are Identical

```sql
-- What happens with identical order amounts?
SELECT 
    order_id,
    total_amount,
    ROW_NUMBER() OVER (ORDER BY total_amount DESC) as row_num
FROM orders
WHERE total_amount IN (1245.00, 1200.00, 350.00, 350.00);
```

**If we had duplicate amounts:**
```
| order_id | total_amount | row_num |
|----------|--------------|---------|
| 1001     | 1245.00      | 1       |
| 1004     | 1200.00      | 2       |
| 1002     | 350.00       | 3       | ← First 350
| 1008     | 350.00       | 4       | ← Second 350 (unique number)
```

**Important:** Even though two orders have the same amount ($350), ROW_NUMBER() assigns different numbers (3 and 4). The tie-breaking is arbitrary but consistent.

**To control tie-breaking:**
```sql
ROW_NUMBER() OVER (ORDER BY total_amount DESC, order_id) as row_num
-- Uses order_id as tiebreaker
```

---

## Common Use Cases

### Use Case 1: Top N Per Group

**Problem:** Find the most recent 2 orders for each customer.

```sql
WITH numbered_orders AS (
    SELECT 
        c.name,
        o.order_date,
        o.total_amount,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date DESC
        ) as recency_rank
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT 
    name,
    order_date,
    total_amount
FROM numbered_orders
WHERE recency_rank <= 2
ORDER BY name, order_date DESC;
```

**Result:**
```
| name          | order_date | total_amount |
|---------------|------------|--------------|
| Alice Johnson | 2026-09-15 | 25.00        | ← Most recent
| Alice Johnson | 2026-09-05 | 145.00       | ← 2nd most recent
| Bob Smith     | 2026-09-12 | 120.00       |
| Bob Smith     | 2026-09-03 | 350.00       |
| Carol White   | 2026-09-07 | 1200.00      |
| David Brown   | 2026-09-10 | 40.00        |
```

### Use Case 2: Pagination

**Problem:** Get page 2 of results (rows 11-20) when displaying orders.

```sql
WITH numbered_rows AS (
    SELECT 
        order_id,
        order_date,
        total_amount,
        ROW_NUMBER() OVER (ORDER BY order_date DESC) as row_num
    FROM orders
)
SELECT 
    order_id,
    order_date,
    total_amount
FROM numbered_rows
WHERE row_num BETWEEN 11 AND 20;  -- Page 2 (assuming 10 per page)
```

### Use Case 3: Remove Duplicates

**Problem:** Keep only the first occurrence when there are duplicates.

```sql
-- Sample data with duplicates
CREATE TEMP TABLE orders_with_dupes AS
SELECT * FROM orders
UNION ALL
SELECT * FROM orders WHERE order_id = 1001;  -- Create a duplicate

-- Remove duplicates, keeping the first one
WITH numbered AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, order_date, total_amount
            ORDER BY (SELECT NULL)  -- Arbitrary ordering
        ) as rn
    FROM orders_with_dupes
)
DELETE FROM orders_with_dupes
WHERE (order_id, order_date, total_amount) IN (
    SELECT order_id, order_date, total_amount
    FROM numbered
    WHERE rn > 1
);
```

### Use Case 4: Identifying First/Last in Group

**Problem:** Identify each customer's first and last order.

```sql
WITH order_positions AS (
    SELECT 
        c.name,
        o.order_id,
        o.order_date,
        o.total_amount,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date ASC
        ) as order_sequence,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date DESC
        ) as reverse_sequence
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT 
    name,
    order_date,
    total_amount,
    CASE 
        WHEN order_sequence = 1 THEN 'FIRST ORDER'
        WHEN reverse_sequence = 1 THEN 'MOST RECENT ORDER'
        ELSE 'MIDDLE ORDER'
    END as order_position
FROM order_positions
ORDER BY name, order_date;
```

**Result:**
```
| name          | order_date | total_amount | order_position       |
|---------------|------------|--------------|---------------------|
| Alice Johnson | 2026-09-01 | 1245.00      | FIRST ORDER         |
| Alice Johnson | 2026-09-05 | 145.00       | MIDDLE ORDER        |
| Alice Johnson | 2026-09-15 | 25.00        | MOST RECENT ORDER   |
| Bob Smith     | 2026-09-03 | 350.00       | FIRST ORDER         |
| Bob Smith     | 2026-09-12 | 120.00       | MOST RECENT ORDER   |
```

### Use Case 5: Alternating Pattern Assignment

**Problem:** Assign orders to different fulfillment centers in a round-robin fashion.

```sql
SELECT 
    order_id,
    order_date,
    total_amount,
    CASE (ROW_NUMBER() OVER (ORDER BY order_date) - 1) % 3
        WHEN 0 THEN 'Warehouse A'
        WHEN 1 THEN 'Warehouse B'
        WHEN 2 THEN 'Warehouse C'
    END as assigned_warehouse
FROM orders;
```

**Result:**
```
| order_id | order_date | total_amount | assigned_warehouse |
|----------|------------|--------------|-------------------|
| 1001     | 2026-09-01 | 1245.00      | Warehouse A       |
| 1002     | 2026-09-03 | 350.00       | Warehouse B       |
| 1003     | 2026-09-05 | 145.00       | Warehouse C       |
| 1004     | 2026-09-07 | 1200.00      | Warehouse A       |
| 1005     | 2026-09-10 | 40.00        | Warehouse B       |
| 1006     | 2026-09-12 | 120.00       | Warehouse C       |
| 1007     | 2026-09-15 | 25.00        | Warehouse A       |
```

---

## Advanced Patterns

### Pattern 1: Top N with Ties Handling

**Problem:** Get top 3 orders, but if there are ties, use different criteria.

```sql
WITH ranked AS (
    SELECT 
        order_id,
        total_amount,
        ROW_NUMBER() OVER (
            ORDER BY total_amount DESC, order_date ASC, order_id
        ) as position
    FROM orders
)
SELECT 
    order_id,
    total_amount,
    position
FROM ranked
WHERE position <= 3;
```

### Pattern 2: Gap Detection

**Problem:** Find gaps in order sequences.

```sql
WITH numbered AS (
    SELECT 
        order_id,
        ROW_NUMBER() OVER (ORDER BY order_id) as row_num
    FROM orders
)
SELECT 
    order_id,
    row_num,
    order_id - row_num as gap_group,
    CASE 
        WHEN order_id - LAG(order_id) OVER (ORDER BY order_id) > 1 
        THEN 'GAP DETECTED'
        ELSE 'Sequential'
    END as gap_status
FROM numbered;
```

### Pattern 3: Even/Odd Row Selection

**Problem:** Select every other row (e.g., for A/B testing).

```sql
-- Get odd-numbered rows
WITH numbered AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY order_date) as rn
    FROM orders
)
SELECT order_id, order_date, total_amount
FROM numbered
WHERE rn % 2 = 1;  -- 1 for odd, 0 for even
```

### Pattern 4: Percentage-Based Selection

**Problem:** Get the top 20% of orders by value.

```sql
WITH ranked AS (
    SELECT 
        order_id,
        total_amount,
        ROW_NUMBER() OVER (ORDER BY total_amount DESC) as rank,
        COUNT(*) OVER () as total_orders
    FROM orders
)
SELECT 
    order_id,
    total_amount,
    rank,
    total_orders
FROM ranked
WHERE rank <= CEILING(total_orders * 0.2);  -- Top 20%
```

---

## Comparison with Other Ranking Functions

### ROW_NUMBER vs RANK vs DENSE_RANK

```sql
-- Same data, different ranking functions
SELECT 
    product_name,
    price,
    ROW_NUMBER() OVER (ORDER BY price DESC) as row_num,
    RANK() OVER (ORDER BY price DESC) as rank,
    DENSE_RANK() OVER (ORDER BY price DESC) as dense_rank
FROM products;
```

**If we had ties:**
```
| product_name         | price   | row_num | rank | dense_rank |
|---------------------|---------|---------|------|------------|
| Laptop Pro          | 1200.00 | 1       | 1    | 1          |
| Monitor 27"         | 350.00  | 2       | 2    | 2          |
| Keyboard A          | 120.00  | 3       | 3    | 3          |
| Keyboard B          | 120.00  | 4       | 3    | 3          | ← Same price as Keyboard A
| Mouse               | 25.00   | 5       | 5    | 4          |
```

**Key Differences:**
- **ROW_NUMBER**: Always unique (3, 4, 5) - breaks ties arbitrarily
- **RANK**: Same for ties, skips next (3, 3, 5) - traditional ranking
- **DENSE_RANK**: Same for ties, no gaps (3, 3, 4) - consecutive ranks

**When to use ROW_NUMBER:**
- ✅ Need unique identifiers for each row
- ✅ Implementing pagination
- ✅ Selecting exactly N rows per group
- ✅ Removing duplicates
- ❌ Don't use when ties should have same rank (use RANK or DENSE_RANK instead)

---

## Performance Considerations

### 1. Index Usage

```sql
-- Good: Index on ORDER BY columns
CREATE INDEX idx_orders_date ON orders(order_date);

SELECT 
    order_id,
    ROW_NUMBER() OVER (ORDER BY order_date) as rn
FROM orders;
-- Can use index for sorting
```

### 2. Partition Size

```sql
-- Good: Reasonable partition sizes
ROW_NUMBER() OVER (PARTITION BY category ORDER BY price)

-- Potentially slow: Too many tiny partitions
ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY line_item)
-- If each order_id has only 2-3 items, lots of tiny partitions
```

### 3. Filter Early

```sql
-- Better: Filter before windowing
WITH filtered AS (
    SELECT * FROM orders WHERE order_date >= '2026-01-01'
)
SELECT 
    *,
    ROW_NUMBER() OVER (ORDER BY order_date) as rn
FROM filtered;

-- Worse: Window over everything, then filter
SELECT * FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY order_date) as rn
    FROM orders
) WHERE order_date >= '2026-01-01';
```

---

## Common Mistakes and Solutions

### Mistake 1: Using ROW_NUMBER in WHERE Clause

```sql
-- ❌ WRONG: Window functions can't be in WHERE
SELECT *
FROM orders
WHERE ROW_NUMBER() OVER (ORDER BY order_date) <= 3;

-- ✅ RIGHT: Use CTE or subquery
WITH numbered AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY order_date) as rn
    FROM orders
)
SELECT * FROM numbered WHERE rn <= 3;
```

### Mistake 2: Forgetting ORDER BY

```sql
-- ❌ WRONG: ROW_NUMBER requires ORDER BY
SELECT 
    order_id,
    ROW_NUMBER() OVER () as rn  -- ERROR!
FROM orders;

-- ✅ RIGHT: Always specify ORDER BY
SELECT 
    order_id,
    ROW_NUMBER() OVER (ORDER BY order_id) as rn
FROM orders;
```

### Mistake 3: Expecting Stable Ordering of Ties

```sql
-- ⚠️ UNPREDICTABLE: Tie-breaking is arbitrary
SELECT 
    product_name,
    price,
    ROW_NUMBER() OVER (ORDER BY price) as rn
FROM products;
-- If two products have same price, their order is undefined

-- ✅ BETTER: Explicit tiebreaker
SELECT 
    product_name,
    price,
    ROW_NUMBER() OVER (ORDER BY price, product_name) as rn
FROM products;
```

### Mistake 4: Using ROW_NUMBER When You Want RANK

```sql
-- Scenario: Award medals to top scorers

-- ❌ WRONG: Ties get different numbers
SELECT 
    player_name,
    score,
    ROW_NUMBER() OVER (ORDER BY score DESC) as position
FROM game_scores;
-- Players with same score get different positions!

-- ✅ RIGHT: Use RANK for sports-style ranking
SELECT 
    player_name,
    score,
    RANK() OVER (ORDER BY score DESC) as position
FROM game_scores;
-- Players with same score get same position
```

---

## Practice Exercises

### Exercise 1: Basic Numbering
Number all products by price (highest to lowest).

<details>
<summary>Solution</summary>

```sql
SELECT 
    product_name,
    price,
    ROW_NUMBER() OVER (ORDER BY price DESC) as price_rank
FROM products;
```
</details>

### Exercise 2: Partition Numbering
Number each product within its category.

<details>
<summary>Solution</summary>

```sql
SELECT 
    category,
    product_name,
    price,
    ROW_NUMBER() OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as rank_in_category
FROM products
ORDER BY category, rank_in_category;
```
</details>

### Exercise 3: Latest N Per Group
Find the 2 most recent orders for each customer.

<details>
<summary>Solution</summary>

```sql
WITH ranked_orders AS (
    SELECT 
        c.name,
        o.order_date,
        o.total_amount,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date DESC
        ) as recency
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT name, order_date, total_amount
FROM ranked_orders
WHERE recency <= 2
ORDER BY name, order_date DESC;
```
</details>

### Exercise 4: Alternating Assignment
Assign orders alternately to 2 support agents.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_id,
    order_date,
    CASE ROW_NUMBER() OVER (ORDER BY order_date) % 2
        WHEN 1 THEN 'Agent A'
        WHEN 0 THEN 'Agent B'
    END as assigned_agent
FROM orders;
```
</details>

---

## Summary

**ROW_NUMBER() is best for:**
- ✅ Unique sequential numbering
- ✅ Top N per group queries
- ✅ Pagination
- ✅ Deduplication
- ✅ Round-robin assignment

**Key Points:**
1. Always returns unique numbers (no ties)
2. Requires ORDER BY clause
3. Tie-breaking is arbitrary but consistent
4. Cannot be used directly in WHERE clause
5. Most commonly used ranking function

**Remember:**
- Use ROW_NUMBER when you need unique sequential numbers
- Use RANK when ties should share the same rank
- Use DENSE_RANK when you want consecutive rank numbers

---

**Next:** Learn about RANK() and DENSE_RANK() for handling ties differently!
