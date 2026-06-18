-- GOLD Mart | GOLD.CUSTOMER_CHURN_INDICATORS
-- Early-warning churn signals for marketing re-engagement
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE CUSTOMER_CHURN_INDICATORS AS
WITH customer_metrics AS (
    SELECT
        o.CUSTOMER_ID,
        COUNT(DISTINCT o.ORDER_ID)                                   AS TOTAL_ORDERS,
        SUM(o.TOTAL_AMOUNT)                                          AS LIFETIME_REVENUE,
        MAX(o.ORDER_DATE)                                            AS LAST_ORDER_DATE,
        MIN(o.ORDER_DATE)                                            AS FIRST_ORDER_DATE,
        DATEDIFF('day', MAX(o.ORDER_DATE), CURRENT_DATE())           AS RECENCY_DAYS,
        AVG(DATEDIFF('day',
            LAG(o.ORDER_DATE) OVER (PARTITION BY o.CUSTOMER_ID ORDER BY o.ORDER_DATE),
            o.ORDER_DATE))                                           AS AVG_DAYS_BETWEEN_ORDERS,
        COUNT(DISTINCT DATE_TRUNC('month', o.ORDER_DATE))            AS ACTIVE_MONTHS
    FROM SILVER.ORDERS o
    WHERE o.ORDER_STATUS NOT IN ('CANCELLED')
    GROUP BY o.CUSTOMER_ID
),
session_metrics AS (
    SELECT
        ws.CUSTOMER_ID,
        COUNT(DISTINCT ws.SESSION_ID)                                AS SESSIONS_LAST_90D,
        AVG(ws.SESSION_DURATION_SEC)                                 AS AVG_SESSION_DURATION,
        MAX(DATE(ws.SESSION_START))                                  AS LAST_VISIT_DATE
    FROM SILVER.WEB_SESSIONS ws
    WHERE ws.SESSION_START >= DATEADD('day', -90, CURRENT_DATE())
    GROUP BY ws.CUSTOMER_ID
)
SELECT
    c.CUSTOMER_SK,
    cm.CUSTOMER_ID,
    c.FULL_NAME,
    c.CUSTOMER_TIER,
    cm.TOTAL_ORDERS,
    cm.LIFETIME_REVENUE,
    cm.LAST_ORDER_DATE,
    cm.RECENCY_DAYS,
    cm.AVG_DAYS_BETWEEN_ORDERS,
    cm.ACTIVE_MONTHS,
    COALESCE(sm.SESSIONS_LAST_90D, 0)                               AS SESSIONS_LAST_90D,
    sm.LAST_VISIT_DATE,
    COALESCE(sm.LAST_VISIT_DATE, cm.LAST_ORDER_DATE)                AS LAST_ACTIVITY_DATE,
    -- Churn score: higher = higher risk (0-100)
    LEAST(100,
        CASE WHEN cm.RECENCY_DAYS > 365 THEN 50
             WHEN cm.RECENCY_DAYS > 180 THEN 35
             WHEN cm.RECENCY_DAYS > 90  THEN 20
             ELSE 0
        END +
        CASE WHEN COALESCE(sm.SESSIONS_LAST_90D, 0) = 0 THEN 25
             WHEN sm.SESSIONS_LAST_90D <= 2              THEN 15
             ELSE 0
        END +
        CASE WHEN cm.TOTAL_ORDERS = 1 THEN 15
             WHEN cm.TOTAL_ORDERS <= 3 THEN 10
             ELSE 0
        END
    )                                                               AS CHURN_SCORE,
    CASE
        WHEN cm.RECENCY_DAYS > 365                                  THEN 'CHURNED'
        WHEN cm.RECENCY_DAYS > 180 OR COALESCE(sm.SESSIONS_LAST_90D, 0) = 0 THEN 'HIGH_RISK'
        WHEN cm.RECENCY_DAYS > 90                                   THEN 'AT_RISK'
        ELSE 'ACTIVE'
    END                                                             AS CHURN_SEGMENT,
    CURRENT_TIMESTAMP()                                             AS DW_REFRESHED_AT
FROM customer_metrics        cm
LEFT JOIN session_metrics    sm ON cm.CUSTOMER_ID = sm.CUSTOMER_ID
LEFT JOIN GOLD.DIM_CUSTOMERS c  ON cm.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE;
