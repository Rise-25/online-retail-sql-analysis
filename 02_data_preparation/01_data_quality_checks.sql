/*
Project: Online Retail Sales Analysis
Database: online_retail_analysis
Source table: retail_transactions

Purpose:
Assess source-data quality and investigate records that may
affect the interpretation of transaction, product and
customer-level analysis.

Primary decisions:
- Retain source records; do not delete rows from the source table.
- Exclude secondary exact duplicates from primary reporting.
- Retain negative quantities and investigate by context.
- Treat C-prefixed invoice numbers as cancellation-associated
  indicators, not definitive cancellation classifications.
- Retain zero and negative UnitPrice records, with appropriate
  interpretation and metric-specific treatment.
- Retain missing descriptions as NULL; do not impute them.
- Retain missing CustomerIDs, excluding them only from analyses
  that require customer identification.
*/


/* =========================================================
   1. INITIAL DATA PROFILE
   ========================================================= */

-- Check missing values in key source columns.
SELECT
    COUNT(*) AS total_record_count,

    SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END)
        AS missing_description_count,
    ROUND(
        SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS missing_description_pct,

    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END)
        AS missing_customer_id_count,
    ROUND(
        SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS missing_customer_id_pct,

    SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END)
        AS missing_country_count,
    SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END)
        AS missing_invoice_date_count
FROM retail_transactions;


/* =========================================================
   2. EXACT DUPLICATE RECORDS
   ========================================================= */

-- Identify exact duplicate groups using all eight source columns.
-- A duplicate group contains two or more identical source rows.
WITH duplicate_groups AS (
    SELECT
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country,
        COUNT(*) AS records_in_group
    FROM retail_transactions
    GROUP BY
        InvoiceNo,
        StockCode,
        Description,
        Quantity,
        InvoiceDate,
        UnitPrice,
        CustomerID,
        Country
    HAVING COUNT(*) > 1
)
SELECT
    SUM(records_in_group) AS records_in_duplicate_groups,
    COUNT(*) AS duplicate_group_count,
    SUM(records_in_group - 1) AS additional_duplicate_count,
    CASE
        WHEN SUM(records_in_group) =
             COUNT(*) + SUM(records_in_group - 1)
        THEN 'PASS'
        ELSE 'FAIL'
    END AS duplicate_count_reconciliation
FROM duplicate_groups;

-- Review the number of negative-quantity records.
SELECT
    COUNT(*) AS negative_quantity_record_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM retail_transactions), 2)
        AS negative_quantity_pct
FROM retail_transactions
WHERE Quantity < 0;


/* =========================================================
   3. NEGATIVE QUANTITY INVESTIGATION
   ========================================================= */

-- Inspect negative-quantity transactions.
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM retail_transactions
WHERE Quantity < 0
ORDER BY InvoiceDate, InvoiceNo;

-- Compare C-prefixed and non-C-prefixed negative-quantity records.
-- C-prefix is used as a proxy only; it is not definitive evidence
-- that every such record represents a cancellation.
SELECT
    CASE
        WHEN InvoiceNo LIKE 'C%' THEN 'C-prefixed'
        ELSE 'Non-C-prefixed'
    END AS invoice_reference_status,
    COUNT(*) AS negative_quantity_record_count,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(Quantity) AS net_quantity,
    SUM(Quantity * UnitPrice) AS net_transaction_value
FROM retail_transactions
WHERE Quantity < 0
GROUP BY invoice_reference_status
ORDER BY invoice_reference_status;

-- Check whether non-C-prefixed negative-quantity records
-- have distinct invoice references.
SELECT
    InvoiceNo,
    COUNT(*) AS negative_quantity_record_count
FROM retail_transactions
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity < 0
GROUP BY InvoiceNo
ORDER BY negative_quantity_record_count DESC, InvoiceNo;

-- Review descriptions associated with non-C-prefixed
-- negative-quantity transactions.
SELECT
    Description,
    COUNT(*) AS record_count
FROM retail_transactions
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity < 0
GROUP BY Description
ORDER BY record_count DESC;

-- Check whether StockCode is populated for non-C-prefixed
-- negative-quantity records with missing descriptions.
SELECT
    COUNT(*) AS total_record_count,
    COUNT(CASE WHEN StockCode IS NULL THEN 1 END) AS missing_stockcode_count,
    COUNT(CASE WHEN StockCode IS NOT NULL THEN 1 END) AS populated_stockcode_count
FROM retail_transactions
WHERE InvoiceNo NOT LIKE 'C%'
  AND Quantity < 0
  AND Description IS NULL;


/* =========================================================
   4. MISSING DESCRIPTION INVESTIGATION
   ========================================================= */

-- Compare missing descriptions across positive and negative
-- quantity records, and count the distinct StockCodes involved.
SELECT
    'Records with missing descriptions' AS measure,
    COUNT(CASE WHEN Quantity < 0 THEN 1 END) AS negative_quantity_count,
    COUNT(CASE WHEN Quantity > 0 THEN 1 END) AS positive_quantity_count
FROM retail_transactions
WHERE Description IS NULL

UNION ALL

SELECT
    'Distinct StockCodes' AS measure,
    COUNT(DISTINCT CASE WHEN Quantity < 0 THEN StockCode END),
    COUNT(DISTINCT CASE WHEN Quantity > 0 THEN StockCode END)
FROM retail_transactions
WHERE Description IS NULL;

-- Assess whether StockCodes with missing descriptions have
-- one, multiple or no alternative descriptions elsewhere.
WITH missing_description_stockcodes AS (
    SELECT
        StockCode,
        COUNT(*) AS missing_description_record_count
    FROM retail_transactions
    WHERE Description IS NULL
    GROUP BY StockCode
),
available_descriptions AS (
    SELECT
        StockCode,
        COUNT(DISTINCT Description) AS distinct_description_count
    FROM retail_transactions
    WHERE Description IS NOT NULL
      AND StockCode IN (
          SELECT StockCode
          FROM missing_description_stockcodes
      )
    GROUP BY StockCode
)
SELECT
    CASE
        WHEN ad.distinct_description_count = 1 THEN 'Single description'
        WHEN ad.distinct_description_count > 1 THEN 'Multiple descriptions'
        ELSE 'No description available'
    END AS description_availability_status,
    COUNT(*) AS stockcode_count
FROM missing_description_stockcodes AS md
LEFT JOIN available_descriptions AS ad
    ON md.StockCode = ad.StockCode
GROUP BY description_availability_status
ORDER BY description_availability_status;

-- Decision: retain missing Description values as NULL.
-- StockCode is used as the product identifier; descriptions
-- are not imputed because multiple descriptions may exist
-- for the same StockCode.


/* =========================================================
   5. ZERO AND NEGATIVE UNIT PRICE INVESTIGATION
   ========================================================= */

-- Count zero and negative UnitPrice records.
SELECT
    COUNT(CASE WHEN UnitPrice = 0 THEN 1 END) AS zero_price_record_count,
    COUNT(CASE WHEN UnitPrice < 0 THEN 1 END) AS negative_price_record_count
FROM retail_transactions;

-- Inspect all negative UnitPrice records.
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country
FROM retail_transactions
WHERE UnitPrice < 0
ORDER BY InvoiceDate;

-- Review quantity and description status among zero-price records.
SELECT
    COUNT(*) AS zero_price_record_count,
    COUNT(CASE WHEN Description IS NULL THEN 1 END) AS missing_description_count,
    COUNT(CASE WHEN Description IS NOT NULL THEN 1 END) AS populated_description_count,
    COUNT(CASE WHEN Quantity < 0 THEN 1 END) AS negative_quantity_count,
    COUNT(CASE WHEN Quantity > 0 THEN 1 END) AS positive_quantity_count,
    COUNT(DISTINCT StockCode) AS distinct_stockcode_count,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count
FROM retail_transactions
WHERE UnitPrice = 0;

-- Review zero-price records by description.
SELECT
    Description,
    COUNT(CASE WHEN Quantity < 0 THEN 1 END) AS negative_quantity_count,
    COUNT(CASE WHEN Quantity > 0 THEN 1 END) AS positive_quantity_count,
    COUNT(*) AS total_record_count
FROM retail_transactions
WHERE UnitPrice = 0
GROUP BY Description
ORDER BY total_record_count DESC;

-- Review zero-price records by StockCode.
SELECT
    StockCode,
    COUNT(CASE WHEN Quantity < 0 THEN 1 END) AS negative_quantity_count,
    COUNT(CASE WHEN Quantity > 0 THEN 1 END) AS positive_quantity_count,
    COUNT(*) AS total_record_count
FROM retail_transactions
WHERE UnitPrice = 0
GROUP BY StockCode
ORDER BY total_record_count DESC;

-- Examine how many zero-price records appear on each invoice.
WITH zero_price_invoice_counts AS (
    SELECT
        InvoiceNo,
        COUNT(*) AS zero_price_record_count
    FROM retail_transactions
    WHERE UnitPrice = 0
    GROUP BY InvoiceNo
)
SELECT
    zero_price_record_count,
    COUNT(*) AS invoice_count
FROM zero_price_invoice_counts
GROUP BY zero_price_record_count
ORDER BY zero_price_record_count;

-- Inspect invoices containing multiple zero-price records.
SELECT
    InvoiceNo,
    COUNT(CASE WHEN Quantity < 0 THEN 1 END) AS negative_quantity_count,
    COUNT(CASE WHEN Quantity > 0 THEN 1 END) AS positive_quantity_count,
    COUNT(*) AS zero_price_record_count
FROM retail_transactions
WHERE UnitPrice = 0
GROUP BY InvoiceNo
HAVING COUNT(*) > 1
ORDER BY zero_price_record_count DESC, InvoiceNo;

-- Exploratory investigation: inspect invoices containing both
-- zero-price records and Manual (StockCode M) entries.
SELECT
    InvoiceNo,
    COUNT(CASE WHEN UnitPrice = 0 THEN 1 END) AS zero_price_record_count,
    COUNT(CASE WHEN StockCode = 'M' THEN 1 END) AS manual_record_count
FROM retail_transactions
GROUP BY InvoiceNo
HAVING zero_price_record_count > 0
   AND manual_record_count > 0
ORDER BY InvoiceNo;

-- Decision: retain zero-price and negative-price records in the
-- prepared dataset. Interpret them according to the metric and
-- business question; negative-price adjustments are not treated
-- as ordinary product sales.


/* =========================================================
   6. MISSING CUSTOMERID INVESTIGATION
   ========================================================= */

-- Quantify missing CustomerIDs at record and invoice level.
SELECT
    COUNT(*) AS total_record_count,
    COUNT(CustomerID) AS populated_customer_id_count,
    COUNT(*) - COUNT(CustomerID) AS missing_customer_id_count,
    ROUND(
        (COUNT(*) - COUNT(CustomerID)) * 100.0 / COUNT(*), 2
    ) AS missing_customer_id_pct,
    COUNT(DISTINCT CASE WHEN CustomerID IS NULL THEN InvoiceNo END)
        AS invoices_with_missing_customer_id,
    COUNT(DISTINCT InvoiceNo) AS total_distinct_invoice_count,
    ROUND(
        COUNT(DISTINCT CASE WHEN CustomerID IS NULL THEN InvoiceNo END)
        * 100.0 / COUNT(DISTINCT InvoiceNo), 2
    ) AS invoices_with_missing_customer_id_pct
FROM retail_transactions;

-- Classify each invoice according to CustomerID completeness.
WITH invoice_customer_id_status AS (
    SELECT
        InvoiceNo,
        COUNT(*) AS total_record_count,
        COUNT(CustomerID) AS populated_customer_id_count,
        CASE
            WHEN COUNT(CustomerID) = COUNT(*) THEN 'Complete'
            WHEN COUNT(CustomerID) = 0 THEN 'Fully Missing'
            ELSE 'Partially Missing'
        END AS invoice_customer_id_status
    FROM retail_transactions
    GROUP BY InvoiceNo
)
SELECT
    invoice_customer_id_status,
    COUNT(*) AS invoice_count,
    SUM(total_record_count) AS transaction_record_count
FROM invoice_customer_id_status
GROUP BY invoice_customer_id_status
ORDER BY invoice_customer_id_status;

-- Reconcile net transaction value by invoice CustomerID status.
-- This is net transaction value, not necessarily recognised revenue.
WITH invoice_customer_id_status AS (
    SELECT
        InvoiceNo,
        CASE
            WHEN COUNT(CustomerID) = COUNT(*) THEN 'Complete'
            WHEN COUNT(CustomerID) = 0 THEN 'Fully Missing'
            ELSE 'Partially Missing'
        END AS invoice_customer_id_status
    FROM retail_transactions
    GROUP BY InvoiceNo
),
status_values AS (
    SELECT
        s.invoice_customer_id_status,
        SUM(r.Quantity * r.UnitPrice) AS net_transaction_value
    FROM retail_transactions AS r
    JOIN invoice_customer_id_status AS s
        ON r.InvoiceNo = s.InvoiceNo
    GROUP BY s.invoice_customer_id_status
)
SELECT
    invoice_customer_id_status,
    net_transaction_value,
    ROUND(
        net_transaction_value * 100.0 /
        SUM(net_transaction_value) OVER (), 2
    ) AS net_transaction_value_pct
FROM status_values
ORDER BY invoice_customer_id_status;

-- Compare missing descriptions across invoice CustomerID status.
WITH invoice_customer_id_status AS (
    SELECT
        InvoiceNo,
        CASE
            WHEN COUNT(CustomerID) = COUNT(*) THEN 'Complete'
            WHEN COUNT(CustomerID) = 0 THEN 'Fully Missing'
            ELSE 'Partially Missing'
        END AS invoice_customer_id_status
    FROM retail_transactions
    GROUP BY InvoiceNo
)
SELECT
    s.invoice_customer_id_status,
    COUNT(*) AS transaction_record_count,
    COUNT(CASE WHEN r.Description IS NULL THEN 1 END)
        AS missing_description_record_count,
    ROUND(
        COUNT(CASE WHEN r.Description IS NULL THEN 1 END)
        * 100.0 / COUNT(*), 2
    ) AS missing_description_pct
FROM retail_transactions AS r
JOIN invoice_customer_id_status AS s
    ON r.InvoiceNo = s.InvoiceNo
GROUP BY s.invoice_customer_id_status
ORDER BY s.invoice_customer_id_status;

-- Decision: retain records with missing CustomerIDs.
-- Exclude them only from analyses that require customer-level
-- attribution, and disclose the resulting coverage limitation.
