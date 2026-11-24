"""Run every question in 04_analysis_queries.sql against PostgreSQL and save each result as results/qNN.csv.

Usage (from the repo root, after loading the schema and data):
    PGPASSWORD=... python scripts/run_queries.py
Connection settings come from PGHOST, PGPORT, PGUSER, PGDATABASE (defaults: localhost, 5432, postgres, vayu_track).
"""
import os
import re
import subprocess

HOST = os.getenv("PGHOST", "localhost")
PORT = os.getenv("PGPORT", "5432")
USER = os.getenv("PGUSER", "postgres")
DB = os.getenv("PGDATABASE", "vayu_track")

sql = open("04_analysis_queries.sql", encoding="utf-8").read()
blocks = re.split(r"^-- @Q(\d+) \| ", sql, flags=re.M)[1:]
os.makedirs("results", exist_ok=True)

for i in range(0, len(blocks), 2):
    n, body = int(blocks[i]), blocks[i + 1]
    _, _, query = body.partition("\n")
    query = re.sub(r"(?m)^--.*$", "", query).strip()
    r = subprocess.run(["psql", "-h", HOST, "-p", PORT, "-U", USER, "-d", DB, "--csv", "-v", "ON_ERROR_STOP=1", "-c", query],
                       capture_output=True, text=True)
    if r.returncode != 0:
        print(f"Q{n} FAILED:\n{r.stderr}")
        continue
    with open(f"results/q{n:02d}.csv", "w", encoding="utf-8") as f:
        f.write(r.stdout)
    print(f"Q{n:02d} ok ({r.stdout.count(chr(10)) - 1} rows)")
