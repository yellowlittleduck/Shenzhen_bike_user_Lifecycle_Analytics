# Data policy

The original Shenzhen trip-order files are stored locally and are intentionally excluded from this repository because of their size and data-use constraints.

`raw/` contains local source files only. `processed/` contains the local DuckDB database and intermediate outputs. `marts/` contains dashboard-ready aggregate tables. None of these directories should contain order-level data in Git.
