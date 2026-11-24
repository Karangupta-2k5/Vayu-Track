-- ==========================================================================
-- Vayu Track: Analysis Question Bank (04_analysis_queries.sql)
-- 29 analytical questions over vw_vayu_master / base tables.
-- Each block starts with a "-- @Q<n> | <analysis type> | <title>" marker.
-- Notes:
--   * AQ data spans 2022-08-05 .. 2026-10-30; weather spans 2020-01-01 .. 2026-10-30.
--   * india_aqi is dominated by O3 (~90% of days), so particulate questions use
--     pm2_5_mean and the PM-only index (india_aqi_pm / india_aqi_pm_category).
--   * 2022 and 2026 are partial years; YoY questions are like-for-like or use
--     full years only (2023-2025).
-- ==========================================================================

-- @Q1 | Data profiling | How big is the dataset and what period does each table cover?
SELECT 'cities' AS table_name, COUNT(*) AS row_count, NULL::date AS first_date, NULL::date AS last_date, COUNT(*) AS distinct_cities FROM cities
UNION ALL
SELECT 'weather_daily', COUNT(*), MIN(date), MAX(date), COUNT(DISTINCT city) FROM weather_daily
UNION ALL
SELECT 'air_quality_daily', COUNT(*), MIN(date), MAX(date), COUNT(DISTINCT city) FROM air_quality_daily;

-- @Q2 | Data quality | Are there missing days, nulls or logically impossible values in the raw data?
SELECT 'air_quality_daily' AS table_name,
       COUNT(*) AS actual_rows,
       (SELECT COUNT(*) FROM cities) * (MAX(date) - MIN(date) + 1) AS expected_rows,
       COUNT(*) FILTER (WHERE pm2_5_mean IS NULL OR india_aqi IS NULL OR india_aqi_category IS NULL) AS null_key_metrics,
       COUNT(*) FILTER (WHERE pm2_5_mean > pm10_mean OR pm2_5_mean < 0 OR hours_available < 24) AS rule_violations
FROM air_quality_daily
UNION ALL
SELECT 'weather_daily', COUNT(*),
       (SELECT COUNT(*) FROM cities) * (MAX(date) - MIN(date) + 1),
       COUNT(*) FILTER (WHERE temperature_2m_mean IS NULL OR precipitation_sum IS NULL OR wind_speed_10m_max IS NULL),
       COUNT(*) FILTER (WHERE temperature_2m_max < temperature_2m_min OR relative_humidity_2m_mean > 100 OR precipitation_sum < 0)
FROM weather_daily;

-- @Q3 | Ranking | Which 10 cities have the highest average PM2.5?
SELECT RANK() OVER (ORDER BY AVG(aq.pm2_5_mean) DESC) AS rank,
       c.city, c.state, c.region,
       ROUND(AVG(aq.pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(aq.pm10_mean), 1)  AS avg_pm10,
       ROUND(100.0 * COUNT(*) FILTER (WHERE aq.india_aqi_pm_category IN ('Poor','Very Poor','Severe')) / COUNT(*), 1) AS pct_days_poor_or_worse
FROM air_quality_daily aq JOIN cities c USING (city)
GROUP BY c.city, c.state, c.region
ORDER BY avg_pm25 DESC
LIMIT 10;

-- @Q4 | Ranking | Which 10 cities have the cleanest air (lowest average PM2.5)?
SELECT RANK() OVER (ORDER BY AVG(aq.pm2_5_mean) ASC) AS rank,
       c.city, c.state, c.region,
       ROUND(AVG(aq.pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(aq.pm10_mean), 1)  AS avg_pm10,
       ROUND(100.0 * COUNT(*) FILTER (WHERE aq.india_aqi_pm_category IN ('Good','Satisfactory')) / COUNT(*), 1) AS pct_days_good_or_satisfactory
FROM air_quality_daily aq JOIN cities c USING (city)
GROUP BY c.city, c.state, c.region
ORDER BY avg_pm25 ASC
LIMIT 10;

-- @Q5 | Distribution | How are days split across CPCB categories, for the overall AQI vs the PM-only AQI?
WITH overall AS (
  SELECT india_aqi_category AS category, COUNT(*) AS days FROM air_quality_daily GROUP BY 1
), pm AS (
  SELECT india_aqi_pm_category AS category, COUNT(*) AS days FROM air_quality_daily GROUP BY 1
)
SELECT COALESCE(o.category, p.category) AS category,
       o.days AS days_overall_aqi,
       ROUND(100.0 * o.days / SUM(o.days) OVER (), 1) AS pct_overall_aqi,
       p.days AS days_pm_only_aqi,
       ROUND(100.0 * p.days / SUM(p.days) OVER (), 1) AS pct_pm_only_aqi
FROM overall o FULL OUTER JOIN pm p ON o.category = p.category
ORDER BY CASE COALESCE(o.category, p.category)
           WHEN 'Good' THEN 1 WHEN 'Satisfactory' THEN 2 WHEN 'Moderate' THEN 3
           WHEN 'Poor' THEN 4 WHEN 'Very Poor' THEN 5 ELSE 6 END;

-- @Q6 | Composition | Which pollutant most often drives the AQI, and how high is the AQI when it does?
SELECT dominant_pollutant,
       COUNT(*) AS days,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_days,
       ROUND(AVG(india_aqi), 1) AS avg_aqi_when_dominant,
       MAX(india_aqi) AS max_aqi
FROM air_quality_daily
GROUP BY dominant_pollutant
ORDER BY days DESC;

-- @Q7 | Comparative | How do the six regions compare across all pollutants?
SELECT region,
       COUNT(DISTINCT city) AS cities,
       ROUND(AVG(pm2_5_mean), 1) AS pm25,
       ROUND(AVG(pm10_mean), 1)  AS pm10,
       ROUND(AVG(no2_mean), 1)   AS no2,
       ROUND(AVG(so2_mean), 1)   AS so2,
       ROUND(AVG(o3_8h_max), 1)  AS o3_8h,
       ROUND(AVG(co_8h_max), 0)  AS co_8h
FROM vw_vayu_master
GROUP BY region
ORDER BY pm25 DESC;

-- @Q8 | Seasonal | What is the average PM2.5 in each season, by region?
SELECT region,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE season = 'Winter'), 1)       AS winter,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE season = 'Summer'), 1)       AS summer,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE season = 'Monsoon'), 1)      AS monsoon,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE season = 'Post-Monsoon'), 1) AS post_monsoon,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE season = 'Winter')
           / NULLIF(AVG(pm2_5_mean) FILTER (WHERE season = 'Monsoon'), 0), 2) AS winter_to_monsoon_ratio
FROM vw_vayu_master
GROUP BY region
ORDER BY winter DESC;

-- @Q9 | Seasonal | What does the national monthly pollution cycle look like?
SELECT month, month_name,
       ROUND(AVG(pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(pm10_mean), 1)  AS avg_pm10,
       ROUND(AVG(pm2_5_mean) / AVG(AVG(pm2_5_mean)) OVER (), 2) AS index_vs_annual_avg,
       ROUND(AVG(precipitation_sum), 1)    AS avg_rain_mm,
       ROUND(AVG(temperature_2m_mean), 1)  AS avg_temp_c
FROM vw_vayu_master
GROUP BY month, month_name
ORDER BY month;

-- @Q10 | Trend | Is air getting cleaner? Like-for-like comparison of 1 Jan - 30 Oct each year.
SELECT year,
       COUNT(*) AS city_days,
       ROUND(AVG(pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(pm10_mean), 1)  AS avg_pm10,
       ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 60) / COUNT(*), 1) AS pct_days_above_naaqs_60,
       ROUND(100.0 * (AVG(pm2_5_mean) / LAG(AVG(pm2_5_mean)) OVER (ORDER BY year) - 1), 1) AS pct_change_vs_prev_year
FROM vw_vayu_master
WHERE (month < 10 OR (month = 10 AND EXTRACT(DAY FROM date) <= 30)) AND year >= 2023
GROUP BY year
ORDER BY year;

-- @Q11 | Trend / delta | Which cities improved or worsened the most between full-year 2023 and 2025?
WITH yr AS (
  SELECT city,
         AVG(pm2_5_mean) FILTER (WHERE year = 2023) AS pm_2023,
         AVG(pm2_5_mean) FILTER (WHERE year = 2025) AS pm_2025
  FROM vw_vayu_master GROUP BY city
), d AS (
  SELECT city, ROUND(pm_2023, 1) AS pm25_2023, ROUND(pm_2025, 1) AS pm25_2025,
         ROUND(pm_2025 - pm_2023, 1) AS abs_change,
         ROUND(100.0 * (pm_2025 - pm_2023) / pm_2023, 1) AS pct_change,
         ROW_NUMBER() OVER (ORDER BY pm_2025 - pm_2023 ASC)  AS rn_improved,
         ROW_NUMBER() OVER (ORDER BY pm_2025 - pm_2023 DESC) AS rn_worsened
  FROM yr
)
SELECT 'Most improved' AS group_label, city, pm25_2023, pm25_2025, abs_change, pct_change FROM d WHERE rn_improved <= 8
UNION ALL
SELECT 'Most worsened', city, pm25_2023, pm25_2025, abs_change, pct_change FROM d WHERE rn_worsened <= 8
ORDER BY group_label DESC, abs_change;

-- @Q12 | Seasonal spike | Which cities see the sharpest Oct-Nov jump over their Aug-Sep baseline?
SELECT city, region,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE month IN (8, 9)), 1)   AS aug_sep_pm25,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE month IN (10, 11)), 1) AS oct_nov_pm25,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE month IN (10, 11))
           / AVG(pm2_5_mean) FILTER (WHERE month IN (8, 9)), 2)   AS jump_ratio
FROM vw_vayu_master
GROUP BY city, region
ORDER BY jump_ratio DESC
LIMIT 10;

-- @Q13 | Extremes | What are the 15 worst city-days on record?
SELECT aq.date, aq.city, c.region,
       aq.pm2_5_mean, aq.pm10_mean, aq.india_aqi_pm, aq.india_aqi_pm_category,
       w.wind_speed_10m_max AS wind_kmh, w.precipitation_sum AS rain_mm
FROM air_quality_daily aq
JOIN cities c USING (city)
JOIN weather_daily w USING (city, date)
ORDER BY aq.pm2_5_mean DESC
LIMIT 15;

-- @Q14 | Extremes | Which cities spend the most days in the 'Very Poor' or 'Severe' PM bands?
SELECT city,
       COUNT(*) FILTER (WHERE india_aqi_pm_category = 'Very Poor') AS very_poor_days,
       COUNT(*) FILTER (WHERE india_aqi_pm_category = 'Severe')    AS severe_days,
       COUNT(*) FILTER (WHERE india_aqi_pm_category IN ('Very Poor','Severe')) AS total_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE india_aqi_pm_category IN ('Very Poor','Severe')) / COUNT(*), 1) AS pct_of_days,
       MODE() WITHIN GROUP (ORDER BY EXTRACT(MONTH FROM date)) FILTER (WHERE india_aqi_pm_category IN ('Very Poor','Severe')) AS most_common_month
FROM air_quality_daily
GROUP BY city
HAVING COUNT(*) FILTER (WHERE india_aqi_pm_category IN ('Very Poor','Severe')) > 0
ORDER BY total_days DESC
LIMIT 10;

-- @Q15 | Gaps and islands | What is the longest unbroken run of 'Poor or worse' (PM-only) days per city?
WITH flagged AS (
  SELECT city, date FROM air_quality_daily WHERE india_aqi_pm_category IN ('Poor','Very Poor','Severe')
), grp AS (
  SELECT city, date, date - (ROW_NUMBER() OVER (PARTITION BY city ORDER BY date))::int AS island FROM flagged
), streaks AS (
  SELECT city, MIN(date) AS start_date, MAX(date) AS end_date, COUNT(*) AS streak_days FROM grp GROUP BY city, island
), ranked AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY city ORDER BY streak_days DESC, start_date) AS rn FROM streaks
)
SELECT city, start_date, end_date, streak_days FROM ranked WHERE rn = 1 ORDER BY streak_days DESC LIMIT 10;

-- @Q16 | Window function | When did Delhi's 7-day rolling PM2.5 peak each year?
WITH r AS (
  SELECT date, EXTRACT(YEAR FROM date)::int AS year, pm2_5_mean,
         ROUND(AVG(pm2_5_mean) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 1) AS rolling_7d,
         ROW_NUMBER() OVER (ORDER BY date) AS n
  FROM air_quality_daily WHERE city = 'Delhi'
), p AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY year ORDER BY rolling_7d DESC) AS rk FROM r WHERE n >= 7
)
SELECT year, date AS peak_window_end, rolling_7d AS peak_7d_avg_pm25, pm2_5_mean AS pm25_that_day
FROM p WHERE rk = 1 ORDER BY year;

-- @Q17 | Correlation | How strongly do wind, rain, humidity and night temperature correlate with PM2.5?
SELECT COALESCE(region, 'All India') AS region,
       ROUND(CORR(pm2_5_mean, wind_speed_10m_max)::numeric, 3)        AS corr_wind,
       ROUND(CORR(pm2_5_mean, precipitation_sum)::numeric, 3)         AS corr_rain,
       ROUND(CORR(pm2_5_mean, relative_humidity_2m_mean)::numeric, 3) AS corr_humidity,
       ROUND(CORR(pm2_5_mean, temperature_2m_min)::numeric, 3)        AS corr_min_temp,
       COUNT(*) AS n
FROM vw_vayu_master
GROUP BY ROLLUP (region)
ORDER BY region NULLS LAST;

-- @Q18 | Segmentation | How much does rainfall intensity reduce PM2.5?
SELECT CASE WHEN precipitation_sum = 0 THEN '1. Dry (0 mm)'
            WHEN precipitation_sum <= 2.5 THEN '2. Light (0-2.5 mm)'
            WHEN precipitation_sum <= 10  THEN '3. Moderate (2.5-10 mm)'
            WHEN precipitation_sum <= 30  THEN '4. Heavy (10-30 mm)'
            ELSE '5. Very heavy (>30 mm)' END AS rain_band,
       COUNT(*) AS city_days,
       ROUND(AVG(pm2_5_mean), 1) AS avg_pm25,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY pm2_5_mean))::numeric, 1) AS median_pm25
FROM vw_vayu_master
GROUP BY 1
ORDER BY 1;

-- @Q19 | Segmentation | How does the daily maximum wind speed relate to PM2.5 levels?
SELECT CASE WHEN wind_speed_10m_max < 10 THEN '1. Calm (<10 km/h)'
            WHEN wind_speed_10m_max < 20 THEN '2. Light (10-20)'
            WHEN wind_speed_10m_max < 30 THEN '3. Breezy (20-30)'
            ELSE '4. Windy (30+)' END AS wind_band,
       COUNT(*) AS city_days,
       ROUND(AVG(pm2_5_mean), 1) AS avg_pm25,
       ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 60) / COUNT(*), 1) AS pct_days_above_60
FROM vw_vayu_master
GROUP BY 1
ORDER BY 1;

-- @Q20 | Lag window / wash-out | Does PM2.5 fall the day it rains, relative to the day before?
WITH s AS (
  SELECT city, date, pm2_5_mean, precipitation_sum,
         LAG(pm2_5_mean) OVER w AS prev_pm25,
         LAG(date) OVER w AS prev_date
  FROM vw_vayu_master
  WINDOW w AS (PARTITION BY city ORDER BY date)
)
SELECT CASE WHEN precipitation_sum = 0 THEN '1. Dry day'
            WHEN precipitation_sum <= 10 THEN '2. Light/moderate rain (<=10 mm)'
            ELSE '3. Heavy rain (>10 mm)' END AS rain_on_day,
       COUNT(*) AS day_pairs,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY 100.0 * (pm2_5_mean - prev_pm25) / prev_pm25))::numeric, 1) AS median_pct_change_vs_prev_day,
       ROUND(AVG(100.0 * (pm2_5_mean - prev_pm25) / prev_pm25), 1) AS mean_pct_change_vs_prev_day,
       ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean < prev_pm25) / COUNT(*), 1) AS pct_days_pm25_fell
FROM s
WHERE prev_date = date - 1 AND prev_pm25 > 0
GROUP BY 1
ORDER BY 1;

-- @Q21 | Meteorology | Do colder winter nights trap more PM2.5, especially in the North?
SELECT CASE WHEN temperature_2m_min < 5  THEN '1. < 5 C'
            WHEN temperature_2m_min < 10 THEN '2. 5-10 C'
            WHEN temperature_2m_min < 15 THEN '3. 10-15 C'
            WHEN temperature_2m_min < 20 THEN '4. 15-20 C'
            ELSE '5. >= 20 C' END AS night_temp_band,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE region = 'North'), 1)  AS north_pm25,
       COUNT(*) FILTER (WHERE region = 'North')                   AS north_days,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE region <> 'North'), 1) AS other_regions_pm25,
       COUNT(*) FILTER (WHERE region <> 'North')                  AS other_days
FROM vw_vayu_master
WHERE season = 'Winter'
GROUP BY 1
ORDER BY 1;

-- @Q22 | Segmentation | Does PM2.5 differ by weather type (fog, rain, thunderstorm...)?
SELECT CASE WHEN w.weather_code IN (0, 1, 2, 3) THEN 'Clear / cloudy'
            WHEN w.weather_code IN (45, 48) THEN 'Fog'
            WHEN w.weather_code BETWEEN 51 AND 57 THEN 'Drizzle'
            WHEN w.weather_code BETWEEN 61 AND 67 THEN 'Rain'
            WHEN w.weather_code BETWEEN 71 AND 77 THEN 'Snow'
            WHEN w.weather_code BETWEEN 80 AND 86 THEN 'Showers'
            WHEN w.weather_code >= 95 THEN 'Thunderstorm'
            ELSE 'Other' END AS weather_type,
       COUNT(*) AS city_days,
       ROUND(AVG(aq.pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(aq.pm2_5_mean) FILTER (WHERE c.region = 'North' AND EXTRACT(MONTH FROM aq.date) IN (12, 1, 2)), 1) AS north_winter_pm25
FROM air_quality_daily aq
JOIN weather_daily w USING (city, date)
JOIN cities c USING (city)
GROUP BY 1
ORDER BY avg_pm25 DESC;

-- @Q23 | Geographic | Does elevation shape pollution levels?
SELECT CASE WHEN c.elevation_m < 50  THEN '1. Low (<50 m)'
            WHEN c.elevation_m < 300 THEN '2. 50-300 m'
            WHEN c.elevation_m < 600 THEN '3. 300-600 m'
            ELSE '4. High (>=600 m)' END AS elevation_band,
       COUNT(DISTINCT c.city) AS cities,
       ROUND(AVG(aq.pm2_5_mean), 1) AS avg_pm25,
       ROUND(AVG(aq.pm10_mean), 1)  AS avg_pm10,
       ROUND(AVG(aq.o3_8h_max), 1)  AS avg_o3
FROM air_quality_daily aq JOIN cities c USING (city)
GROUP BY 1
ORDER BY 1;

-- @Q24 | Source proxy | What does the PM2.5/PM10 ratio and dust level say about regional pollution sources?
SELECT c.region,
       ROUND(AVG(aq.pm2_5_mean) / AVG(aq.pm10_mean), 2) AS pm25_to_pm10_ratio,
       ROUND(AVG(aq.dust_mean), 1) AS avg_dust,
       ROUND(AVG(aq.aod_mean), 3)  AS avg_aod,
       ROUND(AVG(aq.no2_mean), 1)  AS avg_no2,
       ROUND(AVG(aq.so2_mean), 1)  AS avg_so2
FROM air_quality_daily aq JOIN cities c USING (city)
GROUP BY c.region
ORDER BY pm25_to_pm10_ratio DESC;

-- @Q25 | Atmospheric chemistry | What drives ozone: sunshine, heat or humidity?
SELECT c.region,
       ROUND(AVG(aq.o3_8h_max), 1) AS avg_o3_8h,
       ROUND(CORR(aq.o3_8h_max, w.shortwave_radiation_sum)::numeric, 3)     AS corr_radiation,
       ROUND(CORR(aq.o3_8h_max, w.temperature_2m_max)::numeric, 3)          AS corr_max_temp,
       ROUND(CORR(aq.o3_8h_max, w.relative_humidity_2m_mean)::numeric, 3)   AS corr_humidity,
       ROUND(CORR(aq.o3_8h_max, aq.no2_mean)::numeric, 3)                   AS corr_no2
FROM air_quality_daily aq
JOIN weather_daily w USING (city, date)
JOIN cities c USING (city)
GROUP BY c.region
ORDER BY avg_o3_8h DESC;

-- @Q26 | Benchmarking | How often do cities breach India's 24-h PM2.5 limit (60) and the WHO 2021 guideline (15)?
WITH c AS (
  SELECT city,
         ROUND(AVG(pm2_5_mean), 1) AS avg_pm25,
         ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 60) / COUNT(*), 1) AS pct_days_above_india_60,
         ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 15) / COUNT(*), 1) AS pct_days_above_who_15
  FROM air_quality_daily GROUP BY city
)
SELECT * FROM (
  (SELECT city, avg_pm25, pct_days_above_india_60, pct_days_above_who_15, avg_pm25 > 40 AS breaches_india_annual_40
   FROM c ORDER BY pct_days_above_india_60 DESC LIMIT 10)
  UNION ALL
  SELECT 'ALL 50 CITIES', ROUND(AVG(pm2_5_mean), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 60) / COUNT(*), 1),
         ROUND(100.0 * COUNT(*) FILTER (WHERE pm2_5_mean > 15) / COUNT(*), 1),
         AVG(pm2_5_mean) > 40
  FROM air_quality_daily
) t
ORDER BY pct_days_above_india_60 DESC;

-- @Q27 | Statistical / variability | Which cities have the most volatile air, and which PM2.5 quartile do they sit in?
WITH s AS (
  SELECT city, AVG(pm2_5_mean) AS mean_pm25, STDDEV_SAMP(pm2_5_mean) AS sd_pm25,
         MAX(pm2_5_mean) AS max_pm25
  FROM air_quality_daily GROUP BY city
)
SELECT city, ROUND(mean_pm25, 1) AS mean_pm25, ROUND(sd_pm25, 1) AS std_dev,
       ROUND(sd_pm25 / mean_pm25, 2) AS coeff_of_variation,
       max_pm25,
       NTILE(4) OVER (ORDER BY mean_pm25 DESC) AS pollution_quartile_1_worst
FROM s
ORDER BY coeff_of_variation DESC
LIMIT 10;

-- @Q28 | Hypothesis check | Is PM2.5 lower on weekends than weekdays?
SELECT COALESCE(region, 'All India') AS region,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE EXTRACT(ISODOW FROM date) < 6), 2)  AS weekday_pm25,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE EXTRACT(ISODOW FROM date) >= 6), 2) AS weekend_pm25,
       ROUND(100.0 * (AVG(pm2_5_mean) FILTER (WHERE EXTRACT(ISODOW FROM date) >= 6)
                    / AVG(pm2_5_mean) FILTER (WHERE EXTRACT(ISODOW FROM date) < 6) - 1), 2) AS weekend_pct_diff
FROM vw_vayu_master
GROUP BY ROLLUP (region)
ORDER BY region NULLS LAST;

-- @Q29 | Event study | Does PM2.5 jump around Diwali? (North-region cities, +/- 7-day baseline)
-- Diwali (main day) dates used: 2022-10-24, 2023-11-12, 2024-10-31, 2025-10-20.
WITH d(year, diwali) AS (
  VALUES (2022, DATE '2022-10-24'), (2023, DATE '2023-11-12'), (2024, DATE '2024-10-31'), (2025, DATE '2025-10-20')
), x AS (
  SELECT d.year, d.diwali, m.date - d.diwali AS offset_day, m.pm2_5_mean, m.city
  FROM d JOIN vw_vayu_master m ON m.region = 'North' AND m.date BETWEEN d.diwali - 7 AND d.diwali + 3
)
SELECT year, diwali AS diwali_date,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE offset_day BETWEEN -7 AND -1), 1) AS baseline_pm25_prev_7d,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE offset_day = 0), 1) AS diwali_day,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE offset_day = 1), 1) AS day_after,
       ROUND(AVG(pm2_5_mean) FILTER (WHERE offset_day = 2), 1) AS two_days_after,
       ROUND(100.0 * (AVG(pm2_5_mean) FILTER (WHERE offset_day IN (0, 1)) / AVG(pm2_5_mean) FILTER (WHERE offset_day BETWEEN -7 AND -1) - 1), 1) AS pct_change_peak_vs_baseline
FROM x
GROUP BY year, diwali
ORDER BY year;
