-- GOLD Mart | GOLD.GEOGRAPHIC_PERFORMANCE
-- Revenue by geography (country, state, city)
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE GEOGRAPHIC_PERFORMANCE AS
SELECT
    a.COUNTRY_CODE,
    a.STATE_PROVINCE,
    a.CITY,
    d.YEAR_NUMBER,
    d.QUARTER_NAME,
    d.MONTH_NUMBER,
    COUNT(DISTINCT fs.ORDER_ID)                               AS ORDERS,
    COUNT(DISTINCT fs.CUSTOMER_ID)                            AS UNIQUE_CUSTOMERS,
    SUM(fs.TOTAL_AMOUNT)                                      AS GROSS_REVENUE,
    SUM(fs.NET_REVENUE)                                       AS NET_REVENUE,
    AVG(fs.TOTAL_AMOUNT)                                      AS AOV,
    SUM(fs.DISCOUNT_AMOUNT)                                   AS TOTAL_DISCOUNTS,
    SUM(fs.TOTAL_AMOUNT) /
        SUM(SUM(fs.TOTAL_AMOUNT)) OVER (PARTITION BY d.YEAR_NUMBER, d.MONTH_NUMBER, a.COUNTRY_CODE) * 100
                                                              AS STATE_SHARE_OF_COUNTRY_PCT,
    RANK() OVER (PARTITION BY d.YEAR_NUMBER, d.MONTH_NUMBER ORDER BY SUM(fs.TOTAL_AMOUNT) DESC)
                                                              AS REVENUE_RANK,
    CURRENT_TIMESTAMP()                                       AS DW_REFRESHED_AT
FROM GOLD.FACT_SALES      fs
JOIN GOLD.DIM_CUSTOMERS   c ON fs.CUSTOMER_SK = c.CUSTOMER_SK
JOIN GOLD.DIM_ADDRESSES   a ON c.CUSTOMER_ID  = a.CUSTOMER_ID AND a.ADDRESS_TYPE IN ('SHIPPING', 'BOTH')
JOIN GOLD.DIM_DATE        d ON fs.DATE_SK     = d.DATE_SK
GROUP BY a.COUNTRY_CODE, a.STATE_PROVINCE, a.CITY, d.YEAR_NUMBER, d.QUARTER_NAME, d.MONTH_NUMBER;
