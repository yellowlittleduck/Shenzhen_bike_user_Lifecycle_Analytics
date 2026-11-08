from pathlib import Path
import tomllib
import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DB_PATH = PROJECT_ROOT / config["paths"]["database_path"]
MART_DIR = PROJECT_ROOT / config["paths"]["mart_dir"]

con = duckdb.connect(str(DB_PATH))

# 1. 时长分位数：判断大多数订单集中在哪个范围
duration_summary = con.execute("""
    SELECT
        COUNT(*) AS order_count,
        MIN(duration_min) AS min_duration_min,
        QUANTILE_CONT(duration_min, 0.01) AS p01,
        QUANTILE_CONT(duration_min, 0.05) AS p05,
        QUANTILE_CONT(duration_min, 0.25) AS p25,
        QUANTILE_CONT(duration_min, 0.50) AS median,
        QUANTILE_CONT(duration_min, 0.75) AS p75,
        QUANTILE_CONT(duration_min, 0.95) AS p95,
        QUANTILE_CONT(duration_min, 0.99) AS p99,
        MAX(duration_min) AS max_duration_min
    FROM fact_trip_base
""").fetchdf()

print("========== 骑行时长分位数 ==========")
print(duration_summary)

duration_summary.to_csv(
    MART_DIR / "trip_duration_summary.csv",
    index=False,
    encoding="utf-8-sig"
)

# 2. 分桶：查看短时、正常、超长订单分别有多少
duration_buckets = con.execute("""
    SELECT
        CASE
            WHEN duration_min = 0 THEN '0分钟'
            WHEN duration_min > 0 AND duration_min < 1 THEN '0-1分钟'
            WHEN duration_min >= 1 AND duration_min < 3 THEN '1-3分钟'
            WHEN duration_min >= 3 AND duration_min < 5 THEN '3-5分钟'
            WHEN duration_min >= 5 AND duration_min < 10 THEN '5-10分钟'
            WHEN duration_min >= 10 AND duration_min < 20 THEN '10-20分钟'
            WHEN duration_min >= 20 AND duration_min < 30 THEN '20-30分钟'
            WHEN duration_min >= 30 AND duration_min < 60 THEN '30-60分钟'
            WHEN duration_min >= 60 AND duration_min < 120 THEN '60-120分钟'
            WHEN duration_min >= 120 AND duration_min < 240 THEN '120-240分钟'
            ELSE '240分钟及以上'
        END AS duration_bucket,

        COUNT(*) AS order_count,

        ROUND(
            COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
            4
        ) AS order_share_pct

    FROM fact_trip_base

    GROUP BY 1

    ORDER BY
        CASE duration_bucket
            WHEN '0分钟' THEN 1
            WHEN '0-1分钟' THEN 2
            WHEN '1-3分钟' THEN 3
            WHEN '3-5分钟' THEN 4
            WHEN '5-10分钟' THEN 5
            WHEN '10-20分钟' THEN 6
            WHEN '20-30分钟' THEN 7
            WHEN '30-60分钟' THEN 8
            WHEN '60-120分钟' THEN 9
            WHEN '120-240分钟' THEN 10
            ELSE 11
        END
""").fetchdf()

print("\n========== 骑行时长分桶 ==========")
print(duration_buckets)

duration_buckets.to_csv(
    MART_DIR / "trip_duration_buckets.csv",
    index=False,
    encoding="utf-8-sig"
)

con.close()

print("\n运行完成。")