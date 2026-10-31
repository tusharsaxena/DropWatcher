# Analysis — 20261031-213421

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 091e1b8 (feat/2026-10-31-findings-remediation), clean tree
- **Previous run:** 20261031-202124 (pre-merge, measured f799d32)

## Headline

All four suites pass, so the amber on the previous run is gone. `refreshCaptureOff` and
`refreshCaptureOn` now allocate 13456.0 bytes/iter against the 14500-byte ceiling those scenarios
failed last run at 14577.0. The band fell from 8 files to 6, and no function is above CCN 15. There
is nothing to act on in this record.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-202124 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 208 files | [`lint.txt`](lint.txt) | files 206 → 208 |
| tests | pass | 1845 passed, 1 skipped, 0 failed, 1846 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1845 → 1846, skip count unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; the four refresh scenarios fell |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 and warnings 0 unchanged, avg tokens 75.4 → 75.5, band 8 → 6 |

| Metric | Value |
|---|---|
| Total NLOC | 54377 |
| Functions | 6706 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 75.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 6 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from [`manifest.json`](manifest.json)'s `suites.complexity`.

**tests (a skip).** The one skipped case ([`tests.txt`](tests.txt)) is the kit's diagnostics-contract
case for an addon that opts out of turning logging on. This addon keeps the default, so the case does
not apply. It is the same skip as the previous run, a pre-existing condition.

## What moved

Against 20261031-202124 (f799d32):

- **Lint:** still 0/0, over 206 → 208 files.
- **Tests:** 1845 → 1846 cases, all passing but the same one skip. [`test-cases.md`](test-cases.md)
  adds a `skin chrome` case and a `table font` case and drops the `trade rules` case on `Rules`
  listing every situation. Two more cases were renamed.
- **Perf:** `refreshCaptureOff`/`On` 14577.0 → 13456.0 bytes/iter, back under the ceiling.
  `refreshCompactCaptureOff`/`On` 11345.0 → 10224.0. `parseCaptureOff`/`On` 664.2 → 664.0.
  `showDecisionStoodDown` stayed 0.0. In each pair capture off and capture on allocate the same
  bytes, so the zero-overhead pairing holds. The whole-number readings also reflect a measuring
  change: `tests/perf.lua` moved between these two runs, so the byte movement is not all allocation.
  The ms/iter figures differ too, but [`perf.txt`](perf.txt) says to compare them within a run only.
- **Complexity:** NLOC 54383 → 54377 and functions 6712 → 6706. Avg NLOC 7.4 and avg CCN 2.4 did not
  move, and avg tokens rose 75.4 → 75.5. Max CCN stayed 15 and warnings stayed 0.
- **Band:** `core/Compat.lua` and `locales/enUS.lua` left the band, 8 → 6. The six that remain hold
  the LOC they held last run. None newly crossed and none is over the cap.

## Complexity watch list

### Functions

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 | `modules/LootFeed.lua` | 1041 | Carried **Accepted**: unchanged at 1041, under its 1100 split line |
| 1000–1500 | `modules/WindowCells.lua` | 1165 | Carried: Trade composers split before 1250; unchanged at 1165 |
| 1000–1500 | `modules/WindowGroup.lua` | 1138 | Carried **Accepted**: under its 1250 split line; unchanged at 1138 |
| 1000–1500 | `tests/test_compat.lua` | 1030 | Carried **Accepted**: unchanged at 1030 |
| 1000–1500 | `tests/test_window_group.lua` | 1065 | Carried **Accepted**: unchanged at 1065 |
| 1000–1500 | `tests/test_window_shell.lua` | 1034 | Carried **Accepted**: unchanged at 1034 |

No Disposition cell was blank, so this run authored none. The rulings are in
[`RESULTS.md`](../RESULTS.md)'s Disposition column. The two split rows dropped out as their
dispositions said they would, which closes the previous run's actions on `locales/enUS.lua` and
`core/Compat.lua`.

## Actions

None.
