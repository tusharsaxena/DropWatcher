# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20261013-141937`](20261013-141937/) | `d2c4e7a` | clean | 0.1.0 | 0/0 | 164 | 1335/1/1336 | pass | 39524 | 5106 | 7.2 | 2.4 | 13 | 0 | **green** |
| [`20261013-104522`](20261013-104522/) | `189a13d` | clean | 0.1.0 | 0/0 | 161 | 1333/1/1334 | pass | 39660 | 5143 | 7.2 | 2.4 | 13 | 0 | **green** |
| [`20261011-230412`](20261011-230412/) | `7b77749` | clean | 0.1.0 | 0/0 | 161 | 1321/1/1322 | pass | 39401 | 5110 | 7.2 | 2.4 | 13 | 0 | **green** |
| [`20261011-211521`](20261011-211521/) | `0bca5ca` | clean | 0.1.0 | 0/0 | 148 | 1196/1/1197 | pass | 35560 | 4635 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-204356`](20261011-204356/) | `c6b3161` | clean | 0.1.0 | 0/0 | 146 | 1175/1/1176 | pass | 35025 | 4563 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-192657`](20261011-192657/) | `8fcfe45` | clean | 0.1.0 | 0/0 | 142 | 1150/1/1151 | pass | 34430 | 4487 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-184145`](20261011-184145/) | `2176e48` | clean | 0.1.0 | 0/0 | 141 | 1131/1/1132 | pass | 33900 | 4423 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-142452`](20261011-142452/) | `51d7065` | clean | 0.1.0 | 0/0 | 133 | 1065/1/1066 | pass | 31928 | 4162 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-132717`](20261011-132717/) | `8257eea` | clean | 0.1.0 | 0/0 | 130 | 1031/1/1032 | pass | 30605 | 4008 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-115548`](20261011-115548/) | `394af4f` | clean | 0.1.0 | 0/0 | 125 | 984/1/985 | pass | 29037 | 3808 | 7.1 | 2.4 | 13 | 0 | **green** |
| [`20261011-091808`](20261011-091808/) | `eb7aafb` | clean | 0.1.0 | 0/0 | 109 | 886/1/887 | pass | 25529 | 3369 | 7.0 | 2.4 | 13 | 0 | **green** |
| [`20261010-232937`](20261010-232937/) | `43d3792` | clean | 0.1.0 → 0.1.0 | 0/0 | 39 | 137/1/138 | pass | 2829 | 533 | 4.3 | 2.0 | 10 | 0 | **green** |

## Test suite

**1336 cases** — 1335 passed, 0 failed, 1 skipped. The generated inventory
[`20261013-141937/test-cases.md`](20261013-141937/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **1334 → 1336** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 164 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 6 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `docs/revendor/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**7 scenarios** from `tests/perf.lua`; the measurements are in
[`20261013-141937/perf.json`](20261013-141937/perf.json).

| `scenario` | `iters` | `ms/iter` | `notes/iter` | `bytes/iter` |
|---|---|---|---|---|
| `refreshCaptureOff` | 1000 | 0.09607 | 0.00 | 14400.8 |
| `refreshCaptureOn` | 1000 | 0.08947 | 1.00 | 14400.8 |
| `refreshCompactCaptureOff` | 1000 | 0.09526 | 0.00 | 10368.9 |
| `refreshCompactCaptureOn` | 1000 | 0.09595 | 1.00 | 10368.9 |
| `showDecisionStoodDown` | 1000 | 0.00013 | 0.00 | 0.0 |
| `parseCaptureOff` | 1000 | 0.01431 | 0.00 | 664.2 |
| `parseCaptureOn` | 1000 | 0.01559 | 1.00 | 664.2 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261013-141937`](20261013-141937/) — **this run's measurement, not its diff.** Max CCN **13** across 5106
functions, **0** of them warned on; 0 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|

None.

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

