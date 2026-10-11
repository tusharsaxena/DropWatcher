# Analysis — 20261011-211521

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 0bca5ca (feat/2026-10-11-drop-watcher-feedback-3)
- **Previous run:** 20261011-204356

## Headline

Green. All four suites passed on a clean tree. No function is above CCN 15 and `blindFiles` is 0
([`manifest.json`](manifest.json)). This run records the rest of milestone M11 since the previous
bundle (c6b3161). DW-B4 makes the group headers name the instance, the boss and the difficulty, and
only your character. DW-B5 covers the M11 review leftovers: the My drops count and the Group drops
`· n yours on My drops` suffix now count only what My drops lists, `SimReport` honors `feed.showOwn`
and the feed the window shows, and `Window.PlaceAbove` checks the vertical room. No authored file is
over 1000 lines.

An earlier run of this battery, on 0c42908, read **amber**. Its perf suite failed because the refresh
pair allocated 17384.1 bytes per iteration, over the 14500 ceiling. DW-B5's first cut had built the
My drops context twice on every repaint. That bundle was discarded uncommitted. Commit 0bca5ca made
the count and the suffix allocation-free while the feed holds none of your drops, and this run
measures the fix.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-204356 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 148 files | [`lint.txt`](lint.txt) | 146 → 148 files, still 0/0 |
| tests | pass | 1196 passed, 1 skipped, 0 failed, 1197 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1175/1/1176 → 1196/1/1197 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 14248.1 bytes/iter, unchanged (ceiling 14500); parse pair 664.2, unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 35560 |
| Functions | 4635 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 68.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). Max CCN is still 13
(`Window.SetMinimized`, unchanged). The functions DW-B5 touched stay under the hard limit of 15:
`R.Summarize` 12, `R.TipLines` 12 and `R.Place` 11 in `modules/SimReport.lua`, `visibleDrops` 11
in `modules/WindowCells.lua`, `WM.ExcludedLines` 8 in `modules/WindowMine.lua`, and
`Window.TabContext` 8 in `modules/Window.lua`. `R.Place` and `visibleDrops` are guard chains, one
early return or branch per place or tab rule, not tangled control flow.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1186). It does not apply, because this addon keeps the default.

**perf.** The refresh pair (`NS.Window.Refresh`) reads 14248.1 bytes per iteration. That is the same
as the previous run and 251.9 under its 14500 ceiling. The parse pair still reads 664.2, and the
stood-down show decision stays at 0.0. The capture-off and capture-on pairs read equal bytes, so the
debug capture costs no allocation. Timings are for orientation only.

## What moved

- **lint:** in-scope files went from 146 to 148. The new files are `modules/GroupPlace.lua` and
  `tests/test_group_place.lua` (DW-B4).
- **tests:** cases went from 1176 to 1197 (1175 to 1196 passing). `test_group_place` adds 13 cases
  (DW-B4). `test_sim_report` goes from 13 to 19 (DW-B5: the tab counts with Hide and with a filter,
  the places under `feed.showOwn` and test mode, `View`, and the owner's step with `showOwn` on).
  `test_window_shell` goes from 55 to 57 (DW-B5: `AboveFits` and placing the tooltip below near the
  top of the screen). The skip count held at 1.
- **perf:** nothing moved in this bundle. The discarded amber run above shows the regression that
  the fix caught.
- **complexity:** NLOC went from 35025 to 35560, and functions from 4563 to 4635. Avg NLOC (7.1),
  avg CCN (2.4) and max CCN (13) held. Avg tokens went from 68.4 to 68.6. The 1000–1500 band is
  still empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The files nearest the 1000-line target are `core/Compat.lua` (995), `modules/LootFeed.lua`
(978), `tests/test_compat.lua` (952) and `tests/test_window_shell.lua` (927).

## Actions

1. Before adding code to `core/Compat.lua`, `modules/LootFeed.lua`, `tests/test_compat.lua` or
   `tests/test_window_shell.lua`, move code out of them first.
2. The refresh pair is 251.9 bytes under its ceiling. A repaint must not build a tab context it does
   not need; the amber run showed that two extra contexts cost about 3100 bytes.
3. The M11 in-client checks in `docs/smoke-tests.md` (SIM-12, SIM-13, FEED-26 to FEED-29) are owed to
   the owner. This bundle covers only the headless side.
