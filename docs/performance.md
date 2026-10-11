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
| `parse` | `modules/LootParser.lua` `LootParser.Parse` | one `CHAT_MSG_LOOT` line read |
| `inspect.read` | `modules/Inspect.lua` `readSlots` | one read of a member's 17 slots (the fast path, or after `INSPECT_READY`) |
| `feed.add` | `modules/LootFeed.lua` `LootFeed.Receive` | one receipt taken into the feed: the dedupe, the gates and the judging done at once (a drop whose item is still loading is judged later, outside the bracket) |
| `evaluate` | `modules/LootFeed.lua` `evaluate` | one verdict for one candidate (you, the looter, or a member for your own drop) |
| `quality.gate` | `modules/LootFeed.lua` `qualityGate` | one minimum-quality decision |
| `tradeTimer.scan` | `modules/TradeTimer.lua` `TradeTimer.Scan` | one read of your own drops' bag items and their trade-time lines (at most one per 2 seconds) |
| `gear.rebuild` | `modules/Gear.lua` `Gear.Refresh` | one read of your worn and bag items into the gear snapshot (deferred out of combat for bag events; a bag-only rebuild reads no worn tooltip) |
| `window.refresh` | `modules/Window.lua` `Window.Refresh` | one repaint pass of the window |

Every bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean
test when capture is off. Every bucket of design spec §13 is declared, plus `gear.rebuild` (added by the M2 review:
the rebuild runs on frequent bag events), each with the bracket that reaches it, and `tests/test_setup.lua` fails if a declared bucket is never reached.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling |
|---|---|---|
| `refreshCaptureOff` | the shown window's whole repaint with capture off: the bracket notes nothing, and allocates nothing over the same pass with capture on (zero overhead, paired) | 14000 bytes (the pass's own labels, footer strings, tab context and empty state; 13456 measured 2026-10-11), 0 notes |
| `refreshCaptureOn` | the same with capture on: one note per pass, at most 64 bytes over the off run | 14000 bytes, 1 note |
| `showDecisionStoodDown` | the stood-down show decision returns before any work | 0 bytes, 0 notes |
| `parseCaptureOff` | one third-person loot line parsed, the looter in the group; the bracket notes nothing | 700 bytes (the parse's own captures, record and roster lookup; 664 measured), 0 notes |
| `parseCaptureOn` | the same with capture on: one note, and the same bytes, so the bracket adds none | 700 bytes, 1 note |

## In game

`/dw perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.
