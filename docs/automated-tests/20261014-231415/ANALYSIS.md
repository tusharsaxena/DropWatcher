# Analysis — 20261014-231415

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** fb8128c (feat/2026-10-14-drop-watcher-review-audit)
- **Previous run:** 20261014-133254 (measured 5996818)

## Headline

All four suites passed on a clean tree at the end of the 2026-10-14 review and audit remediation (M24, closing
finding F16). There are now 1418 cases, up from 1400, and lint is still clean over 170 files, one more than before
(the new `tests/test_locale.lua`). No function is above CCN 15 and the run is sighted. One thing newly crossed a
threshold: `locales/enUS.lua` is in the 1000–1500 band now that DW-P19 has put every routed key in it. Its
disposition is below. Nothing else needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261014-133254 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 170 files | [`lint.txt`](lint.txt) | +1 file (`tests/test_locale.lua`), still 0/0 |
| tests | pass | 1417 passed, 1 skipped, 0 failed, 1418 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +18 cases; the one skip is unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; compact refresh allocates +64 bytes/iter |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +1330 NLOC, +55 functions; averages flat, max CCN 14 |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 42869 |
| Functions | 5359 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.4 |
| Max CCN | 14 |
| Avg tokens / function | 72.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0). The totals grew because the remediation added code: the routed enUS keys, the
locale scan and its test, the toc-file-§5 harness cases, and the stood-down refusal and channel guards. The
averages did not get denser: NLOC per function and CCN are flat, and tokens per function went from 72.3 to 72.4.
Max CCN is still 14, in `candidateEq@157-176` in `modules/SideCells.lua` ([`complexity.txt`](complexity.txt)), the same
function as last run. Finding X12 asked whether the functions the remediation touched stayed under 15. They did:
`DW.OnSharedFeatureEvent@60-70` in `core/DropWatcher.lua` scores CCN 6, and `LF.Receive@632-637` in
`modules/LootFeed.lua` scores 3. The `(anonymous)` closure that DW-P26 added to `tests/test_harness.lua` would have
been this run's only warning. Commit fb8128c split it into four named helpers before this run, so none of its
pieces appear above 13.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the figure to compare, and timings are only
for orientation. `refreshCompactCaptureOff` and `refreshCompactCaptureOn` both allocate 10432.9 bytes/iter, up from
10368.9. That is +64 bytes on each compact refresh. The full refresh (14240.8), `showDecisionStoodDown` (0.0) and
the parse (664.2) did not move. This run does not show which remediation change added the 64 bytes. Only the
compact path moved, and capture on and off moved together, so the extra allocation is in the compact painter and
not in the capture bracket.

## What moved

- **lint:** 169 → 170 files, still 0 warnings and 0 errors. The new file is `tests/test_locale.lua` (DW-P19).
- **tests:** 1400 → 1418 cases, 1399 → 1417 passed, with 1 skip as before (the diagnostics-contract opt-out
  case, which does not apply to this addon). New cases cover the stored-channel announce guards, the cancel path for
  a vanished group, the shared-handler error isolation, the close mark degrading to nothing, the stood-down and
  perf-hold refusal lines, the enUS completeness scan, the toc-file-§5 label checks, the per-tab defaults, the empty
  filter-bar groups, the secret-width tooltip and the When-to-show OnRelease. One KeepsHeader case was renamed in
  place. [`test-cases.md`](test-cases.md) matches `docs/test-cases.md` at HEAD.
- **perf:** the compact refresh allocates +64 bytes/iter. Nothing else moved.
- **complexity:** +1330 NLOC and +55 functions, with every average flat, max CCN 14 and no warnings. One file
  entered the 1000–1500 band: `locales/enUS.lua` at 1296 lines.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1296 | **Accepted** — a flat `L["..."] = "..."` string table with no logic; it grew past 1000 when DW-P19 added every routed enUS key (F07, D8). Split it by surface before it nears the 1500 cap. Newly crossed. |

## Actions

1. `locales/enUS.lua`: this is the first run with it on notice. Nothing is owed yet. If it nears the 1500 cap,
   split it by surface (for example a second enUS file for the options panel) before any new strings land. This is
   new here, and no deviation ID or review finding owns it.
2. `modules/` compact painter: find out which change between 5996818 and fb8128c added the +64 bytes/iter in
   `refreshCompact*`. This is new here. The figure is recorded and does not gate.
