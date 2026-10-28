-- 01_integrity_check.sql
-- MECE 검증: 하위 항목을 모두 더하면 총매출과 같아야 한다(Collectively Exhaustive),
-- 그리고 항목끼리 겹치지 않는다(Mutually Exclusive)는 전제가 데이터에서도 성립하는지 확인.
-- 결과: 축별로 "하위 합계 / 총매출" 비율과 불일치 행 비율
WITH t AS (
    SELECT *,
        amt_weekday + amt_weekend                                              AS s_week,
        amt_t00_06 + amt_t06_11 + amt_t11_14 + amt_t14_17 + amt_t17_21 + amt_t21_24 AS s_time,
        amt_male + amt_female                                                  AS s_sex,
        amt_a10 + amt_a20 + amt_a30 + amt_a40 + amt_a50 + amt_a60              AS s_age
    FROM sales
)
SELECT
    yr,
    ROUND(SUM(s_week) / SUM(amt), 4)  AS week_ratio,
    ROUND(SUM(s_time) / SUM(amt), 4)  AS time_ratio,
    ROUND(SUM(s_sex)  / SUM(amt), 4)  AS sex_ratio,
    ROUND(SUM(s_age)  / SUM(amt), 4)  AS age_ratio,
    ROUND(AVG(CASE WHEN ABS(s_time - amt) > 1 THEN 1 ELSE 0 END), 4) AS time_mismatch_rows,
    ROUND(AVG(CASE WHEN ABS(s_sex  - amt) > 1 THEN 1 ELSE 0 END), 4) AS sex_mismatch_rows
FROM t
GROUP BY yr
ORDER BY yr;
