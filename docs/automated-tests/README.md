# Automated test records — Ka0s Drop Watcher

The consolidated record of the four out-of-game suites (automated-tests). Each run of the vendored
runner writes one frozen bundle, `docs/automated-tests/<YYYYMMDD-HHMMSS>/` (one file per suite plus
`manifest.json`), and regenerates [`RESULTS.md`](RESULTS.md), the trend line. Bundles are never
edited; `RESULTS.md` is generated and never hand-edited except the watch list's `Disposition` column.

## How to run it

```sh
tests/_kit/run-automated-tests.sh                      # all four suites, writes a bundle
tests/_kit/run-automated-tests.sh --release 0.1.0      # at a release, before the tag
tests/_kit/run-automated-tests.sh --no-bundle          # print only, write nothing
```

The runner is the kit's (`tests/_kit/`), recorded `100755` in the git index, and LF by
`.gitattributes`. `/dev-copilot:wow-automated-tests` runs it and writes the bundle's `ANALYSIS.md`.

## What gates, and what only records

- **`lint`** and **`tests`** gate the **commit**: `luacheck .` and `lua tests/run.lua` must be green.
- **`perf`** and **`complexity`** never fail a **run** and never gate a **commit**: they are recorded
  and compared between runs.
- The **release** (the tag) is gated on **all four** suites passing, plus zero functions above CCN 15
  and `blindFiles` 0 on the sighted complexity suite, evaluated by `/dev-copilot:bump-version` from the
  run's `manifest.json`.
- A missing tool is a **skip** with its reason, never a pass; a skip is not a pass for the release
  gate either. `perf` runs the offline scenarios in `tests/perf.lua` (see
  [`../performance.md`](../performance.md)).
