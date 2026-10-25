# Perf analysis — Ka0s Drop Watcher

The store for **in-game** performance captures (performance-§8). An interpretation without its
record is an assertion, so every capture this repo cites lands here as a frozen bundle. What the
harness measures and why is on [performance.md](../performance.md).

## Bundle naming

`docs/perf-analysis/<YYYYMMDD-HHMMSS>/`, in local time, taken from the record's own timestamp
rather than from when the bundle was written.

## The three artifacts

| File | What it is |
|---|---|
| `report.md` | The text report the client printed after `/dw perf finish` |
| `dump.json` | The JSON dump, byte for byte as copied out of the client |
| `ANALYSIS.md` | The write-up, per the standards repo's `PERF_ANALYSIS.md` playbook |

Bundles are never edited and never pruned.

## Record schema

The record is LibKa0s-Perf's, not this addon's: `lib.SCHEMA` in `libs/LibKa0s/Perf.lua`, documented
field by field in the library's `docs/api/Perf/`. The buckets are declared in `core/PerfSetup.lua`.

## How to capture

1. `/dw perf` opens the step panel.
2. Run Experiment A, then Experiment B, then finish.
3. Copy the report and the dump.
4. Run `/dev-copilot:wow-perf-analysis` with both; it writes the bundle here.

Offline runs (`lua tests/perf.lua`) are not captures. They are recorded with the automated-test
battery in [`automated-tests/`](../automated-tests/RESULTS.md).

## Captures

Two captures so far. Smoke check DIAG-4 (the `feed.add` nesting) is still waiting for one that
observes loot inside the clean arm.

| Stamp | Addon version | Label | What it measured | Bundle |
|---|---|---|---|---|
| 20261025-153429 | 1.0.0 | `2026-10-25 15:30` | Two trash pulls in Murder Row, party of 5, 62.0 s and 69.3 s. One `tradeTimer.scan` (0.0154 ms, 0.00025 ms/s) was the only addon code measured; the -0.47 ms/frame delta is inside the floor and backwards | [ANALYSIS](20261025-153429/ANALYSIS.md) |
| 20261017-010913 | 0.1.0 | `2026-10-17 01:04` | Two trash pulls in Murder Row, party of 5, 19.1 s and 15.0 s. No bucket fired, so it measured no addon code; the -2.35 ms/frame delta is backwards (the pulls differed) | [ANALYSIS](20261017-010913/ANALYSIS.md) |
