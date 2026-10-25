-- 03_gold.sql  ·  GOLD = business-ready tables that the dashboard and Genie read from.
-- Convention: spend_dkk is POSITIVE money out (refunds reduce it). Transfers are excluded everywhere.

-- 3a. Monthly cashflow: income vs spending vs what's left
CREATE OR REPLACE TABLE workspace.personal_finance.gold_monthly_cashflow
COMMENT 'One row per month: income, spending (excl. internal transfers), net and savings rate, in DKK'
AS
SELECT
  txn_month,
  sum(CASE WHEN txn_type = 'Income'   THEN amount_dkk ELSE 0 END)                AS income_dkk,
  -sum(CASE WHEN txn_type = 'Spending' THEN amount_dkk ELSE 0 END)               AS spend_dkk,
  sum(CASE WHEN txn_type <> 'Transfer' THEN amount_dkk ELSE 0 END)               AS net_dkk,
  round(sum(CASE WHEN txn_type <> 'Transfer' THEN amount_dkk ELSE 0 END)
        / nullif(sum(CASE WHEN txn_type = 'Income' THEN amount_dkk ELSE 0 END), 0), 3) AS savings_rate
FROM workspace.personal_finance.silver_transactions
GROUP BY txn_month;

-- 3b. Spending by month and category (the main stacked bar chart)
CREATE OR REPLACE TABLE workspace.personal_finance.gold_monthly_category_spend
COMMENT 'Spending in DKK per month and category (positive = money out), excl. income and transfers'
AS
SELECT
  txn_month,
  category,
  -sum(amount_dkk)  AS spend_dkk,
  count(*)          AS txn_count
FROM workspace.personal_finance.silver_transactions
WHERE txn_type = 'Spending'
GROUP BY txn_month, category;

-- 3c. Top merchants over the whole period
CREATE OR REPLACE TABLE workspace.personal_finance.gold_top_merchants
COMMENT 'Total spending per merchant over the full period, in DKK'
AS
SELECT
  merchant,
  category,
  -sum(amount_dkk)                 AS spend_dkk,
  count(*)                         AS txn_count,
  round(-avg(amount_dkk), 2)       AS avg_ticket_dkk
FROM workspace.personal_finance.silver_transactions
WHERE txn_type = 'Spending'
GROUP BY merchant, category;

-- 3d. Daily spending with month-to-date running total (line chart)
CREATE OR REPLACE TABLE workspace.personal_finance.gold_daily_spend
COMMENT 'Daily spending in DKK and month-to-date cumulative spending'
AS
WITH daily AS (
  SELECT txn_date, txn_month, -sum(amount_dkk) AS spend_dkk
  FROM workspace.personal_finance.silver_transactions
  WHERE txn_type = 'Spending'
  GROUP BY txn_date, txn_month
)
SELECT
  txn_date,
  txn_month,
  spend_dkk,
  sum(spend_dkk) OVER (PARTITION BY txn_month ORDER BY txn_date
                       ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS mtd_spend_dkk
FROM daily;

-- On-camera check
SELECT * FROM workspace.personal_finance.gold_monthly_cashflow ORDER BY txn_month;
