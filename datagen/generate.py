"""PRISM lab data generator — a small, modelled warehouse for an analyst to query.

Builds a star schema as CSVs and loads it into a single DuckDB file. Small on
purpose: every table fits in your head, and every answer in the answer key is a
number you can reproduce exactly.

  python datagen/generate.py            # writes CSVs + prism.duckdb
  python datagen/selftest.py            # checks the numbers

Deterministic: the same command always produces byte-identical data, so the
answers never drift. Stdlib only for generation; DuckDB only for the load.

Tables
  dim_date          one row per calendar date, 2025-01-01 .. 2026-06-30
  dim_customer      SCD2 — a customer with a changed segment has TWO rows
  dim_product       one row per product
  dim_store         one row per store; one store closes mid-period
  dim_promo         one row per promo code
  fct_order         one row per order (includes cancelled and returned orders)
  fct_order_item    one row per order line
  bridge_order_promo one row per (order, promo) — an order can carry several
  raw_customer_list  a messy hand-maintained list, for the dedup exercise
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import os
import random
from datetime import date, datetime, timedelta
from pathlib import Path

VERSION = "1.0"
START, END = date(2025, 1, 1), date(2026, 6, 30)
N_CUSTOMERS = 1_200
N_PRODUCTS = 180
N_STORES = 14
ORDERS_PER_DAY = 110          # ~60k orders over 18 months

SEGMENTS = ["consumer", "smb", "enterprise"]
COUNTRIES = [("NL", "Netherlands"), ("DE", "Germany"), ("BE", "Belgium"),
             ("FR", "France"), ("VN", "Vietnam")]
CITIES = {"NL": ["Amsterdam", "Rotterdam", "Utrecht"], "DE": ["Berlin", "Hamburg"],
          "BE": ["Brussels", "Ghent"], "FR": ["Paris", "Lyon"],
          "VN": ["Ho Chi Minh City", "Ha Noi"]}
CATEGORIES = {
    "audio": ["headphones", "speakers", "microphones"],
    "computing": ["laptops", "monitors", "keyboards"],
    "home": ["kitchen", "lighting", "furniture"],
    "outdoor": ["camping", "cycling"],
    "wearables": ["watches", "trackers"],
}
CHANNELS = ["web", "app", "store", "phone"]
# Categories deliberately differ in both price and popularity: that is what makes
# an average-of-averages disagree with a properly weighted average (Q02, Q07).
CAT_PRICE = {"audio": 0.55, "computing": 3.10, "home": 0.80, "outdoor": 1.10,
             "wearables": 0.70}
CAT_POPULARITY = {"audio": 0.34, "computing": 0.09, "home": 0.24,
                  "outdoor": 0.15, "wearables": 0.18}
STATUSES = [("completed", 0.84), ("cancelled", 0.06), ("returned", 0.05),
            ("pending", 0.05)]
PROMOS = [("SPRING10", "Spring 10% off", "percent", 10),
          ("WELCOME5", "Welcome discount", "fixed", 5),
          ("FREESHIP", "Free shipping", "shipping", 0),
          ("BUNDLE15", "Bundle deal", "percent", 15),
          ("LOYAL20", "Loyalty reward", "percent", 20),
          ("BLACKFRI", "Black Friday", "percent", 25),
          ("CLEAR30", "Clearance", "percent", 30),
          ("VIPGIFT", "VIP gift", "fixed", 15)]
HOLIDAYS = {  # NL-centric, deliberately incomplete — Q04 notices that
    date(2025, 1, 1), date(2025, 4, 21), date(2025, 4, 27), date(2025, 5, 5),
    date(2025, 12, 25), date(2025, 12, 26), date(2026, 1, 1), date(2026, 4, 6),
    date(2026, 4, 27), date(2026, 5, 14),
}
FIRST = ["Anna", "Bram", "Chen", "Diana", "Emre", "Fatima", "Guido", "Hana",
         "Ivo", "Julia", "Karel", "Linh", "Mateo", "Nadia", "Omar", "Pia",
         "Quinn", "Rosa", "Sven", "Tessa", "Umut", "Vera", "Wout", "Yara"]
LAST = ["Bakker", "de Vries", "Nguyen", "Müller", "Dubois", "Rossi", "Kowalski",
        "Jansen", "Smit", "Okafor", "Haddad", "Larsen", "García", "Tran",
        "Visser", "Peeters", "Novak", "Silva"]


def rng(*parts) -> random.Random:
    return random.Random(int(hashlib.md5("|".join(map(str, parts)).encode()).hexdigest()[:12], 16))


def daterange(a: date, b: date):
    d = a
    while d <= b:
        yield d
        d += timedelta(days=1)


def w(path: Path, header: list[str], rows) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        cw = csv.writer(fh, lineterminator="\n")
        cw.writerow(header)
        n = 0
        for r in rows:
            cw.writerow(r)
            n += 1
    return n


def pick(r: random.Random, weighted):
    return r.choices([a for a, _ in weighted], [b for _, b in weighted], k=1)[0]


# ------------------------------------------------------------------ dim_date --
def gen_date(out: Path) -> int:
    rows = []
    for d in daterange(START, END):
        fy = d.year if d.month >= 7 else d.year - 1       # fiscal year starts 1 July
        fq = ((d.month - 7) % 12) // 3 + 1
        rows.append([
            int(d.strftime("%Y%m%d")), d.isoformat(), d.year, (d.month - 1) // 3 + 1,
            d.month, d.strftime("%B"), int(d.strftime("%V")),
            d.isoweekday(), d.strftime("%A"),
            "Y" if d.isoweekday() >= 6 else "N",
            "Y" if d in HOLIDAYS else "N",
            f"FY{fy + 1}", f"FY{fy + 1}-Q{fq}",
            date(d.year, d.month, 1).isoformat(),
        ])
    return w(out / "dim_date.csv",
             ["date_key", "full_date", "year", "quarter", "month", "month_name",
              "iso_week", "day_of_week", "day_name", "is_weekend", "is_holiday",
              "fiscal_year", "fiscal_quarter", "month_start"], rows)


# -------------------------------------------------------------- dim_customer --
def build_customers():
    """Returns (dim rows, lookup by customer_id -> list of (sk, valid_from, valid_to))."""
    rows, lookup = [], {}
    sk = 0
    for i in range(1, N_CUSTOMERS + 1):
        r = rng("cust", i)
        cid = f"C{i:05d}"
        cc, _cn = r.choice(COUNTRIES)
        city = r.choice(CITIES[cc])
        name = f"{r.choice(FIRST)} {r.choice(LAST)}"
        signup = START - timedelta(days=r.randint(0, 900)) if r.random() < 0.55 \
            else START + timedelta(days=r.randint(0, 500))
        seg = pick(r, [("consumer", 0.70), ("smb", 0.22), ("enterprise", 0.08)])
        email = f"{name.split()[0].lower()}.{i}@example.com"
        # missing contact details, drawn from their own stream so the rest of the
        # dataset is unaffected: ~4% have no city, ~2% no email on file
        nb = rng("blank", i)
        if nb.random() < 0.04:
            city = ""
        if nb.random() < 0.02:
            email = ""
        # ~9% of customers change segment once: two rows, only one is_current
        if r.random() < 0.09 and signup < date(2026, 1, 1):
            change = max(signup + timedelta(days=30),
                         START + timedelta(days=r.randint(60, 480)))
            new_seg = r.choice([s for s in SEGMENTS if s != seg])
            sk += 1
            rows.append([sk, cid, name, email, seg, cc, city,
                         signup.isoformat(), "1900-01-01", change.isoformat(), "N"])
            lookup.setdefault(cid, []).append((sk, date(1900, 1, 1), change))
            sk += 1
            rows.append([sk, cid, name, email, new_seg, cc, city,
                         signup.isoformat(), change.isoformat(), "9999-12-31", "Y"])
            lookup[cid].append((sk, change, date(9999, 12, 31)))
        else:
            sk += 1
            rows.append([sk, cid, name, email, seg, cc, city,
                         signup.isoformat(), "1900-01-01", "9999-12-31", "Y"])
            lookup.setdefault(cid, []).append((sk, date(1900, 1, 1), date(9999, 12, 31)))
    return rows, lookup


def gen_customer(out: Path, rows) -> int:
    return w(out / "dim_customer.csv",
             ["customer_sk", "customer_id", "customer_name", "email", "segment",
              "country_code", "city", "signup_date", "valid_from", "valid_to",
              "is_current"], rows)


def gen_raw_customer_list(out: Path, dim_rows) -> int:
    """A hand-maintained spreadsheet export: duplicates, casing, blanks."""
    r = rng("rawlist")
    rows = []
    current = [x for x in dim_rows if x[10] == "Y"]
    for c in current:
        name, email, cc, city = c[2], c[3], c[5], c[6]
        rows.append([c[1], name, email, cc, city, r.choice(["yes", "Yes", "y", "no", ""])])
        if r.random() < 0.06:                 # the same person, entered twice
            rows.append([c[1], name.upper(), email.upper(), cc.lower(),
                         f" {city} ", r.choice(["yes", ""])])
    r.shuffle(rows)
    return w(out / "raw_customer_list.csv",
             ["customer_id", "customer_name", "email", "country_code", "city",
              "newsletter_opt_in"], rows)


# --------------------------------------------------------------- dim_product --
def build_products():
    rows = []
    cats = list(CATEGORIES)
    for i in range(1, N_PRODUCTS + 1):
        r = rng("prod", i)
        cat = cats[i % len(cats)]
        sub = r.choice(CATEGORIES[cat])
        cost = round(r.uniform(4, 160) * CAT_PRICE[cat], 2)
        price = round(cost * r.uniform(1.25, 2.4), 2)
        rows.append([i, f"SKU-{i:04d}", f"{sub.title()[:-1] if sub.endswith('s') else sub.title()} "
                     f"Model {i}", cat, sub, cost, price,
                     "Y" if r.random() < 0.07 else "N"])
    return rows


def gen_product(out: Path, rows) -> int:
    return w(out / "dim_product.csv",
             ["product_sk", "sku", "product_name", "category", "subcategory",
              "unit_cost", "list_price", "is_discontinued"], rows)


# ----------------------------------------------------------------- dim_store --
def build_stores():
    rows = []
    for i in range(1, N_STORES + 1):
        r = rng("store", i)
        cc, _ = r.choice(COUNTRIES)
        rows.append([i, f"ST{i:02d}", f"Store {i}",
                     f"{cc}-{r.choice(['North', 'South', 'Central'])}", cc,
                     (START - timedelta(days=r.randint(200, 3000))).isoformat(),
                     "2026-02-28" if i == 9 else ""])       # store 9 closes
    return rows


def gen_store(out: Path, rows) -> int:
    return w(out / "dim_store.csv",
             ["store_sk", "store_code", "store_name", "region", "country_code",
              "opened_date", "closed_date"], rows)


# ------------------------------------------------------------------- facts ----
def gen_facts(out: Path, cust_lookup, products, stores) -> dict:
    orders, items, bridge = [], [], []
    seq = 0
    # 40 customers never order and discontinued products are never sold, so
    # "which ones have never..." has a real answer (Q03).
    cids = list(cust_lookup)[:-40]
    sellable = [p for p in products if p[7] == "N"]
    weights = [CAT_POPULARITY[p[3]] for p in sellable]
    for d in daterange(START, END):
        r = rng("day", d)
        # seasonality: December peak, weekend dip, a Black Friday spike
        f = 1.0
        if d.month == 12:
            f *= 1.45
        if d.month in (1, 2):
            f *= 0.85
        if d.isoweekday() >= 6:
            f *= 0.75
        if (d.month, d.day) in ((11, 28), (11, 27)):
            f *= 3.0
        n = max(1, int(ORDERS_PER_DAY * f * r.uniform(0.85, 1.15)))
        for _ in range(n):
            seq += 1
            oid = f"O{seq:07d}"
            # ~1.5% of orders are guest checkouts: no customer at all
            if r.random() < 0.015:
                csk = ""
            else:
                cid = r.choice(cids)
                versions = cust_lookup[cid]
                csk = next((sk for sk, vf, vt in versions if vf <= d < vt),
                           versions[-1][0])
            store = r.choice(stores)
            if store[6] and d.isoformat() > store[6]:      # closed store: no orders
                store = stores[0]
            status = pick(r, STATUSES)
            channel = pick(r, [("web", 0.46), ("app", 0.28), ("store", 0.18),
                               ("phone", 0.08)])
            nlines = pick(r, [(1, 0.52), (2, 0.28), (3, 0.13), (4, 0.07)])
            gross = 0.0
            for line in range(1, nlines + 1):
                p = r.choices(sellable, weights, k=1)[0]
                qty = pick(r, [(1, 0.74), (2, 0.18), (3, 0.06), (5, 0.02)])
                unit = round(p[6] * r.uniform(0.9, 1.0), 2)
                amount = round(unit * qty, 2)
                gross += amount
                returned = "Y" if (status == "returned" and r.random() < 0.7) else "N"
                items.append([oid, line, p[0], qty, unit, amount, returned])
            disc = round(gross * r.choice([0, 0, 0, 0.05, 0.1, 0.15]), 2)
            ship = 0.0 if gross > 75 else round(r.uniform(3.5, 7.5), 2)
            total = round(gross - disc + ship, 2)
            # ~2% of orders have an order-level adjustment the lines do not show
            if r.random() < 0.02:
                total = round(total - r.uniform(2, 25), 2)
            orders.append([oid, int(d.strftime("%Y%m%d")), csk, store[0], channel,
                           status, round(gross, 2),
                           "" if r.random() < 0.04 else f"{disc:.2f}",
                           f"{ship:.2f}", total,
                           f"{d.isoformat()} {r.randint(7, 22):02d}:{r.randint(0, 59):02d}:00"])
            # promos: 0-3 codes per order
            k = pick(r, [(0, 0.74), (1, 0.19), (2, 0.05), (3, 0.02)])
            if k:
                codes = r.sample([c for c, _, _, _ in PROMOS], k)
                for c in codes:
                    bridge.append([oid, c, round(1.0 / k, 4)])
    counts = {
        "fct_order": w(out / "fct_order.csv",
                       ["order_id", "date_key", "customer_sk", "store_sk", "channel",
                        "status", "gross_amount", "discount_amount", "shipping_fee",
                        "order_total", "ordered_at"], orders),
        "fct_order_item": w(out / "fct_order_item.csv",
                            ["order_id", "line_no", "product_sk", "quantity",
                             "unit_price", "line_amount", "is_returned"], items),
        "bridge_order_promo": w(out / "bridge_order_promo.csv",
                                ["order_id", "promo_code", "allocation_factor"], bridge),
    }
    return counts


def gen_promo(out: Path) -> int:
    return w(out / "dim_promo.csv",
             ["promo_code", "promo_name", "promo_type", "discount_pct"],
             [[c, n, t, p] for c, n, t, p in PROMOS])


# -------------------------------------------------------------------- load ----
def load_duckdb(out: Path, db_path: Path) -> None:
    import duckdb
    if db_path.exists():
        db_path.unlink()
    con = duckdb.connect(str(db_path))
    types = {
        "dim_date": "date_key INTEGER, full_date DATE, year INTEGER, quarter INTEGER, month INTEGER, month_name VARCHAR, iso_week INTEGER, day_of_week INTEGER, day_name VARCHAR, is_weekend VARCHAR, is_holiday VARCHAR, fiscal_year VARCHAR, fiscal_quarter VARCHAR, month_start DATE",
        "dim_customer": "customer_sk INTEGER, customer_id VARCHAR, customer_name VARCHAR, email VARCHAR, segment VARCHAR, country_code VARCHAR, city VARCHAR, signup_date DATE, valid_from DATE, valid_to DATE, is_current VARCHAR",
        "dim_product": "product_sk INTEGER, sku VARCHAR, product_name VARCHAR, category VARCHAR, subcategory VARCHAR, unit_cost DECIMAL(10,2), list_price DECIMAL(10,2), is_discontinued VARCHAR",
        "dim_store": "store_sk INTEGER, store_code VARCHAR, store_name VARCHAR, region VARCHAR, country_code VARCHAR, opened_date DATE, closed_date DATE",
        "dim_promo": "promo_code VARCHAR, promo_name VARCHAR, promo_type VARCHAR, discount_pct INTEGER",
        "fct_order": "order_id VARCHAR, date_key INTEGER, customer_sk INTEGER, store_sk INTEGER, channel VARCHAR, status VARCHAR, gross_amount DECIMAL(12,2), discount_amount DECIMAL(12,2), shipping_fee DECIMAL(12,2), order_total DECIMAL(12,2), ordered_at TIMESTAMP",
        "fct_order_item": "order_id VARCHAR, line_no INTEGER, product_sk INTEGER, quantity INTEGER, unit_price DECIMAL(10,2), line_amount DECIMAL(12,2), is_returned VARCHAR",
        "bridge_order_promo": "order_id VARCHAR, promo_code VARCHAR, allocation_factor DECIMAL(6,4)",
        "raw_customer_list": "customer_id VARCHAR, customer_name VARCHAR, email VARCHAR, country_code VARCHAR, city VARCHAR, newsletter_opt_in VARCHAR",
    }
    for t, cols in types.items():
        con.execute(f"CREATE TABLE {t} ({cols})")
        con.execute(f"COPY {t} FROM '{(out / (t + '.csv')).as_posix()}' (HEADER, DELIM ',', NULLSTR '')")
        n = con.execute(f"SELECT count(*) FROM {t}").fetchone()[0]
        print(f"  {t:<20} {n:>8,} rows")
    con.close()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.environ.get("PRISM_LAB_DATA", "./data"))
    ap.add_argument("--csv-only", action="store_true")
    a = ap.parse_args()
    out = Path(a.out)
    print(f"PRISM datagen v{VERSION} -> {out.resolve()}")
    gen_date(out)
    cust_rows, lookup = build_customers()
    gen_customer(out, cust_rows)
    gen_raw_customer_list(out, cust_rows)
    products = build_products()
    gen_product(out, products)
    stores = build_stores()
    gen_store(out, stores)
    gen_promo(out)
    gen_facts(out, lookup, products, stores)
    if not a.csv_only:
        load_duckdb(out, out / "prism.duckdb")
        print(f"\nready: {(out / 'prism.duckdb').resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
