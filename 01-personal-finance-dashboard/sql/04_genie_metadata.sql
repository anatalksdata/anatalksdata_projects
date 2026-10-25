-- 04_genie_metadata.sql  ·  Databricks-only. Table/column comments are what Genie reads to understand your data.
-- (COMMENT ON TABLE also runs in DuckDB; ALTER ... ALTER COLUMN ... COMMENT is Databricks syntax.)

COMMENT ON TABLE workspace.personal_finance.silver_transactions IS
  'Every personal bank transaction (synthetic). amount_dkk < 0 = money out. txn_type is Income, Spending or Transfer; ignore Transfer when talking about spending.';

ALTER TABLE workspace.personal_finance.silver_transactions ALTER COLUMN amount_dkk  COMMENT 'Amount in Danish kroner. Negative = money out, positive = money in. EUR converted at 7.46.';
ALTER TABLE workspace.personal_finance.silver_transactions ALTER COLUMN category    COMMENT 'Spending category, e.g. Groceries, Eating Out, Transport, Subscriptions, Housing.';
ALTER TABLE workspace.personal_finance.silver_transactions ALTER COLUMN txn_type    COMMENT 'Income, Spending or Transfer (moves between own accounts; exclude from spending).';
ALTER TABLE workspace.personal_finance.silver_transactions ALTER COLUMN merchant    COMMENT 'Clean merchant name, e.g. FreshMart, Wolt, Netflix.';
ALTER TABLE workspace.personal_finance.gold_monthly_category_spend ALTER COLUMN spend_dkk COMMENT 'Money spent in DKK as a positive number.';
ALTER TABLE workspace.personal_finance.gold_monthly_cashflow ALTER COLUMN savings_rate COMMENT 'net_dkk / income_dkk. 0.25 means 25% of income was left over.';
