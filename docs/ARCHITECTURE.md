# Architecture — Ka0s Drop Watcher

The hub: what this addon is, in ten mandated sections, each a summary with a link to its topic doc.
The design it was built to is
[`superpowers/specs/2026-10-10-drop-watcher-v1-design.md`](superpowers/specs/2026-10-10-drop-watcher-v1-design.md);
this page describes what exists.

## Overview

A Retail addon that watches the loot a party or raid receives, judges each drop for you and for the
looter, estimates whether it can be traded, and asks for it in one click ([`scope.md`](scope.md)).
Ace3 (AceAddon, AceDB, AceEvent, AceTimer, AceConsole, AceGUI, AceConfig, AceDBOptions),
LibSharedMedia, LibDataBroker, LibDBIcon and LibCustomGlow are vendored under `libs/`, and so is the
LibKa0s v1.91.0 payload (twenty-one majors; media/icons pruned to the declared subset), twenty wired with one setup file each and `LibKa0s-IconBrowser-1.0` deliberately unwired, since this addon offers no icon picker (`DEPENDENCIES.md`
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
| Widgets | `core/WidgetsSetup.lua` | the window's flat dropdowns (`NS.MakeDropdown`), the shared menu on a host's rows (`NS.ContextMenu`: the compact Filters ▾ cascade, V89A-DW, and the History row menu at the pointer, V89A-DWH) and its `NS.CloseMenu`, TestStrip (the mode strips, `NS.MakeTestStrip`: the amber test-mode banner, DW-06, LibKa0s#48, and the cyan simulation strip, `kind = "sim"`, Widgets minor 14, DW-10) and SearchBox (the filter bar's search, `NS.MakeSearchBox`; DW-07, LibKa0s#52) |
| Sim | `core/SimSetup.lua` + `modules/Sim.lua` | the simulator: the answer seam over the compat family (`NewSeam`), the session and its two-phase stop, the timeline, the `/dw sim` grammar and the step panel; DropWatcher hosts its scenarios, world providers, event drivers, restriction model and eight verbs (DW-02..DW-04) |
| Charts | `core/ChartsSetup.lua` | the Insights tab's cards and chart renderers (`NS.Charts`, a context per pane through `NS.ChartsHost()`, the skin owner `DropWatcher`; issue #12); without it `NS.Charts` is nil, with no drawing stub (anti-pattern #73), and the tab keeps its filters and strip and says the charts are unavailable |
| Glow | `core/GlowSetup.lua` | the stateless LibCustomGlow-1.0 driver behind the upgrade glow (`NS.GlowLib`, read by `modules/Glow.lua`; DW-08, LibKa0s#56); without it no icon glows |
| Toast | `core/ToastSetup.lua` | the alert-toast shell under the upgrade toast (`NS.NewToast`, called by `modules/Toast.lua`; LibKa0s#60, AT-A2): the queue, the stack (Toast-1.0 minor 4's opt-in `stack`, `stackGrow` and `SetStack`: up to `toast.stack` toasts at once, each on its own pooled frame, DW-T2), the countdown and its hover pause, the close mark and right-click, the HIGH tier, the drag, the scale and the sound, around the content `modules/Toast.lua` builds; without it (`NS.ToastStub`) no toast shows. |
| Skin | `core/SkinSetup.lua` | the skin the addon wears (skinning-§3): the owner `DropWatcher` with its twenty-four `dw.*` owner tokens, the facade `NS.Skin`, the Skin tab's read and write seams and the first-run skin picker ([§ Skins](#skins)); without it a degraded facade answers Ka0s Default's values |

Without LibKa0s-Widgets-1.0 the window draws no dropdown and no search box at all
(`NS.MakeDropdown` and `NS.MakeSearchBox` answer nil, and nothing filters by text), `NS.ContextMenu` answers nil (no Filters ▾ in compact; the History row menu is the client's `MenuUtil` menu), `NS.CloseMenu` is a no-op, and test mode and a simulation draw no strip
(`NS.MakeTestStrip` answers nil, the panes reserve no room and the `TEST MODE` / `SIM` title word
marks the mode; with the library, a word shows only while the window is minimized, DW-10). Each setup file holds a
descriptor and a degradation stub, and `tests/test_surface_parity.lua` holds every stub to the live
surface.

The main window (`modules/Window.lua`) is a non-secure standalone frame with the shared Ka0s edge,
built on its first show; one ladder decides when it is on screen ([`data-flow.md`](data-flow.md)).

## Module Map

The authored files load from the TOC in the standard's folder order; every one, its kind, its
one-line responsibility and why its position is load-bearing or conventional is in
[`module-map.md`](module-map.md), the only inventory. In short:

- `locales/` and `core/`: the strings, the identity, one setup file per LibKa0s major, the compat
  family (`Compat.lua`, `CompatClient.lua`, `CompatWorld.lua`, `CompatItem.lua`, `CompatJournal.lua`, `CompatCollect.lua`, `CompatLoot.lua`, the only files that name the client
  globals they wrap, with the pure parsers in `TextParse.lua`) and the simulator's answer seam over
  it (`SimSetup.lua`, LibKa0s-Sim-1.0's `NewSeam`), the library-shaped item reads, the game-data tables, the session state, the
  addon object with its lifecycle and shared host handlers, and the migration runner.
- `defaults/Profile.lua`: every default value (`NS.C`).
- `modules/`: the simulator's session (`Sim.lua`: LibKa0s-Sim-1.0 hosting DropWatcher's scenarios,
  world providers, event drivers, restriction model and eight verbs); the login session (`Session.lua`, the session start and This
  instance kept per character across a reload); the pure engine kernels (the verdict kernel and its
  off-spec pass, `OffSpec.lua`, which judges a drop your current spec can't use for the other specs
  of your class), the item kinds and the collection verdict (`Collectibles.lua`, issue #13: a mount,
  pet, toy, recipe or cosmetic is judged new or collected, feed-only, and read again on the
  collection events; since RX-04 a lockbox or bag (`container`) and an item of no kind rolled on
  under the catch-all (`other`) read their kind word, Lockbox, Container or Item, feed-only with no
  gain, on the rows, the cards, Rolling now and the roll popup), the tier-token pass (`TierTokens.lua`: the slot a token makes, read from its
  Use text, else its name (TT-1), and the best tier slot of a token whose slot it cannot read or an
  omni Curio, so a token is judged as gear) and the scorers; the item lists' one writer
  (`ItemLists.lua`: Always watch and Never watch, which the panel and the CLI share); the edges
  that read the client; the feed that orchestrates them, with its counts, rosters, places and
  recorders, and beside it the store of drops seen but not yet assigned (`Pending.lua`: open group-loot rolls, and `PendingML.lua`'s master-loot drops awaiting the master looter, drawn by the Drops tab's Rolling now section, `WindowPending.lua`, over the pure `RollCells.lua`, with your verdict marked on Blizzard's own roll popup, `RollPopup.lua`); the recorded and opt-in features (History, its retention and the feed rebuilt from it
  after a reload, `FeedRestore.lua`; the Insights tab's pure filters and one stats pass over the kept
  history, `InsightsFilters.lua` and `InsightsStats.lua`, issue #12; the toast, its content on LibKa0s-Toast-1.0's shell, and
  auto-ask); the simulator's
  host half: its world providers (`SimWorld.lua`), item pool and group (`SimPool.lua`, `SimRoster.lua`), event
  drivers (`SimEvents.lua`), scenarios and timeline steps (`SimScenario.lua`), loot report
  (`SimReport.lua`) and the step panel's fields (`SimPanel.lua`; the panel, the session, the step
  machine and the verb grammar are LibKa0s-Sim-1.0's); then the window: its shell, chrome, three tabs (Drops, History and
  Insights, whose cards and chart sections draw through LibKa0s-Charts-1.0: `InsightsRows.lua`,
  `InsightsSections.lua`, `WindowInsights.lua`), their strips' one
  footer button kind and Expand all / Collapse all (`FooterRow.lua`), pure cell composers (an
  off-spec verdict's look, `OffSpecCells.lua`, and a collectible's, `CollectCells.lua`, among them), the two
  detail cards (the Drops card, and the History card drawn from a kept snapshot, `HistoryCard.lua`),
  tooltip placement, the upgrade glow on a drop's icon (`Glow.lua`, LibCustomGlow-1.0), every item
  icon's look (`IconStyle.lua`: Window › Icons' zoom and border), compact
  mode's switch and bodies, test mode and the diagnostics.
- `settings/`: the schema seam and its rows (the hand-written ones, then the composed blocks the
  Options instance emits: Master controls in `Panel.lua`, Window › Icons' border in
  `ComposedRows.lua`), the options pages and their editors (Drops › Item lists' in
  `ListEditors.lua`), the slash table,
  the slash-only and `/dw sim` verbs, and Profiles, last.

The window only listens: it reads the engine through read-only accessors and the bus, and every
button goes through the host handler its slash verb shares.

### Per-client features (clients-§4)

Drop Watcher serves Retail and WoW Forever. The table names each feature that serves one client,
or that both clients have in a shape of their own (Forever port design §4.4); every feature it does
not name serves both. The Client column takes the standard's tokens alone: `retail`, `forever` or
`both`. A feature both clients have in their own shape is two rows, one `retail` and one `forever`,
its two lists picked once by `ClientKey()` (clients-§5), never a filtered Retail list. A `both` row
is a feature the port added that serves both clients in one shape, listed so the port's surface is
in one place. A declaration is `clients = { ... }` on the row, the event row, the column or the
seed list; `C.FEATURE_CLIENTS` (`core/Constants.lua`) names the Retail-only features DW-FP10 and
DW-FP11 gate, and `C.FEATURE` holds each one's `ForClient` answer, read once. A default only a
Retail-only feature reads is added on Retail alone (`defaults/Profile.lua`, DW-FP21).

| Feature | Client | Gated in |
|---|---|---|
| The default skin: Ka0s Default (`NS.DEFAULT_SKIN = Skin:DefaultSkin()`, skinning-§2, DW-FP03) | `retail` | `core/SkinSetup.lua`, `defaults/Profile.lua` (`skin.skin`) |
| The default skin: WoW Forever (the same read) | `forever` | `core/SkinSetup.lua`, `defaults/Profile.lua` (`skin.skin`) |
| Character names: `Name-Realm` (`Compat.UnitCharacterName`, `Compat.CharacterKey`, client-quirks-§5, DW-FP04) | `retail` | `core/CompatClient.lua`, `modules/Roster.lua`, `modules/SimRoster.lua` (sim names per client) |
| Character names: the whole name, first name and surname, no realm (the same reads) | `forever` | `core/CompatClient.lua`, `modules/Roster.lua`, `modules/SimRoster.lua` |
| The class data: Retail's classes and specs (DW-FP05) | `retail` | `core/ClassData.lua` (the list picked at load), `modules/Evaluate.lua` |
| The class data: Forever's nine classes keyed `"<classFile>:<tree>"` by talent tree, armor by level (`CD.ArmorFor`, plate or mail from 40, reason `armorLevel`) and the soft stat gate (`CD.STAT_GATE`, DW-FP05) | `forever` | `core/ClassDataForever.lua`, `modules/Evaluate.lua` (the stat and armor gates) |
| The ranged slot plan: a bow, gun, crossbow or wand fills both hands (DW-FP06) | `retail` | `core/Constants.lua` (`SLOT_PLAN_RANGED` per client, joined into `C.SLOT_PLAN`) |
| The ranged slot plan: slot 18 (`C.SLOT.RANGED`) holds ranged and thrown weapons, wands and relics, and the snapshot and the inspect read it (DW-FP06) | `forever` | `core/Constants.lua`, `modules/Gear.lua`, `modules/Inspect.lua` |
| Pawn and your weights by spec (DW-FP07) | `retail` | `core/Compat.lua` (`PawnScaleForSpec`, `PawnVisibleScale`, `PawnClassScales`), `modules/Scoring.lua`, `settings/Editors.lua` |
| Pawn and your weights by talent tree: Pawn's Classic scale per tree, the best of the class's scales for a looter, weights keyed `"<classFile>:<tree>"`, the class list's `PAWN_BY_TREE` (DW-FP07) | `forever` | `core/Compat.lua`, `modules/Scoring.lua`, `settings/Editors.lua`, `settings/PageEditors.lua` (the weights strip's trees) |
| Item-level-first verdicts: `opts.verdictMode` is `ilvlFirst` (DW-FP08) | `retail` | `modules/LootFeed.lua` (`LF.VERDICT_MODE`), `modules/Evaluate.lua` (`decide`) |
| Score-first verdicts: `opts.verdictMode` is `scoreFirst` (the score decides, item level breaks a tie within 1%, `noScore` falls back to item level; the verdict's `led` says which decided, and a score-led upgrade passes the toast's and auto-ask's least gain, DW-FP08) | `forever` | `modules/LootFeed.lua`, `modules/Evaluate.lua`, `modules/Toast.lua`, `modules/AutoAsk.lua`, `modules/Asks.lua` (`{mygain}`), `modules/WindowCells.lua` (`VERDICT_MEANS`), `modules/MineCells.lua` (`EXPLAIN`: the Offer panel's For them on an upgrade reads a higher score, item level breaking a tie) |
| Test mode's and the simulator's seeds: Retail's classes, places and history samples (DW-FP09) | `retail` | `modules/TestData.lua`, `modules/SimScenario.lua`, `modules/SimRoster.lua` (seed lists per client) |
| Test mode's and the simulator's seeds: Forever's nine classes, its places and its history samples (DW-FP09) | `forever` | `modules/TestData.lua`, `modules/SimScenario.lua`, `modules/SimRoster.lua` |
| Mythic+, delves, follower dungeons, Raid Finder, scenarios: their situations, rows and sim scenarios | `retail` | `core/Constants.lua` (`C.SITUATIONS`, `C.DIFFICULTY_KIND`), `defaults/Profile.lua`, `modules/SimScenario.lua` (seed lists per client) |
| The words Mythic+, delve and follower in shared text: the Compact view in a run row's tooltip (a dungeon or raid on Forever), By boss's empty line (no whole-key runs on Forever), your own drop's solo No action hint (no followers or companions on Forever), the `/dw diagnostics` and `/dw situation` inputs `challengeMode`/keystone, `delve` and `follower` | `retail` | `settings/SchemaRows.lua`, `modules/InsightsSections.lua` (`SX.EMPTY`), `modules/MineCells.lua` (`ALONE_HINT`), `modules/Diagnostics.lua` and `settings/SlashVerbs.lua` (`INPUT_LINES` per client) |
| `CHALLENGE_MODE_START`, `CHALLENGE_MODE_COMPLETED` and the keystone header | `retail` | `modules/Situations.lua`, `modules/LootFeed.lua`, `modules/Asks.lua`, `modules/WindowCompact.lua` (event rows) |
| `PLAYER_SPECIALIZATION_CHANGED` | `retail` | `modules/Gear.lua` (event row) |
| `TRAIT_CONFIG_UPDATED`, `CHARACTER_POINTS_CHANGED`, `PLAYER_LEVEL_UP` | `forever` | `modules/Gear.lua` (event rows) |
| The Encounter Journal item pool and `EJ_LOOT_DATA_RECIEVED` | `retail` | `modules/SimPool.lua` (`BuildInto`, event row), `modules/SimPanel.lua` (Start's tooltip) |
| The simulator's item pool from your own gear | `forever` | `modules/SimPool.lua` (`BuildInto`), `modules/SimPanel.lua` |
| Transmog: the look read, `TRANSMOG_COLLECTION_UPDATED`, the look chip, the `transmog` template, `messages.transmogAsk` and `messages.templates.transmog` (rows and defaults), the CanIMogIt and transmog diagnostics lines | `retail` | `modules/ItemFacts.lua`, `modules/DetailCells.lua`, `modules/Messaging.lua`, `modules/Asks.lua`, `settings/SchemaRows.lua`, `defaults/Profile.lua`, `modules/Diagnostics.lua`, `core/DropWatcher.lua`, `modules/TestData.lua` |
| Upgrade tracks: the Track row, the track in the item level chip and the Ilvl tooltip, the `{track}` token | `retail` | `modules/DetailCells.lua`, `modules/WindowCells.lua`, `core/Constants.lua` (`C.MESSAGE_TOKENS`) |
| Off-spec: the off-spec pass (`OffSpec.Initialized`), the candidates' off-spec gear, the `askOffSpec` template (row and default), the off-spec glow (`Glow.KINDS`, its rows, its defaults, its skin companion), its legend and notes, the auto-ask diagnostics line's `offSpec=` | `retail` | `modules/OffSpec.lua`, `modules/Gear.lua`, `modules/Inspect.lua`, `core/Constants.lua` (`C.MESSAGE_TEMPLATES`), `settings/SchemaRows.lua`, `defaults/Profile.lua`, `modules/Glow.lua`, `core/Database.lua` (`NS.FULL_SKIN_KEYS`), `modules/OffSpecCells.lua`, `modules/WindowGroup.lua`, `modules/OfferPanel.lua`, `modules/Diagnostics.lua`, `modules/TestData.lua` |
| The simulator's bonus rolls | `retail` | `modules/SimEvents.lua` (`Plan`) |
| The trade rules `personal`, `group` and `legacy` | `retail` | `core/Constants.lua` (`C.TRADE_RULE_NAMES` per client), `defaults/Profile.lua` (`trade.rules` per client), `modules/TradeRules.lua` |
| The trade rule `soulbound` alone: a BoP drop is `no soulbound`, basis `bind`; only a BoE drop changes hands (design §4.6) | `forever` | `core/Constants.lua`, `defaults/Profile.lua`, `modules/TradeRules.lua` |
| The trade timer's countdown and warning (`TradeTimer.Initialized`; on Forever the bag match runs and every entry is permanent), the Drops table's Trade window column and its Shown columns row (`window.columns.tradeWindow`), the `trade.warnAt` row and default, the card's bag-timer basis line, the words `Trade window` on the Offer panel's item line | `retail` | `modules/TradeTimer.lua`, `modules/WindowGroup.lua` (the column's `clients`), `settings/SchemaRows.lua`, `defaults/Profile.lua`, `modules/DetailCells.lua`, `modules/MineCells.lua` (`PanelHeader`), `modules/Diagnostics.lua` |
| General › Role, the role override (`char.role`: Automatic, Tank, Healer or Damage, saved per character through LibKa0s `Role.SetOverride`; on a Druid it picks the Feral Pawn scale, design §11.4, DW-FP22) | `forever` | `settings/SchemaRows.lua` (`role`, `Settings.RefreshRoleTooltip`), `settings/Schema.lua` (the `CHAR` closure row), `core/CompatClient.lua` (`Compat.AutomaticRole`, `Compat.SetRoleOverride`), `settings/Panel.lua`, `defaults/Profile.lua` (`ROLE_DEFAULT`) |
| The per-situation loot rule rows (`trade.rules.<situation>`) and the Situations table's Loot rule column | `retail` | `settings/SchemaRows.lua`, `settings/Editors.lua` (`SITUATION_FIELDS`), `settings/PageEditors.lua` |
| Everyone's group-loot rolls: the pending store's roll kind, the Drops tab's Rolling now section, a rolled drop's Rolls box, the roll table kept in History, the Drops › Rolls rows, `/dw sim roll` and test mode's sample roll (design §5, §8; DW-FP13 to DW-FP17) | `both` | `core/CompatLoot.lua`, `modules/Pending.lua`, `modules/WindowPending.lua`, `modules/RollCells.lua`, `modules/History.lua`, `modules/SimEvents.lua`, `modules/TestData.lua` |
| Master-loot pending and Ask the master looter: an item at or above the group's loot threshold in the loot window you opened, held as awaiting the master looter until a receipt names who got it, the `askML` template and its row, `/dw sim ml` (design §6; DW-FP18, DW-FP19). On Retail the method is Guild Master Loot alone (design §11.2): a declared reach of the client, not a client gate | `both` | `core/CompatLoot.lua` (`LootMethod`, `LootThreshold`, `LootSlots`), `modules/PendingML.lua`, `modules/Asks.lua`, `modules/WindowPending.lua` (`AskAction`), `modules/SimEvents.lua` |
| The roll popup mark: your verdict and `Need so far` on a card over Blizzard's `GroupLootFrame1..4` (design §7, DW-FP20; not drawn in the gamepad UI) | `both` | `modules/RollPopup.lua`, `core/CompatLoot.lua` (`HookRollPopup`, `RollPopupOpen`) |
| The roll popup mark's wording on any verdict: the verdict word | `retail` | `modules/RollPopup.lua` (`RP.Verdict`, the client read once at load) |
| The roll popup mark's wording on a bound-on-pickup drop: an upgrade reads `Need: upgrade` and one you can't use `Greed / Pass: you can't use it` (a BoP drop is soulbound once looted, design §4.6, §7); any other verdict, the verdict word | `forever` | `modules/RollPopup.lua` (`RP.Verdict`) |

The filter bar is shared by the tabs and never reflows between them: a control a tab does not use
is grayed, not removed (Ka0s Loot History's pattern, `modules/WindowFilterBar.lua`). The one
exception is a tab registered with `ownBar` (`Window.RegisterTab`, `Window.TabOwnsBar`): Insights,
whose seven filters none of the shared controls apply to. While it is active the window hides the
shared bar and the footer's Sort, starts the pane under the tabs, re-anchors the test-mode and
simulation strips there, and never syncs the shared bar. This is a DropWatcher convention, not a rule
of the standard (Insights design spec §4.1), so it owes no deviation row.

## Settings Schema

One write seam, `NS.SchemaRuntime.Set` (LibKa0s-Schema), reached by the panel, the CLI, the launcher
and the host verbs alike, and one read, `NS.Setting(path)`. The rows are `settings/Schema.lua`'s
`Settings.Schema` array: the composed Master controls rows (`settings/Panel.lua`), then every
hand-written row of design spec §12.1 (`settings/SchemaRows.lua`), then the composed blocks of the
later pages (`settings/ComposedRows.lua`: Window › Icons' border, options-ui-§16; feedback-21 G11),
which take SchemaRows' checks. Each row's `group` is its tab on
its page, a `disabledIf` predicate dims a row with nothing to do, its `default` references
`defaults/Profile.lua`, and its `validate` refuses a value before the seam stores it. The two
specID-keyed tables are whole-value `map` rows (architecture-§5's value route), and so are the two
item lists, `feed.whitelist` and `feed.blacklist` (issue #13): flat `{ [itemID] = true }` sets
whose one writer, `NS.ItemLists` (`modules/ItemLists.lua`), the panel's Item lists tab and
`/dw whitelist|blacklist` both call, so an ID on one list is refused by the other on both surfaces.
The seam's `resetExempt` keeps them out of the Drops page's Defaults (plan #13, Q9). On WoW Forever, General › Role
(`char.role`) is a per-character closure row over the role store, which no profile reset reaches.

State written outside the seam (architecture-§5) is named, each key with its one owner module and
every writer, in one place: the window's per-layout geometry and its minimized flag, the toast's
position (the simulation panel's is session-only, held by LibKa0s-Sim-1.0), auto-ask's one-time notice, the history's own record, the per-character session
(`char.session`, feedback-15 spec §0), the per-character role store (`char.role`, LibKa0s-Role-1.0's, DW-FP02) and LibDBIcon's own write. The load pass is `NS:RunMigrations` (`core/Database.lua`), and
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

Eleven messages are sent today; the Forever port added the eleventh, `PENDING_CHANGED` (DW-FP14),
which the Drops tab's Rolling now section and the roll popup mark receive, and the master-loot ask
rides `ASK_STATE_CHANGED` as kind `askML` (DW-FP19). The window only listens:
it reads records through the engine's read-only accessors, and a button goes through the host
handler its slash verb shares. Every message's sender, payload and consumers, and every receiver's
list, are in [`message-bus.md`](message-bus.md).

## Slash Commands

`/dw`, alias `/dropwatcher`. The reserved verbs (`help config skin enable disable version list get set
reset resetall profile debug diagnostics perf`; `skin`, LibKa0s v1.82.0's `O.SkinVerb`, is refused while disabled) plus `lock`, `unlock`, `show`, `hide`, `toggle`,
`test` and the feature verbs of design spec §12.3 (`scan clear history mine compact situation offer
add`, plus compact spec §1's `full` and issue #12's `insights`, which opens the Insights tab as `history` opens History; `mine` opens Drops since My drops was retired, feedback-5 spec §3; and
issue #13's `whitelist` and `blacklist`, each `add|remove <id|link>` or `list`, through the item
lists' one writer, `NS.ItemLists`, which the settings panel shares); the full table, the live-while-disabled set and the handlers are in
[`slash-dispatch.md`](slash-dispatch.md). Every toggle verb calls the same handler as its Master
controls row and its launcher entry (`core/DropWatcher.lua`); `scan`, `compact` and `full` share the
window's own handlers, and the slash-only verbs are answered by `settings/SlashVerbs.lua`. `sim` is
one feature-verb row that hands its argument to LibKa0s-Sim-1.0's `NS.Sim:RunVerb` (the library's
grammar plus DropWatcher's eight verbs, `settings/SimVerbs.lua`; DW-03), so it is refused while
disabled like any other and has no key binding. The launcher menu's Sim mode entry and Master
controls' Sim mode box are its one other door: both take the same `NS.IsSimMode` / `NS.ToggleSim`
pair (`core/DropWatcher.lua`). `NS.IsSimMode` answers whether the step panel is shown or a sim runs
(R7-SIM), and `NS.ToggleSim` runs the verb itself: from off the bare `sim` (the status and the step
panel), from on `stop` while a sim runs and then the panel closed. A verb or
button refused while stood down prints `NS.StoodDownRefusal()`, so a perf capture never tells the
player to `/dw enable` an addon that is already enabled.

The launcher's Show window entry has a key binding (launcher-§6, LibKa0s#58). The root
`Bindings.xml`, which the client reads without a TOC line, declares one
`CLICK DropWatcherToggleWindow:LeftButton` binding in the addon's own category,
`BINDING_HEADER_DROPWATCHER`, with no `header` attribute and no default key, so Options →
Keybindings shows it in a section of its own titled with the brand. `core/LauncherSetup.lua` builds that button at load, above its
library check: a plain, named, hidden, non-secure Button registered `AnyDown`. Its OnClick asks
`NS.StoodDownRefusal()` first, because `NS.ToggleWindow` relies on the dispatcher's gate for
`/dw toggle`, and prints that one line when it answers (the disabled line under the disabled hold,
`Not available during a performance capture.` under the perf hold alone). Otherwise it calls
`NS.ToggleWindow`, so the menu entry, the toggle verb and the key are one handler. The header label
is `NS.BRAND` and the row label `Toggle drop feed` goes through `NS.L`. `NS.BINDINGS`, beside the
button, lists the commands in `Bindings.xml` order (Show window first) with each one's tooltip; the
General page's last tab, Keybindings, is LibKa0s's `O.KeybindingsTab` over it (options-ui-§20,
`settings/Panel.lua`), and `tests/test_bindings.lua` holds `Bindings.xml` to it through
`Kit.assertBindingsXml`. The button's name is permanent: a rename unbinds every player's key.

## Event Subscriptions

Every game event is declared in `NS.FEATURE_EVENTS` and registered through
`NS.SafeRegisterEvent`, so `OnEnable` and the stand-up register exactly that list and the
stand-down unregisters it. (Compact mode's Filters menu is LibKa0s-Widgets' shared menu, whose own
`GLOBAL_MOUSE_DOWN` listener closes it on a press outside it; the addon registers none for it,
`modules/CompactChrome.lua`.) Two
modules may declare the same event: AceEvent keeps one handler per event, so such an event is
registered once, on `DW:OnSharedFeatureEvent`, which calls each declared handler in row order (the
TOC order of the modules). Each handler runs under `pcall`, so one that raises never skips the
rest: its error is an `Init` debug line, and the first error is raised once every handler has run,
the way the client's own registrant dispatch and AceAddon's errorCollector behave. `NS.FeatureEventNames()` is the declared list with each event once.
`NS.DeliverEvent(event, ...)`, beside the dispatcher in `core/DropWatcher.lua`, is the simulator's
replay of the same `NS.FEATURE_EVENTS` rows (`NS.Sim:Fire` and `NS.Sim:DeliverForCleanup` call it):
it skips an event listed in `NS.rejectedEvents`, as the client never delivers one it rejected at
registration, calls each declared handler in row order under `pcall`, writes a raise as a `SIM`
debug line and never rethrows it (the deliberate difference from the live dispatcher), and answers
how many handlers it called.

| Event | Handler | Why |
|---|---|---|
| `PLAYER_REGEN_DISABLED` | `DW.OnCombatStart`, then `DW.OnInspectCombatEvent`, then `DW.OnToastCombatStart` (through `DW:OnSharedFeatureEvent`) | ends test mode; re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then parks the inspect queue (`modules/Inspect.lua`); then, unless `toast.inCombat`, holds the toast: the shell's `Hold` takes every toast on screen down and puts them back at the head of its queue, in order (`modules/Toast.lua`) |
| `PLAYER_REGEN_ENABLED` | `DW.OnCombatEnd`, then `DW.OnCollectRegenEvent`, then `DW.OnGearRegenEvent`, then `DW.OnInspectCombatEvent`, then `DW.OnToastCombatEnd` (the same) | re-runs the window's show decision; hands the combat edge to `modules/Restrictions.lua`; then (since DW-CAT3) arms the collection re-read for the live collectibles still at `collectUnknown`, whose protected answer may read now (`modules/Collectibles.lua`); then arms the gear rebuild a bag event deferred in combat (`modules/Gear.lua`); then resumes the inspect queue (`modules/Inspect.lua`); then shows the toast combat held, the shell's `Release` (`modules/Toast.lua`) |
| `ADDON_RESTRICTION_STATE_CHANGED` | `DW.OnRestrictionEvent` | records the type's state as a hint and re-reads the restrictions (`modules/Restrictions.lua`); sends `RestrictionChanged` on a change |
| `PLAYER_ENTERING_WORLD` | `DW.OnSimWorldEvent`, then `DW.OnSessionWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnInspectWorldEvent`, then `DW.OnPendingWorldEvent`, then `DW.OnPendingWhere`, then `DW.OnRetentionWorldEvent`, then `DW.OnRestoreWorldEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | ends a running simulation when the real client is now inside an instance or in a group (`modules/Sim.lua`, read past the seam); then (since DW-Q0) an initial login starts the session now, a reload keeps it (`modules/Session.lua`, `char.session.start`); then re-classifies the situation (`modules/Situations.lua`); sends `SituationChanged` on a change; then, inside an instance, arms the inspect warm-up (`modules/Inspect.lua`); then (since DW-FP14) rebuilds the open group-loot rolls from the client, every encounter's open drops and your open roll popups, never opening a drop twice (`modules/Pending.lua`, Forever port design §5.2); then (since DW-FP18) expires each pending master-loot item seen in another instance (`modules/PendingML.lua`); then (since DW-A5) the first one of the session arms the History's prune by age five seconds later on a cancelable timer the stand-down takes back (`modules/HistoryRetention.lua`); then (since DW-Q0) the first one of a load that says `isReloadingUi` rebuilds the Drops tab from this session's History entries (`modules/FeedRestore.lua`); then (since DW-62) ends auto-ask's encounter hold when no Encounter restriction is left in force, so a player who left mid-fight is not held for good, or, while it is still in force, lets its later lifting (`RestrictionChanged`) end the hold (`modules/AutoAsk.lua`) |
| `ZONE_CHANGED_NEW_AREA` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnAutoAskWorldEvent` (through `DW:OnSharedFeatureEvent`) | the simulation's automatic stop and the situation, as above; then auto-ask's encounter hold, as above |
| `CHALLENGE_MODE_START` | `DW.OnSituationEvent`, then `DW.OnFeedRunStart`, then `DW.OnCompactRunStart` (through `DW:OnSharedFeatureEvent`) | Retail only (`clients = { "retail" }`, DW-FP09: WoW Forever has no keystones): the same (a keystone started); then opens the run's drop group (`modules/LootFeed.lua`); then (since DW-C0) clears compact mode's completed-key latch and its grace timer (`modules/WindowCompact.lua`) |
| `CHALLENGE_MODE_COMPLETED` | `DW.OnSituationEvent`, then `DW.OnFeedRunEnd`, then `DW.OnAskFlushEvent`, then `DW.OnCompactRunEnd` (the same) | Retail only (`clients = { "retail" }`, DW-FP09): the same (a keystone ended); then keeps the run's group open while you stay in its instance, else 120 seconds, for the chest and a late bonus roll (feedback-20); then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`); then (since DW-C0) arms compact mode's grace timer: 120 seconds later the run override ends (a hidden window lets go at once, a shown one when next hidden) and the situation is latched, since a completed key still reads as mythicPlus until the player leaves (`modules/WindowCompact.lua`) |
| `GROUP_ROSTER_UPDATE` | `DW.OnSimWorldEvent`, then `DW.OnSituationEvent`, then `DW.OnRosterEvent`, then `DW.OnInspectRosterEvent`, then `DW.OnPendingRoster`, then `DW.OnAskRosterEvent`, then `DW.OnAutoAskRosterEvent` (through `DW:OnSharedFeatureEvent`) | the simulation's automatic stop (joining a real group ends it); then the situation (solo and open-world group turn on it); then re-reads the group's members (`modules/Roster.lua`), and on a change its sinks grow the open group's roster and its History group's (`modules/GroupRoster.lua`); then drops the inspect entries of members who left and arms the inspect warm-up (`modules/Inspect.lua`); then (since DW-FP18), out of a group, expires every pending master-loot item (`modules/PendingML.lua`); then cancels the asks queued to members who left, and the queued announces once you are out of a group (`modules/Asks.lua`); then cancels the waiting automatic asks to looters who left (`modules/AutoAsk.lua`) |
| `PLAYER_DIFFICULTY_CHANGED` | `DW.OnSituationEvent` | the same |
| `SPELL_TEXT_UPDATE` | `DW.OnSpellTextUpdate` | (since TT-1) a spell's text arrived: every cached item whose use spell it is and whose use text came back empty (`useSpellLoading`, not loaded yet) reads its use text, tier-token flag, made slot and category again (`modules/ItemFacts.lua`); a drop of such an item already waits for the spell through `ItemFacts.Request` |
| `TRANSMOG_COLLECTION_UPDATED` | `DW.OnTransmogCollectionUpdated` | Retail only (`clients = C.FEATURE_CLIENTS.transmog`, DW-FP10: WoW Forever has no transmog): re-reads whether each cached item's appearance is collected (`modules/ItemFacts.lua`), then (since DW-CAT3) arms the collection re-read, so a live cosmetic's verdict follows (`modules/Collectibles.lua`) |
| `NEW_MOUNT_ADDED`, `NEW_PET_ADDED`, `NEW_TOY_ADDED`, `NEW_RECIPE_LEARNED`, `SKILL_LINES_CHANGED` | `DW.OnCollectionEvent` | (since DW-CAT3) a mount, pet, toy or recipe learned, or a profession gained or lost: arms one 0.5-second timer, so a burst reads once; it re-reads the cached collectibles (`NS.ItemFacts.RereadCollections`, the cache's one writer) and re-judges each live collectible whose verdict moved through `LootFeed.Refresh(rec, "collection")`, which sends `DropUpdated(id, "collection")`; the stand-down cancels the timer (`modules/Collectibles.lua`). `PET_JOURNAL_LIST_UPDATE` is not used: it fires too often |
| `PLAYER_EQUIPMENT_CHANGED` | `DW.OnGearEvent` | arms the gear snapshot's throttled rebuild (`modules/Gear.lua`); sends `GearChanged` when it moved |
| `BAG_UPDATE_DELAYED` | `DW.OnGearEvent`, then `DW.OnTradeTimerEvent` (through `DW:OnSharedFeatureEvent`) | the same (a better item may have entered or left the bags), except in combat, where it is noted for the combat's end; a bag-only rebuild keeps the worn slots whose link stayed and reads no worn tooltip; then asks for the trade timer's scan of your own drops' bag items, at most one per 2 seconds (`modules/TradeTimer.lua`) |
| `PLAYER_SPECIALIZATION_CHANGED` | `DW.OnGearSpecEvent` | Retail only (`clients = { "retail" }`): the same, for your own unit only (another member's spec change is ignored) |
| `TRAIT_CONFIG_UPDATED`, `CHARACTER_POINTS_CHANGED` | `DW.OnGearTalentEvent` | WoW Forever only (`clients = { "forever" }`, DW-FP05): a talent change is the spec change there (the talent trees are the specs), so it arms the same rebuild, which re-reads your top talent tree (`NS.Compat.PlayerTalentTree`) |
| `PLAYER_LEVEL_UP` | `DW.OnGearLevelEvent` | WoW Forever only (`clients = { "forever" }`, DW-FP09): a level gained moves what you can wear (plate or mail from level 40), so it arms the same rebuild, which re-reads your level once the throttle runs |
| `CHAT_MSG_LOOT` | `DW.OnChatMsgLoot` | parses the line (`modules/LootParser.lua`), counts it, and hands a receipt to the feed's sink (`modules/LootFeed.lua`) |
| `INSPECT_READY` | `DW.OnInspectReadyEvent` | reads the inspected member's slots and spec after 0.15s, for the job in flight or any other group member (`modules/Inspect.lua`); sends `InspectDone` when the job ends |
| `UNIT_INVENTORY_CHANGED` | `DW.OnInspectInventoryEvent` | marks a group member's inspect read stale and re-queues it as a warm-up job (`modules/Inspect.lua`) |
| `ENCOUNTER_START` | `DW.OnFeedEncounterStart`, then `DW.OnAutoAskEncounterStart` (through `DW:OnSharedFeatureEvent`) | the encounter in progress, which names the group of the drops that follow (`modules/LootFeed.lua`); then holds the waiting automatic asks until it ends (`modules/AutoAsk.lua`) |
| `ENCOUNTER_END` | `DW.OnFeedEncounterEnd`, then `DW.OnAskFlushEvent`, then `DW.OnAutoAskEncounterEnd` (through `DW:OnSharedFeatureEvent`) | a kill keeps the encounter's group open 120 seconds for its loot; a wipe closes it; then re-reads the restrictions and flushes the queued asks when chat may be sent (`modules/Asks.lua`); then makes every waiting automatic ask due its delay after now (`modules/AutoAsk.lua`) |
| `ENCOUNTER_LOOT_RECEIVED` | `DW.OnFeedEncounterLoot` | a drop reported by the encounter, with its encounter id; merged with the chat line of the same drop, the more complete of the two links kept (ui spec §0) |
| `LOOT_CLOSED` | `DW.OnTradeTimerEvent` | asks for the trade timer's scan: the items just looted are in the bags (`modules/TradeTimer.lua`) |
| `LOOT_HISTORY_UPDATE_ENCOUNTER` | `DW.OnPendingEncounter` | both clients (since DW-FP14): walks the encounter's drops (`Compat.LootHistoryDropsFor`) and opens each open one that passes the feed's pre-looter gates (`NS.FeedFilter.PassesForMe` through `LootFeed.GateFor`, design §11.1) as a pending roll item (`modules/Pending.lua`); sends `PendingChanged(id, "open")` |
| `LOOT_HISTORY_UPDATE_DROP` | `DW.OnPendingDrop` | both clients (the feed's until DW-FP14): re-reads one drop's roll table (`Compat.LootHistoryRolls`, `core/CompatLoot.lua`). A changed table of an open item sends `PendingChanged(id, "rolls")` once; a winner hands the final table to the feed (`LootFeed.OnLootHistoryDrop` with `roll` and `pendingKey`: the `history` source, taken once, merged with the other reports, the most complete link kept, `rec.roll` kept) and closes the item (`PendingChanged(id, "closed")`); everyone passing keeps the item 60 s, then closes it, with nothing in the feed; a drop with a winner and no item goes to the feed as before |
| `LOOT_HISTORY_CLEAR_HISTORY` | `DW.OnPendingClear` | both clients (since DW-FP14): drops the pending store's live key mapping and detaches every open roll item from its `encounterID:dropKey` (a reused key never resolves the wrong drop); a detached item, or an open item whose drop the history no longer answers, expires on the next tick |
| `START_LOOT_ROLL`, `CANCEL_LOOT_ROLL` | `DW.OnPendingStartRoll`, then `DW.OnRollPopupStart`; `DW.OnPendingCancelRoll`, then `DW.OnRollPopupCancel` (through `DW:OnSharedFeatureEvent`) | both clients (since DW-FP14): your own roll popup (`Compat.LootRollInfo`) claims the oldest unclaimed open item of its item ID (`Pending.ForRoll`, for the popup mark, design §7), and lets it go when canceled; then (since DW-FP20) the popup mark reads the popup's item, judges it for you and caches it by rollID, drawing a simulated roll on its stand-in, and drops it when canceled (`modules/RollPopup.lua`) |
| `LOOT_READY`, `LOOT_OPENED` | `DW.OnPendingLootReady`, `DW.OnPendingLootOpened` | both clients (since DW-FP18; on Retail master loot is Guild Master Loot only): under master loot (`Compat.LootMethod`, `core/CompatLoot.lua`) and when you are not the master looter, holds each loot-window slot (`Compat.LootSlots`) at or above the group's loot threshold (`Compat.LootThreshold`: `GetLootThreshold`, else 2, Uncommon; rolls UX RX-03, not `MasterLootQualityThreshold`, which only gates Blizzard's distribution-confirm popup) that passes the feed's pre-looter gates as a pending `ml` item keyed `sourceGUID:itemID` (`modules/PendingML.lua`); a re-opened corpse adds nothing. A chat or encounter receipt for that item inside 600 s assigns it (the drop carries `pendingKey` and `askedML`); it expires at 900 s |
| `PARTY_LOOT_METHOD_CHANGED` | `DW.OnPendingLootMethod` | both clients (since DW-FP18): made master looter, your pending `ml` items expire (nothing is pending for the master looter) |
| `TRADE_SHOW` | `DW.OnHistoryTradeShow` | a trade opened: its partner (`UnitCharacterName("NPC")`: the whole name on WoW Forever) and the window's items are read (`modules/History.lua`, through `core/Compat.lua`) |
| `TRADE_PLAYER_ITEM_CHANGED`, `TRADE_TARGET_ITEM_CHANGED` | `DW.OnHistoryTradeItems` | the items moved: re-read, and any both-accepted state is off |
| `TRADE_ACCEPT_UPDATE` | `DW.OnHistoryTradeAccept` | either side accepted: the items are read once more and kept as the offer, since they are gone by the end |
| `TRADE_CLOSED` | `DW.OnHistoryTradeClosed` | the window closed, completed or not: the trade waits `CLOSED_GRACE` (5) seconds for its "Trade complete."; alone it is a cancel or a failure and completes nothing. The client's second `TRADE_CLOSED` changes nothing |
| `EJ_LOOT_DATA_RECIEVED` (the client's spelling) | `DW.OnSimPoolLoot` | Retail only (`clients = C.FEATURE_CLIENTS.journalPool`, DW-FP10: WoW Forever disables the journal, and its pool is your own gear): a journal entry loaded: every item-pool build waiting for its data (a simulation's, or test mode's since DW-84) reads the journal again once the burst settles (`modules/SimPool.lua`); with no build waiting it does nothing |
| `UI_INFO_MESSAGE` | `DW.OnHistoryInfoMessage` | the client's "Trade complete." (`Compat.IsTradeCompleteMessage`), before the close or within the grace after it, completes the trade: the offer's items you got mark the matching drops `received`, the items you gave your own `tradedAway`; sends `HistoryChanged`. Any other message, or no trade, returns at once |
| `UI_SCALE_CHANGED`, `DISPLAY_SIZE_CHANGED` | `DW.OnIconScaleEvent` | the client's UI scale or display size moved every pixel: each item button made so far whose effective scale changed re-snaps its icon edge to one physical pixel (`NS.IconStyle.Resnap`, `modules/IconStyle.lua`; the window's and the toast's Scale rows call it too, R5-ICON) |

AceDB's `OnProfileChanged`, `OnProfileCopied` and `OnProfileReset` callbacks are setup and stay up
while disabled. Events the client refuses are kept in `NS.rejectedEvents` and reported by the
`[Init]` summary and the diagnostics report.

### The simulator on LibKa0s-Sim-1.0

The simulator is LibKa0s-Sim-1.0 hosting DropWatcher's scenarios, world providers, event drivers,
restriction model and eight verbs (DW-02..DW-04, LibKa0s#54). The library owns the answer seam, the
session and its two-phase stop, the timeline's step machine, the `/dw sim` grammar and the step
panel; it reaches this addon's handlers only through `NS.DeliverEvent` above. The host contract
(LibKa0s `docs/api/Sim/version-2.3.10.3-docs.md`, *The host contract (H1–H10)*; the standard's
preview-mode, *The in-game simulator*) binds this addon, and each obligation is met here:

| | Obligation | Where DropWatcher meets it |
|---|---|---|
| H1 | Every simulated client read and outward action is a Compat member read at call time; senders and actions are guarded | `NS.Compat` routing (`core/Compat.lua`, `CompatWorld.lua`, `CompatItem.lua`); the chat sender, the inspect calls and the trade action in `core/SimSetup.lua`'s `GUARDED`; `test_sim_e2e`'s scan fails a module that names a world global the simulator answers |
| H2 | `Sim:NewSeam` straight after the Compat files, and `Unwrapped()` empty | `core/SimSetup.lua`'s TOC slot right after `core/CompatCollect.lua` (the last of the compat family), under a LOAD-BEARING comment; `test_sim_e2e` asserts `NS.SimSeam:Unwrapped()` empty |
| H3 | One `deliver` with the client's handler set and order | `NS.DeliverEvent` (`core/DropWatcher.lua`, this section above): the `NS.FEATURE_EVENTS` rows in order, `NS.rejectedEvents` skipped |
| H4 | Session-only storage for every saved write the capture path reaches, and a before/after test | `History.LogFor` (`modules/History.lua`) gives a simulated drop or trade the session's log, never `global.history`; `test_sim_core`'s `sim history` cases hold the saved history untouched |
| H5 | `refusal` covers stood-down, test mode and the world rules | `NS.SimHost.Refusal` (`modules/Sim.lua`): stood down, test mode, combat, an instance, a real group; test mode refuses while a simulation runs (`Test mode is not available while a simulation runs.`) |
| H6 | `Stop("standDown")` is the first stand-down step | `modules/Sim.lua` puts `NS.Sim:Stop("standDown")` first in `NS.STAND_DOWN` (it loads before every other module that adds one); the automatic stops say `group` and `instance` with their own lines |
| H7 | One Slash-1.0 feature-verb row, slash-only | the `sim` row in `settings/Slash.lua` calling `NS.Sim:RunVerb`; no key binding. Not slash-only any more: since LibKa0s v1.85.0 the launcher menu's Sim mode entry (`isSimMode` / `toggleSim`, `core/LauncherSetup.lua`; SG-RV) and Master controls' Sim mode box (R6-SIM) run that same verb through `NS.ToggleSim` (`core/DropWatcher.lua`), so a click prints what `/dw sim` or `/dw sim stop` prints; since R7-SIM the pair reads "panel shown or running" and an untick also closes the panel |
| H8 | A marker while a session runs, a diagnostics section and a debug tag | the cyan simulation strip under the filter bar (`f.simBanner`, `modules/Window.lua`; DW-10), the `SIM` title text while minimized or with no strip (`modules/WindowTitleBar.lua`, `SIM` in compact), the footer's `Simulating: <situation> · n members` line (`modules/WindowFooter.lua`), the `sim` diagnostics section (`modules/Diagnostics.lua`) and the `SIM` debug tag (the descriptor's `debug` sink) |
| H9 | The degradation stub, with surface parity | the seam stub in `core/SimSetup.lua` and the session stub in `modules/Sim.lua`; `test_surface_parity` holds both to the live surface |
| H10 | The panel position is session-only | the descriptor's `panel` (`modules/SimPanel.lua`) carries no `store`; migration 9 (`core/Database.lua`) retired the old `profile.simPanel` point, and `schema.md` names the position session-only |

The pool also keeps the journal's drops that are not gear, by item kind (`NS.SimPool.Extras`: the
tier tokens, mounts, pets, toys, recipes and cosmetics), so a loot burst draws one line in eight from
them and `/dw sim drop <kind> [player|me]` sends one item of a named kind (`NS.SimEvents.Drop`); a
kind the journal lists none of falls back to `NS.SimPool.COLLECTIBLE_SAMPLES`, curated ids that ship
empty until each is checked in the client (issue #13, DW-CAT6, smoke check COLL-8). Test mode's sixth
boss draws its item-kind samples the same way (`NS.TestMode.Source`).

## Frame layering

Every strata and frame level the addon sets reads one table, `NS.Constants.LAYERS`
(`core/Constants.lua`, frame-layering-§5), whose header comment states the whole stack with its
levels; every level is relative to the frame's parent. The tiers, low to high: the main window
(`MEDIUM`, toplevel, clamped) with its chrome, content and the Offer panel docked beside it; the
library's resize grip; the window's popover in its own strata, by level (the floating Offer panel);
the toast (`HIGH`, toplevel and clamped: LibKa0s-Toast-1.0 sets its
frame-layering T5 tier, which `LAYERS.STRATA.ALERT` names), with the roll popup mark's cards and the simulator's stand-in popup on the same tier (`modules/RollPopup.lua`, parented to UIParent, never toplevel); the Edit message box (`DIALOG`, toplevel), beside
the library's debug console, perf and sim panels; the library's Copy window (`FULLSCREEN`); the
library's dropdown menu (`FULLSCREEN_DIALOG`, the compact Filters ▾ cascade included); tooltips. Inside an item button, the border frame sits
under the upgrade glow. No frame changes strata at runtime. `tests/test_layers.lua` pins each class.

## Skins

The window and every surface around it are painted from the skin the player picks (LibKa0s-Skin-1.0,
skinning-§4): `core/SkinSetup.lua` registers the owner `DropWatcher` with its owner tokens (`dw.*`) and
publishes the facade `NS.Skin`. No look value is typed at a call site (anti-pattern #107): a color is
read from a library or owner token, a face from the skin, the monospace glyphs from `font.mono`. Under
Ka0s Default each is the pixel the addon drew before skins. The drop tables' tones keep their shape,
`NS.Constants.TONE[key]`, refilled from the tokens `C.TONE_TOKEN` names at load and first on every skin
switch; what the addon paints itself at build goes through `NS.SkinPaint`, which repaints it on a switch,
and the window, the Offer panel and every toast on screen repaint on `NS.Skin.OnLooksChanged`.
`tests/test_skin_chrome.lua` pins the chrome. The kit gates typed colors and textures (`test_skin_values`) and proves each declared surface changes on a skin switch (`test_skin_switch`, `tests/skin_switch_facts.lua`).

- **The choice.** The player picks on Settings → General → **Skin**, the library's own tab
  (`O.AppearanceTab` over `NS.SkinChoice` / `NS.WriteSkinChoice`, `settings/Panel.lua`): the skin
  source (the Ka0s skins, or EllesmereUI's when it can skin this addon), the skin, the Font and
  texture overrides, the Font outline (`skin.outline`, LibKa0s v1.82.0: HUD text only by default since
  v1.83.0, all text or off, applied with `Skin:SetOutline`) and the Scope (Ignore settings panel, Ignore fonts). The eight `skin.*` rows are
  `skipRender` rows of the one seam, so `/dw get|set` reaches the same values, and a pick calls
  `Skin:SetChoice` first: the repaint is live, with no reload. A profile switch, copy or reset applies
  the incoming profile's skin, scope, overrides and outline (`reloadProfile`). `tests/test_skin_setup.lua`,
  `tests/test_skin_outline.lua` and `tests/test_skin_settings.lua` pin the seam and the rows.
- **The HUD.** Drop Watcher's HUD is the item icon's border (Window › Icons). While **Use the skin's
  border** (`icons.borderStyleFromSkin`, the composer's `fromSkin = "icon"`, on by default) is on,
  the border's style and thickness are the skin's icon border family (`icon.borderStyle`,
  `icon.borderSize`); every skin's is Solid 1px since LibKa0s v1.85.0's R3-FIX. The thickness is
  physical pixels at the button's effective scale (`NS.Compat.PixelFactor`, as the library's
  `S.IconBorder`), re-snapped on a Scale row's write and on `UI_SCALE_CHANGED` and `DISPLAY_SIZE_CHANGED` (`NS.IconStyle.Resnap`), and its color is a window's `icon.outline` (Ka0s Default's #4D4D57), the toast's
  icon alone keeping the HUD's `icon.border` (`WG.ItemButton`'s `hud`; R5-ICON, the library's icon
  rule in its docs/api). Show border and the zoom stay the player's. Migration step 10 (`NS.ResetIconBorderToSkin`) turned the companion on once per stored
  profile (the rollout's O2) and kept the stored style. `tests/test_skin_hud.lua`.
- **The colors and the shadow (FS-DW-FLIP, causes D4, D5, D6; the owner's rulings of 2026-11-01).** A
  *Use the skin's ...* companion, on by default, stands in front of each stored value:
  `icons.borderColorFromSkin` (`icon.outline` in a window, `icon.border` on the toast, R5-ICON), `glow.<g>.colorFromSkin` (`dw.glowMain`,
  `dw.glowOffSpec`) and `window.tableFontShadowFromSkin` (`dw.tableShadow`). A class or quality color
  comes first and has no companion. The three owner tokens keep this addon's pixels under Ka0s
  Default, whose `glow.color` is gold and whose `hud.shadow` is none. Every shipped skin answers one
  `glow.color`, `sem.warband` and `icon.border` today, so the border's color and the glows move only
  once, leaving Ka0s Default; the shadow varies by skin. Migration step 11
  (`NS.ResetProfileToSkin`, `Skin.FollowOnce`) moves stored profiles once, recorded per profile in
  `skin.fullSkinReset`. `tests/test_skin_flip.lua`.
- **The window's own surfaces (FS-DW-FIX, causes A1, L4, L8, L9).** The flat button is `S.Button`,
  its box remapped to `dw.btnBg` and `dw.btnBorder`; the library does not reach `b.label` or `b.art`,
  which carry a state tone (decision D1), so `NS.WindowTitleBar.PaintButtonLook` draws an untoned one
  in `btn.text`, `btn.hover` and `btn.icon`. The detail boxes are `S.Card`, the tabs `S.Tab` (decision
  D11 reversed: they gain the skin's backing, and an idle label reads `tab.text`), the column heads
  `S.SortHeaderBar`, the footer `S.Footer`, the title bar `S.TitleBar` with `place` (the one `title.bg`
  layer: the window's `S.Shell` takes `noTopBar`), and a row takes `list.hover` through `S.ListRow`,
  from a cell or an item button inside it too (`NS.WindowRows.WashRowOf`). Without the
  library the tabs keep their text roles and underline. `tests/test_skin_host.lua`.
- **Headers on the band (R5-WIN, LibKa0s v1.85.0's `S.Band` and `S.Header`).** Every window's
  header sits on the title band S.Shell lays, flush inside the edge at its inset (`win.borderSize`
  in from a flat edge, else 1) and `title.height` high, as Ka0s Loot History's. The main window's
  title bar takes the band's rect (`S.Header` `bars`), so its title, mode words, badge and
  controls, anchored to the bar at y 0, sit on the band's middle; minimized, the window is the band
  and its two edges. The Offer panel and the Edit message box keep the band S.Shell draws, put
  their title (by `title.align`) and close on it through `S.Header`, and start their content
  `POPOVER_TOP` (36) down. The detail card is an expanded row with no header, and the toast opts
  out of the band. Without the library the builders' own anchors stand. `tests/test_header_band.lua`.
- **The first-run picker.** `NS.MaybeShowSkinPicker` shows the library's picker (`O.SkinPicker`)
  while the profile's `skin.pickerSeen` is false: two seconds after login, at a stand-up, and after a
  profile event; never while stood down, and a start in combat waits for combat's end. Its preview
  is test mode (`spec.preview`, LibKa0s OptionsSkinPicker 11, round 6): shown with the window hidden
  and test mode off, the picker turns test mode on through `NS.SetTestMode`, the seam `/dw test`, the
  launcher and the Master controls checkbox share; its eye toggles it (lit on, dimmed off); every
  close (Apply, Apply to all, the gear, the close control, Escape, `NS.HideSkinPicker`) puts back what
  the picker and the eye moved, and test mode's end closes the window only if its start opened it. A
  window already shown, or test mode already on, is left alone. Its gear opens General → Skin. Its title is the library's "Choose a
  skin", the addon's name on its own line above the dropdown (LibKa0s v1.81.0). Only the player's
  close writes `pickerSeen`. `/dw skin` (`NS.RunSkinVerb`, `O.SkinVerb`) opens it on demand, whatever
  `pickerSeen` says. `tests/test_skin_picker.lua`, `tests/test_skin_verb.lua`.
- **The settings panel.** Every AceGUI widget the pages acquire themselves is painted for this owner
  (`NS.SkinPaintAce`, restored on release), the Situations table's session-held cells repaint on a
  switch, and the Profiles page paints the tree AceConfigDialog draws (`NS.SkinPaintAceTree`).
  Nothing in the panel is painted while Ignore settings panel is on (a new profile's default): the
  cells go back stock, and the table's own headers, labels and stripes read `NS.SkinPanelColor`, which
  answers the Ka0s Default value while the panel is ignored.
- **What Ka0s Default changes.** Ka0s Default keeps every color, but three things look new under it:
  every string reads in Prototype (the library's Ka0s Default face since LibKa0s v1.82.0; Oxanium before) instead of Friz Quadrata, the title
  bar wears the shell's darker band, and the four scroll bars are the library's corridor and flat
  knob instead of the stock art (the rollout's DropWatcher calls D3 and D2). The smoke checks in `smoke-tests.md` → Skins say so.
- **Fonts, outline and widths (LibKa0s v1.82.0, the default moved in v1.83.0).** Window text is
  unoutlined by default (*HUD text only*, D-10); the Skin tab's Font outline (`skin.outline`) puts it
  on all text (*All text*) or takes it off everywhere (*Off*), and a stored mode stays. Every string outside the drop tables takes the skin's face and flags through `S.Font` /
  `S.Text`, its color from the skin's tokens and the verdict tones, and the verdict glyphs the mono
  role, which the skin never outlines. The drop tables' text is the one font setting (D-07, the lead's
  ruling on DW-01's review): Window › Layout › Tables carries the library's composed font block
  (`H.FontGroup` with `fromSkin` and `flagsFromSkin`, `settings/ComposedRows.lua`): Font
  (`window.tableFont`, read only while Use the skin's font, `window.tableFontFromSkin`, is off), Font
  size (`window.fontSize`, 0 Default as before), Font color and Use class color
  (`window.tableFontColor`, `window.tableFontClassColor`), Font flags (`window.tableFontFlags`, From
  skin by default, resolved by `S.FontFlags(v, "window")` through the Font outline; a picked flag wins)
  and Font shadow (`window.tableFontShadow`, with Use the skin's shadow). `NS.WindowRows` draws it on
  both tabs and both layouts through `S.HudFont`: one named font object per string (a 12.0.7 client
  draws a font object's shadow, not a runtime one),
  the color on the tables' plain text only (`WR.SetTone`; verdicts, qualities and classes keep theirs),
  read as the skin's plain color while the swatch is at its default, so the defaults keep the look the
  tables had (`tests/test_table_font.lua`). The glyphs keep their face and flags and take the size. No
  flag was stored before the block, so none migrates; and the addon draws no HUD text, so
  `S.HudFontSize` (D-09) reaches nothing. Each skin's
  body and title sizes are the library's, measured so every skin's text is as wide as Ka0s Default's.
- **Characters every face draws.** `tests/test_locale.lua` runs the kit's display-glyph guard
  (`T.assertDisplayGlyphs`, kit revision 45): a string outside the safe set fails unless it is drawn
  in the mono role and marked `glyph: mono` (the verdict glyphs ▲ ≈ ▼ and ⊘).

### Intentional exceptions

What stays out of the skin, each for its reason (the literal gate's allow-list carries the chat ones):

| What | Why |
|---|---|
| Chat output: the `[DW]` prefix, the command highlights, debug ON / OFF, the schema validator's errors | printed into the client's chat frame, not a frame this addon draws |
| `NS.GroupRoster.Colored`'s escape format | it writes the color its caller hands it (a token's, a class's) |
| The four secondary stats' name colors (`C.TONE.stat*`) | identity by hue: each stat is told from the others by its color |
| The upgrade glows' default colors (`C.TONE.glowMain`, `glowOffSpec`) | Ka0s Default's values of `dw.glowMain` and `dw.glowOffSpec`, and of the swatches a player sees with the companion off; the two hues mean main spec against off-spec |
| Item quality and class colors | game meaning; a quality reads the skin's `q.*` (Ka0s Default's are the client's own colors byte for byte since LibKa0s v1.81.0), and a quality the schema does not name the client's |
| GameTooltip's frame, StaticPopups, the launcher's button and menu | Blizzard or third-party frames (skinning-§7); the tooltip LINES this addon writes take skin colors |
| The Edit message box's `ChatFontNormal` face (`modules/DetailCard.lua`) | it previews a whisper, so it wears chat's own face (the rollout's DropWatcher call D6) |
| The icon border's `IS.SOLID_EDGE` (WHITE8X8) and `IS.BORDER_FALLBACK` (UI-Tooltip-Border) in `modules/IconStyle.lua` | LibSharedMedia key resolution for the border's edge file, not a color: what a style name draws when LSM has no path for it |

The resize grips are not on this list: every one, the main window's and the four tool windows', is
LibKa0s's grip given this addon as its skin owner (Core minor 14, `opts.owner`), so it follows the
skin's `icon.grip`, tinted under a skin that sets it and the client's own art under Ka0s Default and
WoW Default.

## Taint Notes

The window and the toast are plain `Frame`s, never secure, so showing, hiding and moving them are
allowed in combat and nothing defers (the toast waits out combat by choice, `toast.inCombat`). The
upgrade glow (`modules/Glow.lua`) is LibCustomGlow-1.0's plain frames parented to the window's
item buttons (never the toast's), none of them secure, so it starts and stops in combat too. Settings writes touch no protected frame. Opening the settings panel is refused
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
While a simulation runs (`modules/Sim.lua`), the seam over `core/Compat.lua` (`core/SimSetup.lua`,
LibKa0s-Sim-1.0's `NewSeam`) keeps the chat sender, the inspect calls and the trade action from the client
altogether: a send is printed with `[sim]`, a trade is printed, and nothing is inspected
or traded (simulator spec §5). The stop cancels every queued ask before it lifts its
simulated restrictions (its `OnStopGuarded` step), so nothing it queued can reach the real sender.
`NS.Sim:Fire` calls each handler under `pcall` (through `NS.DeliverEvent`), as the client's event
dispatch and the live shared dispatcher (`DW:OnSharedFeatureEvent`) isolate it, and the library's
stop runs each `OnStop` step under `pcall`, so one that raises never skips the rest nor the later stand-down steps; the
failure is a `SIM` debug line. While its combat edge is up, the simulator answers
`InCombatLockdown` and the player's combat flag `true` through the seam and never `false`, so a
caller that must not act in combat is never told it may (DW-90).
The roll popup mark (`modules/RollPopup.lua`, since DW-FP20) draws its own cards over Blizzard's
roll popups, `GroupLootFrame1..4`, which are plain frames on both clients (no secure template, no
protected attribute: R2 §10.1). Each card is parented to UIParent and anchored once BOTTOM to its
popup's TOP, so the card depends on the popup and never the other way round. The one call made on
a Blizzard popup is `HookScript("OnShow")` and `HookScript("OnHide")`, installed once at enable
through `core/CompatLoot.lua` (`Compat.HookRollPopup`); `hooksecurefunc("GroupLootFrame_OnShow")`
is not used, because the XML binds that function at load. The hooks can't be removed, so their
bodies gate on the disabled state; OnShow re-checks the popup is still shown with a plain rollID
(`Compat.RollPopupOpen`), because Blizzard can close it inside its own OnShow. Nothing is written to
a popup or its table: no field, no `SetScript`, `SetParent`, `SetPoint` or strata change, and the
buttons (on the frame on Retail, in `LootButtonContainer` on Forever) are never touched, so the
container's managed layout is not tainted. None of it is protected, so it draws in combat too.
The master-loot pending kind (`modules/PendingML.lua`, DW-FP18) only reads the loot window you
opened, through `core/CompatLoot.lua` (`LootSlots`: each slot's link, quality, lock and source GUID,
after LOOT_READY or LOOT_OPENED); it never touches the loot frame or its buttons, never loots a slot
and never calls a master-loot assignment.
The addon's three confirmations, Clear history (`modules/History.lua`'s `AskClear`, since DW-Q3), a
shorter Keep history for (`modules/HistoryRetention.lua`, since DW-A5) and Reset all settings
(`settings/Schema.lua`), set `preferredIndex = 3`, so none shares a StaticPopup slot with
Blizzard's own dialogs (DW-62).

## Known Limitations

What the addon does not do yet, or cannot know without the client. In short: no in-game check has a
recorded client pass yet, so the encounter-time chat and loot readings and the raid trade rule are
unconfirmed; a non-English client shows no upgrade-track change; a delve's tier is not read, and a
tier token's slot is read from its English text (TT-1), and a token it misses is judged in any slot; a caged
battle pet (a `|Hbattlepet:` link) is never watched, a recipe's known state is read from its
*Already known* tooltip line (`ITEM_SPELL_KNOWN`), a lockbox from its *Locked* or *<Right Click to
Open>* line (RX-04), the rolled-on catch-all sees only rolls (never a master-loot hold), and the item kinds and item lists apply to new
drops only; your gear is a per-slot best, not a loadout planner; your own drop is offered only while another player is in your group (never to followers or a delve companion); an off-spec is judged on item level alone, and a looter's on the gear they wear; a reload brings the
session's drops back (a cleared one stays cleared, an asked one reads Asked) but starts a new key
header mid-key and forgets who your own drops were offered to, and a relog starts an empty Drops tab
(the session is the login); the roll popup mark is not drawn in WoW Forever's gamepad mode, whose roll list (`GamepadGroupLootRollFrame`) is not the four popups; the roll clock's units and when a roll's numbers appear are unconfirmed (probes P-R1 and P-R4); under master loot two copies of one item on one corpse collapse to one awaiting item, and a raider may not see the master looter's slots at all (probe P-ML1); the simulator and test mode have no master-loot timeline step or sample beyond `/dw sim ml`; the Forever port's features have no recorded client pass yet; the History card shows only what a kept entry holds; Insights reads only the kept history (the
retention window, pruned a whole group at a time), infers asks and offers from trades settled before
they were stamped (so the old success rate reads high, and an old gain is the verdict as last
judged), has no per-boss breakdown inside a Mythic+ key, and reads a collectible recorded before
issue #13 as equipment; an install
missing LibKa0s shows no toast (its shell is LibKa0s-Toast-1.0); and a simulation does not exercise every live
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
| `module-map.md` | Every non-vendored file, its responsibility, and the TOC load order (the off-spec pass `modules/OffSpec.lua` and its look `modules/OffSpecCells.lua` included, the upgrade glow `modules/Glow.lua` and every item icon's look `modules/IconStyle.lua`) |
| `schema.md` | The SavedVariables shape, every default, and the migration path |
| `settings-panel.md` | The `Page \| Covers` table and the page → tab → row tree |
| `data-flow.md` | The loot pipeline end to end, then each stage: a setting written, the show decision, the repaints, the feed, inspecting, the trade timer, the sends, the history, the Insights tab, the toast and auto-ask, and the off-spec verdict with its tones and ask precedence, Can't use and Trade's Can't use in dim red, and the upgrade glow |
| `common-tasks.md` | Recipes for the changes made most often here |

### Conditional (documentation-§3, Tier 2)

| Doc | Status | Trigger |
|---|---|---|
| `perf-analysis/README.md` | Present | The performance harness is wired (`core/PerfSetup.lua`) |
| `slash-dispatch.md` | Present | 34 commands in `NS.COMMANDS` |
| `profiles.md` | Present | The Profiles page ships in the options UI |
| `debug.md` | Present | The diagnostics dump ships in every addon (debug-logging-§14) |
| `midnight-quirks.md` | Present | Always (documentation-§3): the vendored catalog block (client-quirks-§1), then the addon's own client-version workarounds; `core/Compat.lua` carries the addon's own client-version workarounds (secret guards on tooltip and gate answers, the deprecated-global fallbacks, enums by name, the trade-time decode) |
| `compat-layer.md` | Present | The compat family publishes 121 addon-specific shims (three or more), counted across the family per documentation-§3: `core/Compat.lua` 59, `core/CompatClient.lua` 11, `core/CompatLoot.lua` 8, `core/CompatWorld.lua` 18, `core/CompatItem.lua` 5, `core/CompatJournal.lua` 5, `core/CompatCollect.lua` 15 (`cat core/Compat*.lua \| grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'`) |
| `message-bus.md` | Present | 11 messages are defined, more than ten (`PENDING_CHANGED`, DW-FP14, was the eleventh) |
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
| `forever-probes.md` | The WoW Forever port's in-game probe sheet: each open read of the port's design and research, a line to type and what to read (linked from `smoke-tests.md` and `known-limitations.md`) |

## Documented deviations

The single home for a ratified deviation from the Ka0s WoW Addon Standard (documentation-§3). A
deviation not in this table is not ratified.

| Rule | What differs | Why | Decided | Re-check trigger |
|---|---|---|---|---|
| library-stack-§7, anti-pattern #47 | The chat sender (`Compat.ChatSender`) and the tooltip line reader with its duration decoder (`Compat.ReadTooltipLine`, `DecodeDuration`, its parsing in `core/TextParse.lua`) are written in this addon, not taken from LibKa0s | No LibKa0s major carries them, and MultiMeters' `ChatSender` is the only other copy; the promotion bars (two consumers with the same semantics) are not met. The LibKa0s promotion issue, [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14), was rejected | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major (v1.72.0 moves Perf.lua to minor 15 and the kit to revision 39 only). Re-checked 2026-10-22 against LibKa0s v1.75.0: LibKa0s#49 was ruled will-not-do, the chat sender for having no content (its fallback rung is unreachable on every admitted client) and the reader and decoder for having one consumer; the recorded rejection is the library repo's `docs/api/Compat/version-1-docs.md`, *Censused for #49 and rejected* and the standard's `open-evolutions`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | The chat sender: Blizzard moves or reshapes the send API again so the resolver's second rung becomes reachable, or a third roster addon sends chat through the API with the same resolution. The reader and decoder: a second roster addon reads tooltip lines with first-answer semantics keyed by `Enum.TooltipDataLineType`, or decodes a whole localized duration sentence from the client's GlobalStrings |
| (no rule yet) chat sent by an addon | The addon whispers and posts to group chat on the player's behalf: an ask or offer whispered to one member, an ask whispered to the master looter for an item awaiting them (`askML`, DW-FP19, both clients, the same guards), an announce to INSTANCE_CHAT, RAID or PARTY, each from a click or, when queued under a restriction, from the 1.5-second flush timer (`modules/Asks.lua`) | The standard has no rule for addon-sent chat. The addon holds itself to design spec §9: one send per click, the one-ask guard, the 255-byte limit, the restriction queue, `pcall` around the sender, never SAY or YELL, a confirmation line per send, and test mode printing instead. A WowAddonStandards proposal issue is filed as [WowAddonStandards#11](https://github.com/tusharsaxena/WowAddonStandards/issues/11) (design spec §14) | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): WowAddonStandards#11 is still open and the standard (v2.81.0 branch) has no addon-sent-chat rule, so the trigger has not fired. Re-checked 2026-10-22 against the standard v2.86.0: the rule is still absent (the chat-sender row of LibKa0s v1.75.0's `docs/api/Compat/version-1-docs.md`, *Censused for #49 and rejected*, says addon chat-send policy belongs in the standard, which has not adopted one) | The standard adopts a rule for addon-sent chat |
| library-stack-§7, anti-pattern #47 | The loot parser (`modules/LootParser.lua`: the `LOOT_ITEM*` GlobalStrings compiled into patterns for every looter, rebuilt when the globals change, the upgrade and crafting echoes rejected) is written in this addon, not taken from LibKa0s | No LibKa0s major parses loot lines. LootHistory carries the only other parser (`core/Util.lua`), and it reads the player's own loot only, so the semantics differ. The LibKa0s promotion issues, [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14) and [LibKa0s#51](https://github.com/tusharsaxena/LibKa0s/issues/51) (its second candidate), were rejected for it | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major. Re-checked 2026-10-22 against LibKa0s v1.75.0: the parser was ruled will-not-do under #49 and #51 for a correctness disagreement, not only scope (LootHistory treats crafting and refund lines as receipts, this addon rejects crafting lines and has no refund shape); the recorded rejection is the library repo's `docs/api/Item/version-3-docs.md`, *What this major is not* and the standard's `open-evolutions`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | A second addon needs every looter's loot **and** the consumers agree in writing on which line kinds are receipts (crafted, refund, bonus roll, pushed), or a third loot addon appears whose receipt set matches one of the two exactly. LootHistory needing third-person loot alone does not fire it, because it leaves the crafted-line disagreement in place |
| library-stack-§7, anti-pattern #47 | The item read (`core/ItemRead.lua`: how complete a link is, the better of two links, an item's identity, the gear level read detailed-then-base, the exact level and quality at a bag location, the quality of a link) is written in this addon, shaped as the API LibKa0s-Item-1.0 would take, not taken from LibKa0s | Rejected for promotion ([LibKa0s#51](https://github.com/tusharsaxena/LibKa0s/issues/51)); stays in-addon by ruling. LibKa0s-Item-1.0 carries identity primitives (`ItemIDFromLink`, `QualityFromLink`, `QualityLabel`, `LoadItem`) and, from minor 3, `BonusIDsFromLink`, the one piece #51 promoted (its adopters are Bank Ledger and Loot History). This addon keeps its own link walk because it also reads the modifiers. The other reads have one consumer or disagreeing semantics: Loot History reads gear levels with its own `GetItemExtras` / `GearItemLevel` under a different non-gear rule and gate, Bank Ledger reads base `GetItemInfo` only, and the bag reads route through this addon's simulator seam. The run built in-addon first (ui spec §0) | 2026-10-11 (ui spec §0). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): Item.lua stays at minor 2. Re-checked 2026-10-22 against LibKa0s v1.75.0: Item.lua moves to minor 3 with `BonusIDsFromLink` only, and LibKa0s#51 was ruled will-not-do for `LinkDetail` / `BetterLink`, `IdentityKey`, `EffectiveItemLevel`, `ItemLevelAt` / `QualityAt` and `QualityOf`; the recorded rejection is the library repo's `docs/api/Item/version-3-docs.md`, *What this major is not* and the standard's `open-evolutions`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | Per read, the trigger the library repo's `docs/api/Item/version-3-docs.md`, *What this major is not* records: a second addon must merge two reports of one item from sources whose links differ in completeness; a second addon tells variants of one item id apart; this addon and Loot History settle on one non-gear rule and one gear gate (or a third addon needs a gear level read); a second addon reads an exact level or quality at an `ItemLocation`; or Bank Ledger adopts the color fallback for uncached quality |
| library-stack-§7, anti-pattern #47 | The restriction tracker (`modules/Restrictions.lua`: the restriction event's hints, the chat lockdown and the combat edges folded into `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason`) is written in this addon, not taken from LibKa0s | No LibKa0s major tracks the 12.0 restrictions. AuraMaster, ConsumableMaster and MultiMeters react to `ADDON_RESTRICTION_STATE_CHANGED`, but to re-run their own work, not to answer what is allowed, so the semantics differ. QuickComms carries a copy of this tracker whose announce edge differs (it also has no `CanInspect` / `CanTrade`). The LibKa0s promotion issue, [LibKa0s#49](https://github.com/tusharsaxena/LibKa0s/issues/49) (design spec §14), was rejected | 2026-10-10 (design spec §2, §14). Re-checked 2026-10-14 against LibKa0s v1.72.0 (DW-P22): no new major. Re-checked 2026-10-22 against LibKa0s v1.75.0: LibKa0s#49 was ruled will-not-do for the tracker (a same-author copy under ten days old whose edges already diverged) and deferred the four restriction readers as guards; the recorded rejection is the library repo's `docs/api/Compat/version-1-docs.md`, *Censused for #49 and rejected* and the standard's `open-evolutions`, *Further `LibKa0s` modules*, *Recorded rejections, LibKa0s#46–#58* | At least two of: a third roster addon, not a copy, needs a restriction answer set; this tracker and QuickComms' copy converge on one announce edge and one answer set; 12.2 ships with no change to `Enum.AddOnRestrictionType`, the event payload or the chat-blocking classification |
| localization-§4 (anti-pattern #37) | A tier token's slot is read from its own text against English words held in the enUS locale table (`locales/enUS.lua`, the TT-1 block): its Use text (the `appropriate for your class` phrase and `set <slot> item`) and, for an older class-group token, the slot nouns in its item name (`Gauntlets of the Foreseen Conqueror`); an omni Curio is told by its name ending in `Curio`. The parsing is `core/TextParse.lua`'s, handed the locale table's words | No ID-based answer exists without a hand-kept itemID table each season, which the owner's TT-1 request rules out; no GlobalString carries these phrases. A miss degrades, unevenly. On a non-English client the Use-text and name rungs match nothing: a token with a Classes line is read by its localized tooltip slot line where it has one (`Compat.TierTokenSlot` matches the client's `INVTYPE_*` GlobalStrings), else judged as `any` slot (the best of the five tier slots); a Curio, or a token with neither a Classes line nor the English Use phrase (the Midnight tokens), is not seen as a token at all and is judged as the plain item it is (`unknown`, not gear). The `any` fold can also pick a slot the token does not make (it tries all five tier slots), on English clients too, for a token whose text names no slot. Curio detection by name works on English clients only | 2026-11-05 (owner, TT-1) | A non-enUS locale ships, or Blizzard exposes a token's slot through an API or an ID field |
| localization-§4 (anti-pattern #37) | `C.TRACK_TIER` (`core/Constants.lua`) maps an upgrade track's English name (`Explorer`, `Adventurer`, `Veteran`, `Champion`, `Hero`, `Myth`) to its tier, the fallback `ItemFacts.TrackTier` takes when the track carries no `trackStringID` that `C.TRACK_TIER_BY_STRING_ID` knows | That id table is still empty (smoke check `FEED-5` records the client's ids), so the English name is the only ID-less key to a track's order. A miss degrades safely: a localized track name matches nothing, the tier stays nil and the kernel leaves the track delta unset, never a wrong one | 2026-11-05 (owner, by the TT-1 ruling) | A non-enUS locale ships, or `C.TRACK_TIER_BY_STRING_ID` is filled from the client's ids |
| options-ui-§17 | the class-color companion sits below its swatch in the tab's mirrored two-column layout | owner's choice: main spec left, off-spec right on every row | 2026-10-18 | the next options-ui-§17 edit, or LibKa0s gaining a mirrored color-pair layout |

### Files over the 1500-line cap

The layout-§1 census of authored `.lua` files over the 1500-line cap. Vendored code (`libs/`,
`tests/_kit/`) is out of scope, and the repository has no generated data.

Nothing is over the cap today. `locales/enUS.lua` came back under it when the settings panel's
strings moved to the topic file `locales/enUS_Settings.lua` (feedback-21), and it left the
1000-line band when the tooltips' rows moved to `locales/enUS_Tooltips.lua` (2026-10-31), both split
on localization-§6's shape, which owes no row here.
