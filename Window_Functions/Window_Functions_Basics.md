# Window Functions - Starting from the Basics

## What is a Window Function?

Imagine you have a list of employees with their salaries. You want to see:
- Each employee's salary
- The average salary of ALL employees (next to each row)

**Normal way (doesn't work well):**
```sql
-- This gives you ONLY the average, losing individual employees
SELECT AVG(salary) FROM employees;
```

**Window function way:**
```sql
-- This gives you BOTH individual rows AND the average
SELECT 
    employee_name,
    salary,
    AVG(salary) OVER () as overall_average
FROM employees;
```

**Key insight:** Window functions let you **keep all your rows** while **adding calculated information** from a group.

---

## Let's Build a Practice Dataset

First, let's create a simple employee table to practice with:

```sql
-- Create a practice table
CREATE TABLE employees (
    employee_id INT,
    employee_name VARCHAR(50),
    department VARCHAR(50),
    salary DECIMAL(10, 2),
    hire_date DATE
);

-- Insert sample data
INSERT INTO employees VALUES
(1, 'Alice', 'Sales', 60000, '2020-01-15'),
(2, 'Bob', 'Sales', 50000, '2021-03-20'),
(3, 'Carol', 'IT', 80000, '2019-06-10'),
(4, 'Dave', 'IT', 70000, '2021-08-05'),
(5, 'Eve', 'Sales', 55000, '2020-11-12'),
(6, 'Frank', 'IT', 75000, '2020-02-28'),
(7, 'Grace', 'HR', 65000, '2019-09-15'),
(8, 'Henry', 'HR', 62000, '2021-01-10');
```

---

## Lesson 1: The Simplest Window Function

### OVER () - Process ALL Rows

```sql
SELECT 
    employee_name,
    salary,
    AVG(salary) OVER () as company_average
FROM employees;
```

**Result:**
```
| employee_name | salary | company_average |
|---------------|--------|-----------------|
| Alice         | 60000  | 64625           |
| Bob           | 50000  | 64625           |
| Carol         | 80000  | 64625           |
| Dave          | 70000  | 64625           |
| Eve           | 55000  | 64625           |
| Frank         | 75000  | 64625           |
| Grace         | 65000  | 64625           |
| Henry         | 62000  | 64625           |
```

**What happened?**
- Every employee row is preserved
- The company average (64,625) is calculated once and shown on every row
- `OVER ()` means "consider ALL rows"

### Practice: Try Different Aggregates

```sql
SELECT 
    employee_name,
    salary,
    AVG(salary) OVER () as avg_salary,
    MIN(salary) OVER () as min_salary,
    MAX(salary) OVER () as max_salary,
    COUNT(*) OVER () as total_employees,
    SUM(salary) OVER () as total_payroll
FROM employees;
```

**Result:**
```
| employee_name | salary | avg_salary | min_salary | max_salary | total_employees | total_payroll |
|---------------|--------|------------|------------|------------|-----------------|---------------|
| Alice         | 60000  | 64625      | 50000      | 80000      | 8               | 517000        |
| Bob           | 50000  | 64625      | 50000      | 80000      | 8               | 517000        |
| ...           | ...    | ...        | ...        | ...        | ...             | ...           |
```

**Exercise 1:** How much is each employee's salary compared to the company average?

```sql
SELECT 
    employee_name,
    salary,
    AVG(salary) OVER () as company_avg,
    salary - AVG(salary) OVER () as difference_from_avg,
    ROUND((salary / AVG(salary) OVER ()) * 100, 2) as pct_of_average
FROM employees;
```

---

## Lesson 2: PARTITION BY - Creating Groups

Now let's look at **department averages** instead of company average.

### The Wrong Way (Using GROUP BY)

```sql
-- This collapses the data - you lose individual employees!
SELECT 
    department,
    AVG(salary) as dept_avg
FROM employees
GROUP BY department;
```

**Result:**
```
| department | dept_avg |
|------------|----------|
| Sales      | 55000    |
| IT         | 75000    |
| HR         | 63500    |
```

You only get 3 rows (one per department), losing all employee details!

### The Right Way (Using PARTITION BY)

```sql
SELECT 
    employee_name,
    department,
    salary,
    AVG(salary) OVER (PARTITION BY department) as dept_average
FROM employees
ORDER BY department, employee_name;
```

**Result:**
```
| employee_name | department | salary | dept_average |
|---------------|------------|--------|--------------|
| Grace         | HR         | 65000  | 63500        |
| Henry         | HR         | 62000  | 63500        |
| Carol         | IT         | 80000  | 75000        |
| Dave          | IT         | 70000  | 75000        |
| Frank         | IT         | 75000  | 75000        |
| Alice         | Sales      | 60000  | 55000        |
| Bob           | Sales      | 50000  | 55000        |
| Eve           | Sales      | 55000  | 55000        |
```

**What happened?**
- `PARTITION BY department` says: "Calculate the average **within each department**"
- All 8 employee rows are kept
- Each employee sees their department's average

**Think of PARTITION BY like this:**
- Take your data
- Divide it into groups (partitions)
- Run the calculation within each group
- But keep all individual rows

### Visual Understanding

```
Without PARTITION BY:          With PARTITION BY department:
All employees together         Split into groups

[All 8 employees]              [HR: Grace, Henry]
    ↓                              ↓
Calculate AVG                  Calculate AVG for HR only
    ↓                              ↓
Show on all rows              Show on HR rows only

                               [IT: Carol, Dave, Frank]
                                   ↓
                               Calculate AVG for IT only
                                   ↓
                               Show on IT rows only

                               [Sales: Alice, Bob, Eve]
                                   ↓
                               Calculate AVG for Sales only
                                   ↓
                               Show on Sales rows only
```

### Practice: Multiple Partitions

```sql
-- Department statistics for each employee
SELECT 
    employee_name,
    department,
    salary,
    COUNT(*) OVER (PARTITION BY department) as dept_employee_count,
    AVG(salary) OVER (PARTITION BY department) as dept_avg_salary,
    MIN(salary) OVER (PARTITION BY department) as dept_min_salary,
    MAX(salary) OVER (PARTITION BY department) as dept_max_salary
FROM employees
ORDER BY department, salary DESC;
```

**Exercise 2:** Find how much above or below the department average each employee is:

```sql
SELECT 
    employee_name,
    department,
    salary,
    AVG(salary) OVER (PARTITION BY department) as dept_avg,
    salary - AVG(salary) OVER (PARTITION BY department) as diff_from_dept_avg,
    CASE 
        WHEN salary > AVG(salary) OVER (PARTITION BY department) THEN 'Above Average'
        WHEN salary < AVG(salary) OVER (PARTITION BY department) THEN 'Below Average'
        ELSE 'At Average'
    END as performance_category
FROM employees
ORDER BY department, salary DESC;
```

---

## Lesson 3: ORDER BY - Creating Sequences

`ORDER BY` inside a window function creates a **running calculation**.

### Running Total (Cumulative Sum)

```sql
SELECT 
    employee_name,
    salary,
    SUM(salary) OVER (ORDER BY employee_id) as running_total
FROM employees;
```

**Result:**
```
| employee_name | salary | running_total |
|---------------|--------|---------------|
| Alice         | 60000  | 60000         |  -- Just Alice
| Bob           | 50000  | 110000        |  -- Alice + Bob
| Carol         | 80000  | 190000        |  -- Alice + Bob + Carol
| Dave          | 70000  | 260000        |  -- Alice + Bob + Carol + Dave
| Eve           | 55000  | 315000        |  -- All 5 so far
| Frank         | 75000  | 390000        |
| Grace         | 65000  | 455000        |
| Henry         | 62000  | 517000        |  -- All 8 employees
```

**What's happening?**
- Start with first row: sum = 60,000
- Second row: add Bob's salary: sum = 110,000
- Third row: add Carol's salary: sum = 190,000
- And so on...

### Running Average

```sql
SELECT 
    employee_name,
    hire_date,
    salary,
    AVG(salary) OVER (ORDER BY hire_date) as running_avg_salary
FROM employees
ORDER BY hire_date;
```

**Result:**
```
| employee_name | hire_date  | salary | running_avg_salary |
|---------------|------------|--------|--------------------|
| Carol         | 2019-06-10 | 80000  | 80000              |  -- First hire
| Grace         | 2019-09-15 | 65000  | 72500              |  -- Avg of Carol & Grace
| Alice         | 2020-01-15 | 60000  | 68333              |  -- Avg of first 3
| Frank         | 2020-02-28 | 75000  | 70000              |  -- Avg of first 4
| Eve           | 2020-11-12 | 55000  | 67000              |  -- Avg of first 5
| Henry         | 2021-01-10 | 62000  | 66166              |
| Bob           | 2021-03-20 | 50000  | 63857              |
| Dave          | 2021-08-05 | 70000  | 64625              |  -- All 8 employees
```

**Use case:** "What was the average salary as we hired each person?"

### Practice: COUNT with ORDER BY

```sql
SELECT 
    employee_name,
    hire_date,
    COUNT(*) OVER (ORDER BY hire_date) as employees_hired_so_far
FROM employees
ORDER BY hire_date;
```

---

## Lesson 4: Combining PARTITION BY and ORDER BY

This is where it gets powerful!

### Running Total PER Department

```sql
SELECT 
    employee_name,
    department,
    salary,
    SUM(salary) OVER (
        PARTITION BY department 
        ORDER BY employee_id
    ) as dept_running_total
FROM employees
ORDER BY department, employee_id;
```

**Result:**
```
| employee_name | department | salary | dept_running_total |
|---------------|------------|--------|-------------------|
| Grace         | HR         | 65000  | 65000             |  -- First HR employee
| Henry         | HR         | 62000  | 127000            |  -- Both HR employees
| Carol         | IT         | 80000  | 80000             |  -- First IT employee
| Dave          | IT         | 70000  | 150000            |  -- Carol + Dave
| Frank         | IT         | 75000  | 225000            |  -- All 3 IT employees
| Alice         | Sales      | 60000  | 60000             |  -- First Sales employee
| Bob           | Sales      | 50000  | 110000            |  -- Alice + Bob
| Eve           | Sales      | 55000  | 165000            |  -- All 3 Sales employees
```

**Understanding:**
```
PARTITION BY department → Split into HR, IT, Sales groups
ORDER BY employee_id    → Within each group, create running total
```

### Real-World Example: Hiring Budget Tracking

```sql
SELECT 
    employee_name,
    department,
    hire_date,
    salary,
    SUM(salary) OVER (
        PARTITION BY department 
        ORDER BY hire_date
    ) as cumulative_dept_payroll,
    COUNT(*) OVER (
        PARTITION BY department 
        ORDER BY hire_date
    ) as employees_in_dept_so_far
FROM employees
ORDER BY department, hire_date;
```

**Use case:** "As we hired each person in each department, what was the growing payroll?"

---

## Lesson 5: Understanding the Default Frame

When you use `ORDER BY` in a window function, SQL applies a default frame:

```sql
-- These two are IDENTICAL:
SUM(salary) OVER (ORDER BY employee_id)

SUM(salary) OVER (
    ORDER BY employee_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
)
```

**Translation:** "From the start (UNBOUNDED PRECEDING) to the current row (CURRENT ROW)"

This is why you get a running total!

---

## Quick Reference Guide

### 1. All Rows (No Partition, No Order)
```sql
AVG(salary) OVER ()
-- Calculates across ALL rows, shows same value everywhere
```

### 2. Grouped Calculations (PARTITION BY)
```sql
AVG(salary) OVER (PARTITION BY department)
-- Calculates within each department group
-- Shows department average on each row
```

### 3. Running Calculations (ORDER BY)
```sql
SUM(salary) OVER (ORDER BY hire_date)
-- Creates running total in date order
-- Each row includes itself + all previous rows
```

### 4. Grouped Running Calculations (Both)
```sql
SUM(salary) OVER (PARTITION BY department ORDER BY hire_date)
-- Running total within each department
-- Resets for each department group
```

---

## Practice Exercises

Use the employees table we created. Try these yourself:

### Exercise 1: Basic Window
Find each employee's salary and what percentage of the total payroll they represent.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    employee_name,
    salary,
    SUM(salary) OVER () as total_payroll,
    ROUND((salary * 100.0 / SUM(salary) OVER ()), 2) as pct_of_payroll
FROM employees;
```
</details>

### Exercise 2: Partition Practice
Show each employee with:
- Their salary
- Their department's total payroll
- Their percentage of their department's payroll

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    employee_name,
    department,
    salary,
    SUM(salary) OVER (PARTITION BY department) as dept_payroll,
    ROUND((salary * 100.0 / SUM(salary) OVER (PARTITION BY department)), 2) as pct_of_dept_payroll
FROM employees
ORDER BY department, salary DESC;
```
</details>

### Exercise 3: Running Total
Create a report showing how total company payroll grew with each hire.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    employee_name,
    hire_date,
    salary,
    SUM(salary) OVER (ORDER BY hire_date) as cumulative_payroll,
    COUNT(*) OVER (ORDER BY hire_date) as total_employees_hired,
    AVG(salary) OVER (ORDER BY hire_date) as avg_salary_at_this_point
FROM employees
ORDER BY hire_date;
```
</details>

### Exercise 4: Combined Challenge
For each department, show the running total of salaries as people were hired.

<details>
<summary>Click for solution</summary>

```sql
SELECT 
    employee_name,
    department,
    hire_date,
    salary,
    SUM(salary) OVER (
        PARTITION BY department 
        ORDER BY hire_date
    ) as dept_running_payroll,
    ROUND(AVG(salary) OVER (
        PARTITION BY department 
        ORDER BY hire_date
    ), 2) as dept_avg_at_this_point
FROM employees
ORDER BY department, hire_date;
```
</details>

---

## Common Mistakes to Avoid

### Mistake 1: Confusing GROUP BY with PARTITION BY

```sql
-- WRONG: This loses detail
SELECT department, AVG(salary)
FROM employees
GROUP BY department;

-- RIGHT: This keeps detail
SELECT employee_name, department, salary,
       AVG(salary) OVER (PARTITION BY department)
FROM employees;
```

### Mistake 2: Forgetting ORDER BY for Running Totals

```sql
-- This gives you the TOTAL for each row (not running)
SELECT employee_name, salary,
       SUM(salary) OVER ()
FROM employees;

-- This gives you the RUNNING total
SELECT employee_name, salary,
       SUM(salary) OVER (ORDER BY employee_id)
FROM employees;
```

### Mistake 3: Wrong ORDER BY Column

```sql
-- If you want chronological running total, order by date!
SUM(salary) OVER (ORDER BY hire_date)  -- Correct
SUM(salary) OVER (ORDER BY employee_name)  -- Wrong for time series
```

---

## What's Next?

Now that you understand the basics:
- ✅ What window functions do (preserve rows + add calculations)
- ✅ OVER () for all rows
- ✅ PARTITION BY for groups
- ✅ ORDER BY for running calculations
- ✅ Combining both

**Next topics to explore:**
1. **Ranking functions** (ROW_NUMBER, RANK, DENSE_RANK)
2. **LAG and LEAD** (accessing previous/next rows)
3. **Frame specifications** (custom row ranges)
4. **Advanced patterns** (moving averages, top N per group)

Let me know when you're ready to move forward!
