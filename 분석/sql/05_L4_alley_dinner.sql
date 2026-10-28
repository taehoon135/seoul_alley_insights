-- 05_L4_alley_dinner.sql
-- 로직트리 L4: L3에서 가장 크게 빠진 '골목상권 × 외식업 × 저녁(17~24시)'을 한 단계 더 분해
-- 저녁 = 시간대_17~21 + 시간대_21~24 (시간대 축은 01에서 합계=총매출 검증 완료)
-- 결과 표가 5개라 README의 블록별 실행 스니펫(세미콜론 단위 분할)으로 돌린다.

-- (a) 상권유형별 저녁 외식매출·저녁 의존도 5개년 추이
SELECT area_type, yr,
       ROUND(SUM(amt_t17_21 + amt_t21_24) / 1e12, 3)               AS dinner_trillion,
       ROUND(SUM(amt_t11_14) / 1e12, 3)                            AS lunch_trillion,
       ROUND(100 * SUM(amt_t17_21 + amt_t21_24) / SUM(amt), 1)     AS dinner_share_pct
FROM sales
WHERE substr(biz_code, 1, 3) = 'CS1'
GROUP BY ALL
ORDER BY area_type, yr;

-- (b) 골목상권 외식 저녁 vs 점심 분기별 전년동기비 → 저녁만 2023Q4부터 연속 역성장
WITH t AS (
    SELECT yr, qtr, SUM(amt_t17_21 + amt_t21_24) d, SUM(amt_t11_14) l
    FROM sales
    WHERE substr(biz_code, 1, 3) = 'CS1' AND area_type = '골목상권'
    GROUP BY ALL
)
SELECT yr, qtr,
       ROUND(100 * (d / LAG(d) OVER w - 1), 2) AS dinner_yoy_pct,
       ROUND(100 * (l / LAG(l) OVER w - 1), 2) AS lunch_yoy_pct
FROM t
WINDOW w AS (PARTITION BY qtr ORDER BY yr)
ORDER BY yr, qtr;

-- (c) 골목상권 외식 업종별 저녁매출 기여도(2024→2025) + 건수/객단가 분해(업종 전체 시간대 기준)
WITH p AS (
    SELECT biz_name,
           SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2024) d0, SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2025) d1,
           SUM(amt_t11_14) FILTER (yr = 2024) l0, SUM(amt_t11_14) FILTER (yr = 2025) l1,
           SUM(amt) FILTER (yr = 2024) a0, SUM(amt) FILTER (yr = 2025) a1,
           SUM(cnt) FILTER (yr = 2024) c0, SUM(cnt) FILTER (yr = 2025) c1
    FROM sales
    WHERE substr(biz_code, 1, 3) = 'CS1' AND area_type = '골목상권'
    GROUP BY 1
)
SELECT biz_name,
       ROUND(100 * d0 / SUM(d0) OVER (), 1)                AS dinner_share_pct,
       ROUND(100 * d0 / a0, 1)                             AS dinner_dependency_pct,
       ROUND(100 * (d1 / d0 - 1), 2)                       AS dinner_growth_pct,
       ROUND(100 * (l1 / l0 - 1), 2)                       AS lunch_growth_pct,
       ROUND(100 * (c1 / c0 - 1), 2)                       AS cnt_growth_pct,
       ROUND(100 * ((a1 / c1) / (a0 / c0) - 1), 2)         AS ticket_growth_pct,
       ROUND(100 * (d1 - d0) / SUM(d0) OVER (), 3)         AS contribution_pp
FROM p
ORDER BY contribution_pp;

-- (d) 골목상권별 저녁 성장률 5분위: 방어 상권과 급락 상권은 무엇이 다른가
--     2024 저녁 외식매출 10억 이상 상권(637개, 골목 저녁매출의 95.7%)만 사용해 소형 상권 노이즈 제거
WITH ad AS (
    SELECT area_code,
           SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2024) d0, SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2025) d1,
           SUM(amt_t21_24) FILTER (yr = 2024) n0,
           SUM(amt_t11_14) FILTER (yr = 2024) l0, SUM(amt_t11_14) FILTER (yr = 2025) l1,
           SUM(cnt) FILTER (yr = 2024) c0, SUM(cnt) FILTER (yr = 2025) c1,
           SUM(amt) FILTER (yr = 2024) a0,
           SUM(amt_weekend) FILTER (yr = 2024) we0,
           SUM(amt) FILTER (yr = 2024 AND biz_name = '호프-간이주점') hof0
    FROM sales
    WHERE substr(biz_code, 1, 3) = 'CS1' AND area_type = '골목상권'
    GROUP BY 1
), t AS (
    SELECT *, NTILE(5) OVER (ORDER BY d1 / d0) AS quintile FROM ad WHERE d0 >= 1e9 AND d1 > 0
)
SELECT quintile, COUNT(*) AS n_area,
       ROUND(100 * MEDIAN(d1 / d0 - 1), 1)              AS dinner_growth_pct,
       ROUND(100 * MEDIAN(l1 / l0 - 1), 1)              AS lunch_growth_pct,
       ROUND(100 * MEDIAN(c1 / c0 - 1), 1)              AS cnt_growth_pct,
       ROUND(100 * MEDIAN(n0 / d0), 1)                  AS late_night_share_pct,
       ROUND(100 * MEDIAN(COALESCE(hof0, 0) / a0), 1)   AS hof_share_pct,
       ROUND(100 * MEDIAN(we0 / a0), 1)                 AS weekend_share_pct,
       -- 저녁 성장률과 점심 성장률의 상관(전체 상권, 성장률 ±50~100% 극단값 제외). 행마다 같은 값
       (SELECT ROUND(CORR(d1 / d0, l1 / l0), 3) FROM t WHERE d1 / d0 BETWEEN 0.5 AND 2) AS r_dinner_lunch
FROM t
GROUP BY quintile
ORDER BY quintile;

-- (e) 골목상권 외식 연령대별 매출 기여도(2024→2025, 전 시간대). '미상' = 성별·연령 식별 불가 결제
WITH u AS (
    UNPIVOT (
        SELECT yr, SUM(amt_a10) a10, SUM(amt_a20) a20, SUM(amt_a30) a30, SUM(amt_a40) a40,
               SUM(amt_a50) a50, SUM(amt_a60) a60_plus, SUM(amt - amt_male - amt_female) unknown
        FROM sales
        WHERE substr(biz_code, 1, 3) = 'CS1' AND area_type = '골목상권' AND yr IN (2024, 2025)
        GROUP BY yr
    ) ON COLUMNS(* EXCLUDE yr) INTO NAME age VALUE v
)
SELECT age,
       ROUND(100 * SUM(v) FILTER (yr = 2024) / SUM(SUM(v) FILTER (yr = 2024)) OVER (), 1)                          AS share_2024_pct,
       ROUND(100 * (SUM(v) FILTER (yr = 2025) / SUM(v) FILTER (yr = 2024) - 1), 2)                                  AS growth_pct,
       ROUND(100 * (SUM(v) FILTER (yr = 2025) - SUM(v) FILTER (yr = 2024)) / SUM(SUM(v) FILTER (yr = 2024)) OVER (), 3) AS contribution_pp
FROM u
GROUP BY age
ORDER BY age;
