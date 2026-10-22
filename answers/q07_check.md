# Q07 — Data Quality Checks

## 1. Before aggregating a fact table

- Check the distribution of important categorical columns, especially order statuses, using `GROUP BY` and `COUNT(*)`.
- Identify which records should be included in the metric before calculating totals.
- For revenue reporting, filter to completed orders when using the operational revenue definition established for this analysis.

## 2. Before and after every join

- Count rows before and after each join, and compare the results.
- Check whether the join key is unique on the lookup side and whether the join changes the intended grain of the data.
- Use `COUNT(DISTINCT ...)` to verify the number of unique business entities, such as orders or customers.
- Investigate unexpected row multiplication or row loss before aggregating measures.

## 3. Whenever a metric is a ratio or an average

- Identify the numerator and denominator before calculating the metric.
- Check whether groups have different numbers of observations before averaging group-level averages.
- Calculate an overall average from the underlying observations rather than averaging group averages unless equal weighting is intended.
- Use `NULLIF` when a denominator could be zero.

## 4. Whenever a number is broken down into parts

- Compare the sum of the parts with the overall total.
- Check whether the categories overlap or whether the same entity can appear in multiple groups.
- For customer counts, distinguish between a version identifier such as `customer_sk` and a business identifier such as `customer_id`.
- When using an SCD Type 2 dimension, decide whether the analysis requires the customer's attributes at the time of the event or their current attributes.

## 5. Before publishing any revenue figure

- Define the revenue metric and document which order statuses are included or excluded.
- Reconcile order-level totals against line-item amounts, discounts, and shipping fees.
- Investigate missing values and unexplained differences rather than automatically treating `NULL` as zero.
- Check whether joins to bridge tables duplicate revenue, and apply allocation factors when the business definition requires revenue attribution.
- Confirm the reporting definition and unresolved reconciliation issues with Finance before presenting the figure as recognized accounting revenue.