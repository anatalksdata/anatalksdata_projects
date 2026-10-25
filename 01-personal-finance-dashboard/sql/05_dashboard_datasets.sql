-- 05_dashboard_datasets.sql  ·  Paste each query as a dataset in the AI/BI dashboard (Data tab).

-- KPI counters (last full month vs 6-month average)
SELECT
  max_by(spend_dkk, txn_month)          AS last_month_spend_dkk,
  round(avg(spend_dkk), 0)              AS avg_monthly_spend_dkk,
  max_by(savings_rate, txn_month)       AS last_month_savings_rate
FROM workspace.personal_finance.gold_monthly_cashflow;

-- Stacked bar: spend by month x category  -> gold_monthly_category_spend (use table directly)
-- Line: month-to-date spend                -> gold_daily_spend
-- Table: top 10 merchants
SELECT merchant, category, spend_dkk, txn_count, avg_ticket_dkk
FROM workspace.personal_finance.gold_top_merchants
ORDER BY spend_dkk DESC
LIMIT 10;

-- Subscriptions (the "small leaks" chart)
SELECT merchant, sum(-amount_dkk) AS spend_dkk, count(*) AS months_charged
FROM workspace.personal_finance.silver_transactions
WHERE category = 'Subscriptions'
GROUP BY merchant
ORDER BY spend_dkk DESC;
