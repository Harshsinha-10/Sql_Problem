# RANK() and DENSE_RANK() - Complete Guide

## Overview

Both `RANK()` and `DENSE_RANK()` assign rankings to rows, and **both handle ties by giving them the same rank**. The key difference is what happens after a tie:

- **RANK()**: Leaves gaps after ties (1, 2, 2, 4, 5)
- **DENSE_RANK()**: No gaps after ties (1, 2, 2, 3, 4)

## Syntax

```sql
RANK() OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)

DENSE_RANK() OVER (
    [PARTITION BY partition_expression]
    ORDER BY sort_expression [ASC|DESC]
)
```

---

## Understanding RANK()

### How RANK() Works

RANK() assigns the same rank to rows with identical values in the ORDER BY clause. After a tie, it **skips ranks** equal to the number of tied rows.

### Example 1: Basic RANK()

```sql
-- Rank customers by total spending
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
    RANK() OVER (ORDER BY total_spent DESC) as spending_rank
FROM customer_spending;
```

**Result:**
```
| name          | total_spent | spending_rank |
|---------------|-------------|---------------|
| Alice Johnson | 1415.00     | 1             |
| Carol White   | 1200.00     | 2             |
| Bob Smith     | 470.00      | 3             |
| David Brown   | 40.00       | 4             |
```

**If there were ties:**
```
| name          | total_spent | spending_rank |
|---------------|-------------|---------------|
| Alice Johnson | 1415.00     | 1             |
| Carol White   | 1415.00     | 1             | ← Tied for first
| Bob Smith     | 470.00      | 3             | ← Skips rank 2
| David Brown   | 40.00       | 4             |
| Emma Davis    | 40.00       | 4             | ← Tied for 4th
| Frank Lee     | 35.00       | 6             | ← Skips rank 5
```

### Visual Understanding of RANK()

```
Values: 100, 95, 95, 90, 85, 85, 85, 80

RANK() assigns:
100 → Rank 1  (1 person)
95  → Rank 2  (2 people tied)
95  → Rank 2  (same as above)
90  → Rank 4  (skip rank 3, because 2 people held rank 2)
85  → Rank 5  (3 people tied)
85  → Rank 5  (same as above)
85  → Rank 5  (same as above)
80  → Rank 8  (skip ranks 6 and 7, because 3 people held rank 5)
```

**The rule:** After N tied rows, skip (N-1) ranks.

---

## Understanding DENSE_RANK()

### How DENSE_RANK() Works

DENSE_RANK() also assigns the same rank to tied rows, but it **never skips ranks**. The next rank is always the previous rank + 1.

### Example 2: Basic DENSE_RANK()

```sql
-- Same query, but with DENSE_RANK
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
    DENSE_RANK() OVER (ORDER BY total_spent DESC) as spending_rank
FROM customer_spending;
```

**With ties:**
```
| name          | total_spent | spending_rank |
|---------------|-------------|---------------|
| Alice Johnson | 1415.00     | 1             |
| Carol White   | 1415.00     | 1             | ← Tied for first
| Bob Smith     | 470.00      | 2             | ← No gap! (not 3)
| David Brown   | 40.00       | 3             |
| Emma Davis    | 40.00       | 3             | ← Tied
| Frank Lee     | 35.00       | 4             | ← No gap! (not 5)
```

### Visual Understanding of DENSE_RANK()

```
Values: 100, 95, 95, 90, 85, 85, 85, 80

DENSE_RANK() assigns:
100 → Rank 1
95  → Rank 2
95  → Rank 2  (tied)
90  → Rank 3  (no skip)
85  → Rank 4  (no skip)
85  → Rank 4  (tied)
85  → Rank 4  (tied)
80  → Rank 5  (no skip - only 5 unique values, so max rank is 5)
```

**The rule:** Rank = number of distinct values that are greater than or equal to current value.

---

## Side-by-Side Comparison

### Example 3: All Three Ranking Functions

```sql
-- Compare ROW_NUMBER, RANK, and DENSE_RANK
SELECT 
    product_name,
    category,
    price,
    ROW_NUMBER() OVER (ORDER BY price DESC) as row_num,
    RANK() OVER (ORDER BY price DESC) as rank,
    DENSE_RANK() OVER (ORDER BY price DESC) as dense_rank
FROM products;
```

**Result:**
```
| product_name         | category    | price   | row_num | rank | dense_rank |
|---------------------|-------------|---------|---------|------|------------|
| Laptop Pro          | Computers   | 1200.00 | 1       | 1    | 1          |
| Monitor 27"         | Displays    | 350.00  | 2       | 2    | 2          |
| Keyboard Mechanical | Accessories | 120.00  | 3       | 3    | 3          |
| Wireless Mouse      | Accessories | 25.00   | 4       | 4    | 4          |
| USB-C Cable         | Accessories | 15.00   | 5       | 5    | 5          |
```

**If we add duplicate prices:**
```
| product_name      | price   | row_num | rank | dense_rank |
|------------------|---------|---------|------|------------|
| Product A        | 100.00  | 1       | 1    | 1          |
| Product B        | 80.00   | 2       | 2    | 2          |
| Product C        | 80.00   | 3       | 2    | 2          | ← Same as B
| Product D        | 80.00   | 4       | 2    | 2          | ← Same as B
| Product E        | 60.00   | 5       | 5    | 3          | ← RANK skips to 5, DENSE_RANK goes to 3
| Product F        | 40.00   | 6       | 6    | 4          |
| Product G        | 40.00   | 7       | 6    | 4          | ← Same as F
| Product H        | 20.00   | 8       | 8    | 5          | ← RANK skips to 8, DENSE_RANK goes to 5
```

**Key Observations:**
- **ROW_NUMBER**: Every value is unique (1,2,3,4,5,6,7,8)
- **RANK**: Ties share ranks, then skips (1,2,2,2,5,6,6,8)
- **DENSE_RANK**: Ties share ranks, no skips (1,2,2,2,3,4,4,5)

---

## Use Cases

### Use Case 1: Competition Rankings (Use RANK)

In sports and competitions, traditional ranking uses RANK() - if two people tie for 2nd place, the next person is in 4th place.

```sql
-- Olympic medal standings
SELECT 
    country,
    gold_medals,
    silver_medals,
    bronze_medals,
    gold_medals + silver_medals + bronze_medals as total_medals,
    RANK() OVER (ORDER BY 
        gold_medals DESC, 
        silver_medals DESC, 
        bronze_medals DESC
    ) as world_rank
FROM olympic_medals
ORDER BY world_rank;
```

**Example Result:**
```
| country | gold | silver | bronze | total | world_rank |
|---------|------|--------|--------|-------|------------|
| USA     | 40   | 44     | 42     | 126   | 1          |
| China   | 40   | 27     | 24     | 91    | 1          | ← Tied on gold
| Japan   | 27   | 14     | 17     | 58    | 3          | ← Skips rank 2
```

### Use Case 2: Grade Rankings (Use DENSE_RANK)

In academic settings, DENSE_RANK() is often preferred because it shows how many distinct performance levels exist.

```sql
-- Student grade rankings
SELECT 
    student_name,
    final_score,
    DENSE_RANK() OVER (ORDER BY final_score DESC) as class_rank,
    COUNT(DISTINCT final_score) OVER () as total_grade_levels
FROM student_grades;
```

**Result:**
```
| student_name | final_score | class_rank | total_grade_levels |
|--------------|-------------|------------|-------------------|
| Alice        | 98          | 1          | 5                 |
| Bob          | 95          | 2          | 5                 |
| Carol        | 95          | 2          | 5                 |
| Dave         | 92          | 3          | 5                 | ← Rank 3, not 4
| Emma         | 88          | 4          | 5                 |
| Frank        | 85          | 5          | 5                 |
```

**Benefit:** class_rank directly corresponds to performance level. Rank 3 means "3rd distinct score level."

### Use Case 3: Top N Including Ties (Use RANK)

**Problem:** Get top 3 products, but include all ties.

```sql
WITH ranked_products AS (
    SELECT 
        product_name,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) as sales_rank
    FROM product_summary
)
SELECT 
    product_name,
    total_sales,
    sales_rank
FROM ranked_products
WHERE sales_rank <= 3;  -- Gets top 3, plus any ties
```

**Why RANK?** If the 3rd place is tied, you want to include all tied products. RANK() ensures this.

### Use Case 4: Percentile Bands (Use DENSE_RANK)

```sql
-- Divide customers into performance bands
WITH customer_ranks AS (
    SELECT 
        name,
        total_spent,
        DENSE_RANK() OVER (ORDER BY total_spent DESC) as performance_rank,
        COUNT(DISTINCT total_spent) OVER () as total_bands
    FROM customer_totals
)
SELECT 
    name,
    total_spent,
    performance_rank,
    CASE 
        WHEN performance_rank <= total_bands * 0.2 THEN 'Top 20%'
        WHEN performance_rank <= total_bands * 0.5 THEN 'Top 50%'
        ELSE 'Bottom 50%'
    END as performance_band
FROM customer_ranks;
```

---

## With PARTITION BY

### Example 4: Ranking Within Groups

```sql
-- Rank products within each category
SELECT 
    category,
    product_name,
    price,
    RANK() OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as rank_in_category,
    DENSE_RANK() OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as dense_rank_in_category
FROM products
ORDER BY category, price DESC;
```

**Result:**
```
| category    | product_name         | price   | rank_in_category | dense_rank_in_category |
|-------------|---------------------|---------|------------------|----------------------|
| Accessories | Keyboard Mechanical | 120.00  | 1                | 1                    |
| Accessories | Wireless Mouse      | 25.00   | 2                | 2                    |
| Accessories | USB-C Cable         | 15.00   | 3                | 3                    |
| Computers   | Laptop Pro          | 1200.00 | 1                | 1                    |
| Displays    | Monitor 27"         | 350.00  | 1                | 1                    |
```

**Understanding:**
- Rankings reset for each partition (category)
- Each category has its own #1, #2, etc.

### Example 5: Top N Per Category

```sql
-- Top 2 products per category by sales
WITH product_ranks AS (
    SELECT 
        p.category,
        p.product_name,
        SUM(oi.quantity * p.price) as total_revenue,
        RANK() OVER (
            PARTITION BY p.category 
            ORDER BY SUM(oi.quantity * p.price) DESC
        ) as revenue_rank
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.category, p.product_name
)
SELECT 
    category,
    product_name,
    total_revenue,
    revenue_rank
FROM product_ranks
WHERE revenue_rank <= 2  -- Top 2, including ties
ORDER BY category, revenue_rank;
```

---

## Advanced Patterns

### Pattern 1: Ranking with Multiple Criteria

```sql
-- Rank orders by amount, with date as tiebreaker
SELECT 
    order_id,
    order_date,
    total_amount,
    RANK() OVER (
        ORDER BY 
            total_amount DESC,
            order_date ASC  -- Earlier date wins ties
    ) as value_rank
FROM orders;
```

### Pattern 2: Quartile Classification Using DENSE_RANK

```sql
-- Classify customers into quartiles
WITH ranked_customers AS (
    SELECT 
        name,
        total_spent,
        DENSE_RANK() OVER (ORDER BY total_spent DESC) as spending_rank,
        COUNT(DISTINCT total_spent) OVER () as total_ranks
    FROM customer_totals
)
SELECT 
    name,
    total_spent,
    spending_rank,
    CASE 
        WHEN spending_rank <= total_ranks * 0.25 THEN 'Q1 - Top 25%'
        WHEN spending_rank <= total_ranks * 0.50 THEN 'Q2 - Upper Middle'
        WHEN spending_rank <= total_ranks * 0.75 THEN 'Q3 - Lower Middle'
        ELSE 'Q4 - Bottom 25%'
    END as quartile
FROM ranked_customers;
```

### Pattern 3: Gap Analysis

```sql
-- Find customers who dropped significantly in ranking
WITH this_month AS (
    SELECT 
        customer_id,
        SUM(total_amount) as spending,
        RANK() OVER (ORDER BY SUM(total_amount) DESC) as current_rank
    FROM orders
    WHERE EXTRACT(MONTH FROM order_date) = EXTRACT(MONTH FROM CURRENT_DATE)
    GROUP BY customer_id
),
last_month AS (
    SELECT 
        customer_id,
        SUM(total_amount) as spending,
        RANK() OVER (ORDER BY SUM(total_amount) DESC) as previous_rank
    FROM orders
    WHERE EXTRACT(MONTH FROM order_date) = EXTRACT(MONTH FROM CURRENT_DATE) - 1
    GROUP BY customer_id
)
SELECT 
    c.name,
    tm.spending as current_spending,
    tm.current_rank,
    lm.previous_rank,
    lm.previous_rank - tm.current_rank as rank_change
FROM customers c
JOIN this_month tm ON c.customer_id = tm.customer_id
LEFT JOIN last_month lm ON c.customer_id = lm.customer_id
WHERE lm.previous_rank - tm.current_rank < -3  -- Dropped 3+ positions
ORDER BY rank_change;
```

### Pattern 4: Percentile Rank

Combine with total count to calculate exact percentile.

```sql
SELECT 
    customer_name,
    total_spent,
    RANK() OVER (ORDER BY total_spent DESC) as rank,
    COUNT(*) OVER () as total_customers,
    ROUND(
        (RANK() OVER (ORDER BY total_spent DESC) - 1) * 100.0 / 
        (COUNT(*) OVER () - 1),
        2
    ) as percentile
FROM customer_totals;
```

**Result:**
```
| customer_name | total_spent | rank | total_customers | percentile |
|---------------|-------------|------|-----------------|------------|
| Alice         | 1415.00     | 1    | 4               | 0.00       | ← Top (0th percentile)
| Carol         | 1200.00     | 2    | 4               | 33.33      |
| Bob           | 470.00      | 3    | 4               | 66.67      |
| David         | 40.00       | 4    | 4               | 100.00     | ← Bottom (100th percentile)
```

---

## When to Use Which

### Use RANK() when:
✅ **Traditional competition-style ranking** (Olympics, sports standings)  
✅ **Top N with all ties included** (if 3 people tie for 3rd, all should be included)  
✅ **Ranking reflects absolute position** (being 10th out of 100 vs 10th out of 10,000)  
✅ **You want the rank number to reflect how many people are ahead**

### Use DENSE_RANK() when:
✅ **Number of distinct levels matters** (grade levels A,B,C,D,F)  
✅ **Creating categories or tiers** (High/Medium/Low performance bands)  
✅ **Consecutive rank numbers needed** (for UI display, percentile calculations)  
✅ **You want the maximum rank = number of distinct values**

### Use ROW_NUMBER() when:
✅ **Unique sequential numbers needed** (pagination, IDs)  
✅ **Exactly N rows required** (not "top N including ties")  
✅ **Ties don't matter or should be broken arbitrarily**

---

## Common Mistakes

### Mistake 1: Using RANK when you need exactly N rows

```sql
-- ❌ PROBLEM: If there are ties, you get more than 3 rows
WITH ranked AS (
    SELECT 
        *,
        RANK() OVER (ORDER BY score DESC) as rank
    FROM players
)
SELECT * FROM ranked WHERE rank <= 3;
-- If 3 players tie for 3rd, you get 5+ rows!

-- ✅ SOLUTION: Use ROW_NUMBER if you need exactly 3
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (ORDER BY score DESC) as rank
    FROM players
)
SELECT * FROM ranked WHERE rank <= 3;
-- Always returns exactly 3 rows
```

### Mistake 2: Expecting RANK = COUNT of people ahead

```sql
-- If you have: 100, 95, 95, 90
-- RANK gives:    1,   2,  2,  4

-- ❌ WRONG INTERPRETATION:
-- "Rank 4 means 3 people ahead"
-- Actually: 3 people ahead, but 2 share rank 2

-- Correct interpretation:
-- "Rank 4 means 4th position, but positions 2 and 3 are tied"
```

### Mistake 3: Filtering on RANK in WHERE clause

```sql
-- ❌ WRONG: Can't use window function in WHERE
SELECT 
    product_name,
    RANK() OVER (ORDER BY price DESC) as rank
FROM products
WHERE RANK() OVER (ORDER BY price DESC) <= 5;

-- ✅ RIGHT: Use CTE or subquery
WITH ranked AS (
    SELECT 
        product_name,
        RANK() OVER (ORDER BY price DESC) as rank
    FROM products
)
SELECT * FROM ranked WHERE rank <= 5;
```

---

## Performance Tips

### 1. Index ORDER BY columns

```sql
-- Create index on ranking columns
CREATE INDEX idx_orders_amount ON orders(total_amount DESC);

-- Query benefits from index
SELECT 
    order_id,
    total_amount,
    RANK() OVER (ORDER BY total_amount DESC) as rank
FROM orders;
```

### 2. Filter before ranking when possible

```sql
-- ✅ BETTER: Filter first, then rank
WITH recent_orders AS (
    SELECT * FROM orders 
    WHERE order_date >= '2026-01-01'
)
SELECT 
    *,
    RANK() OVER (ORDER BY total_amount DESC) as rank
FROM recent_orders;

-- ❌ SLOWER: Rank everything, then filter
SELECT * FROM (
    SELECT 
        *,
        RANK() OVER (ORDER BY total_amount DESC) as rank
    FROM orders
) WHERE order_date >= '2026-01-01';
```

---

## Practice Exercises

### Exercise 1: Basic Ranking
Rank all products by price (highest to lowest) using both RANK() and DENSE_RANK().

<details>
<summary>Solution</summary>

```sql
SELECT 
    product_name,
    price,
    RANK() OVER (ORDER BY price DESC) as rank,
    DENSE_RANK() OVER (ORDER BY price DESC) as dense_rank
FROM products;
```
</details>

### Exercise 2: Top N with Ties
Find the top 3 customers by spending, including all ties.

<details>
<summary>Solution</summary>

```sql
WITH ranked_customers AS (
    SELECT 
        c.name,
        SUM(o.total_amount) as total_spent,
        RANK() OVER (ORDER BY SUM(o.total_amount) DESC) as spending_rank
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT name, total_spent, spending_rank
FROM ranked_customers
WHERE spending_rank <= 3;
```
</details>

### Exercise 3: Rank Within Groups
Rank products within each category by price.

<details>
<summary>Solution</summary>

```sql
SELECT 
    category,
    product_name,
    price,
    RANK() OVER (
        PARTITION BY category 
        ORDER BY price DESC
    ) as rank_in_category
FROM products
ORDER BY category, rank_in_category;
```
</details>

### Exercise 4: Performance Tiers
Divide customers into 4 performance tiers based on spending using DENSE_RANK.

<details>
<summary>Solution</summary>

```sql
WITH customer_ranks AS (
    SELECT 
        c.name,
        SUM(o.total_amount) as total_spent,
        DENSE_RANK() OVER (ORDER BY SUM(o.total_amount) DESC) as spending_rank,
        COUNT(DISTINCT SUM(o.total_amount)) OVER () as total_levels
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    spending_rank,
    CASE 
        WHEN spending_rank <= total_levels * 0.25 THEN 'Tier 1 - Elite'
        WHEN spending_rank <= total_levels * 0.50 THEN 'Tier 2 - Premium'
        WHEN spending_rank <= total_levels * 0.75 THEN 'Tier 3 - Standard'
        ELSE 'Tier 4 - Basic'
    END as tier
FROM customer_ranks;
```
</details>

---

## Summary

### RANK()
- ✅ Assigns same rank to ties
- ✅ Skips ranks after ties
- ✅ Good for competition-style rankings
- ✅ Max rank = number of rows (not number of distinct values)

### DENSE_RANK()
- ✅ Assigns same rank to ties
- ✅ Never skips ranks
- ✅ Good for tier/band classifications
- ✅ Max rank = number of distinct values

### Quick Decision Guide

| Scenario | Use |
|----------|-----|
| Olympics, sports standings | RANK |
| Grade levels (A,B,C,D,F) | DENSE_RANK |
| Need exactly N rows | ROW_NUMBER |
| Performance tiers/bands | DENSE_RANK |
| Top N including ties | RANK |
| Unique IDs needed | ROW_NUMBER |

---

**Next:** Learn about NTILE() for dividing data into equal groups!
