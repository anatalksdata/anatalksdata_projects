"""Local syntax/logic sanity check of the Databricks SQL using DuckDB.
Run from the project folder: python sql/tests/test_duckdb.py
(needs `pip install duckdb`)
Only Databricks-specific bits are rewritten; each rewrite is listed in REWRITES."""
import re, pathlib, duckdb

HERE = pathlib.Path(__file__).resolve().parent
SQL_DIR = HERE.parent
CSV = str(SQL_DIR.parent / "data" / "sample_transactions.csv")
REWRITES = [
    # Databricks read_files(volume) + _metadata  ->  DuckDB read_csv(..., filename=true)
    (r"FROM read_files\(.*?\);", f"FROM read_csv('{CSV}', header=true, all_varchar=true, filename=true);", re.S),
    (r"_metadata\.file_name", "filename", 0),
    (r"current_timestamp\(\)", "current_timestamp", 0),
    # CTAS-level COMMENT clause and schema COMMENT are Databricks syntax
    (r"\nCOMMENT '[^']*'\nAS\n", "\nAS\n", 0),
    (r"\n  COMMENT '[^']*';", ";", 0),
]
SKIP = ("CREATE VOLUME", "ALTER TABLE")   # Databricks-only DDL

con = duckdb.connect()
con.execute("ATTACH ':memory:' AS workspace")
# initcap() is built into Databricks SQL, not DuckDB -> shim it
con.create_function("initcap", lambda x: x.title() if x else x, ["VARCHAR"], "VARCHAR")
for f in ["00_setup.sql", "01_bronze.sql", "02_silver.sql", "03_gold.sql",
          "04_genie_metadata.sql", "05_dashboard_datasets.sql"]:
    sql = (SQL_DIR / f).read_text()
    for pat, rep, flags in REWRITES:
        sql = re.sub(pat, rep, sql, flags=flags)
    print(f"\n===== {f}")
    for stmt in sql.split(";\n"):
        body = "\n".join(l for l in stmt.splitlines() if not l.strip().startswith("--")).strip()
        if not body: continue
        if body.upper().startswith(SKIP):
            print("  [skipped, Databricks-only]", body.splitlines()[0][:70]); continue
        res = con.execute(body)
        if body.upper().startswith(("SELECT", "WITH")):
            print(res.fetchdf().to_string(index=False) if hasattr(res, "fetchdf") else res.fetchall())
        else:
            print("  ok:", body.splitlines()[0][:80])

# Simulate the on-camera "Uncategorised" fix (02_silver.sql section 2c) and rebuild silver.
con.execute("""INSERT INTO workspace.personal_finance.category_rules VALUES
  (20,'PHARMACY%','Pharmacy','Health & Fitness'),(20,'NEWSAGENT%','Newsagent','Eating Out'),
  (20,'PAYPAL *STEAM%','Steam','Entertainment')""")
silver = (SQL_DIR / "02_silver.sql").read_text()
stmt = [s for s in silver.split(";\n") if "TABLE workspace.personal_finance.silver_transactions" in s][0]
con.execute(re.sub(r"\nCOMMENT '[^']*'\nAS\n", "\nAS\n", stmt))
print("\n===== after live fix: rows, uncategorised =",
      con.execute("SELECT count(*), count(*) FILTER (WHERE category='Uncategorised') "
                  "FROM workspace.personal_finance.silver_transactions").fetchone())
