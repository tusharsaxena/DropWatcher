# Analysis — 20261115-064052

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 20c6364 (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261114-194343

## Headline

All four suites pass on a clean tree at `20c6364`, and the headless suite also passes under the Forever kit profile with 0 failed. This run covers the 25 commits since `2118228`: the LibKa0s v1.102.0 re-vendor, the M6 items and the Rolls panel (RX-17 to RX-20). The suite grew 2487 → 2542 cases and perf gained a ninth scenario, `rollsPanelRaid`, which holds under its ceiling. Max CCN stays 15 with no warnings. One thing to act on: `modules/Window.lua` is now 1130 lines, past the 1100 its own watch-list disposition set as the point to split the tab strip out.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261114-194343 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 264 files | [`lint.txt`](lint.txt) | 261 → 264 files, still 0/0 |
| tests (Retail profile) | pass | 2541 passed, 1 skipped, 0 failed, 2542 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2487 → 2542 total, skip count 1 unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2433 passed, 108 skipped, 0 failed, 2541 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` (bounded) at `20c6364` (no bundle artifact; the second profile writes none) | 2486 → 2541 total, skip count 108 unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 8 → 9 scenarios (`rollsPanelRaid` new); allocation of the eight carried scenarios unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC and functions grew; averages, max CCN and warnings held |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 75106 |
| Functions | 9017 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 79.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted, with `blindFiles` and `crashedFiles` both 0. The tree grew by 1865 NLOC and 215 functions, mostly `modules/RollsPanel.lua` and `modules/RollsPanelRows.lua`, and every average held, so the growth is size, not density.

Every suite is a clean pass, so no suite needs a failure paragraph.

**perf.** The new `rollsPanelRaid` scenario times `NS.RollsPanel.Refresh` over 200 iterations of the raid-mode panel: 0.39220 ms/iter and 89376.0 bytes/iter ([`perf.txt`](perf.txt)), under its 95000-byte ceiling (`ROLLS_PANEL_RAID_CEILING` in `tests/perf.lua`). The refresh pair still allocates 12624.0 bytes/iter and the compact pair 8272.0, off and on matching in both, so capture still costs nothing.

## What moved

- **lint**: 0/0, over 264 files (was 261), from the new Rolls panel module, its rows module and their suites. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: Retail 2487 → 2542 cases (+55), Forever 2486 → 2541 (+55). Failed is 0 on both profiles; skips held at 1 (Retail) and 108 (Forever).
- **perf**: one new scenario, `rollsPanelRaid`. The eight carried scenarios allocate exactly what they did: the refresh pair 12624.0, the compact pair 8272.0, `parseCaptureOff`/`parseCaptureOn` 664.0, `showDecisionStoodDown` 0.0 and `insightsCompute` 4957904.0 bytes/iter. Timings are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: NLOC 73241 → 75106 and functions 8802 → 9017. Avg NLOC (7.6), avg CCN (2.5), avg tokens (79.0), max CCN (15) and warnings (0) held. Band files held at 15 and over-cap files at 0. Within the band, `modules/Window.lua` rose 1089 → 1130, `locales/enUS.lua` 1014 → 1034, `tests/test_feed.lua` 1065 → 1075, `tests/test_settings_pages.lua` 1188 → 1190 and `tests/test_window_shell.lua` 1143 → 1146 (`RESULTS.md` › Complexity watch list).

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

1. `modules/Window.lua` (1130 lines). Its carried disposition reads "move the tab strip's build and paint into its own file before it passes 1100", and this run measures it past that line, from the Rolls panel's open and hold wiring (RX-16, RX-17, RX-20). Either peel the tab strip out, or re-rule the disposition in `RESULTS.md` with a new trigger. This is new here; no deviation ID or review finding tracks it yet.
