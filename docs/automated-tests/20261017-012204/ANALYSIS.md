# Analysis — 20261017-012204

- **Addon:** DropWatcher 0.1.0 → 1.0.0 (release record)
- **Verdict:** green
- **Commit:** 80df719 (master, clean tree)
- **Previous run:** 20261017-011710 (measured 05b777c), the release attempt this one replaces; the last
  analysed run is 20261015-001310 (measured 0109f2a)

## Headline

This is the 1.0.0 release record, and every release gate holds: all four suites passed on a clean tree at
80df719, no function is above CCN 15 (max 14) and the run is sighted (`blindFiles` 0). The release run
before it, 20261017-011710, was refused on one function, `FR.Pick` at CCN 19. 80df719 split it into two
helpers and it now scores 11. Since the last analysed run there are 1481 cases, up from 1423; lint is still
clean, now over 178 files; and `core/Compat.lua` newly crossed into the 1000–1500 band.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261015-001310 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 178 files | [`lint.txt`](lint.txt) | +8 files, still 0/0 |
| tests | pass | 1480 passed, 1 skipped, 0 failed, 1481 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +58 cases; the one skip is unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; the two refresh pairs moved (below) |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | +2217 NLOC, +234 functions; max CCN 14 |

**Complexity is reported in full** (all figures from [`manifest.json`](manifest.json), `suites.complexity`):

| Metric | Value |
|---|---|
| Total NLOC | 45215 |
| Functions | 5611 |
| Avg NLOC / function | 7.4 |
| Avg CCN | 2.5 |
| Max CCN | 14 |
| Avg tokens / function | 73.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

The run is sighted (`blindFiles` 0). Max CCN 14 is shared by four functions
([`complexity.txt`](complexity.txt)):
- `candidateEq@157-176` in `modules/SideCells.lua`, the same as last analysed run;
- `Compat.JournalSelection@934-944` in `core/Compat.lua`, new with feedback-17's keystone preview level;
- `pickDrop@148-158` in `modules/TestData.lua`;
- an anonymous case body at `tests/test_test_mode.lua:142-178`.

`FR.Pick@68-89` in `modules/FeedRestore.lua` scores 11, and its two new helpers, `sessionFeedKey@47-51` and
`pickable@54-57`, score 5 and 6.

**Perf** ([`perf.txt`](perf.txt)): compare the per-iteration allocation; the timings are only for
orientation.
- The full refresh allocates 14096.8 bytes/iter, down from 14240.8.
- The compact refresh allocates 10864.9, up from 10432.9.
- Both refresh pairs went over their ceilings after feedback-15 and feedback-16, and DW-R4 brought them back
  under (`docs/performance.md`). The compact painter still carries 432 bytes/iter more than it did before
  feedback-15. Its footer row and icon strip are new work, and this figure is within its ceiling.
- `showDecisionStoodDown` (0.0) and the parse pair (664.2) did not move.
- Capture off and on are equal in every pair.

## What moved

- **lint:** 170 → 178 files, still 0 warnings and 0 errors.
- **tests:** 1423 → 1481 cases, 1422 → 1480 passed, the 1 skip as before. The new cases came with
  feedback-15 to feedback-18 (the reload restore, the icon strip, real-boss test data and the sample gear)
  and DW-R4's `test_drops_strip`. [`test-cases.md`](test-cases.md) matches `docs/test-cases.md` at HEAD.
- **perf:** the two refresh pairs, as above; nothing else.
- **complexity:**
  - +2217 NLOC and +234 functions; avg NLOC 7.3 → 7.4, avg CCN 2.4 → 2.5, tokens per function 72.3 → 73.5.
  - Max CCN is still 14, with no warnings.
  - The band table gained `core/Compat.lua` at 1009 lines.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Compat.lua` | 1009 | **Newly crossed** — feedback-17's journal shims (the keystone preview level, the world-boss flag and `JournalEncounterName`) took it from 960 to 1009 lines. The Encounter Journal shims are the natural family file to split out (`core/CompatJournal.lua`, named from `core/Compat.lua`'s header) before it grows further. |
| 1000–1500 (on notice) | `locales/enUS.lua` | 1329 | **Accepted** — a flat `L["..."] = "..."` string table with no logic; it grew past 1000 when DW-P19 added every routed enUS key (F07, D8). Split it by surface before it nears the 1500 cap. This is its first release run, so it starts the three-release shelf life here. |

## Actions

1. `core/Compat.lua`: newly in the 1000–1500 band at 1009 lines. Splitting the Encounter Journal shims into
   a family file would take it back under 1000. New here; no deviation ID or review finding owns it.
2. The compact refresh's extra 432 bytes/iter since feedback-15 is the cost of its footer row and icon strip,
   inside its ceiling since DW-R4. It needs no action unless a later run moves it again. The +64 bytes/iter
   carried from 20261014-231415 is part of that figure now.
