"""Check that your PRISM database matches the one the answer key was written against.

  python datagen/selftest.py

If everything passes, every number in answers/ANSWERS.md applies to your copy. If
something fails, re-run `python datagen/generate.py` — the data is deterministic, so
identical commands always produce identical data.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

CHECKS: list[tuple[str, str, object]] = [
    ("dim_date rows", "SELECT count(*) FROM dim_date", 546),
    ("dim_customer rows", "SELECT count(*) FROM dim_customer", 1302),
    ("distinct customers", "SELECT count(DISTINCT customer_id) FROM dim_customer", 1200),
    ("current customer rows", "SELECT count(*) FROM dim_customer WHERE is_current = 'Y'", 1200),
    ("dim_product rows", "SELECT count(*) FROM dim_product", 180),
    ("dim_store rows", "SELECT count(*) FROM dim_store", 14),
    ("dim_promo rows", "SELECT count(*) FROM dim_promo", 8),
    ("fct_order rows", "SELECT count(*) FROM fct_order", 55423),
    ("fct_order_item rows", "SELECT count(*) FROM fct_order_item", 96883),
    ("bridge_order_promo rows", "SELECT count(*) FROM bridge_order_promo", 19572),
    ("raw_customer_list rows", "SELECT count(*) FROM raw_customer_list", 1269),
    ("completed orders", "SELECT count(*) FROM fct_order WHERE status = 'completed'", 46460),
    ("completed revenue",
     "SELECT round(sum(order_total), 2) FROM fct_order WHERE status = 'completed'",
     14201609.13),
    ("guest orders", "SELECT count(*) FROM fct_order WHERE customer_sk IS NULL", 840),
    ("orders with no discount recorded",
     "SELECT count(*) FROM fct_order WHERE discount_amount IS NULL", 2253),
    ("customers with no city", "SELECT count(*) FROM dim_customer WHERE city IS NULL", 53),
    ("products never sold",
     "SELECT count(*) FROM dim_product p WHERE NOT EXISTS "
     "(SELECT 1 FROM fct_order_item i WHERE i.product_sk = p.product_sk)", 9),
    ("duplicate ids in raw list",
     "SELECT count(*) FROM (SELECT customer_id FROM raw_customer_list "
     "GROUP BY 1 HAVING count(*) > 1)", 69),
    ("date range start", "SELECT min(full_date)::VARCHAR FROM dim_date", "2025-01-01"),
    ("date range end", "SELECT max(full_date)::VARCHAR FROM dim_date", "2026-06-30"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", default=os.environ.get("PRISM_LAB_DATA", "./data") + "/prism.duckdb")
    a = ap.parse_args()
    p = Path(a.db)
    if not p.exists():
        print(f"No database at {p} — run: python datagen/generate.py")
        return 2
    try:
        import duckdb
    except ImportError:
        print("duckdb is not installed — run: pip install -r requirements.txt")
        return 2

    con = duckdb.connect(str(p), read_only=True)
    failed = 0
    print(f"PRISM selftest — {p}")
    for name, sql, expected in CHECKS:
        try:
            got = con.execute(sql).fetchone()[0]
        except Exception as e:
            print(f"  [FAIL] {name:<34} query error: {str(e)[:50]}")
            failed += 1
            continue
        if isinstance(expected, float):
            ok = abs(float(got) - expected) < 0.01
        else:
            ok = str(got) == str(expected)
        if ok:
            print(f"  [PASS] {name:<34} {got}")
        else:
            print(f"  [FAIL] {name:<34} got {got}, expected {expected}")
            failed += 1
    con.close()
    print()
    if failed:
        print(f"{failed} check(s) failed. Re-run: python datagen/generate.py")
        return 1
    print("ALL PASS — every number in answers/ANSWERS.md applies to your copy.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
