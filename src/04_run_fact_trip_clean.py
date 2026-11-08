from pathlib import Path
import tomllib

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
SQL_PATH = PROJECT_ROOT / "sql" / "02_build_fact_trip_clean.sql"
MART_DIR = PROJECT_ROOT / config["paths"]["mart_dir"]

sql_text = SQL_PATH.read_text(encoding="utf-8")

con = duckdb.connect(str(DB_PATH))

print("开始建立 fact_trip_clean...")
con.execute(sql_text)

print("\n========== 清洗审计 ==========")
audit = con.execute("""
    SELECT *
    FROM mart_trip_cleaning_audit
""").fetchdf()
print(audit)

audit.to_csv(
    MART_DIR / "trip_cleaning_audit.csv",
    index=False,
    encoding="utf-8-sig"
)

print("\n========== 最终事实表概览 ==========")
summary = con.execute("""
    SELECT
        COUNT(*) AS order_count,
        COUNT(DISTINCT user_id) AS user_count,
        MIN(trip_date) AS min_trip_date,
        MAX(trip_date) AS max_trip_date,
        ROUND(AVG(duration_min), 2) AS avg_duration_min,
        ROUND(AVG(straight_line_distance_km), 3) AS avg_straight_line_distance_km,
        ROUND(AVG(straight_line_speed_kmh), 2) AS avg_straight_line_speed_kmh
    FROM fact_trip_clean
""").fetchdf()
print(summary)

con.close()

print("\n运行完成。")
print(f"审计结果已输出：{MART_DIR / 'trip_cleaning_audit.csv'}")
