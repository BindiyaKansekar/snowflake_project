-- GOLD Layer | Fact: GOLD.FACT_CUSTOMER_INTERACTIONS
-- Grain: one row per customer touchpoint event (order, return, review, session)
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE FACT_CUSTOMER_INTERACTIONS AS
SELECT
    c.CUSTOMER_SK,
    TO_NUMBER(TO_CHAR(o.ORDER_DATE, 'YYYYMMDD'))    AS DATE_SK,
    o.ORDER_ID                                      AS INTERACTION_ID,
    o.CUSTOMER_ID,
    'ORDER'                                         AS INTERACTION_TYPE,
    o.ORDER_DATE                                    AS INTERACTION_DATE,
    o.TOTAL_AMOUNT                                  AS INTERACTION_VALUE,
    o.CHANNEL,
    CURRENT_TIMESTAMP()                             AS DW_REFRESHED_AT
FROM SILVER.ORDERS o
LEFT JOIN GOLD.DIM_CUSTOMERS c ON o.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE

UNION ALL

SELECT
    c.CUSTOMER_SK,
    TO_NUMBER(TO_CHAR(r.RETURN_DATE, 'YYYYMMDD'))   AS DATE_SK,
    r.RETURN_ID                                     AS INTERACTION_ID,
    r.CUSTOMER_ID,
    'RETURN'                                        AS INTERACTION_TYPE,
    r.RETURN_DATE                                   AS INTERACTION_DATE,
    -r.REFUND_AMOUNT                                AS INTERACTION_VALUE,
    NULL                                            AS CHANNEL,
    CURRENT_TIMESTAMP()                             AS DW_REFRESHED_AT
FROM SILVER.RETURNS r
LEFT JOIN GOLD.DIM_CUSTOMERS c ON r.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE

UNION ALL

SELECT
    c.CUSTOMER_SK,
    TO_NUMBER(TO_CHAR(rv.REVIEW_DATE, 'YYYYMMDD'))  AS DATE_SK,
    rv.REVIEW_ID                                    AS INTERACTION_ID,
    rv.CUSTOMER_ID,
    'REVIEW'                                        AS INTERACTION_TYPE,
    rv.REVIEW_DATE                                  AS INTERACTION_DATE,
    NULL                                            AS INTERACTION_VALUE,
    NULL                                            AS CHANNEL,
    CURRENT_TIMESTAMP()                             AS DW_REFRESHED_AT
FROM SILVER.REVIEWS rv
LEFT JOIN GOLD.DIM_CUSTOMERS c ON rv.CUSTOMER_ID = c.CUSTOMER_ID AND c.IS_CURRENT = TRUE;
