from pathlib import Path
import re
import tomllib
import duckdb

# 1. 读取本地配置
PROJECT_ROOT = Path(__file__).resolve().parents[1]

with open(PROJECT_ROOT / "config.toml", "rb") as f:
    config = tomllib.load(f)

DATA_DIR = Path(config["paths"]["raw_data_dir"])

# 2. 找到主数据文件：data1.csv、data2.csv ...
files = [
    p for p in DATA_DIR.glob("data*.csv")
    if re.fullmatch(r"data\d+\.csv", p.name)
]

files = sorted(
    files,
    key=lambda p: int(re.search(r"\d+", p.stem).group())
)

total_size_gb = sum(p.stat().st_size for p in files) / 1024**3

print(f"主数据文件数：{len(files)}")
print(f"总文件大小：{total_size_gb:.2f} GB")
print(f"第一个文件：{files[0].name}")
print(f"最后一个文件：{files[-1].name}")

# 3. 用两个字段可能不同的文件，测试 DuckDB 的字段合并能力
test_files = [str(files[0]), str(files[50])]

con = duckdb.connect()

sample = con.read_csv(
    test_files,
    header=True,
    union_by_name=True,
    all_varchar=True,
    filename=True
)

print("\n字段列表：")
print(sample.columns)

print("\n前 5 行数据：")
print(sample.limit(5).df())

print("\n时间范围测试：")
result = con.execute("""
    SELECT
        COUNT(*) AS order_cnt,
        MIN(TRY_CAST(START_TIME AS TIMESTAMP)) AS min_start_time,
        MAX(TRY_CAST(START_TIME AS TIMESTAMP)) AS max_start_time
    FROM sample
""").fetchdf()

print(result)