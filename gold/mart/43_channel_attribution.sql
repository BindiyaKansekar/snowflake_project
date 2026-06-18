-- GOLD Mart | GOLD.CHANNEL_ATTRIBUTION
-- Revenue attribution by sales channel and first-touch / last-touch
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE CHANNEL_ATTRIBUTION AS
SELECT
    fs.CHANNEL,
    d.YEAR_NUMBER,
    d.QUARTER_NAME,
    d.MONTH_NUMBER,
    d.MONTH_NAME,
    COUNT(DISTINCT fs.ORDER_ID)                                   AS ORDERS,
    COUNT(DISTINCT fs.CUSTOMER_ID)                                AS UNIQUE_CUSTOMERS,
    COUNT(DISTINCT IFF(fs.IS_FIRST_ORDER, fs.CUSTOMER_ID, NULL)) AS NEW_CUSTOMERS_ACQUIRED,
    SUM(fs.TOTAL_AMOUNT)                                          AS GROSS_REVENUE,
    SUM(fs.NET_REVENUE)                                           AS NET_REVENUE,
    AVG(fs.TOTAL_AMOUNT)                                          AS AOV,
    SUM(fs.DISCOUNT_AMOUNT)                                       AS TOTAL_DISCOUNTS,
    -- Channel share of total revenue in period
    SUM(fs.TOTAL_AMOUNT) /
        SUM(SUM(fs.TOTAL_AMOUNT)) OVER (PARTITION BY d.YEAR_NUMBER, d.MONTH_NUMBER) * 100
                                                                  AS CHANNEL_REVENUE_SHARE_PCT,
    -- Channel share of new customers
    COUNT(DISTINCT IFF(fs.IS_FIRST_ORDER, fs.CUSTOMER_ID, NULL)) /
        SUM(COUNT(DISTINCT IFF(fs.IS_FIRST_ORDER, fs.CUSTOMER_ID, NULL)))
            OVER (PARTITION BY d.YEAR_NUMBER, d.MONTH_NUMBER) * 100
                                                                  AS NEW_CUSTOMER_SHARE_PCT,
    -- Return rate by channel
    SUM(IFF(fs.ORDER_STATUS = 'RETURNED', fs.TOTAL_AMOUNT, 0)) /
        NULLIF(SUM(fs.TOTAL_AMOUNT), 0) * 100                    AS RETURN_RATE_PCT,
    CURRENT_TIMESTAMP()                                           AS DW_REFRESHED_AT
FROM GOLD.FACT_SALES fs
JOIN GOLD.DIM_DATE   d ON fs.DATE_SK = d.DATE_SK
GROUP BY fs.CHANNEL, d.YEAR_NUMBER, d.QUARTER_NAME, d.MONTH_NUMBER, d.MONTH_NAME;
