# Analysis — 20261013-200128

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 98688dc (feat/2026-10-13-drop-watcher-feedback-5)
- **Previous run:** 20261013-160309 (measured 453bab1)

## Headline

All four suites passed on a clean tree at the end of M16 (owner feedback 7: the Offer panel's Their eq column, action
icons, `Upgrade for N`, columnar gear tooltips, Scan group on the Drops strip), M17 (When to show as a table) and M18
(the four-row toast). Tests grew by 31 passing cases to 1397; lint stayed clean over one more file (169, the new
`modules/TipGrid.lua`); complexity grew with the code, the per-function averages moved by a tenth or less, and no
function is above CCN 15. The full-layout refresh allocates 456 bytes more per iteration. Nothing to act on; one
function to watch (below).

## Suites

| Suite | Status | Result | Artifact | Moved since 20261013-160309 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 169 files | [`lint.txt`](lint.txt) | +1 file (168 before), still 0/0 |
| tests | pass | 1397 passed, 1 skipped, 0 failed, 1398 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +31 passed, +31 total (1366 / 1367 before); skipped unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; full refresh +456 bytes/iter, compact unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +1129 NLOC, +102 functions; avg NLOC 7.2 → 7.3, avg tokens 71.0 → 72.3, avg CCN flat |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 41508 |
| Functions | 5303 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.4 |
| Max CCN | 14 |
| Avg tokens / function | 72.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0). The code grew by 1129 NLOC and 102 functions: the tooltip grid (`TipGrid`,
the grid composers in `TipMarks`), the Offer panel's Their eq composer, the When to show table's pure rows and
widgets, the toast's row composer, the marked-cell helpers, and their tests; the give path (`TradeHelper.Give`, four
Compat shims) was removed. Average NLOC and tokens per function rose by about a tenth and 1.3: slightly denser new
code, not a complexity signal at this size. Max CCN is 14 in two functions (`complexity.txt`): the test closure
`(anonymous)@500-522` in `tests/test_window_group.lua`, as before, and, **new to the top of the list**,
`candidateEq@157-176` in `modules/SideCells.lua`. The latter was 16 when DW-G0 wrote it and was brought under the cap
in review (its baseline fallback moved to a helper); it is mostly `and`/`or` guarding of inspect reads.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are orientation
only. The full-layout refresh pair allocates 14120.8 bytes per iteration, up from 13664.8 (+456), which fits the
looter's `[YOU]` mark and the Me/Them gear rows composed per painted row. The compact pair is unchanged at 10368.9.
`showDecisionStoodDown` still allocates nothing and both parse scenarios are unchanged at 664.2 bytes.

## What moved

- **lint:** one more file in scope (169), 0 warnings and 0 errors.
- **tests:** 1366 → 1397 passed, 1367 → 1398 total. Added: the Offer panel's Their eq cell and stripes, the icon walk
  over every action look, the `[YOU]` mark and `Upgrade for N`, the tooltip grid (data, column arithmetic, painted
  hover), the strip's Scan group slot and Post-over-Sort alignment, the centered empty-state pair, the When to show
  table (pure rows, painted table, Defaults and profile repaint, re-hosting), the toast's four rows, width fit and
  right-click. Removed: the give path's cases (TradeHelper.Give, the four Compat shims). The one skip is unchanged.
- **perf:** +456 bytes per full refresh; nothing else moved.
- **complexity:** +1129 NLOC, +102 functions, max CCN 14, no warnings, nothing in either band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None. `modules/WindowGroup.lua` is the largest module near the band, at 969 lines (it reached 997 during M16 before
the review moved the empty state out); the next feature there should split it rather than grow it.

## Actions

None.
