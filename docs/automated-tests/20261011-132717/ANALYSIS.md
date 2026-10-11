# Analysis — 20261011-132717

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 8257eea (feat/2026-10-10-drop-watcher-v1)
- **Previous run:** 20261011-115548

## Headline

Green: all four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` 0, so
the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). This run
measures milestone M8, the owner's first in-game feedback (DW-80 to DW-84, docs in DW-85), on top of
the M7 simulator the previous run measured. No authored file is over 1000 lines: `core/Compat.lua`
is still at 999 and `modules/LootFeed.lua` went from 996 to 982, because DW-80 moved its pure record
helpers to `modules/FeedRecords.lua` and its item reads to `core/ItemRead.lua` and
`core/CompatItem.lua` instead of growing either file. No new ruling is owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-115548 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 130 files | [`lint.txt`](lint.txt) | 125 → 130 files, still 0/0 |
| tests | pass | 1031 passed, 1 skipped, 0 failed, 1032 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 984/1/985 → 1031/1/1032 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 13456.1 → 13680.1 bytes/iter (DW-83, bisected); parse pair unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 30605 |
| Functions | 4008 |
| Avg NLOC / function | 7.1 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 67.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). Five functions sit
at CCN 13: the four from last run (`uniquePlan` in `modules/Evaluate.lua`, `Window.SetMinimized` in
`modules/Window.lua`, `eqText` in `modules/MineCells.lua`, `bestCandidate` in `settings/Editors.lua`)
and one new, `dropLine` in `modules/Diagnostics.lua` (DW-80's `drops` line: ten fields, most with an `and`/`or` fallback that lizard counts as a
branch). It is within the hard limit of 15 but above the plan's aim of 10. M8's other new code is
flatter: `WC.Header` at 12, `inspectWhy` and `WC.Looter` at 11, then `historyEntry`, `inspected` and
`worn` in `modules/TestData.lua` at 9, and `WC.TheirEq` and `IR.LinkDetail` at 8.

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line
1021). It does not apply because this addon keeps the default. It is a standing condition, the same
skip as the previous three runs.

**perf.** The refresh pair (`NS.Window.Refresh`) went from 13456.1 to 13680.1 bytes per iteration,
224 bytes more per repaint, still under the suite's 14000 ceiling. The parse pair (664.2) and the
stood-down show decision (0.0) did not move. The capture-off / capture-on pairs still read equal
bytes, so the debug capture costs no allocation. The refresh change was bisected over M8's commits
with `tests/perf.lua`, each in a detached worktree outside the repo: 13456.1 at c68f2b5 (M7), 937d5e4
(DW-80), 3a5193d (DW-81) and 351cfdb (DW-82); 13680.1 at b3581f1 (DW-83) and 06521f0 (DW-84). DW-83
is the commit that moved it. That commit adds the `My eq` column and the two filter checkboxes whose
labels the bar measures on each layout, which fits the size of the change. Timings moved within
noise and are for orientation only.

## What moved

- **lint:** in-scope files went from 125 to 130: `core/ItemRead.lua` (the library-shaped item read,
  drafted for LibKa0s-Item-1.0), `core/CompatItem.lua` (its client calls behind the compat layer),
  `modules/FeedRecords.lua` (the feed's pure record helpers, peeled out of `LootFeed.lua`),
  `modules/TestData.lua` (test mode's sample data over real items) and `tests/test_item_read.lua`.
  Still 0/0, with the `.luacheckrc` exclusions unchanged.
- **tests:** cases went from 985 to 1032 (984 to 1031 passing). The new cases cover the item read and
  the most complete link (DW-80, `test_item_read`), the header (DW-81) and filter bar (DW-82) in
  `test_window_shell`, the `My eq` / `Their eq` columns, the two new filters and auto-open on every
  drop (DW-83), and test mode's real items and History samples (DW-84, `test_test_mode`). The skip
  count did not move (1).
- **perf:** the refresh pair rose by 224 bytes per iteration (DW-83, above); nothing else moved.
- **complexity:** NLOC went from 29037 to 30605 and functions from 3808 to 4008. The averages held
  (avg NLOC 7.1, avg CCN 2.4; avg tokens 66.9 → 67.2). Max CCN held at 13, now on five functions
  instead of four. The 1000–1500 band stays empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The two files nearest the 1000-line target are `core/Compat.lua` (999) and
`modules/LootFeed.lua` (982). Neither can take more code without first moving some out.

## Actions

1. `core/Compat.lua` and `modules/LootFeed.lua`: add no code to either without first moving pure code
   out, as DW-80 did with `modules/FeedRecords.lua` and `core/CompatItem.lua`. Promoting
   `core/ItemRead.lua` to LibKa0s-Item-1.0 (drafted in the plan's `issues-to-file.md`) would also
   free room.
2. `dropLine` (`modules/Diagnostics.lua`, CCN 13): a candidate to split into per-field formatters if
   it grows. No action is owed now (below 15).
3. The M8 in-client checks in `docs/smoke-tests.md` (ITEM-3, ITEM-4, FEED-16, FEED-17, FEED-18,
   STATE-4) are owed to the owner. This bundle covers only the headless side.
