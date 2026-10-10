# Module map — Ka0s Drop Watcher

Every non-vendored file, its responsibility, and the TOC load order. `libs/` (Ace3, LibSharedMedia,
LibDataBroker, LibDBIcon, LibKa0s v1.71.0 whole) and `tests/_kit/` are vendored and never edited.

## Load order (the TOC)

| # | File | Kind | Responsibility |
|---|---|---|---|
| 1 | `locales/enUS.lua` | data | `NS.L`, the metatable fallback; the key is the English string |
| 2 | `core/Namespace.lua` | data | name, version, brand, the cyan `[DW]` tag, the slash and its alias |
| 3 | `core/CoreSetup.lua` | setup | LibKa0s-Core: the printer, the secret-safe stringifier, the SafeRegister family, the skin, the close-button wrapper, the resize grip |
| 4 | `core/Compat.lua` | edge | `NS.Compat`: LibKa0s-Compat's secret guards, and the only caller of version-variant, deprecated and optional client APIs (the chat sender, the tooltip line reader and the trade-time decoder, the upgrade track, the restriction APIs, the player's normalized realm and spec, the bind helpers, the inventory and bag readers, the inspect calls and the `NotifyInspect` hook, the item readers, the Pawn seam, the trade actions); see [`compat-layer.md`](compat-layer.md) |
| 5 | `core/MediaSetup.lua` | setup | LibKa0s-Media: `NS.Icon`, `NS.MediaFont`, the one RegisterLSM call |
| 6 | `core/Constants.lua` | data | `FONT_MONO`, the window geometry, the gold; the item, quality, slot, bag, difficulty and situation ids, the slot plans, the trade rules |
| 7 | `core/ClassData.lua` | data | `NS.ClassData`: class armor types, weapon proficiencies, every Retail spec (Devourer included) with its primary stat and dual-wield, Titan's Grip, shield and off-hand flags, and the pure lookups over them |
| 8 | `core/State.lua` | state | session-only state: debug flag, test mode, the player's window choice, the current situation and its inputs, the restriction tracker's hints, combat edge and last announced answers, the roster as last read, the item facts cache, the gear snapshot, the loot parser's counters, the inspect broker's entries and queue, the feed's drops, groups, dedupe window and encounter context, the trade timer's entries |
| 9 | `core/EnvSetup.lua` | setup | LibKa0s-Env: `NS.Meta`, `NS.Version` |
| 10 | `core/PoolSetup.lua` | setup | LibKa0s-Pool: `NS.Pool` (rows, from the feature items) |
| 11 | `core/ItemSetup.lua` | setup | LibKa0s-Item: `NS.Item` (link parsing and the item load, read by `modules/ItemFacts.lua`) |
| 12 | `core/Bus.lua` | setup | LibKa0s-Bus: `NS.MSG` (the strict catalog) and `NS.Bus` (tracked receivers) |
| 13 | `core/LifecycleSetup.lua` | setup | LibKa0s-Lifecycle: the stand-down latch, `NS.IsStoodDown` |
| 14 | `core/PerfSetup.lua` | setup | LibKa0s-Perf: `NS.Perf`, the declared buckets |
| 15 | `core/DebugLogSetup.lua` | setup | LibKa0s-DebugLog: the console, `NS.Debug` and its gates, the diagnostics descriptor |
| 16 | `core/DropWatcher.lua` | lifecycle | AceAddon registration, the feature-event registration (an event two modules declare fans out through `OnSharedFeatureEvent`), `NS.StandDown` / `NS.StandUp`, the shared host handlers, profile callbacks |
| 17 | `core/Database.lua` | data | the schemaVersion migration runner |
| 18 | `core/LauncherSetup.lua` | setup | LibKa0s-Launcher: the one LDB object, registered twice |
| 19 | `defaults/Profile.lua` | data | every default value (`NS.C`) |
| 20 | `modules/Evaluate.lua` | kernel (pure) | `NS.Evaluate`: the verdict kernel of design spec §5, equippability, the slot plans, the deltas and the verdict; no WoW call |
| 21 | `modules/QualityGate.lua` | kernel (pure) | `NS.QualityGate`: the minimum-quality gate of design spec §6.2, the three modes, the floor, the upgrade override, the per-situation mode and the filter bar label; no WoW call |
| 22 | `modules/Situations.lua` | classifier + edge | `NS.Situations`: the situation classifier of design spec §6.1 (pure `Classify` and `Resolve`), the edge that reads the client on six events and sends `SituationChanged`, and the per-situation track, auto-open and quality answers |
| 23 | `modules/TradeRules.lua` | kernel (pure) | `NS.TradeRules`: the trade estimator of design spec §7.1-§7.3, the bind checks, the rule per situation with the owner's override map, the trade window and the looter's item level; no WoW call |
| 24 | `modules/Messaging.lua` | kernel (pure) | `NS.Messaging`: the messaging core of design spec §9.1-§9.2, the templates and their tokens, the length check, the one-ask guard and the send queue's states; it sends nothing and makes no WoW call |
| 25 | `modules/Restrictions.lua` | edge | `NS.Restrictions`: the restriction tracker of design spec §4, `CanSendChat`, `CanInspect`, `CanTrade` and `ActiveReason` from `ADDON_RESTRICTION_STATE_CHANGED`, the chat lockdown and the combat edges; sends `RestrictionChanged` |
| 26 | `modules/Roster.lua` | edge | `NS.Roster`: the group's members of design spec §4 by GUID (Name-Realm, unit token, classFile, specID, online) re-read on `GROUP_ROSTER_UPDATE`, and `Resolve` from a GUID, a Name-Realm or a bare name, a same-name tie settled by classFile |
| 27 | `modules/ItemFacts.lua` | edge (cached) | `NS.ItemFacts`: an item link turned into the facts of design spec §5.1 (levels, slot, class, quality, binds, the upgrade track and its tier, stats, specs, uniqueness, tier tokens, appearance), cached by link; an uncached item loaded through LibKa0s-Item's `LoadItem`, retried on its callback |
| 28 | `modules/Gear.lua` | edge | `NS.Gear`: your own gear snapshot of design spec §4, each worn slot at its current level and the best item you own per slot (bags included), rebuilt on `PLAYER_EQUIPMENT_CHANGED`, `BAG_UPDATE_DELAYED` (deferred to the combat's end while fighting; worn slots kept as read on a bag-only rebuild; only bag items with a slot plan asked of the item facts) and your spec change behind one throttle, bracketed in `gear.rebuild`; the candidate table the verdict kernel takes for you and the per-slot qualities the quality gate reads; sends `GearChanged` |
| 29 | `modules/LootParser.lua` | edge | `NS.LootParser`: a `CHAT_MSG_LOOT` line turned into the looter (resolved through the roster), the item link, the quantity and the kind (loot, bonus roll or pushed), with patterns compiled from the client's `LOOT_ITEM*` GlobalStrings and rebuilt when another addon rewrites them; the upgrade and crafting echoes rejected, secret lines counted and dropped; each receipt handed to the feed's sink |
| 30 | `modules/Inspect.lua` | edge | `NS.Inspect`: the inspect broker of design spec §8, another member's worn gear (links and tooltip levels) and spec read through one spaced `NotifyInspect` at a time, a priority queue (looters, Offer-panel candidates, warm-up), the range, identity and ready timeouts, the incomplete-link retries, the fast path, the foreign-inspect hook, opportunistic reads, the combat park, the 600s cache invalidated on `UNIT_INVENTORY_CHANGED`, the warm-up and `Scan`; the candidate table the verdict kernel takes for a member; sends `InspectDone` |
| 31 | `modules/LootFeed.lua` | orchestrator | `NS.LootFeed`: the feed of design spec §3 and §6, each drop taken from `CHAT_MSG_LOOT` (the parser's sink), `ENCOUNTER_LOOT_RECEIVED` and `C_LootHistory`, the reports of one drop merged, drops grouped by encounter or keystone run, the situation gate, the filters and the quality gate before any inspect, the verdicts for you and for the looter, the trade estimate (re-made on a 30s sweep and on each `TradeTimerTick`, your own drops' with the exact timer folded in), your own drops' candidates, the score retry, `Add` for `/dw add` and test mode; sends `DropAdded` and `DropUpdated` |
| 32 | `modules/TradeTimer.lua` | edge | `NS.TradeTimer`: the exact trade countdown of design spec §7.4 on your own drops, each one's bag item matched by link then item id and read for its `TradeTimeRemaining` line (or the localized sentence, decoded) on `BAG_UPDATE_DELAYED`, `LOOT_CLOSED` and your own `DropAdded`, at most one scan per 2s; expiries keyed by item GUID; one shared ticker (1s with the window shown, 60s hidden, off with nothing live); the warning once per item at `trade.warnAt`; sends `TradeTimerTick` and `TradeTimerExpiring` |
| 33 | `modules/TradeHelper.lua` | edge | `NS.TradeHelper`: the click-driven trade actions of design spec §4: `Give(dropID, target)` finds your drop's bag item by its GUID (the trade timer's slot first, then a walk of the bags) and hands it over with `PickupContainerItem` and `DropItemOnUnit`; `Open(target)` is `InitiateTrade`; `CanGive` and `CanTradeWith` check without acting. Each refusal is a reason with its tooltip line (`ReasonText`): disabled, combat, not a member, yourself, offline, out of trade range, not in the bags, expired, a busy cursor, no API. No events, no timers, no messages |
| 34 | `modules/Asks.lua` | edge | `NS.Asks`: the messaging edge of design spec §9.2-§9.3 (the pure core is `modules/Messaging.lua`): `Request(kind, target, dropID, opts)` resolves the recipient through the roster, builds the tokens from the drop, runs the core's guard and length check, and sends through `Compat.ChatSender` inside `pcall` with one confirmation line, or queues while chat is restricted; `Flush` on `RestrictionChanged`, `ENCOUNTER_END` and `CHALLENGE_MODE_COMPLETED`, one send every 1.5s; `Press` and `Cancel`, and the asks queued to a member who left canceled on `GROUP_ROSTER_UPDATE`; test mode prints instead of sending; sends `AskStateChanged`
| 35 | `modules/Window.lua` | UI | the main window's shell and its show decision; tells visibility listeners (the trade timer) on every show and hide |
| 36 | `modules/Diagnostics.lua` | sections | the addon's sections of `/dw diagnostics` |
| 37 | `settings/SchemaSetup.lua` | setup | LibKa0s-Schema, or the host's documented stub of it |
| 38 | `settings/Schema.lua` | settings | the rows, the write seam, the shared reactions, the defaults tree, the global reset |
| 39 | `settings/OptionsSetup.lua` | setup | LibKa0s-Options: the panel descriptor |
| 40 | `settings/Panel.lua` | settings | the landing page and the General page (Master controls) |
| 41 | `settings/Slash.lua` | setup | `NS.COMMANDS` and the LibKa0s-Slash descriptor |
| 42 | `settings/Profiles.lua` | settings | the Profiles page (AceDBOptions) |

Why each position is load-bearing or conventional is written beside its line in `DropWatcher.toc`
(toc-file-§5). The planned feature modules and the files they add are listed in design spec §4.

## Tests

| File | What it is |
|---|---|
| `tests/run.lua` | the load list, the three factories, the kit facts and the suite list |
| `tests/loader.lua` | the instance factory: TOC files plus `LibKa0s.xml`'s files, isolated per case |
| `tests/wow_mock.lua` | the thin extender over `tests/_kit/mock_base.lua` |
| `tests/test_*.lua` | one suite per subject (see [`testing.md`](testing.md)) |
| `tests/perf.lua` | the offline scenarios, outside the gate |
