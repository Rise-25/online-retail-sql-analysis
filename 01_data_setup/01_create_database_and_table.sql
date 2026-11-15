/*
Project: Online Retail Sales Analysis
Database: online_retail_analysis

Purpose:
Create the database and original source table used for the
Online Retail analysis.
*/

CREATE DATABASE IF NOT EXISTS online_retail_analysis;

USE online_retail_analysis;

CREATE TABLE IF NOT EXISTS retail_transactions (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate DATETIME,
    UnitPrice DECIMAL(10,2),
    CustomerID VARCHAR(20),
    Country VARCHAR(100)
);

-- Confirm that the source table exists.
SHOW TABLES;

-- Review the source table structure.
DESCRIBE retail_transactions;
