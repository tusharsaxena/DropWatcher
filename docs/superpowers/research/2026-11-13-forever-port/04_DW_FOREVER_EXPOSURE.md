# 04 — DropWatcher's exposure to WoW Forever: every place the port must touch

Research note for the WoW Forever port (branch `feat/2026-11-13-forever-port`, 2026-11-13).
Read-only on all code. This note is the only file written.

Tags: **MEASURED** = seen in source, docs, a SavedVariables file or a command run here.
**REPORTED** = a third party or earlier research says so. **INFERRED** = my reading; it needs a probe or a test.

Scope: DropWatcher's shipping code (`core/`, `modules/`, `settings/`, `defaults/`, `locales/`), not `libs/`,
`tests/` or `tools/`. Loot rules, roll data and the loot pipeline are notes 01, 02, 03 and 05 beside this one.
This note names loot only where it is an exposure.

Paths used:

- `WF/` = Gethe/wow-ui-source `forever`, 1.60.1 (70888), sparse clone at
  `/tmp/claude-1000/-mnt-d-Profile-Users-Tushar-Documents-GIT-DropWatcher/8e7a7246-e9bd-4614-aaea-6144aa02c981/scratchpad/wus-forever/Interface/AddOns/`
- `KF/`, `KL/` = Ketho/BlizzardInterfaceResources `forever` and `live` (`Resources/Events.lua`,
  `Resources/GlobalStrings/enUS.lua`), fetched to
  `/tmp/claude-1000/-mnt-d-Profile-Users-Tushar-Documents-GIT-DropWatcher/8e7a7246-e9bd-4614-aaea-6144aa02c981/scratchpad/ketho/`
- `FV/` = `/mnt/g/Games/Blizzard/World of Warcraft/_forever_/` (the owner's install)
- `LK/` = `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` (tag v1.95.0)
- `QC/` = `/mnt/d/Profile/Users/Tushar/Documents/GIT/QuickComms` (master)
- `STD/` = `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards/standards/standards/`
- `CT/` = `/mnt/d/Profile/Users/Tushar/Documents/GIT/Ka0sAddonsCommonTasks/docs/`

## 0. The short version

1. **Forever has almost every API DropWatcher calls.** The kit's missing-globals scan, forced to check
   Forever, finds **0** findings in DropWatcher's code (section 2). Every event DropWatcher registers exists on
   Forever (36 of 36), and every GlobalString it reads has the same text on both clients. **MEASURED.**
   The breakage is in **game data and game rules**, not in missing functions.
2. **The spec table is the biggest break.** `core/ClassData.lua:81-121` is the Retail 12.x spec table. On
   Forever every class has one spec (the Hunter's is `1485`, named "Hunter", measured), so every lookup keyed by
   spec ID answers nil. Under the forever kit profile **8 tests fail**, all spec-driven (section 2).
3. **Pawn scoring stops on Forever.** `Compat.PawnScaleForSpec` and `PawnVisibleScale` translate a spec ID to a
   Pawn index through `ClassData.SpecIndex` (`core/Compat.lua:757-804`). `1485` has no index, so both answer nil.
   Pawn on Forever has no spec at all (`SpecsExist = false`) and keeps one scale per classic talent tree.
4. **LibKa0s-Role-1.0 covers the player's spec and role only.** It does not give a primary stat, armor or weapon
   rules, dual wield, shields, off hands, a Pawn index, or anything about another unit (section 4).
5. **Names break in 10 places.** The roster builds `"First-Surname"` from `UnitName`'s two returns
   (`modules/Roster.lua:97-101`). Chat names the looter `"First Surname"`, so lookups miss, and whispers go to a
   wrong name (section 6).
6. **Forever has the ranged slot (18).** DropWatcher maps bows, guns, crossbows and wands to the two hands
   (`core/Constants.lua:429-431`). On Forever they go in slot 18, with thrown weapons and relics (section 9).
7. **Retail-only features must be absent on Forever, not hidden** (clients-§4): Mythic+, delves, follower
   dungeons, LFR, the Encounter Journal pool, transmog, upgrade tracks, the trade window timer, off-spec asks.
   DropWatcher has no client gating today: no `IsForever`, `IsRetail`, `ClientKey` or `ForClient` call anywhere
   in its code. **MEASURED** (`grep -rn "IsForever\|ClientKey\|ForClient" core modules settings defaults`: none).
8. **LibKa0s must be re-vendored.** DropWatcher holds v1.93.0 (Compat minor 3, Skin minor 17, kit 53). The port
   needs v1.94.0+ for `UnitCharacterName`, `CharacterKey` and `Skin:DefaultSkin`, and v1.95.0 for Role.

## 1. Baseline (2026-11-13)

| Check | Result | Tag |
|---|---|---|
| `lua tests/run.lua` (retail profile) | 2242 passed, 0 failed, 1 skipped, 2243 total | MEASURED |
| `KA0S_KIT_CLIENT=forever lua tests/run.lua` | 2234 passed, **8 failed**, 1 skipped, 2243 total | MEASURED |
| `docs/test-cases.md` Total | 2239 (`docs/test-cases.md:2720`): 3 cases stale, the known kit-53 drift (`CT/2026-11-07-WOW_FOREVER_PORT_STEP5/01_WAVE1_PLAN.md:21-24`) | MEASURED |
| README tests badge | `2239/2239` (`README.md:7`) | MEASURED |
| TOC | `## Interface: 120105`, no gating line (`DropWatcher.toc:1`) | MEASURED |
| Roster row | `Retail (port pending)` (`WowAddonStandards/standards/ADDONS.md:24`) | MEASURED |
| README opening | "Retail only for now; WoW Forever support is planned." (`README.md:9`) | MEASURED |
| Vendored LibKa0s | Compat minor 3 (`libs/LibKa0s/Compat.lua:92`), no `UnitCharacterName`, no `DefaultSkin`; kit `VERSION = 53` | MEASURED |

## 2. The kit run under the forever profile, and how the kit is driven

### 2.1 The 8 failures (all spec)

Each one is a spec read that answers nil, because the forever profile removes `GetSpecialization`,
`GetSpecializationInfo`, `GetActiveSpecGroup` and `GetTalentInfo` (`tests/_kit/mock_client.lua:24-29`). **MEASURED.**

| Test | Assert | Root |
|---|---|---|
| compat: PlayerSpecID reads the index then its spec id… | expected 72, got nil | `core/Compat.lua:285-293` |
| scoring: the feed judges your drop with your weights once they are set | expected -50, got nil | weights keyed by spec |
| gear: the candidate carries the class, the spec and the hand flags from ClassData | expected 260, got nil | `modules/Gear.lua:131` |
| gear: with Titan's Grip a two-hander can fill the off hand too | `tests/test_gear.lua:189` indexes nil | `CD.SPECS` row |
| gear: the candidate brings its off-spec gear… Holy against the bag mace | expected cantUse, got unknown | `modules/OffSpec.lua:145` |
| gear: the player's spec change rebuilds; another unit's does not | expected 1, got 0 | `PLAYER_SPECIALIZATION_CHANGED` path |
| diagnostics: the gear section lists the stored slots… | output mismatch | spec line |
| diagnostics: the scoring section names the scorer… | output mismatch | spec line |

These tests install Retail spec mocks. On Forever they test a shape the client does not have. The port gives each
a per-profile expectation (clients-§6: "A per-client feature MUST have a test on each profile"). **INFERRED.**

### 2.2 The missing-globals check is not armed yet

- The kit checks Forever **only when a root `.toc`'s `## Interface` line carries a 16xxx number**
  (`tests/_kit/client_globals.lua:50-51`, `CG.clientsFromToc`, `:187-195`). DropWatcher's TOC says `120105`, so
  today the forever set is **not armed**. **MEASURED.**
- The profile (`KA0S_KIT_CLIENT`) and the globals check are separate. `KA0S_KIT_CLIENT` picks the mock profile in
  `tests/_kit/mock_client.lua:33-55` (constants, `GetBuildInfo`, and the names it removes). The globals check reads
  the TOC, not the env var. **MEASURED.**
- How it runs: `tests/run.lua:322` lists `{ name = "test_client_globals", dir = "tests/_kit/" }`.
  `tests/_kit/test_client_globals.lua:35-43` collects `git ls-files '*.lua' '*.toc'` (leaving `tests/` out),
  scans for bare calls and `C_X.Y(` calls, and judges them against `client_globals_live.lua` and
  `client_globals_forever.lua` (Ketho's lists; the forever file is a diff from live, `client_globals.lua:169-184`).
  Allowed names go in `tests/client_globals_allow.lua`. DropWatcher has none (the file is absent). **MEASURED.**
- I armed it by hand (a scratch script calling `CG.collect(".", {"tools/"})`, `CG.scan`, then
  `CG.judge(found, allow, {"live","forever"})`). Result: **0 findings**. So turning on `16001` will not turn this
  suite red. **MEASURED.**
- The check is lenient. It cannot see a behavior gap: for example `EJ_*` and `C_TransmogCollection` exist on
  Forever, but the journal is disabled and transmog is off there (sections 7, 8). It also passes
  `GetInspectSpecialization`, because the file tests for it (`core/Compat.lua:380`). **MEASURED** (the heuristics:
  `client_globals.lua:20-47`).

### 2.3 Every event DropWatcher names exists on Forever

36 event tokens in `core/` and `modules/` (for example `CHAT_MSG_LOOT`, `ENCOUNTER_LOOT_RECEIVED`,
`LOOT_HISTORY_UPDATE_DROP`, `CHALLENGE_MODE_START`, `EJ_LOOT_DATA_RECIEVED`, `TRANSMOG_COLLECTION_UPDATED`,
`PLAYER_SPECIALIZATION_CHANGED`, `TRADE_*`) are in both `KF/Events.lua` and `KL/Events.lua`. So are the events a
Forever talent read would need (`TRAIT_CONFIG_UPDATED`, `CHARACTER_POINTS_CHANGED`, `ACTIVE_TALENT_GROUP_CHANGED`)
and the roll events (`START_LOOT_ROLL`, `CANCEL_LOOT_ROLL`, `LOOT_ROLLS_COMPLETE`, `OPEN_MASTER_LOOT_LIST`,
`PARTY_LOOT_METHOD_CHANGED`). **MEASURED.** That an event exists does not mean it fires (client-quirks-§3).
`CHALLENGE_MODE_*` and `EJ_LOOT_DATA_RECIEVED` most likely never fire on Forever. **INFERRED.**

### 2.4 Every GlobalString DropWatcher reads is identical on both clients

69 names read through `Compat.GlobalString` / `globalString` and the `LOOT_ITEM*` shapes
(`modules/LootParser.lua:70-85`). Every one exists in both `KF/` and `KL/` `enUS.lua` with the same text.
`BIND_TRADE_TIME_REMAINING` exists on Forever too. **MEASURED.** So the loot parser compiles the same patterns on
both clients.

## 3. Spec IDs and the Retail 12.x spec table

### 3.1 What Forever answers

- One specialization per class. **MEASURED** for the Hunter: the owner's QuickComms probe recorded
  `spec = { id = 1485, name = "Hunter" }` and `specID = 1485` (`FV/WTF/Account/ADD1KTED2KA0S/SavedVariables/QuickComms.lua:8,334-337`).
  **REPORTED** for the Warrior: `1491` (ForeverPlusPlus, quoted in
  `CT/2026-11-07-WOW_FOREVER_PORT/research_notes/WoW Forever porting research/02_api_differences.md:131,337`).
  Other classes' IDs are not known. They need no seed if they are read from the client (`Role.SpecsForClass`).
- The spec's name is the class name ("Hunter"). **MEASURED** (same probe). So `Compat.SpecName` on Forever shows
  the class name, not a tree.
- The classic talent trees are `C_Traits` groups: Hunter groups `11372` Beast Mastery (10 points),
  `11371` Marksmanship (3), `11370` Survival (0) (`FV/.../QuickComms.lua:312-331`). **MEASURED.**
- `GetSpecialization*` globals are nil on Forever (`Blizzard_DeprecatedSpecialization` is gated to standard).
  **REPORTED** (`CT/2026-11-07-WOW_FOREVER_PORT/reports/WoW Forever porting research.md:15`). The
  `C_SpecializationInfo` rung exists on both (`client_globals` sets: `C_SpecializationInfo.GetSpecialization`
  live=true forever=true). **MEASURED.**
- Nine classes only: `CLASS_SORT_ORDER` is Warrior, Paladin, Priest, Shaman, Druid, Rogue, Mage, Warlock, Hunter
  (`WF/Blizzard_FrameXMLBase/Camelot/Constants.lua:1-12`). **MEASURED.** No Death Knight, Monk, Demon Hunter or
  Evoker.

### 3.2 DropWatcher's spec-keyed sites

| Site | What it does | On Forever | Port must |
|---|---|---|---|
| `core/ClassData.lua:24-27` `CLASS_ID` | 13 classes | 4 never appear | Keep (IDs are the same); seed lists that enumerate classes come from a per-client list |
| `core/ClassData.lua:30-35` `ARMOR` | class → loot armor type | Hunter, Shaman mail and Warrior, Paladin plate only from level 40 in vanilla rules | Forever armor table (section 5) |
| `core/ClassData.lua:47-64` `WEAPONS` | loot-relevant proficiencies | vanilla sets differ | Forever weapon table (section 5) |
| `core/ClassData.lua:81-121` `SPECS` | 39 Retail spec rows: stat, D/T/S/O flags | no row matches `1485` | A Forever table keyed by class and **talent group**, picked once by `ClientKey()` (clients-§5) |
| `core/ClassData.lua:126-140` `SPEC_INDEX` | spec → Pawn index | nil | Forever: Pawn index = talent group index (Druid differs, section 10) |
| `core/ClassData.lua:143-149` `CLASS_SPECS` | derived from `SPECS` | empty for every Forever class | Derived from the Forever table |
| `core/Compat.lua:285-293` `PlayerSpecID` | Compat spec ladder | `1485` via `C_SpecializationInfo` (if it answers) | Route through `Role.Spec()`; add the talent group as its own read |
| `core/Compat.lua:379-385` `InspectSpecID` | reads **only** the global `GetInspectSpecialization` | the global is defined only when the CVar `loadDeprecationFallbacks` is on, on both clients (`WF/Blizzard_Deprecated/Shared/Deprecated_12_1_0.lua:4-6,75`) | Read `C_SpecializationInfo.GetInspectSpecialization` first (both clients; a latent Retail bug too). On Forever it is class-wide |
| `core/Compat.lua:562-577` `GetItemSpecs` | `C_Item.GetItemSpecInfo` | unknown what it answers for vanilla items | Probe (section 14) |
| `core/Compat.lua:972-978` `SpecName` | `GetSpecializationInfoByID` | "Hunter" | Show the talent tree name for you, the class for others |
| `modules/Gear.lua:21,131,376,397` | your spec, hand flags, off-spec gear, spec event | nil spec; no event on a talent change | Read the talent group; listen to `TRAIT_CONFIG_UPDATED` on Forever |
| `modules/Inspect.lua:280` | looter's spec from inspect | class-wide `1485` | Another unit's talent group is not read by Role; probe `INSPECT_TRAIT_CONFIG_ID` (section 14) |
| `modules/Evaluate.lua:136-150` `statCheck` | primary stat by spec, or across class specs | one spec, no row | Score-first on Forever makes this a soft check (section 11) |
| `modules/OffSpec.lua:145` and `modules/OffSpecCells.lua:58-180` | another spec of your class | one spec per class | Off-spec is Retail-only, or rebuilt on talent groups (owner) |
| `modules/Scoring.lua:177-182` `specScale` | Pawn scale per spec | nil | Section 10 |
| `settings/Editors.lua:40-170`, `settings/PageEditors.lua:350-385` | weights editor strip per spec | one tab ("Hunter") | Per class, or per talent tree (owner) |
| `modules/SimRoster.lua:47,105` | sim classes from `CLASS_SPECS` | Retail classes and spec IDs | Forever roster seed |
| `modules/TestData.lua:305-328` | 24 sample members with Retail spec IDs and Monk, Evoker, DK, DH | not real on Forever | Forever sample seed |

## 4. LibKa0s-Role-1.0 (v1.95.0): what it covers for DropWatcher

The surface (`LK/docs/api/Role/version-1-docs.md:43-50`, `LK/LibKa0s/Role.lua`). **MEASURED.**

- `Spec()` → `specID, name` of the player's spec, through Compat's ladder, `C_SpecializationInfo` first
  (`Role.lua:130-150`).
- `SpecsForClass(classFile)` → `{ id, name, role }` per spec of a class, read from the client
  (`C_SpecializationInfo.GetSpecializationInfoForClassID`, `Role.lua:178-200`).
- `Groups()` → Forever only: `{ index, id, name, spent }` per talent group of the **player's** active config
  (`docs/api/Role/version-1-docs.md:80-94`). Empty on Retail.
- `Resolve(store)` → `role, source, detail`: override, assigned, talents (Forever), spec, saved
  (`docs/api/Role/version-1-docs.md:54-74`).
- `SetOverride(store, role)` and the seed `TALENT_GROUP_ROLE` (`Role.lua:71-81`), "MATCHED, NOT CONFIRMED".
  The Hunter probe's order (BM 1, MM 2, SV 3) matches the seed's order. **MEASURED** for one class.

| DropWatcher need | Covered? | Notes |
|---|---|---|
| Your spec ID on both clients | **Yes**, `Spec()` | On Forever it is the class-wide `1485` |
| Your spec's name | Partly | Forever answers the class name; the tree name is `Groups()`' top group |
| Your talent tree (Arms/Fury/Prot) | **Yes**, `Groups()` | Points per group; the caller picks the most. A tie or 0 points has no answer |
| Your role (tank, healer, damage) | **Yes**, `Resolve` | Needs a per-character store (`db.char`), like QuickComms |
| A class's spec list | **Yes**, `SpecsForClass` | Forever: one entry per class. No seed needed |
| Primary stat per spec or tree | **No** | DropWatcher keeps a Forever table by class and talent group |
| Armor type per class (and level) | **No** | DropWatcher's own table |
| Weapon proficiencies per class | **No** | DropWatcher's own table |
| Dual wield, Titan's Grip, shield, held off hand | **No** | DropWatcher's own table (no Titan's Grip on Forever, INFERRED) |
| The Pawn scale index | **No** | Derivable from the talent group (section 10) |
| Another unit's spec or talent tree (the looter, the candidates) | **No** | "Inspecting another unit" is out of scope (`docs/api/Role/version-1-docs.md:149-150`). Only `UnitGroupRolesAssigned(unit)` is cheap |
| A talent change event | **No** | "A host re-reads on its own events" (`:151-152`) |

So Role replaces `Compat.PlayerSpecID` and gives the player's tree and role. It does not replace
`ClassData`'s rules. DropWatcher still owes a Forever `ClassData` (clients-§5: two lists, picked once).

### How QuickComms adopted it (master, `37a1e7b`)

- One upvalue, `RoleLib = LibStub("LibKa0s-Role-1.0", true)` (`QC/core/Compat.lua:115`).
- `activeSpec()` calls `RoleLib.Spec()`, else its own ladder (`QC/core/Compat.lua:134-142`).
- `Compat.RoleStore()` makes `db.char.role` (`:201-206`); `Compat.PlayerRole()` is `RoleLib.Resolve(store)`
  with a library-absent fallback: override, assigned, spec (`:208-229`).
- `AutomaticRole`, `RoleOverride`, `SetRoleOverride` wrap the override (`:231-262`); the Role row is on
  General → Behavior (`QC/docs/ARCHITECTURE.md:129`).
- `Compat.SpecsForClass` uses `RoleLib.SpecsForClass`, "so WoW Forever needs no seed", with Retail's shipped list
  as the fallback (`QC/core/Compat.lua:265-277`, `QC/docs/ARCHITECTURE.md:128`).
- `/qc probe` records `Groups()` into `global.probes` (`CT/2026-11-10-QUICKCOMMS_FOREVER_EMOTES/00_DESIGN.md:110-116`).
  That probe is the measured Hunter data above.

DropWatcher can copy that shape: Role behind `core/Compat.lua`, a library-absent stub, and a probe verb that
records `Groups()`. **INFERRED.**

## 5. Armor, weapons, stats on Forever (the rules Role does not give)

None of this is in the Forever UI source as a table. It is vanilla-era game knowledge, so treat every row as
**INFERRED** until probed (section 14).

| Class | Armor (60) | Notes |
|---|---|---|
| Warrior, Paladin | Plate from 40; mail below | Plate skill spell 750 |
| Hunter, Shaman | Mail from 40; leather below | Mail skill spell 8737 |
| Rogue, Druid | Leather | |
| Priest, Mage, Warlock | Cloth | |

- DropWatcher's `CD.ARMOR` ignores level (`core/ClassData.lua:30-35`). On Retail that is fine. On Forever a level 30
  Hunter in a dungeon wears leather. A level-aware check (`IsSpellKnown(8737)`, or the skill line) is a Forever need.
- Vanilla had no armor specialization, so a warrior "needing" mail is legal. The owner decides how strict the
  armor check is on Forever.
- Weapons that differ from DropWatcher's Retail sets (`core/ClassData.lua:47-64`), vanilla rules: Warriors also
  bows, guns, crossbows, thrown; Rogues bows, guns, crossbows, thrown; Hunters no maces, plus thrown; Druids no
  polearms; Paladins no staves or daggers. Wands for Priest, Mage, Warlock as now.
- Relics: Paladin libram, Shaman totem, Druid idol go in the ranged slot (`INVTYPE_RELIC`, GlobalString
  `INVTYPE_RELIC = "Relic"` on Forever, `KF/enUS.lua:12627`). **MEASURED** that the string exists.
- Dual wield: Warrior, Rogue, Hunter. Not Shaman in vanilla. No Titan's Grip. Shields: Warrior, Paladin, Shaman.
  Held off hands: casters.
- Primary stats: vanilla items carry several of Strength, Agility, Intellect, Spirit, Stamina at once, plus
  attack power and spell damage. DropWatcher's one-stat-per-spec gate (`modules/Evaluate.lua:136-150`) will misfire
  ("can't use" or "unknown"). Pawn's Forever weights value every one of these (`FV/Interface/AddOns/Pawn/ClassicHawsJon.lua:324-590`).
  **MEASURED** that Pawn's weights use them.

## 6. Character names (client-quirks-§5)

The rule (`STD/client-quirks.md:209-239`, quoted): "read a character through `LibKa0s-Compat-1.0`'s identity
readers (from `LibKa0s v1.94.0`): `UnitCharacterName(unit)` for any unit, `CharacterKey()` and `RealmKey()` for
the player, and `RegionalNames()` for the question itself." and "Never read `UnitName`'s second return as a realm,
never split a name on whitespace or key on its first word, and size every surface that shows a name, a realm or a
profile key for the long form". **MEASURED.**

On Forever, `UnitName` answers `"Traxex", "Silentshot"`; a chat sender is `"Doom Dock"` with no realm;
`GetNormalizedRealmName()` is `"CAMWOWAU1Realm2PvP"` (`STD/client-quirks.md:214-220`). **MEASURED** (owner probe).

| Site | Today | On Forever | Port must |
|---|---|---|---|
| `core/CompatWorld.lua:60-63` `Compat.UnitName` | raw `UnitName` | returns the surname as 2nd value | Add `Compat.UnitCharacterName` (route the library's); callers move to it |
| `modules/Roster.lua:95-101` `identityOf` | `name, realm = UnitName(unit)`; `fullName = name-realm` | `"Traxex-Silentshot"` | `UnitCharacterName`: `"Traxex Silentshot"`, realm nil |
| `modules/Roster.lua:125,250,262` | own realm via `NormalizedRealm` | long realm label | No realm on Forever |
| `modules/Roster.lua:256-260` `parse` | splits `"Name-Realm"` on `-` | `"Doom Dock"` has no `-`: kept whole and lowercased, then matched against the first name: **miss** | Match against the whole name |
| `core/Compat.lua:881-889` `TradePartnerName` | `UnitName("NPC")` 2 values → `Name-Realm` | `"Traxex-Silentshot"` | `UnitCharacterName("NPC")` |
| `modules/CharFilter.lua:49-55,194-200` `CF.Key`, `Recorder` | `UnitName("player")` + `NormalizedRealm` | `"Traxex-CAMWOWAU1Realm2PvP"`: two alts with one first name collide | `Compat.CharacterKey()` |
| `modules/LootFeed.lua:194` `you()` | `UnitName("player")` 1 value | first name only | `UnitCharacterName("player")` |
| `modules/LootParser.lua:188` `selfLooter` | same | first name only | same |
| `modules/TestMode.lua:110` | same | first name only | same |
| `modules/SimEvents.lua:417,431`, `modules/SimRoster.lua:111,260` | sim names as `name-realm` | Retail shape | Per-client sim name shape |
| `modules/GroupRoster.lua:47,158,191` | key and paint `name-realm` | wrong shape | Whole name, no realm |
| `modules/CompactHistory.lua:166`, `modules/CompactGroup.lua:556` | `ownRealm` for display | long label | No realm on Forever |
| `modules/Asks.lua:99-101` `shortName` | `name:match("^([^%-]+)")` | keeps the whole two words (no `-`), which is right | Keep; check width |
| `modules/Asks.lua:159-165` `whisperRecipient` | whispers `m.fullName` | `"Traxex-Silentshot"`: the wrong target | Whisper the whole name; probe how a whisper target is spelled (section 14) |

`W1_FOREVER_NAME_PROBE.md` lists the six sites `core/Compat.lua:883`, `modules/Roster.lua:97`,
`CharFilter.lua:196`, `LootFeed.lua:194`, `LootParser.lua:188`, `TestMode.lua:110`
(`CT/2026-11-07-WOW_FOREVER_PORT_STEP5/W1_FOREVER_NAME_PROBE.md:45-54`). All six are still at those lines today.
**MEASURED.** The table adds the rest.

Width: every surface that shows a name must fit "First Surname" or truncate with the whole name in a tooltip
(the Group roster lines, the Who column, toast lines, the Offer panel). **INFERRED** which ones overflow; smoke.

## 7. The Encounter Journal (`core/CompatJournal.lua`)

- `Blizzard_EncounterJournal` does not load on camelot, and the `EncounterJournalDisabled` game rule is checked
  by Blizzard's own `GameRulesUtil.EJIsDisabled()` (`WF/Blizzard_SharedXML/GameRulesUtil.lua:78-99`). **MEASURED.**
  That the rule is active on Forever is **REPORTED** (`02_api_differences.md:348`).
- The `EJ_*` and `C_EncounterJournal` functions exist on Forever (scan sets: `EJ_SelectInstance` forever=true).
  **MEASURED.** What they answer with the journal disabled is unknown. **INFERRED** empty.
- The one caller is the simulator's item pool (`modules/SimPool.lua:267-316`, event at `:483`), used by Sim mode
  and Test mode (`modules/TestMode.lua:15`). The pool already falls back to your own gear when the journal yields
  nothing (`modules/SimPool.lua:26-29`). **MEASURED.**
- Port: the journal source is Retail-only. `EJ_LOOT_DATA_RECIEVED` is registered only on Retail (`ForClient`,
  clients-§4). Forever's pool is the own-gear fallback, or a Forever seed list of real item IDs (clients-§5:
  "Forever gets its own list, not a filtered Retail one"). `P.SOURCES` (`modules/SimPool.lua:64-72`) and
  `P.FAMILY` (`:75-78`) use Retail difficulties. **INFERRED.**

## 8. Transmog, CanIMogIt, `C_TransmogCollection`

- Transmog is reported off on Forever (`TransmogEnabled = 0`, `02_api_differences.md:348`). **REPORTED.**
  `C_TransmogOutfitInfo.IsTransmogEnabled()` exists on Forever (`WF/Blizzard_APIDocumentationGenerated/TransmogOutfitInfoDocumentation.lua:631-638`),
  a candidate for one feature-detection read. **MEASURED** that it exists.
- DropWatcher sites: `core/Compat.lua:597-650` (`PlayerHasTransmog`, `TransmogSource`, CanIMogIt calls);
  `modules/ItemFacts.lua:359` (`TRANSMOG_COLLECTION_UPDATED`); the transmog ask (`modules/Asks.lua`,
  `modules/Messaging.lua`, `C.MESSAGE_TEMPLATES` `transmog` at `core/Constants.lua:560-566`); the settings rows
  `messages.transmogAsk` and `messages.templates.transmog` (`settings/SchemaRows.lua:396-416`); the look chips in
  `modules/DetailCells.lua`, `modules/WindowCells.lua`, `modules/CompactCards.lua`, `modules/CompactGroup.lua`;
  `modules/Collectibles.lua` (6 sites), `modules/Diagnostics.lua` (5); `## OptionalDeps: … CanIMogIt`
  (`DropWatcher.toc:8`). **MEASURED.**
- Port: transmog is a Retail-only feature: the rows, the template, the event, the chips and the "New to my
  collection: look" meaning are absent on Forever. **INFERRED** from clients-§4 ("A Forever player never sees a
  Retail-only feature (… transmog …)", `STD/clients.md:8`).
- `Compat.DressUpItem` (`core/Compat.lua:961`) uses `DressUpItemLink`. Whether the dressing room works with
  transmog off is unknown (section 14).

## 9. Slots: the ranged slot exists on Forever

- `INVSLOT_RANGED = 18` (`WF/Blizzard_FrameXMLBase/Constants.lua:153`). Forever's paper doll shows the ranged slot
  when `C_PaperDollInfo.IsRangedSlotShown()` is true (`WF/Blizzard_UIPanels_Game/Camelot/PaperDollFrame.lua:1933-1946`)
  and an ammo slot when `UnitUsesAmmo("player")` (`:1517`). Pawn treats the ranged slot as present on Forever
  (`FV/Interface/AddOns/Pawn/VgerCore/VgerCore.lua:50`). **MEASURED.**
- DropWatcher: "Slot 18, the old ranged slot, is unused on Retail" (`core/Constants.lua:389-394`, `C.SLOT` has no
  18). `INVTYPE_RANGED` and `INVTYPE_RANGEDRIGHT` are `kind = "ranged"` over the two hands (`:429-431`).
  `INVTYPE_THROWN` and `INVTYPE_RELIC` have no plan, so they are "not gear". **MEASURED.**
- Port: a Forever slot plan, picked once: ranged, thrown, wands and relics compare against slot 18, and slot 18 is
  read in the gear snapshot and inspect. The decision "is the ranged slot shown" is feature detection inside the
  compat family (`IsRangedSlotShown`), or a per-client plan. **INFERRED.**

## 10. Pawn on Forever (installed 2.14.1)

What Pawn does on Forever. **MEASURED** from `FV/Interface/AddOns/Pawn/`:

- Pawn's TOC is `## Interface: 16001`, version 2.14.1 (`Pawn.toc:1,3`). It loads `ClassicHawsJon.lua` on
  `classic, camelot` and not `AskMrRobot.lua` (`Pawn.toc`, the last lines).
- It detects Forever by interface number: `VgerCore.IsForever = BuildNumber > 16000 and BuildNumber < 20000`
  (`VgerCore/VgerCore.lua:25`), and `SpecsExist = IsMists or IsDraenorOrLater` is **false** (`:49`).
- With no specs, Automatic mode is off (`Pawn.lua:745-756`, `PawnOptions.AutoSelectScales = false`), and
  `PawnSetAutoSelectScales(true)` refuses (`Pawn.lua:5462-5465`).
- The Forever scales are the "Classic" provider's, one per classic talent tree:
  `PawnAddPluginScaleFromTemplate("Classic", ClassID, SpecIndex, …)` for Druid 1 Balance, 2 Feral (Damage),
  3 Feral (Tank), 4 Restoration; Hunter 1-3; Mage 1-3; Paladin 1-3; Priest 1-3; Rogue 1 Assassination,
  2 Combat, 3 Subtlety; Shaman 1-3; Warlock 1-3; Warrior 1-3 (`ClassicHawsJon.lua:324-590`). Each scale stores
  `ClassID` and `SpecID` = that index; its name is `UnlocalizedClassName .. index`, e.g. `"HUNTER1"`
  (`Pawn.lua:5787-5826`).
- On first login every Classic scale of your class is made visible, unless you already have a custom scale
  (`ClassicHawsJon.lua:1401-1410`). So a Forever Hunter sees three scales at once.
- `PawnFindScaleForSpec(ClassID, SpecID)` matches `Scale.SpecID == SpecID` (or any spec when SpecID is nil) and a
  provider (`Pawn.lua:4565-4574`). `PawnGetItemData` (`:1324`), `PawnGetSingleValueFromItem` (`:1690`),
  `PawnIsItemAnUpgrade` (`:3586`), `PawnIsReady` (`:4949`), `PawnIsScaleVisible` (`:5500`) all exist.
- Pawn's per-character key on Forever is the surname form (`Pawn.lua:588-591`).

What breaks in DropWatcher:

- `Compat.PawnScaleForSpec` and `Compat.PawnVisibleScale` return nil when `SpecIndex(specID)` is nil
  (`core/Compat.lua:757-761,799-804`). On Forever that is always. **MEASURED** (code) / **INFERRED** (in game).
- `scaleFits` skips a scale whose `SpecID ~= index` (`core/Compat.lua:768-775`); with three visible scales and no
  index it cannot choose.
- For you, `modules/Scoring.lua:188-192` first takes `bestVisibleScale(link)` from `PawnIsItemAnUpgrade`. On Forever that
  answers across all visible scales, so it picks the tree that gains most, not the tree you play. **INFERRED.**
- The comments cite Pawn 2.13.6 line numbers (`core/Compat.lua:712-760`); the installed Forever Pawn is 2.14.1 and
  the lines moved (e.g. `PawnIsReady` 4916 → 4949). **MEASURED.**

Port: on Forever the Pawn index is the player's top talent group index from `Role.Groups()`, except the Druid's
Feral tree, which is Pawn 2 or 3 by role (tank vs damage; `Role.Resolve`), and Druid Restoration, which is Pawn 4.
For another unit with no talent read, use the visible scale or no scale. The owner's ruling "score-first
(Pawn/custom) with item level a tiebreak" needs this read to work. **INFERRED.**

## 11. Verdict order: Retail is item-level-first

`decide` (`modules/Evaluate.lua:410-417`) takes the item level's sign; a score that disagrees makes it a
sidegrade. With no score it is item level alone. **MEASURED.** The owner's Forever ruling is score-first with
item level as the tiebreak. That is a per-client policy in the kernel (an `opts` field the edge sets once), not a
client check inside `Evaluate`. **INFERRED.** The primary-stat gate (`:136-150`) and the off-spec pass would
otherwise refuse many vanilla items before the score is asked.

## 12. Retail-only systems in DropWatcher (each becomes absent on Forever)

| System | Sites (file:line) | On Forever | Port must |
|---|---|---|---|
| Mythic+ / keystones | `core/CompatWorld.lua:138-155` (`KeystoneLevel`, `ChallengeModeActive`); `core/Compat.lua:441-448` (`ChallengeMapName`); `modules/Situations.lua:75` and its `CHALLENGE_MODE_*` rows; `modules/LootFeed.lua:1042-1043`; `C.MESSAGE_FLUSH_TRIGGERS` (`core/Constants.lua:573`); `modules/WindowCompact.lua` (8 sites), `modules/Asks.lua`, `modules/SimScenario.lua:70` `key` | `C_ChallengeMode` exists, `Blizzard_ChallengesUI` does not load on camelot (REPORTED, `02_api_differences.md:345`); no keystones (INFERRED) | Gate the `CHALLENGE_MODE_*` registrations and the `mythicPlus` situation, the `key` scenario and the header to Retail |
| Delves | `C.DIFFICULTY.DELVE = 208` (`core/Constants.lua:492`); `modules/Situations.lua:61`; `modules/GroupPlace.lua` (5); `defaults/Profile.lua:60,116`; `modules/SimScenario.lua:77`; `settings/SlashVerbs.lua` (2) | no delves (INFERRED) | Retail-only situation and scenario |
| Follower dungeons, LFR (group finder) | `C.DIFFICULTY` 7, 17, 151, 205 (`core/Constants.lua:470-493`); `core/CompatWorld.lua:39-50` (`InstanceGroupCategory`); `modules/Situations.lua:62`; `modules/GroupPlace.lua` (4); `modules/SimScenario.lua:75` `lfr`; `modules/TestData.lua` (11) | `Blizzard_GroupFinder` excluded on camelot; Forever has its own dungeon finder (REPORTED, `reports/…research.md:103`). Whether `LE_PARTY_CATEGORY_INSTANCE` and `INSTANCE_CHAT` work there is unknown | Retail-only `followerDungeon`, `raidLFR`; probe the instance channel |
| Scenarios | `modules/Situations.lua:55`, `defaults/Profile.lua:61` | none in vanilla (INFERRED) | Retail-only, or keep as harmless fallback (owner) |
| Upgrade tracks (crests) | `core/Compat.lua:186-212` (`GetItemUpgradeInfo`), `core/TextParse.lua:152`, `modules/ItemFacts.lua:117-121`, `modules/Evaluate.lua:451` (`trackDelta`), `modules/DetailCells.lua:193,332-346`, `modules/WindowCells.lua:215,729`, `C.MESSAGE_TOKENS` `track` (`core/Constants.lua:569`), `C.TRACK_TIER` (`core/Constants.lua:350`, a deviation row in `docs/ARCHITECTURE.md`) | `C_Item.GetItemUpgradeInfo` exists; vanilla items have no track (INFERRED) | The Track row, the `{track}` token and the track chips are Retail-only |
| Warbound binds | `core/Compat.lua:461-468`, `C.TRADE_ACCOUNT_BIND` (`core/Constants.lua:537-540`), `modules/TradeRules.lua:86-91` | `Enum.ItemBind` has the same members on Forever (`WF/Blizzard_APIDocumentationGenerated/ItemConstantsDocumentation.lua:249-265`, MEASURED); no Warband bank in practice (REPORTED) | Harmless; keep. The "warbound" reason words should never show (INFERRED) |
| Bonus rolls | `modules/LootParser.lua:74-83` (`LOOT_ITEM_BONUS_ROLL*`), `modules/TradeRules.lua:89`, `modules/LootFeed.lua` (6), `modules/SimEvents.lua` (8) | strings exist (MEASURED); no bonus rolls in vanilla (INFERRED) | Harmless parser rows; the sim's bonus-roll events are Retail-only |
| Tier tokens | `modules/TierTokens.lua` (whole), `core/CompatCollect.lua:200-206` (`TierTokenSlot`), `C.TIER_TOKENS = {}` (`core/Constants.lua:383`), the `tierToken` category row (`settings/SchemaRows.lua:166-167`) | vanilla had tokens in AQ40 and Naxx, with different text (INFERRED); the `TT-1` English phrases target Retail ("Create a soulbound set hand item…") | Owner: Forever tokens or Retail-only. A Forever `C.TIER_TOKENS` would be its own list |
| Mounts, battle pets, toys, cosmetics | `core/CompatCollect.lua:49-130`, category rows `settings/SchemaRows.lua:168-174` | journals exist as APIs (MEASURED); vanilla has no battle pets or toy box (INFERRED) | Probe; absent where the client has none |
| The trade window (2h/4h) | `C.TRADE_WINDOW = 14400` (`core/Constants.lua:542`); `C.TRADE_RULES` and names (`:544-552`); `modules/TradeRules.lua:94-102` (`expiryCheck`); `modules/TradeTimer.lua` (own item's countdown, `LOOT_CLOSED` at `:381`); `trade.warnAt` (`defaults/Profile.lua:118`); the rule words (`modules/WindowCells.lua:361-433`, `modules/DetailCells.lua:108`) | owner ruling: a looted BoP is soulbound forever; only BoE changes hands | A Forever rule ("BoE only"), Forever's own default rule map, and the trade timer Retail-only |
| Off-spec | `modules/OffSpec.lua`, `modules/OffSpecCells.lua`, `C.MESSAGE_TEMPLATES` `askOffSpec` | one spec per class | Retail-only, or rebuilt on talent groups (owner) |
| Personal loot words | `settings/SchemaRows.lua:184` (`RULES`), `defaults/Profile.lua:114-118` | no personal loot (owner ruling) | Forever rule choices and defaults |

### Situations and difficulty IDs

- `C.SITUATIONS` is one Retail list (`core/Constants.lua:461-465`); the settings table draws one row per entry
  (`settings/SchemaRows.lua:258-282`). Defaults per situation (`defaults/Profile.lua:54-65`) and trade rules
  (`:114-118`). **MEASURED.** Port: a Forever situation list, picked once (clients-§5), so a Forever panel shows
  only dungeon, raid, pvp, open world group and solo. **INFERRED.**
- Forever's `DifficultyUtil.ID` adds `RaidClassic20Normal = 242` and `RaidClassic10Normal = 243`
  (`WF/Blizzard_FrameXMLUtil/Mainline/DifficultyUtil_Base.lua:22-23`). Live has neither (Gethe `live`, same file:
  ends at `RaidMythicFlexible = 233, RaidWorld = 250`). **MEASURED.**
- DropWatcher's `C.DIFFICULTY_KIND` (`core/Constants.lua:497-517`) has no 242 or 243, so they fall back to the
  instance type and read as `raid` (`modules/Situations.lua:48-56,71-78`). That is the right answer. **MEASURED**
  (code) / **INFERRED** (in game). Add both to a Forever map so the classifier is explicit.
- The probe saw instance map IDs on Forever: 33 Shadowfang Keep, 389 Ragefire Chasm, 34 Stormwind Stockade,
  409 Molten Core, 2875 Karazhan Crypts, 2999, 3001, 3065 (`FV/.../QuickComms.lua:339-352`). **MEASURED.**
  DropWatcher keeps no instance IDs today.

## 13. Blizzard frames, strata, secrets, other client surfaces

- **GetFrameStrata:** DropWatcher never reads it (`grep -rn GetFrameStrata core modules`: none). It only sets
  strata (`modules/Window.lua:584`, `modules/OfferPanel.lua:214`, `modules/DetailCard.lua:682`). The Forever-only
  `Enum.SecretAspect.FrameStrata` (REPORTED, `02_api_differences.md:245`) does not reach it. **MEASURED.**
- **Blizzard frames and hooks:** `hooksecurefunc("NotifyInspect")` (`core/Compat.lua:401-404`), `InspectFrame:IsShown()`
  (`:388-395`), `UISpecialFrames` (`modules/Window.lua:605`), `StaticPopupDialogs` (`modules/History.lua:727-728`,
  `modules/HistoryRetention.lua:243-244`, `settings/Schema.lua:324`), `GameTooltip` (`modules/Window.lua:222-248`,
  `modules/TipGrid.lua:85-86`), `MenuUtil` (`core/Compat.lua:895`), `ChatFrameUtil.InsertLink` /
  `ChatEdit_InsertLink` (`:949-955`), `DressUpItemLink` (`:961`). **MEASURED.** Each exists in the Forever set.
  Forever re-draws the inspect and character frames (camelot `PaperDollFrame`,
  `WF/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc:52-53`); `InspectFrame` itself is in an addon not in the
  sparse clone. Smoke.
- **The roll popup (new feature):** `GroupLootFrame.lua` loads on the mainline family, so on both clients
  (`WF/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc:129-130`). Master loot is `MasterLooterFrame` in the same
  file (`Mainline/GroupLootFrame.lua:985-992`). **MEASURED.** Annotating it is a new frame hook; notes 02 and 05
  cover it.
- **`GameTooltip:SetText` with a boolean alpha** (rejected on Forever, REPORTED, `reports/…research.md:87`):
  DropWatcher passes `r, g, b` only (`modules/Window.lua:240`). No other call passes a fifth argument. **MEASURED.**
- **`SetDesaturation`:** no call. **MEASURED.**
- **Secrets:** Forever keeps Midnight's secrets (REPORTED, `reports/…research.md:19`). DropWatcher's guards already
  wrap every read (`core/Compat.lua:6-10`). More unit stats are secret on Forever (63 vs 50,
  `SecretWhenUnitStatsRestricted`, REPORTED); DropWatcher reads no unit stat. **MEASURED** (grep). Creature GUIDs
  are obfuscated on Forever (REPORTED); the feed keys players' GUIDs only. **INFERRED.**
- **Chat:** asks and offers go out as `WHISPER` through `C_ChatInfo.SendChatMessage` (`core/Compat.lua:74-78`,
  `modules/Asks.lua:253-266`). No addon messages. Trial accounts cannot send addon messages on Forever (REPORTED);
  not an exposure. **MEASURED** (no `SendAddonMessage`).
- **`ADDON_RESTRICTION_STATE_CHANGED`** exists on Forever (MEASURED, `KF/Events.lua`); the restriction reads stay.

## 14. Hard-coded Retail data

| Data | Site | Port must |
|---|---|---|
| Retail spec table and Pawn index | `core/ClassData.lua:81-140` | Forever table by class and talent group |
| Difficulty IDs and their kinds | `core/Constants.lua:470-517` | Forever map (adds 242, 243; drops 8, 17, 205, 208…) |
| Situation list and per-situation defaults | `core/Constants.lua:461-465`, `defaults/Profile.lua:54-65,114-118` | Forever lists, chosen once by `ClientKey()` |
| Trade window 4 h (12.1.5) | `core/Constants.lua:542` | Retail only |
| Track tier names (`C.TRACK_TIER`) | `core/Constants.lua:350-355` | Retail only |
| Slot plans without slot 18 | `core/Constants.lua:389-432` | Forever plan with ranged, thrown, relic |
| Test mode sample members (Retail classes, spec IDs) | `modules/TestData.lua:305-328` and the "key" and "raidHeroic" drops (`:628-659`) | Forever sample set (nine classes, Forever places) |
| Sim pool sources and families | `modules/SimPool.lua:64-78` | Forever source (own gear or a seed of real IDs) |
| Collectible samples | `modules/SimPool.lua:139` (empty) | nothing to change |
| Tier token overrides | `core/Constants.lua:383` (empty) | nothing unless Forever tokens are in scope |
| Sim scenarios `key`, `lfr`, `delve` | `modules/SimScenario.lua:69-78` | Forever scenario list |
| Default skin literal `"ka0s"` | `core/SkinSetup.lua:99,410,723`; `defaults/Profile.lua:254-255` | `NS.DEFAULT_SKIN = Skin:DefaultSkin()` (skinning-§2) |

No item IDs or instance IDs are hard-coded today. **MEASURED** (grep of four-digit-plus numbers in the sim and
test modules: only spec IDs, times and GUID seeds).

## 15. The standard's binding rules for this port (quoted)

- **Both clients by default.** "By default each addon serves both from one codebase" (`STD/clients.md:5`).
- **Absent, not hidden.** "A feature is absent, never just hidden, on a client that cannot support it. A Forever
  player never sees a Retail-only feature (the group finder, the warband bank, Mythic+, transmog, the Encounter
  Journal)" (`STD/clients.md:8`). "MUST NOT be registered and then hidden" (`:46`).
- **Declare and gate.** A feature is "a module, a settings page or tab, a slash verb, a launcher menu entry, a key
  binding, or an event registration"; it "MUST be declared … `clients = { "retail" }`" and "gated at
  registration … through `Compat.ForClient(clients)` where the addon registers it itself (a module's
  `OnInitialize`, an event registration)" (`STD/clients.md:42-45`).
- **Per-client feature table.** "MUST carry a per-client feature table in `docs/ARCHITECTURE.md` … one row per
  declared feature … its client, and the file that gates it" (`STD/clients.md:47`).
- **Seeds.** "MUST exist as two lists, one per client" and "MUST be chosen once, at load or at first use, by
  `ClientKey()`" and "MUST NOT be a single Retail list filtered at runtime" (`STD/clients.md:62-64`).
- **Detection.** "MUST ask which client it is on only through `LibKa0s-Compat-1.0`: `IsForever()`, `IsRetail()`
  and `ClientKey()`" (`STD/clients.md:33`). "SHOULD read the player's specialization and the role it plays
  through `LibKa0s-Role-1.0`" (`:34`). "MUST NOT … decide the client from an interface number" (`:35`).
  Feature detection "MAY" fill one API gap inside a supported feature, and "MUST NOT decide whether a whole feature
  exists" (`:37`).
- **Compat.** "the family is the only place an addon touches them in a shim, and no other file reads a
  `WOW_PROJECT_*` global" (`STD/compat.md:5`). The split rule: a split file "MAY be opened only when the family's
  combined length would otherwise put `core/Compat.lua` past layout-§1's 1000-line on-notice line"
  (`STD/compat.md:11`). `core/Compat.lua` is at 979 lines today (MEASURED, `wc -l`), so new client and Role members
  likely need a new topic file (for example `core/CompatClient.lua`). **INFERRED.**
- **TOC.** "`Retail · Forever` … MUST carry one `## Interface:` line with two numbers … today `120105, 16001` …
  No load-gating line" (`STD/toc-file.md:62`). "The README `[wow]` badge … MUST show the same number or numbers
  as the TOC" (`:85`).
- **Roster.** "MUST flip the row in the same change that lands the port" (`STD/clients.md:26`).
- **Tests.** "MUST run a dual-client addon's headless suite under both kit profiles … A suite that passes on one
  profile and not the other is a failing suite. A per-client feature MUST have a test on each profile: present
  where declared, absent where not." (`STD/clients.md:76`). "A `Retail · Forever` addon MUST be green under both
  profiles, and its commit gate runs both" (`STD/testing.md:47`).
- **Smoke.** "every check names the client it runs on … A feature absent on a client gets a smoke check that it
  is not there" and "MUST NOT be marked passed by an agent" (`STD/clients.md:78-79`).
- **Default skin.** "It is Ka0s Default (`ka0s`) on Retail and WoW Forever (`forever`) on the WoW Forever client.
  The library answers it: `Skin:DefaultSkin()` … An adopted addon's profile defaults MUST name that answer, read
  once at file load into a seam value such as `NS.DEFAULT_SKIN` … MUST NOT write the literal `"ka0s"` as the
  profile's default skin" (`STD/skinning.md:36`).
- **Names.** client-quirks-§5, quoted in section 6 (`STD/client-quirks.md:209-239`).
- **Quirks block.** A Forever behavior "is written with `Forever` and its build" (`STD/client-quirks.md:27`);
  the addon's own quirks go below the vendored block in `docs/midnight-quirks.md` (`:37-65`).
- **Sim.** The simulator routes "every client read the simulation answers" through the compat family
  (`STD/compat.md:19`, `STD/preview-mode.md:42`). New Compat members for Role, names and the ranged slot are
  therefore in the seam's reach, and `core/SimSetup.lua` wraps them (`DropWatcher.toc` comment on SimSetup).

## 16. The per-port checklist, applied to DropWatcher

From `CT/2026-11-07-WOW_FOREVER_PORT_STEP5/01_WAVE1_PLAN.md:26-41` and `03_WAVE2_PLAN.md:31-41`.

| # | Item | What it means for DropWatcher |
|---|---|---|
| 1 | Re-vendor LibKa0s | v1.93.0 → v1.95.0 (Compat 3→4: `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey`; Skin 17→18: `DefaultSkin`; Role 1 new; Launcher 9→10; DebugLogDiagnostics 7→8; kit 53→54, CCN split only). Roll the `CLAUDE.md` provenance line (`CLAUDE.md:45`). MEASURED (`git show v1.93.0/v1.95.0`) |
| 2 | TOC | `## Interface: 120105, 16001`, no gating line (`DropWatcher.toc:1`). This arms the forever missing-globals check (0 findings today, section 2.2) |
| 3 | README | Badge `WoW-Midnight_12.1.5_and_Forever_1.60.1` (`README.md:3`); opening "Supports Retail and WoW Forever." (`README.md:9`); tests badge to the regenerated count (`README.md:7`) |
| 4 | DEPENDENCIES.md | The runtime row names both clients and the two-number line (`DEPENDENCIES.md:12-13` says "Retail only"). The Pawn bullet (`:21-30`) says Pawn on Forever has no Automatic mode and one scale per tree; CanIMogIt is Retail-only |
| 5 | Per-client feature table (clients-§4) | `docs/ARCHITECTURE.md` Module Map (`:50`): one row per Retail-only feature in section 12 (situations, scenarios, transmog rows and event, track row and token, trade timer, off-spec, journal pool, `CHALLENGE_MODE_*` and `EJ_LOOT_DATA_RECIEVED` registrations) with the gating file, and the Forever-only ones (master-loot pending, BoE-only trade rule, ranged slot plan) |
| 6 | Both kit profiles in the gate | `CLAUDE.md:39` and `docs/testing.md:8,703` add `KA0S_KIT_CLIENT=forever lua tests/run.lua`. The 8 failures in 2.1 become per-profile cases |
| 7 | FOREVER smoke theme | `docs/smoke-tests.md` "Before you start" (`:59`) gets a Clients note; a new FOREVER theme: install (no `DropWatcher` symlink in `FV/Interface/AddOns` today, MEASURED), absent-feature checks (no Mythic+/delve/LFR/follower rows, no transmog rows, no Track row), names, Pawn scale, ranged slot, BoE trade, master-loot pending, roll display, roll popup marks |
| 8 | `docs/test-cases.md` | Regenerate (`lua tests/run.lua --list`, `docs/testing.md:674`); 2239 today vs 2242+1 run |
| 9 | Default skin per client | `core/SkinSetup.lua:99` `DEFAULT = "ka0s"` and `defaults/Profile.lua:254-255` become `NS.DEFAULT_SKIN` (`Skin:DefaultSkin()`), with the fallbacks at `core/SkinSetup.lua:399,410,723`. Tests pin the default per profile (`03_WAVE2_PLAN.md:40-41`) |
| 10 | Names via `Compat.UnitCharacterName` | Section 6's 13 rows; surfaces sized for "First Surname" |
| 11 | Roster row | `WowAddonStandards/standards/ADDONS.md:24` → `Retail · Forever` in the landing change |
| 12 | Quirks | Forever behaviors DropWatcher meets (spec `1485` = class name, Pawn without specs, ranged slot) go in `docs/midnight-quirks.md`'s own section with the build |

Two things the wave plans did not have and DropWatcher needs: client detection routed in Compat (`IsForever`,
`IsRetail`, `ClientKey`, `ForClient`, none routed today), and `Compat.ForClient` around `NS.FEATURE_EVENTS` rows
(`core/DropWatcher.lua:20-46,91-113` registers every row on both clients). **MEASURED.**

## 17. Open probes (owner, in game on Forever 1.60.1)

Each is a line to type and what to read. None is passed by me.

1. `/dump C_SpecializationInfo.GetSpecialization(), C_SpecializationInfo.GetSpecializationInfo(1)` on a Warrior,
   a Druid and a Paladin. Expect one spec, its id (Warrior `1491`?) and the class name.
2. `/dump GetSpecialization, GetSpecializationInfo, GetInspectSpecialization, GetCVarBool("loadDeprecationFallbacks")`.
   Expect nil, nil, nil, false. If the CVar is false on Retail too, `Compat.InspectSpecID` is dead there.
3. Inspect a group member, then
   `/dump C_SpecializationInfo.GetInspectSpecialization("target"), C_Traits.GetConfigInfo(Constants.TraitConsts.INSPECT_TRAIT_CONFIG_ID)`.
   Look for a tree ID; if present, `C_Traits.GetGroupCurrencyInfo(-1, groupIDs)` may give another player's tree.
4. `/run local f,m=C_PaperDollInfo.IsRangedSlotShown(),UnitUsesAmmo("player") print(f,m,GetInventoryItemLink("player",18))`
   on a Hunter and a Paladin. Expect `true` and the ranged item or relic link.
5. Link a vanilla drop: `/dump C_Item.GetItemSpecInfo(link), C_Item.GetItemUpgradeInfo(link), C_Item.GetItemStats(link)`.
   Expect nil spec list and nil track; read which stat keys come back.
6. `/dump IsSpellKnown(8737), IsSpellKnown(750)` on a level 40+ Hunter and Warrior. Expect true (mail, plate).
7. `/dump C_TransmogOutfitInfo.IsTransmogEnabled(), C_GameRules.IsGameRuleActive(Enum.GameRule.EncounterJournalDisabled)`.
   Expect false, true.
8. `/run EJ_SelectTier(EJ_GetNumTiers()) print(EJ_GetNumTiers(), EJ_GetInstanceByIndex(1, false))`. Expect 0 or
   nil (journal disabled).
9. Pawn: `/dump PawnOptions.AutoSelectScales, PawnFindScaleForSpec(3, 1), PawnFindScaleForSpec(3, nil)` on a
   Hunter. Expect false, the name of "Hunter: Beast Mastery", a provider scale.
10. In a party: `/dump UnitName("party1"), GetUnitName("party1", true)` and whisper that name with
    `/run C_ChatInfo.SendChatMessage("test","WHISPER",nil,GetUnitName("party1",true))`. Read whether the whisper
    arrives with the two-word name.
11. In a Forever dungeon-finder group: `/dump IsInGroup(LE_PARTY_CATEGORY_INSTANCE), GetInstanceInfo()`. Read
    whether the instance channel exists and which difficulty ID a dungeon and Molten Core answer (1? 9? 242?).
12. `/dump C_MountJournal.GetNumMounts(), C_ToyBox.GetNumToys(), C_PetJournal.GetNumPets()`. Read which journals
    hold anything.
13. After a group-loot drop: `/dump C_LootHistory.GetSortedInfoForDrop(encounterID, lootListID).winner.playerName`.
    Read whether the winner's name is one word or two.
14. `/dump C_PartyInfo.GetLootMethod()` under group loot and master loot. Read the method and the master
    looter's party/raid index (notes 01 and 02 own the loot reads).
