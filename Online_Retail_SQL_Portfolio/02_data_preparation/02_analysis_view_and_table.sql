/*
Project: Online Retail Sales Analysis
Database: online_retail_analysis

Purpose:
Create the final analysis view and materialise its results
in a physical analysis table.

The original retail_transactions source table remains unchanged.
*/


/* =========================================================
   1. FINAL ANALYSIS VIEW
   ========================================================= */

CREATE OR REPLACE VIEW vw_retail_transactions_analysis AS

WITH duplicate_check AS (
    SELECT
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country,

        COUNT(*) OVER (
            PARTITION BY
                InvoiceNo,
                StockCode,
                Description,
                Quantity,
                InvoiceDate,
                UnitPrice,
                CustomerID,
                Country
        ) AS duplicate_count,

        ROW_NUMBER() OVER (
            PARTITION BY
                InvoiceNo,
                StockCode,
                Description,
                Quantity,
                InvoiceDate,
                UnitPrice,
                CustomerID,
                Country
            ORDER BY InvoiceNo
        ) AS duplicate_row_number

    FROM retail_transactions
)

SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,

    (Quantity * UnitPrice) AS line_value,

    CASE
        WHEN CustomerID IS NULL THEN 'Missing CustomerID'
        ELSE 'Populated CustomerID'
    END AS customer_id_status,

    CASE
        WHEN Description IS NULL THEN 'Missing Description'
        ELSE 'Populated Description'
    END AS description_status,

    CASE
        WHEN Quantity > 0 THEN 'PosQty'
        WHEN Quantity < 0 THEN 'NegQty'
        ELSE 'ZeroQty'
    END AS quantity_status,

    CASE
        WHEN UnitPrice > 0 THEN 'PosPrice'
        WHEN UnitPrice < 0 THEN 'NegPrice'
        ELSE 'ZeroPrice'
    END AS unit_price_status,

    CASE
        WHEN InvoiceNo LIKE 'C%' THEN 'C-prefixed'
        ELSE 'Non-C-prefixed'
    END AS invoice_reference_status,

    CASE
        WHEN duplicate_count = 1 THEN 'Unique'
        WHEN duplicate_row_number = 1 THEN 'Primary Duplicate'
        ELSE 'Secondary Duplicate'
    END AS duplicate_record_status

FROM duplicate_check;


/* =========================================================
   2. CREATE THE PHYSICAL ANALYSIS TABLE

   This stores the calculated columns and duplicate statuses
   from the view, avoiding repeated calculation when the
   analysis table is queried.

   Run this CREATE TABLE statement once after creating or
   refreshing the view. If the table already exists, do not
   rerun it without first considering whether it needs to be
   refreshed.
   ========================================================= */

CREATE TABLE retail_transactions_analysis AS
SELECT *
FROM vw_retail_transactions_analysis;


/* =========================================================
   3. VALIDATE THE ANALYSIS TABLE
   ========================================================= */

-- Confirm the physical table record count.
SELECT
    COUNT(*) AS total_record_count
FROM retail_transactions_analysis;

-- Check the duplicate classifications.
SELECT
    duplicate_record_status,
    COUNT(*) AS record_count
FROM retail_transactions_analysis
GROUP BY duplicate_record_status
ORDER BY duplicate_record_status;

-- Reconcile the duplicate classifications to the source count.
SELECT
    COUNT(*) AS total_record_count,
    COUNT(CASE
        WHEN duplicate_record_status IN ('Unique', 'Primary Duplicate')
        THEN 1
    END) AS retained_record_count,
    COUNT(CASE
        WHEN duplicate_record_status = 'Secondary Duplicate'
        THEN 1
    END) AS excluded_secondary_duplicate_count
FROM retail_transactions_analysis;

-- Compare the view and physical table record counts.
SELECT
    (SELECT COUNT(*) FROM vw_retail_transactions_analysis)
        AS view_record_count,
    (SELECT COUNT(*) FROM retail_transactions_analysis)
        AS analysis_table_record_count;
