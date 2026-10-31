# Analysis — 20261101-025807

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 18ddf3c (feat/2026-10-31-findings-remediation), clean tree
- **Previous run:** 20261101-001631 (measured ec6b6c5)

## Headline

The final pre-merge run passes all four suites on the re-cut LibKa0s v1.84.0, with lint 0/0, no
function above CCN 15 and nothing blind or crashed. The case count, the skip and the perf byte
readings all held, and total NLOC moved by one. Perf timings read higher than the previous run in
all seven scenarios, on a run whose test suite was also slower. Nothing newly crossed a
threshold, so no Disposition is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-001631 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 208 files | [`lint.txt`](lint.txt) | nothing moved |
| tests | pass | 1849 passed, 1 skipped, 0 failed, 1850 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | nothing moved; `test-cases.md` is unchanged from the previous run's |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in all seven; timings moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 54463 → 54464; every other figure unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 54464 |
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

Every suite is a clean pass. The one skipped case is the standing diagnostics-contract case in
[`tests.txt`](tests.txt): this addon keeps the default `Kit.diagnostics.enablesLogging`, so the
opt-out case does not apply to it.

## What moved

- **lint:** did not move, 0/0 over 208 files.
- **tests:** did not move, 1850 cases with one skip. Suite time rose 51323 ms → 82073 ms in
  `manifest.json`.
- **perf:** bytes/iter did not move in any scenario. Time per iteration in [`perf.txt`](perf.txt),
  previous → this run:
  - `refreshCaptureOff` 0.08907 → 0.15733
  - `refreshCaptureOn` 0.08182 → 0.13061
  - `refreshCompactCaptureOff` 0.09206 → 0.12662
  - `refreshCompactCaptureOn` 0.09353 → 0.13194
  - `showDecisionStoodDown` 0.00012 → 0.00014
  - `parseCaptureOff` 0.01157 → 0.01583
  - `parseCaptureOn` 0.01200 → 0.01600

  Lint, tests, perf and complexity all took longer in this run's manifest (total 64565 ms →
  99212 ms), and the identical allocation figures point at a busier host, not a heavier path. This
  bundle does not prove that, so the next run's timings are the check.
- **complexity:** NLOC 54463 → 54464. Functions, all averages, max CCN, warnings and the band are
  unchanged.

## Complexity watch list

Functions:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/LootFeed.lua` | 1041 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/WindowCells.lua` | 1165 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/WindowGroup.lua` | 1138 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_compat.lua` | 1030 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_settings_pages.lua` | 1052 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_group.lua` | 1065 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_shell.lua` | 1034 | carried forward unchanged in `RESULTS.md` |

## Actions

None.
