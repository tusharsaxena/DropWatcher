# Analysis — 20261101-203422

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 6074774 (feat/2026-11-01-full-skinning), clean tree
- **Previous run:** 20261101-150352 (measured a2a1dbf)

## Headline

All four suites pass on the re-cut LibKa0s v1.85.0 (kit revision 50) with the kit's two skin gates adopted: lint 0/0, no function above CCN 15, nothing blind or crashed. The case count rose by 50, nearly all of it `test_skin_switch`, and perf bytes/iter did not move in any scenario. Nothing newly crossed a threshold.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-150352 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 210 files | [`lint.txt`](lint.txt) | file count unchanged, one suite retired and one facts file added |
| tests | pass | 1927 passed, 1 skipped, 0 failed, 1928 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1878 → 1928 cases |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in all seven; timings moved, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 55132 → 55305, functions 6802 → 6869, band 8 → 8 |

| Metric | Value |
|---|---|
| Total NLOC | 55305 |
| Functions | 6869 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 75.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every suite is a clean pass. The one skipped case is the standing diagnostics-contract case in [`tests.txt`](tests.txt): this addon keeps the default `Kit.diagnostics.enablesLogging`, so the opt-out case does not apply to it.

## What moved

- **lint:** still 0/0 over 210 files.
- **tests:** `test_skin_switch` adds 41 cases over the surfaces `tests/skin_switch_facts.lua` declares, and `test_skin_values` 3, replacing `test_skin_literals`' 3. The rest of the rise is the review commit `7499d17` and the library's kit suites. The tables' face is not declared: the harness has no LibSharedMedia, so no face moves there, and a skin's face on the tables stays with SKIN-30.
- **perf:** bytes/iter did not move in any scenario, so moving the shadow onto `opts.shadowToken` added no allocation to a repaint. Time per iteration in [`perf.txt`](perf.txt), previous → this run:
  - `refreshCaptureOff` 0.11754 → 0.11331
  - `refreshCaptureOn` 0.11587 → 0.08591
  - `refreshCompactCaptureOff` 0.11689 → 0.11080
  - `refreshCompactCaptureOn` 0.14277 → 0.11066
  - `showDecisionStoodDown` 0.00023 → 0.00012
  - `parseCaptureOff` 0.01215 → 0.01152
  - `parseCaptureOn` 0.01827 → 0.01173

  With identical allocation these read as host noise. Avg CCN and max CCN are unchanged, and avg tokens fell 75.6 → 75.2.
- **complexity:** NLOC 55132 → 55305 and functions 6802 → 6869, the suites' growth. No warning.

## Complexity watch list

Functions:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files:

| Band | File | LOC | Disposition |
|---|---|---|---|
|1000–1500 (on notice) | `modules/LootFeed.lua` | 1041| carried forward unchanged in `RESULTS.md` |
|1000–1500 (on notice) | `modules/Window.lua` | 1007| LOC moved, disposition carried in `RESULTS.md` |
|1000–1500 (on notice) | `modules/WindowCells.lua` | 1165| carried forward unchanged in `RESULTS.md` |
|1000–1500 (on notice) | `modules/WindowGroup.lua` | 1152| LOC moved, disposition carried in `RESULTS.md` |
|1000–1500 (on notice) | `tests/test_compat.lua` | 1030| carried forward unchanged in `RESULTS.md` |
|1000–1500 (on notice) | `tests/test_settings_pages.lua` | 1052| carried forward unchanged in `RESULTS.md` |
|1000–1500 (on notice) | `tests/test_window_group.lua` | 1065| carried forward unchanged in `RESULTS.md` |
|1000–1500 (on notice) | `tests/test_window_shell.lua` | 1037| carried forward unchanged in `RESULTS.md` |

## Actions

Owner smoke: SKIN-37..43, and SKIN-2, SKIN-14, SKIN-30 and GLOW-9. SKIN-40 was rewritten at this run's commit, because each skin now states its own `glow.color` and `icon.border`.
