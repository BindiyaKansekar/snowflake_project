-- GOLD Mart | GOLD.CAMPAIGN_EFFECTIVENESS
-- Marketing campaign ROI and attribution metrics
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE CAMPAIGN_EFFECTIVENESS AS
SELECT
    cam.CAMPAIGN_ID,
    cam.CAMPAIGN_NAME,
    cam.CAMPAIGN_TYPE,
    cam.CHANNEL,
    cam.START_DATE,
    cam.END_DATE,
    cam.CAMPAIGN_DURATION_DAYS,
    cam.BUDGET_AMOUNT,
    cam.SPEND_AMOUNT,
    cam.IMPRESSIONS,
    cam.CLICKS,
    cam.CONVERSIONS,
    cam.REVENUE_ATTRIBUTED,
    cam.CTR_PCT,
    cam.CONVERSION_RATE_PCT,
    cam.COST_PER_CONVERSION,
    cam.ROAS_PCT,
    -- Orders from campaign-sourced sessions
    COUNT(DISTINCT fws.ORDER_ID)                           AS ORDERS_TRACKED,
    COUNT(DISTINCT fws.CUSTOMER_SK)                        AS UNIQUE_CUSTOMERS_REACHED,
    -- Revenue from campaign sessions that converted
    SUM(IFF(fws.CONVERTED, fs.TOTAL_AMOUNT, 0))           AS TRACKED_REVENUE,
    AVG(IFF(fws.CONVERTED, fws.SESSION_DURATION_SEC, NULL)) AS AVG_SESSION_DURATION_CONVERTED,
    SUM(fws.PAGE_VIEWS)                                   AS TOTAL_PAGE_VIEWS,
    AVG(fws.IS_BOUNCE::NUMBER)                            AS BOUNCE_RATE_PCT,
    IFF(cam.SPEND_AMOUNT > 0,
        cam.REVENUE_ATTRIBUTED / cam.SPEND_AMOUNT,
        NULL)                                             AS ROAS_RATIO,
    IFF(cam.SPEND_AMOUNT > 0,
        (cam.REVENUE_ATTRIBUTED - cam.SPEND_AMOUNT) / cam.SPEND_AMOUNT * 100,
        NULL)                                             AS ROI_PCT,
    RANK() OVER (ORDER BY IFF(cam.SPEND_AMOUNT > 0, cam.REVENUE_ATTRIBUTED / cam.SPEND_AMOUNT, 0) DESC) AS ROAS_RANK,
    CURRENT_TIMESTAMP()                                   AS DW_REFRESHED_AT
FROM GOLD.DIM_CAMPAIGNS cam
LEFT JOIN GOLD.FACT_WEB_SESSIONS fws ON cam.CAMPAIGN_ID = fws.CAMPAIGN_ID
LEFT JOIN GOLD.FACT_SALES        fs  ON fws.ORDER_ID    = fs.ORDER_ID
GROUP BY cam.CAMPAIGN_ID, cam.CAMPAIGN_NAME, cam.CAMPAIGN_TYPE, cam.CHANNEL, cam.START_DATE,
         cam.END_DATE, cam.CAMPAIGN_DURATION_DAYS, cam.BUDGET_AMOUNT, cam.SPEND_AMOUNT,
         cam.IMPRESSIONS, cam.CLICKS, cam.CONVERSIONS, cam.REVENUE_ATTRIBUTED, cam.CTR_PCT,
         cam.CONVERSION_RATE_PCT, cam.COST_PER_CONVERSION, cam.ROAS_PCT;
