from pathlib import Path
import tomllib

import duckdb


# 1. 找到项目根目录与本地 DuckDB 数据库
PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
SQL_PATH = PROJECT_ROOT / "sql" / "01_build_fact_trip_base.sql"


# 2. 读取 SQL 文件
sql_text = SQL_PATH.read_text(encoding="utf-8")


# 3. 连接数据库并执行 SQL
print("连接 DuckDB...")
con = duckdb.connect(str(DB_PATH))

print("开始建立 fact_trip_base...")
print("首次运行需要处理稳定观察窗口内的大量订单，请耐心等待。")

con.execute(sql_text)

print("事实表建立完成。")


# 4. 基础核验
print("\n========== 事实表概览 ==========")

summary = con.execute("""
    SELECT
        COUNT(*) AS order_count,
        COUNT(DISTINCT user_id) AS user_count,
        MIN(trip_date) AS min_trip_date,
        MAX(trip_date) AS max_trip_date,
        ROUND(AVG(duration_min), 2) AS avg_duration_min
    FROM fact_trip_base
""").fetchdf()

print(summary)


print("\n========== 首尾日期订单量 ==========")

daily_check = con.execute("""
    SELECT
        trip_date,
        COUNT(*) AS order_count,
        COUNT(DISTINCT user_id) AS active_user_count
    FROM fact_trip_base
    GROUP BY trip_date
    ORDER BY trip_date
""").fetchdf()

print(daily_check.head(5))
print("...")
print(daily_check.tail(5))


con.close()

print("\n运行完成。")