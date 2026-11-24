import subprocess

def table(name, title_color, rows, note=""):
    h = f'<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="5" BGCOLOR="white" COLOR="#334155">'
    h += f'<TR><TD COLSPAN="3" BGCOLOR="{title_color}"><FONT COLOR="white" POINT-SIZE="15"><B>{name}</B></FONT></TD></TR>'
    for key, col, typ in rows:
        if key == "SEP":
            h += f'<TR><TD COLSPAN="3" BGCOLOR="#e2e8f0"><FONT POINT-SIZE="10" COLOR="#475569"><I>{col}</I></FONT></TD></TR>'
            continue
        key = key or "&#160;"
        kc = {"PK":"#b45309","FK":"#1d4ed8","PK,FK":"#7c3aed"}.get(key,"#94a3b8")
        h += (f'<TR><TD ALIGN="CENTER" WIDTH="38"><FONT COLOR="{kc}" POINT-SIZE="10"><B>{key}</B></FONT></TD>'
              f'<TD ALIGN="LEFT">{col}</TD><TD ALIGN="LEFT"><FONT COLOR="#64748b" POINT-SIZE="10">{typ}</FONT></TD></TR>')
    if note:
        h += f'<TR><TD COLSPAN="3" BGCOLOR="#f1f5f9"><FONT POINT-SIZE="10" COLOR="#475569">{note}</FONT></TD></TR>'
    return h + '</TABLE>>'

def view(name, color, lines):
    h = f'<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="5" BGCOLOR="white" COLOR="#334155" STYLE="rounded">'
    h += f'<TR><TD BGCOLOR="{color}"><FONT COLOR="white" POINT-SIZE="14"><B>{name}</B></FONT> <FONT COLOR="white" POINT-SIZE="10">(VIEW)</FONT></TD></TR>'
    for l in lines:
        h += f'<TR><TD ALIGN="LEFT"><FONT POINT-SIZE="11">{l}</FONT></TD></TR>'
    return h + '</TABLE>>'

cities = table("cities", "#0f766e", [
    ("PK","city","VARCHAR(100)"),("","state","VARCHAR(100)"),("","region","VARCHAR(50)"),
    ("","latitude","NUMERIC(9,6)"),("","longitude","NUMERIC(9,6)"),("","elevation_m","NUMERIC(7,2)")],
    "50 rows  |  Dimension  |  idx: region")

weather = table("weather_daily", "#2563eb", [
    ("PK,FK","city","VARCHAR(100)"),("PK","date","DATE"),
    ("SEP","temperature","") ,
    ("","temperature_2m_max / min / mean","NUMERIC(6,2)"),("","apparent_temperature_max","NUMERIC(6,2)"),
    ("SEP","moisture &amp; wind",""),
    ("","precipitation_sum / precipitation_hours","NUMERIC"),("","relative_humidity_2m_mean","NUMERIC(5,2)"),
    ("","wind_speed_10m_max","NUMERIC(6,2)"),("","wind_direction_10m_dominant","NUMERIC(6,2)"),
    ("SEP","energy &amp; condition",""),
    ("","shortwave_radiation_sum","NUMERIC(8,2)"),("","et0_fao_evapotranspiration","NUMERIC(6,2)"),("","weather_code","SMALLINT")],
    "124,750 rows  |  Fact  |  2020-01-01 to 2026-10-30  |  idx: date")

aq = table("air_quality_daily", "#dc2626", [
    ("PK,FK","city","VARCHAR(100)"),("PK","date","DATE"),
    ("SEP","particulates",""),
    ("","pm2_5_mean / pm2_5_max","NUMERIC(8,2)"),("","pm10_mean / pm10_max","NUMERIC(8,2)"),
    ("","dust_mean","NUMERIC(8,2)"),("","aod_mean","NUMERIC(6,3)"),
    ("SEP","gases",""),
    ("","no2_mean","NUMERIC(8,2)"),("","so2_mean","NUMERIC(8,2)"),("","o3_8h_max","NUMERIC(8,2)"),("","co_8h_max","NUMERIC(10,2)"),
    ("SEP","indices (CPCB / US)",""),
    ("","india_aqi / india_aqi_category","NUMERIC / VARCHAR"),("","dominant_pollutant","VARCHAR(20)"),
    ("","india_aqi_pm / india_aqi_pm_category","NUMERIC / VARCHAR"),("","us_aqi_max","NUMERIC(6,2)"),("","hours_available","SMALLINT")],
    "77,400 rows  |  Fact  |  2022-08-05 to 2026-10-30  |  idx: date, category, dominant_pollutant")

master = view("vw_vayu_master", "#7c3aed", [
    "<B>aq</B> INNER JOIN <B>weather</B> ON (city, date)",
    "INNER JOIN <B>cities</B> ON city",
    "+ derived: year, month, month_name, <B>season</B>",
    "   Winter(Dec-Feb) | Summer(Mar-May)",
    "   Monsoon(Jun-Sep) | Post-Monsoon(Oct-Nov)",
    "77,400 rows (1 per city-day)"])
summary = view("vw_city_summary", "#9333ea", [
    "GROUP BY city from vw_vayu_master",
    "total_days, avg_india_aqi, avg_pm2_5",
    "pct_clean_days, pct_unhealthy_days",
    "50 rows (1 per city)"])
consumers = ('<<TABLE BORDER="0" CELLBORDER="1" CELLSPACING="0" CELLPADDING="6" BGCOLOR="#fef9c3" COLOR="#a16207" STYLE="rounded">'
             '<TR><TD><B>Consumers</B></TD></TR><TR><TD ALIGN="LEFT">04_analysis_queries.sql (29 questions)</TD></TR>'
             '<TR><TD ALIGN="LEFT">Power BI / Streamlit dashboards</TD></TR><TR><TD ALIGN="LEFT">FastAPI backend (backend/app.py)</TD></TR></TABLE>>')

dot = f'''
digraph G {{
  graph [rankdir=TB, splines=spline, nodesep=1.0, ranksep=1.0, bgcolor="white", pad=0.4, fontname="Helvetica",
         label=<<FONT POINT-SIZE="24"><B>Vayu Track: Database Schema (PostgreSQL)</B></FONT><BR/><FONT POINT-SIZE="12" COLOR="#475569">Star-style design: 1 dimension + 2 daily fact tables, joined on (city, date), exposed through 2 analytical views</FONT>>,
         labelloc=t];
  node [shape=plaintext, fontname="Helvetica", fontsize=12];
  edge [fontname="Helvetica", fontsize=11, color="#334155", penwidth=1.6];

  cities [label={cities}];
  weather [label={weather}];
  aq [label={aq}];
  master [label={master}];
  summary [label={summary}];
  consumers [label={consumers}];

  cities -> weather [dir=both, arrowtail=teeodot, arrowhead=crowodot, label="  1 : N   (FK city, ON DELETE CASCADE)  ", headlabel="", taillabel=""];
  cities -> aq      [dir=both, arrowtail=teeodot, arrowhead=crowodot, label="  1 : N   (FK city, ON DELETE CASCADE)  "];
  weather -> aq [dir=none, style=dashed, color="#7c3aed", constraint=false, label=<<FONT COLOR="#7c3aed">logical 1 : 1<BR/>on (city, date)<BR/>(weather starts 2020, AQ 2022)</FONT>>];
  weather -> master [style=dashed, color="#7c3aed"];
  aq -> master [style=dashed, color="#7c3aed"];
  cities -> master [style=dashed, color="#7c3aed", constraint=false];
  master -> summary [style=dashed, color="#9333ea"];
  master -> consumers [style=dotted, color="#a16207"];
  summary -> consumers [style=dotted, color="#a16207"];

  {{ rank=same; weather; aq; }}
  {{ rank=same; master; summary; }}
}}'''
open("docs/vayu_track_erd.dot","w").write(dot)
for fmt in ("png","svg"):
    args = ["dot", f"-T{fmt}"] + (["-Gdpi=170"] if fmt=="png" else []) + ["docs/vayu_track_erd.dot","-o",f"docs/vayu_track_erd.{fmt}"]
    r = subprocess.run(args, capture_output=True, text=True); print(fmt, r.returncode, r.stderr[:300])
