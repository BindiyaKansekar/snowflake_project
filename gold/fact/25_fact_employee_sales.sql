-- GOLD Layer | Fact: GOLD.FACT_EMPLOYEE_SALES
-- Grain: one row per employee per day (sales associate attribution)
-- NOTE: Requires order-to-employee linkage stored in order payload
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE FACT_EMPLOYEE_SALES AS
WITH emp_orders AS (
    SELECT
        PAYLOAD:employee_id::VARCHAR(50)    AS EMPLOYEE_ID,
        PAYLOAD:order_id::VARCHAR(50)       AS ORDER_ID,
        TRY_TO_DATE(PAYLOAD:order_date::VARCHAR) AS ORDER_DATE
    FROM RAW.ORDERS
    WHERE PAYLOAD:employee_id IS NOT NULL
)
SELECT
    e.EMPLOYEE_SK,
    TO_NUMBER(TO_CHAR(o.ORDER_DATE, 'YYYYMMDD'))    AS DATE_SK,
    s.STORE_SK,
    eo.EMPLOYEE_ID,
    o.STORE_ID,
    o.ORDER_DATE,
    COUNT(DISTINCT o.ORDER_ID)                      AS ORDERS_TAKEN,
    COUNT(DISTINCT o.CUSTOMER_ID)                   AS CUSTOMERS_SERVED,
    SUM(o.TOTAL_AMOUNT)                             AS TOTAL_SALES_AMOUNT,
    AVG(o.TOTAL_AMOUNT)                             AS AVG_TRANSACTION_VALUE,
    SUM(o.DISCOUNT_AMOUNT)                          AS TOTAL_DISCOUNTS_GIVEN,
    CURRENT_TIMESTAMP()                             AS DW_REFRESHED_AT
FROM emp_orders eo
JOIN  SILVER.ORDERS      o ON eo.ORDER_ID   = o.ORDER_ID
LEFT JOIN GOLD.DIM_EMPLOYEES e ON eo.EMPLOYEE_ID = e.EMPLOYEE_ID AND e.IS_CURRENT = TRUE
LEFT JOIN GOLD.DIM_STORES    s ON o.STORE_ID     = s.STORE_ID
GROUP BY e.EMPLOYEE_SK, eo.EMPLOYEE_ID, o.STORE_ID, s.STORE_SK, o.ORDER_DATE;
