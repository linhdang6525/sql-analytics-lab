# Q00 — Journal
## Stuff I learned

fct_order and fct_order_item look similar (both have order_id) but they're not the same grain - one row of fct_order is 1 order, one row of fct_order_item is 1 line. Sounds obvious writing it now but I didn't actually think about this until I picked order O0000596 and saw 1 row in fct_order vs 3 rows in fct_order_item. Made it click.

Also got Q7 wrong at first. Guessed the dim_customer row count mismatch (1302 vs 1200) was because a customer can change segment over time - when that happens, the system adds a new row with the updated segment instead of overwriting the old one, so the old row stays in the table. That's why the total row count (1302) ends up higher than the actual number of customers (1200).

## What was hard

Kept trusting column names too much — assumed customer_sk / order_id were primary keys just because they look like IDs, without actually checking. Now I run this before using any column as a join key or to sort:

    SELECT COUNT(*) - COUNT(DISTINCT col), COUNT(*) - COUNT(col) FROM table;

Going to do this by default before Q03 instead of assuming.

## Note to self
Don't trust a column name. Check it.

## New concept I picked up: SCD (Slowly Changing Dimension)

This came out of Q7, from figuring out why dim_customer has 1302 rows but only 1200 distinct customer_id. Turns out there's a whole concept behind it.

Basically - when info about something in a dimension table changes over time (like a customer's segment), the warehouse has to decide what to do with the old row. Found out there's a few standard ways to handle this:

- Type 1: just overwrite the old value. Simple, but you lose history - can't tell what it used to be.
- Type 2: keep the old row, add a new row for the new value. This is what dim_customer does - valid_from/valid_to/is_current mark which row is the current one. Costs more storage but keeps full history.
- Type 3: add an extra column for "previous value" - only keeps 1 change back, not full history.

dim_customer here is Type 2. That's why customer_sk (surrogate key, one per row/version) is different from customer_id (the actual customer) - one customer_id can map to multiple customer_sk if they changed segment.
