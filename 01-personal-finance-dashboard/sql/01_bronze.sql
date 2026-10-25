-- 01_bronze.sql  ·  BRONZE = raw, as-delivered. Everything stays STRING; we only add lineage columns.
-- Databricks-specific: read_files() + _metadata. (DuckDB test harness swaps in read_csv(); see test_duckdb.py)

CREATE OR REPLACE TABLE workspace.personal_finance.bronze_transactions
COMMENT 'Raw bank transactions exactly as exported (all strings) + ingestion lineage'
AS
SELECT
  date,
  description,
  amount,
  currency,
  account,
  _metadata.file_name   AS source_file,
  current_timestamp()   AS ingested_at
FROM read_files(
  '/Volumes/workspace/personal_finance/raw/',
  format  => 'csv',
  header  => true,
  schema  => 'date STRING, description STRING, amount STRING, currency STRING, account STRING'
);

-- Quick look on camera
SELECT count(*) AS raw_rows, count(DISTINCT source_file) AS files FROM workspace.personal_finance.bronze_transactions;
