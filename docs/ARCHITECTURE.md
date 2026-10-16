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
LibKa0s v1.72.0 payload, of which fifteen majors are wired, one setup file each (`DEPENDENCIES.md`
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
| Lifecycle | `core/LifecycleSetup.lua` | the stand-down latch; `NS.StoodDownRefusal()`, the one stood-down refusal line (the dispatcher's under the `disabled` hold, `Not available during a performance capture.` under the `perf` hold alone) |
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

The authored files load from the TOC in the standard's folder order; every one, its kind, its
one-line responsibility and why its position is load-bearing or conventional is in
[`module-map.md`](module-map.md), the only inventory. In short:

- `locales/` and `core/`: the strings, the identity, one setup file per LibKa0s major, the compat
  family (`Compat.lua`, `CompatWorld.lua`, `CompatItem.lua`, the only files that name the client
  globals they wrap, with the pure parsers in `TextParse.lua`) and the simulator's answer seam over
  it (`SimSeam.lua`), the library-shaped item reads, the game-data tables, the session state, the
  addon object with its lifecycle and shared host handlers, and the migration runner.
- `defaults/Profile.lua`: every default value (`NS.C`).
- `modules/`: the simulator's session; the login session (`Session.lua`, the session start and This
  instance kept per character across a reload); the pure engine kernels and the scorers; the edges
  that read the client; the feed that orchestrates them, with its counts, rosters, places and
  recorders; the recorded and opt-in features (History, its retention and the feed rebuilt from it
  after a reload, `FeedRestore.lua`; the toast, auto-ask); the simulator's
  inputs, scenarios and step panel; then the window: its shell, chrome, two tabs, their strips' one
  footer button kind and Expand all / Collapse all (`FooterRow.lua`), pure cell composers, tooltip placement, compact mode's switch and bodies, test mode and the diagnostics.
- `settings/`: the schema seam and its rows, the options pages and their editors, the slash table,
  the slash-only and `/dw sim` verbs, and Profiles, last.

The window only listens: it reads the engine through read-only accessors and the bus, and every
button goes through the host handler its slash verb shares.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike, and one read, `NS.Setting(path)`. The rows are `settings/Schema.lua`'s
`Settings.Schema` array: the composed Master controls rows (`settings/Panel.lua`), then every
hand-written row of design spec §12.1 (`settings/SchemaRows.lua`). Each row's `group` is its tab on
its page, a `disabledIf` predicate dims a row with nothing to do, its `default` references
`defaults/Profile.lua`, and its `validate` refuses a value before the seam stores it. The two
specID-keyed tables are whole-value `map` rows (architecture-§5's value route).

State written outside the seam (architecture-§5) is named, each key with its one owner module and
every writer, in one place: the window's per-layout geometry and its minimized flag, the toast's and
the simulation panel's positions, auto-ask's one-time notice, the history's own record, the per-character session
(`char.session`, feedback-15 spec §0) and LibDBIcon's own write. The load pass is `NS:RunMigrations` (`core/Database.lua`, seven steps), and
no structural registry exists yet. The shape, every default, the named state with its writers, the
session-only state and each migration step are in [`schema.md`](schema.md).

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
detail card's `NS.RetryInspect` and `NS.TradeWithLooter`, the Offer
panel's `NS.PressOffer` and `NS.PressAnnounce`, and the Drops strip's `NS.PostTradeables`). Drops leaving a
feed are not a message: `LF.Clear` and the cap's trim call the feed's removal sinks
(`NS.LootFeed.AddRemovalSink`, the loot parser's `AddSink` shape), and the toast's sink lets a toast
go with its drop. The payloads and consumers below are the code's.

| `NS.MSG` key | Wire suffix | Sender | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`. Sent once per drop, when it has passed every gate and been judged; a drop whose item is still loading is announced once it loads. `NS.LootFeed.Get(dropId)` is the record; test drops are announced too (`drop.feed` is `test`), test mode's placeholders (since DW-34, `AddTest`) one each as they are put in; since DW-Q0 a drop of this session restored after a reload (`source` `restore`, `LootFeed.Restore`) too, linked to its History entry first | TradeTimer (since DW-28): your own live drop asks for a bag scan; Window (since DW-30; the rule since DW-83, feedback spec §3 FB-12): every drop added to the feed the window shows (the live one, the simulator's included, or test mode's while it is on), your own included, opens a hidden window in a situation set to auto-open, with no once-per-situation latch (master `autoOpen` or the situation's `autoOpen` false turns it off); a minimized window stays minimized and counts it (`n new`); a test drop's open counts as test mode's, so `/dw test` off closes it again (DW-83 review); the frame is not protected, so it opens in combat too; and the open window repaints; History (since DW-51): records the live drop (never a test drop) in `global.history`, before the window repaints (a restored drop is already linked to its entry, `History.Adopt`, so nothing is recorded); a restored drop opens no window, is not counted new on a minimized one, queues no toast and schedules no automatic ask (DW-Q0); Toast (since DW-52): queues the drop for a toast when it qualifies (each drop once; a test drop too, so test mode can place it); AutoAsk (since DW-54): schedules its automatic ask when it qualifies (each drop once) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`, `cause`: `source` (another source reported it; when its link was more complete the drop keeps it and is re-judged on the facts read from it, ui spec §0), `bag` (your own drop read from its matched bag item: its exact level and quality, and the bag item's link when more complete; since DW-80), `inspect` (the looter's or a candidate's read arrived), `gear` (your gear moved), `score` (a pending score retried) or `trade` (the trade estimate moved on the sweep or the trade timer: a drop past its window, your own drop's exact timer). Never for a test drop | Window (since DW-30): the open window repaints its tabs and the active tab's body (since DW-31 the Drops rows: verdicts, trade, the looter's gear (in Them since DW-F1), and since DW-E1 the Trade window; since DW-32 the open detail card with them; since DW-33 the open Offer panel's candidates); History (since DW-51): takes the recorded drop's latest verdicts and trade estimate, and `expired` once the estimate is `no expired`; since the DW-80 review also the more complete link and the level and quality read again (`source`, `bag`); Toast (since DW-52): a drop not toasted yet is considered again (an inspect can make its trade `likely`), and the toast on screen repaints its Ask; AutoAsk (since DW-54): a drop not scheduled yet is considered again |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (sent since DW-26) | `guid`. Sent once per job when it ends: after a read (`fresh` or `cached`), once the read items' facts have loaded or been given up on; at once for `outOfRange` and `failed`. `NS.Inspect.Get(guid)` says which | LootFeed (since DW-27): re-judges the drops that looter received and your own drops' candidate of that GUID; Window (since DW-30): the footer's inspect freshness |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (sent since DW-24) | none. Sent when a rebuild moved the snapshot (your class or spec, or any worn or owned item or its level), including the stand-up's rebuild; the first lazy read is silent | LootFeed (since DW-27): re-judges you on every drop; the quality gate's dynamic threshold reads the snapshot at the next drop; Window (since DW-83): repaints, so the Drops table's Me cells (My eq until DW-F1) show the new snapshot |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (sent since DW-21) | `reason` (`encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown` or `combat`; nil when nothing the addon does is restricted), `canSendChat` (boolean). Sent when the reason or any of `CanSendChat`, `CanInspect`, `CanTrade` moves | Messaging edge (since DW-2A, `modules/Asks.lua`): `canSendChat` true starts a flush of the queued asks; Window (since DW-30): the restriction badge, shown while `reason` is not nil; Auto-ask (since the M6 review, `modules/AutoAsk.lua`): after a world event that came while the Encounter restriction held, its lifting ends the encounter hold |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (sent since DW-13) | `situationKey`, `previousKey` (nil on the first classification and after a stand-up) | Window (since DW-30): marks where "This instance" starts (since DW-Q0 through `NS.Session.MarkSituation`, which keeps it across a reload in the same situation and instance), and repaints the footer and the Quality label (until DW-83 it also re-armed the once-per-situation auto-open latch, which is gone). WindowCompact (since DW-C0): a situation off the one a run override began in ends the run, so the compact layout an auto-open forced lets go (at once while the window is hidden, else when it is next hidden). LootFeed reads `NS.Situations.Current()` at each receipt for its gate and subscribes to nothing |
| `ASK_STATE_CHANGED` | `AskStateChanged` | `modules/Asks.lua` (sent since DW-2A) | `dropId`, `state` (`queued`, `sent`, `failed`, or `ready` after a cancel), `kind` (`ask`, `offer` or `announce`), `target` (the Name-Realm, or `group` for an announce), `reason` (a failure's reason, or `canceled` / `left` after a cancel). Sent on every move of one ask; `NS.Asks.StateOf(kind, target, dropId)` reads it back | Window (since DW-30): the restriction badge's queued count, and (since DW-31) a repaint of the active tab, so each Drops row's Ask or Offer button follows its ask, and (since DW-32) the open detail card's Ask and Edit message, and (since DW-33) the Offer panel's Offer and Announce to group; History (since DW-51): `sent` makes the drop's outcome `asked` (an ask) or `offered` (an offer or announce); Toast (since DW-52): the toast on screen repaints its Ask button; AutoAsk (since DW-54): any move of a drop's `ask` cancels its waiting automatic ask (you asked yourself) |
| `TRADE_TIMER_TICK` | `TradeTimerTick` | `modules/TradeTimer.lua` (sent since DW-28) | none. Sent on every tick of the shared ticker (each second while the window is shown, each minute while it is hidden, never with nothing live) and after a scan that found your own drops or dropped the last entries; `NS.TradeTimer.ForDrop(dropId)` and `Remaining(entry)` are the countdown | LootFeed (since the DW-27 review): reads each own drop the timer matched from its bag item (since DW-80, `ReadBagItems`: `DropUpdated(id, "bag")` when its level, quality or link moved), then re-estimates your own drops' trade with the timer folded in; Window (since DW-33; the Drops tab since DW-E1): repaints the Drops tab's countdowns alone (its Trade window cells, the compact cards' countdowns and the strip's next expiry, `WindowGroup.TickCountdowns`) while it shows a live one, and the Offer panel while it is open, nothing else |
| `TRADE_TIMER_EXPIRING` | `TradeTimerExpiring` | `modules/TradeTimer.lua` (sent since DW-28) | `dropId`, `itemGUID`, `remaining` (seconds). Sent once per item, when its remaining time first falls to `trade.warnAt` (600s) or less; the module prints the chat warning itself, and the entry's `warned` is set | Window (since DW-33): one whole repaint, batched; the countdown reads `ending soon` in bold from its own clock, so a repaint carries it |
| `HISTORY_CHANGED` | `HistoryChanged` | `modules/History.lua` (sent since DW-51); `modules/TestMode.lua` (since DW-84) when its sample groups arrive or leave; `modules/HistoryRetention.lua` (since DW-A5) when Keep history for deletes groups | none. Sent when a drop is recorded, a refresh changes what its entry keeps (its verdicts, trade estimate, outcome, or its link, level and quality read again; a DropUpdated that changes none of them sends nothing), an outcome moves (an ask sent, declined set or cleared, a completed trade), Keep history for deletes groups (`modules/HistoryRetention.lua`, since DW-A5: the login prune or a confirmed shorter window), or Clear history empties it; `NS.History.Groups()` is the log | History tab (since DW-51, `modules/WindowHistory.lua`): the filter bar's cached History Character rows dropped (`WindowFilterBar.InvalidateChars`, since DW-A6), then one repaint of the shown window on the next frame through the window's own coalesced repaint (`Window.ScheduleRepaint`, shared with `DropUpdated`, so the two cost one pass), the Drops rows included (a received drop's Ask button reads `Traded`); AutoAsk (since DW-54): a waiting automatic ask for a drop now `received` is canceled |

## Slash Commands

`/dw`, alias `/dropwatcher`. The reserved verbs (`help config enable disable version list get set
reset resetall profile debug diagnostics perf`) plus `lock`, `unlock`, `show`, `hide`, `toggle`,
`test` and the feature verbs of design spec §12.3 (`scan clear history mine compact situation offer
add`, plus compact spec §1's `full`; `mine` opens Drops since My drops was retired, feedback-5 spec §3); the full table, the live-while-disabled set and the handlers are in
[`slash-dispatch.md`](slash-dispatch.md). Every toggle verb calls the same handler as its Master
controls row and its launcher entry (`core/DropWatcher.lua`); `scan`, `compact` and `full` share the
window's own handlers, and the slash-only verbs are answered by `settings/SlashVerbs.lua`. A verb or
button refused while stood down prints `NS.StoodDownRefusal()`, so a perf capture never tells the
player to `/dw enable` an addon that is already enabled.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. Two
modules may declare the same event: AceEvent keeps one handler per event, so such an event is
registered once, on `DW:OnSharedFeatureEvent`, which calls each declared handler in row order (the
TOC order of the modules). Each handler runs under `pcall`, so one that raises never skips the
rest: its error is an `Init` debug line, and the first error is raised once every handler has run,
the way the client's own registrant dispatch and AceAddon's errorCollector behave. `NS.FeatureEventNames()` is the declared list with each event once.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart`, then `DW.OnInspectCombatEvent`, then `DW.OnToastCombatStart` (through `DW:OnSharedFeatureEvent`) | ends test mode; re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then parks the inspect queue (`modules/Inspect.lua`); then, unless `toast.inCombat`, takes the toast on screen down and puts it back at the head of its queue (`modules/Toast.lua`) |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd`, then `DW.OnInspectCombatEvent`, then `DW.OnGearRegenEvent`, then `DW.OnToastCombatEnd` (the same) | re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then resumes the inspect queue; then arms the gear rebuild a bag event deferred in combat (`modules/Gear.lua`); then shows the toast combat held (`modules/Toast.lua`) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `DW.OnRestrictionEvent` | records the type's state as a hint and re-reads the restrictions (`modules/Restrictions.lua`); sends `RestrictionChanged` on a change |
| `PLAYER_ENTERING_WORLD` | `DW.OnSimWorldEvent`, then `DW.OnSessionWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnInspectWorldEvent`, then `DW.OnRetentionWorldEvent`, then `DW.OnRestoreWorldEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | ends a running simulation when the real client is now inside an instance or in a group (`modules/Sim.lua`, read past the seam); then (since DW-Q0) an initial login starts the session now, a reload keeps it (`modules/Session.lua`, `char.session.start`); then re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change; then, inside an instance, arms the inspect warm-up (`modules/Inspect.lua`); then (since DW-A5) the first one of the session arms the History's prune by age five seconds later on a cancelable timer the stand-down takes back (`modules/HistoryRetention.lua`); then (since DW-Q0) the first one of a load that says `isReloadingUi` rebuilds the Drops tab from this session's History entries (`modules/FeedRestore.lua`); then (since DW-62) ends auto-ask's encounter hold when no Encounter restriction is left in force, so a player who left mid-fight is not held for good, or, while it is still in force, lets its later lifting (`RestrictionChanged`) end the hold (`modules/AutoAsk.lua`) |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | the simulation's automatic stop and the situation, as above; then auto-ask's encounter hold, as above |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent`, then `DW.OnFeedRunStart`, then `DW.OnCompactRunStart` (through `DW:OnSharedFeatureEvent`) | the same (a keystone started); then opens the run's drop group (`modules/LootFeed.lua`); then (since DW-C0) clears compact mode's completed-key latch and its grace timer (`modules/WindowCompact.lua`) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent`, then `DW.OnFeedRunEnd`, then `DW.OnAskFlushEvent`, then `DW.OnCompactRunEnd` (the same) | the same (a keystone ended); then keeps the run's group open 120 seconds for the chest; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`); then (since DW-C0) arms compact mode's grace timer: 120 seconds later the run override ends (a hidden window lets go at once, a shown one when next hidden) and the situation is latched, since a completed key still reads as mythicPlus until the player leaves (`modules/WindowCompact.lua`) |
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
its own and never closes Blizzard's settings window (options-ui-§2). The trade action
(`InitiateTrade`) and the chat sender are wrapped in
`core/Compat.lua` and guard nothing themselves: the trade helper (`modules/TradeHelper.lua`) and the
messaging edge (`modules/Asks.lua`) call them only from a click, or for a queued ask from the flush
timer, and check combat, range and restriction state first (design spec §4, §9). The chat sender
runs inside `pcall`, so a client refusal is a failed ask, never a Lua error; a whisper and a
PARTY, RAID or INSTANCE_CHAT message need no hardware event, so the timer may send them, and SAY
and YELL, which do, are never used. The trade helper reads `NS.Restrictions.CanTrade()` before the
trade range, because `CheckInteractDistance` is not to be called in combat. The inspect broker (`modules/Inspect.lua`) watches `NotifyInspect` through
`hooksecurefunc` (in `core/Compat.lua`), never by replacing it; it never inspects in combat or while
Blizzard's inspect window is open, and calls `ClearInspectPlayer` only for an inspect it started
and nobody took over, so another addon's or the player's inspect is never cleared under them.
While a simulation runs (`modules/Sim.lua`), the seam over `core/Compat.lua` (`core/SimSeam.lua`)
keeps the chat sender, the inspect calls and the trade action from the client
altogether: a send is printed with `[sim]`, a trade is printed, and nothing is inspected
or traded (simulator spec §5). The stop cancels every queued ask before it lifts its
simulated restrictions, so nothing it queued can reach the real sender. `Sim.Fire` calls each
handler under `pcall`, as the client's event dispatch and the live shared dispatcher
(`DW:OnSharedFeatureEvent`) isolate it, and the stop runs each cleanup
step under `pcall`, so one that raises never skips the rest nor the later stand-down steps; the
failure is a `SIM` debug line. While its combat edge is up, the simulator answers
`InCombatLockdown` and the player's combat flag `true` through the seam and never `false`, so a
caller that must not act in combat is never told it may (DW-90).
The addon's two confirmations, Clear history (`modules/WindowHistory.lua`) and Reset all settings
(`settings/Schema.lua`), set `preferredIndex = 3`, so neither shares a StaticPopup slot with
Blizzard's own dialogs (DW-62).

## Known Limitations

What the addon does not do yet, or cannot know without the client. In short: no in-game check has a
recorded client pass yet, so the encounter-time chat and loot readings and the raid trade rule are
unconfirmed; a non-English client shows no upgrade-track change; a delve's tier and a tier token's
slot are not read; your gear is a per-slot best, not a loadout planner; a reload brings the
session's drops back but starts a new key header mid-key, and a relog starts an empty Drops tab
(the session is the login); and a simulation does not exercise every live
path (a member's spec, cross-source de-duplication, a situation's tracking switch). Every limitation,
with its smoke-check id, is in [`known-limitations.md`](known-limitations.md).

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
| `slash-dispatch.md` | Present | 30 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Present | `core/Compat.lua` carries the addon's own client-version workarounds (secret guards on tooltip and gate answers, the deprecated-global fallbacks, enums by name, the trade-time decode) |
| `compat-layer.md` | Present | The compat family publishes 84 addon-specific shims (three or more), counted across the family per documentation-§3: `core/Compat.lua` 62, `core/CompatWorld.lua` 17, `core/CompatItem.lua` 5 (`cat core/Compat*.lua \| grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'`) |
| `message-bus.md` | Not applicable | 10 messages are defined, not more than ten |
| `known-limitations.md` | Present | Known Limitations passed roughly 60 lines in this hub and spilled there |
| `taint.md` | Not applicable | Taint Notes is under roughly 60 lines |

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
| `design-readings.md` | How the code reads every case the design spec leaves open, module by module (linked from `known-limitations.md`) |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| library-stack-§7, anti-pattern #47 | The chat sender (`Compat.ChatSender`) and the tooltip line reader with its duration decoder (`Compat.ReadTooltipLine`, `DecodeDuration`, its parsing in `core/TextParse.lua`) are written in this addon, not taken from LibKa0s | No LibKa0s major carries them, and MultiMeters' `ChatSender` is the only other copy; the promotion bars (two consumers with the same semantics) are not met yet. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major (v1.72.0 moves Perf.lua to minor 15 and the kit to revision 39 only) and LibKa0s#49 is still open, so the trigger has not fired | LibKa0s ships a major carrying either shape, or a second Ka0s addon needs the reader or the decoder |
| (no rule yet) chat sent by an addon | The addon whispers and posts to group chat on the player's behalf: an ask or offer whispered to one member, an announce to INSTANCE_CHAT, RAID or PARTY, each from a click or, when queued under a restriction, from the 1.5-second flush timer (`modules/Asks.lua`) | The standard has no rule for addon-sent chat. The addon holds itself to design spec §9: one send per click, the one-ask guard, the 255-byte limit, the restriction queue, `pcall` around the sender, never SAY or YELL, a confirmation line per send, and test mode printing instead. A WowAddonStandards proposal issue is filed as [WowAddonStandards#11](https://github.com/tusharsaxena/WowAddonStandards/issues/11) (design spec §14) | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): WowAddonStandards#11 is still open and the standard (v2.81.0 branch) has no addon-sent-chat rule, so the trigger has not fired | The standard adopts a rule for addon-sent chat |
| library-stack-§7, anti-pattern #47 | The loot parser (`modules/LootParser.lua`: the `LOOT_ITEM*` GlobalStrings compiled into patterns for every looter, rebuilt when the globals change, the upgrade and crafting echoes rejected) is written in this addon, not taken from LibKa0s | No LibKa0s major parses loot lines. LootHistory carries the only other parser (`core/Util.lua`), and it reads the player's own loot only, so the semantics differ. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major and LibKa0s#49 is still open, so the trigger has not fired | LibKa0s ships a loot-line major, or LootHistory needs third-person loot |
| library-stack-§7, anti-pattern #47 | The item read (`core/ItemRead.lua`: how complete a link is, the better of two links, an item's identity, the gear level read detailed-then-base, the exact level and quality at a bag location, the quality of a link) is written in this addon, shaped as the API LibKa0s-Item-1.0 would take, not taken from LibKa0s | LibKa0s-Item-1.0 carries identity primitives only (`ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem`). Loot History reads the same levels with its own `GetItemExtras` / `GearItemLevel`, and Bank Ledger resolves items too, so the read has three would-be adopters; the run builds in-addon first and promotes later (ui spec §0). A LibKa0s promotion issue is filed as [LibKa0s#51](https://github.com/tusharsaxena/LibKa0s/issues/51), with the loot-line parser as its second candidate | 2026-10-11 (ui spec §0). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): Item.lua stays at minor 2 and LibKa0s#51 is still open, so the trigger has not fired | LibKa0s-Item-1.0 ships these reads, or Loot History or Bank Ledger adopts them |
| library-stack-§7, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the restriction event's hints, the chat lockdown and the combat edges folded into `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`) is written in this addon, not taken from LibKa0s | No LibKa0s major tracks the 12.0 restrictions. AuraMaster and ConsumableMaster each react to `ADDON_RESTRICTION_STATE_CHANGED`, but to re-run their own work, not to answer what is allowed, so the semantics differ. A LibKa0s promotion issue is filed as [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major and LibKa0s#49 is still open, so the trigger has not fired | LibKa0s ships a restriction major, or a second Ka0s addon needs the same four answers |
| library-stack-§7, anti-pattern #47 | The simulation step panel (`modules/SimPanel.lua`) copies LibKa0s-Perf-1.0's step panel (`PerfPanel.lua`): its geometry, its three columns and its per-state colors. The frame is built from Core's skin and close mark (`NS.ApplySkin`, `NS.MakeCloseButton`) and the Widgets dropdown, but the row and state logic is this addon's | PerfPanel is attached to the Perf probe and drives only its fixed perf steps; it takes no host step list, so a simulator timeline cannot use it. The owner asked for its look exactly (sim feedback spec §1) | DW-91, 2026-10-11. Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): PerfPanel.lua stays at minor 6 and LibKa0s#53 is still open, so the trigger has not fired | The LibKa0s step-panel issue ([LibKa0s#53](https://github.com/tusharsaxena/LibKa0s/issues/53)) lands a shared step panel: adopt it and delete the copy |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
