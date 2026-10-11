# Analysis — 20261011-230412

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 7b77749 (feat/2026-10-11-drop-watcher-compact)
- **Previous run:** 20261011-211521

## Headline

Green. All four suites passed on a clean tree, no function is above CCN 15, and `blindFiles` is 0
([`manifest.json`](manifest.json)). This run records milestone M12, compact mode (DW-C0 to DW-C6),
plus the two M11 review fixes that landed after the previous bundle (b5e95f8, 4e4f566). Compact mode
adds six modules and seven test suites. The new compact refresh pair reads 11064.8 bytes per
iteration, under its 11500 ceiling, and the full refresh pair moved by 0.7 bytes. Nothing needs action
before the M12 checkpoint, but the in-client COMPACT-1..7 checks are owed.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261011-211521 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 161 files | [`lint.txt`](lint.txt) | 148 → 161 files, still 0/0 |
| tests | pass | 1321 passed, 1 skipped, 0 failed, 1322 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1196/1/1197 → 1321/1/1322 |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 5 → 7 scenarios (the compact refresh pair is new); refresh pair 14248.1 → 14248.8 bytes/iter (ceiling 14500); parse pair 664.2, unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 13 → 13, avg CCN 2.4 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 39401 |
| Functions | 5110 |
| Avg NLOC / function | 7.2 |
| Avg CCN | 2.4 |
| Max CCN | 13 |
| Avg tokens / function | 70.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 0 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

All values come from [`manifest.json`](manifest.json)'s `suites.complexity`, and the footer in
[`complexity.txt`](complexity.txt) agrees. The run is sighted (`blindFiles` 0). Max CCN is still 13,
but one more function now reaches it: the `window` section of `modules/Diagnostics.lua` went from 10
to 13, because DW-C0 added the layout, the run override and each layout's geometry to the
diagnostics report. It is a guard chain, one `or` default per field it prints, not tangled control
flow. The other 13s (`uniquePlan` in `modules/Evaluate.lua`, `Window.SetMinimized`, `dropLine` in
`modules/Diagnostics.lua`, `eqText` in `modules/MineCells.lua`, `bestCandidate` in
`settings/Editors.lua`) are where they were. The new compact modules stay well under the hard limit:
their highest are `WC.Geometry` 10 (`modules/WindowCompact.lua`), `placeTitle` 9
(`modules/CompactChrome.lua`), `freshText` 8 (`modules/CompactCards.lua`), and `paintAsk`,
`paintTrade` and `paintStrip` 7 (`CompactGroup.lua`, `CompactMine.lua`, `CompactHistory.lua`).

**tests.** The one skip is still the kit's diagnostics opt-out case ([`tests.txt`](tests.txt)). It
does not apply, because this addon keeps the default.

**perf.** The compact refresh pair (`NS.Window.Refresh` with the window in its compact layout) reads
11064.8 bytes per iteration with capture off and on, so the bracket costs no allocation there either;
its ceiling is 11500. The full refresh pair reads 14248.8, 251.2 under its 14500 ceiling; the 0.7-byte
rise is under a byte per iteration, and the off and on runs still agree. The parse pair reads 664.2 and the stood-down show decision 0.0, both
unchanged. Timings are for orientation only.

## What moved

- **lint:** in-scope files went from 148 to 161, the 13 new files of M12: `modules/WindowCompact.lua`,
  `CompactCards.lua`, `CompactGroup.lua`, `CompactMine.lua`, `CompactHistory.lua`, `CompactChrome.lua`,
  and their seven suites under `tests/`.
- **tests:** cases went from 1197 to 1322 (1196 to 1321 passing; the skip count held at 1). M12 adds
  `test_window_compact` (21), `test_compact_cards` (29), `test_compact_group` (14),
  `test_compact_mine` (16), `test_compact_history` (9), `test_compact_chrome` (19) and
  `test_compact_modes` (7, the same drop set in both layouts), and `test_sim_e2e` goes from 12 to 19
  (each scenario in both layouts, and a simulated key's compact auto-open). The M11 review fixes add
  one case to `test_group_place` (13 to 14) and two to `test_sim_report` (19 to 21). Four cases were
  renamed or rewritten from the retired compact preset to the compact layout
  ([`test-cases.md`](test-cases.md)).
- **perf:** two new scenarios, `refreshCompactCaptureOff` and `refreshCompactCaptureOn`; the others
  are as described above.
- **complexity:** NLOC went from 35560 to 39401 and functions from 4635 to 5110. Avg NLOC went from
  7.1 to 7.2 and avg tokens from 68.6 to 70.0; avg CCN (2.4) and max CCN (13) held. So the addon grew
  without getting denser. The 1000–1500 band is still empty.

## Complexity watch list

**Functions `lizard` warned on**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|

None. The authored files nearest the 1000-line target are `core/Compat.lua` (995),
`modules/LootFeed.lua` (978), `tests/test_compat.lua` (952), `tests/test_window_shell.lua` (927) and
`modules/Window.lua` (923). M12 grew none of them: compact mode lives in its own files.

## Actions

1. Before adding code to `core/Compat.lua`, `modules/LootFeed.lua`, `modules/Window.lua`,
   `tests/test_compat.lua` or `tests/test_window_shell.lua`, move code out of them first (carried
   from the previous run; `Window.lua` is newly named, at its unchanged 923 lines).
2. The in-client checks COMPACT-1..7 in `docs/smoke-tests.md` are owed to the owner. This bundle
   covers only the headless side.
