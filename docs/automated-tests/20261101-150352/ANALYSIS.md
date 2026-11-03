# Analysis — 20261101-150352

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** a2a1dbf (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-025807 (measured 18ddf3c)

## Headline

All four suites pass on LibKa0s v1.85.0 with the FS-DW-FLIP and FS-DW-FIX changes in: lint 0/0, no
function above CCN 15, nothing blind or crashed. The case count rose by 28 with the two new suites,
and perf bytes/iter did not move in any scenario. One file newly crossed the 1000-line band,
`modules/Window.lua` at 1005, and its Disposition is written in `RESULTS.md`.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-025807 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 210 files | [`lint.txt`](lint.txt) | 208 → 210 files, the two new suites |
| tests | pass | 1877 passed, 1 skipped, 0 failed, 1878 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1850 → 1878 cases |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in all seven; timings moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 54464 → 55132, functions 6714 → 6802, band 7 → 8 |

| Metric | Value |
|---|---|
| Total NLOC | 55132 |
| Functions | 6802 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 75.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skipped case is the standing diagnostics-contract case in
[`tests.txt`](tests.txt): this addon keeps the default `Kit.diagnostics.enablesLogging`, so the
opt-out case does not apply to it.

## What moved

- **lint:** still 0/0, over two more files.
- **tests:** 28 more cases, `test_skin_flip` and `test_skin_host`. Suite time rose 82073 ms → 123410 ms
  in `manifest.json`; other repos' batteries were running on the bounded pool at the same time.
- **perf:** bytes/iter did not move in any scenario, so the row signature's resolved shadow and the
  one reused `S.HudFont` opts table added no allocation to a repaint. Time per iteration in
  [`perf.txt`](perf.txt), previous → this run:
  - `refreshCaptureOff` 0.15733 → 0.11754
  - `refreshCaptureOn` 0.13061 → 0.11587
  - `refreshCompactCaptureOff` 0.12662 → 0.11689
  - `refreshCompactCaptureOn` 0.13194 → 0.14277
  - `showDecisionStoodDown` 0.00014 → 0.00023
  - `parseCaptureOff` 0.01583 → 0.01215
  - `parseCaptureOn` 0.01600 → 0.01827

  The previous run was itself the slow one, and these move both ways with identical allocation, so
  they read as host noise. The scenarios do not cover the first-paint cost of one font object per
  table string, which the library holds for the session.
- **complexity:** NLOC 54464 → 55132 and functions 6714 → 6802, the host and suite
  growth of this run; every average, max CCN and the warnings are unchanged.

## Complexity watch list

Functions:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/LootFeed.lua` | 1041 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Window.lua` | 1005 | **Newly crossed**, see `RESULTS.md` |
| 1000–1500 (on notice) | `modules/WindowCells.lua` | 1165 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/WindowGroup.lua` | 1146 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_compat.lua` | 1030 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_settings_pages.lua` | 1052 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_group.lua` | 1065 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_shell.lua` | 1037 | carried forward unchanged in `RESULTS.md` |

## Actions

Owner smoke: SKIN-37..43, and SKIN-2, SKIN-14, SKIN-30 and GLOW-9, whose expected results moved.
