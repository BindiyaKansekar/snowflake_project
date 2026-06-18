-- GOLD Mart | GOLD.CATEGORY_REVENUE
-- Revenue and margin breakdown by category hierarchy
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE CATEGORY_REVENUE AS
SELECT
    cat.CATEGORY_ID,
    cat.CATEGORY_NAME,
    cat.PARENT_CATEGORY_NAME,
    cat.TOP_CATEGORY_NAME,
    cat.CATEGORY_PATH,
    d.YEAR_NUMBER,
    d.QUARTER_NAME,
    d.MONTH_NUMBER,
    d.MONTH_NAME,
    COUNT(DISTINCT foi.ORDER_ID)                           AS ORDERS,
    SUM(foi.QUANTITY)                                      AS UNITS_SOLD,
    SUM(foi.LINE_TOTAL)                                    AS GROSS_REVENUE,
    SUM(foi.DISCOUNT_AMOUNT)                               AS DISCOUNTS,
    SUM(foi.LINE_TOTAL - foi.DISCOUNT_AMOUNT)              AS NET_REVENUE,
    SUM(foi.GROSS_PROFIT)                                  AS GROSS_PROFIT,
    AVG(foi.MARGIN_PCT)                                    AS AVG_MARGIN_PCT,
    COUNT(DISTINCT foi.PRODUCT_ID)                         AS DISTINCT_PRODUCTS_SOLD,
    SUM(foi.LINE_TOTAL) /
        SUM(SUM(foi.LINE_TOTAL)) OVER (PARTITION BY d.YEAR_NUMBER, d.MONTH_NUMBER) * 100 AS CATEGORY_REVENUE_SHARE_PCT,
    CURRENT_TIMESTAMP()                                    AS DW_REFRESHED_AT
FROM GOLD.FACT_ORDER_ITEMS foi
JOIN GOLD.DIM_PRODUCTS     p   ON foi.PRODUCT_ID  = p.PRODUCT_ID
JOIN GOLD.DIM_CATEGORIES   cat ON p.CATEGORY_ID   = cat.CATEGORY_ID
JOIN GOLD.DIM_DATE         d   ON foi.DATE_SK      = d.DATE_SK
GROUP BY cat.CATEGORY_ID, cat.CATEGORY_NAME, cat.PARENT_CATEGORY_NAME, cat.TOP_CATEGORY_NAME,
         cat.CATEGORY_PATH, d.YEAR_NUMBER, d.QUARTER_NAME, d.MONTH_NUMBER, d.MONTH_NAME;
