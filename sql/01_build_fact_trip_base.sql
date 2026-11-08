-- 目的：从 stg_trip_raw 建立稳定观察窗口内的基础订单事实表。
-- 前置条件：已运行 src/01_build_staging_and_profile.py。
-- 本阶段只处理已验证的日期范围与基础完整性；骑行时长、距离等异常阈值
-- 将在分布检查后再确定，避免过早丢失有效订单。

CREATE OR REPLACE TABLE fact_trip_base AS
WITH parameters AS (
    SELECT
        DATE '2021-04-08' AS analysis_start_date,
        DATE '2021-08-28' AS analysis_end_date
),
base AS (
    SELECT
        s.user_id,
        s.com_id,
        s.start_time,
        s.end_time,
        s.start_lng,
        s.start_lat,
        s.end_lng,
        s.end_lat,
        s.source_file,

        CAST(s.start_time AS DATE) AS trip_date,
        EXTRACT('hour' FROM s.start_time) AS start_hour,
        EXTRACT('isodow' FROM s.start_time) AS iso_weekday,
        CASE
            WHEN EXTRACT('isodow' FROM s.start_time) IN (6, 7) THEN TRUE
            ELSE FALSE
        END AS is_weekend,

        DATEDIFF('second', s.start_time, s.end_time) / 60.0 AS duration_min,

        -- 约 100 米级网格，仅用于聚合分析，不代表真实站点。
        ROUND(s.start_lng, 3) AS start_grid_lng,
        ROUND(s.start_lat, 3) AS start_grid_lat,
        ROUND(s.end_lng, 3) AS end_grid_lng,
        ROUND(s.end_lat, 3) AS end_grid_lat
    FROM stg_trip_raw AS s
    CROSS JOIN parameters AS p
    WHERE s.start_time >= p.analysis_start_date
      AND s.start_time < p.analysis_end_date + INTERVAL 1 DAY

      -- 基础完整性：缺少用户、时间或坐标的订单无法用于后续分析。
      AND s.user_id IS NOT NULL
      AND s.end_time IS NOT NULL
      AND s.start_lng IS NOT NULL
      AND s.start_lat IS NOT NULL
      AND s.end_lng IS NOT NULL
      AND s.end_lat IS NOT NULL

      -- 不删除时长异常值，但删除结束早于开始的明显无效记录。
      AND s.end_time >= s.start_time

      -- 宽松的深圳区域坐标范围；后续会结合分布进一步检查。
      AND s.start_lng BETWEEN 113.0 AND 115.0
      AND s.end_lng BETWEEN 113.0 AND 115.0
      AND s.start_lat BETWEEN 21.5 AND 23.5
      AND s.end_lat BETWEEN 21.5 AND 23.5
)
SELECT *
FROM base;

-- 运行后可用下列语句快速核验：
-- SELECT COUNT(*) AS order_count, MIN(trip_date), MAX(trip_date) FROM fact_trip_base;
