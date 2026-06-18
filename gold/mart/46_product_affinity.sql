-- GOLD Mart | GOLD.PRODUCT_AFFINITY
-- Customer-level product category affinity scores for personalization
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE PRODUCT_AFFINITY AS
WITH customer_category_spend AS (
    SELECT
        foi.CUSTOMER_ID,
        p.TOP_CATEGORY_NAME                          AS CATEGORY,
        SUM(foi.LINE_TOTAL)                          AS CATEGORY_SPEND,
        COUNT(DISTINCT foi.ORDER_ID)                 AS CATEGORY_ORDERS,
        SUM(foi.QUANTITY)                            AS UNITS_BOUGHT,
        MAX(foi.ORDER_DATE)                          AS LAST_PURCHASE_IN_CATEGORY
    FROM GOLD.FACT_ORDER_ITEMS foi
    JOIN GOLD.DIM_PRODUCTS     p ON foi.PRODUCT_ID = p.PRODUCT_ID
    GROUP BY foi.CUSTOMER_ID, p.TOP_CATEGORY_NAME
),
customer_totals AS (
    SELECT CUSTOMER_ID, SUM(CATEGORY_SPEND) AS TOTAL_SPEND
    FROM customer_category_spend
    GROUP BY CUSTOMER_ID
)
SELECT
    ccs.CUSTOMER_ID,
    c.FULL_NAME,
    c.CUSTOMER_TIER,
    ccs.CATEGORY,
    ccs.CATEGORY_SPEND,
    ccs.CATEGORY_ORDERS,
    ccs.UNITS_BOUGHT,
    ccs.LAST_PURCHASE_IN_CATEGORY,
    ct.TOTAL_SPEND,
    ccs.CATEGORY_SPEND / NULLIF(ct.TOTAL_SPEND, 0) * 100         AS CATEGORY_SPEND_SHARE_PCT,
    RANK() OVER (PARTITION BY ccs.CUSTOMER_ID ORDER BY ccs.CATEGORY_SPEND DESC) AS CATEGORY_RANK_FOR_CUSTOMER,
    -- Affinity score (0-100): spend share + recency bonus
    LEAST(100, ccs.CATEGORY_SPEND / NULLIF(ct.TOTAL_SPEND, 0) * 100 +
        CASE
            WHEN DATEDIFF('day', ccs.LAST_PURCHASE_IN_CATEGORY, CURRENT_DATE()) <= 30 THEN 10
            WHEN DATEDIFF('day', ccs.LAST_PURCHASE_IN_CATEGORY, CURRENT_DATE()) <= 90 THEN 5
            ELSE 0
        END)                                                      AS AFFINITY_SCORE,
    CURRENT_TIMESTAMP()                                           AS DW_REFRESHED_AT
FROM customer_category_spend    ccs
JOIN customer_totals            ct ON ccs.CUSTOMER_ID = ct.CUSTOMER_ID
LEFT JOIN GOLD.DIM_CUSTOMERS    c  ON ccs.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE;
