# Online Retail SQL Portfolio Project

## Project overview

This project analyses the UCI Online Retail transactional dataset using MySQL. It explores sales performance, product performance, customer behaviour, geographical performance and cancellation-associated transaction activity.

The work was developed incrementally, with data-quality decisions and business-question definitions agreed before the corresponding analysis. The original source table is retained unchanged; analysis is performed using a prepared view and a physical analysis table.

## Dataset and environment

- **Dataset:** UCI Online Retail dataset
- **Database:** `online_retail_analysis`
- **Source table:** `retail_transactions`
- **Analysis view:** `vw_retail_transactions_analysis`
- **Physical analysis table:** `retail_transactions_analysis`
- **Database platform:** MySQL Server 8.0.46
- **SQL environment:** MySQL Workbench 8.0.46

The imported source dataset contained 541,909 records, covered 1 December 2010 to 9 December 2011, and represented 38 countries.

The original CSV was imported using the MySQL Command Line Client with `LOAD DATA LOCAL INFILE`. The original import statement and local file path were not retained in the development script, so they are not reproduced here. The import returned four warnings; their details were not retained.

## Repository structure

```text
Online_Retail_SQL_Portfolio/
├── 01_data_setup/
│   ├── 01_create_database_and_table.sql
│   └── 02_data_import_and_validation.sql
├── 02_data_preparation/
│   ├── 01_data_quality_checks.sql
│   └── 02_analysis_view_and_table.sql
├── 03_business_analysis/
│   ├── BQ1_sales_performance.sql
│   ├── BQ2_product_performance.sql
│   ├── BQ3_customer_and_geographical_performance.sql
│   └── BQ4_cancellation_associated_analysis.sql
├── 04_validation/
│   └── final_reconciliation_checks.sql
└── README.md
```

## How to run the project

Run the scripts in the numbered folder order:

1. `01_data_setup/01_create_database_and_table.sql`
   - Creates the database and source table.
2. Import the UCI CSV into `retail_transactions`.
   - The import method is documented in `02_data_setup/02_data_import_and_validation.sql`.
   - The actual local file path and `LOAD DATA LOCAL INFILE` statement must be supplied for the local environment.
3. `01_data_setup/02_data_import_and_validation.sql`
   - Checks the imported row count, sample records, date range and country count.
4. `02_data_preparation/01_data_quality_checks.sql`
   - Runs the data-quality investigations and documents the agreed treatments.
5. `02_data_preparation/02_analysis_view_and_table.sql`
   - Creates the authoritative analysis view and materialises it as `retail_transactions_analysis`.
   - The physical table creation is a one-time preparation step. If rerunning it, consider the existing table and any dependent work before replacing it.
6. Run the four scripts in `03_business_analysis/`.
7. Run `04_validation/final_reconciliation_checks.sql`.

The scripts are written for MySQL 8.0.46. The four business-question scripts were executed in the user’s MySQL environment and their result exports were reviewed. All nine checks in `04_validation/final_reconciliation_checks.sql` were also run and passed. The local CSV import step remains environment-specific: supply the correct file path and ensure `LOCAL INFILE` is enabled before importing.

## Data preparation and analytical decisions

The project retained the original source data and applied metric-specific treatments in the analysis population.

- **Exact duplicates:** exact matches across all eight source columns were classified as `Unique`, `Primary Duplicate` and `Secondary Duplicate`. Unique and primary duplicate rows are retained for primary reporting; secondary duplicate rows are excluded.
- **Negative quantities:** retained. Negative quantities are not automatically assumed to represent cancellations or returns.
- **C-prefixed invoice references:** treated as a cancellation-associated indicator, not definitive proof of cancellation.
- **Zero unit prices:** retained. Their presence and quantity direction were investigated.
- **Negative unit prices:** retained and flagged for interpretation; the identified records relate to `Adjust bad debt`, not ordinary product sales.
- **Missing descriptions:** retained as NULL. No description imputation was applied. `StockCode` is used as the product identifier.
- **Missing CustomerID:** retained in the analysis dataset. Customer-specific analysis excludes records without an identifiable CustomerID; country analysis includes them.
- **Product exclusions:** six identified non-product StockCodes (`AMAZONFEE`, `B`, `DOT`, `M`, `POST` and `S`) are excluded from the final product rankings. `DCGSSBOY`, `DCGSSGIRL` and `PADS` are retained.

### Primary reporting scenario

Scenario C is the approved primary reporting basis:

- Exclude secondary exact duplicates.
- Retain C-prefixed records.

Scenario D is used as a sensitivity comparison in the agreed analysis. The earlier Scenario D product-identification work is retained in the BQ2 script as exploratory history and is labelled accordingly. Final product rankings use Scenario C.

## Business questions and headline findings

### BQ1 — Sales performance over time

**Question:** How has the retailer's sales performance changed over time, and what do transaction patterns reveal about its financial and operational activity?

- Scenario C net transaction value: **£9,726,006.95**.
- November 2011 was the strongest month by net transaction value: **£1,456,145.80**.
- Net transaction value exceeded £1 million in September, October and November 2011.
- April 2011 was the weakest complete calendar month by net transaction value.
- December 2010 and December 2011 are partial periods in the dataset and should not be compared as full months.

### BQ2 — Product performance

**Question:** Which products contribute most to the retailer's financial performance and sales volume, and what does this reveal about its product portfolio?

- Product performance is grouped by `StockCode`, rather than description text.
- StockCode `22423` ranked first by net transaction value (**£164,459.49**).
- StockCode `22197` ranked first by net quantity (**56,427**).
- Five StockCodes appeared in both the top-ten net-value and top-ten net-quantity rankings: `85099B`, `85123A`, `23084`, `84879` and `22197`.
- The top-ten quantity ranking retained the same product composition in the zero-price sensitivity check, although some quantities and ranks changed.

### BQ3 — Customer behaviour and geographical performance

**Question:** Who are the retailer's highest-value customers, and how concentrated is its net transaction value among them?

- The retained analysis population contains **4,372 identifiable customers**.
- Identifiable-customer net transaction value: **£8,278,519.42**.
- Records with missing CustomerID account for **£1,447,487.53** of net transaction value and remain included in the overall and country-level populations.
- The top 10% of identifiable customers (438 customers) account for **60.14%** of identifiable-customer net transaction value.
- The UK accounts for **£8,167,128.18**, or **83.97%**, of overall Scenario C net transaction value.
- Country represents the country recorded on the transaction and should not automatically be interpreted as customer residence.

### BQ4 — Cancellation-associated transaction analysis

**Question:** What is the scale and financial impact of cancellation-associated transactions, and how do they affect the retailer's overall transaction performance?

- There are **9,251 retained C-prefixed records** across **3,836 distinct C-prefixed invoices**.
- C-prefixed records represent approximately **1.72%** of the retained analysis records.
- December 2011 has the largest negative quantity (**-83,569**) and negative transaction value (**-£205,089.27**) among the monthly periods.
- StockCodes `23843` and `23166` are prominent in the product-level cancellation-associated analysis.
- `M` represents a manual transaction code, not a conventional product, and is treated accordingly in interpretation.
- The corrected intersection of the top-ten negative-quantity and negative-value rankings contains five codes: `21108`, `23166`, `23843`, `85123A` and `M`.

## Important interpretation and limitations

- `line_value` is calculated as `Quantity * UnitPrice`. The resulting totals are described as **net transaction value**, not recognised revenue.
- C-prefixed invoice numbers are a useful proxy for cancellation-associated activity, but the prefix alone does not prove the commercial status of every record.
- Negative quantities can occur on non-C-prefixed invoices and may reflect different operational or accounting events.
- The dataset ends on 9 December 2011; December 2011 is incomplete.
- Missing CustomerID affects customer attribution. It does not mean those transactions should be removed from overall transaction or country analysis.
- Some StockCodes have multiple descriptions. Description text is therefore not treated as a stable product key.
- The analysis is based on the fields supplied in the dataset; it does not establish customer residence, recognised revenue, or the underlying reason for every adjustment.

## Validation

**Execution status: completed.** All nine reconciliation checks in `04_validation/final_reconciliation_checks.sql` were executed in MySQL Workbench and passed. The result exports for BQ1 (10 outputs), BQ2 (15 outputs), BQ3 (8 outputs) and BQ4 (5 outputs) were also reviewed against the agreed findings. No outstanding discrepancies requiring a rerun were identified.

The validation script contains checks for:

- Source, view and physical-table row counts.
- Duplicate classification and retained population.
- Scenario C customer-ID population.
- Scenario C financial reconciliation.
- Monthly-to-overall net transaction value.
- Product-analysis population.
- Customer and country totals.
- C-prefixed record and invoice counts.
- Key aggregate agreement between the view and physical analysis table.

Expected values in the validation script are reference points from the completed analysis. The checks passed in the project environment; users reproducing the work should run them against their own imported dataset and investigate any discrepancies.

## Project integrity and reproducibility

The original development SQL was preserved separately as a working record. This portfolio repository is a cleaned and organised presentation of the agreed analytical work. Exploratory queries are labelled where relevant; superseded definitions are not presented as authoritative. Any future reconstructed or newly developed analysis should be identified transparently rather than represented as an original executed query.
