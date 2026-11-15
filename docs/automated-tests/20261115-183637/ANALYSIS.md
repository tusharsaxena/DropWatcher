# Analysis — 20261115-183637

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** fa8cf5a (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261115-161114

## Headline

All four suites pass on a clean tree at `fa8cf5a`, and the headless suite also passes under the Forever kit profile with 0 failed. This run covers the 5 commits since `31873cb`: the RX-23 bundle, the M8–M10 checkpoints, the M11 plan, RX-24 (the window footer on the library's lines and marks, Sort on the filter bar) and RX-25 (one Expand / Collapse toggle on the Rolls panel's title bar). The case count held at 2560 on Retail and 2559 on Forever. Both refresh pairs rose +448 bytes/iter and stay under their ceilings. Max CCN stays 15 with no warnings. `modules/Window.lua` came down 1144 → 1141 lines but is still past the 1100 its disposition named, so that action carries forward.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261115-161114 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 264 files | [`lint.txt`](lint.txt) | 264 files unchanged, still 0/0 |
| tests (Retail profile) | pass | 2559 passed, 1 skipped, 0 failed, 2560 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2560 total unchanged, skip count 1 unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2451 passed, 108 skipped, 0 failed, 2559 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` (bounded) at `fa8cf5a` (no bundle artifact; the second profile writes none) | 2559 total unchanged, skip count 108 unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 9 scenarios unchanged; both refresh pairs rose 448 bytes/iter (below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC fell 173, functions +1; avg NLOC 7.7 → 7.6, avg tokens 79.1 → 78.8; avg CCN, max CCN and warnings held |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 75518 |
| Functions | 9082 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted, with `blindFiles` and `crashedFiles` both 0. The tree shrank by 173 NLOC and gained one function. Avg NLOC per function went 7.7 → 7.6 and avg tokens 79.1 → 78.8. Both moves are at rounding scale. Avg CCN held at 2.5 and max CCN at 15, so the branching shows no density signal.

Every suite is a clean pass, so no suite needs a failure paragraph.

**perf.** The refresh pair rose 13104.0 → 13552.0 bytes/iter and the compact pair 8752.0 → 9200.0, +448 bytes each. That leaves 948 bytes of headroom under the 14500 ceiling and 2300 under the 11500 ceiling (`BYTE_CEILING` in `tests/perf.lua`, unchanged). Off and on still match in both pairs, so capture still costs nothing ([`perf.txt`](perf.txt)). This run did not isolate the commit that added the bytes. RX-24 is the likely one, because it rebuilt the window footer and the refresh paints that window, but nothing here measures it. This is the second run in a row where the refresh pairs grew (+480 last run, +448 this run). Two more steps of that size would bring the refresh pair within 100 bytes of its ceiling. `rollsPanelRaid` held at 79392.0 bytes/iter under its 95000 ceiling. That is unchanged even with RX-25's title-bar toggle.

## What moved

- **lint**: 0/0 over 264 files, unchanged. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: Retail held at 2560 cases and Forever at 2559. Failed is 0 on both profiles, and skips held at 1 (Retail) and 108 (Forever). RX-24 and RX-25 changed existing cases (`tests/test_window_shell.lua` went from 1146 to 1174 lines) and added no net cases. [`test-cases.md`](test-cases.md) has the inventory.
- **perf**: the scenario count held at 9. The refresh pair went 13104.0 → 13552.0 and the compact pair 8752.0 → 9200.0. `rollsPanelRaid` (79392.0), `parseCaptureOff`/`parseCaptureOn` (664.0), `showDecisionStoodDown` (0.0) and `insightsCompute` (4957904.0) are unchanged. No ceiling was raised. Timings are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: NLOC went 75691 → 75518 and functions 9081 → 9082. Avg CCN (2.5), max CCN (15) and warnings (0) held. Band files held at 15 and over-cap files at 0. Inside the band, `modules/Window.lua` went 1144 → 1141, `modules/WindowGroup.lua` 1171 → 1170, `tests/test_test_mode.lua` 1302 → 1304 and `tests/test_window_shell.lua` 1146 → 1174 (`RESULTS.md` › Complexity watch list).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**: nothing newly crossed this run. All 15 entries are carried in `RESULTS.md` with their dispositions, and none is blank.

| Band | File | LOC | Disposition |
|---|---|---|---|

None newly crossed.

No **Accepted** entry has been carried across three consecutive release runs. So far only the 1.1.0 release run has carried the band entries.

## Actions

1. `modules/Window.lua` (1141 lines). Its carried disposition says to move the tab strip's build and paint into a file of its own before the file passes 1100. It has been past that line for three runs (1130, 1144, 1141). Either peel the tab strip out, or re-rule the disposition in `RESULTS.md` with a new trigger. This action was carried from the previous two analyses, and no deviation ID or review finding tracks it yet.
2. `tests/perf.lua` refresh pairs. Two runs in a row each added about 460 bytes/iter, and 948 bytes of headroom remain under the 14500 ceiling. Find out which part of the RX-24 footer build allocates per refresh before the next window change spends the rest. This action is new here.
