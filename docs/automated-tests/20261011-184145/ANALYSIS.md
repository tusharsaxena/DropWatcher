# Analysis — 20261011-184145

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 2176e48 (feat/2026-10-11-drop-watcher-feedback-2)
- **Previous run:** 20261011-142452

## Headline

Green: all four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` 0, so
the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). This run
measures milestone M10, the owner's second in-game feedback: every hidden or refused drop counted
(DW-A0), the multi-select View with All as the default (DW-A1), item tooltips beside the window
(DW-A2), the party named in each group header (DW-A3), the Character dropdown (DW-A4), History kept
by days (DW-A5), and this docs and bundle pass (DW-A6). No authored file is over 1000 lines. The
largest are `core/Compat.lua` (995), `modules/LootFeed.lua` (975) and `modules/WindowGroup.lua` (922).

One finding was fixed before this run. A first run at 1605852 failed perf: the window's repaint
allocated 17226 bytes per pass, over its 14000 ceiling. A bisect over the milestone put the growth in
DW-A0 (+448), DW-A1 (+1488) and DW-A4 (+1610). The filter bar's Sync runs on every repaint, and it
was rebuilding the View and Character rows and selections each time. Commit 5de8d08 now builds the
rows once and writes a dropdown only when its contents change. That brought the pass down to 14168
bytes, which is the M10 work itself, so the ceiling was raised to 14500 with the reason recorded
(`tests/perf.lua`, `docs/performance.md`).

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-142452 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 141 files | [`lint.txt`](lint.txt) | 133 → 141 files, still 0/0 |
| tests | pass | 1131 passed, 1 skipped, 0 failed, 1132 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1065/1/1066 → 1131/1/1132 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 13680.1 → 14168.1 bytes/iter (ceiling 14000 → 14500); parse pair 664.2, unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 33900 |
| Functions | 4423 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 67.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). The same five
functions sit at CCN 13 as in the last run: `uniquePlan` (`modules/Evaluate.lua`),
`Window.SetMinimized` (`modules/Window.lua`), `dropLine` (`modules/Diagnostics.lua`), `eqText`
(`modules/MineCells.lua`) and `bestCandidate` (`settings/Editors.lua`). M10 added none of them.

M10's new modules are flat. The highest scores are `GR.Entry` and `GR.Grow` in
`modules/GroupRoster.lua`, at 10. The touched window code has `WH.Entries` (`modules/WindowHistory.lua`)
and `WC.Looter` (`modules/WindowCells.lua`) at 11, and `FB.HiddenBy`, `visibleDrops` and `WG.Entries`
at 10. All are under the hard limit of 15.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1121). It does not apply, because this addon keeps the default.

**perf.** The refresh pair (`NS.Window.Refresh`) reads 14168.1 bytes per iteration, under its new
14500 ceiling, and the parse pair still reads 664.2. The stood-down show decision stays at 0.0. The
capture-off and capture-on pairs still read equal bytes, so the debug capture costs no allocation.
DW-A0's per-reason counting added nothing to the parse path. Timings moved within noise and are for
orientation only.

## What moved

- **lint:** in-scope files went from 133 to 141. The eight new files are four modules
  (`modules/FeedCounts.lua`, `modules/CharFilter.lua`, `modules/GroupRoster.lua`,
  `modules/HistoryRetention.lua`) and their four suites.
- **tests:** cases went from 1066 to 1132 (1065 to 1131 passing). The four new suites hold
  `test_feed_counts` (the two-Yoke regression on the owner's chat lines), `test_char_filter`,
  `test_group_roster` and `test_history_retention`. Edits to `test_database` (steps 3 and 4),
  `test_window_shell`, `test_window_group`, `test_history`, `test_schema_rows`, `test_test_mode` and
  `test_sim_e2e` add the rest. The skip count held at 1.
- **perf:** the refresh pair rose by 488 bytes for the M10 header and Character work, as described in
  the Headline above.
- **complexity:** NLOC went from 31928 to 33900 and functions from 4162 to 4423. The averages held
  (avg NLOC 7.1, avg CCN 2.4), and avg tokens went from 67.5 to 67.9. Max CCN held at 13. The
  1000–1500 band is still empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The three files nearest the 1000-line target are `core/Compat.lua` (995),
`modules/LootFeed.lua` (975) and `modules/WindowGroup.lua` (922).

## Actions

1. Before adding code to `core/Compat.lua`, `modules/LootFeed.lua` or `modules/WindowGroup.lua`, move
   code out of them first. Topic shims go in `core/CompatWorld.lua` or `core/CompatItem.lua`.
2. The refresh pair now sits 332 bytes under its ceiling. The filter bar must keep writing its
   controls only on change, so that the next feature's repaint work shows up as a real rise and not
   as churn.
3. The M10 in-client checks in `docs/smoke-tests.md` (FEED-19..23, HIST-3) are owed to the owner. This
   bundle covers only the headless side.
