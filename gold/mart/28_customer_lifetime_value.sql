-- GOLD Mart | GOLD.CUSTOMER_LIFETIME_VALUE
-- Historical and predicted CLV per customer
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE CUSTOMER_LIFETIME_VALUE AS
WITH order_stats AS (
    SELECT
        o.CUSTOMER_ID,
        MIN(o.ORDER_DATE)                                     AS FIRST_ORDER_DATE,
        MAX(o.ORDER_DATE)                                     AS LAST_ORDER_DATE,
        COUNT(DISTINCT o.ORDER_ID)                            AS TOTAL_ORDERS,
        SUM(o.TOTAL_AMOUNT)                                   AS LIFETIME_REVENUE,
        AVG(o.TOTAL_AMOUNT)                                   AS AVG_ORDER_VALUE,
        DATEDIFF('day', MIN(o.ORDER_DATE), MAX(o.ORDER_DATE)) AS CUSTOMER_LIFESPAN_DAYS,
        DATEDIFF('day', MAX(o.ORDER_DATE), CURRENT_DATE())    AS DAYS_SINCE_LAST_ORDER,
        STDDEV(o.TOTAL_AMOUNT)                                AS ORDER_VALUE_STDDEV
    FROM SILVER.ORDERS o
    WHERE o.ORDER_STATUS NOT IN ('CANCELLED', 'RETURNED')
    GROUP BY o.CUSTOMER_ID
),
return_stats AS (
    SELECT
        o.CUSTOMER_ID,
        COUNT(DISTINCT r.RETURN_ID)     AS TOTAL_RETURNS,
        SUM(r.REFUND_AMOUNT)            AS TOTAL_REFUNDS
    FROM SILVER.RETURNS r
    JOIN SILVER.ORDERS o ON r.ORDER_ID = o.ORDER_ID
    GROUP BY o.CUSTOMER_ID
)
SELECT
    c.CUSTOMER_SK,
    os.CUSTOMER_ID,
    c.FULL_NAME,
    c.CUSTOMER_TIER,
    c.REGISTRATION_DATE,
    os.FIRST_ORDER_DATE,
    os.LAST_ORDER_DATE,
    os.TOTAL_ORDERS,
    os.LIFETIME_REVENUE,
    os.AVG_ORDER_VALUE,
    os.CUSTOMER_LIFESPAN_DAYS,
    os.DAYS_SINCE_LAST_ORDER,
    COALESCE(rs.TOTAL_RETURNS, 0)                            AS TOTAL_RETURNS,
    COALESCE(rs.TOTAL_REFUNDS, 0)                            AS TOTAL_REFUNDS,
    os.LIFETIME_REVENUE - COALESCE(rs.TOTAL_REFUNDS, 0)     AS NET_LIFETIME_REVENUE,
    -- Purchase frequency: orders per year active
    IFF(os.CUSTOMER_LIFESPAN_DAYS > 0,
        os.TOTAL_ORDERS / (os.CUSTOMER_LIFESPAN_DAYS / 365.0),
        os.TOTAL_ORDERS)                                     AS ORDERS_PER_YEAR,
    -- Projected CLV (5-year): avg_order * annualised frequency * 5
    os.AVG_ORDER_VALUE *
        IFF(os.CUSTOMER_LIFESPAN_DAYS > 0,
            os.TOTAL_ORDERS / (os.CUSTOMER_LIFESPAN_DAYS / 365.0),
            os.TOTAL_ORDERS) * 5                             AS PROJECTED_CLV_5YR,
    -- Churn risk (4-band: more granular than previous 3-band)
    CASE
        WHEN os.DAYS_SINCE_LAST_ORDER <= 30  THEN 'LOW'
        WHEN os.DAYS_SINCE_LAST_ORDER <= 60  THEN 'MEDIUM'
        WHEN os.DAYS_SINCE_LAST_ORDER <= 120 THEN 'MEDIUM_HIGH'
        WHEN os.DAYS_SINCE_LAST_ORDER <= 180 THEN 'HIGH'
        ELSE 'CHURNED'
    END                                                      AS CHURN_RISK,
    -- CLV tier
    CASE
        WHEN os.LIFETIME_REVENUE >= 10000 THEN 'PLATINUM'
        WHEN os.LIFETIME_REVENUE >= 2500  THEN 'GOLD'
        WHEN os.LIFETIME_REVENUE >= 500   THEN 'SILVER'
        ELSE 'BRONZE'
    END                                                      AS CLV_TIER,
    CURRENT_TIMESTAMP()                                      AS DW_REFRESHED_AT
FROM order_stats os
LEFT JOIN return_stats      rs ON os.CUSTOMER_ID = rs.CUSTOMER_ID
LEFT JOIN GOLD.DIM_CUSTOMERS c ON os.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE;
