# Drop Watcher on WoW Forever, and everyone's loot rolls — design

Date: 2026-11-13. Branch `feat/2026-11-13-forever-port`. Evidence: the five research notes in
[`../research/2026-11-13-forever-port/`](../research/2026-11-13-forever-port/) (cited below as R1–R5, with the
note's own section). The collection-wide port bundles are in `Ka0sAddonsCommonTasks/docs/2026-11-07-WOW_FOREVER_PORT/`
and `…_STEP5/`.

## 1. Intent

Drop Watcher answers three questions for each drop: is it an upgrade for me, is it an upgrade for the looter, and
can it change hands. Today the answers assume Retail's personal loot, where an item that is no upgrade for its looter
can be traded for four hours. This run does three things:

1. **Ports Drop Watcher to WoW Forever** from the same codebase (clients-§1, the owner's 2026-11-07 ruling), so one
   TOC, `## Interface: 120105, 16001`, serves Retail and Forever.
2. **Fits Forever's loot rules.** Forever has no personal loot, and a looted BoP item is soulbound for good. So the
   useful moment moves from "after the drop: ask the looter to trade" to "before it is assigned": the roll, or the
   master looter's choice.
3. **Adds everyone's loot rolls, on both clients.** A rolled drop shows live while the roll is open, then the final
   result. The roll table is kept in History.

### Owner rulings (2026-11-13, fixed)

| # | Ruling |
|---|---|
| O1 | Forever has no personal loot. In practice the owner sees Group loot, Free for all and Master loot. |
| O2 | On Forever a looted BoP item is soulbound, with no trade window (measured in game). |
| O3 | Rolls show live, then final. |
| O4 | Rolls are kept in History. |
| O5 | Forever: Ask, Offer, auto-ask and the tradeables list only for BoE. The trade estimate reads "No: soulbound" for BoP. Retail is unchanged. |
| O6 | Master loot: a pending "awaiting master looter" drop, with a one-click polite whisper "Ask the master looter". It uses the same one-ask guard and restriction queue as today's ask. |
| O7 | Drop Watcher annotates Blizzard's Need/Greed popup with your verdict, on both clients. |
| O8 | Forever: verdicts are score-first (Pawn or custom weights). Item level is only a tiebreak, and the fallback when there is no score. Retail is unchanged. |

## 2. Goals, non-goals, anti-goals

**Goals**

- Green under both kit profiles (`retail` and `forever`) and luacheck 0/0. The commit gate runs both (testing-§3,
  clients-§6).
- Every Retail-only feature is **absent** on Forever, not hidden (clients-§4). The per-client feature table is in
  `docs/ARCHITECTURE.md`.
- The roll feature, master-loot pending and the popup mark work on both clients wherever the loot method makes them
  apply. Master loot also exists on Retail, as China-only "Guild Master Loot" (R1 §1.3).
- No Retail behaviour changes except the new roll feature and popup mark.

**Non-goals (this run)**

- Forever tier tokens (AQ40 / Naxx), and Forever seed lists of real item IDs for the sim pool. The own-gear fallback
  stands in.
- Parsing roll chat lines. `C_LootHistory` is the only roll source (§5.1). Chat parsing is a recorded follow-up.
- Rebuilding off-spec judging on Forever talent trees. Off-spec is Retail-only (§4.4).
- An Insights section over rolls. The data is kept so a later run can chart it.
- Loot-council or addon-comms features (RCLootCouncil style). No `SendAddonMessage`.
- Version bump, tag or release (the owner's call).

**Anti-goals (failure even if it works)**

- Anything that taints Blizzard's roll popup or the bottom-managed layout: writing into its frames or tables,
  `SetScript`, re-parenting, re-strata.
- A Forever player seeing a Retail word or control: "personal loot", "Warband", "four hours", Mythic+, Delves, LFR,
  Track, transmog, Off-spec.
- Advising "Need" on a soulbound item you can't use, or offering a trade on Forever that the game can't do.
- A rolling or pending drop leaking into consumers that assume a looted drop: the toast, auto-ask, the trade timer,
  tradeables, the glow, and History before resolution.

## 3. Constraints

- **The Ka0s standard** (CLAUDE.md). The rules this run leans on:
  - clients-§3: detect the client only through LibKa0s-Compat (`IsForever`, `IsRetail`, `ClientKey`, `ForClient`).
  - clients-§4: declare each feature's clients and gate it at registration.
  - clients-§5: Forever seeds are their own lists, picked once by `ClientKey()`, never a filtered Retail list.
  - client-quirks-§5: names go through `UnitCharacterName` / `CharacterKey`.
  - skinning-§2: the default skin comes from `Skin:DefaultSkin()`.
  - toc-file-§3: two Interface numbers, no load-gating line.
  - compat: every client read goes through `core/Compat*.lua`. A new topic file is allowed because
    `core/Compat.lua` is at 979 lines.
  - events-frames-taint: verify each hooked symbol against Blizzard source. A one-way hook gates its body on
    disabled (slash-commands-§7).
  - layout-§1: 1500-line cap, with the recorded split triggers (R3 §15).
  - CCN ≤ 15.
  - History stays additive, `v = 1`.

  If a change can't meet a rule, stop and flag it.
- **LibKa0s v1.95.0** is the vendored target: Compat minor 4 (names), Skin minor 18 (`DefaultSkin`), and
  LibKa0s-Role-1.0 (spec, talent groups, role).
- **Secrets.** Forever keeps Midnight's secret values. Every new client read is guarded and copies plain values out
  once (R2 §7).

## 4. The Forever port

### 4.1 Groundwork (the per-port checklist, R4 §16)

- **Re-vendor LibKa0s v1.95.0.** Re-vendor `libs/LibKa0s/` and `tests/_kit/` (kit 54), roll the CLAUDE.md
  provenance line, and keep the icon declaration. Use `/dev-copilot:wow-revendor-libka0s` in its copy role only. Its
  adoption interview is skipped; this design decides what is adopted.
- **Client routing in Compat.** A new `core/CompatClient.lua` routes `IsForever`, `IsRetail`, `ClientKey` and
  `ForClient`, plus the Role and name readers below. No other file reads `WOW_PROJECT_*`.
- **Gate the event table.** `NS.FEATURE_EVENTS` rows take an optional `clients` field, honoured where
  `core/DropWatcher.lua` registers them through `Compat.ForClient`. The Retail-only rows are `CHALLENGE_MODE_*`,
  `EJ_LOOT_DATA_RECIEVED`, `TRANSMOG_COLLECTION_UPDATED` and the off-spec spec events.
- **Default skin:** `NS.DEFAULT_SKIN = Skin:DefaultSkin()` (`core/SkinSetup.lua`, `defaults/Profile.lua`). The
  stand-in fallbacks read it. Tests pin the default per profile.
- **Names (client-quirks-§5).** Add `Compat.UnitCharacterName` and `Compat.CharacterKey`. Every site in R4 §6 moves to
  them:
  - Roster identity: the whole name, no realm on Forever.
  - Roster `parse`: matches the whole name.
  - `TradePartnerName`.
  - `CharFilter`: `CharacterKey()`.
  - `you()`, `selfLooter` and test mode.
  - Sim names: the per-client shape.
  - `GroupRoster` keys.
  - Whisper recipients: the whole name.

  Every surface that shows a name fits "First Surname" or truncates with the whole name in its tooltip.
- **TOC, README, DEPENDENCIES, roster row.** These land in the milestone where the Forever profile first goes green
  (§9, M3), because the second TOC number arms the kit's Forever missing-globals check. That check is already
  measured clean, with 0 findings (R4 §2.2). The WowAddonStandards `ADDONS.md` row flips to `Retail · Forever` in
  the same landing (clients-§2).

### 4.2 Specs, classes and the Forever ClassData

Forever has one spec per class. Its ID is class-wide (Hunter 1485) and its name is the class name. The talent trees
are `C_Traits` groups. Forever has nine classes (R4 §3).

- **Spec reads go through LibKa0s-Role.**
  - `Compat.PlayerSpecID` → `Role.Spec()`.
  - New `Compat.PlayerTalentTree()` → the top group of `Role.Groups()` as `{ index, name }`. It is nil on Retail, or
    on a tie or 0 points.
  - New `Compat.PlayerRole()` → `Role.Resolve(store)`, with a `db.char.role` store, as QuickComms does.
  - A library-absent stub falls back to today's ladder.
  - `Compat.InspectSpecID` reads `C_SpecializationInfo.GetInspectSpecialization` first. This also fixes a latent Retail
    bug, because the global exists only under a deprecation CVar (R4 §3.2).
- **ClassData becomes two lists picked once (clients-§5).** `core/ClassData.lua` keeps Retail's tables. A new
  `core/ClassDataForever.lua` carries Forever's, and `CD` exposes whichever `ClientKey()` names, at file load. The
  Forever list:
  - **Classes:** the nine Forever classes.
  - **Armor:**
    - Warrior and Paladin: plate from level 40, mail below.
    - Hunter and Shaman: mail from level 40, leather below.
    - Rogue and Druid: leather.
    - Priest, Mage and Warlock: cloth.

    The level test is `UnitLevel` for you, and the inspect's level for others. A probe settles whether
    `IsSpellKnown(750/8737)` is better (R4 §17 #6).
  - **Armor strictness:** vanilla has no armor specialization, so a lower armor type is "usable", not "can't use".
  - **Weapons:** the vanilla proficiencies (R4 §5), with relics and thrown weapons added.
  - **Hands:**
    - Dual wield: Warrior, Rogue and Hunter.
    - Shields: Warrior, Paladin and Shaman.
    - Held off-hands: casters.
    - No Titan's Grip.
  - **Spec rows:** one row per class and talent tree (index 1–3, and the Druid's 4th Pawn scale, §4.3), with the
    primary-stat hint. On Forever the stat gate is soft (§4.5).
- **Gear and inspect.** The candidate's spec is the class-wide ID plus your talent tree. A talent change on Forever
  is `TRAIT_CONFIG_UPDATED` / `CHARACTER_POINTS_CHANGED`, registered for Forever only. The Retail
  `PLAYER_SPECIALIZATION_CHANGED` row is Retail-only.

### 4.3 Pawn on Forever

On Forever Pawn has no specs. It has one "Classic" scale per talent tree, named `HUNTER1`…, with `SpecID` = the tree
index, and Automatic mode off (R4 §10).

- **For you:** the scale is the one whose `SpecID` equals your top talent tree index. The Druid maps as follows:
  - Balance = 1.
  - Feral = 2 (damage) or 3 (tank), by `Compat.PlayerRole()`.
  - Restoration = 4.

  A visible custom scale of your class wins when the owner has picked one in Pawn (today's rule). With no tree
  (0 points or a tie), score with the best of your class's Classic scales, and say so in the tooltip.
- **For others:** score with the best of their class's Classic scales (an "at best" read). If Pawn can't value a scale
  for another class, fall back to item level. The detail card says which.
- `Compat.PawnScaleForSpec` / `PawnVisibleScale` take a per-client index source, so `ClassData.SpecIndex` on Forever
  answers the tree index.
- **Custom weights** (`comparison.weights[specID]`) on Forever are keyed by `"<classFile>:<tree>"`. The weights
  editor strip shows the class's trees. Retail keys don't change.
- **Item stats can be missing** for a Forever drop not yet seen on the realm (R1 §8). The existing score retry
  (5 × 1 s) stays. After that, the verdict is item level plus "score unknown".

### 4.4 Retail-only features (absent on Forever, clients-§4)

Each row is declared `clients = { "retail" }` and gated where it registers.

| Feature | What is absent on Forever |
|---|---|
| Mythic+ / keystones | the `mythicPlus` situation, `CHALLENGE_MODE_*` events, the `key` sim scenario, the keystone header and flush trigger |
| Delves, follower dungeons, LFR, scenarios | their situations and settings rows, sim scenarios and test data |
| Encounter Journal item pool | the journal source in `SimPool` and `EJ_LOOT_DATA_RECIEVED`. Forever's pool is the own-gear fallback |
| Transmog | the `transmog` template and `messages.transmogAsk` rows, the look chips, `TRANSMOG_COLLECTION_UPDATED` and the CanIMogIt reads |
| Upgrade tracks | the Track row, the `{track}` token and the track chips |
| Off-spec | `OffSpec`, `OffSpecCells`, the `askOffSpec` template, the off-spec glow, and their settings rows |
| Trade timer (own BoP countdown) | `TradeTimer`'s countdown and ten-minute warning (`trade.warnAt`). On Forever nothing BoP can be traded |
| Trade rule overrides | the per-situation rule rows (Drops › Situations' Trade column). Forever has one rule (§4.6) |
| Bonus rolls in the sim | the sim's bonus-roll events. The parser rows stay, since they are harmless |
| Personal-loot words | the `personal` / `legacy` rule words never show |

Collectibles (mounts, pets, toys): the readers stay, because they are feature-detected per journal. Smoke checks
whether any appears.

**Seeds picked once by `ClientKey()` (clients-§5):**

- **Situations:** Forever has dungeon, raid, pvp, open world group and solo. A Forever difficulty map adds 242 and
  243, Classic 20 and 10 raids (R4 §12).
- **Per-situation defaults:** Forever has its own.
- **The slot plan:** Forever has the ranged slot 18 for ranged, thrown, wand and relic, and it is read in the gear
  snapshot and the inspect (R4 §9).
- **Test-mode sample members and drops:** Forever samples use the nine classes and Forever places.
- **Sim roster and scenarios.**
- **Sim pool sources.**

### 4.5 Score-first verdicts on Forever (O8)

`Evaluate.decide` takes a verdict mode on `opts.verdictMode`, which the edge (`LootFeed.evalOpts`) sets once per
client. Retail is `"ilvlFirst"`, today's rule. Forever is `"scoreFirst"`:

- **With a score:**
  - If `|scoreDelta|` ≤ 1% of the worn item's score, it is a tie, and item level decides by today's sidegrade band.
  - Otherwise the score's sign decides: upgrade or downgrade.
  - If both tie, it is a sidegrade.
- **Without a score:** item level, exactly as today, with reason `noScore`.
- **The primary-stat gate is soft on Forever.** A missing primary stat never makes "can't use" by itself, because
  vanilla items carry several stats and the score values them. "Can't use" still comes from armor, weapon type and
  class restriction.
- **Gain gates.** The toast's `gainPasses` and auto-ask's `minGain` read the verdict mode. On Forever a score-led
  upgrade passes, and `minGain` applies only when the verdict was item-level-led.
- **Words.** `VERDICT_MEANS` gets Forever wordings: "a higher score (item level breaks a tie)". The per-client words
  are picked once.

### 4.6 The Forever trade model (O2, O5)

- `C.TRADE_RULES` gains `soulbound = { tradeable = false, bopOnly = true }`. On Forever
  `C.TRADE_RULE_NAMES = { "soulbound" }` and every situation's default is `soulbound`, picked once.
- `TradeRules.estimate` is unchanged in order:
  - BoE → `yes boe` (first, already).
  - Warbound → `no warbound`. It never fires on Forever, which is harmless.
  - Else, under `soulbound` → `no soulbound`, with basis `bind`, so `FoldTimer` passes it through untouched (R3 §10).
- New words: `TRADE_REASON.soulbound` "Bind on Pickup items can't change hands once looted.", the short form
  "Soulbound", and the rows "Rule: Bind on Pickup".
- **Effects that fall out of `trade.state == "no"`:** no Ask or Offer, no auto-ask, no toast, not in tradeables, and
  no glow (the glow needs Yes/Likely). That is O5.
- BoE drops behave as today. The looter check doesn't apply to BoE: it's `yes boe`.
- Retail is untouched: `personal` / `group` / `legacy`, and the four-hour window.

## 5. Everyone's rolls (both clients)

### 5.1 Source

`C_LootHistory` is the only roll source on both clients (R2 §0, R5 §1). For each group-loot drop it gives `rollInfos[]`
with each eligible player's name, GUID, class, state (NeedMainSpec 0, NeedOffSpec 1, Transmog 2, Greed 3, NoRoll 4,
Pass 5), roll number (nilable) and `isWinner`. It also gives `currentLeader`, `isTied`, `winner`, `allPassed`,
`startTime` and `duration`.

- **The reader.** A new `core/CompatLoot.lua` holds `Compat.LootHistoryRolls(encounterID, key)`. It returns plain
  fields only, guarded field by field:

  ```
  { link, key, startTime, duration, allPassed, isTied, myState,
    leader = { name, guid, classFile, roll }, winner = { … },
    rolls = { { name, guid, classFile, isSelf, state, roll, isWinner } } }
  ```

  `Compat.LootHistoryDrop` becomes a thin view over it, so there is one call path. The drop-table key reads
  `lootListID or lootListKey` (the Forever rename, R2 §2.2). Also new: `Compat.LootHistoryDropsFor(encounterID)`,
  `Compat.LootHistoryEncounter(encounterID)` (for the name), `Compat.LootHistoryNow()`,
  `Compat.ActiveLootRolls()` and `Compat.LootRollInfo(rollID)`.
- **Events** (NS.FEATURE_EVENTS rows, both clients):
  - `LOOT_HISTORY_UPDATE_ENCOUNTER`: walk the encounter's drops and open the new ones.
  - `LOOT_HISTORY_UPDATE_DROP`: re-read one drop. This already exists; its handler changes.
  - `LOOT_HISTORY_CLEAR_HISTORY`: drop the live mapping only.
  - `START_LOOT_ROLL` / `CANCEL_LOOT_ROLL`: your own roll, for the popup mark (§7).
- **A fallback ticker** runs once a second, only while an open roll exists. It re-reads each open drop and closes it on
  `winner`, `allPassed` or `startTime + duration` elapsed. Blizzard itself polls drop completion every frame (R2,
  skeptic correction 4), so a 1 Hz read is well inside that.
- **Names.** `playerName` is displayed, and `playerGUID` is the key when plain (`Compat.IsSafeKey`). A Forever
  two-word name is kept whole.
- Trash and open-world encounter IDs are opaque keys (R2 §6). Use the encounter name from `LootHistoryEncounter`.

### 5.2 The model: open rolls live beside the feed, not in it

A rolling drop has no looter yet, and every feed consumer assumes one (R3 §8). So open rolls are **not** feed records.
A new store, `NS.Pending` (`modules/Pending.lua`, the edge), holds every drop that is **seen but not yet assigned**,
of two kinds:

- **`roll`** — keyed `encounterID:key`. It holds the roll table above and `state = open | won | allPassed | expired`.
- **`ml`** — keyed by the loot source GUID and item ID (§6). It holds `state = awaiting | assigned | expired`.

Each pending item carries `link`, `itemID`, `facts` (`ItemFacts.Request`) and `me` (`Evaluate` for you only, run
through the same `judgeMe` path). The `me` verdict and its "for you" words are what the popup and the pending row
show.

**Lifecycle:**

1. **Open.** The item gets an entry in `NS.Pending` and the bus sends `PENDING_CHANGED(id, "open")`. The Drops tab
   draws it in a **"Rolling now"** section (§5.3). No toast, auto-ask, glow, History or tradeables touch it.
2. **Update.** Re-read the roll table. If it differs, send `PENDING_CHANGED(id, "rolls")`.
3. **Resolve with a winner.** The pending item hands its roll table to the feed. The receipt
   `source = "history"` (as today) carries `roll = <final table>` and `pendingKey`. `newRecord`/`merge` keep
   `rec.roll`. If a chat or encounter receipt for the same item and winner arrived first, `merge` attaches the roll to
   that record. The pending item closes and the bus sends `PENDING_CHANGED(id, "closed")`. From here the drop is an
   ordinary feed record, judged for the looter as today.
4. **All passed or expired.** The row shows "Everyone passed", or "Roll ended" when no winner was read, for 60 s, then
   closes. Nothing goes to the feed or History, because there's no looter (my call).

The bus catalog gains one message, `PENDING_CHANGED`, sent by Pending. Receivers are Window, the compact window,
`RollPopup` (§7) and the master-loot ask book.

**Reload.** Open rolls survive `/reload` through `Compat.ActiveLootRolls()` and a re-walk of
`GetAllEncounterInfos()` for drops with no winner. They aren't saved.

### 5.3 Showing rolls

**Pure composers** live in a new `modules/RollCells.lua`:

- `RollCells.Summary(roll)` → a one-line cell: "Need 3 · Greed 2 · Pass 1 · waiting 4", or after the end
  "Won by Name (Need 87)". It uses class colours and the skin tones.
- `RollCells.Rows(roll)` → one row per player:
  - The rows are sorted: winner, then numbered rolls high to low, then chosen-without-number, then waiting, then
    pass.
  - Each row has the name, a state glyph and word (Need / Need (off-spec) / Transmog / Greed / Pass / waiting), the
    roll number, and a winner mark.
  - Blizzard's "win protection" rows (a higher roll that is not the winner) are shown, with a muted "(protected)" mark.
    `isWinner` is the truth, not the highest number (R2 §4).
- `RollCells.Timer(roll, now)` → the time left while open.

**Where it shows:**

- **Drops tab, full layout.** A collapsible **Rolling now** section sits above the boss groups. It appears only while a
  pending item exists. Each row shows:
  - the item icon and link;
  - your verdict (Me);
  - the roll summary;
  - the time left (rolls), or "awaiting master looter" (ml);
  - the row action: Ask master looter (ml, §6), or none.

  Clicking the row expands the roll table inline, like the detail card.
- **Compact layout.** The same section as four-line cards.
- **The resolved drop's detail card** gets a **Rolls** box with `RollCells.Rows`. The row tooltip gets the summary
  line.
- **History card.** The kept roll table, same rows.
- **The popup mark** (§7).

**Settings** (schema rows, defaults in `defaults/Profile.lua`):

- `rolls.show` (on): the Rolling now section and the Rolls box.
- `rolls.keep` (on): keep rolls in History.
- `rolls.popupMark` (on), §7.

### 5.4 Keeping rolls in History (O4)

- `H.Snapshot` and `H.Refresh` take `roll` from the record into the entry as `rolls`. It is additive, and `v` stays 1.
  `takeSnaps` compares it, so `HistoryChanged` fires when the roll lands after the entry.
- **The kept shape is compact:**
  - `rolls = { at, allPassed, n, w = <winner index>, r = { {name, class, s, n?}, … } }`;
  - `s` is the state number, `n` the roll number;
  - it is capped at 40 rows (a full raid);
  - GUIDs are not kept;
  - the `at` epoch comes from `time()`.

  That's about 1.5 kB per rolled drop at 40 players, inside the 5,000-drop ceiling in practice. Rolled drops are a
  small share.
- `WindowHistory.AsDrop`, `FeedRestore.Receipt` and `FeedRecords.TestRecord` name the new field. `/reload` brings the
  roll table back on restored drops.
- Retention and the ceiling are unchanged.

## 6. Master loot pending, and "Ask the master looter" (O6)

**Detection** goes through a new `Compat.LootMethod()`, which returns `{ method, mlUnit, mlName, threshold }`. It
reads `C_PartyInfo.GetLootMethod()`:

- The master looter's unit is `party<N>`, `raid<N>` or `player`. The name comes from `Compat.UnitCharacterName`.
- The threshold reads `Constants.LootConsts.MasterLootQualityThreshold` (the runtime key on both clients: 4 on Forever,
  5 on Retail; R1 skeptic C1), then `Constants.LootConsts_Camelot`, then 4 on Forever or 5 on Retail.
- `PARTY_LOOT_METHOD_CHANGED` and `GROUP_ROSTER_UPDATE` refresh it.

**Pending source.** On the raider's own client, on `LOOT_READY`/`LOOT_OPENED` while the method is master loot and you
are not the master looter:

- Scan the loot slots for `quality >= threshold`. The slot must have a readable link, and `locked` is allowed.
- Each becomes an `ml` pending item keyed by `GetLootSourceInfo` GUID + itemID. The key is deduped across re-opens.
- This needs the raider to open the corpse. Whether a non-master-looter can see the slots at all is probe P-ML1.
- If they can't, the feature degrades gracefully: no pending items, and the drop arrives as a normal receipt when it
  is assigned.

**Resolution.** A receipt (chat `LOOT_ITEM` or `ENCOUNTER_LOOT_RECEIVED`) for the same itemID within 10 minutes
assigns it, oldest first. The pending item hands `askedML` (if sent) to the record and closes. Leaving the instance or
group, or 15 minutes passing, expires it.

**The send.** A new message kind, `askML`, has its own one-ask slot `(askML, ML, pendingID)` and its own template
`messages.templates.askML`. The default is "Hi {player}, if nobody needs {item}, I'd love it: {mygain} for me. Thanks!",
with tokens `player` = the master looter, and `item`, `ilvl`, `slot`, `mygain`. It is a new kind, not an ask template,
because:

- the target is the master looter, not a looter;
- it is filed against a pending item, not a feed record;
- auto-ask never sends it.

Behaviour:

- It has the same queue, restriction gate (`Restrictions.CanSendChat`, which includes chat lockdown) and confirmation
  line.
- It is one click with no confirm dialog, the same shape as Ask. The edit-first box applies when `editFirst` is on.
- It is refused when you are the master looter, when the item is not an upgrade for you (`me` not upgrade or
  sidegrade), or when the master looter is offline.
- `History` gets `SENT_OUTCOME.askML = "asked"` for the record the pending item turns into, so an assigned item you
  asked for shows "Asked", then "Received" if it is yours.
- **Standards.** Addon-sent chat sits under the existing register row (design spec §9, one send per click), which
  this send keeps. No new deviation row is needed. The plan's documentation step confirms that row's wording covers a
  whisper to the master looter.

## 7. The roll popup mark (O7, both clients)

- **The frames.** `GroupLootFrame1..4` are the frames on both clients. They are not protected and have no secure
  template (R2 §10). The button layout differs: Retail puts the buttons on the frame, and Forever puts them in
  `LootButtonContainer`. The mark doesn't touch buttons.
- **How the mark is drawn.** A new `modules/RollPopup.lua` holds one owned overlay frame per popup, created at
  enable. Each is parented to `UIParent` and anchored to `GroupLootFrameN`, just above its top edge (BOTTOM to TOP,
  centred). It is a single line: the verdict glyph and word, coloured by tone. Examples:
  - "Upgrade +12 · score +4.1%";
  - "Not for you: plate";
  - "BoP · soulbound for you". On Forever a BoP that is an upgrade reads "Need: upgrade"; one you can't use reads
    "Greed / Pass: you can't use it".
  - With the roll open, a second muted line: "Need so far: 2".
- **Hooks.** `GroupLootFrameN:HookScript("OnShow"/"OnHide")`, installed once at enable for N = 1..4.
  - The hook body gates on the disabled state (slash-commands-§7: a one-way hook).
  - On show it re-checks `frame:IsShown()` and a non-nil `rollID`, because Blizzard can close a popup at once
    (R2, skeptic correction 6).
  - It never writes into Blizzard's frame or its table.
  - It never calls `SetScript`, `SetParent`, `SetPoint` on the Blizzard frame, or a strata change.
  - Each symbol is verified against both source trees at the interface version (events-frames-taint-§6).
- **Data.** `START_LOOT_ROLL(rollID)` → `Compat.LootRollInfo(rollID)` (link, bindOnPickUp, canNeed, canGreed,
  canTransmog) → `ItemFacts` + `Evaluate` for you → `RollPopup` caches by rollID. On show, the overlay reads the cache
  and asks once if it's missing. The "Need so far" line comes from the matching `roll` pending item, joined by item ID,
  oldest unclaimed first, like XLoot and RPGLootFeed (R5 §1.4).
- **Forever gamepad mode** (`GamepadGroupLootRollFrame`) is skipped while `InputUtil.IsGamepadUIEnabled()` is true.
  That's a recorded limitation.
- **Settings.** The setting is `rolls.popupMark` (Alerts › Roll popup). It uses the skin's font and tones.
- **Docs.** The taint note goes in `docs/ARCHITECTURE.md` → Taint Notes.

## 8. Sim and test mode

- **Sim.** Every new Compat member (in `CompatClient`, `CompatLoot`, `LootMethod`) is defined before
  `core/SimSetup.lua`, so the seam wraps it (`test_sim_e2e` `Unwrapped()` empty). `SimWorld` providers answer:
  - the roll table for invented `encounterID:key` pairs;
  - `ActiveLootRolls` and `LootRollInfo`;
  - the loot method and master looter;
  - the master-loot loot-window slots.

  `SimEvents` gains:
  - **a seeded roll plan:** members choose over a few seconds, numbers appear at the end, and the winner is set;
  - **a master-loot plan:** a pending Epic, then the assignment after a delay.

  Plus the steps and verbs `roll` and `ml` (`/dw sim roll`, `/dw sim ml`), a `SimReport` line, and a popup stand-in.
  The real popup can't be faked, so the sim draws the overlay against a stand-in frame of the popup's size.
- **Test mode** adds sample pending items: one open roll, one awaiting master looter, and a resolved drop with a roll
  table in the sample History log. Per-client sample seeds per §4.4.

## 9. Milestones

The plan turns these into checkpointed items. Each milestone ends green under both profiles where §9 says so, and is
pushed.

| M | What | Gate at its end |
|---|---|---|
| M0 | Research, this design, the plan | docs only |
| M1 | Re-vendor LibKa0s v1.95.0; `CompatClient` (client, Role, names); default skin; the name sites; `FEATURE_EVENTS` client gating | retail green; forever: the 8 known spec failures may remain |
| M2 | Specs and ClassData per client; Pawn on Forever; the ranged slot; score-first verdicts | retail and forever green |
| M3 | The Retail-only gating (§4.4); the Forever trade model (§4.6); the Forever seeds; TOC `120105, 16001`, README, DEPENDENCIES, roster row; the per-client feature table | both green, Forever globals armed. **The port is complete here** |
| M4 | Rolls: `CompatLoot`, `Pending`, `RollCells`, the Rolling now section (full and compact), the Rolls box, History, restore, sim `roll`, test mode | both green |
| M5 | Master-loot pending and `askML` | both green |
| M6 | The roll popup mark | both green |
| M7 | Docs sweep, the FOREVER smoke theme and the in-game probe sheet, the final review, push | both green, lizard 0 > 15, inventory regenerated |

## 10. Left to the builder

- Exact file splits under the size triggers. `LootFeed` stays under 1100, `WindowCells` and `WindowGroup` under 1250,
  `Window` under 1100, and a new mock family goes to its own `tests/wow_mock_*.lua`.
- Exact colours and glyphs, from the skin tokens.
- Wording of new locale strings, in the addon's existing voice.
- Whether a Retail-only module is skipped at `OnInitialize` or its rows are left out of the schema. Either is
  clients-§4 "absent", so pick per module, and the feature table names it.

## 11. Calls taken after the builder check (Claude, 2026-11-13)

The owner can override any of these at the merge gate.

1. **Pending items pass the feed's pre-looter gates.** A roll or master-loot item enters `NS.Pending` only if the feed
   would show the item for you. That covers:
   - the situation's on/off;
   - the quality gate, in its fixed and dynamic modes;
   - the category toggles and the whitelist/blacklist;
   - the "usable by me" filters when they are set.

   The looter-dependent gates (CharFilter on the looter, "not mine") don't apply. The gate checks become one pure
   function in `FeedFilter` that `LootFeed` and `Pending` both call, so `LootFeed` gains no lines.

   `rolls.show` off hides the Rolling now section and the Rolls box only. Tracking still runs, because the popup mark
   and History use it. The popup mark is shown for every roll whether or not the gate passes, because Blizzard
   already shows the popup.
2. **Master-loot pending and `askML` ship on both clients** (`clients = { "retail", "forever" }`). They apply
   wherever `GetLootMethod()` is master loot, which on Retail is the China-only Guild Master Loot (R1 §1.3). §2's
   "Retail unchanged" means the existing Retail behaviour. The new features are the roll display, the popup mark and
   master-loot pending. Smoke for master loot is Forever's, plus a Retail check that nothing appears under group or
   personal loot.
3. **Outside this repo:**
   - **WowAddonStandards:** the `ADDONS.md` roster row flips on branch `feat/2026-11-13-dropwatcher-forever-port`.
     It's a roster data edit, so no standard version bump, as with the W1/W2 rows.
   - **LibKa0s:** the CLAUDE.md register row for Role (library-stack-§7, "one consumer") is retired on the same
     branch name, because its own re-check trigger is "a second addon reads the role through it". DropWatcher's
     adoption is that second reader. This is a documentation-only edit, with no library release.
   - **Pushes:** the owner's explicit instruction for this run is to commit incrementally and push after major
     milestones, never merging without the go-ahead. That is the instruction CLAUDE.md asks for. Merging, tagging and
     version bumps still wait.
4. **A role override on Forever.** A **Role** row (Automatic / Tank / Healer / Damage), saved per character in
   `db.char.role` through `Role.SetOverride`, sits on General, for Forever only. On Retail, Drop Watcher doesn't read
   the role. It decides the Druid's Feral scale (2 or 3), and any future role-led read. Automatic is
   `Role.Resolve`'s ladder. Its tooltip names what Automatic currently answers, and its source.

## 12. Open probes (the owner's, in game)

The full list goes into `docs/smoke-tests.md` FOREVER and a probe sheet. The design-critical ones:

- **P-ML1:** a non-master-looter opens a master-loot corpse. Do the Epic slots show, with links? (R1 §10 #9)
- **P-R1/P-R2:** when roll numbers appear, and does `UPDATE_DROP` fire per choice? (R2 P1, P2)
- **P-R3:** trash and open-world encounter IDs. (R2 P3)
- **P-NAME:** `rollInfos[].playerName` and whisper target spelling for "First Surname". (R2 P5, R4 #10)
- **P-PAWN:** `PawnFindScaleForSpec(classID, tree)` and valuing another class's scale. (R4 #9)
- **P-LVL:** the armor level rule. (R4 #6)
- **P-SLOT:** the ranged slot. (R4 #4)
