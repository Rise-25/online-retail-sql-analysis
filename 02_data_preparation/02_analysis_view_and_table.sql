/*
Create/refresh the analysis view and materialise its results.
The original retail_transactions source table remains unchanged.
*/

CREATE OR REPLACE VIEW vw_retail_transactions_analysis AS
WITH duplicate_check AS (
    SELECT
        InvoiceNo, StockCode, Description, Quantity, InvoiceDate,
        UnitPrice, CustomerID, Country,
        COUNT(*) OVER (
            PARTITION BY InvoiceNo, StockCode, Description, Quantity,
                         InvoiceDate, UnitPrice, CustomerID, Country
        ) AS duplicate_count,
        ROW_NUMBER() OVER (
            PARTITION BY InvoiceNo, StockCode, Description, Quantity,
                         InvoiceDate, UnitPrice, CustomerID, Country
            ORDER BY InvoiceNo
        ) AS duplicate_row_number
    FROM retail_transactions
)
SELECT
    InvoiceNo, StockCode, Description, Quantity, InvoiceDate,
    UnitPrice, CustomerID, Country,
    (Quantity * UnitPrice) AS line_value,
    -- Classify whether a transaction can be attributed to a customer.
    CASE WHEN CustomerID IS NULL THEN 'Missing CustomerID'
         ELSE 'Populated CustomerID' END AS customer_id_status,
    -- Flag missing product descriptions without imputing values.
    CASE WHEN Description IS NULL THEN 'Missing Description'
         ELSE 'Populated Description' END AS description_status,
    -- Classify transaction quantity direction for later analysis.
    CASE WHEN Quantity > 0 THEN 'PosQty'
         WHEN Quantity < 0 THEN 'NegQty'
         ELSE 'ZeroQty' END AS quantity_status,
    -- Classify unit-price direction, retaining zero and negative prices.
    CASE WHEN UnitPrice > 0 THEN 'PosPrice'
         WHEN UnitPrice < 0 THEN 'NegPrice'
         ELSE 'ZeroPrice' END AS unit_price_status,
    -- Identify C-prefixed invoice references as a cancellation-associated proxy.
    CASE WHEN InvoiceNo LIKE 'C%' THEN 'C-prefixed'
         ELSE 'Non-C-prefixed' END AS invoice_reference_status,
    -- Distinguish unique rows, the retained primary duplicate, and later copies.
    CASE WHEN duplicate_count = 1 THEN 'Unique'
         WHEN duplicate_row_number = 1 THEN 'Primary Duplicate'
         ELSE 'Secondary Duplicate' END AS duplicate_record_status
FROM duplicate_check;

/*
Rebuild only the derived table. This does not drop or modify
the original retail_transactions source table. Review any
additional dependencies on the derived table before rebuilding.
*/
DROP TABLE IF EXISTS retail_transactions_analysis;

CREATE TABLE retail_transactions_analysis AS
SELECT *
FROM vw_retail_transactions_analysis;

SELECT COUNT(*) AS total_record_count
FROM retail_transactions_analysis;

SELECT duplicate_record_status, COUNT(*) AS record_count
FROM retail_transactions_analysis
GROUP BY duplicate_record_status
ORDER BY duplicate_record_status;

SELECT
    COUNT(*) AS total_record_count,
    COUNT(CASE WHEN duplicate_record_status IN ('Unique', 'Primary Duplicate')
               THEN 1 END) AS retained_record_count,
    COUNT(CASE WHEN duplicate_record_status = 'Secondary Duplicate'
               THEN 1 END) AS excluded_secondary_duplicate_count
FROM retail_transactions_analysis;

SELECT
    (SELECT COUNT(*) FROM vw_retail_transactions_analysis) AS view_record_count,
    (SELECT COUNT(*) FROM retail_transactions_analysis) AS analysis_table_record_count;
