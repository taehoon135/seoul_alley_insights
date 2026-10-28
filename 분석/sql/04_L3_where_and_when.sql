-- 04_L3_where_and_when.sql
-- 로직트리 L3: 외식업 매출 변화가 '어디서(상권유형)'·'언제(시간대·요일)' 일어났는지 분해
-- 상권유형 4개, 시간대 6개, 주중/주말 2개는 각각 총매출을 100% 나눠 갖는 MECE 축(01_integrity_check로 검증)
SET VARIABLE base_yr = 2024;
SET VARIABLE cur_yr  = 2025;

-- (a) 상권유형별 기여도
WITH f AS (
    SELECT area_type, yr, SUM(amt) amt, SUM(cnt) cnt
    FROM sales
    WHERE substr(biz_code,1,3) = 'CS1' AND yr IN (getvariable('base_yr'), getvariable('cur_yr'))
    GROUP BY ALL
), p AS (
    SELECT area_type,
           SUM(amt) FILTER (WHERE yr = getvariable('base_yr')) a0, SUM(amt) FILTER (WHERE yr = getvariable('cur_yr')) a1,
           SUM(cnt) FILTER (WHERE yr = getvariable('base_yr')) c0, SUM(cnt) FILTER (WHERE yr = getvariable('cur_yr')) c1
    FROM f GROUP BY ALL
)
SELECT 'area_type' AS axis, area_type AS item,
       ROUND(100*a0/SUM(a0) OVER(),1) share_pct, ROUND(100*(a1/a0-1),2) amt_growth_pct,
       ROUND(100*(c1/c0-1),2) cnt_growth_pct, ROUND(100*(a1-a0)/SUM(a0) OVER(),3) contribution_pp
FROM p

UNION ALL

-- (b) 시간대별 기여도: wide 컬럼을 UNPIVOT으로 세로로 펼친 뒤 같은 계산
SELECT 'time_slot', slot,
       ROUND(100*a0/SUM(a0) OVER(),1), ROUND(100*(a1/a0-1),2), NULL, ROUND(100*(a1-a0)/SUM(a0) OVER(),3)
FROM (
    SELECT slot,
           SUM(v) FILTER (WHERE yr = getvariable('base_yr')) a0,
           SUM(v) FILTER (WHERE yr = getvariable('cur_yr'))  a1
    FROM (
        UNPIVOT (SELECT yr, amt_t00_06, amt_t06_11, amt_t11_14, amt_t14_17, amt_t17_21, amt_t21_24
                 FROM sales WHERE substr(biz_code,1,3) = 'CS1' AND yr IN (getvariable('base_yr'), getvariable('cur_yr')))
        ON COLUMNS(* EXCLUDE (yr)) INTO NAME slot VALUE v
    )
    GROUP BY slot
)

UNION ALL

-- (c) 주중/주말
SELECT 'week', slot,
       ROUND(100*a0/SUM(a0) OVER(),1), ROUND(100*(a1/a0-1),2), NULL, ROUND(100*(a1-a0)/SUM(a0) OVER(),3)
FROM (
    SELECT slot,
           SUM(v) FILTER (WHERE yr = getvariable('base_yr')) a0,
           SUM(v) FILTER (WHERE yr = getvariable('cur_yr'))  a1
    FROM (
        UNPIVOT (SELECT yr, amt_weekday, amt_weekend FROM sales
                 WHERE substr(biz_code,1,3) = 'CS1' AND yr IN (getvariable('base_yr'), getvariable('cur_yr')))
        ON COLUMNS(* EXCLUDE (yr)) INTO NAME slot VALUE v
    )
    GROUP BY slot
)
ORDER BY axis, item;
