# LaDe Delivery Intelligence Pipeline

### A batch data pipeline for last-mile delivery data. It takes a raw CSV of 472,419 delivery records across three cities, cleans, and validates it with PySpark, models it as a star schema in MySQL, analyses it with SQL, and checks its quality automatically.


## What This Project Is

A production-grade data pipeline built on real last-mile delivery data from Cainiao logistics (Alibaba). The pipeline transforms raw delivery records into analytical-ready canonical datasets demonstrating batch processing, distributed transformation, dimensional modeling, data quality automation, and pipeline orchestration.

## Stack: Python, pandas, PySpark (local mode), Parquet, MySQL

## Architecture

delivery_five_cities.csv
        │
   L1  Ingestion ----- MySQL raw_deliveries  +  raw_deliveries.parquet
        │
   L2  PySpark transform ---- lade_staging_clean/  (Parquet, partitioned by city)
        │
   L3  Star schema load ----- dim_city · dim_date · dim_courier · dim_depot · fact_deliveries
        │
   L4  Business metrics ----- 15 SQL analysis queries
   L5  Quality checks ------ data_quality_log
   L6  Orchestration ----- layer order and run summary

## Layers
### L1 - Raw Ingestion
1. reads the CSV with pandas and adds ingested_at and batch_id to every row.
2. Loads the data into MySQL raw_deliveries table in chuncks of 10,000 rows.
3. Saves the same data as raw_deliveries.paraquet for the Spark step.
4. Writes a run record(batch, start and end time, rows, status, duration) to pipeline_runs.

### L2 - PySpark transformation
1. Drops sign_lng and sig_lat, which are empty in the source.
2. Casts the coordinate columns to double and maps the Chinese city names to English.
3. Repllaces missing typecode bvaues with UNKNOWN.
4. Parses the MMDD data column and the MM-DD HH:MM:SS receipt and sign-off times into proper date and timestamp columns
5. Calculates delivery_duration_minutes (sign-off time minus receipt time).
6. Flags each record with is_valid : a record is invalid if itss duration is negative, over 1,440 minutes(24 hours) or missing.
7. Removes duplicate order_id values, keeping the earliest receipt.
8. Add metadata columns (processed_At, pipeline_version, source_file).
9. Writes the result as Paraquet partitioned by city.

Result:  465,384 of 472,419 records are valid (98.5%). The 7,035 invalid records all have a duration over 1,440 minutes. No duplicate order ids were found. The average valid delivery takes 132.76 minutes.

### L3 - Star schema
A fact table surrounded by four dimensions, loaded from the cleaned Paraquet.

| Table | Rows | Description |
|-------|------|-------------|
| raw_deliveries | 472,419 | Landing zone — source data preserved exactly as received |
| fact_deliveries | 472,419 | Central fact table — delivery events with surrogate keys |
| dim_city | 3 | City dimension — English and Chinese names, city size |
| dim_date | 15 | Date dimension — day, month, quarter, weekend flag |
| dim_courier | 1,870 | Courier dimension — unique delivery personnel |
| dim_depot | 134 | Depot dimension — dispatch warehouses with city mapping |

### L4 - Business metrics (SQL)
15 analysis queries on the star schema, including:
1. Average delivery duration and volume by city
2. Top 10 countries by average delivery time (with a minimum of 10 deliveries), using RANK()
3. Daily volume trend, day - over - day change with LAG(), and a running total with SUM() OVER
4. Peak delivery hours, and peak hour per city
5. Weekday vs Weekend patterns
6. Delivery-time buckets for SLA classification (express, standard, delayed, critical)
7. Busiest depots and the top city in each month
8. Courier workload per day
9. a data-quality summary by city
10. An EXPLAIN comparison before and after adding indexes

### L5 - Data quality framework
Automated checks run against the star schema, with each result stored in dat_quality_log  (check name, status, actual value, expected value, time):
1. Row count of the fact table
2. Valid record rate of at least 95%
3. No nul foregin keys
4. No duplicate order ids
5. No negative durations among valid records
6. All three cities present
7. Row counts of the four dimension tables

### L6 - Orchestration
Lays out the order of the pipeliine layers  (ingestion, PySpark, transform, star schema load, SQL analysis, quality checks ) and prints a run summary.

---

## File Structure

```
lade-delivery-pipeline/
├── L1_ingest.ipynb              # Raw ingestion — Python + pandas
├── L2_pyspark_transform.ipynb   # Distributed transformation — PySpark
├── L3_load_star_schema.ipynb    # Star schema loading — Python
├── L3_star_schema.sql           # CREATE TABLE statements
├── L4_business_metrics.sql      # Analytical SQL queries
├── L5_quality_check.ipynb       # Automated quality framework
├── L6_orchestrate.ipynb         # Pipeline orchestration
├── requirements.txt             # Python dependencies
└── README.md                    # This file

## Author

**Rishitha Gopagani**
[LinkedIn](https://linkedin.com/in/rishitha-gopagani-a184ab17a) | [GitHub](https://github.com/ri-data)
