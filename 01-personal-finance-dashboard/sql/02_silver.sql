-- 02_silver.sql  ·  SILVER = typed, cleaned, de-duplicated, categorised.

-- 2a. Category rules: a tiny lookup table instead of a giant CASE WHEN.
--     Lower priority number wins. Patterns are matched against the UPPER-cased clean description.
CREATE OR REPLACE TABLE workspace.personal_finance.category_rules (
  priority INT,
  pattern  STRING,
  merchant STRING,
  category STRING
);

INSERT INTO workspace.personal_finance.category_rules VALUES
  (1,  'SALARY %',              'Salary',            'Income'),
  (1,  'MOBILEPAY FROM %',      'MobilePay in',      'Income'),
  (2,  'TRANSFER %',            'Internal transfer', 'Transfer'),
  (2,  'CREDIT CARD PAYMENT%',  'Credit card bill',  'Transfer'),
  (2,  'PAYMENT RECEIVED%',     'Credit card bill',  'Transfer'),
  (10, 'RENT %',                'Rent',              'Housing'),
  (10, 'CITY POWER%',           'City Power',        'Bills & Utilities'),
  (10, 'TELENOR%',              'Telenor',           'Bills & Utilities'),
  (10, 'SAFEGUARD INSURANCE%',  'Safeguard Insurance','Insurance'),
  (10, 'FITNESS WORLD%',        'Fitness World',     'Health & Fitness'),
  (10, 'NETFLIX%',              'Netflix',           'Subscriptions'),
  (10, 'SPOTIFY%',              'Spotify',           'Subscriptions'),
  (20, 'FRESHMART%',            'FreshMart',         'Groceries'),
  (20, 'VALUE GROCER%',         'Value Grocer',      'Groceries'),
  (20, 'SUPERSTORE%',           'Superstore',        'Groceries'),
  (20, 'LIDL%',                 'Lidl',              'Groceries'),
  (20, 'GOURMET MARKET%',       'Gourmet Market',    'Groceries'),
  (20, 'CORNER COOP%',          'Corner Coop',       'Groceries'),
  (20, 'TRAVEL CARD%',          'Travel Card',       'Transport'),
  (20, 'NATIONAL RAIL%',        'National Rail',     'Transport'),
  (20, 'CIRCLE K%',             'Circle K',          'Transport'),
  (20, 'BVG%',                  'BVG Berlin',        'Transport'),
  (20, 'JOE & THE JUICE%',      'Joe & The Juice',   'Eating Out'),
  (20, 'WOLT%',                 'Wolt',              'Eating Out'),
  (20, 'THE CAKE HOUSE%',       'The Cake House',    'Eating Out'),
  (20, 'SUSHI%',                'Sushi',             'Eating Out'),
  (20, 'CAFE%',                 'Cafe',              'Eating Out'),
  (30, 'MOBILEPAY TO %',        'MobilePay out',     'Friends & MobilePay'),
  (20, 'BEAUTY & CARE%',        'Beauty & Care',     'Shopping'),
  (20, 'H&M%',                  'H&M',               'Shopping'),
  (20, 'ZALANDO%',              'Zalando',           'Shopping'),
  (20, 'IKEA%',                 'IKEA',              'Shopping'),
  (20, 'HOTEL%',                'Hotel',             'Travel'),
  (20, 'MUSEUM%',               'Museum',            'Travel');
-- Deliberately missing: NEWSAGENT, PAYPAL, PHARMACY -> show up as 'Uncategorised'. Add them live on camera (section 2c).

-- 2b. Silver transactions
CREATE OR REPLACE TABLE workspace.personal_finance.silver_transactions
COMMENT 'Cleaned, typed, de-duplicated and categorised transactions. amount_dkk: negative = money out.'
AS
WITH typed AS (
  SELECT
    TRY_CAST(trim(date) AS DATE)                                   AS txn_date,
    regexp_replace(
      regexp_replace(upper(trim(description)), ' +', ' '),         -- collapse double spaces
      '^CARD PURCHASE ', '')                                         AS description_clean,
    TRY_CAST(trim(amount) AS DECIMAL(12,2))                        AS amount,
    upper(trim(currency))                                          AS currency,
    trim(account)                                                  AS account,
    source_file
  FROM workspace.personal_finance.bronze_transactions
),
deduped AS (
  SELECT *
  FROM typed
  WHERE txn_date IS NOT NULL AND amount IS NOT NULL
  -- exact duplicates from overlapping exports. (A real bank export would give you a transaction ID; use that instead.)
  QUALIFY row_number() OVER (
    PARTITION BY txn_date, description_clean, amount, currency, account
    ORDER BY source_file) = 1
),
converted AS (
  SELECT
    *,
    CAST(CASE WHEN currency = 'EUR' THEN round(amount * 7.46, 2)   -- DKK is pegged to EUR; fixed rate is fine for a personal dashboard
              ELSE amount END AS DECIMAL(12,2))                    AS amount_dkk,
    md5(concat_ws('|', CAST(txn_date AS STRING), description_clean,
                       CAST(amount AS STRING), currency, account)) AS txn_id
  FROM deduped
),
categorised AS (
  SELECT
    c.*,
    r.merchant,
    r.category
  FROM converted c
  LEFT JOIN workspace.personal_finance.category_rules r
    ON c.description_clean LIKE r.pattern
  QUALIFY row_number() OVER (PARTITION BY c.txn_id ORDER BY r.priority NULLS LAST) = 1
)
SELECT
  txn_id,
  txn_date,
  CAST(date_trunc('MONTH', txn_date) AS DATE)          AS txn_month,
  account,
  description_clean                                    AS description,
  coalesce(merchant, initcap(description_clean))       AS merchant,
  coalesce(category, 'Uncategorised')                  AS category,
  currency                                             AS original_currency,
  amount                                               AS original_amount,
  amount_dkk,
  CASE WHEN category = 'Income'   THEN 'Income'
       WHEN category = 'Transfer' THEN 'Transfer'
       ELSE 'Spending' END                             AS txn_type,
  source_file
FROM categorised;

-- On-camera checks
SELECT category, count(*) AS n, sum(amount_dkk) AS total_dkk
FROM workspace.personal_finance.silver_transactions
GROUP BY category ORDER BY total_dkk;

SELECT description, amount_dkk FROM workspace.personal_finance.silver_transactions
WHERE category = 'Uncategorised';

-- 2c. LIVE FIX on camera: add the missing rules, then re-run the 2b CREATE OR REPLACE above.
-- INSERT INTO workspace.personal_finance.category_rules VALUES
--   (20, 'PHARMACY%',      'Pharmacy',  'Health & Fitness'),
--   (20, 'NEWSAGENT%',     'Newsagent', 'Eating Out'),
--   (20, 'PAYPAL *STEAM%', 'Steam',    'Entertainment');
