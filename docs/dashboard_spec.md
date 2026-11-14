# 数据看板设计

## 1. 经营总览

核心指标：订单量、DAU、WAU、MAU、人均订单、观察期首现用户。展示日期趋势、小时热力图、骑行时长分布和起终点热点。数据源为 `mart_daily_metrics`、`mart_hourly_metrics`、`mart_day_type_hourly_metrics`、`mart_weekday_hour_metrics` 与 `mart_day_type_summary`。

## 2. 激活与留存

展示 D1/D7/D30、同期群留存矩阵、首周骑行频次与后续留存，以及活跃用户与首现用户趋势。

数据源：`mart_cohort_retention`、`mart_first_week_retention`。

## 3. 用户分层与风险

展示首骑未激活、成长型、稳定通勤型、周末休闲型、高活跃与沉默风险用户的人数、订单贡献和留存差异。

当前数据源：`mart_user_segment_summary`。首周低激活单独在激活页面呈现，避免与当前活跃状态混为同一互斥分层。

## 4. 空间场景与策略中心

展示起终点网格、OD 链路、区域订单变化、低复骑机会区域及策略卡片。空间异常仅作为待排查机会，不直接推断车辆供给不足或体验故障。

当前数据源：`mart_grid_strategy`。其中低复骑仅指首骑起点网格对应首现用户的 D7 留存表现。
