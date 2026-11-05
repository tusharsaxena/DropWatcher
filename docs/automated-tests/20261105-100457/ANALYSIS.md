# Analysis — 20261105-100457

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** fcc2815 (feat/2026-11-05-issues-10-14), clean tree
- **Previous run:** 20261104-042156 (measured 5add81d, 65 commits behind this one)

## Headline

All four suites pass at the end of the issues #10-#14 run (the item categories and lists of #13, the Insights tab of #12, the toast stack, the LibKa0s v1.87.0 and v1.88.0 re-vendors). Lint is 0/0, no function is above CCN 15, and nothing is blind or crashed. The case count rose by 255 and a new perf scenario, `insightsCompute`, pins the Insights recompute. Two test files newly crossed into the 1000–1500 band and are ruled on below. The refresh pair's bytes/iter rose by 832 and is still under its ceiling. The one action is to account for that rise.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261104-042156 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 241 files | [`lint.txt`](lint.txt) | 213 → 241 files, still 0/0 |
| tests | pass | 2215 passed, 1 skipped, 0 failed, 2216 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1961 → 2216 cases |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 7 → 8 scenarios (`insightsCompute` new); refresh bytes/iter +832, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 56014 → 63279, functions 6986 → 7785, band 8 → 10 |

| Metric | Value |
|---|---|
| Total NLOC | 63279 |
| Functions | 7785 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 76.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 10 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass, and every figure above is from [`manifest.json`](manifest.json). The one skipped case is still the diagnostics-contract case in [`tests.txt`](tests.txt): this addon keeps the default `Kit.diagnostics.enablesLogging`, so the opt-out case does not apply to it. It counts toward the total but not toward `passed`. The complexity figures are sighted (`blindFiles` 0, `crashedFiles` 0).

## What moved

- **lint:** still 0/0. The file count rose 213 → 241 with the run's new modules and suites (the Insights filters, stats and tab, the collectible Compat tier and the item-list cases). `.luacheckrc`'s six exclusions did not change.
- **tests:** 1961 → 2216 (+255). The new cases cover issue #13's item kinds, collectibles, whitelist and blacklist, issue #12's Insights filters, stats, charts and tab, the toast stack, the LinkDetail and restriction-signature fixes (#10, #11), and the library's kit suites from the two re-vendors. `docs/test-cases.md` is identical to this bundle's [`test-cases.md`](test-cases.md), and the README badge already reads 2215/2215.
- **perf:** one new scenario, `insightsCompute`: 20 iterations at 37.53655 ms/iter and 4956816 bytes/iter, under its 5200000-byte ceiling in `tests/perf.lua`. It is the pure filter-and-stats pass over a history at the safety ceiling, and by design it notes nothing. It is not a combat path. From [`perf.txt`](perf.txt), previous → this run:
  - `refreshCaptureOff` 13456 → 14288 bytes/iter, 0.13546 → 0.11031 ms
  - `refreshCaptureOn` 13456 → 14288 bytes/iter, 0.13192 → 0.11213 ms
  - `refreshCompactCaptureOff` 10224 → 11056 bytes/iter, 0.15573 → 0.13642 ms
  - `refreshCompactCaptureOn` 10224 → 11056 bytes/iter, 0.14052 → 0.12253 ms
  - `showDecisionStoodDown` 0 → 0 bytes/iter, 0.00021 → 0.00012 ms
  - `parseCaptureOff` 664 → 664 bytes/iter, 0.01587 → 0.01251 ms
  - `parseCaptureOn` 664 → 664 bytes/iter, 0.01728 → 0.01277 ms

  Both refresh pairs rose by the same 832 bytes, and each pair is still equal across capture off and on, so the zero-overhead evidence holds. The rise is in the window's pass itself. The Insights tab joined the tab strip this run, which is the likely source, but `tests/perf.lua`'s ceiling comments do not yet record it. The full pass now has 212 bytes of headroom under its 14500 ceiling, and the compact pass has 444 under 11500. The stood-down decision still allocates nothing and the parse pair did not move. Timings are faster across the board, the parse pair included, which this run did not touch. The previous run was slowed by host load (its tests took 83774 ms against 78296 ms here), so read the timings as orientation only.
- **complexity:** NLOC 56014 → 63279 and functions 6986 → 7785. Avg NLOC (7.4), avg CCN (2.4) and max CCN (15) are unchanged. Avg tokens rose 74.9 → 76.8, which is slight. The code grew by 13% without getting denser in branching. No function is above CCN 15. The band rose 8 → 10: `tests/test_test_mode.lua` (986 → 1158) and `tests/wow_mock.lua` (991 → 1000) newly crossed. Most band files grew, and all of them are still under the split lines their dispositions name: `modules/LootFeed.lua` 1080 (line 1100), `modules/Window.lua` 1064 (1100), `modules/WindowCells.lua` 1177 (1250) and `modules/WindowGroup.lua` 1157 (1250).

## Complexity watch list

Functions:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/LootFeed.lua` | 1080 | LOC moved (1041 → 1080), disposition carried in `RESULTS.md`; 20 lines under its 1100 split line |
| 1000–1500 (on notice) | `modules/Window.lua` | 1064 | LOC moved (1025 → 1064), disposition carried in `RESULTS.md`; 36 lines under its 1100 split line |
| 1000–1500 (on notice) | `modules/WindowCells.lua` | 1177 | LOC moved (1165 → 1177), disposition carried in `RESULTS.md`; under its 1250 split line |
| 1000–1500 (on notice) | `modules/WindowGroup.lua` | 1157 | LOC moved (1156 → 1157), disposition carried in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_compat.lua` | 1053 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_settings_pages.lua` | 1062 | LOC moved (1052 → 1062), disposition carried in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_test_mode.lua` | 1158 | **Newly crossed** (986 → 1158): **Accepted**, a suite file that grows with its cases; split the Insights sample cases out before it nears the cap |
| 1000–1500 (on notice) | `tests/test_window_group.lua` | 1065 | carried forward unchanged in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/test_window_shell.lua` | 1074 | LOC moved (1057 → 1074), disposition carried in `RESULTS.md` |
| 1000–1500 (on notice) | `tests/wow_mock.lua` | 1000 | **Newly crossed** (991 → 1000), at the band's edge: **Accepted**, the next API family goes into its own mock file |

No disposition has been carried as Accepted across three consecutive release runs. The band entries date from 1.0.0 → 1.1.0 at the earliest, so they have seen one release.

## Actions

1. `tests/perf.lua`: record why the refresh pairs rose 832 bytes (13456 → 14288 full, 10224 → 11056 compact) in the ceiling comment, and the 212 bytes of headroom the full pass has left under 14500. The likely cause is the Insights tab in the strip. This action is new here and has no owner yet.
2. `modules/LootFeed.lua` (1080) and `modules/Window.lua` (1064) are within 40 lines of the 1100 split line their dispositions set. The split is owed when either passes it. They are already tracked by those dispositions, so this action is not new.
