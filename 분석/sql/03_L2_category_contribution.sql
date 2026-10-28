-- 03_L2_category_contribution.sql
-- 로직트리 L2: 총매출 = Σ 대분류(외식·서비스·소매) = Σ 62개 업종  (MECE: 모든 매출은 정확히 한 업종에 속함)
-- 성장 기여도(%p) = 전년 매출 비중 × 해당 업종 성장률 = 해당 업종 매출 증감액 ÷ 전년 총매출
--   → 투자론의 '포트폴리오 수익률 = Σ(비중 × 종목 수익률)'과 같은 가중평균 구조
-- 파라미터: base_yr(비교 기준 연도), cur_yr(비교 연도)
SET VARIABLE base_yr = 2024;
SET VARIABLE cur_yr  = 2025;

WITH b AS (
    SELECT
        CASE substr(biz_code, 1, 3) WHEN 'CS1' THEN '외식업' WHEN 'CS2' THEN '서비스업' ELSE '소매업' END AS biz_group,
        biz_code, biz_name, yr,
        SUM(amt) AS amt, SUM(cnt) AS cnt
    FROM sales
    WHERE biz_code <> 'CS200036'
      AND yr IN (getvariable('base_yr'), getvariable('cur_yr'))
    GROUP BY ALL
),
p AS (
    SELECT biz_group, biz_code, biz_name,
           SUM(amt) FILTER (WHERE yr = getvariable('base_yr')) AS amt0,
           SUM(amt) FILTER (WHERE yr = getvariable('cur_yr'))  AS amt1,
           SUM(cnt) FILTER (WHERE yr = getvariable('base_yr')) AS cnt0,
           SUM(cnt) FILTER (WHERE yr = getvariable('cur_yr'))  AS cnt1
    FROM b GROUP BY ALL
)
SELECT
    biz_group, biz_name,
    ROUND(100 * amt0 / SUM(amt0) OVER (), 2)                 AS share_base_pct,
    ROUND(100 * (amt1 / amt0 - 1), 2)                        AS amt_growth_pct,
    ROUND(100 * (cnt1 / cnt0 - 1), 2)                        AS cnt_growth_pct,
    ROUND(100 * ((amt1 / cnt1) / (amt0 / cnt0) - 1), 2)      AS ticket_growth_pct,
    ROUND(100 * (amt1 - amt0) / SUM(amt0) OVER (), 3)        AS contribution_pp
FROM p
ORDER BY contribution_pp DESC;
