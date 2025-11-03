!Open in GitHub Codespaces
# PRACTICE_PROJECT1_sql
SQL Server project: messy e-commerce dataset cleaned and analyzed using T-SQL.
# SQL Data Cleaning & Analysis Project

## Overview
This project demonstrates cleaning and analyzing a messy e-commerce dataset using **Microsoft SQL Server (T-SQL)**.  
It covers:
- Handling mixed date formats
- Normalizing text fields
- Converting currency and percentages
- Removing duplicates and invalid rows
- Computing KPIs and revenue metrics

## Files
- `raw_orders.sql` – Creates raw table and inserts messy sample data
- `clean_orders.sql` – Cleans and transforms data into structured format
- `analysis_views.sql` – Creates views for KPIs and trend analysis

## How to Run
1. Open SSMS or Azure Data Studio.
2. Execute scripts in this order:
   - `raw_orders.sql`
   - `clean_orders.sql`
   - `analysis_views.sql`
3. Quick check:
```sql
SELECT * FROM demo.v_kpi;
SELECT * FROM demo.v_revenue_by_month_category;
SELECT * FROM demo.v_top_states;

## Tech Stack
- Microsoft SQL Server
- T-SQL (Transact-SQL)
- SSMS / Azure Data Studio
