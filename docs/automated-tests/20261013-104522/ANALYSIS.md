# Analysis — 20261013-104522

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 189a13d (feat/2026-10-13-drop-watcher-feedback-4)
- **Previous run:** 20261011-230412 (measured 7b77749)

## Headline

All four suites passed on a clean tree at the M13 milestone (owner feedback 4: verdict and action tones, no
dismissing, the Type column, gold headers, the search box anchors and the least width). Tests grew by 12 passing
cases to 1333; lint stayed clean over the same 161 files; complexity grew with the code and kept every average
flat, with no function above CCN 15 and no blind file. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-230412 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 161 files | [`lint.txt`](lint.txt) | unchanged (0/0 in 161) |
| tests | pass | 1333 passed, 1 skipped, 0 failed, 1334 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +12 passed, +12 total (1321 / 1322 before); skipped unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; allocation per refresh moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +259 NLOC, +33 functions; averages unchanged |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 39660 |
| Functions | 5143 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 70.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0), so every function was measured. The code grew by 259 NLOC and 33 functions
(the Type column's `ArmorType`, the action-tone helpers, the furthest-state query, the new tests) while the averages
held at 7.2 NLOC, CCN 2.4 and 70.0 tokens per function: growth, not densification. Max CCN is still 13.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are for
orientation only. The full-layout refresh pair allocates 14424.8 bytes per iteration, up from 14248.8 (+176),
which fits the Type cell painted on every row. The compact refresh pair allocates 10920.8, down from 11064.8
(−144), which fits the compact card's × and the My drops card's Hide no longer being built or painted, offset in
part by the Type piece on line 2. `showDecisionStoodDown` still allocates nothing, and both parse scenarios are
unchanged at 664.2 bytes.

## What moved

- **lint:** nothing; 0 warnings and 0 errors in 161 files, as before.
- **tests:** 1321 → 1333 passed and 1322 → 1334 total. M13 added cases for the verdict tones and arrow order, the
  action tones (pure and painted), `FurthestState`, `ArmorType`, the Type column, the least width, the search box
  anchors and the gold labels, and removed the cases that exercised dismissing and hiding. The one skip is
  unchanged.
- **perf:** the same seven scenarios; refresh allocation +176 bytes full and −144 bytes compact, as above.
- **complexity:** +259 NLOC and +33 functions, averages flat, max CCN 13, no warnings, nothing in either band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None.
