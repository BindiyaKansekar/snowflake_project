-- GOLD Layer | Dimension: GOLD.DIM_PRODUCTS
-- Enriched product dimension from SILVER.PRODUCT_CATALOG
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE DIM_PRODUCTS AS
SELECT
    p.PRODUCT_SK,
    p.PRODUCT_ID,
    p.SKU,
    p.PRODUCT_NAME,
    p.BRAND,
    p.CATEGORY_ID,
    p.CATEGORY_NAME,
    p.PARENT_CATEGORY_NAME,
    p.TOP_CATEGORY_NAME,
    p.CATEGORY_PATH,
    p.SUPPLIER_ID,
    p.SUPPLIER_NAME,
    p.UNIT_COST,
    p.UNIT_PRICE,
    p.MARGIN_PCT,
    p.IS_ACTIVE,
    p.IS_DIGITAL,
    p.WEIGHT_KG,
    -- Derived price bands
    CASE
        WHEN p.UNIT_PRICE < 10    THEN 'UNDER_$10'
        WHEN p.UNIT_PRICE < 25    THEN '$10-$25'
        WHEN p.UNIT_PRICE < 50    THEN '$25-$50'
        WHEN p.UNIT_PRICE < 100   THEN '$50-$100'
        WHEN p.UNIT_PRICE < 250   THEN '$100-$250'
        WHEN p.UNIT_PRICE < 500   THEN '$250-$500'
        ELSE 'OVER_$500'
    END                                        AS PRICE_BAND,
    CASE
        WHEN p.MARGIN_PCT >= 60 THEN 'HIGH'
        WHEN p.MARGIN_PCT >= 30 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                        AS MARGIN_BAND,
    CURRENT_TIMESTAMP()                        AS DW_REFRESHED_AT
FROM SILVER.PRODUCT_CATALOG p;
