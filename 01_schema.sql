-- ==========================================
-- Vayu Track: PostgreSQL Database Schema
-- ==========================================

-- 1. Dimension Table: Cities (50 Indian Cities)
CREATE TABLE IF NOT EXISTS cities (
    city        VARCHAR(100) PRIMARY KEY,
    state       VARCHAR(100) NOT NULL,
    region      VARCHAR(50)  NOT NULL,
    latitude    NUMERIC(9, 6) NOT NULL,
    longitude   NUMERIC(9, 6) NOT NULL,
    elevation_m NUMERIC(7, 2) NOT NULL
);

-- 2. Fact Table: Daily Weather (2020-01-01 to 2026-10-30)
CREATE TABLE IF NOT EXISTS weather_daily (
    date                         DATE          NOT NULL,
    city                         VARCHAR(100)  NOT NULL REFERENCES cities(city) ON DELETE CASCADE,
    temperature_2m_max           NUMERIC(6, 2),
    temperature_2m_min           NUMERIC(6, 2),
    temperature_2m_mean          NUMERIC(6, 2),
    apparent_temperature_max     NUMERIC(6, 2),
    precipitation_sum            NUMERIC(8, 2),
    precipitation_hours          NUMERIC(5, 2),
    relative_humidity_2m_mean    NUMERIC(5, 2),
    wind_speed_10m_max           NUMERIC(6, 2),
    wind_direction_10m_dominant  NUMERIC(6, 2),
    shortwave_radiation_sum      NUMERIC(8, 2),
    et0_fao_evapotranspiration   NUMERIC(6, 2),
    weather_code                 SMALLINT,
    PRIMARY KEY (city, date)
);

-- 3. Fact Table: Daily Air Quality (2022-08-05 to 2026-10-30)
CREATE TABLE IF NOT EXISTS air_quality_daily (
    date                  DATE          NOT NULL,
    city                  VARCHAR(100)  NOT NULL REFERENCES cities(city) ON DELETE CASCADE,
    pm2_5_mean            NUMERIC(8, 2),
    pm2_5_max             NUMERIC(8, 2),
    pm10_mean             NUMERIC(8, 2),
    pm10_max              NUMERIC(8, 2),
    no2_mean              NUMERIC(8, 2),
    so2_mean              NUMERIC(8, 2),
    o3_8h_max             NUMERIC(8, 2),
    co_8h_max             NUMERIC(10, 2),
    dust_mean             NUMERIC(8, 2),
    aod_mean              NUMERIC(6, 3),
    us_aqi_max            NUMERIC(6, 2),
    hours_available       SMALLINT,
    india_aqi             NUMERIC(6, 2),
    india_aqi_category    VARCHAR(30),
    dominant_pollutant    VARCHAR(20),
    india_aqi_pm          NUMERIC(6, 2),
    india_aqi_pm_category VARCHAR(30),
    PRIMARY KEY (city, date)
);

-- 4. Performance Indexes for Time-Series & Regional Queries
CREATE INDEX IF NOT EXISTS idx_cities_region      ON cities(region);
CREATE INDEX IF NOT EXISTS idx_weather_date       ON weather_daily(date);
CREATE INDEX IF NOT EXISTS idx_aq_date            ON air_quality_daily(date);
CREATE INDEX IF NOT EXISTS idx_aq_category        ON air_quality_daily(india_aqi_category);
CREATE INDEX IF NOT EXISTS idx_aq_dominant_poll   ON air_quality_daily(dominant_pollutant);