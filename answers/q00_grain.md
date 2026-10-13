The ansswers:
bridge_order_promo: One row of bridge_order_promo is one promo code applied to a specific order.
dim_date: One row of dim_date is one calendar date.
dim_customer: One row of dim_customer is one historical version of a customer profile.
dim_product: One row of dim_product is one product.
dim_promo: One row of dim_promo is one promo code.
dim_store: One row of dim_store is one store.
fct_order: One row of fct_order is one order - including cancalled and returned ones.
fct_order_item: One row of fct_order_item is one order line.
raw_customer_list: One row of raw_customer_list is one raw customer record from the spreadsheet.

source .venv/bin/activate
duckdb data/prism.duckdb