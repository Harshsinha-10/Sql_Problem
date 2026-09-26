 -- Clean up existing tables if any (dropped in reverse dependency order)
  DROP TABLE IF EXISTS order_items;
  DROP TABLE IF EXISTS orders;
  DROP TABLE IF EXISTS products;
  DROP TABLE IF EXISTS customers;

  -- 1. Create Tables
  CREATE TABLE customers (
      customer_id INT PRIMARY KEY,
      name VARCHAR(100),
      email VARCHAR(100),
      city VARCHAR(50)
  );

  CREATE TABLE products (
      product_id INT PRIMARY KEY,
      product_name VARCHAR(100),
      category VARCHAR(50),
      price DECIMAL(10, 2)
  );

  CREATE TABLE orders (
      order_id INT PRIMARY KEY,
      customer_id INT,
      order_date DATE,
      total_amount DECIMAL(10, 2),
      FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
  );

  CREATE TABLE order_items (
      order_item_id INT PRIMARY KEY,
      order_id INT,
      product_id INT,
      quantity INT,
      FOREIGN KEY (order_id) REFERENCES orders(order_id),
      FOREIGN KEY (product_id) REFERENCES products(product_id)
  );

  -- 2. Insert Sample Data
  INSERT INTO customers (customer_id, name, email, city) VALUES
  (1, 'Alice Johnson', 'alice@email.com', 'Seattle'),
  (2, 'Bob Smith', 'bob@email.com', 'Portland'),
  (3, 'Carol White', 'carol@email.com', 'Seattle'),
  (4, 'David Brown', 'david@email.com', 'San Francisco'),
  (5, 'Emma Davis', 'emma@email.com', 'Portland');

  INSERT INTO products (product_id, product_name, category, price) VALUES
  (101, 'Laptop Pro', 'Computers', 1200.00),
  (102, 'Wireless Mouse', 'Accessories', 25.00),
  (103, 'USB-C Cable', 'Accessories', 15.00),
  (104, 'Monitor 27"', 'Displays', 350.00),
  (105, 'Keyboard Mechanical', 'Accessories', 120.00);

  INSERT INTO orders (order_id, customer_id, order_date, total_amount) VALUES
  (1001, 1, '2026-09-01', 1245.00),
  (1002, 2, '2026-09-03', 350.00),
  (1003, 1, '2026-09-05', 145.00),
  (1004, 3, '2026-09-07', 1200.00),
  (1005, 4, '2026-09-10', 40.00),
  (1006, 2, '2026-09-12', 120.00),
  (1007, 1, '2026-09-15', 25.00);

  INSERT INTO order_items (order_item_id, order_id, product_id, quantity) VALUES
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


SELECT c.name,c.email, c.city
FROM customers c
LEFT JOIN orders o
ON c.customer_id = o.customer_id
where o.order_id IS NULL;
