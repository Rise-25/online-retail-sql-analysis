/*
BUSINESS QUESTION 2: PRODUCT PERFORMANCE

Which products contribute most to the retailer's financial
performance and sales volume, and what does this reveal about
its product portfolio?

Primary reporting basis: Scenario C
- Retain unique and primary duplicate records.
- Retain C-prefixed and non-C-prefixed transactions.
- Use StockCode as the product identifier.
- Exclude the identified non-product transaction codes:
  AMAZONFEE, B, DOT, M, POST and S.
- Retain DCGSSBOY, DCGSSGIRL and PADS.

Description values are not used as the product key because
a StockCode may have multiple descriptions or missing values.
*/


/* =========================================================
   1. EXPLORATORY PRODUCT IDENTIFICATION
   HISTORICAL SCENARIO D: NON-C-PREFIXED RECORDS
   =========================================================

   These queries document the initial exploratory investigation.
   They are not the final reporting basis. The analysis moved to
   Scenario C after investigation of StockCode 23843 revealed
   a positive and negative transaction pair that offset each other.
   */

-- Initial population and missing-description profile.
SELECT
    COUNT(DISTINCT StockCode) AS distinct_stockcode_count,
    COUNT(*) AS transaction_record_count,
    COUNT(CASE WHEN Description IS NULL THEN 1 END)
        AS missing_description_record_count,
    COUNT(DISTINCT CASE WHEN Description IS NULL THEN StockCode END)
        AS stockcodes_with_missing_descriptions
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed';

-- Identify StockCodes with multiple distinct non-NULL descriptions.
SELECT
    StockCode,
    COUNT(DISTINCT Description) AS distinct_description_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
GROUP BY StockCode
HAVING COUNT(DISTINCT Description) > 1
ORDER BY distinct_description_count DESC;

-- Inspect StockCodes with five or more distinct descriptions.
SELECT
    StockCode,
    COUNT(*) AS transaction_record_count,
    COUNT(DISTINCT Description) AS distinct_description_count,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
GROUP BY StockCode
HAVING COUNT(DISTINCT Description) >= 5
ORDER BY distinct_description_count DESC;

-- Identify letter-only StockCodes for product/non-product review.
SELECT
    StockCode,
    COUNT(*) AS transaction_record_count,
    COUNT(DISTINCT Description) AS distinct_description_count,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode REGEXP '^[A-Za-z]+$'
GROUP BY StockCode
ORDER BY distinct_description_count DESC;

-- Summarise transaction characteristics of letter-only StockCodes.
WITH letter_stockcodes AS (
    SELECT DISTINCT StockCode
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND invoice_reference_status = 'Non-C-prefixed'
      AND StockCode REGEXP '^[A-Za-z]+$'
)
SELECT
    StockCode,
    COUNT(*) AS transaction_record_count,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    SUM(CASE WHEN unit_price_status = 'ZeroPrice' THEN 1 ELSE 0 END)
        AS zero_price_record_count,
    SUM(CASE WHEN unit_price_status = 'NegPrice' THEN 1 ELSE 0 END)
        AS negative_price_record_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode IN (SELECT StockCode FROM letter_stockcodes)
GROUP BY StockCode
ORDER BY net_transaction_value DESC;

-- Inspect selected non-product code records.
SELECT
    StockCode,
    InvoiceNo,
    Description,
    Quantity,
    UnitPrice,
    line_value,
    InvoiceDate
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode IN ('AMAZONFEE', 'B')
ORDER BY StockCode, InvoiceDate;

-- Historical Scenario D population after excluding the six
-- identified non-product codes.
SELECT
    COUNT(DISTINCT StockCode) AS distinct_stockcode_count,
    COUNT(*) AS transaction_record_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S');


/* =========================================================
   2. SCENARIO D EXPLORATORY RANKINGS
   ========================================================= */

-- Top 10 StockCodes by net transaction value (Scenario D).
SELECT
    StockCode,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
GROUP BY StockCode
ORDER BY net_transaction_value DESC
LIMIT 10;

-- Top 10 StockCodes by net quantity (Scenario D).
SELECT
    StockCode,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
GROUP BY StockCode
ORDER BY net_quantity DESC
LIMIT 10;

-- StockCodes appearing in both Scenario D top-10 rankings.
WITH value_list AS (
    SELECT StockCode, SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND invoice_reference_status = 'Non-C-prefixed'
      AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
    GROUP BY StockCode
    ORDER BY net_transaction_value DESC
    LIMIT 10
),
quantity_list AS (
    SELECT StockCode, SUM(Quantity) AS net_quantity
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND invoice_reference_status = 'Non-C-prefixed'
      AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
    GROUP BY StockCode
    ORDER BY net_quantity DESC
    LIMIT 10
)
SELECT
    StockCode,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'Non-C-prefixed'
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
  AND StockCode IN (SELECT StockCode FROM quantity_list)
  AND StockCode IN (SELECT StockCode FROM value_list)
GROUP BY StockCode;

-- Investigate StockCode 23843, which prompted the move to Scenario C.
SELECT
    StockCode,
    InvoiceNo,
    Description,
    Quantity,
    UnitPrice,
    line_value,
    InvoiceDate,
    invoice_reference_status
FROM retail_transactions_analysis
WHERE StockCode = '23843'
ORDER BY InvoiceDate, InvoiceNo;


/* =========================================================
   3. SCENARIO C: FINAL PRODUCT RANKINGS
   ========================================================= */

-- Top 10 products by net transaction value.
SELECT
    StockCode,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
GROUP BY StockCode
ORDER BY net_transaction_value DESC
LIMIT 10;

-- Top 10 products by net quantity.
SELECT
    StockCode,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
GROUP BY StockCode
ORDER BY net_quantity DESC
LIMIT 10;

-- Products appearing in both Scenario C top-10 rankings.
WITH value_list AS (
    SELECT StockCode, SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
    GROUP BY StockCode
    ORDER BY net_transaction_value DESC
    LIMIT 10
),
quantity_list AS (
    SELECT StockCode, SUM(Quantity) AS net_quantity
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
      AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
    GROUP BY StockCode
    ORDER BY net_quantity DESC
    LIMIT 10
)
SELECT
    StockCode,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
  AND StockCode IN (SELECT StockCode FROM quantity_list)
  AND StockCode IN (SELECT StockCode FROM value_list)
GROUP BY StockCode;


/* =========================================================
   4. ZERO-PRICE SENSITIVITY CHECK
   =========================================================

   Compare the top 10 by net quantity after excluding zero-price
   records. This tests whether zero-price transactions materially
   change the composition of the quantity ranking.
   */

SELECT
    StockCode,
    GROUP_CONCAT(DISTINCT Description SEPARATOR ' | ') AS descriptions,
    SUM(line_value) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(AVG(line_value), 2) AS average_line_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S')
  AND unit_price_status <> 'ZeroPrice'
GROUP BY StockCode
ORDER BY net_quantity DESC
LIMIT 10;


/* =========================================================
   5. BQ2 FINDINGS AND INTERPRETATION
   =========================================================

   Product key: StockCode, not Description.

   Six codes excluded from product rankings:
   AMAZONFEE, B, DOT, M, POST and S.
   DCGSSBOY, DCGSSGIRL and PADS were retained.

   The Scenario D exploratory investigation was retained as
   historical context. Final product rankings use Scenario C.

   StockCode 23843 had a positive transaction of 80,995 units
   and £168,469.60, paired with a C-prefixed negative transaction
   of the same quantity and value. This demonstrated why removing
   C-prefixed transactions could materially distort product
   performance.

   The letter-only code investigation covered nine codes only;
   it was not an exhaustive classification of every non-product
   code in the dataset.

   Zero-price sensitivity did not change the composition of
   the Scenario C top 10 quantity ranking, although some ranks
   and quantities changed.

   Descriptions may be missing or multiple for a StockCode.
   No missing descriptions were imputed.
   ========================================================= */
