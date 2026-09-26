# Frame Specifications - Complete Guide

## Overview

Frame specifications define the **exact subset of rows** within a partition that a window function should consider. Think of it as a "sliding window" that moves through your data.

## Why Frames Matter

Without frame specifications, window functions use defaults:
- **Without ORDER BY**: All rows in the partition
- **With ORDER BY**: Start of partition to current row

Frame specifications give you precise control over which rows to include in calculations.

---

## Syntax

```sql
{ROWS | RANGE | GROUPS} BETWEEN frame_start AND frame_end
```

### Frame Boundaries

| Boundary | Meaning |
|----------|---------|
| `UNBOUNDED PRECEDING` | Start of the partition |
| `n PRECEDING` | n rows/values before current |
| `CURRENT ROW` | The current row |
| `n FOLLOWING` | n rows/values after current |
| `UNBOUNDED FOLLOWING` | End of the partition |

### Frame Types

- **ROWS**: Physical row counting (most common and predictable)
- **RANGE**: Logical value-based (includes all rows with same ORDER BY value)
- **GROUPS**: Like RANGE but for peer groups (less common)

---

## Default Frames

### Without ORDER BY

```sql
-- Default frame: entire partition
SUM(amount) OVER (PARTITION BY category)

-- Equivalent to:
SUM(amount) OVER (
    PARTITION BY category
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

### With ORDER BY

```sql
-- Default frame: start to current row
SUM(amount) OVER (ORDER BY date)

-- Equivalent to:
SUM(amount) OVER (
    ORDER BY date
    RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

---

## ROWS Frame Type

**ROWS** counts physical row positions. Most intuitive and commonly used.

### Example 1: Moving Average (3 rows)

```sql
-- 3-order moving average (current + 2 preceding)
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
| 2026-09-01 | 1001     | 1245.00      | 1245.00      | ← Only 1 row: 1245/1
| 2026-09-03 | 1002     | 350.00       | 797.50       | ← 2 rows: (1245+350)/2
| 2026-09-05 | 1003     | 145.00       | 580.00       | ← 3 rows: (1245+350+145)/3
| 2026-09-07 | 1004     | 1200.00      | 565.00       | ← 3 rows: (350+145+1200)/3
| 2026-09-10 | 1005     | 40.00        | 461.67       | ← 3 rows: (145+1200+40)/3
| 2026-09-12 | 1006     | 120.00       | 453.33       | ← 3 rows: (1200+40+120)/3
| 2026-09-15 | 1007     | 25.00        | 61.67        | ← 3 rows: (40+120+25)/3
```

**Visual Understanding:**
```
Row:     [1]  [2]  [3]  [4]  [5]  [6]  [7]
Amount: 1245  350  145 1200   40  120   25

At Row 4 (amount 1200):
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
             [2]  [3]  [4]
            350  145 1200
AVG = (350 + 145 + 1200) / 3 = 565
```

### Example 2: Centered Moving Average

```sql
-- Centered 3-period average (1 before, current, 1 after)
SELECT 
    order_date,
    total_amount,
    ROUND(AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ), 2) as centered_avg
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | total_amount | centered_avg |
|------------|--------------|--------------|
| 2026-09-01 | 1245.00      | 797.50       | ← (1245+350)/2 (no row before)
| 2026-09-03 | 350.00       | 580.00       | ← (1245+350+145)/3
| 2026-09-05 | 145.00       | 565.00       | ← (350+145+1200)/3
| 2026-09-07 | 1200.00      | 461.67       | ← (145+1200+40)/3
| 2026-09-10 | 40.00        | 453.33       | ← (1200+40+120)/3
| 2026-09-12 | 120.00       | 61.67        | ← (40+120+25)/3
| 2026-09-15 | 25.00        | 72.50        | ← (120+25)/2 (no row after)
```

### Example 3: Running Total (Explicit)

```sql
-- Running total from start to current
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as running_total
FROM orders
ORDER BY order_date;
```

### Example 4: Next N Rows

```sql
-- Sum of current + next 2 orders
SELECT 
    order_date,
    order_id,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING
    ) as next_3_orders_total
FROM orders
ORDER BY order_date;
```

**Result:**
```
| order_date | order_id | total_amount | next_3_orders_total |
|------------|----------|--------------|---------------------|
| 2026-09-01 | 1001     | 1245.00      | 1740.00             | ← 1245+350+145
| 2026-09-03 | 1002     | 350.00       | 1695.00             | ← 350+145+1200
| 2026-09-05 | 1003     | 145.00       | 1385.00             | ← 145+1200+40
| 2026-09-07 | 1004     | 1200.00      | 1360.00             | ← 1200+40+120
| 2026-09-10 | 1005     | 40.00        | 185.00              | ← 40+120+25
| 2026-09-12 | 1006     | 120.00       | 145.00              | ← 120+25 (only 1 after)
| 2026-09-15 | 1007     | 25.00        | 25.00               | ← Just current
```

---

## RANGE Frame Type

**RANGE** is value-based, not row-based. It includes all rows with the same ORDER BY value.

### Understanding RANGE

```sql
-- Sample data with duplicate dates
| order_date | amount |
|------------|--------|
| 2026-09-01 | 100    |
| 2026-09-01 | 150    | ← Same date
| 2026-09-01 | 200    | ← Same date
| 2026-09-03 | 300    |
```

### Example 5: ROWS vs RANGE Comparison

```sql
SELECT 
    order_date,
    total_amount,
    
    -- ROWS: Count 2 physical rows
    SUM(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) as rows_sum,
    
    -- RANGE: Include all rows with same date value
    SUM(total_amount) OVER (
        ORDER BY order_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as range_sum
    
FROM orders
ORDER BY order_date;
```

### Example 6: Time-Based RANGE

```sql
-- Sum orders within last 7 days (including today)
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date
        RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
    ) as rolling_7day_sum
FROM orders
ORDER BY order_date;
```

**When to use RANGE:**
- ✅ Time-based windows (last N days, hours, etc.)
- ✅ When you want to include all tied values
- ✅ Value-based calculations

**When to use ROWS:**
- ✅ Fixed number of records (top N, last N)
- ✅ Moving averages over records
- ✅ Most general use cases (more predictable)

---

## Common Frame Patterns

### Pattern 1: Running Total

```sql
-- Cumulative sum
ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
```

**Example:**
```sql
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as cumulative_total
FROM orders;
```

### Pattern 2: Moving Average (N periods)

```sql
-- Last N rows including current
ROWS BETWEEN (N-1) PRECEDING AND CURRENT ROW
```

**Examples:**
```sql
-- 3-period moving average
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW

-- 7-period moving average
ROWS BETWEEN 6 PRECEDING AND CURRENT ROW

-- 30-period moving average
ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
```

### Pattern 3: Centered Moving Average

```sql
-- N before, current, N after
ROWS BETWEEN N PRECEDING AND N FOLLOWING
```

**Example:**
```sql
-- 5-period centered (2 before, current, 2 after)
ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
```

### Pattern 4: Entire Partition

```sql
-- All rows in partition
ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
```

**Example:**
```sql
-- Total revenue in partition
SUM(total_amount) OVER (
    PARTITION BY category
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

### Pattern 5: Forward-Looking Window

```sql
-- Current + next N rows
ROWS BETWEEN CURRENT ROW AND N FOLLOWING
```

**Example:**
```sql
-- Next 3 orders including current
ROWS BETWEEN CURRENT ROW AND 2 FOLLOWING
```

---

## Practical Use Cases

### Use Case 1: Sales Trend Smoothing

```sql
-- 7-day moving average to smooth out daily fluctuations
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
    ROUND(AVG(daily_total) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 2) as ma_7_day,
    ROUND(AVG(daily_total) OVER (
        ORDER BY order_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ), 2) as ma_30_day
FROM daily_sales
ORDER BY order_date;
```

### Use Case 2: Customer Recency Analysis

```sql
-- Find customers whose last 3 orders all declined in value
WITH order_trends AS (
    SELECT 
        c.customer_id,
        c.name,
        o.order_date,
        o.total_amount,
        
        -- Average of last 3 orders
        AVG(o.total_amount) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) as avg_last_3,
        
        -- Count orders
        COUNT(*) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) as orders_in_window,
        
        -- Is this order less than the average of previous 2?
        LAG(o.total_amount, 1) OVER (
            PARTITION BY c.customer_id 
            ORDER BY o.order_date
        ) as prev_order
        
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
)
SELECT 
    name,
    order_date,
    total_amount,
    avg_last_3,
    CASE 
        WHEN orders_in_window = 3 AND total_amount < avg_last_3 
        THEN '⚠️ Declining'
        ELSE 'OK'
    END as trend_warning
FROM order_trends
WHERE orders_in_window >= 3
ORDER BY name, order_date;
```

### Use Case 3: Outlier Detection with Rolling Statistics

```sql
-- Identify orders that are outliers compared to recent history
WITH rolling_stats AS (
    SELECT 
        order_date,
        order_id,
        total_amount,
        
        AVG(total_amount) OVER (
            ORDER BY order_date
            ROWS BETWEEN 9 PRECEDING AND 1 PRECEDING
        ) as prev_10_avg,
        
        -- Simple standard deviation approximation
        AVG(ABS(total_amount - AVG(total_amount) OVER (
            ORDER BY order_date
            ROWS BETWEEN 9 PRECEDING AND 1 PRECEDING
        ))) OVER (
            ORDER BY order_date
            ROWS BETWEEN 9 PRECEDING AND 1 PRECEDING
        ) as prev_10_deviation
        
    FROM orders
)
SELECT 
    order_date,
    order_id,
    total_amount,
    ROUND(prev_10_avg, 2) as recent_avg,
    CASE 
        WHEN total_amount > prev_10_avg + (2 * prev_10_deviation) 
        THEN '📈 Unusually High'
        WHEN total_amount < prev_10_avg - (2 * prev_10_deviation) 
        THEN '📉 Unusually Low'
        ELSE 'Normal'
    END as outlier_status
FROM rolling_stats
WHERE prev_10_avg IS NOT NULL
ORDER BY order_date;
```

### Use Case 4: Quarter-to-Date Calculations

```sql
-- Running total within each quarter
SELECT 
    order_date,
    total_amount,
    EXTRACT(QUARTER FROM order_date) as quarter,
    SUM(total_amount) OVER (
        PARTITION BY 
            EXTRACT(YEAR FROM order_date),
            EXTRACT(QUARTER FROM order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as qtd_revenue
FROM orders
ORDER BY order_date;
```

### Use Case 5: Growth Momentum

```sql
-- Compare current period to multiple historical windows
SELECT 
    order_date,
    total_amount,
    
    -- Compare to previous order
    total_amount - LAG(total_amount, 1) OVER (ORDER BY order_date) as vs_prev_1,
    
    -- Compare to average of last 3
    total_amount - AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
    ) as vs_prev_3_avg,
    
    -- Compare to average of last 7
    total_amount - AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
    ) as vs_prev_7_avg,
    
    -- Momentum indicator
    CASE 
        WHEN total_amount > AVG(total_amount) OVER (
            ORDER BY order_date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AND total_amount > AVG(total_amount) OVER (
            ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ) THEN 'Strong Growth'
        WHEN total_amount < AVG(total_amount) OVER (
            ORDER BY order_date ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING
        ) AND total_amount < AVG(total_amount) OVER (
            ORDER BY order_date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
        ) THEN 'Declining'
        ELSE 'Mixed'
    END as momentum
    
FROM orders
ORDER BY order_date;
```

---

## Frame Specification Gotchas

### Gotcha 1: LAST_VALUE Needs Explicit Frame

```sql
-- ❌ WRONG: Only looks up to current row
LAST_VALUE(amount) OVER (ORDER BY date)

-- ✅ RIGHT: Look at entire partition
LAST_VALUE(amount) OVER (
    ORDER BY date
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
)
```

### Gotcha 2: RANGE with Non-Numeric ORDER BY

```sql
-- ⚠️ PROBLEM: RANGE doesn't support INTERVAL with non-date types
RANGE BETWEEN 5 PRECEDING AND CURRENT ROW  -- Error if not date/time!

-- ✅ SOLUTION: Use ROWS instead
ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
```

### Gotcha 3: Asymmetric Windows

```sql
-- This works but be careful what you're calculating!
ROWS BETWEEN 5 PRECEDING AND 10 FOLLOWING

-- Window size varies:
-- - At start: 1 to 11 rows
-- - In middle: 16 rows (5+1+10)
-- - At end: 6 to 16 rows
```

### Gotcha 4: Negative Offsets

```sql
-- ❌ WRONG: Can't use negative numbers
ROWS BETWEEN -2 PRECEDING AND CURRENT ROW  -- Error!

-- ✅ RIGHT: Use proper keywords
ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
```

---

## Performance Considerations

### 1. Smaller Frames = Better Performance

```sql
-- Faster: Small fixed window
AVG(amount) OVER (ORDER BY date ROWS BETWEEN 9 PRECEDING AND CURRENT ROW)

-- Slower: Entire partition
AVG(amount) OVER (ORDER BY date ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
```

### 2. ROWS vs RANGE

```sql
-- Usually faster: ROWS (simple row counting)
ROWS BETWEEN 5 PRECEDING AND CURRENT ROW

-- Can be slower: RANGE (value comparison)
RANGE BETWEEN INTERVAL '5 days' PRECEDING AND CURRENT ROW
```

### 3. Index ORDER BY Columns

```sql
-- Create index for better window function performance
CREATE INDEX idx_orders_date ON orders(order_date);

-- Benefits all ORDER BY order_date windows
```

### 4. Materialize Complex Windows

```sql
-- If using same frame multiple times, calculate once
CREATE TEMP TABLE orders_with_ma AS
SELECT 
    *,
    AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) as ma_7
FROM orders;

-- Now reuse without recalculation
SELECT * FROM orders_with_ma WHERE ma_7 > 500;
```

---

## Practice Exercises

### Exercise 1: 3-Period Moving Average
Calculate a 3-order moving average.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    total_amount,
    ROUND(AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) as moving_avg_3
FROM orders
ORDER BY order_date;
```
</details>

### Exercise 2: YTD Running Total
Calculate year-to-date revenue for each order.

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    total_amount,
    SUM(total_amount) OVER (
        PARTITION BY EXTRACT(YEAR FROM order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) as ytd_revenue
FROM orders
ORDER BY order_date;
```
</details>

### Exercise 3: Centered Average
Calculate a 5-period centered moving average (2 before, current, 2 after).

<details>
<summary>Solution</summary>

```sql
SELECT 
    order_date,
    total_amount,
    ROUND(AVG(total_amount) OVER (
        ORDER BY order_date
        ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
    ), 2) as centered_avg_5
FROM orders
ORDER BY order_date;
```
</details>

### Exercise 4: Customer Running Average
Calculate each customer's running average order value.

<details>
<summary>Solution</summary>

```sql
SELECT 
    c.name,
    o.order_date,
    o.total_amount,
    ROUND(AVG(o.total_amount) OVER (
        PARTITION BY c.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ), 2) as running_avg
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
ORDER BY c.name, o.order_date;
```
</details>

---

## Frame Specification Cheat Sheet

| Pattern | Frame Specification | Use Case |
|---------|-------------------|----------|
| Running Total | `UNBOUNDED PRECEDING TO CURRENT ROW` | Cumulative sum |
| Moving Avg (N) | `(N-1) PRECEDING TO CURRENT ROW` | Trend smoothing |
| Centered Avg | `N PRECEDING TO N FOLLOWING` | Balanced smoothing |
| Entire Window | `UNBOUNDED PRECEDING TO UNBOUNDED FOLLOWING` | Global stats |
| Look Ahead | `CURRENT ROW TO N FOLLOWING` | Future projection |
| Last N Only | `N PRECEDING TO 1 PRECEDING` | Exclude current |

---

## Summary

**Frame specifications provide:**
- ✅ Precise control over window size
- ✅ Moving averages and trends
- ✅ Flexible calculations (past, current, future)
- ✅ Efficient processing of time series data

**Key Points:**
1. **ROWS** counts physical rows (most common)
2. **RANGE** is value-based (for time windows)
3. Default frame depends on ORDER BY presence
4. **LAST_VALUE requires explicit full frame**
5. Smaller frames = better performance

**Remember:**
- Always specify frames explicitly for clarity
- Use ROWS for predictable behavior
- Use RANGE for time-based windows
- Test frame boundaries with small datasets first
- Profile performance with large datasets

---

**Congratulations!** You now understand all major window function concepts. Practice with real data to master these powerful analytical tools!
