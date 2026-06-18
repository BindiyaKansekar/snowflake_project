-- GOLD Mart | GOLD.SUPPLIER_PERFORMANCE
-- Supplier scorecard: delivery, quality, and cost metrics
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE SUPPLIER_PERFORMANCE AS
SELECT
    s.SUPPLIER_ID,
    s.SUPPLIER_NAME,
    s.COUNTRY,
    s.REGION,
    s.SUPPLIER_RATING,
    s.SUPPLIER_STATUS_LABEL,
    s.PAYMENT_TERMS_DAYS,
    s.LEAD_TIME_DAYS                                                        AS CONTRACTED_LEAD_DAYS,
    -- Order volume
    COUNT(DISTINCT fso.PO_NUMBER)                                          AS TOTAL_PO_COUNT,
    SUM(fso.QUANTITY_ORDERED)                                              AS TOTAL_UNITS_ORDERED,
    SUM(fso.QUANTITY_RECEIVED)                                             AS TOTAL_UNITS_RECEIVED,
    SUM(fso.TOTAL_COST)                                                    AS TOTAL_SPEND,
    -- Delivery performance
    COUNT(DISTINCT IFF(fso.IS_LATE_DELIVERY, fso.PO_NUMBER, NULL))        AS LATE_DELIVERIES,
    COUNT(DISTINCT IFF(fso.IS_LATE_DELIVERY, fso.PO_NUMBER, NULL)) /
        NULLIF(COUNT(DISTINCT fso.PO_NUMBER), 0) * 100                    AS LATE_DELIVERY_RATE_PCT,
    AVG(fso.DAYS_TO_DELIVER)                                              AS AVG_LEAD_TIME_ACTUAL,
    AVG(fso.DELIVERY_VARIANCE_DAYS)                                        AS AVG_DELIVERY_VARIANCE_DAYS,
    -- Fill rate
    SUM(fso.QUANTITY_RECEIVED) /
        NULLIF(SUM(fso.QUANTITY_ORDERED), 0) * 100                        AS FILL_RATE_PCT,
    -- Quality (using return rate as proxy)
    COUNT(DISTINCT fr.RETURN_ID)                                          AS RETURNS_FROM_SUPPLIER_PRODUCTS,
    -- Distinct products supplied
    COUNT(DISTINCT fso.PRODUCT_ID)                                        AS DISTINCT_PRODUCTS,
    RANK() OVER (ORDER BY s.SUPPLIER_RATING DESC)                         AS RATING_RANK,
    CURRENT_TIMESTAMP()                                                    AS DW_REFRESHED_AT
FROM GOLD.DIM_SUPPLIERS        s
LEFT JOIN GOLD.FACT_SUPPLIER_ORDERS fso ON s.SUPPLIER_ID = fso.SUPPLIER_ID
LEFT JOIN GOLD.FACT_ORDER_ITEMS     foi ON fso.PRODUCT_ID = foi.PRODUCT_ID
LEFT JOIN GOLD.FACT_RETURNS         fr  ON foi.ORDER_ID   = fr.ORDER_ID
GROUP BY s.SUPPLIER_ID, s.SUPPLIER_NAME, s.COUNTRY, s.REGION, s.SUPPLIER_RATING,
         s.SUPPLIER_STATUS_LABEL, s.PAYMENT_TERMS_DAYS, s.LEAD_TIME_DAYS;
