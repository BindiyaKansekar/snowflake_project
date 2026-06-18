-- GOLD Layer | Fact: GOLD.FACT_SUPPLIER_ORDERS
-- Grain: one row per purchase order from a supplier
-- NOTE: Sourced from ERP PO data loaded via RAW.INVENTORY supplier payload
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE FACT_SUPPLIER_ORDERS AS
WITH supplier_po AS (
    SELECT
        PAYLOAD:po_number::VARCHAR(50)                     AS PO_NUMBER,
        PAYLOAD:supplier_id::VARCHAR(50)                   AS SUPPLIER_ID,
        PAYLOAD:product_id::VARCHAR(50)                    AS PRODUCT_ID,
        TRY_TO_DATE(PAYLOAD:order_date::VARCHAR)           AS ORDER_DATE,
        TRY_TO_DATE(PAYLOAD:expected_delivery::VARCHAR)    AS EXPECTED_DELIVERY,
        TRY_TO_DATE(PAYLOAD:actual_delivery::VARCHAR)      AS ACTUAL_DELIVERY,
        TRY_TO_NUMBER(PAYLOAD:quantity_ordered::VARCHAR)   AS QUANTITY_ORDERED,
        TRY_TO_NUMBER(PAYLOAD:quantity_received::VARCHAR)  AS QUANTITY_RECEIVED,
        TRY_TO_DOUBLE(PAYLOAD:unit_cost::VARCHAR)          AS UNIT_COST,
        TRY_TO_DOUBLE(PAYLOAD:total_cost::VARCHAR)         AS TOTAL_COST,
        UPPER(PAYLOAD:status::VARCHAR(30))                 AS PO_STATUS
    FROM RAW.INVENTORY
    WHERE PAYLOAD:po_number IS NOT NULL
)
SELECT
    ROW_NUMBER() OVER (ORDER BY po.ORDER_DATE, po.PO_NUMBER) AS SUPPLIER_ORDER_SK,
    TO_NUMBER(TO_CHAR(po.ORDER_DATE, 'YYYYMMDD'))            AS DATE_SK,
    s.SUPPLIER_SK,
    p.PRODUCT_SK,
    po.PO_NUMBER,
    po.SUPPLIER_ID,
    po.PRODUCT_ID,
    po.ORDER_DATE,
    po.EXPECTED_DELIVERY,
    po.ACTUAL_DELIVERY,
    po.QUANTITY_ORDERED,
    po.QUANTITY_RECEIVED,
    po.UNIT_COST,
    po.TOTAL_COST,
    po.PO_STATUS,
    IFF(po.ACTUAL_DELIVERY > po.EXPECTED_DELIVERY, TRUE, FALSE)           AS IS_LATE_DELIVERY,
    DATEDIFF('day', po.EXPECTED_DELIVERY, po.ACTUAL_DELIVERY)             AS DELIVERY_VARIANCE_DAYS,
    po.QUANTITY_RECEIVED - po.QUANTITY_ORDERED                            AS QUANTITY_VARIANCE,
    CURRENT_TIMESTAMP()                                                   AS DW_REFRESHED_AT
FROM supplier_po po
LEFT JOIN GOLD.DIM_SUPPLIERS s ON po.SUPPLIER_ID = s.SUPPLIER_ID
LEFT JOIN GOLD.DIM_PRODUCTS  p ON po.PRODUCT_ID  = p.PRODUCT_ID;
