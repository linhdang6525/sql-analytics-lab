# Q09 — Leadership Analysis Pack

## 1. Completed revenue — H1 comparison

- **Numbers:** H1 2025: **4,476,125.75**; H1 2026: **4,464,733.48**; change: **−0.25%**.
- **Period:** 1 January–30 June 2025 versus 1 January–30 June 2026.
- **Definition:** Sum of `order_total` for completed orders in each six-month period; growth is calculated relative to H1 2025 revenue.
- **Meaning:** Completed revenue was essentially flat, declining slightly year over year. This is a like-for-like period comparison, unlike comparing all of 2025 with only half of 2026.

## 2. Calendar-year completed revenue

- **Number:** **9,736,875.65**.
- **Period:** 1 January–31 December 2025.
- **Definition:** Sum of `order_total` for orders with `status = 'completed'` during calendar year 2025.
- **Meaning:** This is the full-calendar-year completed revenue figure for the board. It should not be compared directly with H1 2026 revenue as if both covered the same duration.

## 3. Store performance — ST13

- **Number:** **347.26 revenue per active day**.
- **Period:** Store activity from 19 May 2018 to 30 June 2026, using the date range in the Q08 query.
- **Definition:** Completed-order revenue attributed to ST13 divided by the number of days between its recorded opening and closing dates, using the query's day-count convention.
- **Meaning:** ST13 has the lowest reported revenue per active day in the Q08 result. This alone is not enough to recommend closure; compare stores over the same period and consider operating costs and local conditions first.

## 4. Category revenue versus margin

- **Numbers:** Computing revenue: **4,016,974.03**; Outdoor profit margin: **44.27%**.
- **Period:** The period covered by the Q08 completed-order dataset; confirm the exact date range before external distribution.
- **Definition:** Category revenue is the sum of `line_amount` for lines in completed orders. The reported margin is calculated as (category revenue − estimated product cost) / category revenue × 100.
- **Meaning:** Computing generates the highest total revenue, while Outdoor has the highest reported margin. The category selling the most is not necessarily the category retaining the highest share of revenue as profit.

## 5. Discounts — recorded versus estimated

- **Numbers:** Recorded discounts: **491,678.94**; estimated missing discounts: **22,312.40** across **1,275 orders**; estimated total: **513,991.34**.
- **Period:** Calendar year 2025, completed orders only.
- **Definition:** Recorded discounts sum non-NULL `discount_amount` values. Missing discounts are estimated from `gross_amount − order_total + shipping_fee` for completed orders with NULL discount values; the estimated total adds the recorded and estimated amounts.
- **Meaning:** Recorded discounts may understate the actual total because 1,275 completed orders have missing discount values. The adjustment is an estimate and must be validated before being treated as a confirmed financial figure.

## What these numbers don't tell us

These figures do not establish profitability at the business level, explain the causes of revenue changes, prove that promotions caused revenue, or establish that a store should close. Store comparisons require consistent periods and operating context. Category margin depends on the accuracy of the product-cost proxy and excludes any costs not represented in the calculation. The discount adjustment relies on an inferred formula and unresolved missing data. Confirm the date coverage and validate these assumptions before using the pack for formal decisions.