-- 00_setup.sql  ·  Run once in the Databricks SQL editor (serverless warehouse) or a notebook %sql cell.
-- Free Edition gives you the `workspace` catalog (with a `default` schema) out of the box.
-- CREATE SCHEMA confirmed working in Free Edition (tested by Ana, 18 Oct 2026).

CREATE SCHEMA IF NOT EXISTS workspace.personal_finance
  COMMENT 'Data Talks by Ana · Video 1 · synthetic personal finance data (not real)';

-- Landing zone for raw bank CSVs. Upload sample_transactions.csv here via
-- New > Add or upload data > Upload files to a volume  (or Catalog Explorer > volume > Upload).
CREATE VOLUME IF NOT EXISTS workspace.personal_finance.raw
  COMMENT 'Raw bank CSV exports land here';

-- Sanity check after upload (Databricks-only: LIST works in SQL editor/notebooks)
-- LIST '/Volumes/workspace/personal_finance/raw/';
