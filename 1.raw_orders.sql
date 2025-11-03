/* ===========================================================
   Retail demo project (SQL Server / T‑SQL)
   Part 1: Create DB, schema, raw table, and insert messy data
   =========================================================== */

-- Create & switch to a working database (safe if it already exists)
IF DB_ID('RetailDemo') IS NULL
    CREATE DATABASE RetailDemo;
GO
USE RetailDemo;
GO

-- Create a schema to keep things tidy
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'demo')
    EXEC('CREATE SCHEMA demo;');
GO

-- Raw (messy) table – store everything as NVARCHAR to simulate real-world mess
IF OBJECT_ID('demo.raw_orders','U') IS NOT NULL DROP TABLE demo.raw_orders;
CREATE TABLE demo.raw_orders (
    order_id         NVARCHAR(50),
    order_date       NVARCHAR(50),
    customer_id      NVARCHAR(50),
    state            NVARCHAR(50),
    product_category NVARCHAR(100),
    product_name     NVARCHAR(100),
    units            NVARCHAR(50),
    unit_price       NVARCHAR(50),
    discount         NVARCHAR(50),  -- "10%", "0.1", "NA"
    tax_rate         NVARCHAR(50),  -- "8%", "0.08"
    status           NVARCHAR(50)   -- "Completed", "Returned", etc.
);

-- Insert messy sample data (Jan–Mar 2025)
INSERT INTO demo.raw_orders VALUES
('1001', '2025-01-05', '501', ' ca ', 'Electronics',       'Headphones',    '2',     '$59.99',   '10%',     '8%',     'Completed'),
('1002', '01/06/2025', '502', 'TX',   'Home & Kitchen',     'Toaster',       '1',     ' $24.50 ', '0.05',    '8.25%',  'completed'),
('1003', '2025/01/07', '503', 'WA',   'Sports',             'Yoga Mat',      '3 pcs', '$19.00',   '',        '7.5%',   'Shipped'),
('1004', 'Jan 08 2025','',    'FL',   'Electronics ',       'Mouse',         '1',     '$15',      'NA',      '6%',     'Completed'),
('1005', '2025-01-09', '504', 'New York','home',            'Blender',       '2',     ' $49.99',  '15%',     '0.0875', 'Completed'),
('1005', '2025-01-10', '504', 'NY',   'HOME',               'Blender',       '2',     '$49.99',   '0.15',    '8.75%',  'Completed'), -- duplicate id, later date
('1006', '2/15/2025',  '505', 'CA',   'Electronics',        'USB Cable',     '5',     '$5.99',    '0%',      '8%',     'Returned'),
('1007', '2025/02/16', '506', ' ca',  'Home & Kitchen',     'Kettle',        'two',   '$39.99',   '10%',     '8%',     'Completed'), -- invalid units (word)
('1008', 'Mar 05 2025','507', 'TX',   'Sports',             'Dumbbell',      '4',     '$25.00',   '0.2',     '8.25%',  'Completed'),
('1009', '2025-03-06', 'N/A', 'wa',   'Electronics',        'Keyboard',      '1',     '49.00',    '0',       '7.5%',   'Completed'),
('1010', '2025/03/07', '508', 'FL ',  'Home & Kitchen',     'Air Fryer',     '1',     '$120.00',  '5%',      '6%',     'CANCELLED'),
('1011', '03/08/2025', '509', 'TX',   'Electronics',        'Monitor',       '1',     '$199.99',  ' 10 %',   '8.25%',  'Completed'),
('1012', '2025-03-09', '510', 'CA',   'Sports ',            'Tennis Racket', '1',     '$89.50',   '0.00',    '8%',     'Completed'),
('1013', '2025-03-10', '511', 'NY',   'Home & Kitchen',     'Blender',       '1',     '$55',      '5%',      '8.75%',  'Completed'),
('1014', '2025-01-11', '512', 'WA',   'electronics',        'Webcam',        '1',     '$35.00',   '0',       '7.5%',   'Completed'),
('1015', '2025-02-20', '513', 'FL',   'Sports',             'Yoga Mat',      '2',     '$19.00',   '10%',     '6%',     'Completed'),
('1016', '2025-03-12', '514', 'TX',   'Electronics',        'Headphones',    '1',     '$59.99',   '0',       '8.25%',  'Completed'),
('1017', '2025-01-15', '515', 'CA',   'Home & Kitchen',     'Toaster',       '1',     '$24.50',   '0',       '8%',     'Completed'),
('1018', '2025-02-22', '516', 'wa ',  'Electronics',        'Mouse',         '1',     '$15',      '',        '7.5%',   'Completed');

SELECT TOP 5 * FROM demo.raw_orders ORDER BY order_id;
