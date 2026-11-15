/*
BUSINESS QUESTION 4: CANCELLATION-ASSOCIATED TRANSACTION ANALYSIS

What is the scale and financial impact of cancellation-associated
transactions, and how do they affect the retailer's overall
transaction performance?

Population:
- Scenario C: unique and primary duplicate records.
- C-prefixed invoice references.

Important limitation:
C-prefixed invoice references are treated as a proxy for
cancellation-associated activity, not definitive cancellation
classification.
*/


/* =========================================================
   1. SCALE AND FREQUENCY
   ========================================================= */

SELECT
    COUNT(*) AS c_prefixed_record_count,
    COUNT(DISTINCT InvoiceNo) AS distinct_c_prefixed_invoice_count,
    ROUND(
        COUNT(*) * 100.0 /
        (
            SELECT COUNT(*)
            FROM retail_transactions_analysis
            WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
        ),
        2
    ) AS percentage_of_retained_records
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed';


/* =========================================================
   2. MONTHLY PATTERNS
   ========================================================= */

SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS transaction_month,
    COUNT(*) AS c_prefixed_record_count,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(Quantity) AS net_quantity,
    SUM(line_value) AS net_transaction_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed'
GROUP BY transaction_month
ORDER BY transaction_month;


/* =========================================================
   3. PRODUCT PATTERNS
   ========================================================= */

-- Top 10 StockCodes by most negative net quantity.
SELECT
    StockCode,
    MAX(Description) AS description,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed'
GROUP BY StockCode
ORDER BY net_quantity ASC
LIMIT 10;

-- Top 10 StockCodes by most negative net transaction value.
SELECT
    StockCode,
    MAX(Description) AS description,
    SUM(line_value) AS net_transaction_value,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed'
GROUP BY StockCode
ORDER BY net_transaction_value ASC
LIMIT 10;


/* =========================================================
   4. INTERSECTION OF THE TWO TOP-10 RANKINGS
   ========================================================= */

WITH quantity_list AS (
    SELECT
        StockCode,
        SUM(Quantity) AS net_quantity
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND invoice_reference_status = 'C-prefixed'
    GROUP BY StockCode
    ORDER BY net_quantity ASC
    LIMIT 10
),
value_list AS (
    SELECT
        StockCode,
        SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND invoice_reference_status = 'C-prefixed'
    GROUP BY StockCode
    ORDER BY net_transaction_value ASC
    LIMIT 10
)
SELECT
    StockCode,
    MAX(Description) AS description,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed'
  AND StockCode IN (SELECT StockCode FROM quantity_list)
  AND StockCode IN (SELECT StockCode FROM value_list)
GROUP BY StockCode
ORDER BY net_transaction_value ASC;


/* =========================================================
   5. BQ4 FINDINGS AND INTERPRETATION
   =========================================================

   C-prefixed records: 9,251.
   Distinct C-prefixed invoices: 3,836.
   Share of retained transaction records: 1.72%.

   October 2011 had the highest C-prefixed record volume.
   November 2011 had the highest distinct invoice count.
   December 2011 had the greatest negative quantity and
   negative transaction value.

   StockCodes 23843 and 23166 were prominent in the analysis.
   Manual (StockCode M) is not a conventional product code but
   was also significant in the intersection analysis.

   These findings describe C-prefixed transaction activity;
   the invoice prefix is not definitive proof of cancellation.
   =========================================================
