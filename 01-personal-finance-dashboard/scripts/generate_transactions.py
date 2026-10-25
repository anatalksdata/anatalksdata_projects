"""Generate a SYNTHETIC (all-English text) personal-finance dataset (6 months, DKK) for the
'Data Talks by Ana' video 1. No real personal data. Deterministic (seed=42).

Columns: date, description, amount, currency, account
Deliberate "real bank export" mess for the silver layer to fix:
  - inconsistent description casing / extra whitespace / store numbers
  - a few lowercase currency codes ('dkk')
  - a handful of EUR card transactions (Berlin trip) -> convert to DKK
  - ~8 exact duplicate rows (overlapping export)
  - a few merchants no rule matches -> 'Uncategorised' (fix live on camera)
"""
import csv, random, datetime as dt
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "sample_transactions.csv"

random.seed(42)
START, END = dt.date(2026, 4, 1), dt.date(2026, 9, 30)
rows = []

def add(d, desc, amt, cur="DKK", acct="Current Account"):
    rows.append([d.isoformat(), desc, f"{amt:.2f}", cur, acct])

def messy(s):
    r = random.random()
    if r < 0.15: return s.lower()
    if r < 0.25: return s.title()
    if r < 0.35: return "  " + s + "  "
    return s

def last_bank_day(y, m):
    d = (dt.date(y, m % 12 + 1, 1) if m < 12 else dt.date(y + 1, 1, 1)) - dt.timedelta(days=1)
    while d.weekday() >= 5: d -= dt.timedelta(days=1)
    return d

months = [(2026, m) for m in range(4, 10)]
for y, m in months:
    first = dt.date(y, m, 1)
    # income (salary paid last bank day of the PREVIOUS month is typical in DK;
    # keep it simple: last bank day of the month)
    add(last_bank_day(y, m), "SALARY ACME FINANCE LTD", round(random.uniform(32400, 32600), 2))
    # move money to budget + savings accounts
    add(first, "TRANSFER TO BILLS ACCOUNT", -12500.00)
    add(first, "TRANSFER FROM CURRENT ACCOUNT", 12500.00, acct="Bills Account")
    add(first + dt.timedelta(days=1), "TRANSFER TO SAVINGS", -3000.00)
    # fixed bills from budget account
    add(first, "RENT CITY HOUSING ASSOCIATION", -9850.00, acct="Bills Account")
    add(first + dt.timedelta(days=4), "CITY POWER ELECTRICITY DD", -round(random.uniform(380, 720), 2), acct="Bills Account")
    add(first + dt.timedelta(days=2), "TELENOR MOBILE DD", -199.00, acct="Bills Account")
    add(first + dt.timedelta(days=9), "SAFEGUARD INSURANCE DD", -485.00, acct="Bills Account")
    add(first + dt.timedelta(days=4), "FITNESS WORLD", -299.00, acct="Bills Account")
    # subscriptions on credit card
    add(first + dt.timedelta(days=6), "NETFLIX.COM", -129.00, acct="Credit Card")
    add(first + dt.timedelta(days=11), "SPOTIFY P1A2B3", -119.00, acct="Credit Card")
    # card settlement: pay off credit card from Current Account at month end-ish
    ndays = (last_bank_day(y, m) - first).days + 1
    def rday(): return first + dt.timedelta(days=random.randrange(ndays))
    groceries = [("Card purchase FRESHMART {n} NORTH", 60, 420), ("VALUE GROCER WESTSIDE", 80, 520),
                 ("SUPERSTORE {n} HARBOUR", 120, 650), ("LIDL STORE {n}", 50, 380),
                 ("GOURMET MARKET PARKSIDE", 90, 480), ("CORNER COOP {n}", 40, 300)]
    for _ in range(random.randint(12, 16)):
        t, lo, hi = random.choice(groceries)
        add(rday(), messy(t.format(n=random.randint(1000, 9999))), -round(random.uniform(lo, hi), 2))
    for _ in range(random.randint(4, 7)):
        t, lo, hi = random.choice([("TRAVEL CARD TOP-UP", 100, 200), ("NATIONAL RAIL TICKET", 40, 380),
                                    ("CIRCLE K {n}", 300, 650)])
        add(rday(), messy(t.format(n=random.randint(100, 999))), -round(random.uniform(lo, hi), 2))
    for _ in range(random.randint(5, 9)):
        t, lo, hi = random.choice([("JOE & THE JUICE {n}", 55, 110), ("WOLT", 140, 320),
                                    ("THE CAKE HOUSE BAKERY", 45, 120), ("SUSHI BAR WESTSIDE", 180, 420),
                                    ("MOBILEPAY TO Sofie", 75, 250)])
        acct = random.choice(["Current Account", "Credit Card"])
        add(rday(), messy(t.format(n=random.randint(10, 99))), -round(random.uniform(lo, hi), 2), acct=acct)
    for _ in range(random.randint(2, 4)):
        t, lo, hi = random.choice([("BEAUTY & CARE {n}", 90, 450), ("H&M {n} HIGH STREET", 150, 700),
                                    ("ZALANDO", 300, 900), ("IKEA WEST", 200, 1500)])
        add(rday(), messy(t.format(n=random.randint(100, 999))), -round(random.uniform(lo, hi), 2), acct="Credit Card")
    # unmatched merchants -> Uncategorised in first silver run
    for _ in range(random.randint(1, 2)):
        t, lo, hi = random.choice([("NEWSAGENT CENTRAL STATION", 25, 90), ("PAYPAL *STEAMGAMES", 80, 300),
                                    ("PHARMACY EASTSIDE", 60, 260)])
        add(rday(), t, -round(random.uniform(lo, hi), 2))
    # MobilePay from a friend (income-ish, not salary)
    if random.random() < 0.6:
        add(rday(), "MOBILEPAY FROM Sofie", round(random.uniform(100, 300), 2))
    # pay credit card bill
    cc_bill = round(random.uniform(2500, 4500), 2)
    add(last_bank_day(y, m), "CREDIT CARD PAYMENT", -cc_bill)
    add(last_bank_day(y, m), "PAYMENT RECEIVED THANK YOU", cc_bill, acct="Credit Card")

# a refund
add(dt.date(2026, 6, 18), "ZALANDO REFUND", 449.00, acct="Credit Card")
# Berlin trip, August, EUR on credit card
for d, desc, eur in [(dt.date(2026, 8, 14), "BVG BERLIN", 9.90), (dt.date(2026, 8, 14), "HOTEL CENTRAL BERLIN", 238.00),
                     (dt.date(2026, 8, 15), "LIDL BERLIN", 23.47), (dt.date(2026, 8, 15), "CAFE EINSTEIN BERLIN", 31.80),
                     (dt.date(2026, 8, 16), "BVG BERLIN", 9.90), (dt.date(2026, 8, 16), "MUSEUM ISLAND BERLIN", 24.00)]:
    add(d, desc, -eur, cur="EUR", acct="Credit Card")

# dedupe accidental natural duplicates, then inject deliberate ones
seen, uniq = set(), []
for r in rows:
    k = tuple(r)
    if k not in seen: seen.add(k); uniq.append(r)
rows = uniq
for r in random.sample(rows, 6): r[3] = r[3].lower() if r[3] == "DKK" else r[3]
dups = random.sample([r for r in rows if r[0] >= "2026-06-25" and r[0] <= "2026-07-05"], 8)
rows += [list(r) for r in dups]
rows.sort(key=lambda r: (r[0], r[4], r[1]))

with open(OUT, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["date", "description", "amount", "currency", "account"])
    w.writerows(rows)
print(len(rows), "rows,", len(dups), "deliberate duplicates")
