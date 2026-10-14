# Analysis — 20261015-001310

- **Addon:** DropWatcher 0.1.0
- **Verdict:** green
- **Commit:** 0109f2a (feat/2026-10-14-drop-watcher-review-audit)
- **Previous run:** 20261014-231415 (measured fb8128c)

## Headline

All four suites passed on a clean tree at 0109f2a, after the LibKa0s v1.72.0 re-vendor (DW-P22), the
`within = "feed.add"` perf nesting (DW-P24), the disabled-state suite's steps 6, 7, 8 and 10 (DW-P25) and their
docs sync (DW-P30). The previous bundle was 5 commits behind HEAD; this one measures HEAD (finding F16). There are
1423 cases, up from 1418, lint is still clean over 170 files, no function is above CCN 15, and the run is sighted.
Nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261014-231415 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 170 files | [`lint.txt`](lint.txt) | none: same 170 files, still 0/0 |
| tests | pass | 1422 passed, 1 skipped, 0 failed, 1423 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +5 cases; four disabled cases renamed; the one skip is unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; every bytes/iter figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +129 NLOC, +18 functions; averages flat, max CCN 14 |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 42998 |
| Functions | 5377 |
| Avg NLOC / function | 7.3 |
| Avg CCN | 2.4 |
| Max CCN | 14 |
| Avg tokens / function | 72.3 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0). The totals grew a little with the new test cases and the depth counter in
`modules/LootFeed.lua`; the averages did not get denser (NLOC per function and CCN flat, tokens per function
72.4 → 72.3). Max CCN is still 14, in `candidateEq@157-176` in `modules/SideCells.lua`
([`complexity.txt`](complexity.txt)), the same function as last run. Finding X12
asked whether the functions the remediation touched stayed under 15 once DW-P24 landed. They did:
`DW.OnSharedFeatureEvent@60-70` in `core/DropWatcher.lua` scores CCN 6 as before, `LF.Receive@638-646` in
`modules/LootFeed.lua` scores 4 (3 last run, before its `pcall` and depth counter), the inner `receive@617-631`
scores 8, and the two nested buckets' brackets, `evaluate@228-233` and `qualityGate@263-274`, score 3 and 4.

**Perf** ([`perf.txt`](perf.txt)): the per-iteration allocation is the figure to compare, and timings are only
for orientation. Every scenario allocates exactly what it did last run: 14240.8 bytes/iter for the full refresh,
10432.9 for the compact refresh, 0.0 for `showDecisionStoodDown` and 664.2 for the parse, capture off and on equal
in each pair. No offline scenario reaches `feed.add`, so DW-P24's nesting is not visible here; it is confirmed in
game by smoke check DIAG-4, which is still owed the owner's capture.

## What moved

- **lint:** unchanged, 170 files, 0 warnings and 0 errors.
- **tests:** 1418 → 1423 cases, 1417 → 1422 passed, with 1 skip as before (the diagnostics-contract opt-out
  case). The new cases are four `perf:` cases in `test_setup` for the `evaluate` and `quality.gate` nesting
  (DW-P24) and `disabled 11`, step 10's hold ordering (DW-P25). `disabled 3`, `4`, `5` and `8` were renamed as
  they widened to step 6's reach, every verb and the bare command, and both launcher buttons.
  [`test-cases.md`](test-cases.md) matches `docs/test-cases.md` at HEAD.
- **perf:** nothing moved.
- **complexity:** +129 NLOC and +18 functions, every average flat, max CCN 14, no warnings. The band table is
  unchanged: `locales/enUS.lua` at 1296 lines.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `locales/enUS.lua` | 1296 | **Accepted** — a flat `L["..."] = "..."` string table with no logic; it grew past 1000 when DW-P19 added every routed enUS key (F07, D8). Split it by surface before it nears the 1500 cap. Carried forward; not a release run, so the three-release shelf life has not started. |

## Actions

1. `modules/` compact painter: the +64 bytes/iter on `refreshCompact*` that the previous run recorded is still
   unexplained (10432.9 here too). Carried forward from 20261014-231415; no deviation ID or review finding owns
   it. The figure is recorded and does not gate.
