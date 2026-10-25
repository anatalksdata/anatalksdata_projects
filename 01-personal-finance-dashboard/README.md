# 01 · Personal finance dashboard

Six months of messy bank transactions become a dashboard you can ask questions. You land the CSV as-is, clean it, and publish gold tables that an AI/BI dashboard and a Genie space both read.

```text
CSV → volume → bronze → silver → gold → dashboard + Genie
```

**The data is synthetic.** `data/sample_transactions.csv` is generated, not a real bank export. It is safe to upload to a Free Edition workspace. If you later swap in your own export, keep that file out of git and do not publish it.

## What you build

| Step | File | What it creates |
|------|------|-----------------|
| Setup | `sql/00_setup.sql` | Schema `workspace.personal_finance` and volume `raw` |
| Bronze | `sql/01_bronze.sql` | `bronze_transactions`: every column stays STRING, plus `source_file` and `ingested_at` |
| Silver | `sql/02_silver.sql` | `category_rules` and `silver_transactions`: typed, trimmed, de-duplicated, EUR converted to DKK, categorised |
| Gold | `sql/03_gold.sql` | `gold_monthly_cashflow`, `gold_monthly_category_spend`, `gold_top_merchants`, `gold_daily_spend` |
| Genie comments | `sql/04_genie_metadata.sql` | Table and column comments Genie uses to read the model |
| Dashboard queries | `sql/05_dashboard_datasets.sql` | KPI, top-10 merchant, and subscription datasets |

The sample covers April–September 2026, in Danish kroner, with a short Berlin trip in euros. Columns are `date`, `description`, `amount`, `currency`, and `account` (Current Account, Bills Account, Credit Card). The file is deliberately untidy: mixed casing, extra spaces, store numbers, a few `dkk` codes, eight exact duplicate rows from an overlapping export, and a handful of merchants with no category rule yet.

## Run it in Databricks Free Edition

Use the SQL editor (serverless warehouse) or a notebook whose default language is SQL. Run each file from top to bottom. Later files depend on the tables the earlier files create.

### 1. Schema and volume

Run `sql/00_setup.sql`. It creates:

- catalog.schema `workspace.personal_finance`
- volume `workspace.personal_finance.raw`

### 2. Upload the CSV

Free Edition does not download files from the internet inside a notebook, so upload through the UI:

1. **New > Add or upload data > Upload files to a volume**
2. Choose the volume `workspace.personal_finance.raw`
3. Upload `data/sample_transactions.csv` from this folder

Catalog Explorer works too: open the volume and use **Upload**.

Optional check (SQL editor or a notebook):

```sql
LIST '/Volumes/workspace/personal_finance/raw/';
```

### 3. Bronze

Run `sql/01_bronze.sql`.

Bronze keeps the bank file as text on purpose. `read_files` reads the volume, and `_metadata.file_name` records which file each row came from. If a future export changes shape, bronze still loads and silver is where you fix it.

Expect **289** raw rows from the sample.

### 4. Silver

Run `sql/02_silver.sql`. This is the cleaning step:

1. **Types and text.** `TRY_CAST` turns date and amount into real types (bad values become null instead of failing the job). Descriptions are trimmed, upper-cased, collapsed to single spaces, and stripped of a leading `CARD PURCHASE `.
2. **Duplicates.** Eight identical rows from the overlapping export are removed with `QUALIFY row_number()`. The sample goes from 289 rows to **281**. A real export usually has a transaction id; use that instead of matching on the whole row, or two identical coffees on the same day would collapse into one.
3. **Currency.** EUR amounts are converted at a fixed 7.46 DKK per EUR. The krone is pegged to the euro, which is enough for a personal dashboard.
4. **Categories.** A small `category_rules` table (pattern, merchant, category, priority) replaces a long `CASE`. The best-priority `LIKE` match wins. Transfers between your own accounts are labelled `Transfer` and stay out of spending.

The first run leaves **10** rows as `Uncategorised`: newsagent, pharmacy, and PayPal Steam purchases. That is intentional. Add the three rules at the bottom of `02_silver.sql` (section 2c), then re-run the `CREATE OR REPLACE TABLE ... silver_transactions` statement. Those 10 rows should drop to **0**.

### 5. Gold

Run `sql/03_gold.sql`. Gold answers questions. `spend_dkk` is positive money out (refunds reduce it). Transfers are excluded everywhere.

- `gold_monthly_cashflow` — income, spending, net, and savings rate per month
- `gold_monthly_category_spend` — the stacked bar of spend by month and category
- `gold_top_merchants` — merchants ranked over the whole period
- `gold_daily_spend` — daily spend plus a month-to-date running total

On the sample, before the uncategorised-rule fix, spending sits around 18–20k DKK a month from April to June and climbs to about 22.5k in August and September. August includes the Berlin weekend. The savings rate falls from about 45% to about 31%.

### 6. Comments for Genie

Run `sql/04_genie_metadata.sql`. The comments describe what `amount_dkk`, `txn_type`, and `savings_rate` mean, including that transfers are not spending. Genie reads those comments when it writes SQL.

## Dashboard

In the workspace: **New > Dashboard**. On the **Data** tab, add the gold tables plus the queries in `sql/05_dashboard_datasets.sql`.

| Widget | Source |
|--------|--------|
| Counters: last month spend, six-month average spend, last month savings rate | KPI query in `05_dashboard_datasets.sql` |
| Stacked bar, month × category | `gold_monthly_category_spend` (`txn_month`, `spend_dkk`, color = `category`) |
| Line, month-to-date spend | `gold_daily_spend` (`mtd_spend_dkk` by `txn_date`) |
| Table, top 10 merchants | top-10 query |
| Bar, subscriptions (Netflix and Spotify) | subscriptions query |
| Filter | category and/or month |

Publish the dashboard when the widgets match.

## Genie

Create a **Genie space** on `silver_transactions` and the four gold tables. You can also open Genie from the published dashboard if that entry point is available in your workspace.

Questions that work well against this model:

- Where did my spending go up in August compared to July?
- How much did I spend on eating out per month?
- What are my recurring subscriptions and what do they cost per year?

Genie is only as good as the tables under it. If an answer treats a transfer as spending, the `txn_type` comment and the gold filters are what correct it.

## Regenerate the sample

`scripts/generate_transactions.py` uses only the Python standard library and `random.seed(42)`, so it always writes the same file:

```bash
python scripts/generate_transactions.py
```

Run that from this project folder. It overwrites `data/sample_transactions.csv`.

## Optional local check

`sql/tests/test_duckdb.py` runs the same SQL files on DuckDB and rewrites the few statements that are Databricks-only (`read_files`, volumes, column comments). From this project folder, with DuckDB installed (`pip install duckdb`):

```bash
python sql/tests/test_duckdb.py
```

A good run ends with bronze 289 rows, silver 281 rows, 10 uncategorised, then `(281, 0)` after the extra category rules.
