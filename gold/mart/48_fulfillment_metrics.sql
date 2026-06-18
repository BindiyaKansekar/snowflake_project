-- GOLD Mart | GOLD.FULFILLMENT_METRICS
-- End-to-end order fulfillment performance: processing, ship, and delivery SLAs
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE FULFILLMENT_METRICS AS
SELECT
    sh.CARRIER,
    sh.SHIPPING_METHOD,
    sh.DESTINATION_COUNTRY,
    d.YEAR_NUMBER,
    d.QUARTER_NAME,
    d.MONTH_NUMBER,
    d.MONTH_NAME,
    COUNT(DISTINCT sh.SHIPMENT_ID)                                    AS TOTAL_SHIPMENTS,
    -- Delivery performance
    COUNT(DISTINCT IFF(sh.ACTUAL_DELIVERY IS NOT NULL, sh.SHIPMENT_ID, NULL)) AS DELIVERED,
    COUNT(DISTINCT IFF(sh.IS_LATE, sh.SHIPMENT_ID, NULL))             AS LATE_DELIVERIES,
    COUNT(DISTINCT IFF(sh.IS_LATE, sh.SHIPMENT_ID, NULL)) /
        NULLIF(COUNT(DISTINCT IFF(sh.ACTUAL_DELIVERY IS NOT NULL, sh.SHIPMENT_ID, NULL)), 0) * 100
                                                                      AS LATE_DELIVERY_RATE_PCT,
    -- Timing
    AVG(sh.DAYS_TO_DELIVER)                                           AS AVG_DAYS_TO_DELIVER,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY sh.DAYS_TO_DELIVER)  AS MEDIAN_DAYS_TO_DELIVER,
    PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY sh.DAYS_TO_DELIVER)  AS P90_DAYS_TO_DELIVER,
    AVG(sh.DAYS_LATE)                                                 AS AVG_DAYS_LATE,
    -- Cost
    SUM(sh.SHIPPING_COST)                                             AS TOTAL_SHIPPING_COST,
    AVG(sh.SHIPPING_COST)                                             AS AVG_SHIPPING_COST,
    SUM(sh.SHIPPING_COST) / NULLIF(SUM(sh.WEIGHT_KG), 0)            AS COST_PER_KG,
    -- SLA achievement (carrier-dependent promise)
    SUM(IFF(NOT sh.IS_LATE OR sh.IS_LATE IS NULL, 1, 0)) /
        NULLIF(COUNT(*), 0) * 100                                     AS ON_TIME_DELIVERY_PCT,
    CURRENT_TIMESTAMP()                                               AS DW_REFRESHED_AT
FROM GOLD.FACT_SHIPMENTS sh
JOIN GOLD.DIM_DATE       d ON sh.SHIP_DATE_SK = d.DATE_SK
GROUP BY sh.CARRIER, sh.SHIPPING_METHOD, sh.DESTINATION_COUNTRY,
         d.YEAR_NUMBER, d.QUARTER_NAME, d.MONTH_NUMBER, d.MONTH_NAME;
