-- 02_L1_total_decomposition.sql
-- 로직트리 L1: 매출 = 거래건수 × 건당 결제액(객단가)
-- 연도별 총매출 증감을 '건수 효과'와 '객단가 효과'로 분리한다.
-- 로그 분해를 쓰면 두 효과의 합이 정확히 매출 성장률(로그)과 같아진다: ln(매출) = ln(건수) + ln(객단가)
-- ※ 고시원(CS200036)은 2024년부터 업종에서 빠져 연도 간 비교가 깨지므로 전 연도에서 제외(like-for-like)
WITH yearly AS (
    SELECT yr,
           SUM(amt)            AS amt,
           SUM(cnt)            AS cnt,
           SUM(amt) / SUM(cnt) AS ticket
    FROM sales
    WHERE biz_code <> 'CS200036'
    GROUP BY yr
)
SELECT
    yr,
    ROUND(amt / 1e12, 2)                                       AS amt_trillion,
    ROUND(cnt / 1e8, 2)                                        AS cnt_100m,
    ROUND(ticket)                                              AS ticket_won,
    ROUND(100 * (amt / LAG(amt) OVER w - 1), 2)                AS amt_yoy_pct,
    ROUND(100 * (cnt / LAG(cnt) OVER w - 1), 2)                AS cnt_yoy_pct,
    ROUND(100 * (ticket / LAG(ticket) OVER w - 1), 2)          AS ticket_yoy_pct,
    -- 로그 기여도: 매출 성장(로그) 중 건수와 객단가가 각각 몇 %p를 설명하는가
    ROUND(100 * LN(cnt / LAG(cnt) OVER w), 2)                  AS cnt_effect_logpct,
    ROUND(100 * LN(ticket / LAG(ticket) OVER w), 2)            AS ticket_effect_logpct
FROM yearly
WINDOW w AS (ORDER BY yr)
ORDER BY yr;
