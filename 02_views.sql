-- ==========================================
-- Vayu Track: Analytical Views (02_views.sql)
-- ==========================================

-- 1. Master Analytical View (Joins AQI + Weather + Cities)
CREATE OR REPLACE VIEW vw_vayu_master AS
SELECT
    aq.date,
    EXTRACT(YEAR FROM aq.date)::INT  AS year,
    EXTRACT(MONTH FROM aq.date)::INT AS month,
    TO_CHAR(aq.date, 'Mon')          AS month_name,
    CASE
        WHEN EXTRACT(MONTH FROM aq.date) IN (12, 1, 2) THEN 'Winter'
        WHEN EXTRACT(MONTH FROM aq.date) IN (3, 4, 5)  THEN 'Summer'
        WHEN EXTRACT(MONTH FROM aq.date) IN (6, 7, 8, 9) THEN 'Monsoon'
        ELSE 'Post-Monsoon'
    END AS season,
    c.city,
    c.state,
    c.region,
    c.latitude,
    c.longitude,
    c.elevation_m,
    aq.india_aqi,
    aq.india_aqi_category,
    aq.dominant_pollutant,
    aq.pm2_5_mean,
    aq.pm2_5_max,
    aq.pm10_mean,
    aq.no2_mean,
    aq.so2_mean,
    aq.o3_8h_max,
    aq.co_8h_max,
    w.temperature_2m_mean,
    w.temperature_2m_max,
    w.temperature_2m_min,
    w.precipitation_sum,
    w.relative_humidity_2m_mean,
    w.wind_speed_10m_max
FROM air_quality_daily aq
INNER JOIN weather_daily w ON aq.city = w.city AND aq.date = w.date
INNER JOIN cities c        ON aq.city = c.city;

-- 2. City-Level KPI Summary View (Great for Power BI Map & Cards)
CREATE OR REPLACE VIEW vw_city_summary AS
SELECT
    city,
    state,
    region,
    latitude,
    longitude,
    COUNT(*) AS total_days,
    ROUND(AVG(india_aqi), 1) AS avg_india_aqi,
    ROUND(AVG(pm2_5_mean), 1) AS avg_pm2_5,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE india_aqi_category IN ('Good', 'Satisfactory')) / COUNT(*),
        1
    ) AS pct_clean_days,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE india_aqi_category IN ('Poor', 'Very Poor', 'Severe')) / COUNT(*),
        1
    ) AS pct_unhealthy_days
FROM vw_vayu_master
GROUP BY city, state, region, latitude, longitude;