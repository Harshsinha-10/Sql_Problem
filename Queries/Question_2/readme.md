# Customer Loyalty Promotion — Top Spenders Analysis

## 📌 Overview

This SQL query identifies the **top 2 highest-spending customers** across all orders. It was written to support a marketing loyalty promotion that targets high-value customers.

---

## 🎯 Business Requirement

> Marketing wants to run a loyalty promotion targeting high-value customers. Identify the top 2 customers who have spent the most money overall across all their orders combined.

---

## 🧾 Deliverable

Return the following fields:

| Column | Description |
|---|---|
| `first_name` | Customer's first name |
| `last_name` | Customer's last name |
| `total_spent` | Sum of all order amounts for that customer |

Results sorted in **descending order** by `total_spent`, limited to the **top 2 rows**.

---

## 🛠️ SQL Solution

```sql
SELECT 
    c.first_name,
    c.last_name,
    SUM(o.total_amount) AS total_spent
FROM 
    customers c
JOIN 
    orders o ON c.customer_id = o.customer_id
GROUP BY 
    c.customer_id, c.first_name, c.last_name
ORDER BY 
    total_spent DESC
LIMIT 2;# Sql_Problem
