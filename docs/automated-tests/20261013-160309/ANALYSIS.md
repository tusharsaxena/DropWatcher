# Analysis — 20261013-160309

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 453bab1 (feat/2026-10-13-drop-watcher-feedback-5), clean tree
- **Previous run:** 20261013-141937 (measured d2c4e7a)

## Headline

All four suites passed on a clean tree at the M15 milestone (owner feedback 6: the Trade window column fitted to its
widest answer, My eq and Their eq merged into Me and Them, Offer in cyan, the (Details) tooltip, and verdict marks
and arrows drawn as textures wherever the default face would draw a box). Tests grew by 31 passing cases to 1366;
lint stayed clean over 4 more files; complexity grew with the code, averages flat except tokens (+0.6), max CCN up
from 13 to 14 in a test closure, still under 15. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261013-141937 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 168 files | [`lint.txt`](lint.txt) | +4 files (164 before); still 0/0 |
| tests | pass | 1366 passed, 1 skipped, 0 failed, 1367 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +31 passed, +31 total (1335 / 1336 before); skipped unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; full refresh allocation down, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +855 NLOC, +95 functions; max CCN 13 → 14; avg tokens 70.4 → 71.0 |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 40379 |
| Functions | 5201 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.4 |
| Max CCN | 14 |
| Avg tokens / function | 71.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0), so every function was measured. The code grew by 855 NLOC and 95 functions:
two new modules (`modules/SideCells.lua`, the merged Me/Them composers; `modules/TipMarks.lua`, the texture marks)
and their suites (`test_side_cells`, `test_tip_marks`). Avg NLOC and avg CCN held at 7.2 and 2.4; avg tokens rose
0.6, which fits texture-escape strings and formatted tooltip lines being longer token runs than plain words. The
new max, CCN 14, is a test closure (`(anonymous)@494-516` in `tests/test_window_group.lua`, per
[`complexity.txt`](complexity.txt)), not shipped code, and is under the 15 threshold.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are for
orientation only. The full-layout refresh pair allocates 13664.8 bytes per iteration, down from 14400.8 (−736),
which fits two fewer columns painted per row (My eq and Their eq merged into Me and Them). The compact refresh pair
is unchanged at 10368.9. `showDecisionStoodDown` still allocates nothing, and both parse scenarios are unchanged at
664.2 bytes.

## What moved

- **lint:** 164 → 168 files, still 0 warnings and 0 errors.
- **tests:** 1335 → 1366 passed and 1336 → 1367 total: the merged Me/Them cells for every verdict, inspect and
  two-item case, History's verdict-only cells, compact line 3, the step-7 migration, the measured widths and shed
  order, Offer's cyan in each place, the (Details) tooltip lines and their escapes, and an audit that no
  default-face FontString draws one of the six glyphs. The one skip is unchanged.
- **perf:** the same seven scenarios; full refresh allocation −736 bytes, compact unchanged.
- **complexity:** +855 NLOC and +95 functions, avg NLOC and CCN flat, tokens +0.6, max CCN 13 → 14 (a test
  closure), no warnings, nothing in either band.

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
