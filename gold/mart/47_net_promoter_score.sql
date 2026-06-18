-- GOLD Mart | GOLD.NET_PROMOTER_SCORE
-- NPS calculation from product reviews (rating >= 4 = Promoter, <= 2 = Detractor)
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE NET_PROMOTER_SCORE AS
WITH review_nps AS (
    SELECT
        r.REVIEW_DATE,
        DATE_TRUNC('MONTH', r.REVIEW_DATE)             AS REVIEW_MONTH,
        p.CATEGORY_NAME,
        p.TOP_CATEGORY_NAME,
        CASE
            WHEN r.RATING >= 4 THEN 'PROMOTER'
            WHEN r.RATING <= 2 THEN 'DETRACTOR'
            ELSE 'PASSIVE'
        END                                            AS NPS_CATEGORY,
        r.REVIEW_ID,
        r.CUSTOMER_ID,
        r.RATING,
        r.IS_VERIFIED_PURCHASE
    FROM GOLD.FACT_REVIEWS r
    JOIN GOLD.DIM_PRODUCTS p ON r.PRODUCT_ID = p.PRODUCT_ID
)
SELECT
    REVIEW_MONTH,
    TOP_CATEGORY_NAME,
    CATEGORY_NAME,
    COUNT(*)                                                             AS TOTAL_RESPONSES,
    SUM(IFF(NPS_CATEGORY = 'PROMOTER', 1, 0))                          AS PROMOTERS,
    SUM(IFF(NPS_CATEGORY = 'PASSIVE', 1, 0))                           AS PASSIVES,
    SUM(IFF(NPS_CATEGORY = 'DETRACTOR', 1, 0))                         AS DETRACTORS,
    SUM(IFF(IS_VERIFIED_PURCHASE, 1, 0))                               AS VERIFIED_RESPONSES,
    -- NPS formula: (promoters - detractors) / total * 100
    (SUM(IFF(NPS_CATEGORY = 'PROMOTER', 1, 0)) -
     SUM(IFF(NPS_CATEGORY = 'DETRACTOR', 1, 0))) /
     NULLIF(COUNT(*), 0) * 100                                         AS NPS_SCORE,
    AVG(RATING)                                                        AS AVG_RATING,
    -- Verified-only NPS
    (SUM(IFF(NPS_CATEGORY = 'PROMOTER' AND IS_VERIFIED_PURCHASE, 1, 0)) -
     SUM(IFF(NPS_CATEGORY = 'DETRACTOR' AND IS_VERIFIED_PURCHASE, 1, 0))) /
     NULLIF(SUM(IFF(IS_VERIFIED_PURCHASE, 1, 0)), 0) * 100            AS VERIFIED_NPS_SCORE,
    CURRENT_TIMESTAMP()                                                AS DW_REFRESHED_AT
FROM review_nps
GROUP BY REVIEW_MONTH, TOP_CATEGORY_NAME, CATEGORY_NAME;
