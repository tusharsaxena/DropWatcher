# Architecture — Ka0s Drop Watcher

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it is being built to is
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
the checkbox and search box still filter), and `NS.CloseMenu` is a no-op. Each setup file holds a
descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every stub to the live
surface.

The main window (`modules/Window.lua`) is a non-secure standalone frame with the shared Ka0s edge,
built on its first show; one ladder decides when it is on screen ([`data-flow.md`](data-flow.md)).

## Module Map

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, eleven of the setup files, the compat seam (`Compat.lua`: the only caller of
version-variant, deprecated and optional client APIs, see [`compat-layer.md`](compat-layer.md)), the game-data tables (`Constants.lua` and
`ClassData.lua`, data plus pure lookups), the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values; `modules/` the verdict kernel
(`Evaluate.lua`, pure: plain tables in, a verdict out, no WoW call), the scorers it takes
(`Scoring.lua`: the Pawn adapter through the Compat seam, your per-spec weights with the Pawn scale
string import, or none, chosen by `comparison.scorer` and Pawn's presence), the minimum-quality gate
(`QualityGate.lua`, pure: a drop's quality, the mode and the equipped qualities in, pass or hide
out), the situation classifier (`Situations.lua`: a pure classifier over the client's instance,
difficulty and group inputs, and the edge that reads them on six events), the trade estimator
(`TradeRules.lua`, pure: a drop's bind facts, the looter's verdict and the situation's rule in, a
yes, likely, unknown or no estimate out), the restriction tracker (`Restrictions.lua`: whether a
chat message, an inspect or a trade is allowed now, and the reason, from the restriction event, the
chat lockdown and the combat edges), the roster (`Roster.lua`: the group's members by GUID with
their Name-Realm, unit token, classFile, specID and online state, and the resolver from a name or a
GUID to a member), the item facts (`ItemFacts.lua`: a link turned into the facts the kernel
reads, cached by link, an uncached item loaded and retried through LibKa0s-Item's `LoadItem`), the
gear snapshot (`Gear.lua`: each slot you wear at its current level and the best item you own per
slot, bags included, rebuilt behind one throttle on the gear events, and the candidate table the
verdict kernel takes for you), the loot parser (`LootParser.lua`: a `CHAT_MSG_LOOT` line read with
the client's own `LOOT_ITEM*` GlobalStrings, rebuilt when another addon rewrites them, into the
looter, the item, the quantity and the kind, the upgrade and crafting echoes rejected), the inspect
broker (`Inspect.lua`: another member's worn gear and spec, read through one spaced `NotifyInspect`
at a time from a priority queue, with the range, identity and ready timeouts, the courtesy hook on
anyone's inspect, the combat park and a 600-second cache, and the candidate table the verdict kernel
takes for that member), the feed (`LootFeed.lua`: the orchestrator that takes each drop from chat,
the encounter loot event and the loot history, merges the reports of one drop, groups drops by
encounter or keystone run, applies the situation gate, the filters and the quality gate before any
inspect, judges each drop for you and for its looter, estimates its trade, judges every member for
your own drops, and sends `DropAdded` and `DropUpdated`), the trade timer (`TradeTimer.lua`: the
exact trade countdown on your own drops, each one's bag item read for its trade-time tooltip line at
most once per 2 seconds, keyed by item GUID, on one shared ticker that runs every second while the
window is shown, every minute while it is hidden and not at all with nothing live, with a warning
once per item at `trade.warnAt`; it sends `TradeTimerTick` and `TradeTimerExpiring`), the trade
helper (`TradeHelper.lua`: called only from a click, it hands one of your drops to a member, its bag
item found by GUID and dropped on them, or opens an empty trade, and refuses with a reason in combat,
out of range, for a stranger, yourself or an offline member, and for an item gone, expired or a busy
cursor; no events, no timers, no messages), the messaging core (`Messaging.lua`, pure: a
template and its tokens in, the text and the ask's next state out; it sends nothing), the messaging
edge (`Asks.lua`: an ask, offer or announce resolved to its recipient, expanded from the drop's
tokens (an ask with the template `NS.Messaging.AskTemplate` picks: the plain ask for a gain, or with
`messages.transmogAsk` on the For transmog ask for a drop whose look you have not collected) and
sent through `Compat.ChatSender` inside `pcall` with one confirmation line, or queued
while chat is restricted and flushed one every 1.5 seconds when the restriction lifts, on
`ENCOUNTER_END` and on `CHALLENGE_MODE_COMPLETED`; a queued ask is canceled by a second click or
when its looter leaves; test mode prints instead of sending; it sends `AskStateChanged`), the
history (`History.lua`: every live drop the feed shows, kept across sessions in the account's
`global.history`, grouped by feed group and session and capped at `global.history.maxGroups`
groups of 50 drops, each with its outcome: `seen`, `asked` or `offered` when an ask, offer or
announce is sent, `expired` when its trade window passes, `received` or `tradedAway` when a trade
completes with a matching item, and `declined` by hand; the trade is read from the trade window's
events; it sends `HistoryChanged`), the window shell (`Window.lua`:
the skinned frame with its title bar (logo, gold title, the restriction badge, Scan group,
minimize, close), the three tabs and their lazily built panes, minimize with its `n new` counter,
resize, position and `UISpecialFrames`, auto-open on the first interesting drop, and the show
decision; it repaints on the bus, batched into one pass on the next frame, and tells visibility listeners, the trade timer's ticker, on every
show and hide), the filter bar (`WindowFilterBar.lua`: View, Quality, Content, Likely tradeable
only and the search box, one state per tab, and the pure row predicates the tabs' bodies use), the
footer (`WindowFooter.lua`: a pure composer over inspect freshness, the last loot seen, the
situation and Pawn, and the tab's Sort), the drop tables' cells (`WindowCells.lua`, pure: a drop
record in, each column's text, verdict glyph, tone and reason tooltip out, for every verdict,
trade, inspect and ask state), the Group drops table (`WindowGroup.lua`: pooled rows under
collapsible encounter headers, the nine columns or the compact preset's five, real item buttons,
the Ask button and the dismiss mark, ordered and filtered by the tab's filter state; a row click
expands it inline into the detail card, one row at a time; with no drop at all, the empty state
with Preview with test data and Scan group), the detail card's words
(`DetailCells.lua`, pure: the item header's chips, the look's `New look` or `Look known` among them, the For you and For the looter comparisons, the
trade estimate box and the actions, each with its reason tooltip), the detail card itself
(`DetailCard.lua`: the frame edge that paints them under the open row, and the Edit message box
that fills the ask template in and sends the edited text), the My drops tab's and the Offer
panel's words (`MineCells.lua`, pure: your own drop's countdown, For me with `keep?`, the
candidates ranked with their status pills, the Offer, Announce and Trade buttons' looks, the
summary, Post my tradeables' lines cut at the chat limit, and where the panel docks), the My drops
tab (`WindowMine.lua`: your own drops in pooled rows with the countdown over its bar, Best
candidates, Offer… and Announce or a dash and Hide, and the summary strip with Post my
tradeables), the Offer panel (`OfferPanel.lua`: "Who could use this?", docked to the window's right
edge, each member with a class stripe, `eq → drop`, a status pill and Offer and Trade, and Announce
to group), the History tab (`WindowHistory.lua`: the kept groups under collapsible headers, read-only
rows in the Group drops style with an Outcome column, a right-click row menu that marks a drop
declined, and Clear history behind a confirmation), the toast (`Toast.lua`: opt-in, a drop someone
else looted that is an upgrade for you by at least `toast.minGain` item levels and likely or surely
tradeable, one at a time from a queue, gone after `toast.duration` seconds and paused while hovered,
held in combat unless `toast.inCombat`, with an Ask button and an optional sound; placed by a drag in
test mode, its position saved), auto-ask (`AutoAsk.lua`: opt-in, the same test with
`messages.autoAsk.minGain`; the ask is sent through the messaging edge `messages.autoAsk.delay`
seconds after the later of the drop and `ENCOUNTER_END`, held while an encounter is in progress, and
canceled when you ask yourself, the looter leaves, the row is dismissed, the item is received or it
is turned off; a one-time chat notice the first time it is turned on), test mode (`TestMode.lua`: placeholder drops in every verdict, trade, inspect and ask
state, put in the separate test feed through `NS.LootFeed.AddTest` when test mode turns on and
cleared when it ends; the window wears a `TEST MODE` chip and banner, and every send is printed)
and the diagnostics sections; `settings/` the schema (the seam in `Schema.lua`, every hand-written row of design spec §12.1 in `SchemaRows.lua`), the panel pages (the landing page and General in `Panel.lua`, Feed, Comparison, Trade, Messages and Window in `Pages.lua`, each a tab strip over its rows; the pages' own editors, the per-spec weights and unwanted types, the template editors with their counters, chips and preview, and the Quality tab's readout, in `PageEditors.lua` over the pure `Editors.lua`), Profiles, the slash table (`Slash.lua`) and the slash-only feature verbs' handlers (`SlashVerbs.lua`). The design's feature modules
(spec §4) are added under `modules/` by the plan's later items.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike, and one read, `NS.Setting(path)` (the stored value, or the row's default
before the database exists). The rows are `settings/Schema.lua`'s `Settings.Schema` array: the
composed Master controls rows (`settings/Panel.lua`), then every hand-written row of design spec
§12.1 (`settings/SchemaRows.lua`): General's `When to show` (master `autoOpen` and
`situations.<key>.track|autoOpen|quality`), Feed (`feed.quality.*`, the filters and the filter bar's
seeds), Comparison (`comparison.*`), Trade (`trade.rules.<situation>`, `trade.warnAt`,
`trade.likelyOnly`), Messages (`messages.*`), Window (`window.columns.<col>`, `window.compact`,
`rowHeight`, `fontSize`, `toast.*`) and the account-wide history cap `global.history.maxGroups`.
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
the history cap (onto `global.history.maxGroups`). Shape, defaults and migrations:
[`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**State written outside the seam** (architecture-§5): `profile.window.point`, `.width` and `.height`
are geometry only a drag or a resize sets. Their one owner is `modules/Window.lua`, and its writers
are `savePoint` (title-bar drag stop and the resize grip's release), `saveSize` (the resize grip's
release, saved together with the point) and
`Window.ResetPosition` (the Reset position button, which forgets the toast's point too); `profile.toast.point` is the
toast's position, written by `modules/Toast.lua` alone (a drag, allowed only in test mode, and
`Toast.ResetPosition`); `profile.window.minimized` is the minimize
button's remembered view, written by `Window.SetMinimized` alone. Every other setting the window and
the feed read is a row: the Group drops table's compact preset (`NS.SetCompact`, the Window page's
row and `/dw compact`) and the filter bar's Quality control (`NS.SetQualityMode`, the Feed page's
row) both write through the seam. The filter bar's per-tab state is session-only
(`NS.State.windowFilters`), seeded from the `feed.view`, `feed.content`, `feed.sort` and
`trade.likelyOnly` rows when they hold a valid value;
test mode sets the Group drops tab's View to All while it is on and puts the player's value back
when it ends (`modules/TestMode.lua`). The
Group drops table's collapsed groups, dismissed rows and the one expanded row (the detail card)
are session-only too (`NS.State.windowGroup`), and so are the My drops tab's hidden rows and the
upgrades whose candidates you chose to see (`NS.State.windowMine`) and the Offer panel's drop
(`NS.State.offerPanel`), and so are the History tab's collapsed groups (`NS.State.windowHistory`).
`global.notices.autoAsk` is auto-ask's one-time notice, set by `modules/AutoAsk.lua` alone the first
time the `messages.autoAsk.enabled` row turns on (its reaction), so the notice is said once per
account. `global.history.v` and `global.history.groups` are the history's own record, written by
`modules/History.lua` alone (on a recorded drop, an outcome, a completed trade, the cap and Clear
history); it never replaces `global.history` whole, since the cap row's value lives in it.
`global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. The load pass is `NS:RunMigrations`
(`core/Database.lua`), whose step 2 (`NS.RepairStoredSettings`) drops a stored value a row now
refuses, in every stored profile. No structural registry exists yet.

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
(`modules/AutoAsk.lua`) those three and `HISTORY_CHANGED`, the History
tab (`modules/WindowHistory.lua`) `HISTORY_CHANGED`, the feed (`modules/LootFeed.lua`) receives `INSPECT_DONE`, `GEAR_CHANGED` and `TRADE_TIMER_TICK`,
the trade timer (`modules/TradeTimer.lua`) `DROP_ADDED`, the messaging edge (`modules/Asks.lua`)
`RESTRICTION_CHANGED`, and the window (`modules/Window.lua`) `RESTRICTION_CHANGED`,
`ASK_STATE_CHANGED`, `SITUATION_CHANGED`, `DROP_ADDED`, `DROP_UPDATED`, `INSPECT_DONE`,
`TRADE_TIMER_TICK` and `TRADE_TIMER_EXPIRING`, each on its own tracked target. The window only listens: it reads records through the engine's read-only
accessors and never calls an engine action; a button's action goes through the host handler its
slash verb shares (`NS.ScanGroup`, `NS.SetQualityMode`, `NS.PressAsk`, `NS.SetCompact`, and the
detail card's `NS.RetryInspect` and `NS.TradeWithLooter`, the row's × and the detail card's Hide
`NS.DismissDrop` (which also cancels the drop's automatic ask), and the My drops tab's and the Offer
panel's `NS.PressOffer`, `NS.PressAnnounce`, `NS.GiveDrop` and `NS.PostTradeables`). Every other sender module below is **planned**: it
does not exist until the item named in its row lands. The payloads and consumers are the design
intent. The item that first sends a message confirms its payload here, and each item that subscribes
adds itself as a consumer.

| `NS.MSG` key | Wire suffix | Sender (planned, item) | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`. Sent once per drop, when it has passed every gate and been judged; a drop whose item is still loading is announced once it loads. `NS.LootFeed.Get(dropId)` is the record; test drops are announced too (`drop.feed` is `test`), test mode's placeholders (since DW-34, `AddTest`) one each as they are put in | TradeTimer (since DW-28): your own live drop asks for a bag scan; Window (since DW-30): the first interesting live drop in an auto-open situation opens it, a minimized window counts it (`n new`), and the open window repaints (the `My drops · n` count); History (since DW-51): records the live drop (never a test drop) in `global.history`, before the window repaints; Toast (since DW-52): queues the drop for a toast when it qualifies (each drop once; a test drop too, so test mode can place it); AutoAsk (since DW-54): schedules its automatic ask when it qualifies (each drop once) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`, `cause`: `source` (another source reported it), `inspect` (the looter's or a candidate's read arrived), `gear` (your gear moved), `score` (a pending score retried) or `trade` (the trade estimate moved on the sweep or the trade timer: a drop past its window, your own drop's exact timer). Never for a test drop | Window (since DW-30): the open window repaints its tabs and the active tab's body (since DW-31 the Group drops rows: verdicts, trade, Their eq; since DW-32 the open detail card with them; since DW-33 the My drops rows and the open Offer panel's candidates); History (since DW-51): takes the recorded drop's latest verdicts and trade estimate, and `expired` once the estimate is `no expired`; Toast (since DW-52): a drop not toasted yet is considered again (an inspect can make its trade `likely`), and the toast on screen repaints its Ask; AutoAsk (since DW-54): a drop not scheduled yet is considered again |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (sent since DW-26) | `guid`. Sent once per job when it ends: after a read (`fresh` or `cached`), once the read items' facts have loaded or been given up on; at once for `outOfRange` and `failed`. `NS.Inspect.Get(guid)` says which | LootFeed (since DW-27): re-judges the drops that looter received and your own drops' candidate of that GUID; Window (since DW-30): the footer's inspect freshness |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (sent since DW-24) | none. Sent when a rebuild moved the snapshot (your class or spec, or any worn or owned item or its level), including the stand-up's rebuild; the first lazy read is silent | LootFeed (since DW-27): re-judges you on every drop; the quality gate's dynamic threshold reads the snapshot at the next drop |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (sent since DW-21) | `reason` (`encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown` or `combat`; nil when nothing the addon does is restricted), `canSendChat` (boolean). Sent when the reason or any of `CanSendChat`, `CanInspect`, `CanTrade` moves | Messaging edge (since DW-2A, `modules/Asks.lua`): `canSendChat` true starts a flush of the queued asks; Window (since DW-30): the restriction badge, shown while `reason` is not nil |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (sent since DW-13) | `situationKey`, `previousKey` (nil on the first classification and after a stand-up) | Window (since DW-30): re-arms auto-open for the new situation, marks where "This instance" starts, and repaints the footer and the Quality label. LootFeed reads `NS.Situations.Current()` at each receipt for its gate and subscribes to nothing |
| `ASK_STATE_CHANGED` | `AskStateChanged` | `modules/Asks.lua` (sent since DW-2A) | `dropId`, `state` (`queued`, `sent`, `failed`, or `ready` after a cancel), `kind` (`ask`, `offer` or `announce`), `target` (the Name-Realm, or `group` for an announce), `reason` (a failure's reason, or `canceled` / `left` after a cancel). Sent on every move of one ask; `NS.Asks.StateOf(kind, target, dropId)` reads it back | Window (since DW-30): the restriction badge's queued count, and (since DW-31) a repaint of the active tab, so each Group drops row's Ask button follows its ask, and (since DW-32) the open detail card's Ask and Edit message, and (since DW-33) the My drops rows' Announce and the Offer panel's Offer and Announce to group; History (since DW-51): `sent` makes the drop's outcome `asked` (an ask) or `offered` (an offer or announce); Toast (since DW-52): the toast on screen repaints its Ask button; AutoAsk (since DW-54): any move of a drop's `ask` cancels its waiting automatic ask (you asked yourself) |
| `TRADE_TIMER_TICK` | `TradeTimerTick` | `modules/TradeTimer.lua` (sent since DW-28) | none. Sent on every tick of the shared ticker (each second while the window is shown, each minute while it is hidden, never with nothing live) and after a scan that found your own drops or dropped the last entries; `NS.TradeTimer.ForDrop(dropId)` and `Remaining(entry)` are the countdown | LootFeed (since the DW-27 review): re-estimates your own drops' trade with the timer folded in; Window (since DW-33): repaints the My drops tab while it is active and the Offer panel while it is open, nothing else |
| `TRADE_TIMER_EXPIRING` | `TradeTimerExpiring` | `modules/TradeTimer.lua` (sent since DW-28) | `dropId`, `itemGUID`, `remaining` (seconds). Sent once per item, when its remaining time first falls to `trade.warnAt` (600s) or less; the module prints the chat warning itself, and the entry's `warned` is set | Window (since DW-33): one whole repaint, batched; the countdown reads `ending soon` in bold from its own clock, so a repaint carries it |
| `HISTORY_CHANGED` | `HistoryChanged` | `modules/History.lua` (sent since DW-51) | none. Sent when a drop is recorded or refreshed, an outcome moves (an ask sent, declined set or cleared, a completed trade), the cap trims the log, or Clear history empties it; `NS.History.Groups()` is the log | History tab (since DW-51, `modules/WindowHistory.lua`): one repaint of the shown window on the next frame, the Group drops rows included (a received drop's Ask button reads `Traded`); AutoAsk (since DW-54): a waiting automatic ask for a drop now `received` is canceled |

## Slash Commands

`/dw`, alias `/dropwatcher`. The reserved verbs (`help config enable disable version list get set
reset resetall profile debug diagnostics perf`) plus `lock`, `unlock`, `show`, `hide`, `toggle`,
`test` and the feature verbs of design spec §12.3 (`scan clear history mine compact situation offer
add`); the full table, the live-while-disabled set and the handlers are in
[`slash-dispatch.md`](slash-dispatch.md). Every toggle verb calls the same handler as its Master
controls row and its launcher entry (`core/DropWatcher.lua`); `scan` and `compact` share the window's
own handlers, and the slash-only verbs are answered by `settings/SlashVerbs.lua`.

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
| `PLAYER_ENTERING_WORLD` | `DW.OnSituationEvent`, then `DW.OnInspectWorldEvent` (through `DW:OnSharedFeatureEvent`) | re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change; then, inside an instance, arms the inspect warm-up (`modules/Inspect.lua`) |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSituationEvent` | the same |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent`, then `DW.OnFeedRunStart` (through `DW:OnSharedFeatureEvent`) | the same (a keystone started); then opens the run's drop group (`modules/LootFeed.lua`) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent`, then `DW.OnFeedRunEnd`, then `DW.OnAskFlushEvent` (the same) | the same (a keystone ended); then keeps the run's group open 120 seconds for the chest; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`) |
| `GROUP_ROSTER_UPDATE` | `DW.OnSituationEvent`, then `DW.OnRosterEvent`, then `DW.OnInspectRosterEvent` (through `DW:OnSharedFeatureEvent`) | the same (solo and open-world group turn on it); then re-reads the group's members (`modules/Roster.lua`); then drops the inspect entries of members who left and arms the inspect warm-up (`modules/Inspect.lua`); then `DW.OnAskRosterEvent` cancels the asks queued to members who left, and the queued announces once you are out of a group (`modules/Asks.lua`); then `DW.OnAutoAskRosterEvent` cancels the waiting automatic asks to looters who left (`modules/AutoAsk.lua`) |
| `PLAYER_DIFFICULTY_CHANGED` | `DW.OnSituationEvent` | the same |
| `TRANSMOG_COLLECTION_UPDATED` | `DW.OnTransmogCollectionUpdated` | re-reads whether each cached item's appearance is collected (`modules/ItemFacts.lua`) |
| `PLAYER_EQUIPMENT_CHANGED` | `DW.OnGearEvent` | arms the gear snapshot's throttled rebuild (`modules/Gear.lua`); sends `GearChanged` when it moved |
| `BAG_UPDATE_DELAYED` | `DW.OnGearEvent`, then `DW.OnTradeTimerEvent` (through `DW:OnSharedFeatureEvent`) | the same (a better item may have entered or left the bags), except in combat, where it is noted for the combat's end; a bag-only rebuild keeps the worn slots whose link stayed and reads no worn tooltip; then asks for the trade timer's scan of your own drops' bag items, at most one per 2 seconds (`modules/TradeTimer.lua`) |
| `PLAYER_SPECIALIZATION_CHANGED` | `DW.OnGearSpecEvent` | the same, for your own unit only (another member's spec change is ignored) |
| `CHAT_MSG_LOOT` | `DW.OnChatMsgLoot` | parses the line (`modules/LootParser.lua`), counts it, and hands a receipt to every sink the feed adds (DW-27) |
| `INSPECT_READY` | `DW.OnInspectReadyEvent` | reads the inspected member's slots and spec after 0.15s, for the job in flight or any other group member (`modules/Inspect.lua`); sends `InspectDone` when the job ends |
| `UNIT_INVENTORY_CHANGED` | `DW.OnInspectInventoryEvent` | marks a group member's inspect read stale and re-queues it as a warm-up job (`modules/Inspect.lua`) |
| `ENCOUNTER_START` | `DW.OnFeedEncounterStart`, then `DW.OnAutoAskEncounterStart` (through `DW:OnSharedFeatureEvent`) | the encounter in progress, which names the group of the drops that follow (`modules/LootFeed.lua`); then holds the waiting automatic asks until it ends (`modules/AutoAsk.lua`) |
| `ENCOUNTER_END` | `DW.OnFeedEncounterEnd`, then `DW.OnAskFlushEvent`, then `DW.OnAutoAskEncounterEnd` (through `DW:OnSharedFeatureEvent`) | a kill keeps the encounter's group open 120 seconds for its loot; a wipe closes it; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`); then makes every waiting automatic ask due its delay after now (`modules/AutoAsk.lua`) |
| `ENCOUNTER_LOOT_RECEIVED` | `DW.OnFeedEncounterLoot` | a drop reported by the encounter, with its encounter id; merged with the chat line of the same drop |
| `LOOT_CLOSED` | `DW.OnTradeTimerEvent` | asks for the trade timer's scan: the items just looted are in the bags (`modules/TradeTimer.lua`) |
| `LOOT_HISTORY_UPDATE_DROP` | `DW.OnFeedLootHistory` | a group-loot drop, taken once it has a winner (`C_LootHistory` through `core/Compat.lua`); merged with the other reports |
| `TRADE_SHOW` | `DW.OnHistoryTradeShow` | a trade opened: its partner (`UnitName("NPC")`) and the window's items are read (`modules/History.lua`, through `core/Compat.lua`) |
| `TRADE_PLAYER_ITEM_CHANGED`, `TRADE_TARGET_ITEM_CHANGED` | `DW.OnHistoryTradeItems` | the items moved: re-read, and any both-accepted state is off |
| `TRADE_ACCEPT_UPDATE` | `DW.OnHistoryTradeAccept` | both sides accepted: the items are read once more, since they are gone by the close |
| `TRADE_CLOSED` | `DW.OnHistoryTradeClosed` | after a both-accepted state the trade completed: the items you got mark the matching drops `received`, the items you gave your own `tradedAway`; sends `HistoryChanged`. The client's second `TRADE_CLOSED` finds nothing open |

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

## Known Limitations

- v0.1.0 is the frame of the addon: the feed records and judges drops, the window's shell (title
  bar, restriction badge, Scan group, tabs, filter bar, footer, minimize) is in, and so is the Group
  drops table with its Ask button (DW-31), its detail card (DW-32), and the My drops tab with the
  Offer panel (DW-33), the history with its History tab (DW-51), the toast (DW-52), the
  transmog-known flag with its opt-in For transmog ask (DW-53), and auto-ask (DW-54)
  ([`scope.md`](scope.md)).
- Every setting of design spec §12.1 has its row and default (DW-40), and every row has its reader:
  the last, `messages.autoAsk.*`, is auto-ask's (DW-54).
- Scoring (DW-50, `modules/Scoring.lua`) settles how it reads design spec §5.4. The adapter in use
  can differ from `comparison.scorer`: `auto` takes Pawn when it is **loaded** (ready or not yet
  initialized, which answers `pending` and is retried), else your weights when any spec has one,
  else none; `pawn` with Pawn absent is none, and `weights` with no weight set is none. The
  diagnostics' Scoring section prints both (`scorer=` and `inUse=`). For you, Pawn's "best visible
  scale" is the one with the highest `PercentUpgrade` for the drop, else your spec's scale when the
  drop upgrades nothing; the drop and its baseline are both valued on that scale
  (`PawnGetSingleValueFromItem`), so `scoreDelta` is a value difference, not Pawn's percent. For a
  looter it is `PawnFindScaleForSpec(classID, specID)`; with no scale for that spec there is no
  score (item level alone), not a pending one. The kernel hands every scorer the drop beside the
  item it values (`scorer(facts, candidate, drop)`). Weights are per spec and apply to anyone of
  that spec, a looter included; a spec without weights is not scored. The Pawn scale string import
  (the Weights tab's box) replaces the weights of the spec on screen, whatever `Class=` and `Spec=`
  the string carries; Pawn keys it does not score (`Dps`, `Armor`, the `Is*` and socket keys) are
  named in the chat line and left out, and a stored weight on a stat key it does not know counts 0,
  logged once per key under `SCORE`.
- The transmog-known flag (DW-53) settles how it reads design spec §4. Whether you have collected a
  drop's look is CanIMogIt's `PlayerKnowsTransmog` when that optional addon is loaded (the look
  known from any source; an item it calls not transmogable has no flag), else
  `C_TransmogCollection.PlayerHasTransmogByItemInfo`; every CanIMogIt call is in `pcall` and an answer
  that is not a boolean falls back to the client. The detail card's header shows `New look` or `Look
  known`; an item with no look (a ring, neck or trinket) or an unknown answer shows no chip. The For
  transmog ask is opt-in (`messages.transmogAsk`, off): with it on, the Ask button is also offered
  on a drop that is no gain for you (not an upgrade or a sidegrade) whose look is known to be
  missing (`false`, never `nil`), and not on one its looter can't trade. It is still an `ask`: the
  same one-ask key, history outcome and button, filled from `messages.templates.transmog`. A gain
  always takes the plain ask, the toast (upgrades only) never offers it and auto-ask (DW-54) never
  sends it. Whether your class can collect that look at all (its armor type) is not checked beyond
  what CanIMogIt's answer carries (TMOG-1).
- Five rows settle how they act. **`feed.clearOnBossKill`** empties the live feed at a kill's
  `ENCOUNTER_END` (never a wipe), before the boss's loot arrives, and repaints the window; queued
  asks keep their text and still flush. **`comparison.heirloomProtect`** (on by default) is yours
  alone: a drop whose baseline is an heirloom reads as a sidegrade for you (reason
  `heirloomProtected`), while the looter's verdict stays plain, so a real upgrade for them is never
  read as one they would give away. **`messages.editFirst`** routes every ask, offer and announce
  press through the Edit message box (the detail card's, now one box for all three kinds); the box's
  Send goes back through the same handler with the edited text, a press on a queued send still
  cancels it, a press with the window closed sends as it stands, and Post my tradeables never opens
  it (its lines are already cut to the chat limit). **`window.rowHeight`** and **`window.fontSize`**
  size the Group drops table's rows and their cells' text; the headers, the column labels, the
  buttons and the My drops tab keep their own.
- The history (DW-51, `modules/History.lua` and the History tab, `modules/WindowHistory.lua`)
  settles eight cases design spec §10 leaves open. **What is kept** is every live drop the feed
  shows (it passed the gates), never a test drop, never a hidden one, with its verdicts and trade
  estimate as last judged while it was in the feed; a group is one feed group of one session, so a
  boss killed again tomorrow is a new group. **Outcomes** move forward only (seen, then asked or
  offered, then expired, then received or traded away); an announce counts as `offered`; `declined`
  is the player's and an automatic move never undoes it, but a completed trade does. **Which entry**
  a live drop is lives in a session-only index, because drop ids restart each session, so after a
  reload the old entries take no more outcomes from asks or the trade estimate; a completed trade
  still matches them by item id. **A completed trade** is `TRADE_CLOSED` after a
  `TRADE_ACCEPT_UPDATE` with both sides accepted and no item moved since (an item change clears it);
  the items are read on every change and at the both-accepted update, since they are gone by the
  close. Whether the client sends that both-accepted update before a completion, rather than going
  straight to the close, is HIST-1. **The match** for an item you got is the newest drop of that
  item id that is someone else's and not yet received, the partner's own drop first; for an item you
  gave, your own drop of that id; one entry per item. **The cap** counts groups, oldest out first,
  and 50 drops per group; a lower cap trims at once. **The tab** opens on View: All and Content: All
  the first time each session (Content's This session and This instance then cut by time, and
  `n days ago` names an older group); it is read-only but for the row menu (right-click: Mark as
  declined or Clear declined, through the client's `MenuUtil`, or at once without it), and Clear
  history asks first (a StaticPopup), then empties the log on every character and keeps the cap.
  **Account-wide:** one log for all your characters, as the cap row says. That the log survives a
  reload and the row menu opens in game is HIST-2.
- The toast (DW-52, `modules/Toast.lua`) settles what design spec §11.5 leaves open. **The gain**
  is the item-level change for you (`me.ilvlDelta`), as the `toast.minGain` row says, whatever the
  scorer; your own drops never toast. **Once per drop:** a drop is considered on `DropAdded` and on
  each `DropUpdated` until it has toasted, so one whose trade turns `likely` after the looter's
  inspect still toasts. **The queue** keeps the newest five; a drop asked for meanwhile, gone from the
  feed or no longer qualifying is skipped when its turn comes. **Combat** holds the queue until
  `PLAYER_REGEN_ENABLED`, and a toast on screen when combat starts goes back to the head of the
  queue with its full duration. **The pause** keeps the seconds left while the pointer is over the
  toast or its buttons, and resumes with them (at least one). **Test mode**'s placeholders toast
  like live drops (with `toast.enabled` on); a test drop's toast has no countdown, so it stays to be
  dragged into place until it is closed or test mode ends. Only in test mode can it be dragged, and
  the Window's Reset position forgets its point too. **The sound** is SOUNDKIT's
  `UI_EPICLOOT_TOAST`, else `RAID_WARNING`, on the Master channel (`Compat.PlayAlertSound`). That it
  shows, pauses, places and sounds right in game is TOAST-1.
- Auto-ask (DW-54, `modules/AutoAsk.lua`) settles what design spec §9.4 leaves open. **What
  qualifies** is the toast's own test (`NS.Toast.Qualifies`) with `messages.autoAsk.minGain`: the
  item-level change for you, whatever the scorer, never your own drop, and an upgrade only, so it
  always fills the plain `ask` template, never the transmog one. **Once per drop:** a drop is
  considered on `DropAdded` and on each `DropUpdated` until it is scheduled, so one whose trade turns
  `likely` after the looter's inspect still qualifies; a drop scheduled, sent or canceled is never
  scheduled again that session. **Only new drops:** turned on, it counts only the drops the feed
  records from then on (all of a session's drops when it was on at login), so turning it on never
  whispers for the drops already in the table. A profile switch, copy or reset runs no row
  reaction, so `reloadProfile` (core/DropWatcher.lua) calls `NS.AutoAsk.OnProfileReloaded`: an
  incoming profile that turns it on counts from that moment the same way, one that turns it off
  cancels the waiting asks, and the one-time notice stays the row's alone. **The timing** is the delay after the later of the
  drop and the last `ENCOUNTER_END`; while an encounter is in progress (`ENCOUNTER_START` without
  its end) nothing is due, and the end makes every waiting ask due its delay after that moment. A
  drop that qualifies once its time has passed is asked at once. A keystone run has no
  `ENCOUNTER_END` for its chest, so its drops are timed from the drop. **The send** is checked again
  when due (on, in the feed, qualifying, never asked, not received, its looter in the group) and
  goes through the messaging edge's `Request`: guarded by the one-ask registry, queued while chat is
  restricted, confirmed in chat, never through the edit-first box; a refusal is logged under `MSG`,
  not said in chat. **Canceled** by any move of the drop's ask (a click on Ask, the toast's or the
  card's), a `GROUP_ROSTER_UPDATE` that leaves its looter out of the group, the row's × or the
  detail card's Hide (`NS.DismissDrop`), the history's `received`, turning it off, and the
  stand-down. **Test mode**'s placeholders qualify like live drops and are timed from when test mode
  put them in; their asks are printed, never sent. **The notice** is said once per account
  (`global.notices.autoAsk`), the first time the row turns on through the seam (the panel, `/dw
  set`); a profile switch or reset that turns it on says nothing. That it whispers in game after a
  boss kill, and holds off on each cancel, is ASK-8.
- The General page's `When to show` tab draws one block per situation (`Track`, `Auto-open`, then
  `Quality`, under the situation's name) rather than the design's grid of situations by setting:
  LibKa0s-Options has no composer for a grid of mixed controls (`ChoiceGrid` is one choice per row
  over one value list). A LibKa0s issue asking for one is filed at the end of the v1 run (DW-63).
- The My drops tab and the Offer panel (DW-33) settle nine cases the design leaves open. **The
  tab** lists every drop of yours in the tab's feed, a drop that cannot be traded included (a dash
  and Hide, board 04's last row); `My drops · n` counts only the tradeable ones, and Hide is
  session-only. **The countdown** is exact once the trade timer has read the item
  (`trade.expiresAt`); before that it is estimated from when the item dropped and the two-hour
  window and reads `~1:48:20`. It repaints on every `TradeTimerTick` (each second while a timer is
  live and the window shown) and on the footer's 5-second ticker, which is what moves an estimate.
  At `trade.warnAt` or less it reads `ending soon`, in bold and amber; the chat warning is the
  trade timer's. A bind-on-equip drop reads `No limit (BoE)`. **Best candidates** of an upgrade for
  you read `Hidden: an upgrade for you` until you open its Offer panel, which reveals them for the
  session (AskFlow B2); Offer… stands out (gold) when someone gains and it is not hidden. **The
  ranking** is upgrades by gain, then EQUAL, NO UPGRADE, CAN'T USE, a judged member whose replaced
  item was not read (UNAVAILABLE), CHECKING… and UNAVAILABLE, each tie by name; `eq → drop` reads
  `… → 305` while checking and `– → 305` when nothing it would replace was read. **Offer and Trade**
  are shown for an upgrade or an equal only; anyone else shows a dash with the reason. Trade is
  `NS.TradeHelper.Give` (the item placed in the trade), disabled with the helper's reason
  (combat, range, offline, not in bags, expired, busy cursor), read first through `CanGive`. **The
  panel** stays open across tabs, repaints with the window, closes with its close mark or when its
  drop is gone, and docks right, else left, else floats over the window's right half above its
  rows. **Announce** (a row's and the panel's Announce to group) is one announce per drop, as the
  messaging edge files it. **Post my tradeables** lists the tradeable drops of yours in the feed on
  show, whatever the tab's filter, prefixed `Up for trade, whisper me:`, cut at 255 bytes without
  splitting a link; each line is its own announce, filed under `post:<n>:<i>`, so every press posts
  again. **Not yet:** a drop of yours traded away is `tradedAway` in the history (DW-51), but its
  row does not say so (board 04's `Traded to Séta`): once the item leaves your bags the trade timer
  drops its entry and the row reads as expired.
- The Group drops table (DW-31) settles five cases the design leaves open. **Group order** is
  newest first (oldest first under Sort: Oldest), and a group the player never toggled is open
  when it is the first one shown and collapsed otherwise (board 01); the Sort orders the drops
  inside each group. The **header** names the group, its situation (the feed's groups carry no
  difficulty), its age and its count. The **compact preset** changes the columns only (Item and
  looter, Ilvl, Their eq, Me, Ask); the tab strip, the filter bar and the window's size stay as the
  player set them. **Their eq** shows both worn items for rings, trinkets and weapons (the hands
  the drop could go in), read from the looter's inspect entry. A **narrow window** sheds columns
  rather than clip them: while the fixed columns and the Item column's 150px do not fit the row,
  Slot goes first, then Looter, Their eq, Ilvl, Them, Trade and Me (My drops: Best candidates, Ilvl,
  For me, Trade window); Item and Actions never go, and the detail card (or the Offer panel) still
  says what a shed column would. The **Ask button** asks at once, or, with `messages.editFirst`
  on, opens the detail card's Edit message box first; it reads `Traded ✓` once the history
  records the drop received from a completed trade (DW-51), and the detail card's Ask with it.
- The detail card (DW-32) settles five cases the design leaves open. **Expansion** is session-only
  and follows the row: a row filtered out or folded under its header hides the card, and it comes
  back, still open, with the row; Hide this item dismisses the row and closes the card. **Trade** on
  someone else's drop opens an empty trade with the looter, so they can put the item in; it is off
  on your own drop (that is My drops' Offer, DW-33) and on a drop its looter can't trade, and
  otherwise follows the trade helper's guards (combat, range, offline, not in the group), its short
  reason on the button (`Trade · out of range`). **Retry inspect** is off while the looter's read is
  still good or already queued, since the broker would not inspect again, and queues them at the
  looter priority otherwise. **Stats** are the four secondary stats' change against the replaced
  item, the largest first; the primary stat, stamina, sockets and tertiary stats are the header's
  chips. The score line is labeled by the scorer in use (**Pawn**, **Weights**, or **Score** with
  none) and shows its change; without one it says why (not scored yet, or no scorer in use).
- The window shell (DW-30) settles four cases the design leaves open. **Interesting** (View) is the
  brainstorm's union (03_FEATURES F1, board 01 note 5): someone else's drop that is an upgrade for
  you, whatever its trade estimate, or one its looter has no use for (a downgrade, can't use or
  doesn't want) whose estimate is `yes` or `likely`; and your own drop whose estimate is `yes` or
  `likely`. **Own loot** stays out of Group drops unless `feed.showOwn` is on (design spec §6.3; it
  goes to My drops), and then neither auto-opens the window nor counts toward `n new`. **This instance** (Content) is the drops since
  the situation last changed (`SituationChanged`), so two dungeons of the same kind in a row, with
  no other situation between them, read as one. **Auto-open** fires once per situation, on the
  first interesting live drop, only while the window is closed; master `autoOpen` false
  turns it off. The **Quality** control writes `feed.quality.mode` through the write seam
  (`NS.SetQualityMode`), the row the Feed page shares.
- The class tables (`core/ClassData.lua`) are a fallback for a candidate whose spec is not known
  yet; an item's own spec list wins whenever it exists. Devourer Demon Hunter (spec 1480, from the
  client's trait-tree data) is recorded as an Intellect dual wielder that takes no held off hand,
  which is unconfirmed in game (FEED-7).
- The situation classifier (`modules/Situations.lua`) confirms a difficulty id with
  `GetDifficultyInfo` before trusting it, so a retired id falls back to the instance type (a party
  instance reads as `dungeon`). It reads three cases the design leaves open: an instance of a type
  the design does not name (a housing interior, say) is the open world (`solo` or
  `openWorldGroup`); the Mythic Keystone difficulty is `mythicPlus` even before
  `IsChallengeModeActive` turns true; and the delve and follower-dungeon inputs come from the
  difficulty id. The check lives in the module's edge today; `core/Compat.lua` (DW-20) may take it.
  The per-situation settings are the `situations.<key>.*` rows, read through `NS.Setting`.
- The verdict kernel (`modules/Evaluate.lua`) reads a few cases the design leaves open as
  follows. With the spec unknown, an item whose primary stat suits only some of the class's specs
  is `unknown`, not `ok`. With a score, the verdict follows spec §5.2 step 4 to the letter: only
  an ilvl and a score that agree in sign give that sign, so one inside its band and the other
  outside is a sidegrade (`scoreDisagrees`); the band is in item levels, so the score's band is 0.
  A candidate whose class is not known yet is `unknown` (`unknownClass`), even for a
  class-restricted item. The track delta orders tracks by a numeric `tier` from ItemFacts and
  falls back to the enUS track names, so a localized name with no tier leaves it unset. Bows
  (`INVTYPE_RANGED`) and guns, crossbows and wands (`INVTYPE_RANGEDRIGHT`) fill both hands, so the
  off-hand and one-hander plans compare against them as two-handers; a ranged drop compares like a
  two-hander for hunters and against the main hand for everyone else. A unique-equipped drop at
  its category's maximum compares against the lowest holder in its own slots when one of them
  holds the category, else the lowest holder anywhere.
- The minimum-quality gate (`modules/QualityGate.lua`) reads three cases the design leaves open.
  A drop whose quality cannot be read passes (`qualityUnknown`), so the feed never hides what it
  could not judge. With no baseline slot yet, `Dynamic per slot` takes the lowest quality across
  the drop's slot plan, and the floor when any of those slots is empty. A per-situation `quality`
  that names no mode (absent, `global` or unknown) means the global mode.
- The trade estimator (`modules/TradeRules.lua`) reads four cases the design leaves open. The
  looter check compares item levels (the evaluation's `ilvlDelta`), not the scored verdict, because
  the game's rule is item level; an equal item level is not an upgrade, a drop the looter cannot use
  is still judged on item level, and an empty slot on the looter is an upgrade for them. The trade
  window's expiry is checked after the bind and legacy checks and before the looter check, so a
  drop past its window is `no expired` whatever the looter's gear; a BoE never expires. BoE means
  `OnEquip` or `OnUse`, and the account binds count as warbound. An unknown situation takes the
  `personal` rule. The rule is item level against the looter's equipped gear only; whether the
  game also counts their bags is TRADE-4. The raid rule is `personal` until TRADE-3 confirms it; the
  `trade.rules.<situation>` rows default to the design's rule for each situation.
- The messaging core (`modules/Messaging.lua`) reads five cases the design leaves open. A known
  token with no value reads `?` rather than an empty gap, and the preview lists it as missing;
  token names are case-sensitive, so `{Player}` is unknown and left as it is. A gain prints with
  one decimal at most. The length limit counts the raw bytes, so an item link counts whole. An
  ask that is queued, or handed to the sender and not yet reported, is never asked twice, even
  with `messages.oneAsk` off; a failed one may be retried, and a canceled one leaves the registry,
  so its button is ready again. The `messages.*` settings are rows, read by the edge through
  `NS.Setting`.
- The messaging edge (`modules/Asks.lua`) reads six cases the design leaves open. Design spec §4
  puts the core and the edge in one file; they are two, so the core stays pure and its suite needs
  no client. An ask is refused before the core when its recipient is not in the group, is you, or
  is offline (`notInGroup`, `self`, `offline`); the registry files a whisper under the member's
  Name-Realm, and an announce under `group`, one per drop whatever the channel. A raise inside the
  sender is the failure's reason (a secret or empty one reads `error`); no sender is `noApi`, and an
  announce outside a group `noChannel`. The first queued ask goes at once when a flush starts and
  the rest every 1.5 seconds; a restriction back mid-flush stops it until the next trigger. Test
  mode, and a test drop, print the text instead of sending, mark the ask sent and never queue it.
  The stand-down drops the queued asks, because no trigger reaches them while down; the sent
  registry is kept for the session. The `asked` history outcome (`offered` for an offer or announce) is
  written by History (`modules/History.lua`) from `AskStateChanged`. The edit-first box is the detail card's Edit message (DW-32): it reads
  `Preview` (the template filled in, nothing sent or filed) and passes the edited text in; with
  `messages.editFirst` on, the Offer panel's Offer and Announce open it too. Whether a whisper really is blocked during an encounter is ASK-4.
- The restriction tracker (`modules/Restrictions.lua`) reads four cases the design leaves open.
  Chat is stopped by the Encounter, ChallengeMode, PvPMatch and Chat restriction types and by the
  chat lockdown; combat alone stops inspects and trades, not chat; the Map type, active for the
  whole of a dungeon, stops nothing; a type the client adds later is reported under its enum name
  and stops nothing. A type counts as active while the event's last word on it or the client's own
  answer says so, so a lift counts only once both agree. The badge's reason is the first in effect
  of encounter, challengeMode, pvpMatch, chat, chatLockdown, combat. Which types really stop a
  whisper is COMBAT-2.
- The roster (`modules/Roster.lua`) reads five cases the design leaves open. A bare name is the
  player's own realm's when that settles it, because chat names a same-realm player without a
  realm; the classFile narrows a same-name tie first; a tie neither settles resolves to nothing.
  Names and realms compare without case, and realms with spaces and hyphens dropped on both sides.
  A unit with a secret or missing GUID is left out, a secret name leaves the member reachable by
  GUID only, the client's `Unknown` placeholder counts as no name, and a secret online flag reads
  as online. A failed resolve re-reads the client once. In a raid the player's token is its
  `raidN`, with `isPlayer` set. The specID is written by the inspect broker (DW-26) through
  `SetSpec` and kept across re-reads while the GUID stays. Whether chat's realm spelling matches
  the normalized one is ROSTER-1.
- The item facts (`modules/ItemFacts.lua`) read six cases the design leaves open. A track's tier
  comes from its `trackStringID` through `C.TRACK_TIER_BY_STRING_ID`, which stays empty until
  FEED-5 records the client's ids, so today every tier comes from the enUS track name and a
  localized client leaves the track delta unset. A tier token is an item that names its classes
  and has no slot plan; which slot it makes is not read, so its verdict is `unknown` for the slot
  until the tier-token follow-up (spec §14). An item unique on its own takes `item:<itemID>` as
  its category. `warbound` is set for warbound and for warbound-until-equipped items alike, with
  `warboundUntilEquip` telling them apart. Rings, necks and trinkets carry no `transmogKnown`.
  The cache holds 512 links; when it would pass that, the least recently used quarter is dropped
  (`NS.ItemFacts.EVICT_SHARE`; a hit or a store marks a link used), so the gear read on every
  judgment stays and old drops go; an item that has not
  loaded after five `LoadItem` calls (about two seconds) is given up, with nil to every waiter, and
  the next request starts afresh. The bonus-roll flag is the loot line's, so the drop record (DW-27)
  carries it, not the cached facts. Whether `GetItemUpgradeInfo` answers for another player's link
  is FEED-5; the item readers' shapes are ITEM-1.
- The gear snapshot (`modules/Gear.lua`) reads five cases the design leaves open. "Best owned per
  slot" is a per-slot best, not a loadout planner: the slots fill in id order, each with the
  highest-level item that fits it and is not placed already, so a pair holds your best two and one
  item never fills two slots, but unique-equipped limits and a two-hander's claim on both hands are
  not weighed. A one-hander may fill the off hand only for a dual wielder, a two-hander only with
  Titan's Grip; with the spec unknown, the class answers when every spec agrees, else neither. Only
  the backpack and the four bags are read: not the reagent bag, the bank or the warband bank. A
  worn item's level is its tooltip's (scaling included), else its link's. A link the client has
  not cached leaves its slot out (unknown, not empty) until it arrives; an item given up on stays
  out until the next gear event. Whether the tooltip level matches the character sheet is GEAR-1.
- The loot parser (`modules/LootParser.lua`) has no consumer until the feed (DW-27) adds its sink;
  until then a parsed line shows only as a `PARSE` debug line and in the diagnostics `feed`
  section. It reads `CHAT_MSG_LOOT` alone: the encounter and loot-history events are the feed's.
  Roll lines ("selected Need", "won") are not receipts and are ignored, since the item arrives on
  its own receipt line. A looter the roster cannot place takes the event's twelfth argument as
  its GUID, which is assumed to be the looter's (FEED-1 confirms it). The `|4` and `|1` grammar
  tokens are not expanded in loot patterns; no `LOOT_ITEM*` string is known to carry one in the
  client languages the design names (LOC-1). Whether the line is readable, or arrives secret,
  mid-encounter is COMBAT-1; a secret line is counted and dropped.
- The inspect broker (`modules/Inspect.lua`) reads nine cases the design leaves open. `fresh` is a
  read after an `INSPECT_READY` (ours or anyone's) and `cached` one taken at once because the
  client already held every link (the fast path, which needs no incomplete slot and an item in each
  slot only inspect data shows: neck, both rings and both trinkets, `NS.Inspect.HIDDEN_SLOTS`);
  both are good for 600 seconds. A read after `INSPECT_READY` that finds no item at all, or whose
  unit token no longer names the GUID, is no data (the inspect was cleared before the read, by
  Blizzard's inspect window or another addon): it is retried like an incomplete one, then never
  stored; the job in flight is re-queued like a timeout (`failed (empty)` once its sends are used),
  and an unasked read is dropped with the entry left as it was. `READY_ATTEMPTS` is two sends in all, so one
  retry. `CanInspect` answering false waits the range wait, as being out of range does; an
  offline member or a GUID with no unit waits the identity wait. A slot is incomplete when the
  client knows its item id but answers no link, or a nameless one; after three retries the read is
  kept, the slot left out and the entry's reason `incomplete`. A foreign `NotifyInspect` re-queues
  the job in flight at no cost in attempts, unless its data has already arrived. An
  `UNIT_INVENTORY_CHANGED` within five seconds of a read is taken for the inspect's own echo and
  ignored. The waits and the spacing are module constants (`NS.Inspect.SPACING` and its siblings):
  spec §12.1 has no `inspect` setting. The queue's priority is the caller's to give: the feed
  (DW-27) asks for looters and the Offer panel (DW-33) for its candidates; `Scan` is the window's
  Scan group button (DW-30, through `NS.ScanGroup`) and `/dw scan` (DW-42). Whether the fast path, the spec read and the tooltip level hold
  for an inspected unit in game is INSPECT-1..4.
- The feed (`modules/LootFeed.lua`) settles ten cases the design leaves open. Reports of one drop
  merge for 120 seconds (`NS.LootFeed.DEDUPE_WINDOW`) when the item id and the looter match (the
  GUID, or the name without its realm when a source has no GUID) and the source has not reported
  it already, so two copies from one source stay two drops. An encounter's group stays open 120
  seconds after a kill (`LOOT_GRACE`) and none after a wipe; a keystone run's group takes every
  drop until 120 seconds after it completes, the chest included (whether the chest's
  `ENCOUNTER_LOOT_RECEIVED` names an encounter is FEED-6). Your own `pushed` lines (quest rewards,
  containers, purchases) are not drops; a member's are. The relative minimum item level is measured
  against your average equipped level. A drop once shown stays shown: updates re-judge its verdicts
  and its trade, never its gates. Your own drop's candidates are inspected (at the Offer panel's
  priority) only while its trade estimate is not `no`, and asked for when it moves off `no`. The
  trade estimate is made again over time: one shared ticker every 30 seconds
  (`NS.LootFeed.TRADE_SWEEP`), alive while a group drop's trade is not `no`, turns a drop past its
  rule's window `no expired`, and each `TradeTimerTick` re-estimates your own drops, whose estimate
  folds in the trade timer (`LootFeed.FoldTimer`: `yes` with the `timer` basis and `expiresAt`
  while the countdown is live, `no expired` once it is gone; a bind answer and a BoE entry keep the
  rule's). A moved estimate sends `DropUpdated(id, "trade")`. A pending score is retried five times, one
  second apart, on one shared timer, and a drop that used them up keeps its answer. Each feed keeps
  200 drops (`MAX_DROPS`), the oldest dropped first; the stand-down keeps the drops and drops the
  dedupe window, the encounter context and any item still loading. The feed reads its settings,
  the `feed.*`, `comparison.*` and `trade.rules.*` rows, through `NS.Setting` (`LootFeed.Config`).
  `/dw add` (DW-42) and `/dw offer` for a bag item the feed never saw reach it through `NS.LootFeed.Add`; `/dw clear` empties the live feed (`NS.LootFeed.Clear`).
- The trade timer (`modules/TradeTimer.lua`) settles eight cases the design leaves open. A bag item
  is matched to one of your drops by its exact link first and its item id second, each drop taking
  one item, so two copies of one drop each keep their own timer; test drops are never timed. A
  BoE drop (its item facts' bind in `C.TRADE_BOE_BIND`) never carries a trade-time line and has no
  window: its entry is `permanent`, never expired and never live, and the trade helper gives it. A
  matched bind-on-pickup item whose tooltip has no trade-time line is `no expired` at once, so an item whose
  tooltip has not loaded yet reads as expired until the next scan (a later bag event) reads the
  line. The tooltip shows whole minutes, so a re-read within a minute of the stored expiry keeps
  it and the countdown does not jump at each scan. An item that leaves the bags (traded, sold, equipped) drops its entry. The ticker runs
  only while an entry is live: each second while the window is shown, each minute while it is
  hidden, so the warning may come up to a minute late with the window closed. An item first read
  with less than `trade.warnAt` left warns at once; `trade.warnAt` 0 turns the warning off, and it
  is read through `NS.Setting` (600 by default). The stand-down keeps the entries, warned flags included, so
  enabling again never repeats a warning.
- The trade helper (`modules/TradeHelper.lua`) settles five cases the design leaves open. The target
  is a member's GUID, `Name-Realm` or bare name, resolved through the roster, so a stranger is
  refused (`noTarget`) rather than traded with. The item is found by the trade timer's entry for the
  drop, so a drop the timer has not matched is `notInBags` and one it read as `no expired` is
  `expired`, never attempted; the entry's last slot is tried first and a walk of the bags second, so
  an item moved since the last scan is still found. A busy cursor refuses (`cursorBusy`) instead of
  being cleared, and a pickup with no `DropItemOnUnit` to follow is put back with `ClearCursor`.
  `CanGive` and `CanTradeWith` run every guard without acting, for the buttons' disabled state and
  tooltip (`ReasonText`). Only the calls that act count towards the diagnostics line.
- The compat seam (`core/Compat.lua`) has its first caller in the restriction tracker; the other M2
  edge items wire the rest. Three of its
  readings are unconfirmed in game and owed as COMPAT-1..3: the enum member names it resolves, the
  shape of the trade-time and item-level tooltip lines (whether the `ItemLevel` line carries a
  numeric field), and that `PawnIsInitialized` is a boolean flag. A secret chat-lockdown or
  restriction answer reads as locked, a secret bind answer as not bound ([`midnight-quirks.md`](midnight-quirks.md)).
- The Profiles page builds only where AceDBOptions and AceConfigDialog resolve, which the headless
  mock does not model; PROFILE-1 is its in-game check.
- The logo is a placeholder generated for the scaffold; the owner may replace the art (regenerate
  the TGAs with the recipe in `DEPENDENCIES.md`).

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
| `data-flow.md` | How a setting, the show decision and the stand-down flow today, and the design's loot pipeline |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 28 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Present | `core/Compat.lua` carries the addon's own client-version workarounds (secret guards on tooltip and gate answers, the deprecated-global fallbacks, enums by name, the trade-time decode) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes 59 addon-specific shims (three or more) |
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

None.

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| library-stack-§7, anti-pattern #47 | The chat sender (`Compat.ChatSender`) and the tooltip line reader with its duration decoder (`Compat.ReadTooltipLine`, `DecodeDuration`) are written in this addon, not taken from LibKa0s | No LibKa0s major carries them, and MultiMeters' `ChatSender` is the only other copy; the promotion bars (two consumers with the same semantics) are not met yet. A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a major carrying either shape, or a second Ka0s addon needs the reader or the decoder |
| (no rule yet) chat sent by an addon | The addon whispers and posts to group chat on the player's behalf: an ask or offer whispered to one member, an announce to INSTANCE_CHAT, RAID or PARTY, each from a click or, when queued under a restriction, from the 1.5-second flush timer (`modules/Asks.lua`) | The standard has no rule for addon-sent chat. The addon holds itself to design spec §9: one send per click, the one-ask guard, the 255-byte limit, the restriction queue, `pcall` around the sender, never SAY or YELL, a confirmation line per send, and test mode printing instead. A WowAddonStandards proposal issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | The standard adopts a rule for addon-sent chat |
| library-stack-§7, anti-pattern #47 | The loot parser (`modules/LootParser.lua`: the `LOOT_ITEM*` GlobalStrings compiled into patterns for every looter, rebuilt when the globals change, the upgrade and crafting echoes rejected) is written in this addon, not taken from LibKa0s | No LibKa0s major parses loot lines. LootHistory carries the only other parser (`core/Util.lua`), and it reads the player's own loot only, so the semantics differ. A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a loot-line major, or LootHistory needs third-person loot |
| library-stack-§7, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the restriction event's hints, the chat lockdown and the combat edges folded into `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`) is written in this addon, not taken from LibKa0s | No LibKa0s major tracks the 12.0 restrictions. AuraMaster and ConsumableMaster each react to `ADDON_RESTRICTION_STATE_CHANGED`, but to re-run their own work, not to answer what is allowed, so the semantics differ. A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a restriction major, or a second Ka0s addon needs the same four answers |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
