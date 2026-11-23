import os
import psycopg2
from psycopg2.extras import RealDictCursor
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

load_dotenv()

app = FastAPI(title="Vayu Track API")


def get_db_connection():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=os.getenv("DB_PORT", "5432"),
        dbname=os.getenv("DB_NAME", "vayu_track"),
        user=os.getenv("DB_USER", "postgres"),
        password=os.getenv("DB_PASSWORD"),
        cursor_factory=RealDictCursor,
    )


@app.get("/api/cities")
def get_cities_summary():
    """Returns summary KPIs, coordinates, and AQI metrics for all 50 cities."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT
                    city,
                    state,
                    region,
                    latitude::FLOAT,
                    longitude::FLOAT,
                    total_days::INT,
                    avg_india_aqi::FLOAT,
                    avg_pm2_5::FLOAT,
                    pct_clean_days::FLOAT,
                    pct_unhealthy_days::FLOAT
                FROM vw_city_summary
                ORDER BY avg_india_aqi DESC;
                """
            )
            return cur.fetchall()
    finally:
        conn.close()


@app.get("/api/trends")
def get_trends(city: str = "ALL"):
    """Returns monthly AQI/PM2.5 vs. Wind Speed and CPCB category breakdown."""
    conn = get_db_connection()
    try:
        with conn.cursor() as cur:
            where_clause = "" if city == "ALL" else "WHERE city = %s"
            params = () if city == "ALL" else (city,)

            # 1. Monthly Pollution vs. Weather Trend
            cur.execute(
                f"""
                SELECT
                    month::INT,
                    month_name,
                    ROUND(AVG(india_aqi), 1)::FLOAT          AS avg_aqi,
                    ROUND(AVG(pm2_5_mean), 1)::FLOAT         AS avg_pm25,
                    ROUND(AVG(wind_speed_10m_max), 1)::FLOAT AS avg_wind,
                    ROUND(AVG(precipitation_sum), 2)::FLOAT  AS avg_rain
                FROM vw_vayu_master
                {where_clause}
                GROUP BY month, month_name
                ORDER BY month;
                """,
                params,
            )
            monthly = cur.fetchall()

            # 2. CPCB Category Breakdown
            cur.execute(
                f"""
                SELECT
                    india_aqi_category AS category,
                    COUNT(*)::INT      AS days_count
                FROM vw_vayu_master
                {where_clause}
                GROUP BY india_aqi_category;
                """,
                params,
            )
            categories = cur.fetchall()

            # 3. KPI Summary for Selected Scope
            cur.execute(
                f"""
                SELECT
                    ROUND(AVG(india_aqi), 1)::FLOAT  AS avg_aqi,
                    ROUND(AVG(pm2_5_mean), 1)::FLOAT AS avg_pm25,
                    ROUND(
                        100.0 * COUNT(*) FILTER (WHERE india_aqi_category IN ('Good', 'Satisfactory')) / COUNT(*),
                        1
                    )::FLOAT AS pct_clean_days,
                    COUNT(*)::INT AS total_records
                FROM vw_vayu_master
                {where_clause};
                """,
                params,
            )
            kpis = cur.fetchone()

            return {"kpis": kpis, "monthly": monthly, "categories": categories}
    finally:
        conn.close()


# Serve frontend static files at root URL
frontend_dir = os.path.join(os.path.dirname(__file__), "..", "frontend")
app.mount("/", StaticFiles(directory=frontend_dir, html=True), name="frontend")