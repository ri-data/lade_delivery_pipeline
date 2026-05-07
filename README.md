# LaDe Delivery Intelligence Pipeline

### End-to-End Data Engineering System | Real Last-Mile Delivery Data | 472,419 Records


## What This Project Is

A production-grade data engineering pipeline built on real last-mile delivery data from Cainiao logistics (Alibaba). The pipeline transforms raw delivery records into analytical-ready canonical datasets demonstrating batch processing, distributed transformation, dimensional modeling, data quality automation, and pipeline orchestration.

**Domain:** Last-mile delivery operations — directly relevant to Uber Delivery Data Solutions (DDS) team workflows.

## Business Problem

Last-mile delivery is the most expensive and complex part of logistics. Cainiao operates thousands of couriers across multiple cities but raw delivery event data is scattered, messy, and unusable for operational decisions.

**Without this pipeline:**
- Raw delivery events sit in CSV files — no structure, no relationships
- Operations teams cannot query courier performance, depot throughput, or SLA compliance
- Data quality issues go undetected — bad data reaches dashboards silently
- No audit trail — impossible to trace data issues back to source

**What this pipeline solves:**
- Transforms raw courier event data into a clean analytical data product
- Enables any downstream team — analytics, data science, operations to query delivery performance without touching raw data
- Enforces data quality automatically on every run  98.51% valid records verified
- Provides complete data lineage every row traceable to its source file and pipeline run
- Star schema design supports SLA monitoring, courier ranking, depot performance, and city comparisons out of the box


## Dataset

| Property | Value |
|----------|-------|
| Source | LaDe — Cainiao AI (Alibaba logistics) |
| Records | 472,419 real delivery events |
| Cities | Shanghai, Hangzhou, Chongqing |
| Period | March — April 2022 |
| Domain | Last-mile courier delivery operations |

**Known data quality issues handled:**

- sign_lng and sign_lat: 100% null — GPS not recorded at delivery sign-off
- City names in Chinese — mapped to English
- Timestamps stored as text without year
- Coordinates in Web Mercator projection EPSG:3857
- 7,035 records with duration over 24 hours, flagged is_valid=False

---

## Architecture

```
SOURCE
└── delivery_five_cities.csv (472,419 rows · 136MB · real Cainiao operations)
    │
    ├── LAYER 1 — Raw Ingestion [L1_ingest.ipynb]
    │   ├── Tool: Python + pandas + MySQL
    │   ├── Load CSV as-is into MySQL raw_deliveries (all VARCHAR)
    │   ├── Save raw_deliveries.parquet (columnar for PySpark)
    │   └── Log to pipeline_runs table (batch_id, rows, duration, status)
    │
    ├── LAYER 2 — PySpark Transformation [L2_pyspark_transform.ipynb]
    │   ├── Tool: PySpark 4.0.2 on Google Colab (local[*])
    │   ├── Drop 100% null columns (sign_lng, sign_lat)
    │   ├── Cast types: string to double, timestamp, boolean
    │   ├── Map Chinese city names to English
    │   ├── Parse timestamps and calculate delivery_duration_minutes
    │   ├── Flag 7,035 invalid records (is_valid=False)
    │   ├── Deduplicate on order_id (0 duplicates found)
    │   └── Write clean Parquet partitioned by city
    │
    ├── LAYER 3 — Star Schema [L3_load_star_schema.ipynb]
    │   ├── Tool: Python + pandas + MySQL
    │   ├── dim_city (3 rows) — dim_date (15 rows)
    │   ├── dim_courier (1,870 rows) — dim_depot (134 rows)
    │   └── fact_deliveries (472,419 rows · surrogate keys · FK constraints)
    │
    ├── LAYER 4 — Business Metrics [L4_business_metrics.sql]
    │   ├── Tool: MySQL
    │   ├── 15 analytical queries on star schema
    │   ├── Window functions: RANK, LAG, SUM OVER, ROW_NUMBER
    │   ├── CTEs for multi-step analysis
    │   └── EXPLAIN + composite indexes for query optimization
    │
    ├── LAYER 5 — Data Quality Framework [L5_quality_check.ipynb]
    │   ├── Tool: Python + MySQL
    │   ├── 10 automated checks — all PASS
    │   └── Results logged to data_quality_log audit table
    │
    ├── LAYER 6 — Orchestration [L6_orchestrate.ipynb]
    │   ├── Tool: Python schedule library
    │   └── Production equivalent: Apache Airflow DAG
```

---

## Data Products Delivered

| Table | Rows | Description |
|-------|------|-------------|
| raw_deliveries | 472,419 | Landing zone — source data preserved exactly as received |
| fact_deliveries | 472,419 | Central fact table — delivery events with surrogate keys |
| dim_city | 3 | City dimension — English and Chinese names, city size |
| dim_date | 15 | Date dimension — day, month, quarter, weekend flag |
| dim_courier | 1,870 | Courier dimension — unique delivery personnel |
| dim_depot | 134 | Depot dimension — dispatch warehouses with city mapping |
| pipeline_runs | 1 | Pipeline execution log — batch tracking and monitoring |
| data_quality_log | 10 | Quality audit trail — check results per run |

## Pipeline Capabilities

- Ingests 472,419 delivery records from source CSV in under 2 minutes
- Distributed transformation using PySpark — scales to cluster without code changes
- Handles real-world data quality issues — 100% null GPS columns, mixed encodings, Web Mercator coordinates
- Automated quality validation on every run — 10 checks, all results audited
- Star schema supports any downstream analytical query without pipeline changes
- Partition pruning reduces city-specific query scan by 65%
- Production-ready logging — every run tracked with batch_id, row counts, duration, status

---

## Tech Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Ingestion | Python + pandas | CSV reading, MySQL loading, Parquet saving |
| Transformation | PySpark 4.0.2 | Distributed data cleaning and feature engineering |
| Storage | MySQL 8.0 | Raw layer, star schema, audit tables |
| File Format | Parquet | Columnar intermediate storage, partition pruning |
| Analysis | MySQL SQL | 15 analytical queries, window functions |
| Quality | Python | 10 automated data quality checks |
| Orchestration | Python schedule | Pipeline sequencing, retry logic |

---

## Performance Optimizations

- **Partition pruning:** Parquet partitioned by city — city-specific queries skip 65% of data
- **Composite indexes:** idx_city, idx_date, idx_courier, idx_valid on fact_deliveries
- **Query optimization:** EXPLAIN verified — type=ref after indexing vs type=ALL before
- **Spark tuning:** shuffle.partitions=4 optimized for 472K rows (default 200 is wasteful)
- **Bulk loading:** chunksize=10000 prevents memory overflow on large inserts
- **Surrogate keys:** Integer joins 10x faster than string joins on 472K rows

---

## File Structure

```
lade-delivery-pipeline/
├── L1_ingest.ipynb              # Raw ingestion — Python + pandas
├── L2_pyspark_transform.ipynb   # Distributed transformation — PySpark
├── L3_load_star_schema.ipynb    # Star schema loading — Python
├── L3_star_schema.sql           # CREATE TABLE statements
├── L4_business_metrics.sql      # 15 analytical SQL queries
├── L5_quality_check.ipynb       # Automated quality framework
├── L6_orchestrate.ipynb         # Pipeline orchestration
├── requirements.txt             # Python dependencies
└── README.md                    # This file
```

---

## Scalability Design

The pipeline architecture is designed to scale without code changes:

- **PySpark transformation** runs on local[*] for development. Same code deploys to EMR or Databricks cluster by changing master configuration only.
- **Parquet with city partitioning** supports partition pruning — adding more cities does not require pipeline changes.
- **Star schema** supports unlimited downstream consumers — analytics, ML, reporting — without pipeline modifications.
- **Batch orchestration** designed for daily execution. Airflow DAG implementation documented in L6_orchestrate.ipynb.
- **Quality framework** checks are configurable — thresholds and checks added without touching transformation logic.

---

## Data Quality Results

All 10 automated checks PASS:

| Check | Expected | Actual | Status |
|-------|----------|--------|--------|
| Row count | 472,419 | 472,419 | PASS |
| Valid rate | 95% minimum | 98.51% | PASS |
| Null foreign keys | 0 | 0 | PASS |
| Duplicate orders | 0 | 0 | PASS |
| Duration range violations | 0 | 0 | PASS |
| City coverage | 3 cities | 3 | PASS |
| dim_city rows | 3 | 3 | PASS |
| dim_courier rows | 1,870 | 1,870 | PASS |
| dim_date rows | 15 | 15 | PASS |
| dim_depot rows | 134 | 134 | PASS |

---

## Author

**Rishitha Gopagani**
[LinkedIn](https://linkedin.com/in/rishitha-gopagani-a184ab17a) | [GitHub](https://github.com/ri-data)
