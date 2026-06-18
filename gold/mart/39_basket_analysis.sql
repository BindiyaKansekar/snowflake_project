-- GOLD Mart | GOLD.BASKET_ANALYSIS
-- Product co-occurrence (market basket) — top product pairs by support/lift
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE BASKET_ANALYSIS AS
WITH order_products AS (
    SELECT DISTINCT ORDER_ID, PRODUCT_ID
    FROM GOLD.FACT_ORDER_ITEMS
),
product_pairs AS (
    SELECT
        a.PRODUCT_ID    AS PRODUCT_A_ID,
        b.PRODUCT_ID    AS PRODUCT_B_ID,
        COUNT(DISTINCT a.ORDER_ID) AS CO_OCCURRENCE_COUNT
    FROM order_products a
    JOIN order_products b ON a.ORDER_ID = b.ORDER_ID AND a.PRODUCT_ID < b.PRODUCT_ID
    GROUP BY a.PRODUCT_ID, b.PRODUCT_ID
),
product_totals AS (
    SELECT PRODUCT_ID, COUNT(DISTINCT ORDER_ID) AS ORDER_COUNT
    FROM order_products
    GROUP BY PRODUCT_ID
),
total_orders AS (
    SELECT COUNT(DISTINCT ORDER_ID) AS N FROM order_products
)
SELECT
    pp.PRODUCT_A_ID,
    pa.PRODUCT_NAME                                              AS PRODUCT_A_NAME,
    pp.PRODUCT_B_ID,
    pb.PRODUCT_NAME                                              AS PRODUCT_B_NAME,
    pp.CO_OCCURRENCE_COUNT,
    tot.N                                                        AS TOTAL_ORDERS,
    pp.CO_OCCURRENCE_COUNT / tot.N                               AS SUPPORT,
    pp.CO_OCCURRENCE_COUNT / NULLIF(pta.ORDER_COUNT, 0)         AS CONFIDENCE_A_GIVEN_B,
    pp.CO_OCCURRENCE_COUNT / NULLIF(ptb.ORDER_COUNT, 0)         AS CONFIDENCE_B_GIVEN_A,
    -- Lift: how much more likely they occur together vs. by chance
    (pp.CO_OCCURRENCE_COUNT * tot.N) /
        NULLIF(pta.ORDER_COUNT * ptb.ORDER_COUNT, 0)            AS LIFT,
    CURRENT_TIMESTAMP()                                         AS DW_REFRESHED_AT
FROM product_pairs          pp
CROSS JOIN total_orders     tot
JOIN  product_totals        pta ON pp.PRODUCT_A_ID = pta.PRODUCT_ID
JOIN  product_totals        ptb ON pp.PRODUCT_B_ID = ptb.PRODUCT_ID
JOIN  GOLD.DIM_PRODUCTS     pa  ON pp.PRODUCT_A_ID = pa.PRODUCT_ID
JOIN  GOLD.DIM_PRODUCTS     pb  ON pp.PRODUCT_B_ID = pb.PRODUCT_ID
WHERE pp.CO_OCCURRENCE_COUNT >= 5   -- minimum support threshold
ORDER BY LIFT DESC
LIMIT 10000;
