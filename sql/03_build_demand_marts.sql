-- 目的：从 fact_trip_clean 构建经营总览页所需的聚合看板数据表。
-- 前置条件：已建立 fact_trip_clean。


-- 1. 每日经营指标：用于日期趋势、KPI 卡片和异常日期观察。
CREATE OR REPLACE TABLE mart_daily_metrics AS
SELECT
    trip_date,
    iso_weekday,
    is_weekend,
    COUNT(*) AS order_count,
    COUNT(DISTINCT user_id) AS active_user_count,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT user_id), 4) AS orders_per_active_user,
    ROUND(AVG(duration_min), 4) AS avg_duration_min,
    ROUND(AVG(straight_line_distance_km), 4) AS avg_straight_line_distance_km,
    ROUND(AVG(straight_line_speed_kmh), 4) AS avg_straight_line_speed_kmh,
    SUM(CASE WHEN is_commute_peak THEN 1 ELSE 0 END) AS commute_peak_order_count,
    ROUND(
        SUM(CASE WHEN is_commute_peak THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        4
    ) AS commute_peak_order_share_pct
FROM fact_trip_clean
GROUP BY trip_date, iso_weekday, is_weekend
ORDER BY trip_date;


-- 2. 全观察期小时指标：用于回答“一天中什么时候需求最高”。
CREATE OR REPLACE TABLE mart_hourly_metrics AS
SELECT
    start_hour,
    COUNT(*) AS order_count,
    COUNT(DISTINCT user_id) AS active_user_count,
    ROUND(AVG(duration_min), 4) AS avg_duration_min,
    ROUND(AVG(straight_line_distance_km), 4) AS avg_straight_line_distance_km,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 4) AS order_share_pct
FROM fact_trip_clean
GROUP BY start_hour
ORDER BY start_hour;


-- 3. 工作日/周末小时指标：用于对比两类日期的日内需求曲线。
CREATE OR REPLACE TABLE mart_day_type_hourly_metrics AS
SELECT
    CASE WHEN is_weekend THEN 'weekend' ELSE 'weekday' END AS day_type,
    start_hour,
    COUNT(*) AS order_count,
    COUNT(DISTINCT user_id) AS active_user_count,
    ROUND(AVG(duration_min), 4) AS avg_duration_min,
    ROUND(AVG(straight_line_distance_km), 4) AS avg_straight_line_distance_km
FROM fact_trip_clean
GROUP BY 1, 2
ORDER BY day_type, start_hour;


-- 4. 星期 × 小时热力图：用于发现具体的高峰时段。
CREATE OR REPLACE TABLE mart_weekday_hour_metrics AS
SELECT
    iso_weekday,
    CASE iso_weekday
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END AS weekday_name,
    start_hour,
    COUNT(*) AS order_count,
    COUNT(DISTINCT user_id) AS active_user_count,
    ROUND(AVG(duration_min), 4) AS avg_duration_min
FROM fact_trip_clean
GROUP BY 1, 2, 3
ORDER BY iso_weekday, start_hour;


-- 5. 工作日 / 周末汇总：用于业务结论和看板 KPI 对比。
CREATE OR REPLACE TABLE mart_day_type_summary AS
SELECT
    CASE WHEN is_weekend THEN 'weekend' ELSE 'weekday' END AS day_type,
    COUNT(DISTINCT trip_date) AS day_count,
    COUNT(*) AS order_count,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT trip_date), 2) AS avg_daily_orders,
    COUNT(DISTINCT user_id) AS unique_user_count,
    ROUND(AVG(duration_min), 4) AS avg_duration_min,
    ROUND(AVG(straight_line_distance_km), 4) AS avg_straight_line_distance_km,
    ROUND(
        SUM(CASE WHEN is_commute_peak THEN 1 ELSE 0 END) * 100.0 / COUNT(*),
        4
    ) AS commute_peak_order_share_pct
FROM fact_trip_clean
GROUP BY 1
ORDER BY day_type;
