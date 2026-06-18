-- GOLD Mart | GOLD.EXECUTIVE_DASHBOARD
-- Single-row-per-period executive summary for C-suite reporting
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE EXECUTIVE_DASHBOARD AS
WITH current_month AS (
    SELECT
        DATE_TRUNC('MONTH', CURRENT_DATE()) AS CUR_MONTH,
        DATEADD('MONTH', -1, DATE_TRUNC('MONTH', CURRENT_DATE())) AS PREV_MONTH,
        DATEADD('MONTH', -12, DATE_TRUNC('MONTH', CURRENT_DATE())) AS LY_MONTH,
        DATE_TRUNC('YEAR', CURRENT_DATE()) AS CUR_YEAR_START
),
monthly_sales AS (
    SELECT
        DATE_TRUNC('MONTH', fs.ORDER_DATE) AS MONTH,
        SUM(fs.TOTAL_AMOUNT)               AS REVENUE,
        COUNT(DISTINCT fs.ORDER_ID)        AS ORDERS,
        COUNT(DISTINCT fs.CUSTOMER_ID)     AS CUSTOMERS,
        AVG(fs.TOTAL_AMOUNT)               AS AOV
    FROM GOLD.FACT_SALES fs
    GROUP BY DATE_TRUNC('MONTH', fs.ORDER_DATE)
),
ytd_sales AS (
    SELECT SUM(fs.TOTAL_AMOUNT) AS YTD_REVENUE, COUNT(DISTINCT fs.ORDER_ID) AS YTD_ORDERS
    FROM GOLD.FACT_SALES fs, current_month cm
    WHERE fs.ORDER_DATE >= cm.CUR_YEAR_START
)
SELECT
    CURRENT_DATE()                                                                  AS REPORT_DATE,
    cm.CUR_MONTH,
    -- Current month KPIs
    ms_cur.REVENUE                                                                 AS MTD_REVENUE,
    ms_cur.ORDERS                                                                  AS MTD_ORDERS,
    ms_cur.CUSTOMERS                                                               AS MTD_CUSTOMERS,
    ms_cur.AOV                                                                     AS MTD_AOV,
    -- MoM
    ms_prev.REVENUE                                                                AS PREV_MONTH_REVENUE,
    (ms_cur.REVENUE - ms_prev.REVENUE) / NULLIF(ms_prev.REVENUE, 0) * 100         AS REVENUE_MOM_PCT,
    -- YoY
    ms_ly.REVENUE                                                                  AS SAME_MONTH_LY_REVENUE,
    (ms_cur.REVENUE - ms_ly.REVENUE) / NULLIF(ms_ly.REVENUE, 0) * 100             AS REVENUE_YOY_PCT,
    -- YTD
    ytd.YTD_REVENUE,
    ytd.YTD_ORDERS,
    -- Active customers (ordered in last 90 days)
    (SELECT COUNT(DISTINCT CUSTOMER_ID) FROM SILVER.ORDERS
     WHERE ORDER_DATE >= DATEADD('day', -90, CURRENT_DATE()))                      AS ACTIVE_CUSTOMERS_90D,
    -- Total CLV
    (SELECT SUM(LIFETIME_REVENUE) FROM GOLD.CUSTOMER_LIFETIME_VALUE)              AS TOTAL_CUSTOMER_LIFETIME_REVENUE,
    -- Inventory value
    (SELECT SUM(INVENTORY_VALUE) FROM GOLD.FACT_INVENTORY_SNAPSHOTS
     WHERE SNAPSHOT_DATE = (SELECT MAX(SNAPSHOT_DATE) FROM GOLD.FACT_INVENTORY_SNAPSHOTS)) AS CURRENT_INVENTORY_VALUE,
    -- Return rate (last 30 days)
    (SELECT COUNT(DISTINCT r.RETURN_ID) / NULLIF(COUNT(DISTINCT o.ORDER_ID), 0) * 100
     FROM SILVER.RETURNS r JOIN SILVER.ORDERS o ON r.ORDER_ID = o.ORDER_ID
     WHERE o.ORDER_DATE >= DATEADD('day', -30, CURRENT_DATE()))                   AS RETURN_RATE_30D_PCT,
    -- NPS (last 90 days)
    (SELECT NPS_SCORE FROM GOLD.NET_PROMOTER_SCORE
     WHERE REVIEW_MONTH = DATE_TRUNC('MONTH', DATEADD('MONTH', -1, CURRENT_DATE()))
       AND TOP_CATEGORY_NAME IS NULL
     LIMIT 1)                                                                      AS OVERALL_NPS_PREV_MONTH,
    -- Loyalty members
    (SELECT COUNT(DISTINCT CUSTOMER_ID) FROM SILVER.LOYALTY_POINTS)              AS TOTAL_LOYALTY_MEMBERS,
    CURRENT_TIMESTAMP()                                                            AS DW_REFRESHED_AT
FROM current_month cm
LEFT JOIN monthly_sales ms_cur  ON ms_cur.MONTH  = cm.CUR_MONTH
LEFT JOIN monthly_sales ms_prev ON ms_prev.MONTH = cm.PREV_MONTH
LEFT JOIN monthly_sales ms_ly   ON ms_ly.MONTH   = cm.LY_MONTH
CROSS JOIN ytd_sales ytd;
