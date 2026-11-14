-- 目的：构建激活留存、用户分层与空间策略分析的汇总表。
-- 前置条件：已生成 fact_trip_clean 和 mart_origin_grid_demand。
-- 说明：所有留存率都仅在对应结果可被完整观测的同期群中计算。

CREATE OR REPLACE TABLE user_lifecycle_features AS
WITH user_first AS (
    SELECT
        user_id,
        MIN(trip_date) AS first_trip_date,
        MAX(trip_date) AS last_trip_date
    FROM fact_trip_clean
    GROUP BY 1
),
analysis_window AS (
    SELECT MAX(trip_date) AS analysis_end_date
    FROM fact_trip_clean
)
SELECT
    f.user_id,
    u.first_trip_date,
    u.last_trip_date,
    DATE_DIFF('day', u.last_trip_date, a.analysis_end_date) AS days_since_last_trip,
    COUNT(*) AS trip_count,
    COUNT(DISTINCT f.trip_date) AS active_day_count,
    SUM(CASE WHEN f.trip_date BETWEEN u.first_trip_date AND u.first_trip_date + 6 THEN 1 ELSE 0 END)
        AS first_week_trip_count,
    MAX(CASE WHEN f.trip_date = u.first_trip_date + 1 THEN 1 ELSE 0 END) AS d1_returned,
    MAX(CASE WHEN f.trip_date = u.first_trip_date + 7 THEN 1 ELSE 0 END) AS d7_returned,
    MAX(CASE WHEN f.trip_date = u.first_trip_date + 30 THEN 1 ELSE 0 END) AS d30_returned,
    SUM(CASE WHEN f.is_commute_peak THEN 1 ELSE 0 END) AS commute_peak_order_count,
    ROUND(100.0 * AVG(CASE WHEN f.is_commute_peak THEN 1 ELSE 0 END), 2)
        AS commute_peak_order_share_pct,
    SUM(CASE WHEN f.is_weekend THEN 1 ELSE 0 END) AS weekend_order_count,
    SUM(CASE WHEN f.trip_date BETWEEN a.analysis_end_date - 13 AND a.analysis_end_date THEN 1 ELSE 0 END)
        AS recent_14_day_order_count,
    ROUND(AVG(f.duration_min), 2) AS avg_duration_min,
    ROUND(AVG(f.straight_line_distance_km), 3) AS avg_straight_line_distance_km
FROM fact_trip_clean f
JOIN user_first u
    ON f.user_id = u.user_id
CROSS JOIN analysis_window a
GROUP BY 1, 2, 3, 4;


CREATE OR REPLACE TABLE mart_cohort_retention AS
WITH analysis_window AS (
    SELECT MAX(trip_date) AS analysis_end_date
    FROM fact_trip_clean
)
SELECT
    first_trip_date AS cohort_date,
    COUNT(*) AS first_seen_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 1 THEN 1 ELSE 0 END) AS d1_eligible_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 1 AND d1_returned = 1 THEN 1 ELSE 0 END)
        AS d1_retained_user_count,
    ROUND(
        100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 1 AND d1_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 1 THEN 1 ELSE 0 END), 0),
        2
    ) AS d1_retention_pct,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END) AS d7_eligible_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
        AS d7_retained_user_count,
    ROUND(
        100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END), 0),
        2
    ) AS d7_retention_pct,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 THEN 1 ELSE 0 END) AS d30_eligible_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 AND d30_returned = 1 THEN 1 ELSE 0 END)
        AS d30_retained_user_count,
    ROUND(
        100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 AND d30_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 THEN 1 ELSE 0 END), 0),
        2
    ) AS d30_retention_pct
FROM user_lifecycle_features
CROSS JOIN analysis_window
GROUP BY 1
ORDER BY 1;


CREATE OR REPLACE TABLE mart_first_week_retention AS
WITH analysis_window AS (
    SELECT MAX(trip_date) AS analysis_end_date
    FROM fact_trip_clean
),
bucketed_users AS (
    SELECT
        *,
        CASE
            WHEN first_week_trip_count = 1 THEN '1 次'
            WHEN first_week_trip_count = 2 THEN '2 次'
            WHEN first_week_trip_count = 3 THEN '3 次'
            WHEN first_week_trip_count BETWEEN 4 AND 6 THEN '4-6 次'
            ELSE '7 次及以上'
        END AS first_week_trip_bucket,
        CASE
            WHEN first_week_trip_count = 1 THEN 1
            WHEN first_week_trip_count = 2 THEN 2
            WHEN first_week_trip_count = 3 THEN 3
            WHEN first_week_trip_count BETWEEN 4 AND 6 THEN 4
            ELSE 5
        END AS bucket_sort_order
    FROM user_lifecycle_features
)
SELECT
    first_week_trip_bucket,
    bucket_sort_order,
    COUNT(*) AS user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END) AS d7_eligible_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
        AS d7_retained_user_count,
    ROUND(
        100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END), 0),
        2
    ) AS d7_retention_pct,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 THEN 1 ELSE 0 END) AS d30_eligible_user_count,
    SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 AND d30_returned = 1 THEN 1 ELSE 0 END)
        AS d30_retained_user_count,
    ROUND(
        100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 AND d30_returned = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 30 THEN 1 ELSE 0 END), 0),
        2
    ) AS d30_retention_pct
FROM bucketed_users
CROSS JOIN analysis_window
GROUP BY 1, 2
ORDER BY 2;


CREATE OR REPLACE TABLE mart_user_segment_summary AS
WITH segmented_users AS (
    SELECT
        *,
        CASE
            WHEN days_since_last_trip >= 14
                 AND trip_count >= 5
                 AND active_day_count >= 3
            THEN '沉默风险召回候选'
            WHEN days_since_last_trip < 14
                 AND commute_peak_order_count >= 8
                 AND commute_peak_order_share_pct >= 50
                 AND active_day_count >= 5
            THEN '稳定通勤用户'
            WHEN days_since_last_trip < 14
                 AND (trip_count >= 20 OR active_day_count >= 10)
            THEN '高活跃用户'
            WHEN days_since_last_trip < 14
            THEN '近期活跃用户'
            ELSE '低活跃历史用户'
        END AS user_segment
    FROM user_lifecycle_features
)
SELECT
    user_segment,
    COUNT(*) AS user_count,
    SUM(trip_count) AS order_count,
    ROUND(100.0 * SUM(trip_count) / SUM(SUM(trip_count)) OVER (), 2) AS order_contribution_pct,
    ROUND(AVG(trip_count), 2) AS avg_trip_count,
    ROUND(AVG(active_day_count), 2) AS avg_active_day_count,
    ROUND(AVG(commute_peak_order_share_pct), 2) AS avg_commute_peak_order_share_pct,
    ROUND(AVG(avg_duration_min), 2) AS avg_duration_min,
    ROUND(AVG(first_week_trip_count), 2) AS avg_first_week_trip_count
FROM segmented_users
GROUP BY 1
ORDER BY order_count DESC;


CREATE OR REPLACE TABLE user_first_location AS
SELECT
    user_id,
    MIN_BY(start_lat, start_time) AS first_start_lat,
    MIN_BY(start_lng, start_time) AS first_start_lng
FROM fact_trip_clean
GROUP BY 1;


CREATE OR REPLACE TABLE mart_grid_strategy AS
WITH first_user_grid AS (
    SELECT
        u.user_id,
        ROUND(FLOOR(l.first_start_lat / 0.005) * 0.005 + 0.0025, 6) AS grid_center_lat,
        ROUND(FLOOR(l.first_start_lng / 0.005) * 0.005 + 0.0025, 6) AS grid_center_lng,
        u.first_trip_date,
        u.d7_returned
    FROM user_lifecycle_features u
    JOIN user_first_location l
        ON u.user_id = l.user_id
),
analysis_window AS (
    SELECT MAX(trip_date) AS analysis_end_date
    FROM fact_trip_clean
),
grid_retention AS (
    SELECT
        grid_center_lat,
        grid_center_lng,
        SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END)
            AS d7_eligible_first_user_count,
        SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
            AS d7_retained_first_user_count,
        ROUND(
            100.0 * SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 AND d7_returned = 1 THEN 1 ELSE 0 END)
            / NULLIF(SUM(CASE WHEN first_trip_date <= analysis_end_date - 7 THEN 1 ELSE 0 END), 0),
            2
        ) AS d7_retention_pct
    FROM first_user_grid
    CROSS JOIN analysis_window
    GROUP BY 1, 2
),
grid_base AS (
    SELECT
        d.*,
        COALESCE(r.d7_eligible_first_user_count, 0) AS d7_eligible_first_user_count,
        COALESCE(r.d7_retained_first_user_count, 0) AS d7_retained_first_user_count,
        r.d7_retention_pct
    FROM mart_origin_grid_demand d
    LEFT JOIN grid_retention r
        ON d.grid_center_lat = r.grid_center_lat
       AND d.grid_center_lng = r.grid_center_lng
),
thresholds AS (
    SELECT
        QUANTILE_CONT(avg_daily_orders, 0.75) AS high_demand_threshold,
        QUANTILE_CONT(commute_peak_order_share_pct, 0.75) AS high_commute_threshold,
        QUANTILE_CONT(commute_peak_order_share_pct, 0.25) AS low_commute_threshold,
        QUANTILE_CONT(avg_duration_min, 0.75) AS long_duration_threshold,
        QUANTILE_CONT(d7_retention_pct, 0.25) FILTER (WHERE d7_eligible_first_user_count >= 100)
            AS low_d7_retention_threshold
    FROM grid_base
)
SELECT
    b.*,
    t.high_demand_threshold,
    t.high_commute_threshold,
    t.low_commute_threshold,
    t.long_duration_threshold,
    t.low_d7_retention_threshold,
    CASE
        WHEN b.avg_daily_orders >= t.high_demand_threshold
             AND b.d7_eligible_first_user_count >= 100
             AND b.d7_retention_pct <= t.low_d7_retention_threshold
        THEN '高需求低复骑机会'
        WHEN b.avg_daily_orders >= t.high_demand_threshold
             AND b.commute_peak_order_share_pct >= t.high_commute_threshold
        THEN '通勤保障优先'
        WHEN b.avg_daily_orders >= t.high_demand_threshold
             AND b.avg_duration_min >= t.long_duration_threshold
             AND b.commute_peak_order_share_pct <= t.low_commute_threshold
        THEN '休闲/消费场景候选'
        WHEN b.avg_daily_orders >= t.high_demand_threshold
        THEN '高需求待观察'
        ELSE '其他网格'
    END AS strategy_scene
FROM grid_base b
CROSS JOIN thresholds t;
