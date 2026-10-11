# Analysis — 20261011-142452

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 51d7065 (feat/2026-10-10-drop-watcher-v1)
- **Previous run:** 20261011-132717

## Headline

Green: all four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` 0, so
the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). This run
measures milestone M9, the owner's simulator feedback: the sim run that left the window empty
(DW-90), the simulation step panel (DW-91) and the docs pass (DW-92). No authored file is over 1000
lines: `core/Compat.lua` is still at 999, because DW-90 put the new world reads (`InCombatLockdown`,
`PlayerInCombat`, `GlobalString`) in `core/CompatWorld.lua` (130 lines), which makes no
version-variant call. The new panel, `modules/SimPanel.lua`, is 636 lines. No new ruling is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-132717 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 133 files | [`lint.txt`](lint.txt) | 130 → 133 files, still 0/0 |
| tests | pass | 1065 passed, 1 skipped, 0 failed, 1066 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1031/1/1032 → 1065/1/1066 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 13680.1 and parse pair 664.2 bytes/iter, both unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 31928 |
| Functions | 4162 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 67.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). The same five
functions sit at CCN 13 as last run (`uniquePlan` in `modules/Evaluate.lua`, `Window.SetMinimized`
in `modules/Window.lua`, `dropLine` in `modules/Diagnostics.lua`, `eqText` in
`modules/MineCells.lua`, `bestCandidate` in `settings/Editors.lua`); M9 added none. M9's new code is
flat: the highest are `E.Trade` in `modules/SimEvents.lua` at 10, `R.Create` (`modules/SimRoster.lua`)
and `E.Loot` / `E.Plan` (`modules/SimEvents.lua`) at 9, and in the panel `bossNames` and
`SP.Controls` at 8. All are within the plan's aim of 10.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1055). It does not apply because this addon keeps the default. It is a standing condition, the same
skip as the previous four runs.

**perf.** Neither allocation figure moved: the refresh pair (`NS.Window.Refresh`) reads 13680.1
bytes per iteration, under its 14000 ceiling, and the parse pair 664.2. The stood-down show
decision stays at 0.0, and the capture-off / capture-on pairs still read equal bytes, so the debug
capture costs no allocation. DW-90's routing of the combat and GlobalString reads through
`NS.Compat` added no allocation to the parse path. Timings moved within noise and are for
orientation only.

## What moved

- **lint:** in-scope files went from 130 to 133: `modules/SimPanel.lua` (the step panel, DW-91),
  `tests/test_sim_e2e.lua` (the every-scenario regression, DW-90) and `tests/test_sim_panel.lua`
  (DW-91). Still 0/0, with the `.luacheckrc` exclusions unchanged.
- **tests:** cases went from 1032 to 1066 (1031 to 1065 passing). DW-90 added `test_sim_e2e` (12
  cases: the no-bare-global scan, the seam's coverage, each of the six scenarios filling Group drops
  and My drops under the default filters, the combat flags, the GlobalString loot lines, `raid1` as
  you and Raid Finder's instance chat) and adjusted `test_sim_pool` and `test_sim_scenario`; DW-91
  added `test_sim_panel` (16 cases). The skip count did not move (1).
- **perf:** nothing moved.
- **complexity:** NLOC went from 30605 to 31928 and functions from 4008 to 4162. The averages held
  (avg NLOC 7.1, avg CCN 2.4; avg tokens 67.2 → 67.5). Max CCN held at 13 on the same five
  functions. The 1000–1500 band stays empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The two files nearest the 1000-line target are still `core/Compat.lua` (999) and
`modules/LootFeed.lua` (982).

## Actions

1. `core/Compat.lua` and `modules/LootFeed.lua`: add no code to either without first moving pure code
   out. Stable world and item reads belong in `core/CompatWorld.lua` and `core/CompatItem.lua`; the
   compat family stays a documented deviation in `docs/ARCHITECTURE.md` until the standard's v2.79.0
   (DW-93) reaches its master.
2. `modules/SimPanel.lua` copies LibKa0s PerfPanel's look; the shared step panel is drafted as
   `issues-to-file.md` I14, to be filed when the owner lifts the hold on GitHub writes.
3. The M9 in-client checks in `docs/smoke-tests.md` (SIM-9, SIM-10) are owed to the owner. This
   bundle covers only the headless side.
