# Analysis — 20261116-102800

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** c03cddd (feat/2026-11-16-loose-ends)
- **Previous run:** 20261116-102122

## Headline

All four suites pass on a clean tree at `c03cddd`. The headless suite also passes under the Forever kit profile with 0 failed. This is the M12 checkpoint's green bundle. The previous run's one complexity warning (`placeTitle`, CCN 16) is gone: max CCN is back to 15 and there are 0 warnings. One perf figure moved with no code on its path: `insightsCompute` rose 4957904 → 4987024 bytes/iter (action 1).

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261116-102122 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 265 files | [`lint.txt`](lint.txt) | unchanged |
| tests (Retail profile) | pass | 2598 passed, 1 skipped, 0 failed, 2599 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2490 passed, 108 skipped, 0 failed, 2598 total | console of `KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --suite tests --no-bundle` (bounded) at `c03cddd`. The second profile writes no bundle artifact | unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `insightsCompute` 4957904 → 4987024 bytes/iter; the rest unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +6, functions +2; max CCN 16 → 15, warnings 1 → 0 |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 76362 |
| Functions | 9196 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 16 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted: `blindFiles` and `crashedFiles` are both 0. The fix split `placeTitle` into `titleAlign` and `titleX`: 2 more functions and 6 more NLOC, with every average unchanged.

**perf.** The refresh pair (11120), compact pair (6768), `rollsPanelRaid` (79392), `parseCaptureOff`/`parseCaptureOn` (664) and `showDecisionStoodDown` (0) match the previous run. `insightsCompute` rose 4957904 → 4987024 bytes/iter (+29120) ([`perf.json`](perf.json)). The one commit since the previous run (`c03cddd`) changes `modules/CompactChrome.lua`'s title placement alone, which the Insights compute never calls. Every earlier bundle that recorded the scenario read 4957904. The rise is therefore unexplained, not a measured regression: perf records it and does not gate on it. Timings are not compared across runs.

## What moved

- **lint**: 0/0 over 265 files, unchanged. The scope is unchanged (`RESULTS.md` › Lint).
- **tests**: 2599 total on Retail and 2598 on Forever, unchanged, with 0 failed on both profiles ([`test-cases.md`](test-cases.md)).
- **perf**: `insightsCompute` +29120 bytes/iter, unexplained (above); every other figure unchanged.
- **complexity**: NLOC went 76356 → 76362, functions 9194 → 9196, max CCN 16 → 15 and warnings 1 → 0. Band files held at 16 and over-cap files at 0, every LOC unchanged.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band.** Every LOC is unchanged since the previous run, and the 16 entries are carried in `RESULTS.md` with their dispositions.

| Band | File | LOC | Disposition |
|---|---|---|---|

None newly crossed.

No **Accepted** entry has been carried across three consecutive release runs. So far only the 1.1.0 release run has carried the band entries.

## Actions

1. `tests/perf.lua` `insightsCompute`: 4957904 → 4987024 bytes/iter, with no change on its path. On the next run, check whether the figure holds. A figure that falls back means the scenario does not count its allocations deterministically. A figure that holds needs a bisect over `c03cddd`. This is new here, and nothing tracks it.
