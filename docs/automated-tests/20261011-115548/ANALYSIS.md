# Analysis — 20261011-115548

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 394af4f (feat/2026-10-10-drop-watcher-v1)
- **Previous run:** 20261011-091808

## Headline

Green: all four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` 0, so
the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). This run
measures milestone M7, the in-game simulator (DW-70 to DW-73, docs in DW-74), on top of the v1 build
the previous run measured. The one file that run put on notice, `core/Compat.lua`, has left the
1000–1500 band: the DW-61 peel took it to 981 lines, and the simulator's world reads went to their own
`core/CompatWorld.lua` rather than into it, so it ends this run at 999. No authored file is over 1000
lines, and no new ruling is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-091808 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 125 files | [`lint.txt`](lint.txt) | 109 → 125 files, still 0/0 |
| tests | pass | 984 passed, 1 skipped, 0 failed, 985 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 886/1/887 → 984/1/985 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged on all five |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 29037 |
| Functions | 3808 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 66.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). The CCN 13 functions
are the same four as last run: `uniquePlan` (`modules/Evaluate.lua`), `Window.SetMinimized`
(`modules/Window.lua`), `eqText` (`modules/MineCells.lua`) and `bestCandidate`
(`settings/Editors.lua`). The simulator adds none of them. Its highest is `E.Trade` in
`modules/SimEvents.lua` at CCN 10, then `E.Loot`, `tradeOf` and `E.Plan` at 9, all within the plan's
aim of 10.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
974), which does not apply because this addon keeps the default. It is a standing condition, the
same skip as the previous two runs.

**perf.** All five scenarios allocate exactly what they did last run: 13456.1 bytes per iteration for
the refresh pair, 664.2 for the parse pair and 0.0 for the stood-down show decision
([`perf.txt`](perf.txt)). So the simulator's seam costs these live paths no allocation: with no
simulation running, each wrapped Compat member adds one boolean test. The capture-off / capture-on
pairs still read equal bytes. Timings moved within noise and are for orientation only.

## What moved

- **lint:** in-scope files went from 109 to 125. Thirteen of the sixteen are the simulator's: its
  nine modules (`core/SimSeam.lua`, `core/CompatWorld.lua`, `modules/Sim.lua`, `SimPool.lua`,
  `SimRoster.lua`, `SimWorld.lua`, `SimEvents.lua`, `SimScenario.lua`, `settings/SimVerbs.lua`) and
  its four suites. The other three are the DW-61/DW-62 peels that landed after the previous run's
  commit (`core/TextParse.lua`, `modules/FeedFilter.lua`, `tests/test_text_parse.lua`). Still 0/0,
  with the `.luacheckrc` exclusions unchanged.
- **tests:** cases went from 887 to 985 (886 to 984 passing): the simulator's suites
  (`test_sim_core`, `test_sim_pool`, `test_sim_events`, `test_sim_scenario`, including the
  end-to-end `key` and `raid` runs), the text-parser suite and the DW-62 review fixes. The skip
  count did not move (1).
- **perf:** no movement in allocation; same five scenarios.
- **complexity:** NLOC went from 25529 to 29037 and functions from 3369 to 3808, mostly the
  simulator. The averages barely moved (avg NLOC 7.0 → 7.1, avg CCN 2.4 → 2.4, avg tokens 66.5 →
  66.9), so the new code is as small and flat as the rest. Max CCN held at 13. The 1000–1500 band
  went from 1 file to 0.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. `core/Compat.lua`, the previous run's only row, is at 999 lines and out of the band. It sits at
the plan's 1000-line target with no room, so M7 put its new client reads in `core/CompatWorld.lua`
instead (compat-§1 holds: both files are the compat layer).

## Actions

1. `core/Compat.lua`: any further shim goes to a sibling compat file, as `core/CompatWorld.lua` did,
   until LibKa0s ships the chat sender or the tooltip line reader and the local copies are deleted
   (the existing `## Documented deviations` row in `docs/ARCHITECTURE.md`; no new deviation).
2. The simulator's in-client checks SIM-1 to SIM-7 in `docs/smoke-tests.md` are owed to the owner;
   this bundle covers only the headless side.
