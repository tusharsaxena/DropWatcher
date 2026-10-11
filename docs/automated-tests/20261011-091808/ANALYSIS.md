# Analysis — 20261011-091808

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** eb7aafb (feat/2026-10-10-drop-watcher-v1)
- **Previous run:** 20261010-232937

## Headline

Green: all four suites passed on a clean tree, with no function above CCN 15 and `blindFiles` 0, so
the release gate's conditions hold on this commit ([`manifest.json`](manifest.json)). Everything moved
a lot since the previous run, because that run measured the DW-02 scaffold and this one measures the
v1 build (plan items DW-03 to DW-61). One thing needs a ruling and has one: `core/Compat.lua` is in
the 1000–1500 band at 1107 lines, accepted for the compat reason given below.

Before this bundle, an unrecorded run in the same item found `perf` failing. The two refresh
scenarios allocated 13456.1 bytes per iteration against ceilings of 0 and 64 that had been measured on
the scaffold's empty repaint. Commit `eb7aafb` re-pinned them to the real pass and made the
zero-overhead check an explicit pair. That run was discarded and not committed. This paragraph is the
only record of it, so it is stated here rather than left out.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261010-232937 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 109 files | [`lint.txt`](lint.txt) | 39 → 109 files, still 0/0 |
| tests | pass | 886 passed, 1 skipped, 0 failed, 887 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 137/1/138 → 886/1/887 |
| perf | pass | 5 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 3 → 5 scenarios; refresh 0.0 → 13456.1 bytes/iter (re-pinned, see below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 10 → 13, avg CCN 2.0 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 25529 |
| Functions | 3369 |
| Avg NLOC / function | 7.0 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 66.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0), so no function went
unmeasured. The CCN 13 functions in [`complexity.txt`](complexity.txt) are `uniquePlan`
(`modules/Evaluate.lua`), `Window.SetMinimized` (`modules/Window.lua`), `eqText`
(`modules/MineCells.lua`) and `bestCandidate` (`settings/Editors.lua`). They are short, at 10 to 17
NLOC, and their score comes mostly from guard chains, not nested control flow.

**tests.** The one skip is the kit's diagnostics opt-out case ([`tests.txt`](tests.txt), line 876).
It does not apply here: this addon keeps the default, so its report turns logging on, and the case
before it covers that. The previous run had the same skip, so this is a standing condition and not a
regression.

**perf.** `refreshCaptureOff` and `refreshCaptureOn` allocate 13456.1 bytes per iteration each, and
the parse pair allocates 664.2 each ([`perf.txt`](perf.txt)). On the scaffold the refresh pair read
0.0, because that Refresh painted nothing. The shown window now builds its tab labels, footer strings,
filter-bar labels, the tab's context closures and the Group drops empty state on every pass, and that
pass runs at most once a frame. The ceilings in `tests/perf.lua` are now that work (14000). The
zero-overhead evidence (performance-§9) is asserted as a pair: capture off allocates no more than
capture on, and capture on adds at most 64 bytes. Both pairs pass, and both read equal bytes, so the
gated bracket adds nothing. `showDecisionStoodDown` still allocates 0.0.

## What moved

- **lint:** in-scope files went from 39 to 109 as the build added modules and suites. The count is
  still 0/0, and the `.luacheckrc` exclusions are unchanged: `libs/`, `tests/_kit/` and the frozen doc
  stores.
- **tests:** cases went from 138 to 887 (from 137 to 886 passing). The skip count did not move (1).
- **perf:** scenarios went from 3 to 5, with the two loot-parser scenarios added at DW-25. Refresh
  bytes went from 0.0 to 13456.1 per iteration, and the ceiling was re-pinned to match (above). The
  stood-down show decision did not move (0.0 bytes, 0 notes).
- **complexity:** NLOC went from 2829 to 25529 and functions from 533 to 3369. Both rises are growth.
  The density signal is the averages: avg NLOC per function went from 4.3 to 7.0, avg CCN from 2.0 to
  2.4, and avg tokens from 33.9 to 66.5. Real feature code is denser than the scaffold's stubs, and
  even so the average function stays small and simple. Max CCN went from 10 to 13, still under 15.
  The 1000–1500 band went from 0 files to 1 (`core/Compat.lua`). `modules/Window.lua`, which reached
  1029 lines during the build, is back to 805 after the DW-61 peel (`modules/WindowTitleBar.lua`).

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Compat.lua` | 1107 | newly crossed; accepted (DW-61). Under compat-§1 this is the only file allowed to call version-variant client APIs, so it cannot be peeled the way a feature module is. About a third of its lines are comments. Re-check when it nears 1500, or when LibKa0s takes `ChatSender` and the tooltip reader (the documented library-stack-§7 deviation) |

## Actions

1. `core/Compat.lua`: when LibKa0s ships the chat sender or the tooltip line reader (the promotion
   issues design spec §14 files at the end of the v1 run), adopt them and delete the local copies.
   That brings the file back under 1000 lines. The trigger is tracked as the re-check of the existing
   `## Documented deviations` row in `docs/ARCHITECTURE.md`; there is no new deviation.
