/*
Run after creating retail_transactions_analysis.
Export each result set separately from MySQL Workbench as CSV.
Scenario C retains Unique and Primary Duplicate records, including
both C-prefixed and non-C-prefixed invoice references.
The SELECT columns and calculated measures match the committed chart CSVs.
*/

/* CHART 1: Monthly net transaction value
   Export as monthly_net_transaction_value.csv
   Columns: sales_month, net_transaction_value, net_quantity,
            distinct_invoice_count, average_net_value_per_invoice */
SELECT
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
    ROUND(SUM(line_value), 2) AS net_transaction_value,
    SUM(Quantity) AS net_quantity,
    COUNT(DISTINCT InvoiceNo) AS distinct_invoice_count,
    ROUND(
        SUM(line_value) / NULLIF(COUNT(DISTINCT InvoiceNo), 0),
        2
    ) AS average_net_value_per_invoice
FROM retail_transactions_analysis
WHERE duplicate_record_status IN ('Unique', 'Primary Duplicate')
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY sales_month;

/* CHART 2: Customer contribution concentration
   Export as customer_contribution_concentration.csv
   Columns: customer_rank, CustomerID, net_transaction_value,
            cumulative_contribution_pct
   Customer analysis excludes missing CustomerID values. */
WITH customer_totals AS (
    SELECT
        CustomerID,
        SUM(line_value) AS net_transaction_value
    FROM retail_transactions_analysis
    WHERE customer_id_status = 'Populated CustomerID'
      AND duplicate_record_status IN ('Unique', 'Primary Duplicate')
    GROUP BY CustomerID
),
ranked_customers AS (
    SELECT
        CustomerID,
        net_transaction_value,
        ROW_NUMBER() OVER (
            ORDER BY net_transaction_value DESC, CustomerID ASC
        ) AS customer_rank,
        SUM(net_transaction_value) OVER () AS total_identifiable_customer_value,
        SUM(net_transaction_value) OVER (
            ORDER BY net_transaction_value DESC, CustomerID ASC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_net_transaction_value
    FROM customer_totals
)
SELECT
    customer_rank,
    CustomerID,
    ROUND(net_transaction_value, 2) AS net_transaction_value,
    ROUND(
        cumulative_net_transaction_value * 100.0
        / NULLIF(total_identifiable_customer_value, 0),
        2
    ) AS cumulative_contribution_pct
FROM ranked_customers
ORDER BY customer_rank;
