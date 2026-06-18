-- GOLD Mart | GOLD.SEASONAL_TRENDS
-- Seasonal revenue patterns by week, month, and quarter
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE SEASONAL_TRENDS AS
SELECT
    d.MONTH_NUMBER,
    d.MONTH_NAME,
    d.QUARTER_NUMBER,
    d.QUARTER_NAME,
    d.WEEK_OF_YEAR,
    d.IS_HOLIDAY,
    d.HOLIDAY_NAME,
    d.YEAR_NUMBER,
    -- Revenue
    SUM(fs.TOTAL_AMOUNT)                                              AS TOTAL_REVENUE,
    COUNT(DISTINCT fs.ORDER_ID)                                       AS ORDER_COUNT,
    AVG(fs.TOTAL_AMOUNT)                                              AS AOV,
    COUNT(DISTINCT fs.CUSTOMER_ID)                                    AS UNIQUE_CUSTOMERS,
    -- Index vs annual average (base = 100)
    SUM(fs.TOTAL_AMOUNT) /
        AVG(SUM(fs.TOTAL_AMOUNT)) OVER (PARTITION BY d.YEAR_NUMBER) * 100 AS REVENUE_SEASONALITY_INDEX,
    -- Same week prior year
    LAG(SUM(fs.TOTAL_AMOUNT), 52)
        OVER (ORDER BY d.YEAR_NUMBER, d.WEEK_OF_YEAR)                AS SAME_WEEK_LY_REVENUE,
    -- 4-week moving average
    AVG(SUM(fs.TOTAL_AMOUNT))
        OVER (ORDER BY d.YEAR_NUMBER, d.WEEK_OF_YEAR ROWS BETWEEN 3 PRECEDING AND CURRENT ROW)
                                                                      AS REVENUE_4W_MA,
    CURRENT_TIMESTAMP()                                               AS DW_REFRESHED_AT
FROM GOLD.FACT_SALES fs
JOIN GOLD.DIM_DATE   d ON fs.DATE_SK = d.DATE_SK
GROUP BY d.MONTH_NUMBER, d.MONTH_NAME, d.QUARTER_NUMBER, d.QUARTER_NAME,
         d.WEEK_OF_YEAR, d.IS_HOLIDAY, d.HOLIDAY_NAME, d.YEAR_NUMBER;
