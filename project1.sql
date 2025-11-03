/* ===========================================================
   Retail demo project (SQL Server / T‑SQL)
   What this script does:
   - Creates DB + schema
   - Inserts a messy dataset
   - Cleans & standardizes data
   - Builds a clean table and analysis views
   =========================================================== */

-- 0) Create & switch to a working database
IF DB_ID('RetailDemo') IS NULL
    CREATE DATABASE RetailDemo;
GO
USE RetailDemo;
GO

-- 1) Create schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'demo')
    EXEC('CREATE SCHEMA demo;');
GO

-- 2) Raw (messy) table – everything as text
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

-- 3) Insert messy sample data (Jan–Mar 2025)
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

-- Quick peek
SELECT TOP 5 * FROM demo.raw_orders ORDER BY order_id;

-- 4) Clean & standardize into a typed table with computed net_revenue
IF OBJECT_ID('demo.orders_clean','U') IS NOT NULL DROP TABLE demo.orders_clean;
GO

;WITH base AS (
    SELECT
        LTRIM(RTRIM(order_id))         AS order_id_raw,
        LTRIM(RTRIM(order_date))       AS order_date_raw,
        LTRIM(RTRIM(customer_id))      AS customer_id_raw,
        LTRIM(RTRIM(state))            AS state_raw,
        LTRIM(RTRIM(product_category)) AS product_category_raw,
        LTRIM(RTRIM(product_name))     AS product_name_raw,
        LTRIM(RTRIM(units))            AS units_raw,
        LTRIM(RTRIM(unit_price))       AS unit_price_raw,
        LTRIM(RTRIM(discount))         AS discount_raw,
        LTRIM(RTRIM(tax_rate))         AS tax_rate_raw,
        UPPER(LTRIM(RTRIM(status)))    AS status_norm
    FROM demo.raw_orders
),
parsed AS (
    SELECT
        TRY_CONVERT(INT, order_id_raw) AS order_id,

        /* Handle multiple date formats; TRY_CONVERT styles + TRY_PARSE for "Mar 05 2025" */
        COALESCE(
            TRY_CONVERT(DATE, order_date_raw, 23),   -- YYYY-MM-DD
            TRY_CONVERT(DATE, order_date_raw, 101),  -- MM/DD/YYYY
            TRY_CONVERT(DATE, order_date_raw, 111),  -- YYYY/MM/DD
            TRY_PARSE(order_date_raw AS DATE USING 'en-US')  -- e.g., "Jan 08 2025"
        ) AS order_date,

        TRY_CONVERT(INT, customer_id_raw) AS customer_id,

        /* Normalize states (trim + uppercase + map long names) */
        CASE
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('CALIFORNIA','CA') THEN 'CA'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('TEXAS','TX') THEN 'TX'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('WASHINGTON','WA') THEN 'WA'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('FLORIDA','FL') THEN 'FL'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('NEW YORK','NY') THEN 'NY'
            ELSE UPPER(LTRIM(RTRIM(state_raw)))
        END AS state,

        /* Normalize categories to 3 buckets */
        CASE
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'elect%' THEN 'Electronics'
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'home%'  THEN 'Home & Kitchen'
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'sport%' THEN 'Sports'
            ELSE CONCAT(UPPER(LEFT(LTRIM(RTRIM(product_category_raw)),1)),
                        LOWER(SUBSTRING(LTRIM(RTRIM(product_category_raw)),2,200)))
        END AS product_category,

        LTRIM(RTRIM(product_name_raw)) AS product_name,

        /* Units: remove 'pcs', keep digits only */
        TRY_CONVERT(INT, REPLACE(REPLACE(units_raw,'pcs',''),'pc','')) AS units,

        /* Unit price: strip $, commas, spaces */
        TRY_CONVERT(DECIMAL(10,2),
            REPLACE(REPLACE(REPLACE(REPLACE(unit_price_raw,'$',''),',',''),' ','CHARNULL'),'CHARNULL','')
        ) AS unit_price,

        /* Discount: allow "10%", "0.10", "10", "", "NA" */
        CAST(
            CASE
                WHEN discount_raw IS NULL OR discount_raw = '' OR UPPER(discount_raw) = 'NA' THEN 0.0
                WHEN discount_raw LIKE '%\%%' ESCAPE '\' THEN
                    TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,'%','')) / 100.0
                ELSE
                    CASE
                        WHEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','') ) IS NULL THEN 0.0
                        WHEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','')) > 1
                            THEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','')) / 100.0
                        ELSE TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ',''))
                    END
            END AS DECIMAL(10,6)
        ) AS discount_pct,

        /* Tax rate: allow "8%", "0.08" */
        CAST(
            CASE
                WHEN tax_rate_raw IS NULL OR tax_rate_raw = '' THEN 0.0
                WHEN tax_rate_raw LIKE '%\%%' ESCAPE '\' THEN
                    TRY_CONVERT(DECIMAL(10,6), REPLACE(tax_rate_raw,'%','')) / 100.0
                ELSE
                    COALESCE(TRY_CONVERT(DECIMAL(10,6), REPLACE(tax_rate_raw,' ','')), 0.0)
            END AS DECIMAL(10,6)
        ) AS tax_rate,

        status_norm
    FROM base
),
filtered AS (
    /* Keep valid rows only; drop CANCELLED/RETURNED and bad values */
    SELECT *
    FROM parsed
    WHERE order_id IS NOT NULL
      AND order_date IS NOT NULL
      AND customer_id IS NOT NULL
      AND units IS NOT NULL AND units > 0
      AND unit_price IS NOT NULL AND unit_price > 0
      AND status_norm IN ('COMPLETED','SHIPPED')
),
dedup AS (
    /* Deduplicate by order_id -> keep the most recent order_date */
    SELECT f.*,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_date DESC) AS rn
    FROM filtered f
)
SELECT
    order_id,
    order_date,
    customer_id,
    state,
    product_category,
    product_name,
    units,
    CAST(unit_price AS DECIMAL(10,2)) AS unit_price,
    CAST(discount_pct AS DECIMAL(6,3)) AS discount_pct,
    CAST(tax_rate AS DECIMAL(6,3)) AS tax_rate,
    CAST(ROUND(units * unit_price * (1 - discount_pct) * (1 + tax_rate), 2) AS DECIMAL(12,2)) AS net_revenue
INTO demo.orders_clean
FROM dedup
WHERE rn = 1;

-- Indexes (speed up grouping/filtering later)
CREATE INDEX IX_orders_clean_date ON demo.orders_clean(order_date);
CREATE INDEX IX_orders_clean_state ON demo.orders_clean(state);
CREATE INDEX IX_orders_clean_category ON demo.orders_clean(product_category);

-- Sanity checks
SELECT * FROM demo.orders_clean ORDER BY order_date, order_id;
SELECT COUNT(*) AS rows_after_cleaning FROM demo.orders_clean;

-- 5) Helpful analysis views
IF OBJECT_ID('demo.v_kpi','V') IS NOT NULL DROP VIEW demo.v_kpi;
GO
CREATE VIEW demo.v_kpi AS
SELECT
    COUNT(*)                           AS orders,
    SUM(units)                         AS total_units,
    CAST(SUM(net_revenue) AS DECIMAL(12,2)) AS total_revenue,
    CAST(AVG(net_revenue) AS DECIMAL(12,2)) AS avg_order_value
FROM demo.orders_clean;
GO

IF OBJECT_ID('demo.v_revenue_by_month_category','V') IS NOT NULL DROP VIEW demo.v_revenue_by_month_category;
GO
CREATE VIEW demo.v_revenue_by_month_category AS
SELECT
    CONVERT(date, DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)) AS month_start,
    product_category,
    CAST(SUM(net_revenue) AS DECIMAL(12,2)) AS revenue
FROM demo.orders_clean
GROUP BY CONVERT(date, DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)), product_category;
GO

IF OBJECT_ID('demo.v_top_states','V') IS NOT NULL DROP VIEW demo.v_top_states;
GO
CREATE VIEW demo.v_top_states AS
SELECT state, CAST(SUM(net_revenue) AS DECIMAL(12,2)) AS revenue
FROM demo.orders_clean
GROUP BY state;
GO
-- 6) Example queries to run after the script
-- KPIs
SELECT * FROM demo.v_kpi;

-- Revenue by month & category
SELECT * FROM demo.v_revenue_by_month_category ORDER BY month_start, product_category;

-- Top states by revenue
SELECT * FROM demo.v_top_states ORDER BY revenue DESC;

-- Daily revenue with simple anomaly flags (IQR rule)
;WITH daily AS (
    SELECT order_date, SUM(net_revenue) AS revenue
    FROM demo.orders_clean
    GROUP BY order_date
),
stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY revenue) OVER() AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY revenue) OVER() AS q3
    FROM daily
)
SELECT d.*,
       CASE WHEN d.revenue < (s.q1 - 1.5*(s.q3 - s.q1))
                 OR d.revenue > (s.q3 + 1.5*(s.q3 - s.q1))
            THEN 1 ELSE 0 END AS is_anomaly
FROM daily d
CROSS JOIN (SELECT TOP 1 q1, q3 FROM stats) s
ORDER BY d.order_date;