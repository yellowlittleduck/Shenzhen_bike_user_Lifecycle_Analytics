from pathlib import Path
import tomllib

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
SQL_PATH = PROJECT_ROOT / "sql" / "05_build_lifecycle_strategy_marts.sql"
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

print("开始构建激活留存、用户分层与空间策略汇总表...")
con.execute(sql_text)

dashboard_tables = [
    "mart_cohort_retention",
    "mart_first_week_retention",
    "mart_user_segment_summary",
    "mart_grid_strategy",
]

print("\n========== 导出 Power BI 数据源 ==========")
for table_name in dashboard_tables:
    export_table(con, table_name)

print("\n========== D1 / D7 / D30 总体留存 ==========")
print(con.execute("""
    SELECT
        ROUND(100.0 * SUM(d1_retained_user_count) / NULLIF(SUM(d1_eligible_user_count), 0), 2) AS d1_retention_pct,
        ROUND(100.0 * SUM(d7_retained_user_count) / NULLIF(SUM(d7_eligible_user_count), 0), 2) AS d7_retention_pct,
        ROUND(100.0 * SUM(d30_retained_user_count) / NULLIF(SUM(d30_eligible_user_count), 0), 2) AS d30_retention_pct
    FROM mart_cohort_retention
""").fetchdf())

print("\n========== 首周骑行次数与后续留存 ==========")
print(con.execute("""
    SELECT first_week_trip_bucket, user_count, d7_retention_pct, d30_retention_pct
    FROM mart_first_week_retention
    ORDER BY bucket_sort_order
""").fetchdf())

print("\n========== 用户分层概览 ==========")
print(con.execute("SELECT * FROM mart_user_segment_summary").fetchdf())

print("\n========== 网格策略场景概览 ==========")
print(con.execute("""
    SELECT
        strategy_scene,
        COUNT(*) AS grid_count,
        ROUND(SUM(order_count) * 100.0 / (SELECT SUM(order_count) FROM mart_grid_strategy), 2)
            AS order_share_pct,
        ROUND(AVG(d7_retention_pct), 2) AS avg_d7_retention_pct
    FROM mart_grid_strategy
    GROUP BY 1
    ORDER BY order_share_pct DESC
""").fetchdf())

con.close()
print("\n运行完成。")
