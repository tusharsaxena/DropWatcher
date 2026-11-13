# Analysis — 20261114-001058

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 912a109 (feat/2026-11-13-forever-port)
- **Previous run:** 20261105-100457

## Headline

All four suites pass on a clean tree at `912a109`, the whole-run review fix commit on the WoW Forever port branch. The headless suite also passes under the Forever kit profile, with 0 failed. Since the previous run at `fcc2815` the suite grew from 2216 to 2415 cases. The perf refresh pairs read exactly what they read on 2026-11-05. Complexity is sighted and nothing is above CCN 15. Nothing has to be fixed before the next commit. Five files newly sit in the 1000–1500 band and have dispositions in `RESULTS.md`, and one of them, `modules/TestData.lua`, is marked to peel next.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261105-100457 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 259 files | [`lint.txt`](lint.txt) | 241 → 259 files, still 0/0 |
| tests (Retail profile) | pass | 2414 passed, 1 skipped, 0 failed, 2415 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2216 → 2415 total (+199), skip count unchanged at 1 |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2306 passed, 108 skipped, 0 failed, 2414 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` at `912a109` (no bundle artifact; the kit writes none for the second profile) | first record of the Forever profile in this store |
| perf | pass | 8 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | none: every `bytes/iter` equals the previous run's |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in size, a little denser per function, 0 warnings both runs |

The one Retail skip is the kit's diagnostics opt-out case, which does not apply to this addon because it keeps the default `Kit.diagnostics.enablesLogging` ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit declares skipped on that profile (`clients-§6`). They count in the total, never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 71503 |
| Functions | 8601 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 78.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted: `blindFiles` and `crashedFiles` are both 0. Every suite passed cleanly, so there is no failure paragraph to write.

**About the run before this one.** An earlier full run that night, at `c9e1ab3` (bundle stamped 20261113-233806), was **amber**. Its perf refresh pairs were over their ceilings (14752 and 11520 bytes against 14500 and 11500). Lizard was blind in `tests/test_evaluate.lua`, and three test bodies scored CCN 16. That bundle was discarded uncommitted once the fixes landed, so its files are not in this store. The figures are recorded in `docs/performance.md`, and the fix commit `912a109` explains them. The perf rise was bisected to DW-FP15 (+256 bytes a pass) and DW-FP17 (+208). The fix restores the 2026-11-05 figures without raising a ceiling. The CCN 16 bodies came from this branch's own test additions and are regressions that were fixed, not newly measured functions.

## What moved

- **lint**: 0/0 both runs. The file count rose from 241 to 259 with the port's new modules and suites. The scope is unchanged: `.luacheckrc` still excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: 2216 → 2415 cases (+199), from the Forever port's cases on both profiles. The failed count is 0 both runs and the skip count is 1 both runs. This store has no earlier Forever-profile figure to compare with.
- **perf**: no allocation figure moved. The refresh pair is 14288.0 and the compact pair 11056.0, every pair matching. `parseCaptureOff` and `parseCaptureOn` are 664.0, `showDecisionStoodDown` is 0.0 and `insightsCompute` is 4956816.0. The timings moved within run-to-run noise and are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: NLOC rose from 63279 to 71503 and functions from 7785 to 8601. Average NLOC per function went from 7.4 to 7.6, average CCN from 2.4 to 2.5 and average tokens from 76.8 to 78.7. Max CCN stayed at 15 with 0 warnings. The three averages show a slight increase in density per function, small next to the growth in size. Band files went from 10 to 15 and over-cap files stayed at 0.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band** (newly crossed this run, the remaining ten carried unchanged in `RESULTS.md`):

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `core/Compat.lua` | 1050 | **Newly crossed** (999). **Accepted**: the one shim home, with the loot and roll readers already in `core/CompatLoot.lua`; split the next shim family out before 1250. |
| 1000–1500 (on notice) | `locales/enUS.lua` | 1006 | **Newly crossed** (865). **Accepted**: a flat key table with no control flow. |
| 1000–1500 (on notice) | `modules/TestData.lua` | 1146 | **Newly crossed** (966). **Peel next**: move the Forever sample tables into their own data file before 1250. |
| 1000–1500 (on notice) | `tests/test_evaluate.lua` | 1099 | **Newly crossed** (888). **Accepted**: a suite file; split the verdict-mode cases out before the cap. |
| 1000–1500 (on notice) | `tests/test_feed.lua` | 1035 | **Newly crossed** (965). **Accepted**: a suite file; split it by receipt source before the cap. |

No **Accepted** entry has been carried across three consecutive release runs yet. The band entries date from after the 1.0.0 release run, and only the 1.1.0 release run has carried them.

## Actions

1. `modules/TestData.lua`: move the Forever sample tables (members, places, the sample roll) into their own data file before the file passes 1250 lines. This is new here and has no tracked ID.
2. The other four newly banded files need no work now. Their split triggers are recorded in `RESULTS.md`.
