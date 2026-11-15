/*
Project: Online Retail Sales Analysis
Database: online_retail_analysis
Source table: retail_transactions

Purpose:
Document the CSV import approach and perform initial checks
to confirm that the dataset was loaded successfully.

Import method:
The Online Retail CSV was imported using the MySQL Command
Line Client with LOAD DATA LOCAL INFILE.

The import statement and local file path were not retained in
the original development script, so they are intentionally
not reproduced here.
*/

USE online_retail_analysis;

-- Check whether LOCAL INFILE is enabled.
SHOW GLOBAL VARIABLES LIKE 'local_infile';

-- Enable LOCAL INFILE if required.
-- This setting may require appropriate MySQL privileges.
-- Run only if the setting is currently disabled.
SET GLOBAL local_infile = 1;

-- Verify the setting after enabling it.
SHOW GLOBAL VARIABLES LIKE 'local_infile';


/* =========================================================
   INITIAL IMPORT VALIDATION
   ========================================================= */

-- Confirm the total number of imported records.
SELECT
    COUNT(*) AS total_record_count
FROM retail_transactions;

-- Inspect a small sample of imported records.
SELECT
    InvoiceNo,
    InvoiceDate,
    Quantity,
    UnitPrice,
    CustomerID,
    Country
FROM retail_transactions
LIMIT 10;

-- Confirm the date range covered by the dataset.
SELECT
    MIN(InvoiceDate) AS earliest_invoice_date,
    MAX(InvoiceDate) AS latest_invoice_date,
    DATEDIFF(MAX(InvoiceDate), MIN(InvoiceDate)) AS date_range_days
FROM retail_transactions;

-- Count the distinct countries represented in the dataset.
SELECT
    COUNT(DISTINCT Country) AS distinct_country_count
FROM retail_transactions;


/* =========================================================
   EXPECTED INITIAL VALIDATION RESULTS

   Total records:       541,909
   Earliest invoice:    2010-12-01 08:26:00
   Latest invoice:      2011-12-09 12:50:00
   Distinct countries:  38

   Note:
   The original import returned four warnings. Their details
   were not retained, so this script does not claim that the
   import completed without warnings.

   Detailed missing-value, duplicate and transaction-quality
   investigations are documented in the data-preparation
   scripts, not in this initial setup file.
   ========================================================= */
