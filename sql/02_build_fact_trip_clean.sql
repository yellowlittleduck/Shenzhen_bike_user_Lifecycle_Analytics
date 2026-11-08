-- 目的：在 fact_trip_base 基础上，构建用于行为、留存与空间分析的最终订单事实表。
-- 前置条件：已运行 sql/01_build_fact_trip_base.sql。
-- 清洗规则：保留 1 分钟（含）至 1,440 分钟（24 小时，含）的骑行订单。

CREATE OR REPLACE TABLE fact_trip_clean AS
WITH duration_valid AS (
    SELECT *
    FROM fact_trip_base
    WHERE duration_min >= 1
      AND duration_min <= 1440
),
distance_features AS (
    SELECT
        *,

        -- Haversine 公式计算起终点直线距离，单位为 km。
        -- 它不是实际路网骑行距离，仅用于相对比较和异常排查。
        6371.0088 * 2 * ASIN(
            SQRT(
                LEAST(
                    1.0,
                    POWER(SIN(RADIANS(end_lat - start_lat) / 2), 2)
                    + COS(RADIANS(start_lat))
                    * COS(RADIANS(end_lat))
                    * POWER(SIN(RADIANS(end_lng - start_lng) / 2), 2)
                )
            )
        ) AS straight_line_distance_km
    FROM duration_valid
)
SELECT
    *,
    straight_line_distance_km / NULLIF(duration_min / 60.0, 0) AS straight_line_speed_kmh,

    CONCAT(CAST(start_grid_lng AS VARCHAR), '_', CAST(start_grid_lat AS VARCHAR)) AS start_grid_id,
    CONCAT(CAST(end_grid_lng AS VARCHAR), '_', CAST(end_grid_lat AS VARCHAR)) AS end_grid_id,

    CONCAT(
        CAST(start_grid_lng AS VARCHAR), '_', CAST(start_grid_lat AS VARCHAR),
        '->',
        CAST(end_grid_lng AS VARCHAR), '_', CAST(end_grid_lat AS VARCHAR)
    ) AS od_grid_id,

    CASE
        WHEN start_hour BETWEEN 7 AND 9
          OR start_hour BETWEEN 17 AND 19
        THEN TRUE
        ELSE FALSE
    END AS is_commute_peak
FROM distance_features;


-- 清洗审计表：记录基础事实表到最终事实表的保留情况。
CREATE OR REPLACE TABLE mart_trip_cleaning_audit AS
SELECT
    CASE
        WHEN duration_min < 1 THEN 'removed_duration_lt_1_min'
        WHEN duration_min > 1440 THEN 'removed_duration_gt_1440_min'
        ELSE 'retained_valid_trip'
    END AS cleaning_result,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 4) AS order_share_pct
FROM fact_trip_base
GROUP BY 1
ORDER BY
    CASE cleaning_result
        WHEN 'retained_valid_trip' THEN 1
        WHEN 'removed_duration_lt_1_min' THEN 2
        ELSE 3
    END;
