# Database Schema (Star Schema – Retail Orders)

> Mở file này trong VS Code rồi nhấn `Ctrl+Shift+V` (Markdown Preview) để xem sơ đồ.
> Nếu preview không hiện sơ đồ, cài extension **"Markdown Preview Mermaid Support"** (bierner.markdown-mermaid).

```mermaid
erDiagram
    dim_customer ||--o{ fct_order : "customer_sk (nullable)"
    dim_date     ||--o{ fct_order : "date_key"
    dim_store    ||--o{ fct_order : "store_sk"
    fct_order    ||--|{ fct_order_item : "order_id"
    dim_product  ||--o{ fct_order_item : "product_sk"
    fct_order    ||--o{ bridge_order_promo : "order_id"
    dim_promo    ||--o{ bridge_order_promo : "promo_code"
    raw_customer_list }o..o{ dim_customer : "customer_id (logic, không có FK)"

    fct_order {
        string order_id PK
        int date_key FK
        int customer_sk FK "nullable (840 NULL)"
        int store_sk FK
        string channel "web|app|store|phone"
        string status "completed|cancelled|pending|returned"
        decimal gross_amount
        decimal discount_amount "nullable"
        decimal shipping_fee
        decimal order_total
        datetime ordered_at
    }

    fct_order_item {
        string order_id PK, FK
        int line_no PK
        int product_sk FK
        int quantity
        decimal unit_price
        decimal line_amount
        string is_returned "Y|N"
    }

    bridge_order_promo {
        string order_id PK, FK
        string promo_code PK, FK
        decimal allocation_factor "1 | 0.5 | 0.3333"
    }

    dim_customer {
        int customer_sk PK "surrogate key"
        string customer_id "business key (SCD2, lặp lại)"
        string customer_name
        string email "nullable"
        string segment "consumer|smb|enterprise"
        string country_code
        string city "nullable"
        date signup_date
        date valid_from "SCD2"
        date valid_to "SCD2, 9999-12-31 = current"
        string is_current "Y|N"
    }

    dim_date {
        int date_key PK "yyyymmdd"
        date full_date UK
        int year
        int quarter
        int month
        string month_name
        int iso_week
        int day_of_week
        string day_name
        string is_weekend "Y|N"
        string is_holiday "Y|N"
        string fiscal_year
        string fiscal_quarter
        date month_start
    }

    dim_product {
        int product_sk PK
        string sku UK
        string product_name
        string category
        string subcategory
        decimal unit_cost
        decimal list_price
        string is_discontinued "Y|N"
    }

    dim_store {
        int store_sk PK
        string store_code UK
        string store_name
        string region
        string country_code
        date opened_date
        date closed_date "nullable"
    }

    dim_promo {
        string promo_code PK
        string promo_name
        string promo_type "percent|fixed|shipping"
        int discount_pct
    }

    raw_customer_list {
        string customer_id "không unique (69 dòng trùng)"
        string customer_name
        string email "nullable"
        string country_code
        string city "nullable"
        string newsletter_opt_in "dirty: yes|Yes|y|no|NULL"
    }
```

## Grain (mỗi dòng đại diện cho)

| Bảng | Grain | Số dòng |
|---|---|---|
| `fct_order` | 1 đơn hàng | 55,423 |
| `fct_order_item` | 1 dòng sản phẩm trong đơn (`order_id`, `line_no`) | 96,883 |
| `bridge_order_promo` | 1 promo áp dụng cho 1 đơn (`order_id`, `promo_code`) | 19,572 |
| `dim_customer` | 1 phiên bản của khách hàng (SCD Type 2) | 1,302 (1,200 khách) |
| `dim_date` | 1 ngày | 546 |
| `dim_product` | 1 sản phẩm | 180 |
| `dim_store` | 1 cửa hàng | 14 |
| `dim_promo` | 1 mã khuyến mãi | 8 |
| `raw_customer_list` | bảng staging/thô, không thuộc star schema | 1,269 |

## Ghi chú quan trọng

- **Toàn vẹn FK**: đã kiểm tra, không có khoá mồ côi ở bất kỳ quan hệ nào ở trên.
- **`dim_customer` là SCD2**: `customer_id` xuất hiện nhiều lần (102 khách có >1 phiên bản). Fact trỏ tới `customer_sk` (đúng phiên bản), không phải `customer_id`. Lọc bản hiện tại bằng `is_current = 'Y'`.
- **`fct_order.customer_sk` có 840 giá trị NULL** (đơn không gắn khách) → dùng LEFT JOIN, không dùng INNER JOIN nếu không muốn mất đơn.
- **`bridge_order_promo` là quan hệ N-N** giữa đơn và promo: một đơn có thể có nhiều promo. `allocation_factor` dùng để chia đều số tiền giảm giá, tránh đếm trùng khi JOIN (14,608 đơn có promo, 19,572 dòng bridge). Nhân `discount_amount * allocation_factor` khi tổng hợp theo promo.
- **`raw_customer_list`** có `customer_id` trùng, email/city thiếu và `newsletter_opt_in` không chuẩn (`yes`/`Yes`/`y`) → cần làm sạch trước khi nạp vào `dim_customer`.
- `dim_date.fiscal_quarter` lệch so với quý lịch (01/2025 → `FY2025-Q3`), tức năm tài chính bắt đầu vào tháng 7.
