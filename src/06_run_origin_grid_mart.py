from pathlib import Path
import tomllib

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
SQL_PATH = PROJECT_ROOT / "sql" / "04_build_origin_grid_mart.sql"
MART_DIR = PROJECT_ROOT / config["paths"]["mart_dir"]
OUTPUT_PATH = MART_DIR / "mart_origin_grid_demand.csv"


con = duckdb.connect(str(DB_PATH))
sql_text = SQL_PATH.read_text(encoding="utf-8")

print("开始构建起点需求网格地图表...")
con.execute(sql_text)
con.execute(
    "COPY mart_origin_grid_demand TO ? (HEADER, DELIMITER ',')",
    [str(OUTPUT_PATH)],
)

print(f"已导出：{OUTPUT_PATH}")
print("\n========== 地图表概览 ==========")
print(con.execute("""
    SELECT
        COUNT(*) AS grid_count,
        SUM(order_count) AS order_count,
        ROUND(AVG(avg_daily_orders), 2) AS avg_grid_daily_orders,
        MAX(order_count) AS max_grid_order_count
    FROM mart_origin_grid_demand
""").fetchdf())

print("\n========== 订单量最高的 10 个起点网格 ==========")
print(con.execute("""
    SELECT
        order_rank,
        grid_center_lat,
        grid_center_lng,
        order_count,
        avg_daily_orders,
        active_user_count,
        commute_peak_order_share_pct
    FROM mart_origin_grid_demand
    ORDER BY order_rank
    LIMIT 10
""").fetchdf())

con.close()
print("\n运行完成。")
