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
LibKa0s v1.71.0 payload, of which fourteen majors are wired, one setup file each (`DEPENDENCIES.md`
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

The Widgets majors are vendored and not wired yet. Each setup file holds a
descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every stub to the live
surface.

The main window (`modules/Window.lua`) is a non-secure standalone frame with the shared Ka0s edge,
built on its first show; one ladder decides when it is on screen ([`data-flow.md`](data-flow.md)).

## Module Map

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, ten of the setup files, the compat seam (`Compat.lua`: the only caller of
version-variant, deprecated and optional client APIs, see [`compat-layer.md`](compat-layer.md)), the game-data tables (`Constants.lua` and
`ClassData.lua`, data plus pure lookups), the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values; `modules/` the verdict kernel
(`Evaluate.lua`, pure: plain tables in, a verdict out, no WoW call), the minimum-quality gate
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
tokens and sent through `Compat.ChatSender` inside `pcall` with one confirmation line, or queued
while chat is restricted and flushed one every 1.5 seconds when the restriction lifts, on
`ENCOUNTER_END` and on `CHALLENGE_MODE_COMPLETED`; a queued ask is canceled by a second click or
when its looter leaves; test mode prints instead of sending; it sends `AskStateChanged`), the window (which tells visibility listeners, the trade timer's ticker, on every show and hide) and the diagnostics sections; `settings/` the schema, the panel pages and the slash table. The design's feature modules
(spec §4) are added under `modules/` by the plan's later items.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike; the rows are `settings/Schema.lua`'s `Settings.Schema` array, today the
composed Master controls rows. The reactions every surface shares are `Settings.REACTIONS`. Paths
`enabled` and `locked` are declared `writeThrough` so the host verbs still land on a load where the
composers are hollow (options-ui-§1 route (a)). Shape, defaults and migrations:
[`schema.md`](schema.md); the panel: [`settings-panel.md`](settings-panel.md).

**State written outside the seam** (architecture-§5): `profile.window.point`, `.width` and `.height`
are geometry only a drag or a resize sets. Their one owner is `modules/Window.lua`, and its writers
are `savePoint` (title-bar drag stop and the resize grip's release), `saveSize` (the resize grip's
release, saved together with the point) and
`Window.ResetPosition` (the Reset position button). `global.minimap.minimapPos` is LibDBIcon's own
write into the table the launcher hands it. No structural registry exists yet.

## Message Bus

`core/Bus.lua` declares the catalog once, `NS.MSG`, as `Ka0s_DropWatcher_<Event>` wire names with one
named sender each (design spec §3). With LibKa0s-Bus present the table is the strict `Catalog` copy,
so a mistyped key raises. Receivers take their own `NS.Bus:NewTarget()`; `NS.StandDown` /
`NS.StandUp` take every tracked registration down and replay it.

Nine messages are sent today, `SITUATION_CHANGED`, `RESTRICTION_CHANGED`, `GEAR_CHANGED`,
`INSPECT_DONE`, `DROP_ADDED`, `DROP_UPDATED`, `TRADE_TIMER_TICK`, `TRADE_TIMER_EXPIRING` and
`ASK_STATE_CHANGED`; the feed (`modules/LootFeed.lua`) receives `INSPECT_DONE` and `GEAR_CHANGED`,
the trade timer (`modules/TradeTimer.lua`) `DROP_ADDED`, and the messaging edge (`modules/Asks.lua`)
`RESTRICTION_CHANGED`, each on its own tracked target. Every other sender module below is **planned**: it
does not exist until the item named in its row lands. The payloads and consumers are the design
intent. The item that first sends a message confirms its payload here, and each item that subscribes
adds itself as a consumer.

| `NS.MSG` key | Wire suffix | Sender (planned, item) | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`. Sent once per drop, when it has passed every gate and been judged; a drop whose item is still loading is announced once it loads. `NS.LootFeed.Get(dropId)` is the record; test drops are announced too (`drop.feed` is `test`) | TradeTimer (since DW-28): your own live drop asks for a bag scan; Window feed tabs (DW-30), Toast (DW-52), History (DW-51) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (sent since DW-27) | `dropId`, `cause`: `source` (another source reported it), `inspect` (the looter's or a candidate's read arrived), `gear` (your gear moved) or `score` (a pending score retried). Never for a test drop | Window feed tabs (DW-30), detail card (DW-32), Offer panel (DW-33) |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (sent since DW-26) | `guid`. Sent once per job when it ends: after a read (`fresh` or `cached`), once the read items' facts have loaded or been given up on; at once for `outOfRange` and `failed`. `NS.Inspect.Get(guid)` says which | LootFeed (since DW-27): re-judges the drops that looter received and your own drops' candidate of that GUID |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (sent since DW-24) | none. Sent when a rebuild moved the snapshot (your class or spec, or any worn or owned item or its level), including the stand-up's rebuild; the first lazy read is silent | LootFeed (since DW-27): re-judges you on every drop; the quality gate's dynamic threshold reads the snapshot at the next drop |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (sent since DW-21) | `reason` (`encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown` or `combat`; nil when nothing the addon does is restricted), `canSendChat` (boolean). Sent when the reason or any of `CanSendChat`, `CanInspect`, `CanTrade` moves | Messaging edge (since DW-2A, `modules/Asks.lua`): `canSendChat` true starts a flush of the queued asks; Window restriction badge (DW-30) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (sent since DW-13) | `situationKey`, `previousKey` (nil on the first classification and after a stand-up) | Window (DW-30): auto-open and the footer. LootFeed reads `NS.Situations.Current()` at each receipt for its gate and subscribes to nothing |
| `ASK_STATE_CHANGED` | `AskStateChanged` | `modules/Asks.lua` (sent since DW-2A) | `dropId`, `state` (`queued`, `sent`, `failed`, or `ready` after a cancel), `kind` (`ask`, `offer` or `announce`), `target` (the Name-Realm, or `group` for an announce), `reason` (a failure's reason, or `canceled` / `left` after a cancel). Sent on every move of one ask; `NS.Asks.StateOf(kind, target, dropId)` reads it back | Window feed tabs (DW-30), detail card (DW-32), Offer panel (DW-33), History (DW-51): the `asked` outcome |
| `TRADE_TIMER_TICK` | `TradeTimerTick` | `modules/TradeTimer.lua` (sent since DW-28) | none. Sent on every tick of the shared ticker (each second while the window is shown, each minute while it is hidden, never with nothing live) and after a scan that found your own drops or dropped the last entries; `NS.TradeTimer.ForDrop(dropId)` and `Remaining(entry)` are the countdown | My drops tab (DW-33), detail card (DW-32) |
| `TRADE_TIMER_EXPIRING` | `TradeTimerExpiring` | `modules/TradeTimer.lua` (sent since DW-28) | `dropId`, `itemGUID`, `remaining` (seconds). Sent once per item, when its remaining time first falls to `trade.warnAt` (600s) or less; the module prints the chat warning itself, and the entry's `warned` is set | My drops tab (DW-33): bold row |
| `HISTORY_CHANGED` | `HistoryChanged` | `modules/History.lua` (DW-51) | none | History tab (DW-51) |

## Slash Commands

`/dw`, alias `/dropwatcher`. The reserved verbs (`help config enable disable version list get set
reset resetall profile debug diagnostics perf`) plus `lock`, `unlock`, `show`, `hide`, `toggle` and
`test`; the full table, the live-while-disabled set and the handlers are in
[`slash-dispatch.md`](slash-dispatch.md). Every toggle verb calls the same handler as its Master
controls row and its launcher entry (`core/DropWatcher.lua`).

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through `NS.SafeRegisterEvent`,
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it. Two
modules may declare the same event: AceEvent keeps one handler per event, so such an event is
registered once, on `DW:OnSharedFeatureEvent`, which calls each declared handler in row order (the
TOC order of the modules). `NS.FeatureEventNames()` is the declared list with each event once.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart`, then `DW.OnInspectCombatEvent` (through `DW:OnSharedFeatureEvent`) | ends test mode; re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then parks the inspect queue (`modules/Inspect.lua`) |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd`, then `DW.OnInspectCombatEvent` (the same) | re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then resumes the inspect queue |
| `ADDON_RESTRICTION_STATE_CHANGED` | `DW.OnRestrictionEvent` | records the type's state as a hint and re-reads the restrictions (`modules/Restrictions.lua`); sends `RestrictionChanged` on a change |
| `PLAYER_ENTERING_WORLD` | `DW.OnSituationEvent`, then `DW.OnInspectWorldEvent` (through `DW:OnSharedFeatureEvent`) | re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change; then, inside an instance, arms the inspect warm-up (`modules/Inspect.lua`) |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSituationEvent` | the same |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent`, then `DW.OnFeedRunStart` (through `DW:OnSharedFeatureEvent`) | the same (a keystone started); then opens the run's drop group (`modules/LootFeed.lua`) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent`, then `DW.OnFeedRunEnd`, then `DW.OnAskFlushEvent` (the same) | the same (a keystone ended); then keeps the run's group open 120 seconds for the chest; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`) |
| `GROUP_ROSTER_UPDATE` | `DW.OnSituationEvent`, then `DW.OnRosterEvent`, then `DW.OnInspectRosterEvent` (through `DW:OnSharedFeatureEvent`) | the same (solo and open-world group turn on it); then re-reads the group's members (`modules/Roster.lua`); then drops the inspect entries of members who left and arms the inspect warm-up (`modules/Inspect.lua`); then `DW.OnAskRosterEvent` cancels the asks queued to members who left, and the queued announces once you are out of a group (`modules/Asks.lua`) |
| `PLAYER_DIFFICULTY_CHANGED` | `DW.OnSituationEvent` | the same |
| `TRANSMOG_COLLECTION_UPDATED` | `DW.OnTransmogCollectionUpdated` | re-reads whether each cached item's appearance is collected (`modules/ItemFacts.lua`) |
| `PLAYER_EQUIPMENT_CHANGED` | `DW.OnGearEvent` | arms the gear snapshot's throttled rebuild (`modules/Gear.lua`); sends `GearChanged` when it moved |
| `BAG_UPDATE_DELAYED` | `DW.OnGearEvent`, then `DW.OnTradeTimerEvent` (through `DW:OnSharedFeatureEvent`) | the same (a better item may have entered or left the bags); then asks for the trade timer's scan of your own drops' bag items, at most one per 2 seconds (`modules/TradeTimer.lua`) |
| `PLAYER_SPECIALIZATION_CHANGED` | `DW.OnGearSpecEvent` | the same, for your own unit only (another member's spec change is ignored) |
| `CHAT_MSG_LOOT` | `DW.OnChatMsgLoot` | parses the line (`modules/LootParser.lua`), counts it, and hands a receipt to every sink the feed adds (DW-27) |
| `INSPECT_READY` | `DW.OnInspectReadyEvent` | reads the inspected member's slots and spec after 0.15s, for the job in flight or any other group member (`modules/Inspect.lua`); sends `InspectDone` when the job ends |
| `UNIT_INVENTORY_CHANGED` | `DW.OnInspectInventoryEvent` | marks a group member's inspect read stale and re-queues it as a warm-up job (`modules/Inspect.lua`) |
| `ENCOUNTER_START` | `DW.OnFeedEncounterStart` | the encounter in progress, which names the group of the drops that follow (`modules/LootFeed.lua`) |
| `ENCOUNTER_END` | `DW.OnFeedEncounterEnd`, then `DW.OnAskFlushEvent` (through `DW:OnSharedFeatureEvent`) | a kill keeps the encounter's group open 120 seconds for its loot; a wipe closes it; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`) |
| `ENCOUNTER_LOOT_RECEIVED` | `DW.OnFeedEncounterLoot` | a drop reported by the encounter, with its encounter id; merged with the chat line of the same drop |
| `LOOT_CLOSED` | `DW.OnTradeTimerEvent` | asks for the trade timer's scan: the items just looted are in the bags (`modules/TradeTimer.lua`) |
| `LOOT_HISTORY_UPDATE_DROP` | `DW.OnFeedLootHistory` | a group-loot drop, taken once it has a winner (`C_LootHistory` through `core/Compat.lua`); merged with the other reports |

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

The window is a plain `Frame`, never secure, so showing, hiding and moving it are allowed in combat
and nothing defers. Settings writes touch no protected frame. Opening the settings panel is refused
in combat by the options library, which also locks a page shown in combat; the addon adds no lock of
its own and never closes Blizzard's settings window (options-ui-§2). The trade actions
(`PickupContainerItem`, `DropItemOnUnit`, `InitiateTrade`) and the chat sender are wrapped in
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

- v0.1.0 is the frame of the addon: the feed records and judges drops, but the window is empty
  apart from its test-mode banner until the feed tabs land (DW-30, DW-31), and asking and trading
  have no buttons until the My drops tab and the Offer panel land (DW-33): the messaging edge and
  the trade helper are reachable only from code ([`scope.md`](scope.md)).
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
  The per-situation settings have no rows until DW-40, so each situation takes its spec default.
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
  game also counts their bags is TRADE-4. The raid rule is `personal` until TRADE-3 confirms it, and
  the `trade.rules.<situation>` overrides have no row until DW-40.
- The messaging core (`modules/Messaging.lua`) reads five cases the design leaves open. A known
  token with no value reads `?` rather than an empty gap, and the preview lists it as missing;
  token names are case-sensitive, so `{Player}` is unknown and left as it is. A gain prints with
  one decimal at most. The length limit counts the raw bytes, so an item link counts whole. An
  ask that is queued, or handed to the sender and not yet reported, is never asked twice, even
  with `messages.oneAsk` off; a failed one may be retried, and a canceled one leaves the registry,
  so its button is ready again. The `messages.*` settings have no row until DW-40.
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
  registry is kept for the session. The `asked` history outcome is written by History (DW-51) from
  `AskStateChanged`, and the edit-first popup is the Offer panel's (DW-33), which passes the edited
  text in. Whether a whisper really is blocked during an encounter is ASK-4.
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
  The cache holds 512 links and is emptied whole when it would pass that; an item that has not
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
- The inspect broker (`modules/Inspect.lua`) reads eight cases the design leaves open. `fresh` is a
  read after an `INSPECT_READY` (ours or anyone's) and `cached` one taken at once because the
  client already held every link (the fast path, which needs at least one worn item and no
  incomplete slot); both are good for 600 seconds. `READY_ATTEMPTS` is two sends in all, so one
  retry. `CanInspect` answering false waits the range wait, as being out of range does; an
  offline member or a GUID with no unit waits the identity wait. A slot is incomplete when the
  client knows its item id but answers no link, or a nameless one; after three retries the read is
  kept, the slot left out and the entry's reason `incomplete`. A foreign `NotifyInspect` re-queues
  the job in flight at no cost in attempts, unless its data has already arrived. An
  `UNIT_INVENTORY_CHANGED` within five seconds of a read is taken for the inspect's own echo and
  ignored. The waits and the spacing are module constants (`NS.Inspect.SPACING` and its siblings):
  spec §12.1 has no `inspect` setting. The queue's priority is the caller's to give: the feed
  (DW-27) asks for looters and the Offer panel (DW-33) for its candidates; `Scan` has no slash verb
  or button until DW-42 and DW-30. Whether the fast path, the spec read and the tooltip level hold
  for an inspected unit in game is INSPECT-1..4.
- The feed (`modules/LootFeed.lua`) settles nine cases the design leaves open. Reports of one drop
  merge for 120 seconds (`NS.LootFeed.DEDUPE_WINDOW`) when the item id and the looter match (the
  GUID, or the name without its realm when a source has no GUID) and the source has not reported
  it already, so two copies from one source stay two drops. An encounter's group stays open 120
  seconds after a kill (`LOOT_GRACE`) and none after a wipe; a keystone run's group takes every
  drop until 120 seconds after it completes, the chest included (whether the chest's
  `ENCOUNTER_LOOT_RECEIVED` names an encounter is FEED-6). Your own `pushed` lines (quest rewards,
  containers, purchases) are not drops; a member's are. The relative minimum item level is measured
  against your average equipped level. A drop once shown stays shown: updates re-judge its verdicts
  and its trade, never its gates. Your own drop's candidates are inspected (at the Offer panel's
  priority) only while its trade estimate is not `no`. A pending score is retried five times, one
  second apart, on one shared timer, and a drop that used them up keeps its answer. Each feed keeps
  200 drops (`MAX_DROPS`), the oldest dropped first; the stand-down keeps the drops and drops the
  dedupe window, the encounter context and any item still loading. Until the settings rows land
  (DW-40) the feed reads `profile.feed`, `profile.comparison` and `profile.trade` when present and
  `C.FEED_DEFAULT` otherwise. `/dw add` and test mode reach it through `NS.LootFeed.Add` once their
  verbs land (DW-42, DW-34).
- The trade timer (`modules/TradeTimer.lua`) settles seven cases the design leaves open. A bag item
  is matched to one of your drops by its exact link first and its item id second, each drop taking
  one item, so two copies of one drop each keep their own timer; test drops are never timed. A
  matched item whose tooltip has no trade-time line is `no expired` at once, so an item whose
  tooltip has not loaded yet reads as expired until the next scan (a later bag event) reads the
  line. The tooltip shows whole minutes, so a re-read within a minute of the stored expiry keeps
  it and the countdown does not jump at each scan. An item that leaves the bags (traded, sold, equipped) drops its entry. The ticker runs
  only while an entry is live: each second while the window is shown, each minute while it is
  hidden, so the warning may come up to a minute late with the window closed. An item first read
  with less than `trade.warnAt` left warns at once; `trade.warnAt` 0 turns the warning off, and
  until its settings row lands (DW-40) it is read from `profile.trade.warnAt` when stored and
  `C.TRADE_WARN_AT` (600) otherwise. The stand-down keeps the entries, warned flags included, so
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
| `slash-dispatch.md` | Present | 20 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Present | `core/Compat.lua` carries the addon's own client-version workarounds (secret guards on tooltip and gate answers, the deprecated-global fallbacks, enums by name, the trade-time decode) |
| `compat-layer.md` | Present | `core/Compat.lua` publishes 46 addon-specific shims (three or more) |
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
