/*
Project: Online Retail Sales Analysis
Database: online_retail_analysis

Purpose:
Run final reconciliation checks after the setup, data-preparation
and business-analysis scripts have been executed.

IMPORTANT:
- These are validation queries; they do not modify source data.
- Run after 02_analysis_view_and_table.sql has created the view
  and physical analysis table.
- Expected values are based on the approved analysis decisions
  and previously established results. A mismatch should be
  investigated, not automatically treated as a query failure.
- The script has been prepared for MySQL 8.0.46 but has not yet
  been executed against the user's local database.
*/

USE online_retail_analysis;


/* =========================================================
   1. SOURCE, VIEW AND PHYSICAL TABLE ROW COUNTS
   ========================================================= */

SELECT
    'retail_transactions' AS object_name,
    COUNT(*) AS record_count
FROM retail_transactions

UNION ALL

SELECT
    'vw_retail_transactions_analysis' AS object_name,
    COUNT(*) AS record_count
FROM vw_retail_transactions_analysis

UNION ALL

SELECT
    'retail_transactions_analysis' AS object_name,
    COUNT(*) AS record_count
FROM retail_transactions_analysis;

/*
Expected:
- Source table:             541,909
- Analysis view:            541,909
- Physical analysis table:  541,909

All three counts should agree.
*/


/* =========================================================
   2. DUPLICATE CLASSIFICATION RECONCILIATION
   ========================================================= */

SELECT
    duplicate_record_status,
    COUNT(*) AS record_count
FROM retail_transactions_analysis
GROUP BY duplicate_record_status
ORDER BY
    CASE duplicate_record_status
        WHEN 'Unique' THEN 1
        WHEN 'Primary Duplicate' THEN 2
        WHEN 'Secondary Duplicate' THEN 3
        ELSE 4
    END;

/*
Expected:
- Unique:               531,762
- Primary Duplicate:      4,879
- Secondary Duplicate:    5,268
- Total:                541,909
*/

SELECT
    COUNT(*) AS total_record_count,
    SUM(
        CASE
            WHEN duplicate_record_status IN ('Unique', 'Primary Duplicate')
            THEN 1 ELSE 0
        END
    ) AS retained_record_count,
    SUM(
        CASE
            WHEN duplicate_record_status = 'Secondary Duplicate'
            THEN 1 ELSE 0
        END
    ) AS excluded_secondary_duplicate_count,
    CASE
        WHEN COUNT(*) = 541909
         AND SUM(
             CASE
                 WHEN duplicate_record_status IN ('Unique', 'Primary Duplicate')
                 THEN 1 ELSE 0
             END
         ) = 536641
         AND SUM(
             CASE
                 WHEN duplicate_record_status = 'Secondary Duplicate'
                 THEN 1 ELSE 0
             END
         ) = 5268
        THEN 'PASS'
        ELSE 'REVIEW'
    END AS duplicate_reconciliation_status
FROM retail_transactions_analysis;


/* =========================================================
   3. SCENARIO C ANALYSIS POPULATION
   ========================================================= */

SELECT
    COUNT(*) AS retained_record_count,
    SUM(CASE WHEN CustomerID IS NOT NULL THEN 1 ELSE 0 END)
        AS populated_customer_id_record_count,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END)
        AS missing_customer_id_record_count,
    COUNT(DISTINCT CASE WHEN CustomerID IS NOT NULL THEN CustomerID END)
        AS distinct_identifiable_customer_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate');

/*
Expected:
- Retained records:                    536,641
- Populated CustomerID records:        401,604
- Missing CustomerID records:          135,037
- Distinct identifiable customers:       4,372
*/


/* =========================================================
   4. SCENARIO C FINANCIAL RECONCILIATION
   ========================================================= */

SELECT
    ROUND(SUM(line_value), 2) AS total_net_transaction_value,
    ROUND(
        SUM(CASE WHEN CustomerID IS NOT NULL THEN line_value ELSE 0 END),
        2
    ) AS populated_customer_id_net_value,
    ROUND(
        SUM(CASE WHEN CustomerID IS NULL THEN line_value ELSE 0 END),
        2
    ) AS missing_customer_id_net_value,
    ROUND(
        SUM(CASE WHEN CustomerID IS NOT NULL THEN line_value ELSE 0 END)
        + SUM(CASE WHEN CustomerID IS NULL THEN line_value ELSE 0 END),
        2
    ) AS customer_id_value_reconciliation
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate');

/*
Expected:
- Total net transaction value:             £9,726,006.95
- Populated CustomerID net value:          £8,278,519.42
- Missing CustomerID net value:            £1,447,487.53

The populated and missing CustomerID amounts should sum to
the total net transaction value.
*/


/* =========================================================
   5. BQ1 MONTHLY-TO-OVERALL VALUE RECONCILIATION
   ========================================================= */

WITH monthly_values AS (
    SELECT
        DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
        SUM(line_value) AS monthly_net_value
    FROM retail_transactions_analysis
    WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
    GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
)
SELECT
    ROUND(SUM(monthly_net_value), 2) AS sum_of_monthly_net_values,
    ROUND(
        (
            SELECT SUM(line_value)
            FROM retail_transactions_analysis
            WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
        ),
        2
    ) AS overall_net_transaction_value
FROM monthly_values;

/*
Expected:
Both values: £9,726,006.95

This reconciles monthly net transaction values to the Scenario C
overall net transaction value. It does not imply that the two
December periods represent complete calendar months.
*/


/* =========================================================
   6. BQ2 PRODUCT POPULATION RECONCILIATION
   ========================================================= */

SELECT
    COUNT(DISTINCT StockCode) AS distinct_stock_code_count,
    COUNT(*) AS product_analysis_record_count,
    ROUND(SUM(line_value), 2) AS product_analysis_net_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND StockCode NOT IN ('AMAZONFEE', 'B', 'DOT', 'M', 'POST', 'S');

/*
This check confirms the final product-analysis population after
the six agreed non-product StockCodes are excluded.

No fixed expected row count or StockCode count is asserted here:
the earlier recorded counts related to the exploratory Scenario D
population and should not be substituted for Scenario C results.
*/


/* =========================================================
   7. BQ3 CUSTOMER AND COUNTRY VALUE RECONCILIATION
   ========================================================= */

-- Customer-level population: identifiable customers only.
SELECT
    COUNT(DISTINCT CustomerID) AS distinct_customer_count,
    ROUND(SUM(line_value), 2) AS identifiable_customer_net_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND CustomerID IS NOT NULL;

-- Country-level population: all retained records, including
-- records with missing CustomerID.
SELECT
    COUNT(DISTINCT Country) AS distinct_country_count,
    ROUND(SUM(line_value), 2) AS country_analysis_net_value
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate');

/*
Expected:
- Identifiable customers: 4,372
- Identifiable customer net value: £8,278,519.42
- Countries: 38
- Country analysis net value: £9,726,006.95

Country-level analysis includes records with missing CustomerID.
The sum of distinct invoice counts across countries is not the
same as a global distinct invoice count in every possible dataset;
do not use grouped invoice counts as a substitute for a global
distinct-invoice measure.
*/


/* =========================================================
   8. BQ4 C-PREFIXED TRANSACTION RECONCILIATION
   ========================================================= */

SELECT
    COUNT(*) AS c_prefixed_record_count,
    COUNT(DISTINCT InvoiceNo) AS c_prefixed_distinct_invoice_count,
    ROUND(SUM(line_value), 2) AS c_prefixed_net_transaction_value,
    SUM(Quantity) AS c_prefixed_net_quantity
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
  AND invoice_reference_status = 'C-prefixed';

/*
Previously established reference points:
- C-prefixed records: 9,251
- Distinct C-prefixed invoices: 3,836

The net value and net quantity should be reviewed against the
current query output. C-prefixed is a cancellation-associated
indicator, not a definitive cancellation classification.
*/


/* =========================================================
   9. FINAL VIEW-TO-TABLE CONTENT RECONCILIATION
   ========================================================= */

-- Compare key aggregate values between the view and physical table.
SELECT
    'view' AS analysis_object,
    COUNT(*) AS total_record_count,
    ROUND(SUM(line_value), 2) AS total_line_value,
    SUM(CASE WHEN duplicate_record_status = 'Secondary Duplicate'
             THEN 1 ELSE 0 END) AS secondary_duplicate_count
FROM vw_retail_transactions_analysis

UNION ALL

SELECT
    'physical_table' AS analysis_object,
    COUNT(*) AS total_record_count,
    ROUND(SUM(line_value), 2) AS total_line_value,
    SUM(CASE WHEN duplicate_record_status = 'Secondary Duplicate'
             THEN 1 ELSE 0 END) AS secondary_duplicate_count
FROM retail_transactions_analysis;

/*
The view and physical table should agree on all three measures.
If they do not, recreate the physical table from the current
authoritative view and rerun the checks. Do not drop or replace
the table until its contents and any dependent work have been
considered.
*/
