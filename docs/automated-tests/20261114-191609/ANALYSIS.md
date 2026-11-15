# Analysis — 20261114-191609

- **Addon:** DropWatcher 1.1.0
- **Verdict:** amber
- **Commit:** fe183b3 (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261114-001058

## Headline

Lint and the headless suite pass on a clean tree at `fe183b3`, the last RX-12 review fix on the rolls UX branch. The headless suite also passes under the Forever kit profile with 0 failed. The run is **amber** because of two things this round added. The perf refresh pair now allocates 14736 bytes a pass, over its 14500-byte ceiling (it was 14288 at the previous run). `RC.Tooltip` in `modules/RollCells.lua` scores CCN 16. Neither blocks a commit, but both block the tag, so both are owed a fix before this branch is released.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261114-001058 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 261 files | [`lint.txt`](lint.txt) | 259 → 261 files, still 0/0 |
| tests (Retail profile) | pass | 2486 passed, 1 skipped, 0 failed, 2487 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 2415 → 2487 total (+72), skip count unchanged at 1 |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2378 passed, 108 skipped, 0 failed, 2486 total | console of `KA0S_KIT_CLIENT=forever lua tests/run.lua` at `fe183b3` (no bundle artifact; the kit writes none for the second profile) | 2414 → 2486 total, skip count unchanged at 108 |
| perf | fail (non-gating at the commit, gates the tag) | 8 scenarios, 2 ceiling assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 14288 → 14736 bytes/iter, now over the 14500 ceiling |
| complexity | pass (1 warning, gates the tag) | see below | [`complexity.txt`](complexity.txt) | max CCN 15 → 16, warnings 0 → 1 |

The one Retail skip is the kit's diagnostics opt-out case. It does not apply to this addon, which keeps the default `Kit.diagnostics.enablesLogging` ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 73237 |
| Functions | 8801 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 16 |
| Avg tokens / function | 79.0 |
| Warnings (CCN > 15) | 1 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted: `blindFiles` and `crashedFiles` are both 0.

**perf.** [`perf.txt`](perf.txt) reports two failed assertions: `refreshCaptureOff` and `refreshCaptureOn` each allocated 14736.0 bytes/iter, over their 14500-byte ceiling. The pair still matches (off and on are equal), so capture still costs nothing. The rise is the full refresh pass doing more work: +448 bytes a pass since `912a109`. It is a **regression from this round**, not a pre-existing condition. The previous run read 14288.0 on the same scenarios. The compact pair moved the other way (11056.0 → 10384.0). The ceiling's own comment in `tests/perf.lua` records that a rise is to be explained or removed, not absorbed by raising the ceiling. The previous round's amber bundle was resolved the same way (bisected, then fixed without raising a ceiling).

**complexity.** `RC.Tooltip@294-313@./modules/RollCells.lua` scores CCN 16 in 20 NLOC ([`complexity.txt`](complexity.txt)). It is a **regression from this round**, since the previous run's max was 15 and the function arrived with RX-06. The score is mostly **guarding and defaulting**, not tangled control flow: `opts = opts or {}`, the `type(roll) == "table" and roll or {}` guard, `itemTitle(roll) or L["Rolls"]`, `by[g] = by[g] or {}`, `roll.isTied and not roll.winner`, and the `type(opts.verdict) == "table" and ... or nil` / `v and v.text` pair. Each short-circuit counts as a decision. Hoisting the grouping loop or the footer rows (tied, time left, verdict) into a local helper brings it under 15.

The plain `lizard -C 15 -w core modules settings defaults tests` line in this run's per-item gate printed nothing at `fe183b3`. Raw `lizard` does not list `RC.Tooltip` at all, because it is blind in that function (`#tip + 1` is a documented Lua blind spot). The kit's sanitized shadow does measure it. `automated-tests-§3` makes `bash tests/_kit/run-automated-tests.sh --suite complexity` the only command a gate line quotes, and that command reports the warning.

## What moved

- **lint**: 0/0 both runs. The file count rose from 259 to 261 with the round's new modules and suites. The scope is unchanged: `.luacheckrc` still excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: 2415 → 2487 Retail cases (+72) and 2414 → 2486 Forever cases, from the rolls UX round's cases. Failed is 0 on both profiles and both runs. Skips are unchanged at 1 (Retail) and 108 (Forever).
- **perf**: the refresh pair rose 14288.0 → 14736.0 bytes/iter and crossed its 14500 ceiling. The compact pair fell 11056.0 → 10384.0. `parseCaptureOff`/`parseCaptureOn` are unchanged at 664.0, `showDecisionStoodDown` is unchanged at 0.0, and `insightsCompute` rose 4956816.0 → 4957904.0, inside its 5200000 ceiling. Timings are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: NLOC 71503 → 73237 and functions 8601 → 8801. Avg NLOC per function held at 7.6 and avg CCN at 2.5, and avg tokens rose 78.7 → 79.0. So the addon grew without getting denser on average, and the one new signal is a single function crossing CCN 15. Band files held at 15 and over-cap files at 0.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `RC.Tooltip` | 16 | `modules/RollCells.lua` | **Newly crossed** this run (RX-06's per-roll tooltip). Dense guarding and defaulting, not tangled flow. **Fix owed before release**: hoist the grouping loop or the footer rows into a local helper. |

**Files by `layout-§1` band**: none newly crossed this run. All 15 entries are carried unchanged in `RESULTS.md`. Two grew within the band: `locales/enUS.lua` 1006 → 1014, `tests/test_feed.lua` 1035 → 1065. `modules/LootFeed.lua` stays at 1099, one line under its recorded 1100 split trigger.

| Band | File | LOC | Disposition |
|---|---|---|---|

None newly crossed.

No **Accepted** entry has been carried across three consecutive release runs. Only the 1.1.0 release run has carried the band entries so far.

## Actions

1. `modules/RollCells.lua` › `RC.Tooltip`: bring it to CCN 15 or under, for example by hoisting the grouping loop or the footer rows into a local helper. The release gate needs zero functions above CCN 15. This is new here and has no tracked ID.
2. The refresh pass (`tests/perf.lua` › `refreshCaptureOff`/`refreshCaptureOn`): bisect the +448 bytes a pass across the round's commits since `912a109` and remove the new per-pass allocation, without raising the 14500 ceiling. The tag is gated on perf passing. This is new here and has no tracked ID.
3. The run's per-item gate line quotes plain `lizard -C 15 -w`, which is blind in `RC.Tooltip`. Quote `bash tests/_kit/run-automated-tests.sh --suite complexity` instead (`automated-tests-§3`). This is new here.
