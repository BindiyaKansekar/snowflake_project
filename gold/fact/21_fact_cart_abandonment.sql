-- GOLD Layer | Fact: GOLD.FACT_CART_ABANDONMENT
-- Grain: one row per session where cart was started but not converted
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE FACT_CART_ABANDONMENT AS
WITH cart_sessions AS (
    SELECT
        ce.SRC_SESSION_ID          AS SESSION_ID,
        ce.SRC_CUSTOMER_ID         AS CUSTOMER_ID,
        MIN(ce.LOAD_TIMESTAMP)     AS FIRST_CART_EVENT,
        MAX(ce.LOAD_TIMESTAMP)     AS LAST_CART_EVENT,
        COUNT(*)                   AS CART_EVENT_COUNT,
        SUM(IFF(ce.EVENT_TYPE = 'add_to_cart', 1, 0))    AS ITEMS_ADDED,
        SUM(IFF(ce.EVENT_TYPE = 'remove_from_cart', 1, 0)) AS ITEMS_REMOVED
    FROM RAW.CART_EVENTS ce
    WHERE ce.EVENT_TYPE IN ('add_to_cart', 'remove_from_cart', 'checkout_started')
    GROUP BY ce.SRC_SESSION_ID, ce.SRC_CUSTOMER_ID
)
SELECT
    ws.SESSION_SK,
    TO_NUMBER(TO_CHAR(DATE(ws.SESSION_START), 'YYYYMMDD'))  AS DATE_SK,
    c.CUSTOMER_SK,
    ws.SESSION_ID,
    ws.CUSTOMER_ID,
    ws.DEVICE_TYPE,
    ws.CHANNEL,
    ws.SESSION_START,
    cs.FIRST_CART_EVENT,
    cs.LAST_CART_EVENT,
    cs.ITEMS_ADDED,
    cs.ITEMS_REMOVED,
    cs.ITEMS_ADDED - cs.ITEMS_REMOVED                       AS NET_ITEMS_IN_CART,
    DATEDIFF('second', cs.FIRST_CART_EVENT, cs.LAST_CART_EVENT) AS TIME_IN_CART_SEC,
    CURRENT_TIMESTAMP()                                     AS DW_REFRESHED_AT
FROM cart_sessions cs
JOIN  SILVER.WEB_SESSIONS ws ON cs.SESSION_ID = ws.SESSION_ID
LEFT JOIN GOLD.DIM_CUSTOMERS c ON ws.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE
WHERE ws.CONVERTED = FALSE;
