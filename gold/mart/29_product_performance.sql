-- GOLD Mart | GOLD.PRODUCT_PERFORMANCE
-- Rolling product-level sales, margin, and review KPIs
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE PRODUCT_PERFORMANCE AS
SELECT
    p.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.BRAND,
    p.CATEGORY_NAME,
    p.TOP_CATEGORY_NAME,
    p.UNIT_PRICE,
    p.UNIT_COST,
    p.MARGIN_PCT                                                       AS LIST_MARGIN_PCT,
    -- Sales metrics
    SUM(foi.QUANTITY)                                                  AS TOTAL_UNITS_SOLD,
    COUNT(DISTINCT foi.ORDER_ID)                                       AS ORDERS_WITH_PRODUCT,
    SUM(foi.LINE_TOTAL)                                                AS GROSS_REVENUE,
    SUM(foi.DISCOUNT_AMOUNT)                                           AS TOTAL_DISCOUNTS,
    SUM(foi.LINE_TOTAL - foi.DISCOUNT_AMOUNT)                          AS NET_REVENUE,
    AVG(foi.UNIT_PRICE)                                                AS AVG_SELLING_PRICE,
    SUM(foi.GROSS_PROFIT)                                              AS TOTAL_GROSS_PROFIT,
    AVG(foi.MARGIN_PCT)                                                AS AVG_REALIZED_MARGIN_PCT,
    -- Review metrics
    COUNT(fr.REVIEW_ID)                                                AS REVIEW_COUNT,
    AVG(fr.RATING)                                                     AS AVG_RATING,
    SUM(IFF(fr.IS_POSITIVE, 1, 0))                                     AS POSITIVE_REVIEWS,
    SUM(IFF(fr.IS_NEGATIVE, 1, 0))                                     AS NEGATIVE_REVIEWS,
    -- Return metrics
    SUM(IFF(foi.RETURN_FLAG, foi.QUANTITY, 0))                         AS UNITS_RETURNED,
    IFF(SUM(foi.QUANTITY) > 0,
        SUM(IFF(foi.RETURN_FLAG, foi.QUANTITY, 0)) / SUM(foi.QUANTITY) * 100,
        NULL)                                                          AS RETURN_RATE_PCT,
    -- Ranking
    RANK() OVER (ORDER BY SUM(foi.LINE_TOTAL) DESC)                    AS REVENUE_RANK,
    RANK() OVER (ORDER BY SUM(foi.QUANTITY) DESC)                      AS UNITS_RANK,
    CURRENT_TIMESTAMP()                                                AS DW_REFRESHED_AT
FROM GOLD.DIM_PRODUCTS p
LEFT JOIN GOLD.FACT_ORDER_ITEMS foi ON p.PRODUCT_ID = foi.PRODUCT_ID
LEFT JOIN GOLD.FACT_REVIEWS     fr  ON p.PRODUCT_ID = fr.PRODUCT_ID
GROUP BY p.PRODUCT_ID, p.PRODUCT_NAME, p.BRAND, p.CATEGORY_NAME, p.TOP_CATEGORY_NAME,
         p.UNIT_PRICE, p.UNIT_COST, p.MARGIN_PCT;
