from pathlib import Path
import tomllib

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
SQL_PATH = PROJECT_ROOT / "sql" / "03_build_demand_marts.sql"
MART_DIR = PROJECT_ROOT / config["paths"]["mart_dir"]


def export_table(con: duckdb.DuckDBPyConnection, table_name: str) -> None:
    output_path = MART_DIR / f"{table_name}.csv"
    con.execute(
        f"COPY {table_name} TO ? (HEADER, DELIMITER ',')",
        [str(output_path)],
    )
    print(f"已导出：{output_path.name}")


con = duckdb.connect(str(DB_PATH))
sql_text = SQL_PATH.read_text(encoding="utf-8")

print("开始构建需求分析看板数据表...")
con.execute(sql_text)

dashboard_tables = [
    "mart_daily_metrics",
    "mart_hourly_metrics",
    "mart_day_type_hourly_metrics",
    "mart_weekday_hour_metrics",
    "mart_day_type_summary",
]

print("\n========== 导出 Power BI 数据源 ==========")
for table_name in dashboard_tables:
    export_table(con, table_name)

print("\n========== 一天中订单最高的 5 个小时 ==========")
print(con.execute("""
    SELECT start_hour, order_count, active_user_count, order_share_pct
    FROM mart_hourly_metrics
    ORDER BY order_count DESC
    LIMIT 5
""").fetchdf())

print("\n========== 工作日 / 周末对比 ==========")
print(con.execute("SELECT * FROM mart_day_type_summary").fetchdf())

con.close()

print("\n运行完成。")
