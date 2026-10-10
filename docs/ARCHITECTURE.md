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
LibKa0s v1.71.0 payload, of which thirteen majors are wired, one setup file each (`DEPENDENCIES.md`
lists the toolchain):

| Major | Setup file | Gives |
|---|---|---|
| Core | `core/CoreSetup.lua` | the `[DW]` printer, secret-safe stringifier, SafeRegister family, the skin, the close mark, the resize grip |
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

`LibKa0s-Compat-1.0` and the Widgets majors are vendored and not wired yet. Each setup file holds a
descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every stub to the live
surface.

The main window (`modules/Window.lua`) is a non-secure standalone frame with the shared Ka0s edge,
built on its first show; one ladder decides when it is on screen ([`data-flow.md`](data-flow.md)).

## Module Map

Every file, its kind and its TOC position is in [`module-map.md`](module-map.md). In short: `core/`
holds the identity, ten of the setup files, the game-data tables (`Constants.lua` and
`ClassData.lua`, data plus pure lookups), the session state, the addon object and its lifecycle,
and the migration runner; `defaults/` the default values; `modules/` the window and the diagnostics
sections; `settings/` the schema, the panel pages and the slash table. The design's feature modules
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

No message is sent yet. Every sender module below is **planned**: it does not exist until the item
named in its row lands. The payloads and consumers are the design intent. The item that first sends
a message confirms its payload here, and each item that subscribes adds itself as a consumer.

| `NS.MSG` key | Wire suffix | Sender (planned, item) | Payload | Consumers |
|---|---|---|---|---|
| `DROP_ADDED` | `DropAdded` | `modules/LootFeed.lua` (DW-27) | `dropId` | Window feed tabs (DW-30), Toast (DW-52), History (DW-51) |
| `DROP_UPDATED` | `DropUpdated` | `modules/LootFeed.lua` (DW-27) | `dropId` | Window feed tabs (DW-30), detail card (DW-32), Offer panel (DW-33) |
| `INSPECT_DONE` | `InspectDone` | `modules/Inspect.lua` (DW-26) | `guid` | LootFeed (DW-27): re-evaluate that candidate's drops |
| `GEAR_CHANGED` | `GearChanged` | `modules/Gear.lua` (DW-24) | none | LootFeed (DW-27): re-evaluate; QualityGate's dynamic threshold (DW-12) |
| `RESTRICTION_CHANGED` | `RestrictionChanged` | `modules/Restrictions.lua` (DW-21) | `reason` (string, or nil when lifted) | Messaging edge (DW-2A): flush the queue; Window restriction badge (DW-30) |
| `SITUATION_CHANGED` | `SituationChanged` | `modules/Situations.lua` (DW-13) | `situationKey` | LootFeed (DW-27): the situation gate; Window (DW-30): auto-open |
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
so `OnEnable` and the stand-up register exactly that list and the stand-down unregisters it.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart` | ends test mode; re-runs the window's show decision |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd` | re-runs the window's show decision |

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

## Taint Notes

The window is a plain `Frame`, never secure, so showing, hiding and moving it are allowed in combat
and nothing defers. Settings writes touch no protected frame. Opening the settings panel is refused
in combat by the options library, which also locks a page shown in combat; the addon adds no lock of
its own and never closes Blizzard's settings window (options-ui-§2). The planned trade helper's
`PickupContainerItem` / `DropItemOnUnit` and the planned whispers are click-driven and are guarded
for combat and restriction state by their own items (design spec §4, §9).

## Known Limitations

- v0.1.0 is the frame of the addon: the window is empty apart from its test-mode banner, and none
  of the loot features exist yet ([`scope.md`](scope.md)).
- The class tables (`core/ClassData.lua`) are a fallback for a candidate whose spec is not known
  yet; an item's own spec list wins whenever it exists. Devourer Demon Hunter (spec 1480, from the
  client's trait-tree data) is recorded as an Intellect dual wielder that takes no held off hand,
  which is unconfirmed in game (FEED-7). Difficulty ids are confirmed with `GetDifficultyInfo`
  before the situation classifier trusts them (design spec §6.1).
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
| `midnight-quirks.md` | Not applicable | The addon carries no client-version workaround of its own |
| `compat-layer.md` | Not applicable | No `core/Compat.lua` ships: the addon makes no deprecated or version-variant client call outside LibKa0s's majors yet (compat's applicability condition); DW-20 adds the file |
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

None.

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today.
