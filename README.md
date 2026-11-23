# Vayu-Track
End-to-end Indian Air Quality &amp; Weather analytics platform using PostgreSQL, Python, and PowerBI

# Vayu Track 🌬️📊

**Vayu Track** is an end-to-end environmental data analytics project built with **PostgreSQL**, **Python**, and **BI/Visualization tools**. It analyzes daily air quality (AQI/PM2.5) and weather patterns across 50 Indian cities to uncover seasonal pollution trends, regional disparities, and the impact of meteorological factors like wind speed and rainfall on air quality.

---

## 🎯 Project Objectives
* **Relational Data Warehousing:** Design a normalized PostgreSQL schema combining city metadata, daily weather metrics, and daily air quality readings.
* **Automated ETL Pipeline:** Build a repeatable Python pipeline to clean, validate, and upsert daily data into PostgreSQL.
* **CPCB Health Classification:** Categorize daily air quality into official Indian CPCB (Central Pollution Control Board) bands (*Good*, *Satisfactory*, *Moderate*, *Poor*, *Very Poor*, *Severe*).
* **Statistical & Time-Series Analysis:** Use SQL window functions and correlation metrics (`CORR()`) to track 7-day rolling pollution trends and measure how wind and precipitation disperse PM2.5.

---

## 🛠️ Tech Stack
* **Database:** PostgreSQL
* **ETL & Data Processing:** Python (`pandas`, `SQLAlchemy`, `psycopg2`)
* **Visualization:** Power BI / Streamlit + Plotly
* **Version Control:** Git & GitHub

---

## 📂 Dataset
* **Source:** [India Daily Weather and Air Quality (Kaggle)](https://www.kaggle.com/datasets/akshaykarthickms007/india-daily-weather-and-air-quality)
* **Files Used:**
  * `cities.csv` — Dimension table containing city, state, region, latitude, longitude, and elevation.
  * `air_quality_daily.csv` — Daily pollutant concentrations (PM2.5, PM10, NO₂, SO₂, O₃, CO).
  * `weather_daily.csv` — Daily meteorological readings (temperature, precipitation, humidity, wind speed).

> **Data Note:** Pollutant and weather metrics are sourced from Open-Meteo (CAMS atmospheric model & ERA5/IFS), making this dataset ideal for regional and seasonal trend analysis rather than hyper-local street-level monitoring.

---

## 🗂️ Repository Structure
abhi bnayege T_T
