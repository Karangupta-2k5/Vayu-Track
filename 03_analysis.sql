-- ==========================================
-- Vayu Track: Core Analysis (03_analysis.sql)
-- ==========================================

-- 1. Top 10 Most Polluted vs. Cleanest Cities (Overall)
SELECT city, state, region, avg_india_aqi, avg_pm2_5, pct_clean_days, pct_unhealthy_days
FROM vw_city_summary
ORDER BY avg_india_aqi DESC
LIMIT 10;

-- (Change DESC to ASC to see the 10 cleanest cities)


-- 2. Regional & Seasonal AQI Breakdown
SELECT
    region,
    season,
    ROUND(AVG(india_aqi), 1)  AS avg_aqi,
    ROUND(AVG(pm2_5_mean), 1) AS avg_pm2_5,
    MAX(india_aqi)            AS peak_aqi
FROM vw_vayu_master
GROUP BY region, season
ORDER BY region, avg_aqi DESC;


-- 3. Dominant Pollutant Share by Region
SELECT
    region,
    dominant_pollutant,
    COUNT(*) AS days_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY region), 1) AS pct_of_region_days
FROM vw_vayu_master
GROUP BY region, dominant_pollutant
ORDER BY region, days_count DESC;


-- 4. Weather vs. PM2.5 Correlation by Region
-- Negative value = higher wind/rain reduces PM2.5
SELECT
    region,
    ROUND(CORR(pm2_5_mean, wind_speed_10m_max)::numeric, 3)        AS corr_wind_pm25,
    ROUND(CORR(pm2_5_mean, precipitation_sum)::numeric, 3)         AS corr_rain_pm25,
    ROUND(CORR(pm2_5_mean, relative_humidity_2m_mean)::numeric, 3) AS corr_humidity_pm25,
    ROUND(CORR(pm2_5_mean, temperature_2m_min)::numeric, 3)        AS corr_min_temp_pm25
FROM vw_vayu_master
GROUP BY region
ORDER BY corr_wind_pm25 ASC;


-- 5. Year-over-Year (YoY) AQI Trend with 7-Day Rolling Average Sample (Delhi)
SELECT
    date,
    india_aqi,
    pm2_5_mean,
    ROUND(AVG(pm2_5_mean) OVER (
        PARTITION BY city
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ), 1) AS pm25_7day_rolling_avg
FROM vw_vayu_master
WHERE city = 'Delhi'
  AND year >= 2025
ORDER BY date DESC
LIMIT 30;