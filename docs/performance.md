# Performance — Ka0s Drop Watcher

How much this addon costs, and how to find out. The shared protocol, the record contract and the
step panel are `LibKa0s-Perf-1.0`'s and are documented in the library repo's `docs/api/Perf/`; this
page covers what is this addon's.

## The harness

`core/PerfSetup.lua` builds one instance at load (performance-§1): `DropWatcherPerfDB` is the
capture ring, the latch from `core/LifecycleSetup.lua` is handed over so Suspend and Resume take and
release its `perf` hold, and the `perf` verb is the addon's (`settings/Slash.lua`), printing the
lines the library returns. A suspended addon is inert through the same stand-down the disabled
state uses, and the window's show decision refuses at its source while the latch is held. A feature
pressed or typed during a suspended run (Ask, Offer, Announce, Trade, Scan group, Post my
tradeables, `/dw test`, `/dw sim start`) answers `Not available during a performance capture.`
through `NS.StoodDownRefusal()`, never the disabled line's `enable it with /dw enable`, since
`enabled` is still on (DW-P16; smoke check DIAG-2).

## The buckets

| Bucket | Bracketed in | What one note is |
|---|---|---|
| `parse` | `modules/LootParser.lua` `LootParser.Parse` | one `CHAT_MSG_LOOT` line read |
| `inspect.read` | `modules/Inspect.lua` `readSlots` | one read of a member's 17 slots (the fast path, or after `INSPECT_READY`) |
| `feed.add` | `modules/LootFeed.lua` `LootFeed.Receive` | one receipt taken into the feed: the dedupe, the gates and the judging done at once (a drop whose item is still loading is judged later, outside the bracket) |
| `evaluate` (within `feed.add`) | `modules/LootFeed.lua` `evaluate` | one verdict for one candidate (you, the looter, or a member for your own drop) |
| `quality.gate` (within `feed.add`) | `modules/LootFeed.lua` `qualityGate` | one minimum-quality decision |
| `tradeTimer.scan` | `modules/TradeTimer.lua` `TradeTimer.Scan` | one read of your own drops' bag items and their trade-time lines (at most one per 2 seconds) |
| `gear.rebuild` | `modules/Gear.lua` `Gear.Refresh` | one read of your worn and bag items into the gear snapshot (deferred out of combat for bag events; a bag-only rebuild reads no worn tooltip) |
| `window.refresh` | `modules/Window.lua` `Window.Refresh` | one repaint pass of the window |

Every bracket is the gated form (performance-§2): one upvalue read, one field read and one boolean
test when capture is off. Every bucket of design spec §13 is declared, plus `gear.rebuild` (added by the M2 review:
the rebuild runs on frequent bag events), each with the bracket that reaches it, and `tests/test_setup.lua` fails if a declared bucket is never reached.

`evaluate` and `quality.gate` declare `within = "feed.add"` (performance-§3) and are sometimes nested:
inside `LootFeed.Receive` when the item is cached, at top level when it loads later or a re-judge
runs (an inspect, a gear change, a bag read). Each note passes its observed parent: `feed.add`
while Receive is open, Perf 15's `false` (top level) otherwise, read from a depth counter that
Receive raises and lowers around a `pcall`, so a re-entrant Receive cannot clear it early and a raise
cannot leave it set. A report therefore reads `observed inside feed.add and at top level`. **Do not
sum** `evaluate` or `quality.gate` with `feed.add`: their nested calls are already inside it.
`tests/test_setup.lua` covers the declaration, a Receive-only capture, the mixed capture and the raise.

## Offline scenarios

`lua tests/perf.lua`, outside the green gate (performance-§9), asserting bytes per iteration and
notes per iteration, never time:

| Scenario | What it shows | Ceiling |
|---|---|---|
| `refreshCaptureOff` | the shown window's whole repaint with capture off: the bracket notes nothing, and allocates nothing over the same pass with capture on (zero overhead, paired) | 14500 bytes (the pass's own labels, footer strings, tab context and empty state, plus M10's group-header hidden-drop predicates and Character context; 14168 measured 2026-10-11, DW-A6, after the filter bar stopped rebuilding its dropdown rows on every sync), 0 notes |
| `refreshCaptureOn` | the same with capture on: one note per pass, at most 64 bytes over the off run | 14500 bytes, 1 note |
| `refreshCompactCaptureOff` | the same repaint in the compact layout (compact spec §5, DW-C5): the cards' pane and the compact chrome; the bracket notes nothing and allocates nothing over the on run (paired) | 11500 bytes (11065 measured 2026-10-11, under the full pass: no column labels or table to lay out), 0 notes |
| `refreshCompactCaptureOn` | the same with capture on: one note per pass, at most 64 bytes over the off run | 11500 bytes, 1 note |
| `showDecisionStoodDown` | the stood-down show decision returns before any work | 0 bytes, 0 notes |
| `parseCaptureOff` | one third-person loot line parsed, the looter in the group; the bracket notes nothing | 700 bytes (the parse's own captures, record and roster lookup; 664 measured), 0 notes |
| `parseCaptureOn` | the same with capture on: one note, and the same bytes, so the bracket adds none | 700 bytes, 1 note |

The warm-up and the measured loop call each scenario through one helper, so both run at the same Lua
stack depth. Before DW-C5 the measured loop sat one frame deeper, and the first scenario paid a one-time
stack reallocation, about 1.8 KB, once DW-C2 deepened the refresh path. That put `refreshCaptureOff`
at 14249.9 bytes against `refreshCaptureOn`'s 14248.1 and failed the pair's check (found by bisecting
the M12 commits).

Re-run 2026-10-14 after the M24 remediation (DW-P16..DW-P27), again after DW-P24 (no scenario
reaches `feed.add`, so the figures do not move), and 2026-10-15 after DW-P25 (tests only): every pair still matches, off and on
allocating the same bytes (`refreshCaptureOff`/`On` 14240.8, `refreshCompactCaptureOff`/`On` 10432.9,
`parseCaptureOff`/`On` 664.2), each under its ceiling, and `showDecisionStoodDown` 0.

## In game

`/dw perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.

The nesting of `evaluate` and `quality.gate` is confirmed in game, not headless: a two-arm capture
whose report reads each bucket observed inside `feed.add` and at top level (an item judged later,
once it loads, is judged outside the bracket) is smoke check DIAG-4, recorded with
`/dev-copilot:wow-perf-analysis` as a `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle. The
`within = "feed.add"` declarations it confirms landed with DW-P24 (LibKa0s Perf 15); until a capture
is supplied by the owner the check stays pending, and none is ever invented.
