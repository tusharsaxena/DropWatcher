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
looter, the item, the quantity and the kind, the upgrade and crafting echoes rejected), the messaging core (`Messaging.lua`, pure: a
template and its tokens in, the text and the ask's next state out; it sends nothing), the window and the diagnostics sections; `settings/` the schema, the panel pages and the slash table. The design's feature modules
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

Three messages are sent today, `SITUATION_CHANGED`, `RESTRICTION_CHANGED` and `GEAR_CHANGED`. Every other sender module below is **planned**: it
does not exist until the item named in its row lands. The payloads and consumers are the design
intent. The item that first sends a message confirms its payload here, and each item that subscribes
adds itself as a consumer.

| `NS.MSG` key | Wire suffix | Sender (planned, item) | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (DW-27) | `dropId` | Window feed tabs (DW-30), Toast (DW-52), History (DW-51) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (DW-27) | `dropId` | Window feed tabs (DW-30), detail card (DW-32), Offer panel (DW-33) |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (DW-26) | `guid` | LootFeed (DW-27): re-evaluate that candidate's drops |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (sent since DW-24) | none. Sent when a rebuild moved the snapshot (your class or spec, or any worn or owned item or its level), including the stand-up's rebuild; the first lazy read is silent | LootFeed (DW-27): re-evaluate; QualityGate's dynamic threshold (DW-12) |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (sent since DW-21) | `reason` (`encounter`, `challengeMode`, `pvpMatch`, `chat`, `chatLockdown` or `combat`; nil when nothing the addon does is restricted), `canSendChat` (boolean). Sent when the reason or any of `CanSendChat`, `CanInspect`, `CanTrade` moves | Messaging edge (DW-2A): flush the queue; Window restriction badge (DW-30) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (sent since DW-13) | `situationKey`, `previousKey` (nil on the first classification and after a stand-up) | LootFeed (DW-27): the situation gate; Window (DW-30): auto-open and the footer |
| `ASK_STATE_CHANGED` | `AskStateChanged` | `modules/Messaging.lua` (DW-2A) | `dropId`, `state` | Window feed tabs (DW-30), detail card (DW-32) |
| `TRADE_TIMER_TICK` | `TradeTimerTick` | `modules/TradeTimer.lua` (DW-28) | none | My drops tab (DW-33), detail card (DW-32) |
| `TRADE_TIMER_EXPIRING` | `TradeTimerExpiring` | `modules/TradeTimer.lua` (DW-28) | `dropId` | My drops tab (DW-33): bold row; chat warning |
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
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart` | ends test mode; re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua` |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd` | re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua` |
| `ADDON_RESTRICTION_STATE_CHANGED` | `DW.OnRestrictionEvent` | records the type's state as a hint and re-reads the restrictions (`modules/Restrictions.lua`); sends `RestrictionChanged` on a change |
| `PLAYER_ENTERING_WORLD` | `DW.OnSituationEvent` | re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSituationEvent` | the same |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent` | the same (a keystone started) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent` | the same (a keystone ended) |
| `GROUP_ROSTER_UPDATE` | `DW.OnSituationEvent`, then `DW.OnRosterEvent` (through `DW:OnSharedFeatureEvent`) | the same (solo and open-world group turn on it); then re-reads the group's members (`modules/Roster.lua`) |
| `PLAYER_DIFFICULTY_CHANGED` | `DW.OnSituationEvent` | the same |
| `TRANSMOG_COLLECTION_UPDATED` | `DW.OnTransmogCollectionUpdated` | re-reads whether each cached item's appearance is collected (`modules/ItemFacts.lua`) |
| `PLAYER_EQUIPMENT_CHANGED` | `DW.OnGearEvent` | arms the gear snapshot's throttled rebuild (`modules/Gear.lua`); sends `GearChanged` when it moved |
| `BAG_UPDATE_DELAYED` | `DW.OnGearEvent` | the same (a better item may have entered or left the bags) |
| `PLAYER_SPECIALIZATION_CHANGED` | `DW.OnGearSpecEvent` | the same, for your own unit only (another member's spec change is ignored) |
| `CHAT_MSG_LOOT` | `DW.OnChatMsgLoot` | parses the line (`modules/LootParser.lua`), counts it, and hands a receipt to every sink the feed adds (DW-27) |

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

The window is a plain `Frame`, never secure, so showing, hiding and moving it are allowed in combat
and nothing defers. Settings writes touch no protected frame. Opening the settings panel is refused
in combat by the options library, which also locks a page shown in combat; the addon adds no lock of
its own and never closes Blizzard's settings window (options-ui-§2). The trade actions
(`PickupContainerItem`, `DropItemOnUnit`, `InitiateTrade`) and the chat sender are wrapped in
`core/Compat.lua` and guard nothing themselves: the planned trade helper (DW-29) and messaging edge
(DW-2A) call them only from a click, and check combat, range and restriction state first (design
spec §4, §9).

## Known Limitations

- v0.1.0 is the frame of the addon: the window is empty apart from its test-mode banner, and none
  of the loot features exist yet ([`scope.md`](scope.md)).
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
  so its button is ready again. Nothing sends yet: the edge (DW-2A) wires the restriction check,
  the send and the flush timer, and the `messages.*` settings have no row until DW-40.
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
| `compat-layer.md` | Present | `core/Compat.lua` publishes 36 addon-specific shims (three or more) |
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
| library-stack-§7, anti-pattern #47 | The loot parser (`modules/LootParser.lua`: the `LOOT_ITEM*` GlobalStrings compiled into patterns for every looter, rebuilt when the globals change, the upgrade and crafting echoes rejected) is written in this addon, not taken from LibKa0s | No LibKa0s major parses loot lines. LootHistory carries the only other parser (`core/Util.lua`), and it reads the player's own loot only, so the semantics differ. A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a loot-line major, or LootHistory needs third-person loot |
| library-stack-§7, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the restriction event's hints, the chat lockdown and the combat edges folded into `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`) is written in this addon, not taken from LibKa0s | No LibKa0s major tracks the 12.0 restrictions. AuraMaster and ConsumableMaster each react to `ADDON_RESTRICTION_STATE_CHANGED`, but to re-run their own work, not to answer what is allowed, so the semantics differ. A LibKa0s promotion issue is filed at the end of the v1 run (design spec §14) | 2026-10-10 (design spec §2, §14) | LibKa0s ships a restriction major, or a second Ka0s addon needs the same four answers |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
