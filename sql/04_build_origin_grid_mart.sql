-- 目的：将已清洗订单按约 500 米起点网格聚合，供 Power BI 热点地图使用。
-- 说明：展示的是网格级汇总结果，不包含任何单个用户的轨迹或精确起点。
-- 前置条件：已生成 fact_trip_clean。

CREATE OR REPLACE TABLE mart_origin_grid_demand AS
WITH analysis_window AS (
    SELECT
        DATE_DIFF('day', MIN(trip_date), MAX(trip_date)) + 1 AS observation_day_count
    FROM fact_trip_clean
),
trip_with_grid AS (
    SELECT
        -- 0.005 度在深圳约对应 500 米量级；取网格中心点用于地图展示。
        ROUND(FLOOR(start_lat / 0.005) * 0.005 + 0.0025, 6) AS grid_center_lat,
        ROUND(FLOOR(start_lng / 0.005) * 0.005 + 0.0025, 6) AS grid_center_lng,
        user_id,
        trip_date,
        duration_min,
        straight_line_distance_km,
        is_commute_peak
    FROM fact_trip_clean
),
grid_stats AS (
    SELECT
        grid_center_lat,
        grid_center_lng,
        COUNT(*) AS order_count,
        COUNT(DISTINCT user_id) AS active_user_count,
        COUNT(DISTINCT trip_date) AS active_day_count,
        ROUND(AVG(duration_min), 2) AS avg_duration_min,
        ROUND(AVG(straight_line_distance_km), 3) AS avg_straight_line_distance_km,
        ROUND(100.0 * AVG(CASE WHEN is_commute_peak THEN 1 ELSE 0 END), 2)
            AS commute_peak_order_share_pct
    FROM trip_with_grid
    GROUP BY 1, 2
)
SELECT
    CONCAT(CAST(grid_center_lng AS VARCHAR), '_', CAST(grid_center_lat AS VARCHAR))
        AS origin_grid_id,
    grid_center_lat,
    grid_center_lng,
    order_count,
    ROUND(order_count * 1.0 / observation_day_count, 2) AS avg_daily_orders,
    active_user_count,
    active_day_count,
    avg_duration_min,
    avg_straight_line_distance_km,
    commute_peak_order_share_pct,
    ROUND(100.0 * order_count / SUM(order_count) OVER (), 4) AS order_share_pct,
    DENSE_RANK() OVER (ORDER BY order_count DESC) AS order_rank
FROM grid_stats
CROSS JOIN analysis_window;
