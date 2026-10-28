-- 00_load.sql
-- 서울시 상권분석서비스(추정매출-상권) 2021~2025 CSV(UTF-8 변환본)를 하나의 테이블로 적재
-- 컬럼명이 길어서 분석에 쓰는 컬럼만 짧은 영문명으로 바꿔 둔다.
CREATE OR REPLACE TABLE sales AS
SELECT
    CAST("기준_년분기_코드" AS INTEGER)              AS yq,          -- 예: 20251 = 2025년 1분기
    CAST("기준_년분기_코드" AS INTEGER) // 10        AS yr,
    CAST("기준_년분기_코드" AS INTEGER) % 10         AS qtr,
    "상권_구분_코드_명"                                AS area_type,   -- 골목상권/발달상권/전통시장/관광특구
    "상권_코드"                                        AS area_code,
    "상권_코드_명"                                     AS area_name,
    "서비스_업종_코드"                                 AS biz_code,
    "서비스_업종_코드_명"                              AS biz_name,
    CAST("당월_매출_금액" AS DOUBLE)                   AS amt,
    CAST("당월_매출_건수" AS DOUBLE)                   AS cnt,
    CAST("주중_매출_금액" AS DOUBLE)                   AS amt_weekday,
    CAST("주말_매출_금액" AS DOUBLE)                   AS amt_weekend,
    CAST("시간대_00~06_매출_금액" AS DOUBLE)           AS amt_t00_06,
    CAST("시간대_06~11_매출_금액" AS DOUBLE)           AS amt_t06_11,
    CAST("시간대_11~14_매출_금액" AS DOUBLE)           AS amt_t11_14,
    CAST("시간대_14~17_매출_금액" AS DOUBLE)           AS amt_t14_17,
    CAST("시간대_17~21_매출_금액" AS DOUBLE)           AS amt_t17_21,
    CAST("시간대_21~24_매출_금액" AS DOUBLE)           AS amt_t21_24,
    CAST("남성_매출_금액" AS DOUBLE)                   AS amt_male,
    CAST("여성_매출_금액" AS DOUBLE)                   AS amt_female,
    CAST("연령대_10_매출_금액" AS DOUBLE)              AS amt_a10,
    CAST("연령대_20_매출_금액" AS DOUBLE)              AS amt_a20,
    CAST("연령대_30_매출_금액" AS DOUBLE)              AS amt_a30,
    CAST("연령대_40_매출_금액" AS DOUBLE)              AS amt_a40,
    CAST("연령대_50_매출_금액" AS DOUBLE)              AS amt_a50,
    CAST("연령대_60_이상_매출_금액" AS DOUBLE)         AS amt_a60
FROM read_csv('sales_20*.csv', header = true, all_varchar = true, union_by_name = true);
