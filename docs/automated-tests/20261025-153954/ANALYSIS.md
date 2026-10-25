# Analysis — 20261025-153954

- **Addon:** DropWatcher 1.0.0 → 1.1.0 (release record)
- **Verdict:** green
- **Commit:** 343370a (master, clean tree)
- **Previous run:** 20261025-152417 (measured 21ba4a4), the 1.1.0 release attempt this one replaces;
  the last release record is 20261017-012204 (1.0.0, measured 80df719)

## Headline

This is the 1.1.0 release record, and every release gate holds: all four suites passed on a clean
tree at 343370a, no function is above CCN 15 (max 15) and the run is sighted (`blindFiles` 0,
`crashedFiles` 0). The attempt half an hour earlier refused on seven functions over CCN 15 (max 23);
a6e0329 brought each under the ceiling, and nothing else moved. Six files newly sit in the
1000–1500 LOC band since 1.0.0; each is ruled on below.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261025-152417 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 194 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1712 passed, 1 skipped, 0 failed, 1713 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | bytes/iter unchanged in every scenario |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 23 → 15, warnings 7 → 0 |

| Metric | Value |
|---|---|
| Total NLOC | 51201 |
| Functions | 6214 |
| Avg NLOC / function | 7.5 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 76.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 8 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Every value is from [`manifest.json`](manifest.json)'s `suites.complexity`.

The one skipped case ([`tests.txt`](tests.txt)) is the kit's diagnostics-contract case for an addon
that opts out of turning logging on. This addon keeps the default, so the case does not apply; the
case above it covers the default. It is the same skip as at 1.0.0.

## What moved

Against 20261025-152417 (the refused attempt, 21ba4a4): lint and tests are unchanged. Complexity's
max CCN fell from 23 to 15 and its warnings from 7 to 0; NLOC rose 51159 → 51201 and functions
6201 → 6214, the helpers a6e0329 added. Avg NLOC (7.5) and avg CCN (2.5) did not move. Perf
bytes/iter is unchanged in all seven scenarios; ms/iter shifted by a few hundredths, which is
machine noise ([`perf.txt`](perf.txt) says to compare scenarios within a run only).

Against the 1.0.0 release record (20261017-012204, 80df719): tests 1481 → 1713 cases; NLOC
45215 → 51201 and functions 5611 → 6214; avg NLOC 7.4 → 7.5 and avg CCN 2.5 unchanged; max CCN
14 → 15. Lint covers 178 → 194 files. The addon grew by about an eighth without getting denser.

## Complexity watch list

### Functions

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 | `core/Compat.lua` | 1062 | Carried: split the Encounter Journal shims into `core/CompatJournal.lua` before it grows further (1009 at 1.0.0) |
| 1000–1500 | `locales/enUS.lua` | 1317 | Carried **Accepted**: a flat string table (1329 at 1.0.0) |
| 1000–1500 | `modules/LootFeed.lua` | 1041 | **Newly crossed** (992 at 1.0.0) |
| 1000–1500 | `modules/WindowCells.lua` | 1167 | **Newly crossed** (960 at 1.0.0) |
| 1000–1500 | `modules/WindowGroup.lua` | 1118 | **Newly crossed** (983 at 1.0.0) |
| 1000–1500 | `tests/test_compat.lua` | 1030 | **Newly crossed** (958 at 1.0.0) |
| 1000–1500 | `tests/test_window_group.lua` | 1040 | **Newly crossed** (976 at 1.0.0) |
| 1000–1500 | `tests/test_window_shell.lua` | 1031 | **Newly crossed** (937 at 1.0.0) |

The 1.0.0 LOC figures are `wc -l` of each file at the `1.0.0-release` tag. The rulings are in
[`RESULTS.md`](../RESULTS.md)'s Disposition column.

## Preview and simulation data

- **Answer:** Current
- **Asked:** 2026-10-25, by `/dev-copilot:bump-version`
- **Files reviewed:** test-mode data `modules/TestData.lua`, `modules/TestMode.lua`; simulator
  `core/SimSetup.lua`, `modules/Sim.lua`, `modules/SimEvents.lua`, `modules/SimPanel.lua`,
  `modules/SimPool.lua`, `modules/SimReport.lua`, `modules/SimRoster.lua`, `modules/SimScenario.lua`,
  `modules/SimWorld.lua`, `settings/SimVerbs.lua`; suites `tests/test_test_mode.lua`,
  `tests/test_sim_*.lua`
- **Commits since the previous release touching them:** 30 (of 62 touching `core/`, `modules/` or
  `settings/`), counted at 21ba4a4
- **Note:** the owner answered Current. The same day the samples were checked against the compact
  layout change (feedback-25): both rings on each side, the longest Trade reason, every History
  outcome.

## Actions

1. **`locales/enUS.lua` has been Accepted on three consecutive release runs** (20261017-012204,
   20261025-152417 and this one), so anti-pattern #53 owes it a fix or a tracked deviation ID. New
   here.
2. **`core/Compat.lua`'s journal split** is still owed from 1.0.0's watch list; it grew 1009 → 1062.
3. The six newly crossed files carry their rulings in `RESULTS.md`; none is near the 1500 cap.
