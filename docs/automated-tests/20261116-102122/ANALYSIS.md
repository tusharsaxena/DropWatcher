# Analysis — 20261116-102122

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** add159d (feat/2026-11-16-loose-ends)
- **Previous run:** 20261115-200343

## Headline

All four suites pass on a clean tree at `add159d`, the M12 checkpoint (RX-27 to RX-30). The headless suite also passes under the Forever kit profile with 0 failed. RX-27 cut the refresh pair from 13552 to 11120 bytes/iter and the compact pair from 9200 to 6768, and it moved `modules/Window.lua` back under 1100 (1151 → 1054). Complexity has one new warning: `placeTitle` in `modules/CompactChrome.lua` reached CCN 16, from RX-30's title alignment. It is the one action below, and the next commit fixes it.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261115-200343 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 265 files | [`lint.txt`](lint.txt) | 264 → 265 files (RX-27's `modules/WindowTabs.lua`), still 0/0 |
| tests (Retail profile) | pass | 2598 passed, 1 skipped, 0 failed, 2599 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2564 → 2599 total, skip count 1 unchanged |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2490 passed, 108 skipped, 0 failed, 2598 total | console of `KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --suite tests --no-bundle` (bounded) at `add159d`. The second profile writes no bundle artifact | 2563 → 2598 total, skip count 108 unchanged |
| perf | pass | 9 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 13552 → 11120 and compact pair 9200 → 6768 bytes/iter; the rest unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC +760, functions +101; averages held; max CCN 15 → 16, warnings 0 → 1 |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 76356 |
| Functions | 9194 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 16 |
| Avg tokens / function | 78.7 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 16 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted: `blindFiles` and `crashedFiles` are both 0. The tree grew by 760 NLOC and 101 functions. Avg NLOC (7.6) and avg CCN (2.5) held, and avg tokens went 78.8 → 78.7, so the growth adds size, not density.

**complexity (recorded; not a commit gate, a tag gate).** The one warning is `placeTitle` (`modules/CompactChrome.lua`, CCN 16). It is a regression from this round: RX-30 made the title follow the skin's `title.align`, which put the LEFT and RIGHT branches beside the centered one in one function. That is genuine branching, not defaulting. The function existed before at a lower CCN.

**perf.** RX-27 removed the per-pass footer and pane re-lays from the refresh path. The refresh pair fell from 13552 to 11120 bytes/iter, now 3380 under its 14500 ceiling where it had 948 of headroom. The compact pair fell from 9200 to 6768, now 4732 under 11500 (`BYTE_CEILING` in `tests/perf.lua`). `rollsPanelRaid` (79392), `parseCaptureOff`/`parseCaptureOn` (664), `showDecisionStoodDown` (0) and `insightsCompute` (4957904) are unchanged ([`perf.txt`](perf.txt), [`perf.json`](perf.json)). Timings are not compared across runs.

## What moved

- **lint**: 0/0, now over 265 files (264 before), from RX-27's new `modules/WindowTabs.lua`. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: Retail rose 2564 → 2599 and Forever 2563 → 2598, from the cases RX-27 to RX-30 added. Failed is 0 on both profiles, and skips held at 1 (Retail) and 108 (Forever). [`test-cases.md`](test-cases.md) has the inventory.
- **perf**: the scenario count held at 9. The two refresh pairs fell as above, and every other bytes/iter figure is unchanged.
- **complexity**:
  - NLOC went 75596 → 76356 and functions 9093 → 9194.
  - Max CCN went 15 → 16 and warnings 0 → 1 (`placeTitle`).
  - Band files held at 16 and over-cap files at 0.
  - Within the band:
    - `modules/Window.lua` fell 1151 → 1054.
    - `tests/test_rolls_panel.lua` rose 1060 → 1236.
    - `tests/test_window_shell.lua` rose 1174 → 1256.
    - `tests/test_settings_pages.lua` rose 1190 → 1214.
    - `tests/test_feed.lua` rose 1075 → 1078.
    - `locales/enUS.lua` rose 1052 → 1053.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `placeTitle` | 16 | `modules/CompactChrome.lua` | **Regression, fixed after this run**: the next commit splits the alignment and its x out into `titleAlign` and `titleX`. A `--suite complexity --no-bundle` run then reads max CCN 15 and 0 warnings. |

**Files by `layout-§1` band.** Re-ruled this run; the other 14 entries are carried in `RESULTS.md` with their dispositions:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `modules/Window.lua` | 1054 | **Accepted**: RX-27 moved the tab strip into `modules/WindowTabs.lua` (1151 → 1054), as this entry asked. Peel the next surface out before it passes 1100 again. |
| 1000–1500 (on notice) | `tests/test_rolls_panel.lua` | 1236 | **Accepted**: a suite file that grows with its cases (RX-28's Rolls panel minors took it 1060 → 1236). Split the side card's cases from the panel shell's before it nears the 1500 cap. |

No **Accepted** entry has been carried across three consecutive release runs. So far only the 1.1.0 release run has carried the band entries.

## Actions

1. `modules/CompactChrome.lua` `placeTitle` (CCN 16). Split the alignment and its x into helpers and record a fresh bundle at the fixed commit. This is new here, from RX-30, and nothing tracks it beyond this analysis.
2. `modules/Window.lua` (1054). The earlier analyses' standing action is resolved: RX-27 peeled out the tab strip.
3. `tests/perf.lua` refresh pairs. The last analysis flagged the unexplained +928 bytes/iter. RX-27 found and removed the per-pass re-lays behind it, and the pairs are now below where they were before that growth (refresh 11120, compact 6768). This closes it.
