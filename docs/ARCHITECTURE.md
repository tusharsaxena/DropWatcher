# Architecture — Ka0s Drop Watcher

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it was built to is
[`superpowers/specs/2026-10-10-drop-watcher-v1-design.md`](superpowers/specs/2026-10-10-drop-watcher-v1-design.md);
this page describes what exists.

## Overview

A Retail addon that watches the loot a party or raid receives, judges each drop for you and for the
looter, estimates whether it can be traded, and asks for it in one click ([`scope.md`](scope.md)).
Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker and LibDBIcon are vendored under `libs/`, and so is the whole
LibKa0s v1.71.0 payload, of which fifteen majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[DW]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip |
| Compat | `core/Compat.lua` | the secret guards (`IsSecret`, `CanAccess`, `IsSafeKey`); the file is also the addon's own compat seam |
| Media | `core/MediaSetup.lua` | the icon catalog and the monospace face |
| Env | `core/EnvSetup.lua` | the addon's own TOC metadata and version |
| Pool | `core/PoolSetup.lua` | the row pool (for the drop tables) |
| Item | `core/ItemSetup.lua` | link parsing, quality labels, the item load (for item facts) |
| Bus | `core/Bus.lua` | the strict message catalog and the tracked receivers |
| Lifecycle | `core/LifecycleSetup.lua` | the stand-down latch |
| Perf | `core/PerfSetup.lua` | the performance harness |
| DebugLog | `core/DebugLogSetup.lua` | the debug console and the diagnostics report |
| Launcher | `core/LauncherSetup.lua` | the minimap button and broker plugin, one object |
| Schema | `settings/SchemaSetup.lua` | the write seam's runtime |
| Options | `settings/OptionsSetup.lua` | the settings panel |
| Slash | `settings/Slash.lua` | the `/dw` dispatcher |
| Widgets | `core/WidgetsSetup.lua` | the window's flat dropdowns (`NS.MakeDropdown`) and the shared `NS.CloseMenu` |

Without LibKa0s-Widgets-1.0 the window draws no dropdown at all (`NS.MakeDropdown` answers nil and
the search box still filters), and `NS.CloseMenu` is a no-op. Each setup file holds a
descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every stub to the live
surface.

The main window (`modules/Window.lua`) is a non-secure standalone frame with the shared Ka0s edge,
built on its first show; one ladder decides when it is on screen ([`data-flow.md`](data-flow.md)).

## Module Map

Ninety-one authored files load from the TOC, in the standard's folder order; every one, its kind,
its one-line responsibility and why its position is load-bearing or conventional is in
[`module-map.md`](module-map.md). In short:

- `locales/` and `core/`: the strings, the identity, one setup file per LibKa0s major, the compat
  family (its root `Compat.lua`, the only caller of version-variant, deprecated and optional client
  APIs and the GlobalString read, with its pure text parsers in `TextParse.lua`; the stable group,
  unit, instance and combat reads the simulator must also answer in `CompatWorld.lua`; the exact item reads at a
  bag location and the game tooltip's item setters in `CompatItem.lua`; no other file names those
  client globals), and the simulator's answer seam over it in `SimSeam.lua`, which wraps every
  member that answers for the client, the library-shaped item
  reads (`ItemRead.lua`: how complete a link is, the better of two, level and quality read the
  exact way; ui spec §0), the
  game-data tables (`Constants.lua`, `ClassData.lua`), the session state, the addon object and its
  lifecycle (`DropWatcher.lua`, which also holds the host handlers every surface shares), and the
  migration runner.
- `defaults/Profile.lua`: every default value (`NS.C`).
- `modules/`, the simulator's session first (`Sim.lua`: start, stop and its cleanup, the refusals,
  the automatic stop, the event delivery and the session-only history log; simulator spec §1, §5).
- `modules/`, the engine: six pure kernels (`Evaluate.lua` the verdict, `QualityGate.lua`,
  `TradeRules.lua` the trade estimate, `FeedFilter.lua` the feed's filters, `FeedRecords.lua` the
  feed's record logic, `Messaging.lua` the templates and the one-ask guard) and the
  scorers (`Scoring.lua`); the edges that read the client (`Situations.lua`, `Restrictions.lua`,
  `Roster.lua`, `ItemFacts.lua`, `Gear.lua`, `LootParser.lua`, `Inspect.lua`, `TradeTimer.lua`,
  `TradeHelper.lua`, `Asks.lua`); the feed that orchestrates them (`LootFeed.lua`, with
  `FeedCounts.lua` counting every receipt it hides or refuses by reason, and `GroupRoster.lua`
  keeping who was in each group: a snapshot taken by its first drop, grown by every later drop and
  by a roster change, copied into the History group, and named class-colored, you first, on the
  one `Group: ...` line of the headers' tooltips on all three tabs; feedback-2 spec §3, and since
  DW-B4 no longer in the header itself; `GroupPlace.lua` naming where each group dropped, its
  instance and the client's difficulty name (`Mythic+ <level>` for a key), captured when the group
  opens and kept on it and its History group, and the character that saw it, the only name a header
  shows; feedback-3 spec §4; and `CharFilter.lua`, the Character
  dropdown's recorder: every drop record and History entry says who saw it, `seenBy` (Name-Realm)
  and `seenByClass`, and the filter bar's Character dropdown, Current by default, filters History by
  it; feedback-2 spec §4); and the
  recorded and opt-in features (`History.lua`, with `HistoryRetention.lua` keeping it by days:
  Keep history for, confirmed before a shorter window deletes (only the latest pending choice is
  answered), pruned once per session, also when the addon is enabled later in a session that
  started disabled; feedback-2 spec §5, §8; `Toast.lua`, `AutoAsk.lua`).
- `modules/`, the simulator's inputs: its invented group and their gear (`SimRoster.lua`), its
  item pool, read from the Encounter Journal with your own gear as the fallback (`SimPool.lua`), the
  client answers about its world (`SimWorld.lua`: the group, the place, the inspect replies, your
  simulated bag items and the trade window), its event drivers (`SimEvents.lua`: loot lines,
  pulls and kills, a keystone run, combat, a completed trade; simulator spec §2, §3), where a loot
  burst's drops went (`SimReport.lua`: Group drops, My drops, or the gate that hid each, so the
  loot step reads `Loot: 2 drops (1 yours)` and reconciles with the tabs; feedback-3 spec §0; it
  honors `feed.showOwn` and the feed the window shows, `Window.FeedView`, §5) and its
  scenarios and timeline (`SimScenario.lua`: what `/dw sim start` builds and `run` and `step`
  play, with `pause`, `resume` and `restart`; simulator spec §4) and its step panel (`SimPanel.lua`:
  PerfPanel's look, the timeline as clickable steps, the run controls and the scenario picker,
  every click through the typed verb; sim feedback spec §1).
- `modules/`, the window: the shell (`Window.lua`), its title bar, filter bar and footer, compact
  mode's switch (`WindowCompact.lua`: two layouts, `full` and `compact`, over the one frame, each
  with its own size and point, compact 380 x 460 by default at the full window's top right and
  sized 320 to 520 wide; the title-bar toggle, the Layout row, `/dw compact` and `/dw full`; and the
  run override, `window.compactInRuns`, which opens an auto-open inside a dungeon, raid, key or
  delve compact until the run ends; compact spec §1, DW-C0), one body per tab
  (`WindowGroup.lua`, `WindowMine.lua`, `WindowHistory.lua`), the detail card and the Offer panel,
  their pure composers (`WindowCells.lua`, `DetailCells.lua`, `MineCells.lua`, and compact mode's
  `CompactCards.lua`: each card's three lines, tones and tooltips and the header's short form, over
  the same composers; compact spec §2-§3, DW-C1), compact mode's per-tab bodies (`CompactGroup.lua`:
  the Group drops tab's pooled three-line cards under one-line headers in the same pane, handed
  `WindowGroup`'s entries, the detail card stacked at the compact width; compact spec §2, DW-C2),
  the three tables'
  shared row height and text size (`WindowRows.lua`: `window.rowHeight` and `window.fontSize`,
  18-pixel rows and the template's own size by default, like Ka0s Loot History's table; a My drops
  row adds its countdown bar's room; feedback-2 spec §8, FB2-9), test mode
  (`TestData.lua`, its pure sample drops and History groups over real items from the simulator's
  item pool, and `TestMode.lua`, its edge; ui spec §4) and the diagnostics sections
  (`Diagnostics.lua`). Every tooltip raised from a table row (the item tooltip, every cell's
  reason, the Ask, Offer, Announce and Hide buttons, the dismiss mark and the group headers, on the
  three tabs and the Offer panel, and the item tooltip of the equipment columns, the detail card and
  the toast) has one placement, like Ka0s Loot History's `ANCHOR_RIGHT` on a full-width row: the
  tooltip's `BOTTOMLEFT` at the row's top, just outside the right edge of the frame the row sits
  in, or its `BOTTOMRIGHT` outside the left edge when the screen has no room on the right, measured
  after `Show()` at each frame's effective scale (`RowTooltip.lua`: `RowTooltip.Place`, which
  `Window.AttachTooltip`'s `row` placement and the item buttons share; feedback-3 spec §2, DW-B2,
  after DW-A2's beside-the-window placement). The row is the nearest ancestor marked `tipRow`; the
  frame is the nearest ancestor marked `tipHost` (the docked Offer panel), else the outermost one
  under UIParent (the window, the toast). While the Offer panel is docked beside the window, the two
  are one span: a tooltip goes beside the pair, never over the panel nor over the window
  (`tipDocked`; feedback-2 spec §8, FB2-10). My drops sits under the same collapsible group
  headers as the other two tabs, every group open until toggled (DW-A9). The tables' entries in
  order are `WindowCells.Entries` (pure); a Group drops header counts your own drops it leaves to
  My drops (`· 1 yours on My drops`), and the tab reads `My drops · n`, its tooltip naming how many
  you can still trade (feedback-3 spec §0, DW-B0). Both count only the drops My drops actually
  lists: not the ones hidden with Hide nor the ones its own filters hide (`WindowMine.Lists`,
  `Tally`, `ListedCount`, `ListsNow`), and the tab's tooltip names those it leaves out (feedback-3 spec §5, DW-B5). A filter-bar control's
  tooltip (View, Quality, Content, Character, the search box and the footer's Sort) opens above the
  control, never over it or its menu: its `BOTTOMLEFT` on the control's `TOPRIGHT`, or its
  `BOTTOMRIGHT` on the `TOPLEFT` when the screen has no room on the right (`Window.AttachTooltip`'s
  `above` placement, `Window.PlaceAbove`; feedback-3 spec §1, DW-B1). Near the top of the screen,
  with no room above, it opens below instead: its `TOPLEFT` on the control's `BOTTOMRIGHT`, else its
  `TOPRIGHT` on the `BOTTOMLEFT` (`Window.AboveFits`; feedback-3 spec §5, DW-B5).
- `settings/`: the schema seam and its rows, the options pages and their editors, the slash table,
  the slash-only verbs and `/dw sim`'s (`SimVerbs.lua`), and Profiles, last.

The window only listens: it reads the engine through read-only accessors and the bus, and every
button goes through the host handler its slash verb shares.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike, and one read, `NS.Setting(path)` (the stored value, or the row's default
before the database exists). The rows are `settings/Schema.lua`'s `Settings.Schema` array: the
composed Master controls rows (`settings/Panel.lua`), then every hand-written row of design spec
§12.1 (`settings/SchemaRows.lua`): General's `When to show` (master `autoOpen` and
`situations.<key>.track|autoOpen|quality`) and `Simulation` (`sim.stepDelay`, feedback-2 spec §8,
DW-A7), Feed (`feed.quality.*`, the filters and the filter bar's
seeds, the View set `feed.view.<value>` since DW-A1), Comparison (`comparison.*`), Trade (`trade.rules.<situation>`, `trade.warnAt`), Messages (`messages.*`), Window (`window.columns.<col>`, `window.mode`,
`window.compactInRuns`, `rowHeight`, `fontSize`, `toast.*`) and the account-wide `Keep history for`,
`global.history.retentionDays` (feedback-2 spec §5, DW-A5; it replaced the group cap).
Each row's `group` is its tab on its page (design spec §12.2; a page draws the rows whose `page` is
its key, `Settings.RowsForPage`), a row with nothing to do carries a `disabledIf` predicate that dims
it on the panel, its `default` references
`defaults/Profile.lua`, and its `validate` refuses a value outside its list or range before the
seam stores it. `comparison.weights` and `comparison.undesired` are whole-value `map` rows keyed by
specID (architecture-§5's value route: a membership change is a whole write through the seam),
drawn by their own editors (`skipRender`); the CLI shows them as their entry count. The reactions
every surface shares are `Settings.REACTIONS` (Master controls) and the window repaint on the
Columns, Layout and Quality rows. Paths `enabled` and `locked` are declared `writeThrough` so the
host verbs still land on a load where the composers are hollow (options-ui-§1 route (a)). The
global closure rows are the Minimap button (`global.minimap.shown`, onto LibDBIcon's `hide`) and
Keep history for (onto `global.history.retentionDays`, whose change to a shorter window asks before
it deletes anything, `modules/HistoryRetention.lua`; until the player answers, its onChange writes
the agreed window back, so an unanswered confirmation never leaves an unconfirmed window stored). Shape, defaults and migrations:
[`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**State written outside the seam** (architecture-§5): `profile.window.geometry.full` and
`.geometry.compact` (each `{ point, width, height }`, one per layout; compact spec §1, DW-C0) are
geometry only a drag or a resize sets, read and created through `NS.WindowCompact.Geometry` for the
layout in force. Their one owner is `modules/Window.lua`, and its writers
are `savePoint` (title-bar drag stop and the resize grip's release), `saveSize` (the resize grip's
release, saved together with the point) and
`Window.ResetPosition` (the Reset position button, which forgets both layouts' geometry,
`WindowCompact.ResetGeometry`, and the toast's and the simulation panel's points too); `profile.toast.point` is the
toast's position, written by `modules/Toast.lua` alone (a drag, allowed only in test mode, and
`Toast.ResetPosition`); `profile.simPanel.point` is the simulation panel's position, written by
`modules/SimPanel.lua` alone (its drag stop and `SimPanel.ResetPosition`), absent until the player
drags it, so the panel opens beside the window; `profile.window.minimized` is the minimize
button's remembered view, written by `Window.SetMinimized` alone. Every other setting the window and
the feed read is a row: the window's layout (`window.mode`, `NS.SetWindowMode` and
`NS.ToggleWindowMode`: the Window page's Layout row, the title-bar toggle, `/dw compact` and
`/dw full`; it replaced M3's compact preset, `window.compact`, which schema step 5 maps to it) and the filter bar's Quality control (`NS.SetQualityMode`, the Feed page's
row) both write through the seam. The filter bar's per-tab state is session-only
(`NS.State.windowFilters`), seeded from the `feed.view.<value>`, `feed.content` and `feed.sort`
rows when they hold a valid value. Its View is a set (DW-A1): the multi-select View dropdown's
values combine as AND, All is the empty set and the default, and each tab grays the values it does
not use (`FB.HONORS[tab].views`);
test mode sets the Group drops tab's View to All while it is on and puts the player's value back
when it ends (`modules/TestMode.lua`). The
Group drops table's collapsed groups, dismissed rows and the one expanded row (the detail card)
are session-only too (`NS.State.windowGroup`), and so are the My drops tab's hidden rows and the
upgrades whose candidates you chose to see and its collapsed groups (`NS.State.windowMine`) and the Offer panel's drop
(`NS.State.offerPanel`), and so are the History tab's collapsed groups (`NS.State.windowHistory`).
`global.notices.autoAsk` is auto-ask's one-time notice, set by `modules/AutoAsk.lua` alone the first
time the `messages.autoAsk.enabled` row turns on (its reaction), so the notice is said once per
account. `global.history.v` and `global.history.groups` are the history's own record, written by
`modules/History.lua` alone (on a recorded drop, an outcome, a completed trade, the safety ceiling
and Clear history), and by `modules/HistoryRetention.lua`, which deletes the groups older than Keep
history for (once per session, five seconds after the first `PLAYER_ENTERING_WORLD`, or after the
stand-up when the addon started disabled, and on a confirmed shorter window); neither replaces `global.history` whole, since the retention row's value
lives in it. While a simulation
runs, History writes a simulated drop (`sim = true`) and a simulated trade to the simulation's
session-only log instead (`NS.Sim.HistoryLog`, `modules/Sim.lua`), never `global.history`, and the
stop lets that log go (simulator spec §5). A drop or trade is simulated only when `Sim.Fire`
delivered the event that made it (`NS.Sim.IsDelivering`): a real loot line or trade that arrives
while a simulation runs is real, keeps the real situation and is saved (`History.LogFor`).
`global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. The load pass is `NS:RunMigrations`
(`core/Database.lua`), whose step 2 (`NS.RepairStoredSettings`) drops a stored value a row now
refuses, in every stored profile, and whose step 3 (`NS.MigrateViewSet`, DW-A1) turns the old
`feed.view` string and the three retired checkbox rows into the View set. No structural registry exists yet.

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_DropWatcher_<Event>` wire names with one
named sender each (design spec §3). With LibKa0s-Bus present the table is the strict `Catalog` copy,
so a mistyped key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` /
`NS.StandUp` take every tracked registration down and replay it. Without LibKa0s-Bus the seam degrades to an untracked
factory, and `NS.Bus.tracked` (the seam's one answer, false there) tells each receiving module to
unregister and re-register its own receivers in its stand-down and stand-up steps; no module
resolves the library itself.

All ten messages are sent today, `SITUATION_CHANGED`, `RESTRICTION_CHANGED`, `GEAR_CHANGED`,
`INSPECT_DONE`, `DROP_ADDED`, `DROP_UPDATED`, `TRADE_TIMER_TICK`, `TRADE_TIMER_EXPIRING`,
`ASK_STATE_CHANGED` and `HISTORY_CHANGED`; the history (`modules/History.lua`) receives `DROP_ADDED`,
`DROP_UPDATED` and `ASK_STATE_CHANGED`, the toast (`modules/Toast.lua`) the same three, auto-ask
(`modules/AutoAsk.lua`) those three, `HISTORY_CHANGED` and `RESTRICTION_CHANGED`, the History
tab (`modules/WindowHistory.lua`) `HISTORY_CHANGED`, the feed (`modules/LootFeed.lua`) receives `INSPECT_DONE`, `GEAR_CHANGED` and `TRADE_TIMER_TICK`,
the trade timer (`modules/TradeTimer.lua`) `DROP_ADDED`, the messaging edge (`modules/Asks.lua`)
`RESTRICTION_CHANGED`, and the window (`modules/Window.lua`) `RESTRICTION_CHANGED`,
`ASK_STATE_CHANGED`, `SITUATION_CHANGED`, `DROP_ADDED`, `DROP_UPDATED`, `GEAR_CHANGED` (since DW-83),
`INSPECT_DONE`, `TRADE_TIMER_TICK` and `TRADE_TIMER_EXPIRING`, each on its own tracked target; compact
mode's switch (`modules/WindowCompact.lua`) `SITUATION_CHANGED` on its own (DW-C0). The window only listens: it reads records through the engine's read-only
accessors and never calls an engine action; a button's action goes through the host handler its
slash verb shares (`NS.ScanGroup`, `NS.SetQualityMode`, `NS.PressAsk`, `NS.ToggleWindowMode`, and the
detail card's `NS.RetryInspect` and `NS.TradeWithLooter`, the row's × and the detail card's Hide
`NS.DismissDrop` (which also cancels the drop's automatic ask and forgets its toast), and the My drops tab's and the Offer
panel's `NS.PressOffer`, `NS.PressAnnounce`, `NS.GiveDrop` and `NS.PostTradeables`). Drops leaving a
feed are not a message: `LF.Clear` and the cap's trim call the feed's removal sinks
(`NS.LootFeed.AddRemovalSink`, the loot parser's `AddSink` shape), and the toast's sink lets a toast
go with its drop. The payloads and consumers below are the code's.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`. Sent once per drop, when it has passed every gate and been judged; a drop whose item is still loading is announced once it loads. `NS.LootFeed.Get(dropId)` is the record; test drops are announced too (`drop.feed` is `test`), test mode's placeholders (since DW-34, `AddTest`) one each as they are put in | TradeTimer (since DW-28): your own live drop asks for a bag scan; Window (since DW-30; the rule since DW-83, feedback spec §3 FB-12): every drop added to the feed the window shows (the live one, the simulator's included, or test mode's while it is on), your own included, opens a hidden window in a situation set to auto-open, with no once-per-situation latch (master `autoOpen` or the situation's `autoOpen` false turns it off); a minimized window stays minimized and counts it (`n new`); a test drop's open counts as test mode's, so `/dw test` off closes it again (DW-83 review); the frame is not protected, so it opens in combat too; and the open window repaints (the `My drops · n` count); History (since DW-51): records the live drop (never a test drop) in `global.history`, before the window repaints; Toast (since DW-52): queues the drop for a toast when it qualifies (each drop once; a test drop too, so test mode can place it); AutoAsk (since DW-54): schedules its automatic ask when it qualifies (each drop once) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`, `cause`: `source` (another source reported it; when its link was more complete the drop keeps it and is re-judged on the facts read from it, ui spec §0), `bag` (your own drop read from its matched bag item: its exact level and quality, and the bag item's link when more complete; since DW-80), `inspect` (the looter's or a candidate's read arrived), `gear` (your gear moved), `score` (a pending score retried) or `trade` (the trade estimate moved on the sweep or the trade timer: a drop past its window, your own drop's exact timer). Never for a test drop | Window (since DW-30): the open window repaints its tabs and the active tab's body (since DW-31 the Group drops rows: verdicts, trade, Their eq; since DW-32 the open detail card with them; since DW-33 the My drops rows and the open Offer panel's candidates); History (since DW-51): takes the recorded drop's latest verdicts and trade estimate, and `expired` once the estimate is `no expired`; since the DW-80 review also the more complete link and the level and quality read again (`source`, `bag`); Toast (since DW-52): a drop not toasted yet is considered again (an inspect can make its trade `likely`), and the toast on screen repaints its Ask; AutoAsk (since DW-54): a drop not scheduled yet is considered again |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (sent since DW-26) | `guid`. Sent once per job when it ends: after a read (`fresh` or `cached`), once the read items' facts have loaded or been given up on; at once for `outOfRange` and `failed`. `NS.Inspect.Get(guid)` says which | LootFeed (since DW-27): re-judges the drops that looter received and your own drops' candidate of that GUID; Window (since DW-30): the footer's inspect freshness |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (sent since DW-24) | none. Sent when a rebuild moved the snapshot (your class or spec, or any worn or owned item or its level), including the stand-up's rebuild; the first lazy read is silent | LootFeed (since DW-27): re-judges you on every drop; the quality gate's dynamic threshold reads the snapshot at the next drop; Window (since DW-83): repaints, so the Group drops table's My eq column shows the new snapshot |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (sent since DW-21) | `reason` (`encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown` or `combat`; nil when nothing the addon does is restricted), `canSendChat` (boolean). Sent when the reason or any of `CanSendChat`, `CanInspect`, `CanTrade` moves | Messaging edge (since DW-2A, `modules/Asks.lua`): `canSendChat` true starts a flush of the queued asks; Window (since DW-30): the restriction badge, shown while `reason` is not nil; Auto-ask (since the M6 review, `modules/AutoAsk.lua`): after a world event that came while the Encounter restriction held, its lifting ends the encounter hold |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (sent since DW-13) | `situationKey`, `previousKey` (nil on the first classification and after a stand-up) | Window (since DW-30): marks where "This instance" starts, and repaints the footer and the Quality label (until DW-83 it also re-armed the once-per-situation auto-open latch, which is gone). WindowCompact (since DW-C0): a situation off the one a run override began in ends the run, so the compact layout an auto-open forced lets go (at once while the window is hidden, else when it is next hidden). LootFeed reads `NS.Situations.Current()` at each receipt for its gate and subscribes to nothing |
| `ASK_STATE_CHANGED` | `AskStateChanged` | `modules/Asks.lua` (sent since DW-2A) | `dropId`, `state` (`queued`, `sent`, `failed`, or `ready` after a cancel), `kind` (`ask`, `offer` or `announce`), `target` (the Name-Realm, or `group` for an announce), `reason` (a failure's reason, or `canceled` / `left` after a cancel). Sent on every move of one ask; `NS.Asks.StateOf(kind, target, dropId)` reads it back | Window (since DW-30): the restriction badge's queued count, and (since DW-31) a repaint of the active tab, so each Group drops row's Ask button follows its ask, and (since DW-32) the open detail card's Ask and Edit message, and (since DW-33) the My drops rows' Announce and the Offer panel's Offer and Announce to group; History (since DW-51): `sent` makes the drop's outcome `asked` (an ask) or `offered` (an offer or announce); Toast (since DW-52): the toast on screen repaints its Ask button; AutoAsk (since DW-54): any move of a drop's `ask` cancels its waiting automatic ask (you asked yourself) |
| `TRADE_TIMER_TICK` | `TradeTimerTick` | `modules/TradeTimer.lua` (sent since DW-28) | none. Sent on every tick of the shared ticker (each second while the window is shown, each minute while it is hidden, never with nothing live) and after a scan that found your own drops or dropped the last entries; `NS.TradeTimer.ForDrop(dropId)` and `Remaining(entry)` are the countdown | LootFeed (since the DW-27 review): reads each own drop the timer matched from its bag item (since DW-80, `ReadBagItems`: `DropUpdated(id, "bag")` when its level, quality or link moved), then re-estimates your own drops' trade with the timer folded in; Window (since DW-33): repaints the My drops tab while it is active and the Offer panel while it is open, nothing else |
| `TRADE_TIMER_EXPIRING` | `TradeTimerExpiring` | `modules/TradeTimer.lua` (sent since DW-28) | `dropId`, `itemGUID`, `remaining` (seconds). Sent once per item, when its remaining time first falls to `trade.warnAt` (600s) or less; the module prints the chat warning itself, and the entry's `warned` is set | Window (since DW-33): one whole repaint, batched; the countdown reads `ending soon` in bold from its own clock, so a repaint carries it |
| `HISTORY_CHANGED` | `HistoryChanged` | `modules/History.lua` (sent since DW-51); `modules/TestMode.lua` (since DW-84) when its sample groups arrive or leave; `modules/HistoryRetention.lua` (since DW-A5) when Keep history for deletes groups | none. Sent when a drop is recorded, a refresh changes what its entry keeps (its verdicts, trade estimate, outcome, or its link, level and quality read again; a DropUpdated that changes none of them sends nothing), an outcome moves (an ask sent, declined set or cleared, a completed trade), Keep history for deletes groups (`modules/HistoryRetention.lua`, since DW-A5: the login prune or a confirmed shorter window), or Clear history empties it; `NS.History.Groups()` is the log | History tab (since DW-51, `modules/WindowHistory.lua`): the filter bar's cached History Character rows dropped (`WindowFilterBar.InvalidateChars`, since DW-A6), then one repaint of the shown window on the next frame through the window's own coalesced repaint (`Window.ScheduleRepaint`, shared with `DropUpdated`, so the two cost one pass), the Group drops rows included (a received drop's Ask button reads `Traded`); AutoAsk (since DW-54): a waiting automatic ask for a drop now `received` is canceled |

## Slash Commands

`/dw`, alias `/dropwatcher`. The reserved verbs (`help config enable disable version list get set
reset resetall profile debug diagnostics perf`) plus `lock`, `unlock`, `show`, `hide`, `toggle`,
`test` and the feature verbs of design spec §12.3 (`scan clear history mine compact situation offer
add`, plus compact spec §1's `full`); the full table, the live-while-disabled set and the handlers are in
[`slash-dispatch.md`](slash-dispatch.md). Every toggle verb calls the same handler as its Master
controls row and its launcher entry (`core/DropWatcher.lua`); `scan`, `compact` and `full` share the
window's own handlers, and the slash-only verbs are answered by `settings/SlashVerbs.lua`.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. Two
modules may declare the same event: AceEvent keeps one handler per event, so such an event is
registered once, on `DW:OnSharedFeatureEvent`, which calls each declared handler in row order (the
TOC order of the modules). `NS.FeatureEventNames()` is the declared list with each event once.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart`, then `DW.OnInspectCombatEvent`, then `DW.OnToastCombatStart` (through `DW:OnSharedFeatureEvent`) | ends test mode; re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then parks the inspect queue (`modules/Inspect.lua`); then, unless `toast.inCombat`, takes the toast on screen down and puts it back at the head of its queue (`modules/Toast.lua`) |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd`, then `DW.OnInspectCombatEvent`, then `DW.OnGearRegenEvent`, then `DW.OnToastCombatEnd` (the same) | re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then resumes the inspect queue; then arms the gear rebuild a bag event deferred in combat (`modules/Gear.lua`); then shows the toast combat held (`modules/Toast.lua`) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `DW.OnRestrictionEvent` | records the type's state as a hint and re-reads the restrictions (`modules/Restrictions.lua`); sends `RestrictionChanged` on a change |
| `PLAYER_ENTERING_WORLD` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnInspectWorldEvent`, then `DW.OnRetentionWorldEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | ends a running simulation when the real client is now inside an instance or in a group (`modules/Sim.lua`, read past the seam); then re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change; then, inside an instance, arms the inspect warm-up (`modules/Inspect.lua`); then (since DW-A5) the first one of the session arms the History's prune by age five seconds later on a cancelable timer the stand-down takes back (`modules/HistoryRetention.lua`); then (since DW-62) ends auto-ask's encounter hold when no Encounter restriction is left in force, so a player who left mid-fight is not held for good, or, while it is still in force, lets its later lifting (`RestrictionChanged`) end the hold (`modules/AutoAsk.lua`) |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | the simulation's automatic stop and the situation, as above; then auto-ask's encounter hold, as above |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent`, then `DW.OnFeedRunStart` (through `DW:OnSharedFeatureEvent`) | the same (a keystone started); then opens the run's drop group (`modules/LootFeed.lua`) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent`, then `DW.OnFeedRunEnd`, then `DW.OnAskFlushEvent` (the same) | the same (a keystone ended); then keeps the run's group open 120 seconds for the chest; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`) |
| `GROUP_ROSTER_UPDATE` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnRosterEvent`, then `DW.OnInspectRosterEvent` (through `DW:OnSharedFeatureEvent`) | the simulation's automatic stop (joining a real group ends it); then the situation (solo and open-world group turn on it); then re-reads the group's members (`modules/Roster.lua`), and on a change its sinks grow the open group's roster and its History group's (`modules/GroupRoster.lua`); then drops the inspect entries of members who left and arms the inspect warm-up (`modules/Inspect.lua`); then `DW.OnAskRosterEvent` cancels the asks queued to members who left, and the queued announces once you are out of a group (`modules/Asks.lua`); then `DW.OnAutoAskRosterEvent` cancels the waiting automatic asks to looters who left (`modules/AutoAsk.lua`) |
| `PLAYER_DIFFICULTY_CHANGED` | `DW.OnSituationEvent` | the same |
| `TRANSMOG_COLLECTION_UPDATED` | `DW.OnTransmogCollectionUpdated` | re-reads whether each cached item's appearance is collected (`modules/ItemFacts.lua`) |
| `PLAYER_EQUIPMENT_CHANGED` | `DW.OnGearEvent` | arms the gear snapshot's throttled rebuild (`modules/Gear.lua`); sends `GearChanged` when it moved |
| `BAG_UPDATE_DELAYED` | `DW.OnGearEvent`, then `DW.OnTradeTimerEvent` (through `DW:OnSharedFeatureEvent`) | the same (a better item may have entered or left the bags), except in combat, where it is noted for the combat's end; a bag-only rebuild keeps the worn slots whose link stayed and reads no worn tooltip; then asks for the trade timer's scan of your own drops' bag items, at most one per 2 seconds (`modules/TradeTimer.lua`) |
| `PLAYER_SPECIALIZATION_CHANGED` | `DW.OnGearSpecEvent` | the same, for your own unit only (another member's spec change is ignored) |
| `CHAT_MSG_LOOT` | `DW.OnChatMsgLoot` | parses the line (`modules/LootParser.lua`), counts it, and hands a receipt to the feed's sink (`modules/LootFeed.lua`) |
| `INSPECT_READY` | `DW.OnInspectReadyEvent` | reads the inspected member's slots and spec after 0.15s, for the job in flight or any other group member (`modules/Inspect.lua`); sends `InspectDone` when the job ends |
| `UNIT_INVENTORY_CHANGED` | `DW.OnInspectInventoryEvent` | marks a group member's inspect read stale and re-queues it as a warm-up job (`modules/Inspect.lua`) |
| `ENCOUNTER_START` | `DW.OnFeedEncounterStart`, then `DW.OnAutoAskEncounterStart` (through `DW:OnSharedFeatureEvent`) | the encounter in progress, which names the group of the drops that follow (`modules/LootFeed.lua`); then holds the waiting automatic asks until it ends (`modules/AutoAsk.lua`) |
| `ENCOUNTER_END` | `DW.OnFeedEncounterEnd`, then `DW.OnAskFlushEvent`, then `DW.OnAutoAskEncounterEnd` (through `DW:OnSharedFeatureEvent`) | a kill keeps the encounter's group open 120 seconds for its loot; a wipe closes it; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`); then makes every waiting automatic ask due its delay after now (`modules/AutoAsk.lua`) |
| `ENCOUNTER_LOOT_RECEIVED` | `DW.OnFeedEncounterLoot` | a drop reported by the encounter, with its encounter id; merged with the chat line of the same drop, the more complete of the two links kept (ui spec §0) |
| `LOOT_CLOSED` | `DW.OnTradeTimerEvent` | asks for the trade timer's scan: the items just looted are in the bags (`modules/TradeTimer.lua`) |
| `LOOT_HISTORY_UPDATE_DROP` | `DW.OnFeedLootHistory` | a group-loot drop, taken once it has a winner (`C_LootHistory` through `core/Compat.lua`); merged with the other reports, the most complete link kept |
| `TRADE_SHOW` | `DW.OnHistoryTradeShow` | a trade opened: its partner (`UnitName("NPC")`) and the window's items are read (`modules/History.lua`, through `core/Compat.lua`) |
| `TRADE_PLAYER_ITEM_CHANGED`, `TRADE_TARGET_ITEM_CHANGED` | `DW.OnHistoryTradeItems` | the items moved: re-read, and any both-accepted state is off |
| `TRADE_ACCEPT_UPDATE` | `DW.OnHistoryTradeAccept` | either side accepted: the items are read once more and kept as the offer, since they are gone by the end |
| `TRADE_CLOSED` | `DW.OnHistoryTradeClosed` | the window closed, completed or not: the trade waits `CLOSED_GRACE` (5) seconds for its "Trade complete."; alone it is a cancel or a failure and completes nothing. The client's second `TRADE_CLOSED` changes nothing |
| `EJ_LOOT_DATA_RECIEVED` (the client's spelling) | `DW.OnSimPoolLoot` | a journal entry loaded: every item-pool build waiting for its data (a simulation's, or test mode's since DW-84) reads the journal again once the burst settles (`modules/SimPool.lua`); with no build waiting it does nothing |
| `UI_INFO_MESSAGE` | `DW.OnHistoryInfoMessage` | the client's "Trade complete." (`Compat.IsTradeCompleteMessage`), before the close or within the grace after it, completes the trade: the offer's items you got mark the matching drops `received`, the items you gave your own `tradedAway`; sends `HistoryChanged`. Any other message, or no trade, returns at once |

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

The window and the toast are plain `Frame`s, never secure, so showing, hiding and moving them are
allowed in combat and nothing defers (the toast waits out combat by choice, `toast.inCombat`). Settings writes touch no protected frame. Opening the settings panel is refused
in combat by the options library, which also locks a page shown in combat; the addon adds no lock of
its own and never closes Blizzard's settings window (options-ui-§2). The trade actions
(`C_Container.PickupContainerItem`, `DropItemOnUnit`, `InitiateTrade`) and the chat sender are wrapped in
`core/Compat.lua` and guard nothing themselves: the trade helper (`modules/TradeHelper.lua`) and the
messaging edge (`modules/Asks.lua`) call them only from a click, or for a queued ask from the flush
timer, and check combat, range and restriction state first (design spec §4, §9). The chat sender
runs inside `pcall`, so a client refusal is a failed ask, never a Lua error; a whisper and a
PARTY, RAID or INSTANCE_CHAT message need no hardware event, so the timer may send them, and SAY
and YELL, which do, are never used. The trade helper reads `NS.Restrictions.CanTrade()` before the
trade range, because `CheckInteractDistance` is not to be called in combat, and never picks up an
item while the cursor holds another, so nothing of the player's is swapped away. The inspect broker (`modules/Inspect.lua`) watches `NotifyInspect` through
`hooksecurefunc` (in `core/Compat.lua`), never by replacing it; it never inspects in combat or while
Blizzard's inspect window is open, and calls `ClearInspectPlayer` only for an inspect it started
and nobody took over, so another addon's or the player's inspect is never cleared under them.
While a simulation runs (`modules/Sim.lua`), the seam over `core/Compat.lua` (`core/SimSeam.lua`)
keeps the chat sender, the inspect calls, the trade actions and `ClearCursor` from the client
altogether: a send is printed with `[sim]`, a hand-over is printed, and nothing is inspected,
picked up or traded (simulator spec §5). The stop cancels every queued ask before it lifts its
simulated restrictions, so nothing it queued can reach the real sender. `Sim.Fire` calls each
handler under `pcall`, as the client's event dispatch isolates it, and the stop runs each cleanup
step under `pcall`, so one that raises never skips the rest nor the later stand-down steps; the
failure is a `SIM` debug line. While its combat edge is up, the simulator answers
`InCombatLockdown` and the player's combat flag `true` through the seam and never `false`, so a
caller that must not act in combat is never told it may (DW-90).
The addon's two confirmations, Clear history (`modules/WindowHistory.lua`) and Reset all settings
(`settings/Schema.lua`), set `preferredIndex = 3`, so neither shares a StaticPopup slot with
Blizzard's own dialogs (DW-62).

## Known Limitations

What the addon does not do yet, or cannot know without the client. How the code reads every case
the design leaves open, module by module, is in [`design-readings.md`](design-readings.md).

- **Unconfirmed in game.** Every in-game check in [`smoke-tests.md`](smoke-tests.md) is owed: none
  has a recorded client pass yet. The readings most at risk are whether `CHAT_MSG_LOOT` is readable
  mid-encounter (COMBAT-1), whether a whisper goes out during an encounter (ASK-4), the raid trade
  rule (TRADE-3, `personal` until confirmed) and whether the game counts the looter's bags as well
  as their worn gear (TRADE-4, worn gear only today).
- **Localized clients.** Loot lines and the trade-time sentence are read with the client's own
  GlobalStrings, but an upgrade track's tier comes from its enUS name until FEED-5 records the
  client's track ids, so a non-English client shows no track change (LOC-1).
- **Which source handed the bare link** in the owner's BUG-1 report (ui spec §0) is not proven
  offline: the headless reproduction shows that a first report without bonus data read the drop at
  its base level and quality, and the fix keeps the most complete link and reads your own drops from
  their bag item whatever the source. ITEM-3 and the `drops` diagnostics line record it in game.
- **A delve's tier** is not in its group header: the header names the difficulty as the client
  gives it (GetInstanceInfo's difficultyName, else GetDifficultyInfo's), and neither is known to
  name the tier, so a delve reads `Delves` (feedback-3 spec §4 names `a delve tier`). FEED-30 records
  what the client gives.
- **Tier tokens** are recognized, but the slot a token makes is not read, so the verdict for one is
  `unknown` until the tier-token follow-up (design spec §14).
- **Your gear** is a per-slot best, not a loadout planner: unique-equipped limits and a
  two-hander's claim on both hands are not weighed, and the reagent bag, the bank and the warband
  bank are not read.
- **A drop you traded away** is `tradedAway` in the history, but its My drops row reads as expired
  rather than `Traded to …`.
- **After a reload** the kept history takes no more ask or trade-estimate outcomes (drop ids
  restart each session); a completed trade still matches it by item id.
- **The trade-time warning** can arrive up to a minute late while the window is closed (the ticker
  slows to once a minute).
- **A keystone chest** has no `ENCOUNTER_END`, so auto-ask times its drops from the drop itself.
- **When to show** draws one block per situation rather than the design's grid of situations by
  setting: LibKa0s-Options has no grid composer for mixed controls. A LibKa0s issue asking for one
  is filed as [LibKa0s#50](https://github.com/tusharsaxena/LibKa0s/issues/50).
- **The Profiles page** builds only where AceDBOptions and AceConfigDialog resolve, which the
  headless mock does not model; PROFILE-1 is its in-game check.
- **The simulator** (milestone M7) runs end to end: `/dw sim start <scenario> [size]` builds the
  pool and the group, `run` and `step` play the scenario's timeline, and the `SIMULATION` title text, the footer's
  `Simulating` line, the `sim` diagnostics section and the `SIM` debug tag show it (DW-73). The
  timeline's steps are event drivers only; the engine computes every verdict, estimate and inspect.
  A key's bosses drop nothing: its loot comes with the completion, as the end-of-run chest's does.
  Since the owner's first run (DW-90, sim feedback §0) a run fills the window under the default
  filters in every scenario: the group wears the content's items 1 to 12 levels above it (so its
  drops are spare for their looters whatever you wear; the M7 band around your own level left a
  group naked of content you outgear, and nothing read as Interesting), each random burst has a
  line of yours and a member's plain loot line, a simulation tracks the situation it simulates
  whatever its row says (the delve and the open world are untracked by default), and every step
  prints its line. So a simulation does not exercise a situation's tracking switch.
- **A simulated member's spec** stays unknown: the inspect broker reads the spec after it has
  cleared its own inspect (its flight ends first), and the simulator lets the inspect data go on
  `ClearInspectPlayer`, as the client does. Whether the live client still answers
  `GetInspectSpecialization` after the clear is unconfirmed (SIM-4); the headless mock keeps it.
- **A simulated loot line** carries no `ENCOUNTER_LOOT_RECEIVED` or `C_LootHistory` twin, so the
  feed's de-duplication across sources is not exercised by a simulation (`test_feed` covers it).
- **The simulator's item pool** reads the newest Encounter Journal tier, which is the current
  season's on a live client; a season whose dungeons sit in older tiers is read only as far as the
  newest tier lists them. Its difficulty ids are the journal's (Mythic Keystone 8 for a key); an
  instance without one of its side's difficulties repeats another difficulty's links, which the pool
  de-duplicates. A pool built with `loot for me` lists your class's items only, so members of
  another armor type draw fewer slots from it.
- **The logo** is a placeholder generated for the scaffold; the owner may replace the art
  (regenerate the TGAs with the recipe in `DEPENDENCIES.md`).


## Documentation map

Every `.md` under `docs/` appears in exactly one table below. Out of scope and named once each as
directories, never row by row: `docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/perf-analysis/<run>/`, `docs/revendor/<date>-v<tag>/`, `docs/superpowers/` (the research
bundle, the design spec and the checkpointed plan) and `docs/investigations/`.

### Required (documentation-§3, Tier 1)

| Doc | Covers |
|---|---|
| `scope.md` | What the addon is for, what exists at this version, and what it deliberately does not do |
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC load order |
| `schema.md` | The SavedVariables shape, every default, and the migration path |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree |
| `data-flow.md` | The loot pipeline end to end, then each stage: a setting written, the show decision, the repaints, the feed, inspecting, the trade timer, the sends, the history, the toast and auto-ask |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 28 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Present | `core/Compat.lua` carries the addon's own client-version workarounds (secret guards on tooltip and gate answers, the deprecated-global fallbacks, enums by name, the trade-time decode) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes 65 addon-specific shims (three or more), and its family adds the stable reads of `core/CompatWorld.lua` and `core/CompatItem.lua` |
| `message-bus.md` | Not applicable | 10 messages are defined, not more than ten |

### Verification and record (documentation-§3)

| Doc | Covers |
|---|---|
| `testing.md` | How to run the harness and lint; the green commit gate and the release gate |
| `smoke-tests.md` | The in-game smoke-test suite |
| `test-cases.md` | The generated case inventory (authoritative pass count) |
| `performance.md` | The addon performance page |
| `automated-tests/README.md` | What the automated-test record is and how to produce it |
| `automated-tests/RESULTS.md` | One row per run; generated by the runner, never hand-edited apart from the watch list's `Disposition` column (automated-tests-§4) |

### Addon-specific (documentation-§3, Tier 3)

| Doc | Covers |
|---|---|
| `design-readings.md` | How the code reads every case the design spec leaves open, module by module (spilled from Known Limitations) |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| library-stack-§7, anti-pattern #47 | The chat sender (`Compat.ChatSender`) and the tooltip line reader with its duration decoder (`Compat.ReadTooltipLine`, `DecodeDuration`, its parsing in `core/TextParse.lua`) are written in this addon, not taken from LibKa0s | No LibKa0s major carries them, and MultiMeters' `ChatSender` is the only other copy; the promotion bars (two consumers with the same semantics) are not met yet. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a major carrying either shape, or a second Ka0s addon needs the reader or the decoder |
| (no rule yet) chat sent by an addon | The addon whispers and posts to group chat on the player's behalf: an ask or offer whispered to one member, an announce to INSTANCE_CHAT, RAID or PARTY, each from a click or, when queued under a restriction, from the 1.5-second flush timer (`modules/Asks.lua`) | The standard has no rule for addon-sent chat. The addon holds itself to design spec §9: one send per click, the one-ask guard, the 255-byte limit, the restriction queue, `pcall` around the sender, never SAY or YELL, a confirmation line per send, and test mode printing instead. A WowAddonStandards proposal issue is filed as [WowAddonStandards#11](https://github.com/tusharsaxena/WowAddonStandards/issues/11) (design spec §14) | 2026-10-10 (design spec §2, §14) | The standard adopts a rule for addon-sent chat |
| library-stack-§7, anti-pattern #47 | The loot parser (`modules/LootParser.lua`: the `LOOT_ITEM*` GlobalStrings compiled into patterns for every looter, rebuilt when the globals change, the upgrade and crafting echoes rejected) is written in this addon, not taken from LibKa0s | No LibKa0s major parses loot lines. LootHistory carries the only other parser (`core/Util.lua`), and it reads the player's own loot only, so the semantics differ. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a loot-line major, or LootHistory needs third-person loot |
| library-stack-§7, anti-pattern #47 | The item read (`core/ItemRead.lua`: how complete a link is, the better of two links, an item's identity, the gear level read detailed-then-base, the exact level and quality at a bag location, the quality of a link) is written in this addon, shaped as the API LibKa0s-Item-1.0 would take, not taken from LibKa0s | LibKa0s-Item-1.0 carries identity primitives only (`ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem`). Loot History reads the same levels with its own `GetItemExtras` / `GearItemLevel`, and Bank Ledger resolves items too, so the read has three would-be adopters; the run builds in-addon first and promotes later (ui spec §0). A LibKa0s promotion issue is filed as [LibKa0s#51](https://github.com/tusharsaxena/LibKa0s/issues/51), with the loot-line parser as its second candidate | 2026-10-11 (ui spec §0) | LibKa0s-Item-1.0 ships these reads, or Loot History or Bank Ledger adopts them |
| library-stack-§7, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the restriction event's hints, the chat lockdown and the combat edges folded into `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`) is written in this addon, not taken from LibKa0s | No LibKa0s major tracks the 12.0 restrictions. AuraMaster and ConsumableMaster each react to `ADDON_RESTRICTION_STATE_CHANGED`, but to re-run their own work, not to answer what is allowed, so the semantics differ. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a restriction major, or a second Ka0s addon needs the same four answers |
| library-stack-§7, anti-pattern #47 | The simulation step panel (`modules/SimPanel.lua`) copies LibKa0s-Perf-1.0's step panel (`PerfPanel.lua`): its geometry, its three columns and its per-state colors. The frame is built from Core's skin and close mark (`NS.ApplySkin`, `NS.MakeCloseButton`) and the Widgets dropdown, but the row and state logic is this addon's | PerfPanel is attached to the Perf probe and drives only its fixed perf steps; it takes no host step list, so a simulator timeline cannot use it. The owner asked for its look exactly (sim feedback spec §1) | DW-91, 2026-10-11 | The LibKa0s step-panel issue ([LibKa0s#53](https://github.com/tusharsaxena/LibKa0s/issues/53)) lands a shared step panel: adopt it and delete the copy |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
