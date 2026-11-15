/*
BUSINESS QUESTION 3: CUSTOMER BEHAVIOUR AND GEOGRAPHICAL PERFORMANCE

Who are the retailer's highest-value customers, and how
concentrated is its net transaction value among them?

Customer analysis:
- Scenario C: unique and primary duplicate records.
- C-prefixed and non-C-prefixed records retained.
- Missing CustomerIDs excluded only from customer attribution.

Country analysis:
- Scenario C population, including records with missing CustomerID.
- Country represents the country recorded on the transaction,
  not necessarily the customer's country of residence.

Net transaction value is not necessarily recognised revenue.
*/


/* =========================================================
   1. CUSTOMER ANALYSIS POPULATION
   ========================================================= */

SELECT
    COUNT(*) AS transaction_record_count,
    COUNT(CustomerID) AS records_with_customer_id,
    COUNT(CASE WHEN customer_id_status = 'Missing CustomerID' THEN 1 END)
        AS missing_customer_id_record_count,
    COUNT(DISTINCT CustomerID) AS distinct_identifiable_customer_count
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate');

-- Financial impact of missing CustomerIDs.
SELECT
    customer_id_status,
    SUM(line_value) AS net_transaction_value,
    ROUND(
        SUM(line_value) * 100.0 /
        SUM(SUM(line_value)) OVER (), 2
    ) AS net_transaction_value_pct
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY customer_id_status
ORDER BY customer_id_status;

-- Validate the net transaction value attributable to identified customers.
SELECT
    SUM(line_value) AS identifiable_customer_net_transaction_value
FROM retail_transactions_analysis
WHERE customer_id_status = 'Populated CustomerID'
  AND duplicate_record_status IN ('Unique', 'Primary Duplicate');


/* =========================================================
   2. CUSTOMER VALUE RANKING
   ========================================================= */

-- Main customer ranking: one row per CustomerID.
SELECT
    CustomerID,
    SUM(line_value) AS net_transaction_value,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(Quantity) AS net_quantity,
    ROUND(
        SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2
    ) AS average_net_value_per_invoice,
    ROUND(
        SUM(line_value) * 100.0 /
        SUM(SUM(line_value)) OVER (), 2
    ) AS customer_contribution_pct
FROM retail_transactions_analysis
WHERE customer_id_status = 'Populated CustomerID'
  AND duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY CustomerID
ORDER BY net_transaction_value DESC;

-- Supporting exploratory breakdown: CustomerID by recorded Country.
-- Some customers appear in more than one recorded country.
SELECT
    CustomerID,
    Country,
    SUM(line_value) AS net_transaction_value,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(Quantity) AS net_quantity,
    ROUND(
        SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2
    ) AS average_net_value_per_invoice,
    ROUND(
        SUM(line_value) * 100.0 /
        SUM(SUM(line_value)) OVER (), 2
    ) AS customer_country_contribution_pct
FROM retail_transactions_analysis
WHERE customer_id_status = 'Populated CustomerID'
  AND duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY CustomerID, Country
ORDER BY net_transaction_value DESC;


/* =========================================================
   3. CUSTOMER CONCENTRATION
   ========================================================= */

-- Rank customers by net transaction value.
WITH customer_totals AS (
    SELECT
        CustomerID,
        SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE customer_id_status = 'Populated CustomerID'
      AND duplicate_record_status IN ('Unique', 'Primary Duplicate')
    GROUP BY CustomerID
)
SELECT
    CustomerID,
    net_transaction_value,
    ROW_NUMBER() OVER (
        ORDER BY net_transaction_value DESC, CustomerID ASC
    ) AS customer_rank,
    COUNT(*) OVER () AS total_customer_count
FROM customer_totals
ORDER BY customer_rank;

-- Calculate cumulative contribution to net transaction value.
WITH customer_totals AS (
    SELECT
        CustomerID,
        SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE customer_id_status = 'Populated CustomerID'
      AND duplicate_record_status IN ('Unique', 'Primary Duplicate')
    GROUP BY CustomerID
)
SELECT
    ROW_NUMBER() OVER (
        ORDER BY net_transaction_value DESC, CustomerID ASC
    ) AS customer_rank,
    CustomerID,
    net_transaction_value,
    ROUND(
        SUM(net_transaction_value) OVER (
            ORDER BY net_transaction_value DESC, CustomerID ASC
        ) * 100.0 /
        SUM(net_transaction_value) OVER (),
        2
    ) AS cumulative_contribution_pct
FROM customer_totals
ORDER BY customer_rank;


/* =========================================================
   4. COUNTRY PERFORMANCE
   ========================================================= */

-- Includes all Scenario C records, including missing CustomerIDs.
SELECT
    Country,
    SUM(line_value) AS net_transaction_value,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    SUM(Quantity) AS net_quantity,
    ROUND(
        SUM(line_value) / COUNT(DISTINCT InvoiceNo), 2
    ) AS average_net_value_per_invoice,
    ROUND(
        SUM(line_value) * 100.0 /
        SUM(SUM(line_value)) OVER (), 2
    ) AS country_contribution_pct
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY Country
ORDER BY net_transaction_value DESC;


/* =========================================================
   5. BQ3 FINDINGS AND INTERPRETATION
   =========================================================

   Scenario C retained records: 536,641.
   Populated CustomerID records: 401,604.
   Missing CustomerID records: 135,037.
   Distinct identifiable customers: 4,372.

   Identifiable customer net transaction value: £8,278,519.42
   Missing CustomerID net transaction value: £1,447,487.53
   Overall Scenario C net transaction value: £9,726,006.95

   Customer-level analysis excludes missing CustomerIDs.
   Country-level analysis includes them.

   Customer-country results are supporting exploratory analysis;
   the main customer ranking groups by CustomerID alone.

   Country is the country recorded on the transaction and should
   not be interpreted as verified customer residence.

   Concentration percentages can be affected by customers with
   negative net balances. Cumulative contribution may therefore
   briefly exceed 100%.
   =========================================================
