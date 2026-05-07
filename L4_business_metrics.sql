-- Layer 4: Business Metrics — LaDe Delivery Intelligence
USE lade_pipeline;

-- Q1 Average delivery duration by city
SELECT 
    c.city_name,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration_minutes,
    COUNT(f.delivery_id) AS total_deliveries,
    ROUND(MIN(f.delivery_duration_minutes), 2) AS fastest_delivery,
    ROUND(MAX(f.delivery_duration_minutes), 2) AS slowest_delivery
FROM fact_deliveries f
JOIN dim_city c ON f.city_id = c.city_id
WHERE f.is_valid = 1
GROUP BY c.city_name
ORDER BY avg_duration_minutes ASC;

-- Q2 Top 10 most efficient couriers (fastest average delivery)
WITH courier_performance AS (
    SELECT 
        co.delivery_user_id,
        c.city_name,
        ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration,
        COUNT(f.delivery_id) AS total_deliveries
    FROM fact_deliveries f
    JOIN dim_courier co ON f.courier_id = co.courier_id
    JOIN dim_city c ON f.city_id = c.city_id
    WHERE f.is_valid = 1
    GROUP BY co.delivery_user_id, c.city_name
    HAVING COUNT(f.delivery_id) >= 10
)
SELECT *,
    RANK() OVER (ORDER BY avg_duration ASC) AS efficiency_rank
FROM courier_performance
ORDER BY efficiency_rank
LIMIT 10;

-- Q3 Daily delivery volume trend
SELECT 
    d.full_date,
    d.day_of_week,
    d.is_weekend,
    COUNT(f.delivery_id) AS total_deliveries,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration,
    SUM(CASE WHEN f.is_valid = 0 THEN 1 ELSE 0 END) AS invalid_count
FROM fact_deliveries f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.full_date, d.day_of_week, d.is_weekend
ORDER BY d.full_date;

-- Q4 Hourly delivery patterns — peak hours
SELECT 
    f.receipt_hour AS hour_of_day,
    COUNT(f.delivery_id) AS deliveries_started,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration
FROM fact_deliveries f
WHERE f.is_valid = 1
GROUP BY f.receipt_hour
ORDER BY deliveries_started DESC;

-- Q5 City performance comparison — full metrics
SELECT 
    c.city_name,
    COUNT(f.delivery_id) AS total_deliveries,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration,
    ROUND(MIN(f.delivery_duration_minutes), 2) AS min_duration,
    ROUND(MAX(f.delivery_duration_minutes), 2) AS max_duration,
    SUM(CASE WHEN f.is_valid = 1 THEN 1 ELSE 0 END) AS valid_deliveries,
    ROUND(SUM(CASE WHEN f.is_valid = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS valid_pct
FROM fact_deliveries f
JOIN dim_city c ON f.city_id = c.city_id
GROUP BY c.city_name
ORDER BY total_deliveries DESC;

-- Q6 Depot performance — top 10 busiest depots
SELECT 
    dep.from_dipan_id,
    c.city_name,
    COUNT(f.delivery_id) AS packages_dispatched,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration,
    RANK() OVER (ORDER BY COUNT(f.delivery_id) DESC) AS depot_rank
FROM fact_deliveries f
JOIN dim_depot dep ON f.depot_id = dep.depot_id
JOIN dim_city c ON f.city_id = c.city_id
WHERE f.is_valid = 1
GROUP BY dep.from_dipan_id, c.city_name
ORDER BY packages_dispatched DESC
LIMIT 10;

-- Q7 Weekend vs weekday delivery patterns
SELECT 
    CASE WHEN d.is_weekend = 1 THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(f.delivery_id) AS total_deliveries,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration,
    ROUND(AVG(f.receipt_hour), 1) AS avg_start_hour
FROM fact_deliveries f
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.is_valid = 1
GROUP BY d.is_weekend
ORDER BY day_type;

-- Q8 Running total of deliveries over time
SELECT 
    d.full_date,
    COUNT(f.delivery_id) AS daily_deliveries,
    SUM(COUNT(f.delivery_id)) OVER (ORDER BY d.full_date) AS cumulative_deliveries
FROM fact_deliveries f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.full_date
ORDER BY d.full_date;

-- Q9 Day over day delivery volume change using LAG
SELECT 
    d.full_date,
    COUNT(f.delivery_id) AS daily_deliveries,
    LAG(COUNT(f.delivery_id), 1) OVER (ORDER BY d.full_date) AS prev_day_deliveries,
    ROUND(
        (COUNT(f.delivery_id) - LAG(COUNT(f.delivery_id), 1) OVER (ORDER BY d.full_date)) * 100.0
        / LAG(COUNT(f.delivery_id), 1) OVER (ORDER BY d.full_date)
    , 2) AS day_over_day_pct
FROM fact_deliveries f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.full_date
ORDER BY d.full_date;

-- Q10 Delivery duration buckets — SLA classification
SELECT 
    CASE 
        WHEN f.delivery_duration_minutes <= 60 THEN 'Express (under 1 hour)'
        WHEN f.delivery_duration_minutes <= 120 THEN 'Standard (1-2 hours)'
        WHEN f.delivery_duration_minutes <= 240 THEN 'Delayed (2-4 hours)'
        ELSE 'Critical (over 4 hours)'
    END AS sla_category,
    COUNT(f.delivery_id) AS delivery_count,
    ROUND(COUNT(f.delivery_id) * 100.0 / SUM(COUNT(f.delivery_id)) OVER (), 2) AS percentage
FROM fact_deliveries f
WHERE f.is_valid = 1
GROUP BY sla_category
ORDER BY delivery_count DESC;

-- Q11 Top city each month using RANK
WITH monthly_city AS (
    SELECT 
        d.month_name,
        d.month_number,
        c.city_name,
        COUNT(f.delivery_id) AS deliveries,
        RANK() OVER (PARTITION BY d.month_number ORDER BY COUNT(f.delivery_id) DESC) AS city_rank
    FROM fact_deliveries f
    JOIN dim_date d ON f.date_id = d.date_id
    JOIN dim_city c ON f.city_id = c.city_id
    GROUP BY d.month_name, d.month_number, c.city_name
)
SELECT * FROM monthly_city
WHERE city_rank = 1
ORDER BY month_number;

-- Q12 Courier workload per day
SELECT 
    co.delivery_user_id,
    c.city_name,
    d.full_date,
    COUNT(f.delivery_id) AS deliveries_that_day,
    ROUND(AVG(f.delivery_duration_minutes), 2) AS avg_duration_that_day
FROM fact_deliveries f
JOIN dim_courier co ON f.courier_id = co.courier_id
JOIN dim_city c ON f.city_id = c.city_id
JOIN dim_date d ON f.date_id = d.date_id
WHERE f.is_valid = 1
GROUP BY co.delivery_user_id, c.city_name, d.full_date
ORDER BY deliveries_that_day DESC
LIMIT 10;

-- Q13 Data quality summary
SELECT 
    c.city_name,
    COUNT(f.delivery_id) AS total_records,
    SUM(CASE WHEN f.is_valid = 1 THEN 1 ELSE 0 END) AS valid_records,
    SUM(CASE WHEN f.is_valid = 0 THEN 1 ELSE 0 END) AS invalid_records,
    ROUND(SUM(CASE WHEN f.is_valid = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS valid_pct,
    ROUND(AVG(CASE WHEN f.is_valid = 1 THEN f.delivery_duration_minutes END), 2) AS avg_valid_duration
FROM fact_deliveries f
JOIN dim_city c ON f.city_id = c.city_id
GROUP BY c.city_name
ORDER BY total_records DESC;

-- Q14 EXPLAIN query optimisation — before index
EXPLAIN SELECT * FROM fact_deliveries WHERE city_id = 1;

-- Add index
CREATE INDEX idx_city ON fact_deliveries(city_id);
CREATE INDEX idx_date ON fact_deliveries(date_id);
CREATE INDEX idx_courier ON fact_deliveries(courier_id);
CREATE INDEX idx_valid ON fact_deliveries(is_valid);

-- EXPLAIN after index
EXPLAIN SELECT * FROM fact_deliveries WHERE city_id = 1;

-- Q15 Peak hour by city
SELECT 
    c.city_name,
    f.receipt_hour,
    COUNT(f.delivery_id) AS deliveries,
    RANK() OVER (PARTITION BY c.city_name ORDER BY COUNT(f.delivery_id) DESC) AS hour_rank
FROM fact_deliveries f
JOIN dim_city c ON f.city_id = c.city_id
WHERE f.is_valid = 1
GROUP BY c.city_name, f.receipt_hour
ORDER BY c.city_name, hour_rank
LIMIT 15;