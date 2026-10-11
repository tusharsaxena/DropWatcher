# Analysis — 20261011-192657

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 8fcfe45 (feat/2026-10-11-drop-watcher-feedback-2)
- **Previous run:** 20261011-184145

## Headline

Green. All four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` at 0,
so the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). This run
closes milestone M10. Since the previous bundle (2176e48), the branch has taken the two review fixes
(8af37f1, 8866d68), the simulation step delay (DW-A7), the Loot History table font and row height
(DW-A8), and the review leftovers (DW-A9): My drops under group headers, the session prune after a
disabled start, tooltips beside the docked Offer panel, the retention popup answering only the
latest choice, and the stale History cap docs. No authored file is over 1000 lines. Nothing needs
action beyond the owed in-client checks.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-184145 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 142 files | [`lint.txt`](lint.txt) | 141 → 142 files, still 0/0 |
| tests | pass | 1150 passed, 1 skipped, 0 failed, 1151 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1131/1/1132 → 1150/1/1151 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 14168.1 → 14248.1 bytes/iter (ceiling 14500); parse pair 664.2, unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 34430 |
| Functions | 4487 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 68.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). Max CCN is still 13.
The functions DW-A9 added or changed are flat: `WG.Entries` 9, `companionOf` 8, `spanOf` 6,
`WG.PlaceItemTooltip` 6 and `edgesPx` 4 (`modules/WindowGroup.lua`); `WM.Rows` 5, `groupedIds` 4 and
`drawRows` 3 (`modules/WindowMine.lua`); `R.OnChanged` 5, `R.Answer` 3, `retirePending` 3 and
`R.OnStandUp` 1 (`modules/HistoryRetention.lua`). All are under the plan's aim of 10.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1140). It does not apply, because this addon keeps the default.

**perf.** The refresh pair (`NS.Window.Refresh`) reads 14248.1 bytes per iteration, 80 more than the
previous run and 251.9 under its 14500 ceiling. The parse pair still reads 664.2, and the stood-down
show decision stays at 0.0. The capture-off and capture-on pairs read equal bytes, so the debug
capture costs no allocation. Timings are for orientation only.

## What moved

- **lint:** in-scope files went from 141 to 142. `modules/WindowRows.lua` (DW-A8) is the new file.
  `.luacheckrc` gained `StaticPopup_Hide` as a read global (DW-A9).
- **tests:** cases went from 1132 to 1151 (1131 to 1150 passing). DW-A7, DW-A8 and the review fixes
  add most of them. DW-A9 adds seven: two in `test_window_mine` (group headers), two in
  `test_window_group` (tooltip beside the docked panel), and three in `test_history_retention` (the
  prune after a disabled start, and two stale-popup cases). The skip count held at 1.
- **perf:** the refresh pair rose by 80 bytes per pass. That is within the M10 work and under the
  ceiling. The parse path did not move.
- **complexity:** NLOC went from 33900 to 34430, and functions from 4423 to 4487. Avg NLOC (7.1) and
  avg CCN (2.4) held. Avg tokens went from 67.9 to 68.2. Max CCN held at 13. The 1000–1500 band is
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
`modules/LootFeed.lua` (975) and `modules/WindowGroup.lua` (952).

## Actions

1. Before adding code to `core/Compat.lua`, `modules/LootFeed.lua` or `modules/WindowGroup.lua`,
   move code out of them first. `modules/WindowGroup.lua` grew by 30 lines here (tooltip span).
2. The refresh pair is 251.9 bytes under its ceiling. Keep the filter bar writing its controls only
   when they change.
3. The M10 in-client checks in `docs/smoke-tests.md` (FEED-19..25, HIST-3..4, SIM-11) are owed to the
   owner. This bundle covers only the headless side.
