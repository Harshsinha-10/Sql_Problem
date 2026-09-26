# Window Functions - Complete In-Depth Guide with Tech Haven Exercises

## Table of Contents
1. [Foundation Concepts](#foundation-concepts)
2. [OVER Clause - The Basics](#over-clause---the-basics)
3. [PARTITION BY - Creating Groups](#partition-by---creating-groups)
4. [ORDER BY - Sequential Calculations](#order-by---sequential-calculations)
5. [Ranking Functions](#ranking-functions)
6. [Value Functions (LAG, LEAD, FIRST_VALUE, LAST_VALUE)](#value-functions)
7. [Frame Specifications](#frame-specifications)
8. [Advanced Patterns](#advanced-patterns)
9. [Tech Haven Practice Exercises](#tech-haven-practice-exercises)

---

## Foundation Concepts

### What Problem Do Window Functions Solve?

Imagine you're analyzing your Tech Haven store data and you want to answer:
- "Show me each order AND what percentage of total sales it represents"
- "For each product, show its sales compared to the category average"
- "Show the running total of revenue by date"

**The traditional approach has limitations:**

```sql
-- Option 1: Aggregate only (lose detail)
SELECT SUM(total_amount) FROM orders;
-- Result: Just one number, no individual orders

-- Option 2: Join with subquery (complex, inefficient)
SELECT o.order_id, o.total_amount, 
       (SELECT SUM(total_amount) FROM orders) as total_sales
FROM orders o;
-- Works, but repeats calculation for every row
```

**Window functions solve this elegantly:**

```sql
SELECT 
    order_id,
    total_amount,
    SUM(total_amount) OVER () as total_sales,
    ROUND(total_amount * 100.0 / SUM(total_amount) OVER (), 2) as pct_of_total
FROM orders;
```

### The Key Insight

> **Window functions perform calculations across a "window" of rows related to the current row, WITHOUT collapsing those rows into groups.**

Think of it as:
- **GROUP BY** = Collapse rows → Get summary
- **Window Functions** = Keep rows → Add summary information

---

## OVER Clause - The Basics

The `OVER()` clause is what makes a function a "window function."

### Syntax

```sql
function_name(...) OVER (
    [PARTITION BY column]
    [ORDER BY column]
    [frame_specification]
)
```

### Level 1: Empty OVER() - All Rows as One Window

```sql
-- Tech Haven Example: Each order with company-wide context
SELECT 
    order_id,
    customer_id,
    order_date,
    total_amount,
    
    -- Company-wide aggregates (same on every row)
    SUM(total_amount) OVER () as total_revenue,
    AVG(total_amount) OVER () as avg_order_value,
    COUNT(*) OVER () as total_orders,
    MAX(total_amount) OVER () as largest_order,
    MIN(total_amount) OVER () as smallest_order
    
FROM orders;
```

**Result:**
```
| order_id | customer_id | order_date | total_amount | total_revenue | avg_order_value | total_orders | largest_order | smallest_order |
|----------|-------------|------------|--------------|---------------|-----------------|--------------|---------------|----------------|
| 1001     | 1           | 2026-09-01 | 1245.00      | 3125.00       | 446.43          | 7            | 1245.00       | 25.00          |
| 1002     | 2           | 2026-09-03 | 350.00       | 3125.00       | 446.43          | 7            | 1245.00       | 25.00          |
| 1003     | 1           | 2026-09-05 | 145.00       | 3125.00       | 446.43          | 7            | 1245.00       | 25.00          |
| ...      | ...         | ...        | ...          | 3125.00       | 446.43          | 7            | 1245.00       | 25.00          |
```

**Notice:** The aggregate values (total_revenue, avg_order_value, etc.) are the same on every row because `OVER ()` treats all rows as one big window.

### Practical Use Case: Contribution Analysis

```sql
-- What percentage of total sales does each order represent?
SELECT 
    order_id,
    customer_id,
    total_amount,
    SUM(total_amount) OVER () as total_sales,
    ROUND((total_amount * 100.0) / SUM(total_amount) OVER (), 2) as pct_of_sales,
    
    -- How does this order compare to average?
    AVG(total_amount) OVER () as avg_order,
    CASE 
        WHEN total_amount > AVG(total_amount) OVER () THEN 'Above Average'
        WHEN total_amount < AVG(total_amount) OVER () THEN 'Below Average'
        ELSE 'Average'
    END as order_classification
    
FROM orders
ORDER BY total_amount DESC;
```

**When to use OVER():**
- Comparing individual rows to overall aggregates
- Calculating percentages of total
- Adding context without losing row detail

---

## PARTITION BY - Creating Groups

`PARTITION BY` divides your data into groups (partitions) and calculates the window function **separately for each group**.

### Analogy

Think of `PARTITION BY` like organizing books:
- **Without PARTITION BY**: All books in one pile → Calculate statistics for all books
- **With PARTITION BY genre**: Books grouped by genre → Calculate statistics per genre, but keep all books visible

### Syntax

```sql
function(...) OVER (PARTITION BY column1, column2, ...)
```

### Level 2: PARTITION BY - Group Calculations

```sql
-- Tech Haven Example: Product sales by category
SELECT 
    p.product_name,
    p.category,
    p.price,
    
    -- Category-level statistics
    COUNT(*) OVER (PARTITION BY p.category) as products_in_category,
    AVG(p.price) OVER (PARTITION BY p.category) as avg_category_price,
    MIN(p.price) OVER (PARTITION BY p.category) as min_category_price,
    MAX(p.price) OVER (PARTITION BY p.category) as max_category_price,
    
    -- How does this product compare to its category?
    p.price - AVG(p.price) OVER (PARTITION BY p.category) as diff_from_category_avg,
    ROUND((p.price * 100.0) / SUM(p.price) OVER (PARTITION BY p.category), 2) as pct_of_category_value
    
FROM products p
ORDER BY p.category, p.price DESC;
```

**Result:**
```
| product_name         | category    | price   | products_in_category | avg_category_price | diff_from_category_avg | pct_of_category_value |
|---------------------|-------------|---------|----------------------|--------------------|-----------------------|----------------------|
| Keyboard Mechanical | Accessories | 120.00  | 3                    | 53.33              | 66.67                 | 75.00                |
| Wireless Mouse      | Accessories | 25.00   | 3                    | 53.33              | -28.33                | 15.63                |
| USB-C Cable         | Accessories | 15.00   | 3                    | 53.33              | -38.33                | 9.38                 |
| Laptop Pro          | Computers   | 1200.00 | 1                    | 1200.00            | 0.00                  | 100.00               |
| Monitor 27"         | Displays    | 350.00  | 1                    | 350.00             | 0.00                  | 100.00               |
```

### Visual Understanding

```
All Products:                    PARTITION BY category:

[All 5 products]                 [Accessories: 3 products]
                                      ↓
                                 AVG(price) = 53.33
                                 Only for Accessories rows
                                 
                                 [Computers: 1 product]
                                      ↓
                                 AVG(price) = 1200.00
                                 Only for Computers rows
                                 
                                 [Displays: 1 product]
                                      ↓
                                 AVG(price) = 350.00
                                 Only for Displays rows
```

### Customer Analysis Example

```sql
-- Analyze each customer's orders with customer-level context
SELECT 
    c.name,
    c.city,
    o.order_id,
    o.order_date,
    o.total_amount,
    
    -- Customer-specific aggregates
    COUNT(*) OVER (PARTITION BY c.customer_id) as customer_order_count,
    SUM(o.total_amount) OVER (PARTITION BY c.customer_id) as customer_lifetime_value,
    AVG(o.total_amount) OVER (PARTITION BY c.customer_id) as customer_avg_order,
    
    -- City-level aggregates
    COUNT(*) OVER (PARTITION BY c.city) as city_order_count,
    SUM(o.total_amount) OVER (PARTITION BY c.city) as city_total_revenue
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Use Cases for PARTITION BY:**
- Category/department comparisons
- Customer segmentation
- Regional/geographic analysis
- Time period grouping (year, quarter, month)

---

## ORDER BY - Sequential Calculations

`ORDER BY` inside a window function creates **running calculations** or **sequential numbering**.

### The Default Frame Concept

⚠️ **Important:** When you add `ORDER BY` to a window function, SQL automatically applies a frame:

```sql
-- These are IDENTICAL:
SUM(total_amount) OVER (ORDER BY order_date)

SUM(total_amount) OVER (
    ORDER BY order_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

**Translation:** "Sum from the start of the partition up to and including the current row"

This is why you get a **running total** instead of a total for all rows.

### Level 3: ORDER BY - Running Calculations

```sql
-- Tech Haven Example: Running revenue total by date
SELECT 
    order_date,
    order_id,
    total_amount,
    
    -- Running total (cumulative sum)
    SUM(total_amount) OVER (ORDER BY order_date, order_id) as running_total,
    
    -- Running average
    ROUND(AVG(total_amount) OVER (ORDER BY order_date, order_id), 2) as running_avg,
    
    -- Running count
    COUNT(*) OVER (ORDER BY order_date, order_id) as orders_so_far,
    
    -- Running min and max
    MIN(total_amount) OVER (ORDER BY order_date, order_id) as lowest_order_so_far,
    MAX(total_amount) OVER (ORDER BY order_date, order_id) as highest_order_so_far
    
FROM orders
ORDER BY order_date, order_id;
```

**Result:**
```
| order_date | order_id | total_amount | running_total | running_avg | orders_so_far | lowest_order_so_far | highest_order_so_far |
|------------|----------|--------------|---------------|-------------|---------------|---------------------|---------------------|
| 2026-09-01 | 1001     | 1245.00      | 1245.00       | 1245.00     | 1             | 1245.00             | 1245.00             |
| 2026-09-03 | 1002     | 350.00       | 1595.00       | 797.50      | 2             | 350.00              | 1245.00             |
| 2026-09-05 | 1003     | 145.00       | 1740.00       | 580.00      | 3             | 145.00              | 1245.00             |
| 2026-09-07 | 1004     | 1200.00      | 2940.00       | 735.00      | 4             | 145.00              | 1245.00             |
| 2026-09-10 | 1005     | 40.00        | 2980.00       | 596.00      | 5             | 40.00               | 1245.00             |
| 2026-09-12 | 1006     | 120.00       | 3100.00       | 516.67      | 6             | 40.00               | 1245.00             |
| 2026-09-15 | 1007     | 25.00        | 3125.00       | 446.43      | 7             | 25.00               | 1245.00             |
```

### How ORDER BY Works Step-by-Step

For the running total at order_id 1004:

```
Step 1: ORDER BY order_date, order_id
        → Rows are sorted: 1001, 1002, 1003, 1004, ...

Step 2: Default frame (UNBOUNDED PRECEDING TO CURRENT ROW)
        → Include: 1001, 1002, 1003, 1004

Step 3: Calculate SUM(total_amount)
        → 1245 + 350 + 145 + 1200 = 2940
```

### Level 4: Combining PARTITION BY + ORDER BY

This is where window functions become extremely powerful!

```sql
-- Tech Haven Example: Running total per customer
SELECT 
    c.name,
    o.order_date,
    o.order_id,
    o.total_amount,
    
    -- Running total for THIS customer only
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date, o.order_id
    ) as customer_running_total,
    
    -- Running count for THIS customer
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date, o.order_id
    ) as customer_order_number,
    
    -- Running average for THIS customer
    ROUND(AVG(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date, o.order_id
    ), 2) as customer_running_avg
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

**Result:**
```
| name          | order_date | order_id | total_amount | customer_running_total | customer_order_number | customer_running_avg |
|---------------|------------|----------|--------------|------------------------|-----------------------|---------------------|
| Alice Johnson | 2026-09-01 | 1001     | 1245.00      | 1245.00                | 1                     | 1245.00             |
| Alice Johnson | 2026-09-05 | 1003     | 145.00       | 1390.00                | 2                     | 695.00              |
| Alice Johnson | 2026-09-15 | 1007     | 25.00        | 1415.00                | 3                     | 471.67              |
| Bob Smith     | 2026-09-03 | 1002     | 350.00       | 350.00                 | 1                     | 350.00              |
| Bob Smith     | 2026-09-12 | 1006     | 120.00       | 470.00                 | 2                     | 235.00              |
| Carol White   | 2026-09-07 | 1004     | 1200.00      | 1200.00                | 1                     | 1200.00             |
| David Brown   | 2026-09-10 | 1005     | 40.00        | 40.00                  | 1                     | 40.00               |
```

**Understanding the combination:**

```
PARTITION BY customer_id → Create separate windows for each customer
ORDER BY order_date      → Within each customer's window, order by date
SUM(...)                 → Calculate running total within each window
```

Visual representation for Alice Johnson:
```
Alice's Orders (separate window):
Order 1: $1245 → Running total: $1245
Order 2: $145  → Running total: $1245 + $145 = $1390
Order 3: $25   → Running total: $1390 + $25 = $1415

Bob's Orders (separate window - starts fresh):
Order 1: $350  → Running total: $350
Order 2: $120  → Running total: $350 + $120 = $470
```

---

## Ranking Functions

Ranking functions assign a rank or position to each row within a partition.

### The Four Ranking Functions

| Function | Behavior with Ties | Gaps After Ties |
|----------|-------------------|-----------------|
| `ROW_NUMBER()` | Unique sequential numbers (1,2,3,4...) | N/A (no ties) |
| `RANK()` | Same rank for ties | YES (1,1,3,4) |
| `DENSE_RANK()` | Same rank for ties | NO (1,1,2,3) |
| `NTILE(n)` | Divides into n buckets | N/A |

### ROW_NUMBER() - Unique Sequential Numbers

Assigns a unique number to each row, even if values are identical.

```sql
-- Tech Haven Example: Number orders for each customer
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as order_number
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, order_number;
```

**Result:**
```
| name          | order_date | total_amount | order_number |
|---------------|------------|--------------|--------------|
| Alice Johnson | 2026-09-01 | 1245.00      | 1            |
| Alice Johnson | 2026-09-05 | 145.00       | 2            |
| Alice Johnson | 2026-09-15 | 25.00        | 3            |
| Bob Smith     | 2026-09-03 | 350.00       | 1            |
| Bob Smith     | 2026-09-12 | 120.00       | 2            |
```

**Use Case: Top N per Group**

```sql
-- Find the most recent 2 orders for each customer
WITH numbered_orders AS (
    SELECT 
        c.customer_id,
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
SELECT name, order_date, total_amount
FROM numbered_orders
WHERE recency_rank <= 2
ORDER BY name, order_date DESC;
```

### RANK() - Ranking with Gaps

When values tie, they get the same rank, and the next rank is skipped.

```sql
-- Tech Haven Example: Rank products by price (ties possible)
SELECT 
    product_name,
    category,
    price,
    RANK() OVER (ORDER BY price DESC) as overall_price_rank,
    RANK() OVER (PARTITION BY category ORDER BY price DESC) as category_price_rank
FROM products;
```

**Illustration with ties:**
```
If two products cost $120:
Product A: $120 → Rank 1
Product B: $120 → Rank 1 (tied)
Product C: $100 → Rank 3 (skips 2)
Product D: $80  → Rank 4
```

### DENSE_RANK() - Ranking without Gaps

Like RANK(), but doesn't skip numbers after ties.

```sql
-- Compare RANK vs DENSE_RANK
SELECT 
    product_name,
    price,
    RANK() OVER (ORDER BY price DESC) as rank_with_gaps,
    DENSE_RANK() OVER (ORDER BY price DESC) as rank_no_gaps
FROM products;
```

**Result:**
```
| product_name         | price   | rank_with_gaps | rank_no_gaps |
|---------------------|---------|----------------|--------------|
| Laptop Pro          | 1200.00 | 1              | 1            |
| Monitor 27"         | 350.00  | 2              | 2            |
| Keyboard Mechanical | 120.00  | 3              | 3            |
| Wireless Mouse      | 25.00   | 4              | 4            |
| USB-C Cable         | 15.00   | 5              | 5            |
```

**When to use which:**
- **ROW_NUMBER()**: Need unique IDs, pagination, "first N records"
- **RANK()**: Sports standings, academic rankings (traditional ranking with gaps)
- **DENSE_RANK()**: When you want consecutive rank numbers

### NTILE(n) - Divide into Buckets

Distributes rows into a specified number of approximately equal groups.

```sql
-- Tech Haven Example: Divide customers into quartiles by spending
WITH customer_totals AS (
    SELECT 
        c.customer_id,
        c.name,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) as spending_quartile,
    CASE NTILE(4) OVER (ORDER BY total_spent DESC)
        WHEN 1 THEN 'Top 25% - VIP'
        WHEN 2 THEN 'Upper 25% - Premium'
        WHEN 3 THEN 'Middle 25% - Standard'
        WHEN 4 THEN 'Lower 25% - New/Small'
    END as customer_segment
FROM customer_totals;
```

**Result:**
```
| name          | total_spent | spending_quartile | customer_segment        |
|---------------|-------------|-------------------|------------------------|
| Alice Johnson | 1415.00     | 1                 | Top 25% - VIP          |
| Carol White   | 1200.00     | 1                 | Top 25% - VIP          |
| Bob Smith     | 470.00      | 2                 | Upper 25% - Premium    |
| David Brown   | 40.00       | 2                 | Upper 25% - Premium    |
```

---

## Value Functions

Value functions access data from other rows relative to the current row.

### LAG() - Look Backward

Access a column value from a previous row.

**Syntax:**
```sql
LAG(column, offset, default) OVER ([PARTITION BY ...] ORDER BY ...)
```
- `column`: Which column to retrieve
- `offset`: How many rows back (default: 1)
- `default`: Value to use if no previous row exists (default: NULL)

```sql
-- Tech Haven Example: Compare each order to the previous order
SELECT 
    order_date,
    order_id,
    total_amount,
    
    -- Previous order amount
    LAG(total_amount, 1) OVER (ORDER BY order_date, order_id) as prev_order_amount,
    
    -- Change from previous order
    total_amount - LAG(total_amount, 1) OVER (ORDER BY order_date, order_id) as change_from_prev,
    
    -- Percent change
    ROUND(
        (total_amount - LAG(total_amount, 1) OVER (ORDER BY order_date, order_id)) * 100.0 /
        NULLIF(LAG(total_amount, 1) OVER (ORDER BY order_date, order_id), 0),
        2
    ) as pct_change
    
FROM orders
ORDER BY order_date, order_id;
```

**Result:**
```
| order_date | order_id | total_amount | prev_order_amount | change_from_prev | pct_change |
|------------|----------|--------------|-------------------|------------------|------------|
| 2026-09-01 | 1001     | 1245.00      | NULL              | NULL             | NULL       |
| 2026-09-03 | 1002     | 350.00       | 1245.00           | -895.00          | -71.89     |
| 2026-09-05 | 1003     | 145.00       | 350.00            | -205.00          | -58.57     |
| 2026-09-07 | 1004     | 1200.00      | 145.00            | 1055.00          | 727.59     |
```

**Per-Customer LAG:**

```sql
-- Compare each customer's order to their previous order
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    LAG(o.order_date, 1) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_order_date,
    LAG(o.total_amount, 1) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_order_amount,
    o.order_date - LAG(o.order_date, 1) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as days_since_last_order
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

### LEAD() - Look Forward

Access a column value from a following row.

```sql
-- Tech Haven Example: Look ahead to next order
SELECT 
    order_date,
    total_amount,
    LEAD(order_date, 1) OVER (ORDER BY order_date) as next_order_date,
    LEAD(total_amount, 1) OVER (ORDER BY order_date) as next_order_amount,
    LEAD(order_date, 1) OVER (ORDER BY order_date) - order_date as days_until_next_order
FROM orders
ORDER BY order_date;
```

### FIRST_VALUE() and LAST_VALUE()

Access the first or last value in the window frame.

```sql
-- Tech Haven Example: Compare each order to customer's first and last order
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    
    -- Customer's first order amount
    FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as first_order_amount,
    
    -- Customer's last order amount
    LAST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as last_order_amount,
    
    -- Change from first to current
    o.total_amount - FIRST_VALUE(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) as change_from_first_order
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```

⚠️ **Important:** `LAST_VALUE` requires explicit frame specification (`ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`) to see all rows in the partition. Without it, the default frame only goes to the current row.

---

## Frame Specifications

Frame specifications define the **exact subset of rows** within a partition for the calculation.

### Understanding Frames

A frame is a **sliding window** within your partition.

```
Your partition: [Row1] [Row2] [Row3] [Row4] [Row5]
                                 ↑
                          Current Row

Frame example (2 PRECEDING to CURRENT ROW):
                        [Row2] [Row3] [Row4]
                                       ↑
                                 Calculate on these 3 rows
```

### Frame Syntax

```sql
{ROWS | RANGE} BETWEEN frame_start AND frame_end
```

**Frame boundaries:**
- `UNBOUNDED PRECEDING` - Start of partition
- `n PRECEDING` - n rows before current
- `CURRENT ROW` - The current row
- `n FOLLOWING` - n rows after current
- `UNBOUNDED FOLLOWING` - End of partition

### ROWS vs RANGE

- **ROWS**: Physical row count (counts actual rows)
- **RANGE**: Logical value-based (includes all rows with same ORDER BY value)

```sql
-- ROWS: Exactly 3 physical rows
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW

-- RANGE: All rows within value range
RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
```

### Moving Average Example

```sql
-- Tech Haven: 3-order moving average
SELECT 
    order_date,
    order_id,
    total_amount,
    
    -- Simple average (all orders)
    AVG(total_amount) OVER () as overall_avg,
    
    -- Running average (start to current)
    AVG(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_avg,
    
    -- Moving average (last 3 orders including current)
    AVG(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as moving_avg_3,
    
    -- Centered moving average (1 before, current, 1 after)
    AVG(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) as centered_avg_3
    
FROM orders
ORDER BY order_date, order_id;
```

### Frame Examples Explained

```sql
-- Example 1: Running total (default when using ORDER BY)
SUM(total_amount) OVER (
    ORDER BY order_date
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
-- Includes: All rows from start up to current row

-- Example 2: Full partition sum (default without ORDER BY)
SUM(total_amount) OVER (
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
-- Includes: All rows in the partition

-- Example 3: 7-day rolling sum
SUM(total_amount) OVER (
    ORDER BY order_date
    RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
)
-- Includes: All rows where order_date is within 7 days before current row

-- Example 4: Next 3 rows only
SUM(total_amount) OVER (
    ORDER BY order_date
    ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING
)
-- Includes: Current row + next 3 rows
```

---

## Advanced Patterns

### Pattern 1: Top N Per Group

```sql
-- Tech Haven: Top 2 revenue-generating products per category
WITH product_revenue AS (
    SELECT 
        p.product_id,
        p.product_name,
        p.category,
        SUM(p.price * oi.quantity) as total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category 
            ORDER BY SUM(p.price * oi.quantity) DESC
        ) as revenue_rank
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT 
    category,
    product_name,
    total_revenue,
    revenue_rank
FROM product_revenue
WHERE revenue_rank <= 2
ORDER BY category, revenue_rank;
```

### Pattern 2: Running Difference Analysis

```sql
-- Tech Haven: Identify order spikes and drops
WITH order_analysis AS (
    SELECT 
        order_date,
        order_id,
        total_amount,
        LAG(total_amount, 1) OVER (ORDER BY order_date, order_id) as prev_amount,
        AVG(total_amount) OVER (
            ORDER BY order_date, order_id
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as moving_avg_7
    FROM orders
)
SELECT 
    order_date,
    order_id,
    total_amount,
    prev_amount,
    total_amount - prev_amount as change_from_prev,
    ROUND(moving_avg_7, 2) as moving_avg,
    CASE 
        WHEN total_amount > moving_avg_7 * 1.5 THEN 'SPIKE UP'
        WHEN total_amount < moving_avg_7 * 0.5 THEN 'DROP DOWN'
        ELSE 'NORMAL'
    END as order_pattern
FROM order_analysis
WHERE prev_amount IS NOT NULL
ORDER BY order_date, order_id;
```

### Pattern 3: Cohort Analysis

```sql
-- Tech Haven: Customer cohort retention
WITH first_orders AS (
    SELECT 
        customer_id,
        MIN(order_date) as first_order_date,
        DATE_TRUNC('month', MIN(order_date)) as cohort_month
    FROM orders
    GROUP BY customer_id
),
customer_orders AS (
    SELECT 
        fo.customer_id,
        fo.cohort_month,
        o.order_date,
        DATE_TRUNC('month', o.order_date) as order_month
    FROM first_orders fo
    JOIN orders o ON fo.customer_id = o.customer_id
)
SELECT 
    cohort_month,
    order_month,
    COUNT(DISTINCT customer_id) as active_customers,
    FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER (
        PARTITION BY cohort_month 
        ORDER BY order_month
    ) as cohort_size,
    ROUND(
        COUNT(DISTINCT customer_id) * 100.0 / 
        FIRST_VALUE(COUNT(DISTINCT customer_id)) OVER (
            PARTITION BY cohort_month 
            ORDER BY order_month
        ), 
        2
    ) as retention_rate
FROM customer_orders
GROUP BY cohort_month, order_month
ORDER BY cohort_month, order_month;
```

### Pattern 4: Percentile and Distribution Analysis

```sql
-- Tech Haven: Order value distribution
SELECT 
    order_id,
    total_amount,
    
    -- Percentile rank (0 to 1)
    PERCENT_RANK() OVER (ORDER BY total_amount) as percentile_rank,
    
    -- Cumulative distribution
    CUME_DIST() OVER (ORDER BY total_amount) as cumulative_dist,
    
    -- Quartile
    NTILE(4) OVER (ORDER BY total_amount) as quartile,
    
    -- Percentile classification
    CASE 
        WHEN PERCENT_RANK() OVER (ORDER BY total_amount) >= 0.75 THEN 'Top 25%'
        WHEN PERCENT_RANK() OVER (ORDER BY total_amount) >= 0.50 THEN 'Top 50%'
        WHEN PERCENT_RANK() OVER (ORDER BY total_amount) >= 0.25 THEN 'Bottom 50%'
        ELSE 'Bottom 25%'
    END as value_segment
    
FROM orders
ORDER BY total_amount DESC;
```

### Pattern 5: Gap and Island Detection

Finding consecutive sequences (e.g., consecutive days with orders).

```sql
-- Tech Haven: Find consecutive order sequences
WITH order_dates AS (
    SELECT DISTINCT order_date
    FROM orders
),
date_groups AS (
    SELECT 
        order_date,
        order_date - (ROW_NUMBER() OVER (ORDER BY order_date))::INTEGER as grp
    FROM order_dates
)
SELECT 
    MIN(order_date) as sequence_start,
    MAX(order_date) as sequence_end,
    COUNT(*) as consecutive_days
FROM date_groups
GROUP BY grp
ORDER BY sequence_start;
```

---

## Tech Haven Practice Exercises

### Setup: Create the Database

```sql
-- Create tables
CREATE TABLE customers (
    customer_id INT PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    city VARCHAR(50)
);

CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    order_date DATE,
    total_amount DECIMAL(10, 2),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2)
);

CREATE TABLE order_items (
    order_item_id INT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- Insert data
INSERT INTO customers VALUES
(1, 'Alice Johnson', 'alice@email.com', 'Seattle'),
(2, 'Bob Smith', 'bob@email.com', 'Portland'),
(3, 'Carol White', 'carol@email.com', 'Seattle'),
(4, 'David Brown', 'david@email.com', 'San Francisco'),
(5, 'Emma Davis', 'emma@email.com', 'Portland');

INSERT INTO products VALUES
(101, 'Laptop Pro', 'Computers', 1200.00),
(102, 'Wireless Mouse', 'Accessories', 25.00),
(103, 'USB-C Cable', 'Accessories', 15.00),
(104, 'Monitor 27"', 'Displays', 350.00),
(105, 'Keyboard Mechanical', 'Accessories', 120.00);

INSERT INTO orders VALUES
(1001, 1, '2026-09-01', 1245.00),
(1002, 2, '2026-09-03', 350.00),
(1003, 1, '2026-09-05', 145.00),
(1004, 3, '2026-09-07', 1200.00),
(1005, 4, '2026-09-10', 40.00),
(1006, 2, '2026-09-12', 120.00),
(1007, 1, '2026-09-15', 25.00);

INSERT INTO order_items VALUES
(1, 1001, 101, 1),
(2, 1001, 102, 1),
(3, 1001, 103, 2),
(4, 1002, 104, 1),
(5, 1003, 105, 1),
(6, 1003, 102, 1),
(7, 1004, 101, 1),
(8, 1005, 103, 1),
(9, 1005, 102, 1),
(10, 1006, 105, 1),
(11, 1007, 102, 1);
```

---

### Exercise 1: Basic Window Functions (OVER)

**Task:** For each order, show:
- Order ID
- Total amount
- Overall average order value
- How much above/below average this order is
- What percentage of total sales this order represents

<details>
<summary>💡 Hint</summary>

Use `OVER ()` for company-wide calculations. You'll need `AVG()`, `SUM()`, and arithmetic operations.
</details>

<details>
<summary>✅ Solution</summary>

```sql
SELECT 
    order_id,
    total_amount,
    ROUND(AVG(total_amount) OVER (), 2) as avg_order_value,
    ROUND(total_amount - AVG(total_amount) OVER (), 2) as diff_from_avg,
    ROUND(total_amount * 100.0 / SUM(total_amount) OVER (), 2) as pct_of_total_sales
FROM orders
ORDER BY total_amount DESC;
```
</details>

---

### Exercise 2: PARTITION BY - Category Analysis

**Task:** For each product, show:
- Product name and category
- Price
- Number of products in the same category
- Average price in the category
- Whether this product is above/below/at category average

<details>
<summary>💡 Hint</summary>

Use `PARTITION BY category` to create separate windows for each category.
</details>

<details>
<summary>✅ Solution</summary>

```sql
SELECT 
    product_name,
    category,
    price,
    COUNT(*) OVER (PARTITION BY category) as products_in_category,
    ROUND(AVG(price) OVER (PARTITION BY category), 2) as category_avg_price,
    CASE 
        WHEN price > AVG(price) OVER (PARTITION BY category) THEN 'Above Average'
        WHEN price < AVG(price) OVER (PARTITION BY category) THEN 'Below Average'
        ELSE 'At Average'
    END as price_position
FROM products
ORDER BY category, price DESC;
```
</details>

---

### Exercise 3: ORDER BY - Running Totals

**Task:** Create a daily sales report showing:
- Order date
- Daily total sales (sum of all orders on that date)
- Running total of sales
- Running average of daily sales
- Number of days with orders so far

<details>
<summary>💡 Hint</summary>

First aggregate by date, then apply window functions with ORDER BY.
</details>

<details>
<summary>✅ Solution</summary>

```sql
WITH daily_sales AS (
    SELECT 
        order_date,
        SUM(total_amount) as daily_total
    FROM orders
    GROUP BY order_date
)
SELECT 
    order_date,
    daily_total,
    SUM(daily_total) OVER (ORDER BY order_date) as running_total,
    ROUND(AVG(daily_total) OVER (ORDER BY order_date), 2) as running_avg,
    COUNT(*) OVER (ORDER BY order_date) as days_with_orders
FROM daily_sales
ORDER BY order_date;
```
</details>

---

### Exercise 4: Combined PARTITION BY + ORDER BY

**Task:** For each customer's orders, show:
- Customer name
- Order date and amount
- Running total of their spending
- Their order number (1st, 2nd, 3rd order)
- Running average of their order values

<details>
<summary>💡 Hint</summary>

Combine `PARTITION BY customer_id` with `ORDER BY order_date`.
</details>

<details>
<summary>✅ Solution</summary>

```sql
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as running_customer_total,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as order_number,
    ROUND(AVG(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ), 2) as running_avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```
</details>

---

### Exercise 5: ROW_NUMBER - Top N Per Group

**Task:** Find the top 2 best-selling products (by quantity) in each category.

<details>
<summary>💡 Hint</summary>

Use ROW_NUMBER() with PARTITION BY category, then filter WHERE row_number <= 2.
</details>

<details>
<summary>✅ Solution</summary>

```sql
WITH product_sales AS (
    SELECT 
        p.product_name,
        p.category,
        SUM(oi.quantity) as total_quantity_sold,
        ROW_NUMBER() OVER (
            PARTITION BY p.category 
            ORDER BY SUM(oi.quantity) DESC
        ) as rank_in_category
    FROM products p
    JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.product_id, p.product_name, p.category
)
SELECT 
    category,
    product_name,
    total_quantity_sold,
    rank_in_category
FROM product_sales
WHERE rank_in_category <= 2
ORDER BY category, rank_in_category;
```
</details>

---

### Exercise 6: RANK vs DENSE_RANK vs ROW_NUMBER

**Task:** Rank customers by total spending. Show all three ranking functions to understand the difference.

<details>
<summary>💡 Hint</summary>

Calculate total spending per customer first, then apply all three ranking functions.
</details>

<details>
<summary>✅ Solution</summary>

```sql
WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.name,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name
)
SELECT 
    name,
    total_spent,
    ROW_NUMBER() OVER (ORDER BY total_spent DESC) as row_num,
    RANK() OVER (ORDER BY total_spent DESC) as rank,
    DENSE_RANK() OVER (ORDER BY total_spent DESC) as dense_rank
FROM customer_spending
ORDER BY total_spent DESC;
```
</details>

---

### Exercise 7: LAG and LEAD - Comparing Orders

**Task:** For each order, show:
- Order date and amount
- Previous order date and amount
- Next order date and amount
- Days between this order and the previous one
- Days until the next order

<details>
<summary>💡 Hint</summary>

Use LAG() to look backward and LEAD() to look forward.
</details>

<details>
<summary>✅ Solution</summary>

```sql
SELECT 
    order_date,
    order_id,
    total_amount,
    LAG(order_date, 1) OVER (ORDER BY order_date) as prev_order_date,
    LAG(total_amount, 1) OVER (ORDER BY order_date) as prev_order_amount,
    LEAD(order_date, 1) OVER (ORDER BY order_date) as next_order_date,
    LEAD(total_amount, 1) OVER (ORDER BY order_date) as next_order_amount,
    order_date - LAG(order_date, 1) OVER (ORDER BY order_date) as days_since_prev,
    LEAD(order_date, 1) OVER (ORDER BY order_date) - order_date as days_until_next
FROM orders
ORDER BY order_date;
```
</details>

---

### Exercise 8: NTILE - Customer Segmentation

**Task:** Divide customers into 3 tiers (High, Medium, Low) based on their total spending.

<details>
<summary>💡 Hint</summary>

Use NTILE(3) to divide customers into three equal groups.
</details>

<details>
<summary>✅ Solution</summary>

```sql
WITH customer_spending AS (
    SELECT 
        c.customer_id,
        c.name,
        c.city,
        SUM(o.total_amount) as total_spent
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_id, c.name, c.city
)
SELECT 
    name,
    city,
    total_spent,
    NTILE(3) OVER (ORDER BY total_spent DESC) as spending_tier,
    CASE NTILE(3) OVER (ORDER BY total_spent DESC)
        WHEN 1 THEN 'High Value'
        WHEN 2 THEN 'Medium Value'
        WHEN 3 THEN 'Low Value'
    END as customer_segment
FROM customer_spending
ORDER BY total_spent DESC;
```
</details>

---

### Exercise 9: Moving Average with Frames

**Task:** Calculate a 3-order moving average of order amounts.

<details>
<summary>💡 Hint</summary>

Use `ROWS BETWEEN 2 PRECEDING AND CURRENT ROW` to create a 3-row window.
</details>

<details>
<summary>✅ Solution</summary>

```sql
SELECT 
    order_date,
    order_id,
    total_amount,
    ROUND(AVG(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_3_orders,
    COUNT(*) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as orders_in_window
FROM orders
ORDER BY order_date, order_id;
```
</details>

---

### Exercise 10: Complex Analysis - Customer Value Trends

**Task:** Create a comprehensive customer analysis showing:
- Customer name and order details
- Running total of their spending
- Their order number
- Change from their previous order
- Whether their spending is increasing or decreasing
- Their percentile rank among all customers by total spending

<details>
<summary>💡 Hint</summary>

This combines multiple window functions. Use a CTE for customer totals, then join back.
</details>

<details>
<summary>✅ Solution</summary>

```sql
WITH customer_totals AS (
    SELECT 
        customer_id,
        SUM(total_amount) as lifetime_value
    FROM orders
    GROUP BY customer_id
)
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    
    -- Running metrics
    SUM(o.total_amount) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as running_total,
    
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as order_number,
    
    -- Comparison to previous order
    LAG(o.total_amount, 1) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as prev_order_amount,
    
    o.total_amount - LAG(o.total_amount, 1) OVER (
        PARTITION BY c.customer_id 
        ORDER BY o.order_date
    ) as change_from_prev,
    
    CASE 
        WHEN o.total_amount > LAG(o.total_amount, 1) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Increasing'
        WHEN o.total_amount < LAG(o.total_amount, 1) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Decreasing'
        WHEN o.total_amount = LAG(o.total_amount, 1) OVER (
            PARTITION BY c.customer_id ORDER BY o.order_date
        ) THEN 'Stable'
        ELSE 'First Order'
    END as spending_trend,
    
    -- Customer percentile
    ROUND(PERCENT_RANK() OVER (ORDER BY ct.lifetime_value) * 100, 2) as customer_percentile
    
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN customer_totals ct ON c.customer_id = ct.customer_id
ORDER BY c.name, o.order_date;
```
</details>

---

## Quick Reference Cheat Sheet

### Basic Syntax
```sql
-- All rows
function() OVER ()

-- Grouped
function() OVER (PARTITION BY column)

-- Sequential
function() OVER (ORDER BY column)

-- Combined
function() OVER (PARTITION BY col1 ORDER BY col2)
```

### Common Functions

| Function | Use Case | Example |
|----------|----------|---------|
| `SUM() OVER ()` | Total across window | Company revenue |
| `AVG() OVER ()` | Average across window | Average order value |
| `COUNT() OVER ()` | Count rows in window | Total orders |
| `ROW_NUMBER()` | Unique sequential numbers | Order numbering |
| `RANK()` | Ranking with gaps | Competition ranking |
| `DENSE_RANK()` | Ranking without gaps | Grade ranking |
| `NTILE(n)` | Divide into buckets | Customer segments |
| `LAG(col, n)` | Previous row value | Previous order |
| `LEAD(col, n)` | Next row value | Next order |
| `FIRST_VALUE()` | First in window | Initial value |
| `LAST_VALUE()` | Last in window | Final value |

### Frame Shortcuts

```sql
-- Running total
ORDER BY date
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW

-- Moving average (3 rows)
ORDER BY date
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW

-- Entire partition
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
```

---

## Performance Tips

1. **Index columns used in PARTITION BY and ORDER BY**
2. **Limit partition sizes** - Too many small partitions can be slow
3. **Use appropriate frames** - Smaller frames = faster calculations
4. **Consider CTEs** - Break complex queries into readable steps
5. **Test with EXPLAIN** - Check query plans for optimization opportunities

---

## Common Mistakes to Avoid

❌ **Using window function in WHERE clause**
```sql
-- WRONG
WHERE ROW_NUMBER() OVER (ORDER BY total_amount DESC) <= 3

-- RIGHT
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY total_amount DESC) as rn
    FROM orders
)
SELECT * FROM ranked WHERE rn <= 3
```

❌ **Forgetting frame specification for LAST_VALUE**
```sql
-- WRONG - Only looks at current row
LAST_VALUE(amount) OVER (ORDER BY date)

-- RIGHT
LAST_VALUE(amount) OVER (
    ORDER BY date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

❌ **Confusing PARTITION BY with GROUP BY**
```sql
-- GROUP BY - Collapses rows
SELECT department, AVG(salary)
FROM employees
GROUP BY department

-- PARTITION BY - Keeps rows
SELECT name, department, salary,
       AVG(salary) OVER (PARTITION BY department)
FROM employees
```

---

## Summary

**Window functions are powerful because they:**
1. ✅ Preserve individual rows (unlike GROUP BY)
2. ✅ Add aggregate context to each row
3. ✅ Enable complex analytical queries
4. ✅ Avoid complex self-joins
5. ✅ Make running calculations easy

**The three key components:**
- `OVER ()` - Defines the window
- `PARTITION BY` - Creates groups within the window
- `ORDER BY` - Creates sequence/running calculations

**Master these patterns and you can solve:**
- Top N per group
- Running totals and averages
- Period-over-period comparisons
- Customer cohort analysis
- Ranking and percentiles
- Gap and island detection

---

**Ready to level up?** Practice all 10 exercises above, then try applying window functions to your own data!
