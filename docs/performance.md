# Performance — Ka0s Drop Watcher

How much this addon costs, and how to find out. The shared protocol, the record contract and the
step panel are `LibKa0s-Perf-1.0`'s and are documented in the library repo's `docs/api/Perf/`; this
page covers what is this addon's.

## The harness

`core/PerfSetup.lua` builds one instance at load (performance-§1): `DropWatcherPerfDB` is the
capture ring, the latch from `core/LifecycleSetup.lua` is handed over so Suspend and Resume take and
release its `perf` hold, and the `perf` verb is the addon's (`settings/Slash.lua`), printing the
lines the library returns. A suspended addon is inert through the same stand-down the disabled
state uses, and the window's show decision refuses at its source while the latch is held.

## The buckets

| Bucket | Bracketed in | What one note is |
|---|---|---|
| `window.refresh` | `modules/Window.lua` `Window.Refresh` | one repaint pass of the window |

Every bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean
test when capture is off. The feature items add the design's buckets (`parse`, `feed.add`,
`evaluate`, `inspect.read`, `tradeTimer.scan`, `quality.gate`; design spec §13) together with the
bracket that reaches each one, and `tests/test_setup.lua` fails if a declared bucket is never
reached.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling |
|---|---|---|
| `refreshCaptureOff` | the bracketed repaint with capture off notes nothing and allocates nothing (zero overhead) | 0 bytes, 0 notes |
| `refreshCaptureOn` | one note per pass with capture on | 64 bytes, 1 note |
| `showDecisionStoodDown` | the stood-down show decision returns before any work | 0 bytes, 0 notes |

## In game

`/dw perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.
