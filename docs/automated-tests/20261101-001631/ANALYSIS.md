# Analysis — 20261101-001631

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** ec6b6c5 (feat/2026-10-31-findings-remediation), clean tree
- **Previous run:** 20261031-213421 (measured 091e1b8)

## Headline

All four suites pass on the LibKa0s v1.84.0 payload, with lint 0/0 and no function above CCN 15.
Tests rose 1846 → 1850 from the XX-67 settings work, and every perf byte reading held. One thing
moved into a threshold: `tests/test_settings_pages.lua` entered the 1000–1500 band, so the band went
6 → 7. It carries a new disposition and nothing else is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-213421 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 208 files | [`lint.txt`](lint.txt) | nothing moved |
| tests | pass | 1849 passed, 1 skipped, 0 failed, 1850 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1846 → 1850, skip count unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in all seven |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 54377 → 54463, functions 6706 → 6714, avg tokens 75.5 → 75.6, band 6 → 7 |

| Metric | Value |
|---|---|
| Total NLOC | 54463 |
| Functions | 6714 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 75.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 7 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from [`manifest.json`](manifest.json)'s `suites.complexity`.

**tests (a skip).** The one skipped case ([`tests.txt`](tests.txt)) is the kit's diagnostics-contract
case for an addon that opts out of turning logging on. This addon keeps the default, so the case does
not apply. It is the same skip as the previous run, a pre-existing condition.

## What moved

Against 20261031-213421 (091e1b8):

- **Lint:** did not move, 0/0 over 208 files.
- **Tests:** 1846 → 1850 cases, all passing but the same one skip. [`test-cases.md`](test-cases.md)
  takes `test_settings_pages.lua` from 49 to 53 cases: four new `feed` cases cover a situation's own
  quality and the item level modes, and three `feed` cases were reworded.
- **Perf:** all seven scenarios hold their bytes/iter: 13456.0 for `refreshCaptureOff`/`On`, 10224.0
  for `refreshCompactCaptureOff`/`On`, 0.0 for `showDecisionStoodDown` and 664.0 for
  `parseCaptureOff`/`On`. In each pair capture off and capture on allocate the same bytes, so the
  zero-overhead pairing holds. The ms/iter figures differ, but [`perf.txt`](perf.txt) says to compare
  them within a run only.
- **Complexity:** NLOC 54377 → 54463 and functions 6706 → 6714. Avg NLOC 7.4 and avg CCN 2.4 did not
  move, and avg tokens rose 75.5 → 75.6. Max CCN stayed 15 and warnings stayed 0, so the rise is
  growth and not density.
- **Band:** `tests/test_settings_pages.lua` newly crossed at 1052 LOC, 6 → 7. The six already there
  hold the LOC they held last run, and none is over the cap.

## Complexity watch list

### Functions

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 | `modules/LootFeed.lua` | 1041 | Carried **Accepted**: unchanged at 1041, under its 1100 split line |
| 1000–1500 | `modules/WindowCells.lua` | 1165 | Carried: Trade composers split before 1250; unchanged at 1165 |
| 1000–1500 | `modules/WindowGroup.lua` | 1138 | Carried **Accepted**: under its 1250 split line; unchanged at 1138 |
| 1000–1500 | `tests/test_compat.lua` | 1030 | Carried **Accepted**: unchanged at 1030 |
| 1000–1500 | `tests/test_settings_pages.lua` | 1052 | **Newly crossed.** **Accepted**: a suite file that grows with its cases; split it by settings page before it nears the 1500 cap |
| 1000–1500 | `tests/test_window_group.lua` | 1065 | Carried **Accepted**: unchanged at 1065 |
| 1000–1500 | `tests/test_window_shell.lua` | 1034 | Carried **Accepted**: unchanged at 1034 |

One Disposition cell was blank, and this run authored it. The rulings are in
[`RESULTS.md`](../RESULTS.md)'s Disposition column.

## Actions

None.
