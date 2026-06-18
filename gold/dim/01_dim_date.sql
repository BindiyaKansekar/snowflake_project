-- GOLD Layer | Dimension: GOLD.DIM_DATE
-- Standard date dimension covering 2015-2035
USE SCHEMA RETAIL_DW.GOLD;

CREATE TABLE IF NOT EXISTS DIM_DATE (
    DATE_SK             NUMBER        PRIMARY KEY,  -- YYYYMMDD integer key
    FULL_DATE           DATE          NOT NULL UNIQUE,
    DAY_OF_WEEK         NUMBER(1),    -- 1=Mon ... 7=Sun
    DAY_NAME            VARCHAR(10),
    DAY_OF_MONTH        NUMBER(2),
    DAY_OF_YEAR         NUMBER(3),
    WEEK_OF_YEAR        NUMBER(2),
    ISO_WEEK_NUMBER     NUMBER(2),
    MONTH_NUMBER        NUMBER(2),
    MONTH_NAME          VARCHAR(10),
    MONTH_NAME_SHORT    VARCHAR(3),
    QUARTER_NUMBER      NUMBER(1),
    QUARTER_NAME        VARCHAR(6),   -- Q1, Q2, Q3, Q4
    YEAR_NUMBER         NUMBER(4),
    FISCAL_YEAR         NUMBER(4),    -- fiscal year starting Feb 1
    FISCAL_QUARTER      NUMBER(1),
    FISCAL_MONTH        NUMBER(2),
    IS_WEEKEND          BOOLEAN,
    IS_WEEKDAY          BOOLEAN,
    IS_HOLIDAY          BOOLEAN       DEFAULT FALSE,
    HOLIDAY_NAME        VARCHAR(100),
    WEEK_START_DATE     DATE,
    WEEK_END_DATE       DATE,
    MONTH_START_DATE    DATE,
    MONTH_END_DATE      DATE,
    QUARTER_START_DATE  DATE,
    QUARTER_END_DATE    DATE,
    YEAR_START_DATE     DATE,
    YEAR_END_DATE       DATE,
    DAYS_IN_MONTH       NUMBER(2),
    IS_LAST_DAY_OF_MONTH BOOLEAN,
    DW_CREATED_AT       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Generate date spine from 2015-01-01 to 2035-12-31
INSERT INTO GOLD.DIM_DATE
SELECT
    TO_NUMBER(TO_CHAR(d, 'YYYYMMDD'))                        AS DATE_SK,
    d                                                        AS FULL_DATE,
    DAYOFWEEKISO(d)                                          AS DAY_OF_WEEK,
    DAYNAME(d)                                               AS DAY_NAME,
    DAY(d)                                                   AS DAY_OF_MONTH,
    DAYOFYEAR(d)                                             AS DAY_OF_YEAR,
    WEEKOFYEAR(d)                                            AS WEEK_OF_YEAR,
    WEEKISO(d)                                               AS ISO_WEEK_NUMBER,
    MONTH(d)                                                 AS MONTH_NUMBER,
    MONTHNAME(d)                                             AS MONTH_NAME,
    LEFT(MONTHNAME(d), 3)                                    AS MONTH_NAME_SHORT,
    QUARTER(d)                                               AS QUARTER_NUMBER,
    'Q' || QUARTER(d)                                        AS QUARTER_NAME,
    YEAR(d)                                                  AS YEAR_NUMBER,
    IFF(MONTH(d) >= 2, YEAR(d), YEAR(d) - 1)                AS FISCAL_YEAR,
    CASE
        WHEN MONTH(d) BETWEEN 2  AND 4  THEN 1
        WHEN MONTH(d) BETWEEN 5  AND 7  THEN 2
        WHEN MONTH(d) BETWEEN 8  AND 10 THEN 3
        ELSE 4
    END                                                      AS FISCAL_QUARTER,
    MOD(MONTH(d) - 2 + 12, 12) + 1                          AS FISCAL_MONTH,
    DAYOFWEEKISO(d) IN (6, 7)                                AS IS_WEEKEND,
    DAYOFWEEKISO(d) NOT IN (6, 7)                            AS IS_WEEKDAY,
    FALSE                                                    AS IS_HOLIDAY,
    NULL                                                     AS HOLIDAY_NAME,
    DATE_TRUNC('WEEK', d)                                    AS WEEK_START_DATE,
    DATEADD('day', 6, DATE_TRUNC('WEEK', d))                AS WEEK_END_DATE,
    DATE_TRUNC('MONTH', d)                                   AS MONTH_START_DATE,
    LAST_DAY(d)                                              AS MONTH_END_DATE,
    DATE_TRUNC('QUARTER', d)                                 AS QUARTER_START_DATE,
    DATEADD('day', -1, DATEADD('quarter', 1, DATE_TRUNC('QUARTER', d))) AS QUARTER_END_DATE,
    DATE_TRUNC('YEAR', d)                                    AS YEAR_START_DATE,
    DATEADD('day', -1, DATEADD('year', 1, DATE_TRUNC('YEAR', d)))       AS YEAR_END_DATE,
    DAY(LAST_DAY(d))                                         AS DAYS_IN_MONTH,
    d = LAST_DAY(d)                                          AS IS_LAST_DAY_OF_MONTH
FROM (
    SELECT DATEADD('day', ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, '2015-01-01'::DATE) AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 7670))  -- 2015-01-01 to 2035-12-31
)
WHERE d <= '2035-12-31';

-- Mark US federal holidays (partial list — extend as needed)
UPDATE GOLD.DIM_DATE SET IS_HOLIDAY = TRUE, HOLIDAY_NAME = 'New Year''s Day'
    WHERE MONTH_NUMBER = 1  AND DAY_OF_MONTH = 1;
UPDATE GOLD.DIM_DATE SET IS_HOLIDAY = TRUE, HOLIDAY_NAME = 'Independence Day'
    WHERE MONTH_NUMBER = 7  AND DAY_OF_MONTH = 4;
UPDATE GOLD.DIM_DATE SET IS_HOLIDAY = TRUE, HOLIDAY_NAME = 'Christmas Day'
    WHERE MONTH_NUMBER = 12 AND DAY_OF_MONTH = 25;
