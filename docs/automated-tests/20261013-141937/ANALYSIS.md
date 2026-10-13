# Analysis — 20261013-141937

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** d2c4e7a (feat/2026-10-13-drop-watcher-feedback-5), clean tree
- **Previous run:** 20261013-104522 (measured 189a13d)

## Headline

All four suites passed on a clean tree at the M14 milestone (owner feedback 5: the Actions width, the row chevron
and indent, the Trade window column on every drop, your own drops folded into Drops and the My drops tab retired).
Tests ended 2 cases up at 1335 even though two whole suites went with My drops; lint stayed clean over 3 more files;
complexity shrank in total with the retired tab while the averages held. Nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261013-104522 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 164 files | [`lint.txt`](lint.txt) | +3 files (161 before); still 0/0 |
| tests | pass | 1335 passed, 1 skipped, 0 failed, 1336 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +2 passed, +2 total (1333 / 1334 before); skipped unchanged at 1 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; allocation per refresh moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | −136 NLOC, −37 functions; avg tokens 70.0 → 70.4, other averages unchanged |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 39524 |
| Functions | 5106 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 70.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0), so every function was measured. The addon lost 136 NLOC and 37 functions net:
`modules/WindowMine.lua`, `modules/CompactMine.lua` and their two test suites were deleted, outweighing the new
`modules/WindowOwn.lua`, `modules/DropsStrip.lua` and the suites `test_own_drops`, `test_drops_strip` and
`test_drops_layout`. Avg NLOC and avg CCN held at 7.2 and 2.4; avg tokens rose 0.4, within noise for a change that
removed whole modules. Max CCN is still 13, and no file is in the 1000-line band (the split of
`tests/test_window_group.lua` into `test_drops_layout.lua` kept it out).

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the comparable figure; timings are for
orientation only. The full-layout refresh pair allocates 14400.8 bytes per iteration, down from 14424.8 (−24): the
Trade window cell and row chevron are painted on every row, offset by the right-edge expander and the per-tab My
drops wiring going away. The compact refresh pair allocates 10368.9, down from 10920.8 (−551.9), which fits the
compact My drops body no longer being built. `showDecisionStoodDown` still allocates nothing, and both parse
scenarios are unchanged at 664.2 bytes.

## What moved

- **lint:** 161 → 164 files (three new modules or suites net of the deletions), still 0 warnings and 0 errors.
- **tests:** 1333 → 1335 passed and 1334 → 1336 total. M14 removed `test_window_mine` and `test_compact_mine`
  (porting the cases whose behavior survives) and added cases for the row chevron and indent, the gold header
  chevron, the Trade window column and its ticker, own drops' Trade count, `(Multiple)` and its tooltip, the keep?
  rule, Offer and its tones, the strip, the tab strip and the `mine` alias, the `feed.showOwn` retirement step and
  both least widths. The one skip is unchanged.
- **perf:** the same seven scenarios; refresh allocation −24 bytes full and −551.9 bytes compact, as above.
- **complexity:** −136 NLOC and −37 functions, averages flat (tokens +0.4), max CCN 13, no warnings, nothing in
  either band.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

## Actions

None.
