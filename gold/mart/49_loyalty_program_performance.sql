-- GOLD Mart | GOLD.LOYALTY_PROGRAM_PERFORMANCE
-- Monthly loyalty program health: earn/burn/expiry analysis
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE LOYALTY_PROGRAM_PERFORMANCE AS
SELECT
    d.YEAR_NUMBER,
    d.MONTH_NUMBER,
    d.MONTH_NAME,
    d.MONTH_START_DATE,
    flt.TRANSACTION_TYPE,
    -- Volume
    COUNT(DISTINCT flt.TRANSACTION_ID)                              AS TRANSACTIONS,
    COUNT(DISTINCT flt.CUSTOMER_ID)                                 AS ACTIVE_MEMBERS,
    SUM(flt.POINTS_CHANGE)                                          AS TOTAL_POINTS_CHANGE,
    SUM(IFF(flt.POINTS_CHANGE > 0, flt.POINTS_CHANGE, 0))          AS POINTS_EARNED,
    SUM(IFF(flt.POINTS_CHANGE < 0, ABS(flt.POINTS_CHANGE), 0))     AS POINTS_REDEEMED,
    SUM(IFF(flt.TRANSACTION_TYPE = 'EXPIRE', ABS(flt.POINTS_CHANGE), 0)) AS POINTS_EXPIRED,
    AVG(flt.POINTS_BALANCE_AFTER)                                   AS AVG_MEMBER_BALANCE,
    -- Financial equivalent (assume 1 point = $0.01)
    SUM(IFF(flt.POINTS_CHANGE > 0, flt.POINTS_CHANGE, 0)) * 0.01  AS ESTIMATED_POINTS_LIABILITY_EARNED,
    SUM(IFF(flt.POINTS_CHANGE < 0, ABS(flt.POINTS_CHANGE), 0)) * 0.01 AS ESTIMATED_POINTS_REDEEMED_VALUE,
    -- Redemption rate: redeemed / (redeemed + expired)
    SUM(IFF(flt.POINTS_CHANGE < 0, ABS(flt.POINTS_CHANGE), 0)) /
        NULLIF(SUM(IFF(flt.POINTS_CHANGE < 0, ABS(flt.POINTS_CHANGE), 0)) +
               SUM(IFF(flt.TRANSACTION_TYPE = 'EXPIRE', ABS(flt.POINTS_CHANGE), 0)), 0) * 100
                                                                    AS REDEMPTION_RATE_PCT,
    CURRENT_TIMESTAMP()                                             AS DW_REFRESHED_AT
FROM GOLD.FACT_LOYALTY_TRANSACTIONS flt
JOIN GOLD.DIM_DATE                  d   ON flt.DATE_SK = d.DATE_SK
GROUP BY d.YEAR_NUMBER, d.MONTH_NUMBER, d.MONTH_NAME, d.MONTH_START_DATE, flt.TRANSACTION_TYPE;
