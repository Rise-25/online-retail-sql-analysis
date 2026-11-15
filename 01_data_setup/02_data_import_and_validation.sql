/*
Online Retail CSV import documentation.

The original LOAD DATA statement, local file path and import settings
were not retained. This is a TEMPLATE, not a verbatim copy.
The original import returned four warnings; their details were not retained.
*/
USE online_retail_analysis;

SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- Enable only if required and permitted:
-- SET GLOBAL local_infile = 1;

-- TEMPLATE ONLY: adapt the absolute path and all CSV settings.
-- Confirm the CSV column order and date format before running.
--
-- LOAD DATA LOCAL INFILE '/absolute/path/to/Online_Retail.csv'
-- INTO TABLE retail_transactions
-- FIELDS TERMINATED BY ','
-- OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\n'
-- IGNORE 1 LINES
-- (
--   InvoiceNo, StockCode, Description, Quantity,
--   @InvoiceDate, UnitPrice, @CustomerID, Country
-- )
-- SET
--   InvoiceDate = STR_TO_DATE(@InvoiceDate, '%m/%d/%Y %H:%i'),
--   CustomerID = NULLIF(@CustomerID, '');
--
-- The date format above is illustrative only. Change it to match
-- the CSV you actually prepared. Remove IGNORE 1 LINES if there
-- is no header. Adjust delimiters/quoting/line endings as needed.

SELECT COUNT(*) AS total_record_count
FROM retail_transactions;

SELECT InvoiceNo, InvoiceDate, Quantity, UnitPrice, CustomerID, Country
FROM retail_transactions
LIMIT 10;

SELECT
    MIN(InvoiceDate) AS earliest_invoice_date,
    MAX(InvoiceDate) AS latest_invoice_date,
    DATEDIFF(MAX(InvoiceDate), MIN(InvoiceDate)) AS date_range_days
FROM retail_transactions;

SELECT COUNT(DISTINCT Country) AS distinct_country_count
FROM retail_transactions;

/*
Expected initial checks:
Total records: 541,909
Earliest invoice: 2010-12-01 08:26:00
Latest invoice: 2011-12-09 12:50:00
Distinct countries: 38

The original import returned four warnings. Their details were
not retained and are not reconstructed here.
*/
