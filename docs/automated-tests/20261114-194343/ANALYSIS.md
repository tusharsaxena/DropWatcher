# Analysis — 20261114-194343

- **Addon:** DropWatcher 1.1.0
- **Verdict:** green
- **Commit:** 2118228 (feat/2026-11-14-rolls-ux)
- **Previous run:** 20261114-191609

## Headline

All four suites pass on a clean tree at `2118228`, and the headless suite also passes under the Forever kit profile with 0 failed. This run closes the two items the amber run `20261114-191609` left open. The refresh pair is back under its unchanged 14500-byte ceiling at 12624 bytes a pass, and max CCN is 15 with no warnings, since `RC.Tooltip` dropped from 16 to 9. Nothing is left to act on for the tag from this battery.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click. A
skipped suite links nothing — there is no artifact — and says what was not measured.

| Suite | Status | Result | Artifact | Moved since 20261114-191609 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 261 files | [`lint.txt`](lint.txt) | unchanged, 261 files, 0/0 |
| tests (Retail profile) | pass | 2486 passed, 1 skipped, 0 failed, 2487 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged at 2487 total, skip count 1 |
| tests (Forever profile, `KA0S_KIT_CLIENT=forever`, no bundle) | pass | 2378 passed, 108 skipped, 0 failed, 2486 total | console of `KA0S_KIT_CLIENT=forever tests/_kit/run-automated-tests.sh --suite tests --no-bundle` at `2118228` (no bundle artifact; the second profile writes none) | unchanged at 2486 total, skip count 108 |
| perf | pass | 8 scenarios, every ceiling and pair assertion holds | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | refresh pair 14736 → 12624 bytes/iter, compact pair 10384 → 8272 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | max CCN 16 → 15, warnings 1 → 0 |

The one Retail skip is the kit's diagnostics opt-out case. It does not apply to this addon, which keeps the default `Kit.diagnostics.enablesLogging` ([`tests.txt`](tests.txt)). The 108 Forever skips are the Retail-only cases the kit skips on that profile (`clients-§6`). Skips count in the total and never in passed.

**Complexity is reported in full**, from [`manifest.json`](manifest.json)'s `suites.complexity` and the footer of [`complexity.txt`](complexity.txt):

| Metric | Value |
|---|---|
| Total NLOC | 73241 |
| Functions | 8802 |
| Avg NLOC / function | 7.6 |
| Avg CCN | 2.5 |
| Max CCN | 15 |
| Avg tokens / function | 79.0 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 15 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The run is sighted, with `blindFiles` and `crashedFiles` both 0.

Every suite is a clean pass, so no suite needs a failure paragraph. The two fixes behind the movement are below.

**complexity.** `RC.Tooltip` in `modules/RollCells.lua` now scores CCN 9 (`RC.Tooltip@304-319`), and the new local `footerRows@289-295` scores 7 ([`complexity.txt`](complexity.txt)). Commit `6161b2e` moved the footer rows (Tied, Time left, your verdict) into that helper with no change in behavior. The +1 function (8801 → 8802) is that helper.

**perf.** `refreshCaptureOff`/`refreshCaptureOn` allocate 12624.0 bytes/iter each ([`perf.txt`](perf.txt)). That is under the unchanged 14500 ceiling, and under the 14288 the round started from. The amber run's +448 was bisected across the round's commits. RX-04 (`d4cbec4`) added +320: its two new item kinds grew the kinds map that `LootFeed.Config` builds on every pass. RX-09 (`d141787`) added +128. The fix, `2118228`, removed the per-pass config build entirely rather than shaving the new keys. `FB.QualityReadout` runs on every filter bar sync and built the whole feed config to read three settings; it now reads those three through `NS.Setting` (`FB.QualityReadout@506-516`, CCN 11). Off and on still match in both pairs, so capture still costs nothing.

## What moved

- **lint**: 0/0 over 261 files, unchanged. The scope is unchanged: `.luacheckrc` excludes `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/` and `tests/_kit/` (`RESULTS.md` › Lint).
- **tests**: unchanged at 2487 Retail cases and 2486 Forever cases. The two fix commits added no cases. Failed is 0 and skips are 1 (Retail) and 108 (Forever) on both runs.
- **perf**: the refresh pair fell 14736.0 → 12624.0 and the compact pair 10384.0 → 8272.0 bytes/iter. `parseCaptureOff`/`parseCaptureOn` are unchanged at 664.0, `showDecisionStoodDown` is unchanged at 0.0, and `insightsCompute` is unchanged at 4957904.0. Timings are not compared across runs ([`perf.txt`](perf.txt)).
- **complexity**: max CCN 16 → 15 and warnings 1 → 0. NLOC rose 73237 → 73241 and functions 8801 → 8802, from the helper. Avg NLOC (7.6), avg CCN (2.5) and avg tokens (79.0) held. Band files held at 15 and over-cap files at 0.

## Complexity watch list

**Functions `lizard` warned on:**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. `RC.Tooltip` (16 at `20261114-191609`) is fixed, now at 9.

**Files by `layout-§1` band**: none newly crossed this run. All 15 entries are carried unchanged in `RESULTS.md` with their dispositions.

| Band | File | LOC | Disposition |
|---|---|---|---|

None newly crossed.

No **Accepted** entry has been carried across three consecutive release runs. Only the 1.1.0 release run has carried the band entries so far.

## Actions

None.
