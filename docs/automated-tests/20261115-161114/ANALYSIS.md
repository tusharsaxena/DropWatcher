# Analysis — 20261115-161114

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 31873cb (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261115-064052

## Headline

All four suites pass on a clean tree at `31873cb`, and the headless suite also passes under the Forever kit profile with 0 failed. This run covers the 15 commits since `20c6364`: the M8 Rolls panel round 2 (RX-21, RX-22), the LibKa0s v1.103.0 re-vendor with the strips docked under the title bar and the footer built with Widgets Footer (UC-DW), and the RX-23 review fixes. The suite grew 2542 → 2560 cases, `rollsPanelRaid` now opens all six blocks and still holds under its unraised ceiling, and max CCN stays 15 with no warnings. One thing is still open: `modules/Window.lua` is now 1144 lines, further past the 1100 its watch-list disposition set as the point to split the tab strip out.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261115-064052 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 264 files | [`lint.txt`](lint.txt) | 264 files unchanged, still 0/0 |
| tests (Retail profile) | pass | 2559 passed, 1 skipped, 0 failed, 2560 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2542 → 2560 total, skip count 1 unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2451 passed, 108 skipped, 0 failed, 2559 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` (bounded) at `31873cb` (no bundle artifact; the second profile writes none) | 2541 → 2559 total, skip count 108 unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 9 scenarios unchanged; `rollsPanelRaid` and both refresh pairs moved in bytes (below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions grew; avg NLOC 7.6 → 7.7, avg tokens 79.0 → 79.1; avg CCN, max CCN and warnings held |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 75691 |
| Functions | 9081 |
| Avg NLOC / function | 7.7 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 79.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted, with `blindFiles` and `crashedFiles` both 0. The tree grew by 585 NLOC and 64 functions. Avg NLOC per function ticked 7.6 → 7.7 and avg tokens 79.0 → 79.1 (rounding-scale moves), while avg CCN held at 2.5 and max CCN at 15, so there is no density signal in the branching.

Every suite is a clean pass, so no suite needs a failure paragraph.

**perf.** `rollsPanelRaid` now times the round-2 panel with all six blocks open (RX-21 removed the one-open rule, per the comment in `tests/perf.lua`): 0.55825 ms/iter and 79392.0 bytes/iter ([`perf.txt`](perf.txt)), down from 89376.0 at the previous run and under the unchanged 95000-byte ceiling (`ROLLS_PANEL_RAID_CEILING`). The refresh pair rose 12624.0 → 13104.0 bytes/iter and the compact pair 8272.0 → 8752.0, +480 bytes each, under their 14500 and 11500 ceilings. Off and on still match in both pairs, so capture still costs nothing. This run did not isolate which commit added the 480 bytes; the window chrome change (UC-DW) is the candidate, since it touched the window the refresh paints, but that is not measured here.

## What moved

- **lint**: 0/0 over 264 files, unchanged. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: Retail 2542 → 2560 cases (+18), Forever 2541 → 2559 (+18). Failed is 0 on both profiles. Skips held at 1 (Retail) and 108 (Forever).
- **perf**: the scenario count held at 9. `rollsPanelRaid` went 89376.0 → 79392.0 bytes/iter, now measuring six open blocks instead of one. The refresh pair went 12624.0 → 13104.0 and the compact pair 8272.0 → 8752.0. `parseCaptureOff`/`parseCaptureOn` (664.0), `showDecisionStoodDown` (0.0) and `insightsCompute` (4957904.0) are unchanged. No ceiling was raised. Timings are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: NLOC 75106 → 75691 and functions 9017 → 9081. Avg CCN (2.5), max CCN (15) and warnings (0) held. Band files held at 15 and over-cap files at 0. Within the band, `modules/Window.lua` rose 1130 → 1144, `locales/enUS.lua` 1034 → 1052 and `modules/TestData.lua` 1146 → 1147 (`RESULTS.md` › Complexity watch list).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**: none newly crossed this run. All 15 entries are carried in `RESULTS.md` with their dispositions, none blank.

| Band | File | LOC | Disposition |
|---|---|---|---|

None newly crossed.

No **Accepted** entry has been carried across three consecutive release runs. Only the 1.1.0 release run has carried the band entries so far.

## Actions

1. `modules/Window.lua` (1144 lines). Its carried disposition reads "move the tab strip's build and paint into its own file before it passes 1100". The previous run flagged it at 1130, and it has grown 14 more lines since. Either peel the tab strip out, or re-rule the disposition in `RESULTS.md` with a new trigger. It is carried from the previous run's analysis, and no deviation ID or review finding tracks it yet.
