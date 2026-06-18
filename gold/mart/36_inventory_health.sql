-- GOLD Mart | GOLD.INVENTORY_HEALTH
-- Current inventory health: stockouts, overstock, slow movers
USE SCHEMA RETAIL_DW.GOLD;

CREATE OR REPLACE TABLE INVENTORY_HEALTH AS
WITH latest_snapshot AS (
    SELECT *
    FROM GOLD.FACT_INVENTORY_SNAPSHOTS
    WHERE SNAPSHOT_DATE = (SELECT MAX(SNAPSHOT_DATE) FROM GOLD.FACT_INVENTORY_SNAPSHOTS)
),
sales_velocity AS (
    SELECT
        PRODUCT_ID,
        SUM(QUANTITY) / NULLIF(DATEDIFF('day', MIN(ORDER_DATE), CURRENT_DATE()), 0) AS DAILY_UNITS_SOLD
    FROM GOLD.FACT_ORDER_ITEMS
    WHERE ORDER_DATE >= DATEADD('day', -90, CURRENT_DATE())
    GROUP BY PRODUCT_ID
)
SELECT
    inv.PRODUCT_ID,
    p.PRODUCT_NAME,
    p.BRAND,
    p.CATEGORY_NAME,
    p.SUPPLIER_NAME,
    inv.LOCATION_ID,
    inv.LOCATION_TYPE,
    inv.QUANTITY_ON_HAND,
    inv.QUANTITY_RESERVED,
    inv.QUANTITY_AVAILABLE,
    inv.REORDER_POINT,
    inv.REORDER_QUANTITY,
    inv.INVENTORY_VALUE,
    COALESCE(sv.DAILY_UNITS_SOLD, 0)                                       AS DAILY_SALES_VELOCITY,
    IFF(sv.DAILY_UNITS_SOLD > 0,
        inv.QUANTITY_AVAILABLE / sv.DAILY_UNITS_SOLD,
        NULL)                                                              AS DAYS_OF_STOCK,
    inv.IS_OUT_OF_STOCK,
    inv.IS_BELOW_REORDER,
    -- Health classification
    CASE
        WHEN inv.QUANTITY_AVAILABLE = 0                                   THEN 'STOCKOUT'
        WHEN inv.QUANTITY_AVAILABLE <= inv.REORDER_POINT                  THEN 'LOW_STOCK'
        WHEN inv.QUANTITY_AVAILABLE / NULLIF(sv.DAILY_UNITS_SOLD, 0) > 180 THEN 'OVERSTOCK'
        WHEN sv.DAILY_UNITS_SOLD < 0.1 AND inv.QUANTITY_ON_HAND > 50     THEN 'SLOW_MOVER'
        ELSE 'HEALTHY'
    END                                                                    AS INVENTORY_STATUS,
    inv.SNAPSHOT_DATE,
    CURRENT_TIMESTAMP()                                                    AS DW_REFRESHED_AT
FROM latest_snapshot      inv
LEFT JOIN GOLD.DIM_PRODUCTS p  ON inv.PRODUCT_ID = p.PRODUCT_ID
LEFT JOIN sales_velocity   sv  ON inv.PRODUCT_ID = sv.PRODUCT_ID;
