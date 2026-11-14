# Drop Watcher on WoW Forever, and everyone's loot rolls — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drop Watcher serves Retail and WoW Forever from one codebase. It fits Forever's loot rules (no personal loot,
BoP soulbound, master loot), and it shows everyone's loot rolls, live then final, on both clients.

**Architecture:** Client differences go through LibKa0s-Compat (`ClientKey`, `ForClient`) behind `core/CompatClient.lua`.
Forever data is its own list, picked once. Open rolls and master-loot drops live in a new `NS.Pending` store beside
the feed and hand over to it when the drop resolves. The roll popup mark is an owned overlay anchored to Blizzard's
frames.

**Tech Stack:** Lua 5.1 (WoW), Ace3, LibKa0s v1.95.0 (Compat 4, Skin 18, Role 1), the headless harness
`lua tests/run.lua` with the kit profiles `retail` and `forever`, luacheck through `ka0s-bounded`, and lizard.

**Spec:** [`../specs/2026-11-13-drop-watcher-forever-port-design.md`](../specs/2026-11-13-drop-watcher-forever-port-design.md)
(§ references below are to it). Research: [`../research/2026-11-13-forever-port/`](../research/2026-11-13-forever-port/)
R1–R5.

**Run tooling:** [`2026-11-13-drop-watcher-forever-port/`](2026-11-13-drop-watcher-forever-port/):
- `items.tsv` lists the items.
- `checkpoints.tsv` holds the evidence per milestone.
- `RESUME.md` is the log.
- `./resume-state.sh -v` shows what has landed, straight from git.

An item is done when a commit whose subject opens with `<ID>: ` exists on the run branch, or on master, of the repo
that owns it.

## Global Constraints

- **Branch** `feat/2026-11-13-forever-port` (DropWatcher). In WowAddonStandards and LibKa0s it is
  `feat/2026-11-13-dropwatcher-forever-port`.
- **Gate before every commit**, both must pass:
  - `lua tests/run.lua` **and** `KA0S_KIT_CLIENT=forever lua tests/run.lua` (0 failed). Exception: inside M1, the
    8 known Forever spec failures may remain until DW-FP05.
  - `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` 0/0.
- **Never edit** `libs/` or `tests/_kit/` except by the DW-FP01 re-vendor.
- **No version bump, tag or merge.** Push after each milestone.
- **Client checks go only through `NS.Compat`** (`IsForever`, `IsRetail`, `ClientKey`, `ForClient`). No other file reads
  `WOW_PROJECT_*` or decides by interface number (clients-§3).
- **Retail-only features are absent on Forever:** not registered, no settings row, no word. Each is declared in the
  per-client feature table in `docs/ARCHITECTURE.md` (clients-§4).
- **Forever seeds are their own lists, picked once by `ClientKey()`.** Never a filtered Retail list (clients-§5).
- **Every new client read** lives in `core/Compat*.lua`, above `core/SimSetup.lua` in the TOC, is secret-guarded and
  answers plain values only.
- **CCN ≤ 15** for every function (lizard). Files stay under 1500 lines, and under the split triggers:
  - `modules/LootFeed.lua` < 1100;
  - `modules/WindowCells.lua`, `modules/WindowGroup.lua` < 1250;
  - `modules/Window.lua` < 1100;
  - a new mock family goes in its own `tests/wow_mock_<topic>.lua`.
- **History stays additive**, `v = 1`.
- **Every new `L[...]` key** has an enUS entry (`test_locale`).
- **New events and bus receivers** are added to `tests/test_disabled.lua`'s pinned lists.
- **Names** use `Compat.UnitCharacterName` / `Compat.CharacterKey`. Never split a name on whitespace, never read
  `UnitName`'s second return as a realm (client-quirks-§5).
- **Per-client tests:** a per-client feature has a test on each profile: present where declared, absent where not
  (clients-§6). Use `NS.Compat.ClientKey()` in the test to pick the expectation.
- **Commit messages:** `<ID>: <what changed>`, ending with the run's attribution lines.

## Review Focus

These are the five inputs most likely to bite a player. Each has its test in the owning task.

1. **Two identical items on one boss under group loot.** Each roll, pending item and popup mark must stay with its own
   drop (join by item ID, oldest unclaimed first). Test in DW-FP14 and DW-FP20.
2. **A secret or half-filled `rollInfos` inside a raid** (a secret name, a nil roll, an empty list, a `winner` with no
   GUID). The roll table must degrade row by row, never throw, and never key on a secret. Test in DW-FP13.
3. **A `/reload` mid-roll.** The open roll comes back from the client, is not duplicated, and resolves into exactly one
   drop with its table. Test in DW-FP14.
4. **A Forever two-word name** ("Doom Dock") as the looter, the roller, the master looter and the whisper target.
   It must match the roster, be whispered whole, and never become "Doom-Dock" or "Doom". Test in DW-FP04 and DW-FP19.
5. **A Forever BoP upgrade the player can't wear yet** (a level 30 Hunter and mail). The verdict must say "can't use
   yet", or treat leather as fine, never "Need: upgrade" for mail below 40. Test in DW-FP05.

---

## M0 — Research, design and plan (docs)

### DW-FP00: Commit the research notes, the design and this plan

- [ ] `git add docs/superpowers/research/2026-11-13-forever-port docs/superpowers/specs/2026-11-13-drop-watcher-forever-port-design.md docs/superpowers/plans/2026-11-13-drop-watcher-forever-port*`
- [ ] Commit `DW-FP00: Forever port research, design and plan`.

## M1 — Groundwork

### DW-FP01: Re-vendor LibKa0s v1.95.0

**Files:** `libs/LibKa0s/**`, `tests/_kit/**` (copy from tag `v1.95.0` of `../LibKa0s`), `CLAUDE.md` (provenance line
→ v1.95.0), `media/icons/` (prune to the declaration).

- [ ] Run `/dev-copilot:wow-revendor-libka0s` in its **copy role only**. The adoption interview is skipped; this plan
  decides what is adopted. Alternatively, copy by hand from `git -C ../LibKa0s archive v1.95.0` and run the tag's
  `tools/prune-icons.lua`.
- [ ] Check the TOC loads every new library file the vendored `libs/LibKa0s` load order lists, Role.lua among them.
- [ ] Gate. Retail must be green. Forever must show only the 8 known spec failures.
- [ ] Regenerate the test inventory: `lua tests/run.lua --list > docs/test-cases.md`, with the README badge count to
  match.
- [ ] Commit `DW-FP01: Re-vendor LibKa0s v1.95.0 (kit 54)`.

### DW-FP02: CompatClient — client routing, Role and names; client-gated feature events

**Files:**
- Create `core/CompatClient.lua`, listed in the TOC right after `core/Compat.lua`.
- Modify `core/DropWatcher.lua` (the `NS.FEATURE_EVENTS` registration).
- Test: create `tests/test_compat_client.lua`, and register it in `tests/run.lua`.

**Interfaces (produces):**
- `NS.Compat.IsForever() -> boolean`, `NS.Compat.IsRetail() -> boolean`, `NS.Compat.ClientKey() -> "retail"|"forever"`,
  `NS.Compat.ForClient(clients: string[]|nil) -> boolean`. `nil` means both clients.
- `NS.Compat.UnitCharacterName(unit) -> string|nil`, which is the whole name: "Traxex Silentshot" on Forever, "Name" on
  Retail. `NS.Compat.CharacterKey() -> string`.
- `NS.Compat.PlayerSpecID() -> number|nil`. It goes through `Role.Spec()`, and the old ladder is the library-absent
  fallback.
- `NS.Compat.PlayerTalentTree() -> { index: number, name: string }|nil`. On Forever this is the top group of
  `Role.Groups()`. It is nil on Retail, and nil on a tie or 0 points.
- `NS.Compat.RoleStore() -> table`, which is `db.char.role`. `NS.Compat.PlayerRole() -> "TANK"|"HEALER"|"DAMAGER"|nil, source`.
  `NS.Compat.SetRoleOverride(role|nil)`.
- `NS.Compat.InspectSpecID(unit)`: reads `C_SpecializationInfo.GetInspectSpecialization` first.
- A `NS.FEATURE_EVENTS` row may carry `clients = { ... }`. A row is registered only if `Compat.ForClient(row.clients)`.

- [ ] **Tests:**
  - `compat client: ClientKey answers the kit profile` asserts `ClientKey() == (os.getenv("KA0S_KIT_CLIENT") or "retail")`.
  - `compat client: ForClient(nil) is true, ForClient({"retail"}) only on retail`.
  - `compat client: UnitCharacterName joins name and surname on Forever, keeps one name on Retail`, mocking
    `UnitName` → `"Traxex","Silentshot"`.
  - `compat client: PlayerTalentTree is the group with most points; a tie is nil`, mocking `Role.Groups`.
  - `feature events: a retail-only row is not registered on forever`.
- [ ] Run them to see them fail. Implement. Run the gate.
- [ ] Move `test_compat`'s PlayerSpecID case to per-profile expectations.
- [ ] Commit `DW-FP02: CompatClient routes client, Role and name reads; feature events take clients`.

### DW-FP03: The default skin per client

**Files:** `core/SkinSetup.lua` (`NS.DEFAULT_SKIN = Skin:DefaultSkin()`; `:99,399,410,723` read it),
`defaults/Profile.lua:254-255`.

- [ ] **Test:** `skin: the profile default is the client's default skin`. Expected: `"ka0s"` on retail and `"forever"`
  on forever. Cases pinning Ka0s Default's values choose it by name.
- [ ] Implement, then run the gate.
- [ ] Commit `DW-FP03: Default skin per client (skinning-§2)`.

### DW-FP04: Names through UnitCharacterName (client-quirks-§5)

**Files:** every site in R4 §6:
- `core/CompatWorld.lua:60-63`;
- `modules/Roster.lua:95-101,125,250,256-262`;
- `core/Compat.lua:881-889`;
- `modules/CharFilter.lua:49-55,194-200`;
- `modules/LootFeed.lua:194`;
- `modules/LootParser.lua:188`;
- `modules/TestMode.lua:110`;
- `modules/SimEvents.lua:417,431`;
- `modules/SimRoster.lua:111,260`;
- `modules/GroupRoster.lua:47,158,191`;
- `modules/CompactHistory.lua:166`;
- `modules/CompactGroup.lua:556`;
- `modules/Asks.lua:159-165`.

- [ ] **Tests**, in the existing suites (`test_roster`, `test_asks`, `test_char_filter`, `test_loot_parser`):
  - `roster: a Forever chat sender "Doom Dock" matches the member Doom Dock`. Forever profile only; on retail it asserts
    the `Name-Realm` behaviour unchanged.
  - `asks: on Forever the whisper goes to the whole name "Doom Dock"`.
  - `char filter: the character key is CharacterKey(), so two alts named Traxex do not collide`.
- [ ] Implement. Sim names take the per-client shape: Forever is "First Surname" with no realm.
- [ ] Check the width of the Who column, the group roster lines, the toast lines and the Offer panel rows for the long
  form. Truncate with the whole name in the tooltip where needed.
- [ ] Gate (Forever: only the 8 spec failures remain).
- [ ] Commit `DW-FP04: Names through UnitCharacterName and CharacterKey`.
- [ ] **Checkpoint M1:** a row in `checkpoints.tsv`, a log line in `RESUME.md`, a commit, then
  `git push -u origin feat/2026-11-13-forever-port`.

## M2 — Specs, classes, Pawn and verdicts

### DW-FP05: ClassData per client, and the Forever spec model

**Files:**
- Create `core/ClassDataForever.lua` (TOC after `core/ClassData.lua`).
- Modify `core/ClassData.lua`, which exposes the active list at file load by `ClientKey()`.
- Modify `modules/Gear.lua:21,131,376,397`, `modules/Inspect.lua:280`, `modules/Evaluate.lua:136-150` (the stat gate
  mode) and `modules/SimRoster.lua:47,105`.
- Tests: `test_class_data` (new), `test_gear`, `test_evaluate`.

**Interfaces (produces):**
- `CD.SPECS`, `CD.CLASS_SPECS`, `CD.ARMOR`, `CD.WEAPONS` and `CD.SpecIndex(specID, tree)`, with the same shapes as
  today.
- On Forever, `CD.SPECS` is keyed by `"<classFile>:<tree>"`, as `{ stat, dual, shield, offhand, pawn }`. The `pawn`
  index is 1–3, and the Druid has Balance 1, Feral 2 or 3 by role, and Restoration 4.
- `CD.ArmorFor(classFile, level) -> armorType`: the vanilla level-40 rule, so plate/mail from 40, mail/leather below.
- `CD.STAT_GATE = "hard"|"soft"`: retail is hard, forever is soft.
- On Forever, a talent change registers `TRAIT_CONFIG_UPDATED` and `CHARACTER_POINTS_CHANGED`
  (`clients = {"forever"}`), and `PLAYER_SPECIALIZATION_CHANGED` becomes `clients = {"retail"}`.

- [ ] **Tests:**
  - `class data: Forever lists nine classes and no Death Knight, Monk, Demon Hunter or Evoker` (forever profile).
  - `class data: ArmorFor("HUNTER", 30) is leather, ArmorFor("HUNTER", 40) is mail`.
  - `evaluate: on Forever a mail drop for a level 30 Hunter is cantUse with reason armorLevel` (Review Focus 5).
  - `evaluate: on Forever an item with Strength for a Hunter is not cantUse by stat` (the soft gate).
  - `gear: the candidate carries the class-wide spec and your talent tree`. This replaces the 8 failing cases with
    per-profile expectations.
- [ ] Implement, then run the gate. Both profiles must be green.
- [ ] Commit `DW-FP05: ClassData per client; Forever classes, armor by level, soft stat gate, talent events`.

### DW-FP06: The ranged slot on Forever

**Files:** `core/Constants.lua:389-432` (the slot plans picked once per client; Forever adds `C.SLOT.RANGED = 18` with
`INVTYPE_RANGED`, `INVTYPE_RANGEDRIGHT`, `INVTYPE_THROWN` and `INVTYPE_RELIC` → slot 18), `modules/Gear.lua`
(snapshot reads 18 on Forever), `modules/Inspect.lua`.

- [ ] **Tests:**
  - `gear: on Forever a bow compares against slot 18, on Retail against the hands`.
  - `item facts: a relic is gear on Forever, not gear on Retail`.
- [ ] Implement, gate, then commit `DW-FP06: Forever slot plan with the ranged slot`.

### DW-FP07: Pawn and custom weights on Forever

**Files:** `core/Compat.lua:712-804` (`PawnScaleForSpec`, `PawnVisibleScale`, `scaleFits` take the index from
`CD.SpecIndex(specID, tree)`; the Pawn 2.14.1 line refs in comments get updated), `modules/Scoring.lua:177-192`,
`settings/Editors.lua:40-170`, `settings/PageEditors.lua:350-385` (the weights strip shows the class's trees on
Forever).

**Interfaces:**
- `NS.Compat.PawnClassScales(classID) -> { name }[]`.
- `Scoring.ScoreFor(link, who) -> number|nil, how`, where `how` is `"tree"`, `"bestOfClass"`, `"custom"` or `"none"`.
- Forever weights key: `"<classFile>:<tree>"`.

- [ ] **Tests** (a Pawn mock with scales `HUNTER1..3`):
  - `scoring: on Forever your score uses the scale of your top talent tree`.
  - `scoring: with no tree, the best of your class's scales, how = bestOfClass`.
  - `scoring: another player is scored with the best of their class's scales`.
  - `scoring: Feral Druid tank uses Pawn 3, damage Pawn 2`.
  - `scoring: Retail unchanged`, using the existing cases.
- [ ] Implement, gate, then commit `DW-FP07: Pawn and custom weights on Forever by talent tree`.

### DW-FP08: Score-first verdicts on Forever

**Files:** `modules/Evaluate.lua:410-456` (`decide` takes `opts.verdictMode`), `modules/LootFeed.lua:246-248`
(`evalOpts` sets the mode once by client), `modules/Toast.lua` (`gainPasses`), `modules/AutoAsk.lua` (`minGain`),
`modules/WindowCells.lua:55-62` (`VERDICT_MEANS` per client). If `decide` would pass CCN 15, split it.

**Values (spec §4.5):**
- A tie is `|scoreDelta| <= 0.01 * wornScore`.
- In a tie, item level decides by `sidegradeBand`.
- No score means item level, reason `noScore`.

- [ ] **Tests:**
  - `evaluate: scoreFirst, a lower item level with a higher score is an upgrade`.
  - `evaluate: scoreFirst, a score within 1% defers to item level`.
  - `evaluate: scoreFirst, no score is item level with reason noScore`.
  - `toast: on Forever a score-led upgrade passes the gain gate`.
  - `evaluate: ilvlFirst unchanged`, using the existing cases.
- [ ] Implement, gate on both profiles.
- [ ] Commit `DW-FP08: Score-first verdicts on Forever`.
- [ ] **Checkpoint M2:** add the checkpoints row, log a line, push.

## M3 — Retail-only gating, the Forever trade model, the port lands

### DW-FP09: Situations, difficulties and the sim and test seeds per client

**Files:** `core/Constants.lua:461-517` (`C.SITUATIONS` and `C.DIFFICULTY_KIND` picked once; Forever is `dungeon`,
`raid`, `pvp`, `openWorldGroup` and `solo`, with 242 and 243 → raid), `defaults/Profile.lua:54-65,113-118` (per-client
defaults), `modules/Situations.lua`, `modules/GroupPlace.lua`, `core/CompatWorld.lua:138-155` (keystone reads
Retail-only), `modules/LootFeed.lua:1042-1043` (`CHALLENGE_MODE_*` rows `clients={"retail"}`),
`C.MESSAGE_FLUSH_TRIGGERS`, `modules/SimScenario.lua:69-78` (Forever scenario list without `key`, `lfr` or `delve`),
`modules/TestData.lua:305-328,628-659` (a Forever sample set: nine classes, Forever places), `modules/WindowCompact.lua`
(the keystone header Retail-only), `settings/SchemaRows.lua:258-282`, `settings/SlashVerbs.lua`.

- [ ] **Tests:**
  - `situations: Forever has no mythicPlus, delve, followerDungeon, raidLFR or scenario rows`.
  - `situations: difficulty 242 is a raid on Forever`.
  - `sim scenario: Forever lists no key, lfr or delve`.
  - `test mode: Forever samples use only the nine classes`.
  - The settings page test asserts the Situations table rows per client.
- [ ] Implement, gate, then commit `DW-FP09: Situations, difficulties, sim and test seeds per client`.

### DW-FP10: Journal pool, transmog, tracks, off-spec, bonus-roll sim are Retail-only

**Files:**
- `modules/SimPool.lua:64-78,267-316,483`: the journal source is Retail-only, and Forever uses the own-gear fallback.
- `core/Compat.lua:597-650`, `modules/ItemFacts.lua:359`: the transmog reads and `TRANSMOG_COLLECTION_UPDATED` are
  Retail-only.
- `C.MESSAGE_TEMPLATES`: picked per client, so Forever has no `transmog` or `askOffSpec`.
- `settings/SchemaRows.lua:396-424`.
- The look chips in `modules/DetailCells.lua`, `modules/WindowCells.lua`, `modules/CompactCards.lua` and
  `modules/CompactGroup.lua`.
- The track row and token: `core/Constants.lua:569`, and `modules/DetailCells.lua:193,332-346`.
- `modules/OffSpec.lua`, `modules/OffSpecCells.lua`: the module doesn't initialize on Forever, and the off-spec glow
  row is Retail-only.
- `modules/SimEvents.lua`: the bonus-roll events are Retail-only.
- `modules/Diagnostics.lua`.

- [ ] **Tests**, each per profile:
  - `transmog: no transmog template, row or event on Forever`.
  - `tracks: no Track row or {track} token on Forever`.
  - `offspec: not initialized, no rows, no askOffSpec on Forever`.
  - `sim pool: no journal source on Forever`.
  - `settings: no Retail-only row on the Forever panel`. This is a sweep over the schema: no row whose path is in the
    declared Retail-only list.
- [ ] Implement, gate, then commit `DW-FP10: Journal pool, transmog, tracks, off-spec, bonus-roll sim are Retail-only`.

### DW-FP11: The Forever trade model

**Files:**
- `core/Constants.lua:542-552`:
  - add `C.TRADE_RULES.soulbound = { tradeable = false, bopOnly = true }`;
  - add `C.TRADE_RULE_NAMES` per client, Forever `{ "soulbound" }`;
  - Forever's default rule is `soulbound`.
- `modules/TradeRules.lua`: under `soulbound`, a non-BoE drop answers `no soulbound`, basis `bind`.
- `modules/TradeTimer.lua`: the countdown and `trade.warnAt` are Retail-only.
- `modules/WindowCells.lua:344-466`: `TRADE_REASON.soulbound = "Bind on Pickup items can't change hands once looted."`,
  `TRADE_SHORT.soulbound = "Soulbound"`, and the rows "Rule: Bind on Pickup". If WindowCells passes 1250, move the
  Trade composers out first, to `modules/TradeCells.lua`.
- The per-situation trade rule column is Retail-only.

- [ ] **Tests:**
  - `trade rules: on Forever a BoP drop is no soulbound with basis bind`.
  - `trade rules: on Forever a BoE drop is yes boe`.
  - `feed: on Forever a BoP drop shows no Ask, no Offer, no toast, no glow, not in tradeables`.
  - `trade timer: not running on Forever`.
  - Retail's trade-rule cases are unchanged.
- [ ] Implement, gate, then commit `DW-FP11: Forever trade model: BoP soulbound, BoE only`.

### DW-FP12: The port lands (TOC, docs, roster)

**Files:**
- `DropWatcher.toc:1` → `## Interface: 120105, 16001`, with no load-gating line.
- `README.md`: the badge `WoW-Midnight_12.1.5_and_Forever_1.60.1`, the opening "Supports Retail and WoW Forever.", and
  the test badge.
- `DEPENDENCIES.md`: the runtime row with both clients; Pawn on Forever; CanIMogIt Retail-only.
- `docs/ARCHITECTURE.md`: the **per-client feature table**, with one row per declared feature from DW-FP02 to DW-FP11,
  its clients and the gating file.
- `CLAUDE.md` and `docs/testing.md`: the gate runs both profiles.
- `docs/test-cases.md`: regenerated.
- `docs/midnight-quirks.md`: Forever quirks met, with the build (1.60.1 70790):
  - spec 1485 is the class name;
  - Pawn has no specs;
  - the ranged slot;
  - `lootListKey`.

- [ ] Gate: both profiles green, and the kit's Forever missing-globals suite is now armed and passes.
- [ ] Commit `DW-FP12: Retail and WoW Forever (Interface 120105, 16001)`.

### WS-FP12: The roster row (WowAddonStandards)

- [ ] In `../WowAddonStandards`, on branch `feat/2026-11-13-dropwatcher-forever-port`, edit `standards/ADDONS.md`: the
  DropWatcher row → `Retail · Forever`. Run `scripts/check-standard.sh`.
- [ ] Commit `WS-FP12: DropWatcher row Retail · Forever`. No version bump.
- [ ] **Checkpoint M3:** add the checkpoints row, log a line, push the DropWatcher branch and the WowAddonStandards
  branch. **The port is complete at this point.**

## M4 — Everyone's rolls

### DW-FP13: CompatLoot readers and their mock

**Files:**
- Create `core/CompatLoot.lua` (TOC after `core/CompatClient.lua`, before SimSetup).
- Move `Compat.LootHistoryDrop` here as a view.
- Create `tests/wow_mock_loot.lua`, which holds the `C_LootHistory`, roll globals, `C_PartyInfo.GetLootMethod`,
  loot-slot globals and `GroupLootFrameN` stubs.
- Test: create `tests/test_compat_loot.lua`.

**Interfaces (produces):**
```
Compat.LootHistoryRolls(encounterID, key) -> nil | {
  link, key, startTime, duration, allPassed, isTied, myState,
  leader = {name,guid,classFile,roll}|nil, winner = {...}|nil,
  rolls = { {name, guid, classFile, isSelf, state, roll, isWinner} } }
Compat.LootHistoryDrop(encounterID, key) -> today's shape (a view over LootHistoryRolls)
Compat.LootHistoryDropsFor(encounterID) -> { {key, link, open:boolean} }
Compat.LootHistoryEncounter(encounterID) -> name|nil
Compat.LootHistoryNow() -> number|nil
Compat.ActiveLootRolls() -> rollID[]
Compat.LootRollInfo(rollID) -> nil | { link, bop, canNeed, canGreed, canTransmog, quality }
```
The key reads `drop.lootListID or drop.lootListKey`. The states are the plain numbers 0–5. Every field is guarded,
and a secret field drops that field or that row, never the table.

- [ ] **Tests:**
  - `compat loot: rolls answer every row with its state and number`.
  - `compat loot: a secret playerName drops the name, keeps the row` (Review Focus 2).
  - `compat loot: a secret rollInfos answers rolls = {}`.
  - `compat loot: a nil roll stays nil`.
  - `compat loot: lootListKey is read on Forever-shaped drops`.
  - `compat loot: LootHistoryDrop is unchanged`, using today's `test_compat` cases moved here.
  - `compat loot: LootRollInfo answers bop from bindOnPickUp`.
- [ ] Implement, gate, then commit `DW-FP13: CompatLoot: roll tables, active rolls, roll info`.

### DW-FP14: The Pending store and the roll lifecycle

**Files:**
- Create `modules/Pending.lua` (the edge: store, events, ticker, handoff).
- Modify `core/Bus.lua` (add `PENDING_CHANGED`, sender Pending).
- `modules/LootFeed.lua`: the history handler hands over to Pending. A receipt carries `roll` and `pendingKey`, and
  `newRecord`/`merge` keep `rec.roll`. Net LootFeed lines ≤ +20.
- `modules/FeedFilter.lua`: a pure `FF.PassesForMe(facts, ctx) -> boolean, why` shared by LootFeed and Pending
  (spec §11.1).
- `tests/test_disabled.lua`.
- Test: create `tests/test_pending.lua`.

**Interfaces (produces):**
- `NS.Pending.All() -> item[]`, sorted by `at`.
- `NS.Pending.Get(id)`.
- item = `{ id, kind="roll"|"ml", key, link, itemID, at, state, facts, me, roll?, ml?, askedML? }`.
- roll `state` is `open|won|allPassed|expired`. ml `state` is `awaiting|assigned|expired`.
- Bus `PENDING_CHANGED(id, cause)`, where cause is `open|rolls|closed`.
- Events (both clients):
  - `LOOT_HISTORY_UPDATE_ENCOUNTER`
  - `LOOT_HISTORY_UPDATE_DROP` (handler replaced)
  - `LOOT_HISTORY_CLEAR_HISTORY`
  - `START_LOOT_ROLL`
  - `CANCEL_LOOT_ROLL`
- Ticker 1 s, only while an open roll exists.
- On enable, rebuild from `ActiveLootRolls()` and `GetAllEncounterInfos()` drops with no winner.
- An all-passed or expired item stays 60 s, then closes. Nothing goes to the feed.

- [ ] **Tests:**
  - `pending: an UPDATE_ENCOUNTER with an open drop opens one roll item`.
  - `pending: each UPDATE_DROP that changes the table sends PENDING_CHANGED rolls once`.
  - `pending: a winner hands the final table to the feed; the drop has rec.roll and the pending item closes`.
  - `pending: a chat receipt that arrived first gets the roll attached by merge`.
  - `pending: two identical items on one encounter stay two items with their own tables` (Review Focus 1).
  - `pending: reload mid-roll rebuilds one item, and its winner makes exactly one drop` (Review Focus 3).
  - `pending: all passed closes after 60 s with no feed record`.
  - `pending: a drop below the quality gate is not pending`.
  - `pending: the ticker stops when no roll is open`.
  - `pending: standing down unregisters every event and stops the ticker`.
- [ ] Implement, gate, then commit `DW-FP14: Pending store and the roll lifecycle`.

### DW-FP15: RollCells and the Rolling now section

**Files:**
- Create `modules/RollCells.lua` (pure).
- Create `modules/WindowPending.lua`, the Rolling now section for the full layout. It is drawn above the boss groups by
  `modules/WindowGroup.lua` through one hook call.
- Modify `modules/CompactGroup.lua` (the compact cards for pending items).
- `modules/DetailCells.lua` and `modules/DetailCard.lua`: a **Rolls** box on resolved drops with `rec.roll`.
- `modules/RowTooltip.lua`: the summary line.
- `defaults/Profile.lua` and `settings/SchemaRows.lua`: `rolls.show` (true), `rolls.keep` (true), `rolls.popupMark`
  (true), in a "Rolls" group on the Drops page.
- Locale entries.
- Tests: create `tests/test_roll_cells.lua` and `tests/test_window_pending.lua`.

**Interfaces:**
- `RollCells.Summary(roll, now) -> cell`.
- `RollCells.Rows(roll) -> { {name, classFile, word, glyph, tone, roll, winner, protected} }`.
- `RollCells.Timer(roll, now) -> string|nil`.
- The state words:
  - 0 "Need";
  - 1 "Need (off-spec)";
  - 2 "Transmog";
  - 3 "Greed";
  - 4 "waiting";
  - 5 "Pass".
- Sort order: winner, then numbered rolls high→low, then chosen without a number, then waiting, then pass.
- `protected` = a roll above the winner's with `isWinner == false` once won.

- [ ] **Tests:**
  - `roll cells: summary counts Need 3 · Greed 2 · Pass 1 · waiting 4`.
  - `roll cells: won reads Won by Name (Need 87)`.
  - `roll cells: rows sort winner first, then numbers high to low, waiting, pass`.
  - `roll cells: a higher roll that did not win is protected`.
  - `window pending: the section shows only while an item exists and hides with rolls.show off`.
  - `window pending: a pending row has your verdict and no Ask button for a roll`.
  - `detail card: a resolved drop with rec.roll has a Rolls box`.
  - `compact: a pending item is a card`.
- [ ] Implement, gate, then commit `DW-FP15: Rolling now section, Rolls box and roll cells`.

### DW-FP16: Rolls kept in History

**Files:** `modules/History.lua:197-294` (`Snapshot`/`Refresh`/`takeSnaps` take `rolls`, compact shape spec §5.4, cap
40 rows, honour `rolls.keep`), `modules/WindowHistory.lua:172-181`, `modules/HistoryCard.lua` (the rolls rows),
`modules/FeedRestore.lua:99-108`, `modules/FeedRecords.lua:179-195`.

- [ ] **Tests:**
  - `history: a rolled drop keeps rolls { at, allPassed, n, w, r } with no GUIDs`.
  - `history: the roll arriving after the entry fires HistoryChanged`.
  - `history: 50 rollers keep 40 rows and n = 50`.
  - `history: rolls.keep off keeps no rolls`.
  - `feed restore: a reload brings the roll table back`.
  - `history card: shows the rolls rows`.
- [ ] Implement, gate, then commit `DW-FP16: Rolls kept in History`.

### DW-FP17: Sim and test mode for rolls

**Files:** `modules/SimWorld.lua` (providers for every DW-FP13 reader), `modules/SimEvents.lua` (a seeded roll plan
`E.RollPlan(n, members, rnd)`: choices over about 6 s, numbers at close, a winner, sometimes all passed),
`modules/SimScenario.lua` (step `roll`), `settings/SimVerbs.lua` (`/dw sim roll`), `modules/SimReport.lua` (a roll
line), `modules/TestData.lua` (an open roll, and a resolved drop with a table in the sample History).

- [ ] **Tests:**
  - `sim: every CompatLoot member is wrapped` (`Unwrapped()` empty).
  - `sim: /dw sim roll opens a pending roll, updates it and resolves it into a drop with rec.roll`.
  - `sim report: counts rolls`.
  - `test mode: shows one open roll and a History drop with rolls`.
- [ ] Implement, gate, then commit `DW-FP17: Sim and test mode for rolls`.
- [ ] **Checkpoint M4:** add the checkpoints row, log a line, push.

## M5 — Master loot

### DW-FP18: The loot method and master-loot pending

**Files:** `core/CompatLoot.lua` (adds `Compat.LootMethod() -> { method, isML, mlUnit, mlName, threshold }` and
`Compat.LootSlots() -> { {slot, link, quality, locked, sourceGUID} }`), `modules/Pending.lua` (the `ml` kind),
`modules/Pending*.lua` (split if Pending passes about 600 lines), and events `PARTY_LOOT_METHOD_CHANGED`,
`LOOT_READY`, `LOOT_OPENED` (both clients).

**Values (spec §6):**
- The threshold is read in order: `Constants.LootConsts.MasterLootQualityThreshold`, then
  `Constants.LootConsts_Camelot.MasterLootQualityThreshold`, then 4 (Forever) or 5 (Retail).
- The key is `sourceGUID .. ":" .. itemID`.
- An item resolves on a receipt for the same itemID within 600 s, oldest first.
- An item expires at 900 s, or when you leave the group or instance.
- Nothing is pending when you are the master looter.

- [ ] **Tests:**
  - `loot method: ML unit and name from masterLooterRaidID`.
  - `loot method: threshold falls back to 4`.
  - `ml pending: an Epic slot under master loot opens one ml item; re-opening the corpse does not duplicate it`.
  - `ml pending: a receipt for that item assigns it and the drop carries askedML`.
  - `ml pending: you as master looter see no pending item`.
  - `ml pending: expires at 900 s`.
  - `ml pending: under group loot nothing is pending from the loot window`.
- [ ] Implement, gate, then commit `DW-FP18: Loot method and master-loot pending`.

### DW-FP19: Ask the master looter

**Files:** every site in R3 §9's table, for a new kind `askML`:
- `core/Constants.lua` (`C.MESSAGE_KINDS`, `C.MESSAGE_TEMPLATES`);
- `defaults/Profile.lua` (`messages.templates.askML = "Hi {player}, if nobody needs {item}, I'd love it: {mygain} for me. Thanks!"`);
- `settings/SchemaRows.lua`;
- `settings/Editors.lua`;
- `modules/Asks.lua` (the recipient is the ML; the token context from the pending item);
- `modules/Messaging.lua`;
- `modules/History.lua` (`SENT_OUTCOME.askML = "asked"`);
- `core/DropWatcher.lua` (`NS.PressAskML(pendingID)` and the refusal words);
- `modules/WindowPending.lua` and the compact card (the Ask master looter action);
- `modules/Diagnostics.lua`;
- locales.

Auto-ask never sends it.

- [ ] **Tests:**
  - `askML: one press whispers the master looter once; a second press is refused by the one-ask guard`.
  - `askML: queued while chat is restricted and sent on lift`.
  - `askML: refused when you are the master looter, when it is no upgrade for you, when the ML is offline`.
  - `askML: on Forever the whisper target is the whole two-word name` (Review Focus 4).
  - `askML: the received drop's History entry reads asked`.
  - `messaging: four kinds` (update the `#C.MESSAGE_KINDS == 3` pin).
  - `auto-ask: never sends askML`.
- [ ] Sim: `/dw sim ml` plays a pending Epic, then assigns it after about 20 s (`SimWorld` providers for `LootMethod`
  and `LootSlots`). Test `sim: /dw sim ml shows a pending item, Ask sends a [sim] whisper, assignment resolves it`.
- [ ] Implement, gate, then commit `DW-FP19: Ask the master looter`.
- [ ] **Checkpoint M5:** add the checkpoints row, log a line, push.

## M6 — The roll popup mark

### DW-FP20: RollPopup

**Files:** create `modules/RollPopup.lua`, `tests/test_roll_popup.lua`. Settings row `rolls.popupMark` (Alerts ›
Roll popup, moved from DW-FP15's group if the Alerts page is a better home). `docs/ARCHITECTURE.md` gets a Taint Notes
entry.

**Interfaces / rules (spec §7):**
- One overlay per `GroupLootFrame1..4`, created at enable, parented to `UIParent`, and anchored BOTTOM → TOP of the
  popup.
- `HookScript("OnShow"/"OnHide")` is installed once and gated on disabled.
- The OnShow hook re-checks `IsShown()` and a non-nil `rollID`.
- Never write to the Blizzard frame or its table.
- `START_LOOT_ROLL` → `Compat.LootRollInfo` → facts and the `me` verdict, cached by rollID. `CANCEL_LOOT_ROLL` clears
  it.
- The lines:
  - line 1: the verdict glyph and word, plus gain;
  - line 2: "Need so far: N" from the matching pending roll, joined by itemID, oldest unclaimed.
- Forever BoP wording:
  - an upgrade reads "Need: upgrade";
  - can't-use reads "Greed / Pass: you can't use it".
- Skipped while `InputUtil.IsGamepadUIEnabled()` is true.
- The sim draws it against a stand-in frame of the popup's size.

- [ ] **Tests:**
  - `roll popup: an upgrade roll shows the mark on GroupLootFrame1`.
  - `roll popup: two identical items on two popups each show their own Need so far` (Review Focus 1).
  - `roll popup: a popup closed at once draws nothing`.
  - `roll popup: disabled, the hook draws nothing`.
  - `roll popup: popupMark off draws nothing`.
  - `roll popup: no write to the Blizzard frame table` (snapshot of the mock frame's keys before and after).
  - `roll popup: gamepad mode skips`.
  - `roll popup: Forever BoP cantUse says Greed / Pass`.
- [ ] Implement, gate, then commit `DW-FP20: Your verdict on Blizzard's roll popup`.
- [ ] **Checkpoint M6:** add the checkpoints row, log a line, push.

## M7 — Docs, smoke, review

### DW-FP21: Docs sweep, the FOREVER smoke theme and the probe sheet

- [ ] Update `docs/ARCHITECTURE.md`:
  - the module map gets the new modules;
  - the bus gets 11 messages;
  - the per-client feature table gets M4–M6;
  - Taint Notes;
  - the documented-deviations check: the chat-send row covers `askML`, so reword it if needed.
- [ ] Update `docs/scope.md`, `docs/data-flow.md`, `docs/schema.md`, `docs/settings-panel.md`, `docs/common-tasks.md`
  and `README.md` (features).
- [ ] `docs/smoke-tests.md`:
  - each check names its client;
  - a **FOREVER** theme covers: install via the `_forever_` symlink; the absent Retail features; names; the Pawn tree;
    the ranged slot; BoE/BoP trade; rolls live and final; master-loot pending and Ask ML; the popup mark;
  - a Retail ROLLS theme.
- [ ] Create `docs/forever-probes.md`, the in-game probe sheet from spec §12 and R1 §10, R2 §13 and R4 §17, de-duplicated,
  each with its line to type and what to read.
- [ ] Regenerate `docs/test-cases.md`.
- [ ] Commit `DW-FP21: Docs, FOREVER smoke theme and probe sheet`.

### LK-FP21: Retire the Role one-consumer register row (LibKa0s)

- [ ] In `../LibKa0s` on `feat/2026-11-13-dropwatcher-forever-port`, remove the `library-stack-§7` Role row from
  `CLAUDE.md`'s register and update the register's prose count, naming DropWatcher as the second consumer. Run its doc
  checks.
- [ ] Commit `LK-FP21: Retire the Role one-consumer row: DropWatcher is the second reader`.

### DW-FP22: Whole-run review and the automated-test bundle

- [ ] A multi-lens adversarial review of `master..feat/2026-11-13-forever-port`, as a workflow. The lenses:
  - correctness and the Review Focus list;
  - taint and secrets;
  - the standard (clients-§3–§6, client-quirks-§5, skinning-§2);
  - Retail regressions.

  Fix the findings that are verified.
- [ ] Run `/dev-copilot:wow-automated-tests` for a fresh bundle: lint, both profiles, perf, lizard 0 > 15.
- [ ] Commit `DW-FP22: Whole-run review fixes and automated-test bundle`.
- [ ] **Checkpoint M7:** add the checkpoints row, log a line, push all three branches. **Stop:** the owner's smoke
  (`docs/smoke-tests.md` FOREVER and ROLLS, `docs/forever-probes.md`) and the go-ahead to merge.

## After the go-ahead

`/dev-copilot:finalize` merges the three branches with `--no-ff` and pushes. Then delete every branch, stash and
worktree this run made, locally and on origin.
