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
| `insights.compute` (within `window.refresh`) | `modules/WindowInsights.lua` `compute` | one Insights recompute: Rows, Normalize, Filter, Period and the stats pass (issue #12), run only when the tab's cache key says the data or the filters changed |
| `insights.layout` (within `window.refresh`) | `modules/WindowInsights.lua` `layout` | one Insights layout pass: the cards and every chart section, run on a recompute, a width or layout change, or a skin switch |

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
| `insightsCompute` | the Insights recompute's pure pass alone (Rows, Normalize, Filter, Period, Compute) over a log at the safety ceiling, `NS.History.CEILING` (5,000) drops; it builds a row a drop and the options and stats tables by design, so its ceiling is that work; it calls no bracket, so it notes nothing | 5200000 bytes (4956816 measured 2026-11-05), 0 notes |
| `rollsPanelRaid` | the Rolls panel's raid refresh (rolls panel design §3.3, RX-18): `RollsPanel.Refresh` over six watched rolls of 40 players in a group of 40, all six blocks open with their rows and their folded Pass and Waiting lines (RX-21 removed the one-open rule); each block's rows are kept while its roll reads the same and a pooled frame already in place is left there, so a repaint composes the headers and the time left; every frame comes from the pools; it calls no bracket, so it notes nothing | 95000 bytes (89376 measured 2026-11-15 with one block open; 79328 with all six after RX-21, 427136 before it kept the rows), 0 notes |

The warm-up and the measured loop call each scenario through one helper, so both run at the same Lua
stack depth. Before DW-C5 the measured loop sat one frame deeper, and the first scenario paid a one-time
stack reallocation, about 1.8 KB, once DW-C2 deepened the refresh path. That put `refreshCaptureOff`
at 14249.9 bytes against `refreshCaptureOn`'s 14248.1 and failed the pair's check (found by bisecting
the M12 commits).

Re-run 2026-10-14 after the M24 remediation (DW-P16..DW-P27), again after DW-P24 (no scenario
reaches `feed.add`, so the figures do not move), and 2026-10-15 after DW-P25 (tests only): every pair still matches, off and on
allocating the same bytes (`refreshCaptureOff`/`On` 14240.8, `refreshCompactCaptureOff`/`On` 10432.9,
`parseCaptureOff`/`On` 664.2), each under its ceiling, and `showDecisionStoodDown` 0.

Re-run 2026-10-16: the four refresh scenarios had gone over their ceilings, `refreshCaptureOff`/`On`
16048.8 and `refreshCompactCaptureOff`/`On` 12672.9 (14240.8 and 10432.9 before feedback-15; the run sits
outside the green gate, so nothing failed). Bisected to feedback-15's footer row (DW-Q2) and
feedback-16's icon-only compact strip: the Drops strip built its row and slot tables and re-anchored its
three buttons and its text on every repaint, in both layouts, and History's strip its row. Each strip now
places itself only when what decides it changes (the layout, and on Drops whether Post shows), pinned by
`test_drops_strip`. After it: `refreshCaptureOff`/`On` 14096.8 and `refreshCompactCaptureOff`/`On`
10864.9, every pair matching and under its ceiling; the parse pair and `showDecisionStoodDown` unmoved.

Re-run 2026-10-18 after feedback-21: `refreshCaptureOff`/`On` 13713.0 and `refreshCompactCaptureOff`/`On`
10481.1, every pair matching and under its ceiling; the parse pair and `showDecisionStoodDown` unmoved.

Re-run 2026-10-31: `refreshCaptureOff`/`On` had gone over the ceiling at 14577.0 and
`refreshCompactCaptureOff`/`On` had risen to 11345.0 (recorded in `automated-tests/20261031-202124/`).
Bisected to two commits. DW-02 of the skinning rollout (52b9951) added 336 bytes by painting both tab
labels through `S.Text` on every pass (32 more came with the later skin work, 14081.0 at 0d9d843). DW-01 of the
skin fonts run (bc3c5dc) added 496 by building a fresh table in `NS.WindowRows.ReadFont` and widening
the metrics table. A tab label is now painted only when its role changes, since the library replays
the recorded role on a skin switch, and `ReadFont` rewrites one table, pinned by `test_skin_chrome` and
`test_table_font`. After it: `refreshCaptureOff`/`On` 13456.0 and `refreshCompactCaptureOff`/`On`
10224.0 over repeated runs, every pair matching and under its ceiling, which did not move;
`parseCaptureOff`/`On` 664.0 and `showDecisionStoodDown` 0.

The same day the off bracket read 1.9 bytes over the on one once two files joined the TOC, a stack
artifact rather than a cost: the full collect shrinks the Lua stack, how far depends on what the load
left it at, and the first iteration after it pays the regrowth. `measure` now runs one settling call
with the collector stopped, so the loop measures only what each iteration allocates, and the figures
above are whole numbers.

Re-run 2026-11-05 after the Insights tab (issue #12): `refreshCaptureOff`/`On` 14288.0 and
`refreshCompactCaptureOff`/`On` 11056.0, every pair matching and under its ceiling (the window
measured is on Drops: the third tab's label and its tooltip function cost the rise from 13456 and
10224, and the Insights pane is not built); `insightsCompute` 4956816.0 under its 5200000; the parse
pair 664.0 and `showDecisionStoodDown` 0. The two Insights brackets are the gated form and declare
`within = "window.refresh"`, because the tab's refresh runs inside the window's repaint: do not sum
them with it.

Re-run 2026-11-13 on the WoW Forever port branch: the refresh pairs had read 14752.0 and 11520.0, over
their 14500 and 11500 ceilings. Bisected to two commits: DW-FP15 (the Rolling now section, +256 bytes a
pass: `Pending.All`'s list and its empty fallback, built even with nothing pending, and the empty
state's second `WindowPending.Items` call) and DW-FP17 (+208: `Window.FeedView`'s fresh table read for
its feed name). The ceilings stay where they are: the repaint now asks `WindowPending.None`
(`Pending.Count`, `Window.FeedName`) before it builds anything, so with nothing pending the pairs are
back to 14288.0 and 11056.0, the 2026-11-05 figures exactly.

Re-run 2026-11-16 (RX-27): the refresh pairs had climbed from 12624.0 and 8272.0 (after 2118228's
quality readout fix) to 13552.0 and 9200.0, with 948 bytes left under the 14500 ceiling. Bisected
with `tests/perf.lua` over every commit of 2118228..b19707c, each exported to its own directory: two
steps, UC-DW's bee9b9f (+480, the mode strips docked and the footer built with W.Footer) and RX-24's
c5d9613 (+448, the footer's words and controls on W.Footer's lines and marks), every other commit
flat. A per-function profile under the mock put both on one call: `paintMinimized` handed the footer
its grip on every pass, and W.Footer's `SetGrip` lays its marks and both lines out again each time,
which with RX-24's three marks cost more. The shell now calls `SetGrip` only when the grip turns, and
`NS.WindowTabs.Layout` anchors a pane again only when its top moves (a further 1152 bytes: all three
panes were re-anchored on every pass), both pinned by `test_window_shell`.
After it: `refreshCaptureOff`/`On` 11120.0 and `refreshCompactCaptureOff`/`On` 6768.0, the ceilings
unmoved.

## Item Search (WoW Forever alone)

Item Search (DropWatcher#17, Item Search spec §2, §4.2, §4.4) is the one reader of the optional
ForeverDB addon, through LibKa0s-ForeverDB-1.0. On Retail all of it is absent: the hook is never
installed, the reagent table's builder is never made, and nothing loads (`itemSearchTipInert`, 0
bytes). SF-DW-01's detail card Sources chip, which used to load ForeverDB on the first card opened,
is retired (IS-DW-07), so a detail card reads nothing of ForeverDB. The budgets below are this
addon's own; they are not in the refresh ceilings above, which no Item Search path touches.

| Cost | Budget | Measured | Where |
|---|---|---|---|
| ForeverDB itself | not this addon's: some **12 MB on disk**, LoadOnDemand; the addon list charges its tables to ForeverDB | the kit fake counts the loads | `modules/ItemSearch.lua`: one load a session, `C.ITEM_SEARCH.LOAD_DELAY` (5 s) after the first `PLAYER_ENTERING_WORLD`, out of combat (else at `PLAYER_REGEN_ENABLED`), and none while both switches are off; never on a hover, a card or a login frame |
| The adapter's name and quest indexes | built once a session, right after the load, one per frame, never on a hover (spec §4.4) | the library's (`docs/api/ForeverDB/version-1-docs.md`) | LibKa0s-ForeverDB-1.0 minor 2, warmed by `modules/ItemSearch.lua` |
| The recipe-reagent table (`core/RecipeReagentsForever.lua`, 2466 recipes) | **under 2.5 MB** resident on WoW Forever, built once on Item Search's first ask, the builder then let go; **0** on Retail (the chunk's constants are let go after the load) | 1906 KB built (2041 KB kept with the file's strings), 2.9 ms, headless Lua 5.1 on 2026-11-25; the 234 KB file's constants are let go on Retail | `NS.RecipeReagents.Get()` |
| One item hover, cold (the item's static facts read from ForeverDB, then kept for the session) | `itemSearchTipCold`, **17500 bytes** | 16656.0 (16080 at IS-DW-04; +576 since the page stores the section order, a fresh order list a hover) | `modules/ItemSearchTip.lua`, `tests/perf.lua` |
| One item hover, warm (the cache serves the static half; quest state, known recipes and ranks read live) | `itemSearchTipWarm`, **6500 bytes** | 6240.0 (5664 at IS-DW-04; the same +576) | the same |
| The per-item cache | grows with the items hovered, one entry each, for the session; emptied when ForeverDB's state moves or a recipe is learned | not measured headless | `NS.ItemSearch.Get` / `Invalidate` |
| CPU | no budget in milliseconds (performance-§9: offline timings are orientation only); the hover is a cache read plus at most one ForeverDB lookup per source kind | about 0.07 ms cold, 0.04 ms warm per hover in the same run | `lua tests/perf.lua` |

The ceilings were not moved by IS-DW-07: both hovers stay under them, with 844 and 260 bytes left.
The 576-byte rise was measured commit by commit (`tests/perf.lua` over each exported commit): 16080
and 5664 at bec0d6e, 8415639 and 9242fb1, 16656 and 6240 from 8786d8f, the settings page, whose
default stores the section order, so `NS.ItemSearchTip.Options` now builds the order list and its
seen set (`orderOf`) on every hover where it used to answer the default list. It is the work, and the warm hover's margin is now small, so the next rise there is to be bisected
before a ceiling moves.

**ForeverDB_Full (round 3 spec §4.6, ISR3-DW-03).** The uncapped companion addon loads only through
LibKa0s's `LoadFull()`, on the Item Search window's first open of a session (`itemSearch.fullDB`,
"When the Item Search window opens", the default; "Never" loads nothing), never in combat and never
from a tooltip. Measured offline at ForeverDB v2026.11.25.48 (Lua 5.1, the seven files read from the
client folder read-only by a scratch script in no repo, after the base addon's four; numbers only):

| Measure | Value |
|---|---|
| The files on disk | 7, 20.6 MB |
| The base addon resident, for comparison | 62.8 MB |
| ForeverDB_Full's tables kept after a full collect | **+82.3 MB** (+98.9 MB before the collect) |
| The load's time, `os.clock` | 487 to 521 ms over three runs |

The resident cost is about four times the files' size: the "some 20 MB" the planning spec quoted is
the disk, not the memory. The in-game numbers, `collectgarbage("count")` and `debugprofilestop()`
around the load, go to the debug log ("ForeverDB_Full loaded: N MB, N ms") and the diagnostics line
(`itemSearch: ... fullMB= fullMs=`), and smoke row ITEM-SEARCH-40 records them. The load empties the
per-item cache and the spot memo, so the next hover of each item is a cold one.

The round 3 source work (ISR3-DW-03: the test-name filter, the Gathered from split, the per-vendor
prices) left `itemSearchTipCold` at 17112.0 (17127.8 before it) and moved `itemSearchTipWarm` from
6024.0 to 6088.0 (the Gathered from ranking's empty array, one a hover), both on WoW Forever, the
ceilings unmoved. A vendor row is built in one constructor of eight fields, and the drops keep their
array when no object is a gathering node, so a cold hover pays for neither.

## In game

`/dw perf` opens the step panel; [`perf-analysis/README.md`](perf-analysis/README.md) is the
capture store and says how a capture becomes a bundle.

The nesting of `evaluate` and `quality.gate` is confirmed in game, not headless: a two-arm capture
whose report reads each bucket observed inside `feed.add` and at top level (an item judged later,
once it loads, is judged outside the bracket) is smoke check DIAG-4, recorded with
`/dev-copilot:wow-perf-analysis` as a `docs/perf-analysis/<YYYYMMDD-HHMMSS>/` bundle. The
`within = "feed.add"` declarations it confirms landed with DW-P24 (LibKa0s Perf 15). DIAG-4 records
the owner's pass (2026-10-23), but no capture in `perf-analysis/` observes the nesting yet; the
bundle is owed until the owner supplies one, and none is ever invented.
