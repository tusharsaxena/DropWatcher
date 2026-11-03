# Analysis — 20261104-042156

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 5add81d (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-203422 (measured 6074774, 30 commits behind this one)

## Headline

All four suites pass at the end of the full skinning run's round 6 (LibKa0s v1.85.0, the sim checkbox re-cut): lint 0/0, no function above CCN 15, nothing blind or crashed. The case count rose by 33, from rounds 3 to 6 (header band, icon edge, skin picker preview, the Sim mode box). Perf bytes/iter did not move in any scenario. Nothing newly crossed a threshold, and there is nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-203422 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 213 files | [`lint.txt`](lint.txt) | 210 → 213 files, still 0/0 |
| tests | pass | 1960 passed, 1 skipped, 0 failed, 1961 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1928 → 1961 cases |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in all seven; timings moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 55305 → 56014, functions 6869 → 6986, band 8 → 8 |

| Metric | Value |
|---|---|
| Total NLOC | 56014 |
| Functions | 6986 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 74.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skipped case is the standing diagnostics-contract case in [`tests.txt`](tests.txt): this addon keeps the default `Kit.diagnostics.enablesLogging`, so the opt-out case does not apply to it. It is counted in the total and not in `passed`.

## What moved

- **lint:** still 0/0; the file count rose 210 → 213 with the new suites (`test_header_band`, `test_sim_checkbox`, `test_launcher_skin_entry`).
- **tests:** 1928 → 1961. The new cases are the window header band (R5-WIN), the icon edge (R5-ICON), the skin picker's preview as test mode (R6-PV), the Sim mode box beside Test mode (R6-SIM), and the library's kit suites from the round 6 re-vendor.
- **perf:** bytes/iter did not move in any scenario (13456, 13456, 10224, 10224, 0, 664, 664). Time per iteration in [`perf.txt`](perf.txt), previous → this run:
  - `refreshCaptureOff` 0.11331 → 0.13546
  - `refreshCaptureOn` 0.08591 → 0.13192
  - `refreshCompactCaptureOff` 0.11080 → 0.15573
  - `refreshCompactCaptureOn` 0.11066 → 0.14052
  - `showDecisionStoodDown` 0.00012 → 0.00021
  - `parseCaptureOff` 0.01152 → 0.01587
  - `parseCaptureOn` 0.01173 → 0.01728

  Every scenario is slower by a similar factor, the parse scenarios included, which this run's code did not touch, and allocation is identical. The run queued behind eight other bounded runs and its test suite took 83774 ms against 58057 ms last time ([`manifest.json`](manifest.json)), so these read as host load, not a regression.
- **complexity:** NLOC 55305 → 56014 and functions 6869 → 6986. Avg NLOC (7.4), avg CCN (2.4) and max CCN (15) are unchanged, and avg tokens fell 75.2 → 74.9: the code grew without getting denser. No warning.

## Complexity watch list

Functions:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/LootFeed.lua` | 1041 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/Window.lua` | 1025 | LOC moved (1007 → 1025), disposition carried in `RESULTS.md`; still under its 1100 split line |
| 1000–1500 (on notice) | `modules/WindowCells.lua` | 1165 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `modules/WindowGroup.lua` | 1156 | LOC moved (1152 → 1156), disposition carried in `RESULTS.md`; still under its 1250 split line |
| 1000–1500 (on notice) | `tests/test_compat.lua` | 1053 | LOC moved (1030 → 1053), disposition carried in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_settings_pages.lua` | 1052 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_group.lua` | 1065 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_shell.lua` | 1057 | LOC moved (1037 → 1057), disposition carried in `RESULTS.md` |

## Actions

None.
