# Analysis — 20261011-204356

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** c6b3161 (feat/2026-10-11-drop-watcher-feedback-3)
- **Previous run:** 20261011-192657

## Headline

Green. All four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` at 0
([`manifest.json`](manifest.json)). This run closes milestone M11, the owner's third feedback. Since
the previous bundle (8fcfe45), the branch has taken DW-B0 (the simulator's loot step says where its
drops went, and the My drops tab and Group drops headers reconcile with it), DW-B1 (filter-bar
tooltips open above their controls), DW-B2 (every row tooltip at the row's top right, one helper in
the new `modules/RowTooltip.lua`) and the DW-B3 docs sync. No authored file is over 1000 lines, and
`modules/WindowGroup.lua` shrank from 952 to 784 lines. Nothing needs action beyond the owed
in-client checks.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-192657 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 146 files | [`lint.txt`](lint.txt) | 142 → 146 files, still 0/0 |
| tests | pass | 1175 passed, 1 skipped, 0 failed, 1176 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1150/1/1151 → 1175/1/1176 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 14248.1 bytes/iter, unchanged (ceiling 14500); parse pair 664.2, unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 35025 |
| Functions | 4563 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 68.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). Max CCN is still 13.
The functions M11 added are flat: in `modules/SimReport.lua` the highest are `R.Summarize` 12 and
`R.TipLines` 12, then `R.Collect` 9; in `modules/RowTooltip.lua` the highest are `ancestor` 8 and
`companionOf` 8, with `RT.Place` 6; in `modules/Window.lua` `Window.AboveSide` is 6,
`Window.PlaceAbove` 5 and `Window.AttachTooltip` 2. All are under the plan's aim of 10 except the
two 12s, which are under the hard limit of 15.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1165). It does not apply, because this addon keeps the default.

**perf.** The refresh pair (`NS.Window.Refresh`) reads 14248.1 bytes per iteration, the same as the
previous run and 251.9 under its 14500 ceiling. The parse pair still reads 664.2, and the stood-down
show decision stays at 0.0. The capture-off and capture-on pairs read equal bytes, so the debug
capture costs no allocation. Timings are for orientation only.

## What moved

- **lint:** in-scope files went from 142 to 146. The new files are `modules/SimReport.lua` (DW-B0),
  `modules/RowTooltip.lua` (DW-B2), `tests/test_sim_report.lua` and `tests/test_row_tooltip.lua`.
- **tests:** cases went from 1151 to 1176 (1150 to 1175 passing). `test_sim_report` adds 13 and
  `test_row_tooltip` adds 13; `test_window_shell` went from 50 to 55 (DW-B0 tab count, DW-B1
  placement); `test_window_group` went from 46 to 40, its tooltip-placement cases having moved to
  `test_row_tooltip` with the code. The skip count held at 1.
- **perf:** nothing moved. Neither the refresh path nor the parse path took new allocation.
- **complexity:** NLOC went from 34430 to 35025, and functions from 4487 to 4563. Avg NLOC (7.1) and
  avg CCN (2.4) held. Avg tokens went from 68.2 to 68.4. Max CCN held at 13. The 1000–1500 band is
  still empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The three files nearest the 1000-line target are `core/Compat.lua` (995),
`modules/LootFeed.lua` (975) and `tests/test_compat.lua` (952). `modules/WindowGroup.lua` left that
list: DW-B2 moved its tooltip placement into `modules/RowTooltip.lua`.

## Actions

1. Before adding code to `core/Compat.lua`, `modules/LootFeed.lua` or `tests/test_compat.lua`, move
   code out of them first.
2. The refresh pair is 251.9 bytes under its ceiling. Keep the filter bar writing its controls only
   when they change.
3. The M11 in-client checks in `docs/smoke-tests.md` (SIM-12, FEED-26, FEED-27) are owed to the
   owner. This bundle covers only the headless side.
