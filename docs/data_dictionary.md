# 数据字典（初版）

| 字段 | 含义 | 使用说明 |
|---|---|---|
| `START_TIME` | 骑行开始时间 | 用于日期、小时、留存与活跃计算 |
| `END_TIME` | 骑行结束时间 | 与开始时间计算骑行时长 |
| `USER_ID` | 匿名用户标识 | 用于去重、留存和分层；不尝试识别真实个人 |
| `START_LNG`, `START_LAT` | 起点坐标 | 用于网格与 OD 分析 |
| `END_LNG`, `END_LAT` | 终点坐标 | 用于网格与 OD 分析 |
| `COM_ID` | 企业标识 | 部分批次缺失，仅作为补充字段，不作为主分析维度 |

派生字段将在清洗脚本中生成：`trip_date`、`hour`、`weekday`、`is_weekend`、`duration_min`、`straight_line_distance_km`、起终点 H3 网格等。
