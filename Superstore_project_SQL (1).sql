/*
PROJECT: Superstore Data Cleaning and Sales Analysis (PostgreSQL)

OBJECTIVE:
Clean, standardise, and analyse retail sales data to uncover
business insights relating to revenue performance, customer behaviour,
regional trends, shipping efficiency, and sales growth.

SKILLS DEMONSTRATED:
- SQL data cleaning
- Data standardisation
- NULL handling
- Date formatting
- Aggregate analysis
- Window functions
- KPI analysis
- Business insight generation

TOOLS USED:
- PostgreSQL
- pgAdmin 4
*/

--Import data from .csv file
DROP TABLE IF EXISTS superstore_raw;
CREATE TABLE superstore_raw(
	"Row ID" TEXT,
	"Order ID" TEXT,
	"Order Date" TEXT,
	"Ship Date" TEXT,
	"Ship Mode" TEXT,	
	"Customer ID" TEXT,
	"Customer Name" TEXT,
	"Segment" TEXT,
	"Country" TEXT,
	"City" TEXT,
	"State" TEXT,	
	"Postal Code" TEXT,
	"Region" TEXT,
	"Product ID" TEXT,
	"Category" TEXT,
	"Sub-Category" TEXT,	
	"Product Name" TEXT,	
	"Sales" TEXT
);
-- Confirming table created with correctly formatted column headers
SELECT *
FROM superstore_raw;

-- Data imported from csv file
-- Initial view of sample data
SELECT *
FROM superstore_raw
LIMIT 50;

-- Count of total rows in the dataset - 9835
SELECT COUNT(*) AS total_rows_count
FROM superstore_raw;

-- Check for NULL values in key columns
SELECT
	COUNT(*) FILTER (WHERE "Order ID" IS NULL) AS missing_order_id, -- 0
	COUNT(*) FILTER (WHERE "Customer Name" IS NULL) AS missing_customer_name,-- 130
	COUNT(*) FILTER (WHERE "Sales" IS NULL) AS missing_sales -- 188
FROM superstore_raw;

-- Check for duplicate rows
SELECT *, 
	COUNT(*) AS duplicate_count
FROM superstore_raw
GROUP BY 
	"Row ID",
	"Order ID",
	"Order Date",
	"Ship Date",
	"Ship Mode",	
	"Customer ID",
	"Customer Name",
	"Segment",
	"Country",
	"City",
	"State",	
	"Postal Code",
	"Region",
	"Product ID",
	"Category",
	"Sub-Category",	
	"Product Name",	
	"Sales"
HAVING COUNT(*) > 1;
-- 35 rows have a duplicate count of 2

-- Inspect key columns for inconsistencies 
SELECT DISTINCT	"Category"
FROM superstore_raw
ORDER BY "Category";
--Null value and inconsistent capitalisation 

SELECT DISTINCT "Region"
FROM superstore_raw
ORDER BY "Region";
--Null, N/A value and inconsistent capitalisation 

SELECT DISTINCT "Ship Mode"
FROM superstore_raw
ORDER BY "Ship Mode";
--Null value and inconsistent capitalisation 

SELECT DISTINCT "Sales"
FROM superstore_raw
WHERE "Sales" ~ '[^0-9.]';
--Sales values contain currency symbols and negative values.
--Negative sales may represent returns or refunds rather than data errors.

SELECT DISTINCT "Product Name"
FROM superstore_raw
WHERE "Product Name" != TRIM("Product Name");
--No leading or trailing whitespace issues identified

SELECT DISTINCT "Product Name"
FROM superstore_raw
WHERE "Product Name" ~'[^a-zA-Z0-9 ,.-]';
--Many product names contain special characters as part of their name, so not inherently a data issue, just needs to be factored in carefully

SELECT DISTINCT "Ship Date"
FROM superstore_raw
ORDER BY "Ship Date";
--Null values and varying date formats 

SELECT DISTINCT "Order Date"
FROM superstore_raw
WHERE
    "Order Date" IS NULL
    OR TRIM("Order Date") = ''
    OR (
        "Order Date" !~ '^\d{2}/\d{2}/\d{4}$'
        AND "Order Date" !~ '^\d{4}-\d{2}-\d{2}$'
    );
--Null and 'not recorded' value(s)

--Check for blank strings in key columns
SELECT 
	COUNT(*) FILTER(WHERE TRIM("Customer Name") = '') AS blank_customer_name,
	COUNT(*) FILTER(WHERE TRIM("Sales") = '') AS blank_sales,
	COUNT(*) FILTER(WHERE TRIM("Order Date") = '') AS blank_order_date,
	COUNT(*) FILTER(WHERE TRIM("Segment") = '') AS blank_segment,
	COUNT(*) FILTER(WHERE TRIM("Sub-Category") = '') AS blank_subcategory
FROM superstore_raw;

--Inspect unusual postal code values
SELECT DISTINCT "Postal Code"
FROM superstore_raw
WHERE "Postal Code" IS NULL
	OR TRIM("Postal Code") = ''
	OR "Postal Code" ~ '[^0-9]';
-- null and 'UNKNOWN'values present

--Inspecting segment variations
SELECT DISTINCT "Segment"
FROM superstore_raw
ORDER BY "Segment";
-- Null value(s) present and inconsistency in letter casing 

--Inspecting sub-category variations
SELECT DISTINCT "Sub-Category"
FROM superstore_raw
ORDER BY "Sub-Category";
-- Null value(s) present and inconsistency with capitalisation 



-- Create cleaned and standardised version of the dataset

DROP TABLE IF EXISTS superstore_cleaned;
CREATE TABLE superstore_cleaned AS
SELECT
    -- Remove unnecessary Row ID column
    "Order ID" AS order_id,

    -- Clean and standardise order dates
  CASE
    WHEN "Order Date" IS NULL
         OR TRIM("Order Date") = ''
    THEN NULL

    -- DD/MM/YYYY format

    WHEN "Order Date" ~ '^\d{2}/\d{2}/\d{4}$'
         AND SPLIT_PART("Order Date", '/', 1)::INT > 12
    THEN TO_DATE("Order Date", 'DD/MM/YYYY')

    -- MM/DD/YYYY format

    WHEN "Order Date" ~ '^\d{2}/\d{2}/\d{4}$'
         AND SPLIT_PART("Order Date", '/', 2)::INT > 12
    THEN TO_DATE("Order Date", 'MM/DD/YYYY')

    -- YYYY-MM-DD format

    WHEN "Order Date" ~ '^\d{4}-\d{2}-\d{2}$'
    THEN TO_DATE("Order Date", 'YYYY-MM-DD')

    ELSE NULL
END AS order_date,

    -- Clean and standardise ship dates
    CASE
    WHEN "Ship Date" IS NULL
         OR TRIM("Ship Date") = ''
    THEN NULL

    -- DD-Mon-YY format

    WHEN "Ship Date" ~ '^\d{2}-[A-Za-z]{3}-\d{2}$'
    THEN TO_DATE("Ship Date", 'DD-Mon-YY')

    -- DD/MM/YYYY format

    WHEN "Ship Date" ~ '^\d{2}/\d{2}/\d{4}$'
         AND SPLIT_PART("Ship Date", '/', 1)::INT > 12
    THEN TO_DATE("Ship Date", 'DD/MM/YYYY')

    -- MM/DD/YYYY format

    WHEN "Ship Date" ~ '^\d{2}/\d{2}/\d{4}$'
         AND SPLIT_PART("Ship Date", '/', 2)::INT > 12
    THEN TO_DATE("Ship Date", 'MM/DD/YYYY')

    -- YYYY-MM-DD format

    WHEN "Ship Date" ~ '^\d{4}-\d{2}-\d{2}$'
    THEN TO_DATE("Ship Date", 'YYYY-MM-DD')

    ELSE NULL
END AS ship_date,
    -- Standardise ship mode formatting
   
CASE
    WHEN "Ship Mode" IS NULL
         OR TRIM("Ship Mode") = ''
    THEN NULL

    WHEN LOWER(TRIM("Ship Mode")) IN ('same day', 'same-day')
    THEN 'Same Day'

    ELSE INITCAP(TRIM("Ship Mode"))
END AS ship_mode,

    -- Rename customer ID column
    "Customer ID" AS customer_id,

    -- Convert blank customer names to NULL
    NULLIF(TRIM("Customer Name"), '') AS customer_name,

    -- Standardise segment formatting

    CASE
        WHEN "Segment" IS NULL
             OR TRIM("Segment") = ''
        THEN NULL

        ELSE INITCAP(TRIM("Segment"))
    END AS segment,

    -- Remove unnecessary spaces from location columns

    TRIM("Country") AS country,
    TRIM("City") AS city,
    TRIM("State") AS state,

    -- Clean postal code values

    CASE
        WHEN "Postal Code" IS NULL
             OR TRIM("Postal Code") = ''
             OR UPPER(TRIM("Postal Code")) = 'UNKNOWN'
        THEN NULL

        ELSE TRIM("Postal Code")
    END AS postal_code,

    -- Standardise region formatting

    CASE
        WHEN "Region" IS NULL
             OR TRIM("Region") = ''
             OR UPPER(TRIM("Region")) = 'N/A'
        THEN NULL

        ELSE INITCAP(TRIM("Region"))
    END AS region,

    -- Rename product ID column

    "Product ID" AS product_id,

    -- Standardise category formatting

    CASE
        WHEN "Category" IS NULL
             OR TRIM("Category") = ''
        THEN NULL

        ELSE INITCAP(TRIM("Category"))
    END AS category,

    -- Standardise sub-category formatting

    CASE
        WHEN "Sub-Category" IS NULL
             OR TRIM("Sub-Category") = ''
        THEN NULL

        ELSE INITCAP(TRIM("Sub-Category"))
    END AS sub_category,

    -- Remove unnecessary spaces from product names

    TRIM("Product Name") AS product_name,

    -- Clean sales values and convert to numeric datatype

    CASE
    WHEN "Sales" IS NULL
         OR TRIM("Sales") = ''
    THEN NULL

    WHEN REGEXP_REPLACE("Sales", '[^0-9.-]', '', 'g') = ''
    THEN NULL

    ELSE CAST(
        REGEXP_REPLACE("Sales", '[^0-9.-]', '', 'g')
        AS NUMERIC
    )
END AS sales

FROM superstore_raw;

--Initial review of superstore_cleaned table
SELECT *
FROM superstore_cleaned
LIMIT 100;

-- Data quality validation:
--Check remaining NULLs:
SELECT
	COUNT(*) FILTER (WHERE order_date IS NULL) AS missing_order_date,
	COUNT(*) FILTER (WHERE ship_date IS NULL) AS missing_ship_date,
	COUNT(*) FILTER (WHERE segment IS NULL) AS missing_segment,
	COUNT(*) FILTER (WHERE category IS NULL) AS missing_category,
	COUNT(*) FILTER (WHERE sub_category IS NULL) AS missing_subcategory,
	COUNT(*) FILTER (WHERE region IS NULL) AS missing_region,
	COUNT(*) FILTER (WHERE sales IS NULL) AS missing_sales
FROM superstore_cleaned;
-- Remaining missing values after cleaning:
-- order_date: 322
-- ship_date: 319
-- segment: 166
-- category: 118
-- sub_category: 162
-- region: 189
-- sales: 315
-- Missing values were intentionally retained where the correct value could not be reliably inferred from existing data.
-- This preserves data integrity and avoids introducing assumptions.

--  DATA CLEANING SUMMARY
--Standardised text casing
--Identified duplicate rows for further review
--Converted blank strings to NULL
--Standardised date formats to YYYY-MM-DD
--Removed currency symbols from sales values
--Converted sales column to NUMERIC datatype
--Renamed columns using snake_case convention
--Retained unresolved NULL values to preserve data accuracy


-- BUSINESS ANALYSIS QUERIES
-- Superstore Sales Dataset

-- 1. TOTAL SALES BY CATEGORY

-- Business Question:
-- Which product categories generate the highest revenue?

-- Insight:
-- Helps identify the most profitable areas of the business.

SELECT
    category,
    ROUND(SUM(sales), 2) AS total_sales
FROM superstore_cleaned

WHERE sales IS NOT NULL
    AND category IS NOT NULL

GROUP BY category
ORDER BY total_sales DESC;

-- Results:
-- Technology:       $781,555.39
-- Furniture:        $693,991.07
-- Office Supplies:  $664,333.46
-- Analysis:
-- Technology generated the highest total sales revenue,indicating strong customer demand for technology-related products across the business.
-- Furniture was the second highest-performing category, suggesting that larger-ticket items contribute significantly to overall revenue despite potentially lower sales volume.
-- Office Supplies generated the lowest revenue of the three categories, although performance remained relatively close compared to Furniture.
-- Business Insight:
-- The business may benefit from increasing investment in high-performing Technology products through promotions, inventory expansion, or targeted marketing campaigns.


-- 2. TOP 10 HIGHEST REVENUE PRODUCTS

-- Business Question:
-- Which individual products generate the most sales revenue?

-- Insight:
-- Helps identify high-performing products that may deserve
-- increased marketing, inventory, or promotional focus.

SELECT
    product_name,
    ROUND(SUM(sales), 2) AS total_sales
FROM superstore_cleaned

WHERE sales IS NOT NULL
    AND product_name IS NOT NULL

GROUP BY product_name
ORDER BY total_sales DESC
LIMIT 10;

-- Key Results:
-- Canon imageCLASS 2200 Advanced Copier: $61,599.82
-- Cisco TelePresence System EX90:       $22,638.48
-- HON 5400 Series Task Chairs:          $21,870.58
-- Analysis:
-- The Canon imageCLASS 2200 Advanced Copier generated substantially more revenue than any other individual product in the dataset.
-- Several of the highest-performing products are technology and office equipment items, including conferencing systems, printers, and binding machines.
-- This suggests that high-value business and office products are major revenue drivers for the company.
-- Business Insight:
-- Premium office technology products appear to contribute disproportionately to revenue and may represent important strategic products for future growth.


-- 3. SALES PERFORMANCE BY REGION
-- Business Question:
-- Which regions contribute the largest share of total sales?

-- Insight:
-- Useful for regional performance comparisons and
-- identifying areas with strongest business activity.

SELECT
    region,

    ROUND(SUM(sales), 2) AS total_sales,

    ROUND(
        SUM(sales) * 100.0 /
        (SELECT SUM(sales)
         FROM superstore_cleaned
         WHERE sales IS NOT NULL),
        2
    ) AS percentage_of_total_sales

FROM superstore_cleaned

WHERE sales IS NOT NULL
    AND region IS NOT NULL

GROUP BY region
ORDER BY total_sales DESC;

-- Results:
-- West:    $664,158.22 (30.71%)
-- East:    $634,452.33 (29.33%)
-- Central: $455,825.31 (21.07%)
-- South:   $370,624.22 (17.13%)

-- Analysis:
-- The West region generated the highest overall sales, contributing over 30% of total company revenue.
-- The East region performed similarly strongly, contributing approximately 29% of total sales.
-- Combined, the West and East regions accounted for nearly 60% of all revenue, indicating that business performance is heavily concentrated in these areas.
-- The South region generated the lowest revenue overall.
-- Business Insight:
-- The company may benefit from investigating opportunities to improve sales performance in lower-performing regions, particularly the South and Central regions.

-- 4. MONTHLY SALES TREND ANALYSIS
-- Business Question:
-- How do sales change over time?

-- Insight:
-- Helps identify trends, seasonality, peak sales periods,
-- and potential forecasting opportunities.

SELECT
    DATE_TRUNC('month', order_date) AS sales_month,

    ROUND(SUM(sales), 2) AS monthly_sales

FROM superstore_cleaned

WHERE order_date IS NOT NULL
    AND sales IS NOT NULL

GROUP BY sales_month
ORDER BY sales_month;

-- Analysis:
-- Sales generally increased over time between 2015 and 2018, suggesting positive overall business growth.
-- Revenue consistently peaked during the final quarter of each year, particularly in November and December.
-- The highest monthly sales value occurred in November 2018, exceeding $101,000 in total revenue.
-- Lower sales volumes were commonly observed during the beginning of each year, especially in January and February.
-- This pattern indicates strong seasonality within the business, with demand increasing significantly toward the end of the calendar year.
-- Business Insight:
-- The business should ensure sufficient inventory, staffing, and marketing activity during peak Q4 periods to maximise revenue opportunities.


-- 5. AVERAGE SHIPPING DELAY BY SHIP MODE

-- Business Question:
-- Which shipping methods deliver orders the fastest?

-- Insight:
-- Helps evaluate operational efficiency and shipping
-- performance across delivery methods.

SELECT
    ship_mode,

    ROUND(
        AVG(ship_date - order_date),
        2
    ) AS avg_shipping_days

FROM superstore_cleaned

WHERE order_date IS NOT NULL
    AND ship_date IS NOT NULL
    AND ship_mode IS NOT NULL

GROUP BY ship_mode
ORDER BY avg_shipping_days;

-- Results:
-- Same Day:        0.41 days
-- First Class:     2.14 days
-- Second Class:    3.23 days
-- Standard Class:  4.96 days

-- Analysis:
-- Same Day shipping delivered orders almost immediately, as expected.
-- Standard Class had the longest average delivery time at nearly 5 days.
-- Shipping delay analysis provides an additional operational view of fulfilment performance across ship modes.
-- Business Insight:
-- Same Day shipping performs as expected, while Standard Class has the longest average delivery time. This can help support operational planning and customer delivery expectations.

-- BONUS ANALYSIS:
-- TOP CUSTOMERS BY TOTAL SPENDING

-- Business Question:
-- Which customers generate the most revenue?

-- Insight:
-- Helps identify high-value customers and supports
-- customer segmentation analysis.

SELECT
    customer_name,
    segment,

    ROUND(SUM(sales), 2) AS total_customer_spending

FROM superstore_cleaned

WHERE customer_name IS NOT NULL
    AND sales IS NOT NULL

GROUP BY customer_name, segment
ORDER BY total_customer_spending DESC
LIMIT 15;


-- Key Results:
-- Sean Miller:   $24,869.69
-- Tamara Chand: $19,052.22
-- Raymond Buch: $15,074.55

-- Analysis:
-- A relatively small number of customers generated very high total spending compared to the wider customer base.
-- Both Consumer and Corporate customer segments appeared among the top-spending customers, although Consumer customers were more heavily represented overall.
-- Sean Miller generated the highest total revenue, contributing almost $25,000 in sales alone.
-- Business Insight:
-- High-value customers may represent important opportunities for loyalty programmes, personalised marketing, or account management strategies aimed at customer retention.

-- ADDITIONAL KPI & STRATEGIC ANALYSIS


-- 6. AVERAGE ORDER VALUE (AOV)

-- Business Question:
-- What is the average revenue generated per order?

-- Insight:
-- Helps measure typical customer spending behaviour and overall order value performance.

SELECT
    ROUND(
        SUM(sales) / COUNT(DISTINCT order_id),
        2
    ) AS average_order_value

FROM superstore_cleaned

WHERE sales IS NOT NULL;


-- Analysis:
-- The Average Order Value (AOV) measures the typical revenue generated from each customer order.
-- Higher AOV values may indicate successful upselling, bundle purchases, or higher-value product sales.
-- Monitoring AOV can help evaluate customer purchasing behaviour over time.

-- Business Insight:
-- The company could potentially increase revenue further through cross-selling strategies, premium product recommendations, and bundled product promotions.



-- 7. YEARLY SALES GROWTH %

-- Business Question:
-- How has total sales revenue changed year-over-year?

-- Insight:
-- Useful for evaluating long-term business growth and overall sales performance trends.

WITH yearly_sales AS (

    SELECT
        EXTRACT(YEAR FROM order_date) AS sales_year,

        ROUND(SUM(sales), 2) AS total_sales

    FROM superstore_cleaned

    WHERE order_date IS NOT NULL
        AND sales IS NOT NULL

    GROUP BY sales_year
)

SELECT
    sales_year,

    total_sales,

    ROUND(
        (
            total_sales
            - LAG(total_sales) OVER (ORDER BY sales_year)
        )
        /
        LAG(total_sales) OVER (ORDER BY sales_year)
        * 100,
        2
    ) AS yearly_growth_percentage

FROM yearly_sales
ORDER BY sales_year;


-- Analysis:
-- Sales revenue increased consistently across the observed years,indicating positive overall business growth.
-- Year-over-year growth analysis helps identify whether sales performance is improving, stabilising, or slowing over time.

-- Business Insight:
-- Sustained sales growth may support future investment decisions related to inventory expansion, staffing, operations, and marketing initiatives.



-- 8. TOP-PERFORMING STATES BY SALES

-- Business Question:
-- Which states generate the highest total sales revenue?

-- Insight:
-- Helps identify key geographic markets and regional business performance concentrations.

SELECT
    state,

    ROUND(SUM(sales), 2) AS total_sales

FROM superstore_cleaned

WHERE state IS NOT NULL
    AND sales IS NOT NULL

GROUP BY state
ORDER BY total_sales DESC
LIMIT 10;


-- Analysis:
-- A relatively small number of states contribute a significant share of total company revenue.
-- High-performing states likely represent major customer markets with stronger purchasing activity.

-- Business Insight:
-- The business may benefit from maintaining strong operational support and marketing investment within top-performing states while identifying opportunities for growth in lower-performing regions.



-- 9. CATEGORY SALES TREND OVER TIME

-- Business Question:
-- How has category performance changed over time?

-- Insight:
-- Helps identify long-term category growth patterns,seasonal trends, and changing customer demand.

SELECT
    DATE_TRUNC('year', order_date) AS sales_year,

    category,

    ROUND(SUM(sales), 2) AS total_sales

FROM superstore_cleaned

WHERE order_date IS NOT NULL
    AND sales IS NOT NULL
    AND category IS NOT NULL

GROUP BY sales_year, category
ORDER BY sales_year, total_sales DESC;


-- Analysis:
-- Sales performance varied across categories over time, with some categories demonstrating stronger long-term growth trends than others.
-- Technology consistently remained one of the highest-performing categories throughout the observed period.

-- Business Insight:
-- Tracking category trends over time can support strategic decisions related to inventory planning, product investment, and forecasting future customer demand.