# Data Talks by Ana

Code for the YouTube channel **Data Talks by Ana** ([@datatalksbyana](https://www.youtube.com/@datatalksbyana)).

The channel is about learning data engineering in public, one real project at a time. The projects are mostly finance, and they are built to run on [Databricks Free Edition](https://www.databricks.com/learn/free-edition).

Every dataset in this repo is **synthetic**. Do not commit real bank exports or other personal data.

## Projects

| # | Folder | What you build |
|---|--------|----------------|
| 01 | [01-personal-finance-dashboard](01-personal-finance-dashboard/) | A personal finance dashboard from a messy bank CSV: bronze, silver, and gold tables, an AI/BI dashboard, and a Genie space. |

## Use this repo in Databricks Free Edition

Free Edition is serverless, so there is no cluster to create. Your workspace already includes the `workspace` catalog.

1. Sign in to your Databricks Free Edition workspace.
2. Open **Workspace > Create > Git folder**.
3. Paste this repository URL:

   `https://github.com/anatalksdata/anatalksdata_projects`

4. Leave the branch as `main` and create the folder.
5. Open a project folder and follow its README. Start with [01-personal-finance-dashboard](01-personal-finance-dashboard/).

A Git folder puts the SQL, the sample CSV, and the generator script in your workspace. Free Edition blocks outbound downloads from notebooks, so you still upload the CSV into a Unity Catalog volume from the UI before the bronze step. Each project README says exactly where.

## Layout

Each project is a numbered folder with its own README, `sql/` (run the files in order), `data/` (synthetic sample only), and `scripts/` when a generator is included.
