/* ===========================================================
   Retail demo project (SQL Server / T‑SQL)
   Part 2: Clean & standardize into a typed table with net_revenue
   =========================================================== */

USE RetailDemo;
GO

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
        -- IDs
        TRY_CONVERT(INT, order_id_raw) AS order_id,

        -- Dates: try multiple formats; final catch uses TRY_PARSE for "Jan 08 2025"
        COALESCE(
            TRY_CONVERT(DATE, order_date_raw, 23),   -- YYYY-MM-DD
            TRY_CONVERT(DATE, order_date_raw, 101),  -- MM/DD/YYYY
            TRY_CONVERT(DATE, order_date_raw, 111),  -- YYYY/MM/DD
            TRY_PARSE(order_date_raw AS DATE USING 'en-US')
        ) AS order_date,

        TRY_CONVERT(INT, customer_id_raw) AS customer_id,

        -- Normalize state names
        CASE
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('CALIFORNIA','CA') THEN 'CA'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('TEXAS','TX') THEN 'TX'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('WASHINGTON','WA') THEN 'WA'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('FLORIDA','FL') THEN 'FL'
            WHEN UPPER(LTRIM(RTRIM(state_raw))) IN ('NEW YORK','NY') THEN 'NY'
            ELSE UPPER(LTRIM(RTRIM(state_raw)))
        END AS state,

        -- Normalize categories
        CASE
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'elect%' THEN 'Electronics'
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'home%'  THEN 'Home & Kitchen'
            WHEN LOWER(LTRIM(RTRIM(product_category_raw))) LIKE 'sport%' THEN 'Sports'
            ELSE CONCAT(UPPER(LEFT(LTRIM(RTRIM(product_category_raw)),1)),
                        LOWER(SUBSTRING(LTRIM(RTRIM(product_category_raw)),2,200)))
        END AS product_category,

        LTRIM(RTRIM(product_name_raw)) AS product_name,

        -- Units: keep digits only from patterns like "3 pcs"
        TRY_CONVERT(INT, REPLACE(REPLACE(units_raw,'pcs',''),'pc','')) AS units,

        -- Price: remove $, commas, spaces, then convert
        TRY_CONVERT(DECIMAL(10,2),
            REPLACE(REPLACE(REPLACE(unit_price_raw,'$',''),',',''),' ','')
        ) AS unit_price,

        -- Discount: handle "10%", "0.10", "10", "", "NA"
        CAST(
            CASE
                WHEN discount_raw IS NULL OR discount_raw = '' OR UPPER(discount_raw) = 'NA' THEN 0.0
                WHEN CHARINDEX('%', discount_raw) > 0 THEN
                    TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,'%','')) / 100.0
                ELSE
                    CASE
                        WHEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','')) IS NULL THEN 0.0
                        WHEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','')) > 1
                            THEN TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ','')) / 100.0
                        ELSE TRY_CONVERT(DECIMAL(10,6), REPLACE(discount_raw,' ',''))
                    END
            END AS DECIMAL(10,6)
        ) AS discount_pct,

        -- Tax rate: handle "8%", "0.08"
        CAST(
            CASE
                WHEN tax_rate_raw IS NULL OR tax_rate_raw = '' THEN 0.0
                WHEN CHARINDEX('%', tax_rate_raw) > 0 THEN
                    TRY_CONVERT(DECIMAL(10,6), REPLACE(tax_rate_raw,'%','')) / 100.0
                ELSE
                    COALESCE(TRY_CONVERT(DECIMAL(10,6), REPLACE(tax_rate_raw,' ','')), 0.0)
            END AS DECIMAL(10,6)
        ) AS tax_rate,

        status_norm
    FROM base
),
filtered AS (
    -- Keep good rows only; drop CANCELLED/RETURNED, bad types
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
    -- Deduplicate by order_id; keep the most recent order_date
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

-- Helpful indexes
CREATE INDEX IX_orders_clean_date     ON demo.orders_clean(order_date);
CREATE INDEX IX_orders_clean_state    ON demo.orders_clean(state);
CREATE INDEX IX_orders_clean_category ON demo.orders_clean(product_category);

-- Quick checks
SELECT COUNT(*) AS rows_after_cleaning FROM demo.orders_clean;
SELECT TOP 10 * FROM demo.orders_clean ORDER BY order_date, order_id;
