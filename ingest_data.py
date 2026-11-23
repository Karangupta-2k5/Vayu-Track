import os
import io
import pandas as pd
import psycopg2
from dotenv import load_dotenv

# Load credentials from .env
load_dotenv()

DB_CONFIG = {
    "host": os.getenv("DB_HOST", "localhost"),
    "port": os.getenv("DB_PORT", "5432"),
    "dbname": os.getenv("DB_NAME", "vayu_track"),
    "user": os.getenv("DB_USER", "postgres"),
    "password": os.getenv("DB_PASSWORD"),
}

DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "data")


def bulk_upsert_csv(conn, csv_filename, table_name, conflict_cols):
    """Loads a CSV into a temp staging table via COPY, then upserts into the target table."""
    filepath = os.path.join(DATA_DIR, csv_filename)
    print(f"Reading {csv_filename}...")
    df = pd.read_csv(filepath)

    # Ensure date column is formatted cleanly as YYYY-MM-DD
    if "date" in df.columns:
        df["date"] = pd.to_datetime(df["date"]).dt.strftime("%Y-%m-%d")

    cols = list(df.columns)
    cols_sql = ", ".join(cols)
    conflict_sql = ", ".join(conflict_cols)
    temp_table = f"temp_{table_name}"

    # Write DataFrame to an in-memory CSV buffer
    buffer = io.StringIO()
    df.to_csv(buffer, index=False, header=False)
    buffer.seek(0)

    with conn.cursor() as cur:
        # 1. Create a temporary staging table matching the target schema
        cur.execute(f"CREATE TEMP TABLE {temp_table} (LIKE {table_name}) ON COMMIT DROP;")

        # 2. Fast bulk copy into staging table
        cur.copy_expert(
            f"COPY {temp_table} ({cols_sql}) FROM STDIN WITH (FORMAT CSV)",
            buffer,
        )

        # 3. Insert into target table, skipping existing primary keys
        cur.execute(
            f"""
            INSERT INTO {table_name} ({cols_sql})
            SELECT {cols_sql} FROM {temp_table}
            ON CONFLICT ({conflict_sql}) DO NOTHING;
            """
        )

    conn.commit()
    print(f"Loaded {len(df):,} rows into '{table_name}'.")


def main():
    conn = psycopg2.connect(**DB_CONFIG)
    try:
        # Load in relational order: dimension table first, then fact tables
        bulk_upsert_csv(conn, "cities.csv", "cities", ["city"])
        bulk_upsert_csv(conn, "weather_daily.csv", "weather_daily", ["city", "date"])
        bulk_upsert_csv(conn, "air_quality_daily.csv", "air_quality_daily", ["city", "date"])
        print("\nETL complete! All tables are up to date.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()