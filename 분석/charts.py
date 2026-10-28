"""sql/02·04·05 결과를 그대로 그래프로 그려 charts/*.png로 저장한다.
숫자를 따로 적지 않고 SQL을 다시 실행하므로 SQL이 바뀌면 그래프도 같이 바뀐다.
실행: 분석/ 폴더에서 `python charts.py` (seoul.duckdb에 sales 테이블이 적재돼 있어야 함)
"""
from pathlib import Path

import duckdb
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

OUT = Path('charts')
OUT.mkdir(exist_ok=True)

# 색: 저녁=주황, 점심=파랑을 모든 차트에서 고정. 강조 외 항목은 회색, 증감 부호는 파랑(+)/빨강(-)
BLUE, ORANGE, RED, GRAY = '#2a78d6', '#eb6834', '#e34948', '#c3c2b7'
INK, INK2, GRID, SURFACE = '#0b0b0b', '#52514e', '#e6e5e0', '#fcfcfb'
plt.rcParams.update({
    'font.family': 'NanumGothic', 'axes.unicode_minus': False, 'font.size': 11,
    'figure.facecolor': SURFACE, 'axes.facecolor': SURFACE, 'savefig.facecolor': SURFACE,
    'axes.edgecolor': GRID, 'axes.labelcolor': INK2, 'xtick.color': INK2, 'ytick.color': INK2,
    'text.color': INK, 'axes.spines.top': False, 'axes.spines.right': False,
    'axes.grid': True, 'grid.color': GRID, 'grid.linewidth': 0.8, 'axes.axisbelow': True,
})

con = duckdb.connect('seoul.duckdb', read_only=True)


def run(path):
    """SQL 파일을 세미콜론 단위로 실행하고, SELECT 결과마다 {컬럼: 값 리스트}를 돌려준다."""
    out = []
    for s in Path(path).read_text().split(';'):
        if 'SELECT' not in s and 'SET VARIABLE' not in s:
            continue
        r = con.sql(s)
        if 'SELECT' in s:
            out.append(dict(zip(r.columns, zip(*r.fetchall()))))
    return out


def finish(ax, title, subtitle, name):
    ax.set_title(title, loc='left', fontsize=15, fontweight='bold', pad=26)
    ax.text(0, 1.02, subtitle, transform=ax.transAxes, color=INK2, fontsize=10.5)
    ax.figure.tight_layout()
    ax.figure.savefig(OUT / name, dpi=160)
    plt.close(ax.figure)
    print('saved', OUT / name)


def hbar(ax, labels, vals, colors, fmt):
    bars = ax.barh(labels, vals, color=colors, height=0.6, edgecolor=SURFACE, linewidth=2)
    for b, v in zip(bars, vals):
        ax.annotate(fmt.format(v), (v, b.get_y() + b.get_height() / 2), xytext=(4 if v >= 0 else -4, 0),
                    textcoords='offset points', ha='left' if v >= 0 else 'right', va='center', color=INK, fontsize=10)
    ax.axvline(0, color=INK2, linewidth=1)
    ax.grid(axis='y', visible=False)
    ax.invert_yaxis()
    lo, hi = min(vals + [0]), max(vals + [0])
    pad = (hi - lo) * 0.18
    ax.set_xlim(lo - pad, hi + pad)


def vbar(ax, labels, vals, colors, fmt='{:+.1f}%'):
    bars = ax.bar(labels, vals, color=colors, width=0.6, edgecolor=SURFACE, linewidth=2)
    for b, v in zip(bars, vals):
        ax.annotate(fmt.format(v), (b.get_x() + b.get_width() / 2, v), xytext=(0, 4 if v >= 0 else -4),
                    textcoords='offset points', ha='center', va='bottom' if v >= 0 else 'top', color=INK, fontsize=10)
    ax.axhline(0, color=INK2, linewidth=1)
    ax.grid(axis='x', visible=False)
    lo, hi = min(list(vals) + [0]), max(list(vals) + [0])
    pad = (hi - lo) * 0.15
    ax.set_ylim(lo - pad, hi + pad)


l1 = run('sql/02_L1_total_decomposition.sql')[0]
l3 = run('sql/04_L3_where_and_when.sql')[0]
a, q, biz, quint, age = run('sql/05_L4_alley_dinner.sql')

# 1. L1: 건수 vs 객단가
yrs = [y for y in l1['yr'] if y > 2021]
cnt = [v for y, v in zip(l1['yr'], l1['cnt_yoy_pct']) if y > 2021]
tic = [v for y, v in zip(l1['yr'], l1['ticket_yoy_pct']) if y > 2021]
fig, ax = plt.subplots(figsize=(9, 5))
x = range(len(yrs))
for off, vals, c, lab in [(-0.18, cnt, BLUE, '거래 건수'), (0.18, tic, ORANGE, '객단가')]:
    bars = ax.bar([i + off for i in x], vals, width=0.34, color=c, edgecolor=SURFACE, linewidth=2, label=lab)
    for b, v in zip(bars, vals):
        ax.annotate(f'{v:+.1f}%', (b.get_x() + b.get_width() / 2, v), xytext=(0, 4 if v >= 0 else -4),
                    textcoords='offset points', ha='center', va='bottom' if v >= 0 else 'top', fontsize=10)
ax.set_xticks(list(x), [str(y) for y in yrs])
ax.axhline(0, color=INK2, linewidth=1)
ax.grid(axis='x', visible=False)
ax.set_ylim(-4.5, 5)
ax.set_ylabel('전년 대비 증감률(%)')
ax.legend(frameon=False, loc='upper right', ncols=2)
finish(ax, '2025년, 손님은 줄고 객단가가 매출을 떠받쳤다', '서울 전체 오프라인 추정매출 = 거래 건수 × 객단가, 전년 대비 증감률', '01_L1_건수_객단가.png')

# 2. L3: 상권유형별 외식업 매출 증감
idx = [i for i, ax_ in enumerate(l3['axis']) if ax_ == 'area_type']
labs = [l3['item'][i] for i in idx]
vals = [l3['amt_growth_pct'][i] for i in idx]
order = sorted(range(len(vals)), key=lambda i: vals[i])
labs, vals = [labs[i] for i in order], [vals[i] for i in order]
fig, ax = plt.subplots(figsize=(9, 4))
hbar(ax, labs, vals, [ORANGE if l == '골목상권' else GRAY for l in labs], '{:+.2f}%')
ax.set_xlabel('외식업 매출 증감률(%)')
finish(ax, '외식업 매출, 골목상권이 가장 많이 빠졌다', '상권유형별 외식업 추정매출 증감률, 2024 → 2025', '02_L3_상권유형.png')

# 3. L3: 시간대별 외식업 매출 증감
slot_name = {'amt_t00_06': '00~06시', 'amt_t06_11': '06~11시', 'amt_t11_14': '11~14시', 'amt_t14_17': '14~17시',
             'amt_t17_21': '17~21시', 'amt_t21_24': '21~24시'}
idx = [i for i, ax_ in enumerate(l3['axis']) if ax_ == 'time_slot']
keys = [l3['item'][i] for i in idx]
vals = [l3['amt_growth_pct'][i] for i in idx]
fig, ax = plt.subplots(figsize=(9, 5))
vbar(ax, [slot_name[k] for k in keys], vals,
     [ORANGE if k in ('amt_t17_21', 'amt_t21_24') else BLUE if k == 'amt_t11_14' else GRAY for k in keys])
ax.set_ylabel('외식업 매출 증감률(%)')
finish(ax, '점심은 늘고, 저녁·심야가 빠졌다', '시간대별 서울 외식업 추정매출 증감률, 2024 → 2025 (주황 = 저녁, 파랑 = 점심)', '03_L3_시간대.png')

# 4. L4: 골목 외식 저녁 vs 점심 분기별 YoY (2022~23Q1은 코로나 이후 반등기라 제외)
pts = [(y, qt, d, l) for y, qt, d, l in zip(q['yr'], q['qtr'], q['dinner_yoy_pct'], q['lunch_yoy_pct']) if y * 10 + qt >= 20232]
labels = [f"{y % 100}Q{qt}" for y, qt, _, _ in pts]
fig, ax = plt.subplots(figsize=(10, 5))
ax.axvspan(labels.index('23Q4') - 0.4, len(labels) - 0.6, color='#f6e3da', zorder=0)
ax.text(labels.index('23Q4') - 0.3, 6.3, '저녁 7분기 연속 역성장', color=INK2, fontsize=10)
for i, c, lab in [(2, ORANGE, '저녁(17~24시)'), (3, BLUE, '점심(11~14시)')]:
    v = [p[i] for p in pts]
    ax.plot(labels, v, color=c, linewidth=2, marker='o', markersize=6, markeredgecolor=SURFACE, markeredgewidth=2, label=lab)
    ax.annotate(f'{lab.split("(")[0]} {round(v[-1], 1) + 0:+.1f}%', (len(labels) - 1, v[-1]), xytext=(8, 0),
                textcoords='offset points', va='center', fontsize=10,
                bbox=dict(boxstyle='square,pad=0.15', facecolor=SURFACE, edgecolor='none'))
ax.axhline(0, color=INK2, linewidth=1)
ax.set_ylim(-8, 7.5)
ax.set_xlim(-0.5, len(labels) + 0.6)
ax.set_ylabel('전년 동기 대비(%)')
ax.legend(frameon=False, loc='lower left', ncols=2)
finish(ax, '골목 식당, 점심은 버티는데 저녁만 계속 빠진다', '골목상권 외식업 추정매출 전년 동기 대비 증감률', '04_L4_골목_저녁vs점심_분기.png')

# 5. L4: 업종별 저녁매출 기여도
fig, ax = plt.subplots(figsize=(9, 5.5))
hbar(ax, list(biz['biz_name']), list(biz['contribution_pp']), [ORANGE] * len(biz['biz_name']), '{:+.2f}%p')
ax.set_xlabel('골목 외식 저녁매출 증감 기여도(%p)')
finish(ax, '한식의 손님 감소와 호프의 객단가 하락이 저녁 손실의 2/3',
       '골목상권 외식 업종별 저녁(17~24시) 매출 기여도, 2024 → 2025 · 합계 -4.2%p', '05_L4_업종별_저녁기여도.png')

# 6. L4: 연령대별 기여도
age_name = {'a10': '10대', 'a20': '20대', 'a30': '30대', 'a40': '40대', 'a50': '50대', 'a60_plus': '60대 이상', 'unknown': '미상'}
fig, ax = plt.subplots(figsize=(9, 5))
vals = list(age['growth_pct'])
vbar(ax, [age_name[k] for k in age['age']], vals,
     [GRAY if k == 'unknown' else BLUE if v >= 0 else RED for k, v in zip(age['age'], vals)])
ax.set_ylabel('매출 증감률(%)')
finish(ax, '20대가 떠나고 60대 이상이 늘었다', '골목상권 외식업 연령대별 추정매출 증감률, 2024 → 2025 (미상 = 연령 식별 불가 결제)', '06_L4_연령대.png')

# 7. L4: 저녁 성장 5분위별 저녁·점심 성장률
fig, ax = plt.subplots(figsize=(9, 5))
x = range(len(quint['quintile']))
for off, key, c, lab in [(-0.18, 'dinner_growth_pct', ORANGE, '저녁'), (0.18, 'lunch_growth_pct', BLUE, '점심')]:
    vals = list(quint[key])
    bars = ax.bar([i + off for i in x], vals, width=0.34, color=c, edgecolor=SURFACE, linewidth=2, label=lab)
    for b, v in zip(bars, vals):
        ax.annotate(f'{v:+.1f}%', (b.get_x() + b.get_width() / 2, v), xytext=(0, 4 if v >= 0 else -4),
                    textcoords='offset points', ha='center', va='bottom' if v >= 0 else 'top', fontsize=9.5)
ax.set_xticks(list(x), ['1분위\n(급락)', '2분위', '3분위', '4분위', '5분위\n(방어)'])
ax.axhline(0, color=INK2, linewidth=1)
ax.grid(axis='x', visible=False)
ax.set_ylim(-24, 14)
ax.set_ylabel('상권 중앙값 증감률(%)')
ax.legend(frameon=False, loc='upper left', ncols=2)
finish(ax, f"저녁을 지킨 골목은 점심 손님도 늘었다 (상관 r = {quint['r_dinner_lunch'][0]:.2f})",
       '골목상권 637곳을 2024→2025 저녁 외식매출 성장률로 5등분, 분위별 중앙값', '07_L4_상권5분위.png')

# 8. L4: 갭 상권 산점도 (기획안 4-1의 파일럿 대상 정의와 같은 조건)
rows = con.sql("""
    WITH ad AS (
        SELECT area_code,
               SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2024) d0, SUM(amt_t17_21 + amt_t21_24) FILTER (yr = 2025) d1,
               SUM(amt_t11_14) FILTER (yr = 2024) l0, SUM(amt_t11_14) FILTER (yr = 2025) l1
        FROM sales WHERE substr(biz_code, 1, 3) = 'CS1' AND area_type = '골목상권' GROUP BY 1)
    SELECT 100 * (l1 / l0 - 1), 100 * (d1 / d0 - 1), l1 >= l0 AND d1 <= d0 * 0.95, d0 - d1
    FROM ad WHERE d0 >= 1e9 AND d1 > 0 AND l0 > 0""").fetchall()
gap = [r for r in rows if r[2]]
rest = [r for r in rows if not r[2]]
fig, ax = plt.subplots(figsize=(9, 7))
ax.fill_between([0, 60], -60, -5, color='#f6e3da', zorder=0)
ax.scatter([r[0] for r in rest], [r[1] for r in rest], s=14, color=GRAY, label=f'기타 골목상권 {len(rest)}곳', zorder=2)
ax.scatter([r[0] for r in gap], [r[1] for r in gap], s=18, color=ORANGE, edgecolor=SURFACE, linewidth=0.6,
           label=f'갭 상권 {len(gap)}곳', zorder=3)
ax.axhline(0, color=INK2, linewidth=1)
ax.axvline(0, color=INK2, linewidth=1)
ax.set_xlim(-60, 60)
ax.set_ylim(-60, 60)
ax.text(3, -57, f'점심 유지 & 저녁 -5% 이하\n저녁 손실 {sum(r[3] for r in gap) / 1e8:,.0f}억 원', color=INK, fontsize=10.5)
ax.set_xlabel('점심(11~14시) 매출 증감률(%)')
ax.set_ylabel('저녁(17~24시) 매출 증감률(%)')
ax.legend(frameon=False, loc='upper left')
finish(ax, '파일럿 대상: 점심 손님은 있는데 저녁만 빠진 골목',
       '골목상권별 외식 매출 증감률, 2024 → 2025 · 2024 저녁매출 10억 이상 · ±60% 밖은 잘림', '08_L4_갭상권_산점도.png')
