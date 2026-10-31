# Analysis — 20261031-202124

- **Addon:** DropWatcher 1.1.0
- **Verdict:** amber
- **Commit:** f799d32 (feat/2026-10-31-font-pickers-skin-faces), clean tree
- **Previous run:** 20261025-153954 (the 1.1.0 release record, measured 343370a)

## Headline

Lint and tests pass, so the commit gate holds. Complexity passes and is sighted, with no function
above CCN 15, no file over the 1500 cap, and no blind or crashed file, so there is nothing to fix for
CCN or NLOC. The verdict is amber because `perf` failed: `refreshCaptureOff` and `refreshCaptureOn`
each allocate 14577.0 bytes/iter against a 14500-byte ceiling. That does not block this commit, but
the next tag is gated on it.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261025-153954 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 206 files | [`lint.txt`](lint.txt) | files 194 → 206 |
| tests | pass | 1844 passed, 1 skipped, 0 failed, 1845 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | total 1713 → 1845, skip count unchanged |
| perf | fail | 7 scenarios, 2 assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | pass → fail; the four refresh scenarios rose, the parse pair and `showDecisionStoodDown` did not |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 15 and warnings 0 unchanged, avg CCN 2.5 → 2.4 |

| Metric | Value |
|---|---|
| Total NLOC | 54383 |
| Functions | 6712 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.4 |
| Max CCN | 15 |
| Avg tokens / function | 75.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from [`manifest.json`](manifest.json)'s `suites.complexity`.

**perf (a regression).** [`perf.txt`](perf.txt) reports two failed assertions: `refreshCaptureOff`
and `refreshCaptureOn` allocated 14577.0 bytes/iter, over their 14500-byte ceiling in
`tests/perf.lua`. The previous run measured 13713.0 for both. The compact pair rose by about the same
amount, 10481.1 → 11345.0, and stays under its own 11500 ceiling, so the growth is in a path the two
layouts share. The zero-overhead pairing holds, because in each pair the capture-off and capture-on
scenarios allocate the same bytes. `perf` is not on the commit gate, and it is on the tag gate.

**tests (a skip).** The one skipped case ([`tests.txt`](tests.txt)) is the kit's diagnostics-contract
case for an addon that opts out of turning logging on. This addon keeps the default, so the case does
not apply. It is the same skip as the previous run.

## What moved

Against 20261025-153954 (343370a):

- **Lint:** still 0/0, over 194 → 206 files.
- **Tests:** 1713 → 1845 cases, all passing but the same one skip.
- **Perf:** `refreshCaptureOff`/`On` 13713.0 → 14577.0 bytes/iter, now over the ceiling.
  `refreshCompactCaptureOff`/`On` 10481.1 → 11345.0. `parseCaptureOff`/`On` 664.2 and
  `showDecisionStoodDown` 0.0 did not move. The ms/iter figures also differ, but
  [`perf.txt`](perf.txt) says to compare them within a run only, and the machine was shared with other
  bounded runs at the time.
- **Complexity:** NLOC 51201 → 54383 and functions 6214 → 6712, while avg NLOC fell 7.5 → 7.4, avg
  CCN 2.5 → 2.4 and avg tokens 76.9 → 75.4. The addon grew and got no denser. Max CCN stayed 15 and
  warnings stayed 0.
- **Band:** the same 8 files, none newly crossed and none over the cap.

## Complexity watch list

### Functions

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 | `core/Compat.lua` | 1051 | Carried: the journal split is still owed; 1062 at the previous run |
| 1000–1500 | `locales/enUS.lua` | 1331 | Carried **Accepted**: a flat string table; 1317 at the previous run |
| 1000–1500 | `modules/LootFeed.lua` | 1041 | Carried **Accepted**: unchanged at 1041, under its 1100 split line |
| 1000–1500 | `modules/WindowCells.lua` | 1165 | Carried: Trade composers split before 1250; 1167 at the previous run |
| 1000–1500 | `modules/WindowGroup.lua` | 1138 | Carried **Accepted**: under its 1250 split line; 1118 at the previous run |
| 1000–1500 | `tests/test_compat.lua` | 1030 | Carried **Accepted**: unchanged at 1030 |
| 1000–1500 | `tests/test_window_group.lua` | 1065 | Carried **Accepted**: 1040 at the previous run |
| 1000–1500 | `tests/test_window_shell.lua` | 1034 | Carried **Accepted**: 1031 at the previous run |

No Disposition cell was blank, so this run authored none. The rulings are in
[`RESULTS.md`](../RESULTS.md)'s Disposition column.

## Actions

1. **Before the next tag, bring `refreshCaptureOff`/`On` back under 14500 bytes/iter**, in the shared
   repaint path, or re-pin the ceiling in `tests/perf.lua` with a reason if the allocation is judged
   the cost of the feature. A read-only re-measure of each commit, outside this bundle, puts the
   crossing at bc3c5dc (*DW-01: Give the tables' font the whole font setting*), which added a font
   read per repaint in `modules/WindowRows.lua`. New here.
2. **`locales/enUS.lua` remains Accepted past the three-release shelf life**, as 20261025-153954's
   analysis already recorded, so anti-pattern #53 owes it a fix or a tracked deviation ID. This run is
   not a release run, so the count did not advance.
3. **`core/Compat.lua`'s journal split** is still owed, as carried from 1.0.0's watch list.
