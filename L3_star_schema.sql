CREATE DATABASE IF NOT EXISTS lade_pipeline;
-- USE lade_pipeline;
SELECT * FROM pipeline_runs;
USE lade_pipeline;

CREATE TABLE dim_date (
    date_id INT AUTO_INCREMENT PRIMARY KEY,
    full_date DATE NOT NULL,
    day_of_week VARCHAR(10),
    day_number INT,
    month_number INT,
    month_name VARCHAR(10),
    week_number INT,
    quarter INT,
    is_weekend BOOLEAN
);
CREATE TABLE dim_courier (
    courier_id INT AUTO_INCREMENT PRIMARY KEY,
    delivery_user_id VARCHAR(50) NOT NULL,
    city VARCHAR(50)
);

CREATE TABLE dim_city (
    city_id INT AUTO_INCREMENT PRIMARY KEY,
    city_name VARCHAR(50) NOT NULL,
    city_name_chinese VARCHAR(50),
    city_size VARCHAR(10)
);

CREATE TABLE dim_depot (
    depot_id INT AUTO_INCREMENT PRIMARY KEY,
    from_dipan_id VARCHAR(50) NOT NULL,
    city_id INT,
    FOREIGN KEY (city_id) REFERENCES dim_city(city_id)
);


CREATE TABLE fact_deliveries (
    delivery_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50) NOT NULL,
    date_id INT,
    courier_id INT,
    city_id INT,
    depot_id INT,
    delivery_duration_minutes DOUBLE,
    receipt_hour INT,
    sign_hour INT,
    is_valid BOOLEAN,
    processed_at DATETIME,
    batch_id VARCHAR(20),
    FOREIGN KEY (date_id) REFERENCES dim_date(date_id),
    FOREIGN KEY (courier_id) REFERENCES dim_courier(courier_id),
    FOREIGN KEY (city_id) REFERENCES dim_city(city_id),
    FOREIGN KEY (depot_id) REFERENCES dim_depot(depot_id)
);

SELECT 
    f.delivery_duration_minutes,  -- from fact table
    c.city_name,                  -- from dim_city
    co.delivery_user_id,          -- from dim_courier
    d.day_of_week,                -- from dim_date
    f.is_valid                    -- from fact table
FROM fact_deliveries f            -- f is shortcut for fact_deliveries
JOIN dim_city c ON f.city_id = c.city_id        -- connect city
JOIN dim_courier co ON f.courier_id = co.courier_id  -- connect courier
JOIN dim_date d ON f.date_id = d.date_id        -- connect date
LIMIT 5;                          -- show only 5 rows