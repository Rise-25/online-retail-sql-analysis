/*
BUSINESS QUESTION 1: SALES PERFORMANCE OVER TIME

How has the retailer's sales performance changed over time,
and what do transaction patterns reveal about its financial
and operational activity?

Primary reporting basis: Scenario C
- Retain unique and primary duplicate records.
- Retain C-prefixed and non-C-prefixed transactions.
- Retain negative quantities and unusual price records.

Scenario D is used as a sensitivity comparison.
C-prefixed invoice numbers are a cancellation-associated
indicator, not definitive cancellation classifications.

Metrics:
- Net transaction value = SUM(line_value)
- Net quantity = SUM(Quantity)
- Invoice count = COUNT(DISTINCT InvoiceNo)
- Average net value per invoice = net value / distinct invoices

The dataset covers partial December 2010 and December 2011.
*/


/* =========================================================
   1. SCENARIO COMPARISON
   ========================================================= */

-- Scenario A: All records, including secondary duplicates
-- and C-prefixed invoice references.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2)
        AS average_net_value_per_invoice
FROM retail_transactions_analysis
GROUP BY sales_month
ORDER BY sales_month;

-- Scenario B: All records, excluding C-prefixed invoice references.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2)
        AS average_net_value_per_invoice
FROM retail_transactions_analysis
WHERE invoice_reference_status = 'Non-C-prefixed'
GROUP BY sales_month
ORDER BY sales_month;

-- Scenario C: Deduplicated records, retaining C-prefixed references.
-- PRIMARY REPORTING SCENARIO.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2)
        AS average_net_value_per_invoice
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY sales_month
ORDER BY sales_month;

-- Scenario D: Deduplicated records, excluding C-prefixed references.
-- SENSITIVITY COMPARISON.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2)
        AS average_net_value_per_invoice
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
GROUP BY sales_month
ORDER BY sales_month;


/* =========================================================
   2. SCENARIO C: NEGATIVE QUANTITY INVESTIGATION
   ========================================================= */

-- Monthly impact of negative-quantity transactions.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    COUNT(*) AS negative_quantity_record_count,
    COUNT(DISTINCT InvoiceNo) AS affected_invoice_count,
    SUM(Quantity) AS net_negative_quantity,
    SUM(line_value) AS net_transaction_value,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND quantity_status = 'NegQty'
GROUP BY sales_month
ORDER BY sales_month;

-- Examine price characteristics of negative-quantity transactions.
SELECT
    unit_price_status,
    COUNT(*) AS record_count,
    SUM(Quantity) AS net_quantity,
    SUM(line_value) AS net_transaction_value,
    MIN(UnitPrice) AS minimum_unit_price,
    MAX(UnitPrice) AS maximum_unit_price
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND quantity_status = 'NegQty'
GROUP BY unit_price_status
ORDER BY unit_price_status;

-- Inspect the unusual £38,970 transaction identified during analysis.
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    line_value,
    invoice_reference_status,
    duplicate_record_status
FROM retail_transactions_analysis
WHERE UnitPrice = 38970.00;


/* =========================================================
   3. SCENARIO C: ZERO-PRICE INVESTIGATION
   ========================================================= */

-- Monthly impact of zero-price transactions.
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    COUNT(*) AS zero_price_record_count,
    COUNT(DISTINCT InvoiceNo) AS affected_invoice_count,
    SUM(Quantity) AS net_quantity,
    SUM(line_value) AS net_transaction_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND unit_price_status = 'ZeroPrice'
GROUP BY sales_month
ORDER BY sales_month;

-- Quantity breakdown of zero-price transactions.
SELECT
    quantity_status,
    COUNT(*) AS record_count,
    COUNT(DISTINCT InvoiceNo) AS affected_invoice_count,
    SUM(Quantity) AS net_quantity
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND unit_price_status = 'ZeroPrice'
GROUP BY quantity_status
ORDER BY quantity_status;

-- Inspect negative UnitPrice transactions retained in Scenario C.
SELECT
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    CustomerID,
    Country,
    line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND unit_price_status = 'NegPrice'
ORDER BY InvoiceDate;


/* =========================================================
   4. BQ1 FINDINGS AND INTERPRETATION
   =========================================================

   Scenario C net transaction value: £9,726,006.95
   Scenario D net transaction value: £10,619,986.68

   Excluding C-prefixed records increases net transaction
   value in this dataset because cancellation-associated
   negative transactions are removed while their corresponding
   positive transactions may remain.

   November 2011 was the strongest month in Scenario C.
   September to November 2011 each exceeded £1 million in
   monthly net transaction value.

   April 2011 was the weakest complete calendar month.
   December 2010 and December 2011 are partial periods.

   Negative quantities and unusual price records were retained.
   Their meaning depends on transaction context; net transaction
   value should not automatically be described as recognised revenue.

   C-prefix is a proxy, not a verified cancellation label.
   ========================================================= */
