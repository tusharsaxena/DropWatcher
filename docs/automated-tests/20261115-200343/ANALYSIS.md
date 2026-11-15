# Analysis — 20261115-200343

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** ee7cadd (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261115-183637

## Headline

All four suites pass on a clean tree at `ee7cadd`, and the headless suite also passes under the Forever kit profile with 0 failed. This run covers the 4 commits since `fa8cf5a`: the RX-24 bundle, the M11 checkpoint, RX-26 (Rolls panel tooltips open outside the panel, away from the window) and its ledger entry. The case count rose 2560 → 2564 on Retail and 2559 → 2563 on Forever. Every perf figure held, so the refresh-pair growth of the last two runs did not continue. `tests/test_rolls_panel.lua` newly crossed into the 1000–1500 band (994 → 1060), and `modules/Window.lua` grew 1141 → 1151, further past the 1100 its disposition named.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261115-183637 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 264 files | [`lint.txt`](lint.txt) | 264 files unchanged, still 0/0 |
| tests (Retail profile) | pass | 2563 passed, 1 skipped, 0 failed, 2564 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2560 → 2564 total, skip count 1 unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2455 passed, 108 skipped, 0 failed, 2563 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` (bounded) at `ee7cadd` (no bundle artifact; the second profile writes none) | 2559 → 2563 total, skip count 108 unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 9 scenarios unchanged; every bytes/iter figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +78, functions +11; every average, max CCN and warnings held; band files 15 → 16 |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 75596 |
| Functions | 9093 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 16 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted, with `blindFiles` and `crashedFiles` both 0. The tree grew by 78 NLOC and 11 functions, and every average held (avg NLOC 7.6, avg CCN 2.5, avg tokens 78.8), so the growth is size with no density signal. Max CCN held at 15.

Every suite is a clean pass, so no suite needs a failure paragraph.

**perf.** Every bytes/iter figure matches the previous run: refresh pair 13552.0, compact pair 9200.0, `rollsPanelRaid` 79392.0, `parseCaptureOff`/`parseCaptureOn` 664.0, `showDecisionStoodDown` 0.0 and `insightsCompute` 4957904.0 ([`perf.txt`](perf.txt), [`perf.json`](perf.json)). RX-26 changed `modules/RollsPanel.lua` and `modules/Window.lua` and added no per-refresh allocation that these scenarios see. The refresh pair keeps 948 bytes of headroom under its 14500 ceiling and the compact pair 2300 under 11500 (`BYTE_CEILING` in `tests/perf.lua`). Timings are not compared across runs.

## What moved

- **lint**: 0/0 over 264 files, unchanged. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: Retail rose 2560 → 2564 and Forever 2559 → 2563, the four new cases being RX-26's tooltip-placement cases in `tests/test_rolls_panel.lua` (+66 lines). Failed is 0 on both profiles, and skips held at 1 (Retail) and 108 (Forever). [`test-cases.md`](test-cases.md) has the inventory.
- **perf**: the scenario count held at 9 and every bytes/iter figure is unchanged (above).
- **complexity**: NLOC went 75518 → 75596 and functions 9082 → 9093. Avg NLOC (7.6), avg CCN (2.5), avg tokens (78.8), max CCN (15) and warnings (0) held. Band files went 15 → 16 and over-cap files held at 0. `tests/test_rolls_panel.lua` newly crossed at 1060, and `modules/Window.lua` went 1141 → 1151 (`RESULTS.md` › Complexity watch list).

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band** — newly crossed this run (the other 15 entries are carried in `RESULTS.md` with their dispositions):

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_rolls_panel.lua` | 1060 | **Newly crossed** (994 at the previous run), from RX-26's tooltip-placement cases. **Accepted**: a suite file that grows with its cases; split the side card's cases from the panel shell's before it nears the 1500 cap. |

No **Accepted** entry has been carried across three consecutive release runs. So far only the 1.1.0 release run has carried the band entries.

## Actions

1. `modules/Window.lua` (1151 lines). Its carried disposition says to move the tab strip's build and paint into a file of its own before the file passes 1100. It has now been past that line for four runs (1130, 1144, 1141, 1151), and RX-26 added 10 lines to it. Either peel the tab strip out, or re-rule the disposition in `RESULTS.md` with a new trigger. Carried from the previous three analyses; no deviation ID or review finding tracks it yet.
2. `tests/perf.lua` refresh pairs. The growth flagged last run did not continue (no change this run), but the +928 bytes/iter of the two runs before it is still unexplained and 948 bytes of headroom remain under 14500. Carried from the previous analysis.
