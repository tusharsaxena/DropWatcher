# 01 — How loot works on WoW Forever, compared with Retail 12.1.5

Research note for the DropWatcher Forever port. Date: 2026-11-13.

Tags: **MEASURED** means I saw it in source or docs. **REPORTED** means a third party or the web says it.
**INFERRED** means it is my reading and still needs a test.

Paths used below:

- `WF/` = sparse clone of Gethe/wow-ui-source, branch `forever`, 1.60.1 (70888), at
  `/tmp/claude-1000/-mnt-d-Profile-Users-Tushar-Documents-GIT-DropWatcher/8e7a7246-e9bd-4614-aaea-6144aa02c981/scratchpad/wus-forever/Interface/AddOns/`
- `WL/` = sparse clone of Gethe/wow-ui-source, branch `live`, 12.1.5.70783, at
  `.../scratchpad/wus-live/Interface/AddOns/`
- `KF/` and `KL/` = Ketho/BlizzardInterfaceResources, branches `forever` and `live`, files
  `Resources/GlobalStrings/enUS.lua` (gs), `Resources/Events.lua` (ev), `Resources/GlobalAPI.lua` (fn), copied to
  `.../scratchpad/ketho/{gs,ev,fn}_{forever,live}.lua`.
- `PA/` = prior-art addon clones in `.../scratchpad/prior-art/` (XLoot 12.22.1 @0c336bc, Gargul @e3b8d0f, RCLootCouncil2 v3.25.0).

Owner rulings from 2026-11-13 are taken as fixed facts (marked OWNER below). They are in-game observations.

---

## 0. The short version

1. Forever runs the **Retail (Mainline) loot UI and API**. It is not a Classic UI. The Camelot game type is in the
   mainline family, and it loads Mainline `GroupLootFrame`, `LootFrame`, `MasterLooterFrame` and `LootHistory`.
   There are only two small Camelot overrides. **MEASURED** (sections 2, 3, 5).
2. The loot API surface (functions and events) is **the same set on both clients**. No loot function or event exists on
   one client and not the other. **MEASURED** (Ketho fn/ev diff, section 1).
3. Forever has no personal loot in practice. Groups use Group loot (Need/Greed), Free for all or Master loot.
   **OWNER**. The `Personal` enum value still exists. The server decides what is offered through
   `C_PartyInfo.GetAvailableLootMethods()`. **MEASURED** for the API, **INFERRED** that the server leaves out Personal.
4. Master loot threshold: Forever `LootConsts_Camelot.MasterLootQualityThreshold = 4` (Epic). Retail
   `LootConsts.MasterLootQualityThreshold = 5` (Legendary). **MEASURED**.
5. On Forever the group-roll chat lines (`LOOT_ROLL_NEED`, `_GREED`, `_PASSED`, `_ROLLED_*`, `_WON`) all start with
   a `|HlootHistory:%d|h[Loot]|h:` link that carries the encounter ID. On Retail, the lines about *other* players have
   no such prefix. This is the biggest parsing difference. **MEASURED** (section 6).
6. `C_LootHistory` and `GroupLootHistoryFrame` exist on Forever. The only change is that the frame does not auto-open.
   This is the best "everyone's rolls" source on both clients. **MEASURED** (section 5).
7. On Forever a looted BoP item is soulbound with no 2h trade window. **OWNER**. The string
   `BIND_TRADE_TIME_REMAINING` still exists in Forever GlobalStrings, so it cannot be used as proof either way.
   **MEASURED**.

---

## 1. Loot methods

### 1.1 Enum and API (same on both clients)

- `Enum.LootMethod`: Freeforall 0, Roundrobin 1, Masterlooter 2, Group 3, Needbeforegreed 4, Personal 5.
  Forever: `WF/Blizzard_APIDocumentationGenerated/LootConstantsDocumentation.lua:6-19`. Live: identical at
  `WL/Blizzard_APIDocumentationGenerated/LootConstantsDocumentation.lua:6-19`. **MEASURED**.
- `Enum.LootMethodStyles`: Mainline 0, Vanilla 1. Same file, lines 22-31 (Forever) and 22-31 (live). **MEASURED**.
- `C_PartyInfo.GetLootMethod()` returns `method, masterLootPartyID?, masterLooterRaidID?`.
  `WF/Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua:287-295`. **MEASURED**.
- `C_PartyInfo.GetLootMethodStyle()` returns `LootMethodStyles`. Same file `:298-305`. **MEASURED**.
- `C_PartyInfo.GetAvailableLootMethods()` returns a table of `LootMethod`. Same file `:187-193`. **MEASURED**.
- `C_PartyInfo.IsLootMethodAvailable(method)` and `C_PartyInfo.SetLootMethod(method, lootMaster?)` (restricted).
  Same file `:436-445` and `:562-570`. **MEASURED**.
- The only PartyInfo doc difference between the clients is one new `isCrossShard` field on Forever
  (`diff` of the two PartyInfo docs). **MEASURED**.
- Event `PARTY_LOOT_METHOD_CHANGED`, no payload, `UniqueEvent`.
  `WF/.../PartyInfoDocumentation.lua:795-799`. Present in both Ketho event lists. **MEASURED**.
- There is **no `LOOT_METHOD` event** in either Ketho event list. `LOOT_METHOD` is only a GlobalString
  ("Loot Method"). **MEASURED** (`KF gs`, grep of `ev_*`).
- The legacy global `GetLootMethod` is **gone on both clients** (0 hits in `fn_forever.lua` and `fn_live.lua`). Only
  `C_PartyInfo.GetLootMethod` exists (`fn_forever.lua:3081`). Blizzard_DeprecatedPartyInfo has no shim for it.
  **MEASURED**. Gargul guards for both forms (`PA/Gargul/Utils/Shims.lua:182-195`).
- Ketho GlobalAPI diff, live vs forever, filtered for loot/roll/bind/trade: Forever adds only
  `C_AutoLoot.SetUseAutoLootToggle`, `C_LootFrame.TryAutoLoot` and `UnitHasLootInteraction`. Every roll and
  master-loot global (`GetLootRollItemInfo`, `GetLootRollItemLink`, `RollOnLoot`, `GetLootRollTimeLeft`,
  `GetActiveLootRollIDs`, `GetMasterLootCandidate`, `GiveMasterLoot`, `DoMasterLootRoll`, `IsMasterLooter`,
  `GetLootThreshold`, `GetLootSlotLink`, `GetLootSlotInfo`, `GetLootSourceInfo`, `ConfirmLootRoll`, ...) is on both.
  **MEASURED**.

### 1.2 How the Blizzard menu picks methods

- The loot-method menu shows only if `#C_PartyInfo.GetAvailableLootMethods() > 1`, and each entry shows only if
  `C_PartyInfo.IsLootMethodAvailable(method)` is true. Personal is one of the six entries.
  `WF/Blizzard_UnitPopup/Mainline/UnitPopupButtons.lua:646-700, 785, 805-809`. **MEASURED**.
- So the list of methods is decided by the server, not by Lua. **INFERRED** from the code above.
- `GetLootMethodStyle()` is **not used anywhere** in the Forever FrameXML I checked out (grep found only the doc).
  Its value on Forever is unknown. **MEASURED** (no use) / open probe.

### 1.3 Defaults per content

- Forever: no Blizzard article explains loot distribution. A fan wiki says "Blizzard has not published how loot
  distribution works in Forever". **REPORTED**:
  https://guildorder.com/hi/games/wow_forever/wiki/loot-systems-for-a-10-and-a-20
- Forever, as the owner sees it: Group loot, Free for all and Master loot. No Personal. **OWNER**.
- Forever defaults per dungeon / raid / open world: **unknown**. Classic-family habit is Group loot for a new party, with
  the leader able to switch to Master loot. Treat as **INFERRED** until probed.
- Retail 12.1.5: Personal loot is the default in dungeons. Group loot (Need main spec / off spec, Transmog, Greed)
  came back with Dragonflight for raids. **REPORTED**: https://warcraft.wiki.gg/wiki/Loot,
  https://mein-mmo.de/en/wow-brings-group-looting-back-but-does-it-much-better-than-before,886105 (2022-10-02).
- Retail master loot came back in 12.0.5 for CN realms only, as "Guild Master Loot". **REPORTED** by XLoot
  (`PA/XLoot/Modules/Master/Retail.lua:1`, `Master.lua:1`). Matches the live GlobalString
  `LOOT_MASTER_LOOTER = "Loot: Guild Master Loot"` (`KL gs:13395`) vs Forever `"Loot: Master Loot"` (`KF gs:13884`).
  **MEASURED** for the strings.

---

## 2. Group loot (Need / Greed)

### 2.1 Events and functions

- `START_LOOT_ROLL(rollID, rollTime, lootHandle?)`. `WF/.../LootDocumentation.lua:405-416`. **MEASURED**.
- `CANCEL_LOOT_ROLL(rollID)`, `CANCEL_ALL_LOOT_ROLLS`. `:90-105`. **MEASURED**.
- `LOOT_ROLLS_COMPLETE(lootHandle)`. `:238-247`. **MEASURED**.
- `MAIN_SPEC_NEED_ROLL(rollID, roll, isWinning)`. `:268-279`. **MEASURED**.
- `LOOT_ITEM_ROLL_WON(itemLink, rollQuantity, rollType, roll, upgraded)`. `:204-216`. Fires for your own win.
  **MEASURED** (doc) / **INFERRED** (self only).
- `CONFIRM_LOOT_ROLL(rollID, rollType, confirmReason)`, `CONFIRM_DISENCHANT_ROLL(rollID, rollType)`. `:106-128`.
  **MEASURED**.
- `C_Loot.GetLootRollDuration(rollID)` (`:10-24`). `GetLootRollItemInfo`, `GetLootRollItemLink`, `RollOnLoot`,
  `GetLootRollTimeLeft`, `GetActiveLootRollIDs` are undocumented globals present on both (Ketho fn). **MEASURED**.
- `LootDocumentation.lua` is **byte-identical** between live and forever (`diff` empty). **MEASURED**.

### 2.2 Roll types on Forever

- Forever documents `Enum.LootRollType`: Pass 0, Need 1, Greed 2, Disenchant 3, Transmog 4.
  `WF/Blizzard_APIDocumentationGenerated/LootConstants_MainlineDocumentation.lua:23-37`. The live docs I have do not
  document this enum at all (grep empty in `WL/Blizzard_APIDocumentationGenerated`). **MEASURED**.
- Forever also documents `Enum.LootRollDisabledReason` 0-7 (None, NotAllowed, UniqueRestriction, NotDisenchantable,
  InsufficientEnchantSkill, GreedOnly, HasBetterExactItem, MissingProfession). Same file `:5-21`. **MEASURED**.
- The Forever roll frame reads `GetLootRollItemInfo(rollID)` as
  `texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed,
  reasonDisenchant, deSkillRequired, canTransmog`. If `canTransmog`, the Transmog button replaces Greed.
  `WF/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:317, 347-358`. **MEASURED**.
- The gamepad path calls `RollOnLoot(id, 0|1|2|4)`. There is no `RollOnLoot(id, 3)` call.
  `GroupLootFrame.lua:1274-1291`. The plain buttons call `RollOnLoot(rollID, self:GetID())` (`GroupLootFrame.xml:7`).
  **MEASURED**.
- Need main spec vs off spec: the roll *call* is still Need = 1. The split only shows in `C_LootHistory` state
  (`NeedMainSpec 0`, `NeedOffSpec 1`, section 5) and in chat strings like `LOOT_ROLL_WON_NO_SPAM_NEED_OFF_SPEC`.
  Forever's `LOOT_ROLL_NEED_SELF_OFF_SPEC` text is the same as plain Need ("You have selected Need for: %s",
  `KF gs`). **MEASURED**.
- So what does Forever actually offer? The UI can show Need, Greed, Transmog and Pass. Disenchant has no button in this
  frame on either client. Whether the Forever server ever sets `canTransmog` is unknown. The owner sees Need/Greed.
  **INFERRED**: expect Need / Greed / Pass in practice, but code must accept 3 and 4. Probe below.
- Forever GlobalStrings add `LOOT_ROLL_ROLLED_TRANSMOG` ("Transmog Roll - %d for %s by %s") which live does not have
  (`KF gs:13927`, absent in `KL gs`). **MEASURED**. This hints that Transmog rolls are wired on Forever. **INFERRED**.

### 2.3 Which roll frame Forever uses

- There is no `Blizzard_GroupLoot` or Camelot copy. Forever loads the Mainline frame:
  `WF/Blizzard_UIPanels_Game/Blizzard_UIPanels_Game.toc:129-130` →
  `[Family]\GroupLootFrame.lua [AllowLoadGameType mainline]` and `.xml`. Camelot is in the mainline family; the same
  TOC uses `[AllowLoadGameType mainline] [ExcludeLoadGameType camelot]` at lines 44, 46, 52 to *remove* Camelot from
  that family for other files. **MEASURED**.
- Frames: `GroupLootContainer` (`GroupLootFrame.xml:632`), `GroupLootFrame1..4` (`NUM_GROUP_LOOT_FRAMES = 4`,
  `GroupLootFrame.lua:1`), and on gamepad `GamepadGroupLootRollFrame`. **MEASURED**.
- `START_LOOT_ROLL` is routed by `Blizzard_Game`. Forever loads `[Family]\EventRouting.lua` =
  Mainline (`WF/Blizzard_Game/Blizzard_Game.toc:11-12`). Mainline routing maps
  `START_LOOT_ROLL → GameEvent.HandleStartLootRoll` (`WF/Blizzard_Game/Mainline/EventRouting.lua:103`), which calls
  `GroupLootContainer_AddRoll(rollID, rollTime)` unless the gamepad UI is on
  (`WF/Blizzard_Game/Mainline/EventImplementation.lua:385-391`). Live is the same
  (`WL/Blizzard_Game/Mainline/EventRouting.lua:103`, `EventImplementation.lua:386`). **MEASURED**.
- `CONFIRM_LOOT_ROLL` is routed in `Shared/EventRouting.lua:79` on Forever and shows `StaticPopup "CONFIRM_LOOT_ROLL"`
  (`WF/Blizzard_StaticPopup_Game/GameDialogDefs.lua:71-85`). **MEASURED**.
- The Forever `GroupLootFrame.lua` differs from live only by gamepad support (diff shows only added gamepad code and a
  `GroupLootContainer_Update` gamepad early-out). **MEASURED**.
- For the popup annotation feature: hook `GroupLootFrame_OnShow` / `GroupLootFrame_SetupItemDisplay`
  (`GroupLootFrame.lua:312, 371`), or the frames `GroupLootFrame1..4` with their `.rollID`. Same names on both clients.
  **MEASURED** for the names; hook safety is **INFERRED** (these are insecure Lua frames, so `hooksecurefunc` should
  not taint roll buttons, but `RollOnLoot` is not protected anyway).

---

## 3. Master loot

### 3.1 The master looter's side (same UI on both clients)

- `OPEN_MASTER_LOOT_LIST` opens a context menu (Assign Loot / Request Roll) on the selected loot slot.
  `WF/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:196-309`. **MEASURED**.
- `MasterLooterFrame` lists candidates via `GetMasterLootCandidate(slot, i)` for `i = 1..MAX_RAID_MEMBERS` and gives
  with `GiveMasterLoot(slot, candidateId)`. `UPDATE_MASTER_LOOT_LIST` refreshes it.
  `GroupLootFrame.lua:843-1031`. **MEASURED**.
- Quality confirm: `if LootFrame.selectedQuality >= Constants.LootConsts.MasterLootQualityThreshold` show
  `CONFIRM_LOOT_DISTRIBUTION`. `GroupLootFrame.lua:988`. **MEASURED**.
- Forever documents only `LootConsts_Camelot.MasterLootQualityThreshold = 4`
  (`LootConstants_MainlineDocumentation.lua:38-45`). It does **not** document `LootConsts`. Live documents
  `LootConsts.MasterLootQualityThreshold = 5` (`WL/.../LootConstantsDocumentation.lua:47-54`). **MEASURED**.
  Whether `Constants.LootConsts` exists at runtime on Forever (so line 988 does not error) is **unknown**. Probe.
  For DropWatcher: read `Constants.LootConsts_Camelot` first, then `Constants.LootConsts`, then fall back to 4.

### 3.2 What a raider (not the master looter) can see

- Who is the ML: `C_PartyInfo.GetLootMethod()` returns `masterLootPartyID` (party) or `masterLooterRaidID` (raid).
  **MEASURED** (doc). `GetRaidRosterInfo(i)` 11th return is the ML flag (Gargul uses it,
  `PA/Gargul/Utils/Shims.lua:205-211`). **REPORTED** (prior art). Map the ID to a unit with `"party"..id` /
  `"raid"..id`; `0` is likely "player". **INFERRED**.
- `IsMasterLooter()` tells if *you* are the ML. **MEASURED** (Ketho fn).
- Can a raider open the corpse and see the Epic? Classic rule: only the ML can take items at or above the threshold.
  Items below the threshold are handled like round robin. **REPORTED**: https://warcraft.wiki.gg/wiki/Loot
  ("Items below this threshold are handled in a round-robin way"), https://warcraft.wiki.gg/wiki/Master_looter
  ("Any loot on a dead mob can only be looted by the player who was Master Looter at the time that mob was killed.").
  Whether a raider on Forever can open the window and read the Epic's link (`LOOT_READY` / `LOOT_OPENED`,
  `GetLootSlotLink`, `GetLootSlotInfo ... locked`) is **unknown**. Probe below.
- `LootFrame` greys a slot when `GetLootSlotInfo` returns `locked`
  (`WF/Blizzard_UIPanels_Game/Mainline/LootFrame.lua:477, 507-513`). **MEASURED**. So a non-ML who *can* open the
  corpse would likely see the Epic as a locked slot with a link. **INFERRED**.
- `ERR_LOOT_ROLL_PENDING` ("That item is still being rolled for.") and `ERR_LOOT_MASTER_*` strings exist on Forever
  (`KF gs`). **MEASURED**.

### 3.3 How DropWatcher can learn that an Epic awaits assignment

No event tells a bystander "an Epic is waiting". Options, best first. All **INFERRED**:

1. `LOOT_READY` / `LOOT_OPENED` on the raider's own client when they open the corpse. Scan
   `GetLootSlotLink` / `GetLootSlotInfo` for `quality >= threshold` and `locked`. Needs the raider to click the corpse.
2. `ENCOUNTER_END` plus `ENCOUNTER_LOOT_RECEIVED` fire only when someone *gets* the item. Under ML that is after
   assignment, so it gives the final owner, not the pending state.
3. Chat `LOOT_ITEM` ("%s receives loot: %s.") when the ML gives it. Final, not pending.
4. Addon comms from the ML (RCLC/Gargul style). Only works if the ML runs an addon.
5. `C_LootHistory` almost certainly does not populate under ML. Blizzard's own tutorial check skips ML:
   `C_PartyInfo.GetLootMethod() ~= Enum.LootMethod.Masterlooter`
   (`WF/Blizzard_FrameXML/Mainline/LootHistory.lua:552`). **MEASURED** for the check; populating is **INFERRED**.

So "awaiting master looter" is best driven from the raider's own loot window (1), closed by a `LOOT_ITEM` line naming
the winner (3). For the whisper target, use the ML unit from `GetLootMethod()`.

---

## 4. Free for all and round robin: what a bystander gets

- No roll events fire. Nothing goes into `C_LootHistory`. **INFERRED** (rolls only exist under group loot).
- A bystander sees only the chat line when someone loots: `LOOT_ITEM` "%s receives loot: %s." and
  `LOOT_ITEM_MULTIPLE` (`KF gs:13858` and neighbours). Same text on live. **MEASURED** (strings).
- `ENCOUNTER_LOOT_RECEIVED(encounterID, itemID, itemLink, quantity, itemName, fileName)` exists on both
  (`LootDocumentation.lua:130-143`). In practice the last two are the looter's name and class (DropWatcher already
  reads them that way, `modules/LootFeed.lua:1009`). Fires only for boss drops. **MEASURED** (doc) / **INFERRED**
  (FFA behaviour).
- `LOOT_ITEM_WHILE_PLAYER_INELIGIBLE` exists on Forever (`KF gs`). **MEASURED**.

---

## 5. C_LootHistory and the loot history frame

- `C_LootHistory` exists on Forever with `GetAllEncounterInfos`, `GetInfoForEncounter`, `GetLootHistoryTime`,
  `GetSortedDropsForEncounter`, `GetSortedInfoForDrop`, and events `LOOT_HISTORY_CLEAR_HISTORY`,
  `LOOT_HISTORY_GO_TO_ENCOUNTER`, `LOOT_HISTORY_ONE_HUNDRED_ROLL`, `LOOT_HISTORY_UPDATE_DROP`,
  `LOOT_HISTORY_UPDATE_ENCOUNTER`. `WF/Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua:3-124`.
  **MEASURED**.
- The only doc difference from live: the second argument is named `lootListKey` on Forever and `lootListID` on live
  (lines 66, 102, 113, 151). Same type (number). **MEASURED**. Name only; positional code is not affected.
- `EncounterLootDropRollState`: NeedMainSpec 0, NeedOffSpec 1, Transmog 2, Greed 3, NoRoll 4, Pass 5 (`:131-143`).
  `EncounterLootDropInfo` has `itemHyperlink, playerRollState, currentLeader?, isTied, winner?, allPassed, rollInfos,
  startTime, duration` (`:147-160`). `EncounterLootDropRollInfo` has `playerName, playerGUID, playerClass, isSelf,
  state, isWinner, roll?` (`:164-174`). **MEASURED**. This gives everyone's choice live, and the roll number once known.
- `GetInfoForEncounter`, `GetSortedDropsForEncounter`, `GetSortedInfoForDrop` are
  `SecretArguments = "AllowedWhenUntainted"` (`:22, 46, 61`). **MEASURED**. Return fields are not marked
  `NeverSecret`, so names may be secret inside restricted content on Retail. XLoot guards
  `issecret(leader.playerName)` (`PA/XLoot/Modules/Group/Group.lua:703`). **REPORTED** (prior art).
- The frame: `GroupLootHistoryFrame` (`WF/Blizzard_FrameXML/Mainline/LootHistory.xml:193`). Forever TOC loads
  `[Family]\LootHistory.lua`, then `[Game]\LootHistory.lua [AllowLoadGameType camelot]`, then the XML
  (`WF/Blizzard_FrameXML/Blizzard_FrameXML.toc:125-127`). The Camelot override is only:
  `function LootHistoryFrameMixin:ShouldAutoOpen() return false; end`
  (`WF/Blizzard_FrameXML/Camelot/LootHistory.lua:2-4`). **MEASURED**. `/loot` and `/lootrolls` still toggle it
  (`WF/Blizzard_ChatFrameBase/Shared/SlashCommands.lua:1480-1482`; `KF gs:19922-19925`).
- Info text differs: Forever "Loot rolls from group content are displayed here" vs live "Loot rolls from dungeons and
  raids are displayed here" (`KF gs:13851`, `KL gs:13362`). **MEASURED**. This hints that Forever keeps history for
  group rolls outside instances too (open world elites, trash). **INFERRED**.
- When it populates: only for group-loot rolls (the data is roll state). Not for FFA, round robin or ML
  (see 3.3 item 5). **INFERRED**.
- What `encounterID` is for a trash or open-world roll on Forever is **unknown**. Probe.
- XLoot ships "see who rolled and who won" on Retail and Forever using exactly
  `LOOT_HISTORY_UPDATE_DROP` + `GetSortedInfoForDrop`, and binds a drop to a roll frame by item ID, oldest first
  (`PA/XLoot/Modules/Group/Group.lua:609-630, 688-741`; whatsnew `PA/XLoot/whatsnew.lua:28`). **REPORTED** (prior art,
  shipping). XLoot treats Forever as the retail engine: `IS_RETAIL_ENGINE = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or
  WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` (`PA/XLoot/XLoot.lua:27-28`).
- DropWatcher already listens to `LOOT_HISTORY_UPDATE_DROP` and reads `C_LootHistory.GetSortedInfoForDrop`, but only
  takes a drop once it has a winner (`modules/LootFeed.lua:1018, 1044`; `core/Compat.lua:419-429`). **MEASURED**.

---

## 6. Chat: CHAT_MSG_LOOT roll lines

### 6.1 Payload and secrets

- `CHAT_MSG_LOOT` payload: `text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID,
  channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox,
  suppressRaidIcons, discordInfo`. Only `languageName`, `channelName`, `specialFlags`, `zoneChannelID`,
  `channelIndex`, `channelBaseName`, `languageID`, `lineID`, `isMobile`, `isSubtitle`, `hideSenderInLetterbox`,
  `suppressRaidIcons` are `NeverSecret`. So `text`, `playerName`, `playerName2`, `guid` can be secret.
  `WF/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua:1814-1838`. **MEASURED**.
- Whether Forever actually makes chat secret in its dungeons and raids (as Retail 12.x does in restricted content) is
  **unknown**. DropWatcher already has `issecretvalue` guards (`core/Compat.lua:24`). Keep them on both clients.

### 6.2 String differences (enUS), Ketho forever vs live

Diff of all loot/roll/bind strings (`.../scratchpad/ketho/strs_{live,forever}.txt`, 114 vs 115 keys). **MEASURED**:

| Key | Retail 12.1.5 (`KL gs`) | Forever 1.60.1 (`KF gs`) |
|---|---|---|
| `LOOT_ROLL_NEED` | `%s has selected Need for: %s` (:13426) | `\|HlootHistory:%d\|h[Loot]\|h: %s has selected Need for: %s` (:13915) |
| `LOOT_ROLL_GREED` | `%s has selected Greed for: %s` (:13416) | `\|HlootHistory:%d\|h[Loot]\|h: %s has selected Greed for: %s` (:13905) |
| `LOOT_ROLL_PASSED` | `%s passed on: %s` (:13429) | `\|HlootHistory:%d\|h[Loot]\|h: %s passed on: %s` (:13918) |
| `LOOT_ROLL_ROLLED_NEED` | `Need Roll - %d for %s by %s` (:13436) | `\|HlootHistory:%d\|h[Loot]\|h: Need Roll - %d for %s by %s` (:13925) |
| `LOOT_ROLL_ROLLED_GREED` | `Greed Roll - %d for %s by %s` (:13435) | prefixed the same way (:13924) |
| `LOOT_ROLL_ROLLED_TRANSMOG` | absent | `\|HlootHistory:%d\|h[Loot]\|h: Transmog Roll - %d for %s by %s` (:13927) |
| `LOOT_ROLL_WON` | `%s won: %s` (:13439) | `\|HlootHistory:%d\|h[Loot]\|h: %s won: %s` (:13929) |
| `LOOT_ROLL_YOU_WON` | `You won: %s` | `\|HlootHistory:%d\|h[Loot]\|h: You won: %s` |
| `LOOT_ROLL_*_SELF` | prefix **and** a trailing `\|HlootHistory:%d\|h...[View Loot Rolls]\|h` link | prefix only, no trailing link |
| `LOOT_ROLL_ALL_PASSED` | `\|HlootHistory:%d\|h[Loot]\|h: Everyone passed on: %s` (:13413) | same (:13902) |
| `LOOT_ROLL_STARTED` | `\|HlootHistory:%d\|h[Loot]\|h: %s` (:13438) | same (:13928) |
| `LOOT_ROLL_WON_NO_SPAM_*` | prefixed | same |
| `LOOT_ROLL_DISENCHANT`, `LOOT_ROLL_ROLLED_DE`, `LOOT_ROLL_PASSED_AUTO`, `LOOT_ROLL_ROLLED_NEED_ROLE_BONUS` | no prefix | no prefix (same) |
| `LOOT_ITEM` | `%s receives loot: %s.` (:13369) | same (:13858) |
| `LOOT_HISTORY_INFO_TEXT` | "...from dungeons and raids..." | "...from group content..." |
| `LOOT_MASTER_LOOTER` | `Loot: Guild Master Loot` | `Loot: Master Loot` |
| `ITEM_BIND_TO_ACCOUNT` etc. | "Warband" | "Account" |

What this means. **INFERRED** from the table:

- A pattern built with the usual "replace `%s`/`%d` with captures" trick from the *client's own* GlobalString still
  works on both clients, because the extra `%d` (encounter ID) just becomes one more capture. But the capture order
  shifts by one on Forever for the other-player lines. Build patterns from the live GlobalString at runtime and read
  captures by position *per string*, not by a fixed table.
- The `|HlootHistory:%d|h` link is the encounter ID (the link handler does `SetLootHistoryFrameToEncounter(encounterID)`,
  `WF/Blizzard_UIPanels_Game/Mainline/ItemRefHandlers.lua:99-102`; link type `LootHistory = "lootHistory"`,
  `WF/Blizzard_SharedXML/LinkUtil.lua:36`). **MEASURED**. On Forever, every roll line names its encounter, so chat can
  be joined to `C_LootHistory` exactly. On Retail, only self lines carry it.
- Chat is a fallback only. `C_LootHistory` is cleaner and has no locale parsing.

---

## 7. Binding and trading

- BoP is soulbound on loot on Forever, no 2h trade window. **OWNER** (measured in game).
- The GlobalString `BIND_TRADE_TIME_REMAINING` ("You may trade this item with players that were also eligible to
  loot this item for the next %s...") exists on Forever (`KF gs:2303`) and live (`KL gs:2262`). **MEASURED**. So
  string presence proves nothing. **INFERRED**: on Forever, never offer "ask for trade" for a BoP item, even if the
  tooltip line seems present.
- `C_Item.IsBound`, `C_Item.EndBoundTradeable`, `C_Item.MerchantConfirmTradeTimerRemoval`,
  `C_Item.IsItemBindToAccount*` are documented on Forever (`WF/Blizzard_APIDocumentationGenerated/ItemDocumentation.lua:
  231, 1186, 1399, 1414, 1866`). **MEASURED**. The API exists; the trade window does not (OWNER).
- `Enum.ItemBind`: None 0, OnAcquire 1, OnEquip 2, OnUse 3, Quest 4, ..., ToWoWAccount 7, ToBnetAccount 8
  (`WF/.../ItemConstantsDocumentation.lua:249-264`). Use `bindType` from `C_Item.GetItemInfo` (14th return) to tell
  BoP (1) from BoE (2) before the item is in a bag. **MEASURED** (enum) / **INFERRED** (use).
- `GetLootRollItemInfo` returns `bindOnPickUp` (`GroupLootFrame.lua:317`). That is a direct BoP flag for a roll.
  **MEASURED**.
- `LOOT_BIND_CONFIRM(lootSlot)` shows `StaticPopup "LOOT_BIND"` on Forever
  (`WF/Blizzard_Game/Mainline/EventRouting.lua:60`, `EventImplementation.lua:283-291`). **MEASURED**.
- Social rules. GDKP (gold auctions of loot) is banned on Forever NA/EU. **REPORTED**:
  https://www.gamesradar.com/games/world-of-warcraft/wow-forever-doesnt-allow-gdkp-blizzard-says-the-new-mmos-economy-is-something-were-taking-very-seriously/,
  https://www.invenglobal.com/articles/27234/world-of-warcraft-forever-to-allow-gdkp-in-korea (Korea differs).
  This does not change DropWatcher's polite ask/offer flow.

---

## 8. Web and ecosystem

- No Blizzard blue post explains Forever loot methods or defaults. **REPORTED** (searches above, and the Guild Order
  page saying so).
- Forever hides item stats until an item has dropped on your realm. No dungeon journal item lists. **REPORTED**:
  https://www.icy-veins.com/wow-forever/news/blizzard-wants-to-keep-loot-a-surprise-in-wow-forever/,
  https://www.warcrafttavern.com/forever/news/item-stats-will-not-be-known-in-advance-for-wow-forever/.
  **INFERRED** impact: tooltip/stat data for a fresh drop may be missing or slow, so Pawn-style scoring can fail on
  first sight; DropWatcher must handle "unknown" verdicts and retry on `GET_ITEM_INFO_RECEIVED`.
- XLoot supports Forever group rolls and roll results (section 5). Its classic master loot module is kept off retail
  engines; the retail one handles `OPEN_MASTER_LOOT_LIST` (`PA/XLoot/Modules/Master/Retail.lua:51-61, 103-105`).
  **REPORTED** (prior art).
- Gargul ships `## Interface-Camelot: 16001` (`PA/Gargul/Gargul.toc:3`) and a master-loot shim that works with or
  without the legacy global (`PA/Gargul/Utils/Shims.lua:175-212`). **REPORTED** (prior art).
- Forever-only loot addons exist: WLC (loot council "built for Forever"), SimpleLootCouncil ("master loot is back on
  WoW Forever"), ForeverLootMover. **REPORTED**: https://www.curseforge.com/wow/addons/w-l-c,
  https://wowinterface.com/downloads/info27244-SimpleLootCouncil.html,
  https://www.curseforge.com/wow/addons/foreverlootmover. These confirm that master loot is live on Forever.
- pcgames.de articles on Forever loot returned 403 and were not read.

---

## 9. Design notes for DropWatcher (all INFERRED)

- One code path for both clients: treat Forever as the retail engine for loot. Branch only on data
  (threshold constant, BoP trade window, chat patterns), not on frame names.
- Everyone's rolls: drive from `START_LOOT_ROLL` (rollID, link via `GetLootRollItemLink`) plus
  `LOOT_HISTORY_UPDATE_DROP` → `GetSortedInfoForDrop` (live state per player, then winner). Bind drop to roll by item
  ID, oldest first, like XLoot. Close on `winner` or `allPassed`. Use `CANCEL_LOOT_ROLL` to close the popup side only.
- Map roll states: 0/1 Need (main/off), 2 Transmog, 3 Greed, 4 waiting, 5 Pass.
- Master loot pending: detect `GetLootMethod() == Masterlooter`, threshold from `LootConsts_Camelot` then
  `LootConsts`, look for locked slots `>= threshold` on `LOOT_READY`, show "awaiting master looter", whisper the ML
  unit from `masterLootPartyID` / `masterLooterRaidID`. Resolve on `LOOT_ITEM` / `ENCOUNTER_LOOT_RECEIVED`.
- Guard every name/text read with `issecretvalue` on both clients.

---

## 10. Open probes (in game)

Run each in a group on Forever, and the matching ones on Retail where noted.

1. `/dump C_PartyInfo.GetAvailableLootMethods()` in a party, a raid, and a dungeon. Look for which of 0-5 appear.
   Personal (5) should be absent on Forever.
2. `/dump C_PartyInfo.GetLootMethodStyle()` on Forever and Retail. Look for 0 (Mainline) or 1 (Vanilla).
3. `/dump C_PartyInfo.GetLootMethod()` right after joining a fresh party, entering a dungeon, entering a raid. This gives
   the default per content. Under ML also note the 2nd/3rd returns and compare with `/dump GetRaidRosterInfo(1)`
   (11th return).
4. `/dump Constants.LootConsts, Constants.LootConsts_Camelot` on Forever. Look for which table exists and the
   threshold. If `LootConsts` is nil, Blizzard's own `GroupLootFrame.lua:988` would error on assign; note it.
5. During an open roll: `/run for _,id in ipairs(GetActiveLootRollIDs()) do print(id, GetLootRollItemLink(id), select(5, GetLootRollItemInfo(id)), select(6, GetLootRollItemInfo(id)), select(7, GetLootRollItemInfo(id)), select(8, GetLootRollItemInfo(id)), select(13, GetLootRollItemInfo(id))) end`.
   Look for bindOnPickUp, canNeed, canGreed, canDisenchant, canTransmog. Is canTransmog ever true on Forever?
6. While a roll is open and after it ends: `/run for _,e in ipairs(C_LootHistory.GetAllEncounterInfos()) do print(e.encounterID, e.encounterName) for _,d in ipairs(C_LootHistory.GetSortedDropsForEncounter(e.encounterID) or {}) do print(" ", d.lootListKey or d.lootListID, d.itemHyperlink, d.playerRollState, d.winner and d.winner.playerName, #d.rollInfos) end end`.
   Do this for a boss, a trash mob and an open-world elite. Look for what encounterID trash and world drops get.
7. `/etrace` with filters `START_LOOT_ROLL LOOT_HISTORY_UPDATE_DROP LOOT_ROLLS_COMPLETE CANCEL_LOOT_ROLL MAIN_SPEC_NEED_ROLL CHAT_MSG_LOOT`
   during one roll. Look for the order, and whether `LOOT_HISTORY_UPDATE_DROP` fires per player choice or only at the end.
8. Raw chat text: `/run local f=CreateFrame("Frame") f:RegisterEvent("CHAT_MSG_LOOT") f:SetScript("OnEvent",function(_,_,t) print(issecretvalue and issecretvalue(t), (t:gsub("|","||"))) end)`.
   Run in the open world and inside a dungeon/raid boss fight, on both clients. Look for the `|HlootHistory:` prefix on
   other players' lines (Forever) and whether `text` is secret.
9. Under master loot, as a non-ML raider: click the boss corpse. `/run print(GetNumLootItems()) for i=1,GetNumLootItems() do print(i, GetLootSlotLink(i), select(5, GetLootSlotInfo(i)), select(6, GetLootSlotInfo(i))) end`.
   Look for: does the loot window open at all, is the Epic listed, is its link readable, is `locked` true.
   Also `/etrace LOOT_READY LOOT_OPENED OPEN_MASTER_LOOT_LIST UPDATE_MASTER_LOOT_LIST` to see what a non-ML gets.
10. Under master loot: does `LOOT_HISTORY_UPDATE_DROP` ever fire? Watch `/etrace LOOT_HISTORY_UPDATE_DROP` across one
    boss and one assignment.
11. Under free for all: `/etrace ENCOUNTER_LOOT_RECEIVED CHAT_MSG_LOOT` as a bystander when someone else loots a boss.
    Look for both events and their payloads.
12. BoP check: hover a just-looted BoP item, `/dump C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(b,s))`, and scan
    the tooltip for `BIND_TRADE_TIME_REMAINING` text. Expect bound and no trade line on Forever; on Retail expect the line
    under group loot.

---

## Skeptic corrections

A second researcher re-checked the 17 load-bearing claims on 2026-11-13. The checks used the same `WF/` (1.60.1 70888,
commit 4cd0ab7) and `WL/` (12.1.5 70783, commit 297d7aa) clones. Fresh downloads of Ketho `GlobalAPI.lua`,
`Events.lua`, `GlobalStrings/enUS.lua` and `LuaEnum.lua` (branches `forever` and `live`) are byte-identical to the
`KF/`/`KL/` copies and to `.../scratchpad/luaenum/`. Thirteen claims hold as written. The corrections below matter
for the code.

### C1. Master loot threshold: Forever's runtime key is `Constants.LootConsts`, not `LootConsts_Camelot` (claim 6, §3.1, probe 4)

- The Forever docs name the table `LootConsts_Camelot` (`WF/.../LootConstants_MainlineDocumentation.lua:38-45`).
  **MEASURED**.
- Ketho's Forever `LuaEnum.lua` dump has `Constants.LootConsts = { MasterLootQualityThreshold = 4 }`
  (`.../scratchpad/luaenum/forever.lua:9783-9785`, the same as
  `https://raw.githubusercontent.com/Ketho/BlizzardInterfaceResources/forever/Resources/LuaEnum.lua`). The dump has no
  `LootConsts_Camelot` key. Live has `LootConsts = { MasterLootQualityThreshold = 5 }` (`luaenum/live.lua:9378-9380`).
  **MEASURED** in the dump. That the dump reflects the client at runtime is **REPORTED** (Ketho dumps the table in
  game). The doc name differs, so this cannot come from the docs.
- So Blizzard's `GroupLootFrame.lua:988` (`Constants.LootConsts.MasterLootQualityThreshold`) should work on Forever and
  read 4. **INFERRED**.
- For DropWatcher: read `Constants.LootConsts.MasterLootQualityThreshold` first, then `Constants.LootConsts_Camelot`,
  then fall back to 4 on Forever or 5 on Retail. Probe 4 can confirm this in one `/dump`.

### C2. `lootListKey` vs `lootListID` is also a struct field name, so code that reads the field breaks (claim 8, §5)

- The note says the change is in the argument name only and "positional code is not affected". Line 151 of the doc
  is the `EncounterLootDropInfo` **struct field**, not an argument (`WF/.../LootHistoryDocumentation.lua:147-151`).
  **MEASURED**.
- Blizzard's own Forever code reads the field as `dropInfo.lootListKey` and `elementData.lootListKey`
  (`WF/Blizzard_FrameXML/Mainline/LootHistory.lua:545, 405, 409`). Live reads `elementData.lootListID`
  (`WL/Blizzard_FrameXML/Mainline/LootHistory.lua:381, 385`). **MEASURED**.
- Impact: event arguments (`LOOT_HISTORY_UPDATE_DROP(encounterID, id)`) are positional and safe. DropWatcher's
  `LF.OnLootHistoryDrop` uses only those today (`modules/LootFeed.lua:1019`). Any new code that walks
  `C_LootHistory.GetSortedDropsForEncounter()` and reads the ID off each drop must use
  `drop.lootListKey or drop.lootListID`. Probe 6 already does this. **INFERRED**.

### C3. The master-loot tutorial check does not show that history stays empty under ML (claim 9, §3.3 item 5, §5)

- The check is real: `C_PartyInfo.GetLootMethod() ~= Enum.LootMethod.Masterlooter`
  (`WF/.../LootHistory.lua:552`; live `:528`). **MEASURED**.
- But it only runs when `anyRolledOn` is true, which means the player already has a rolled-on drop in the history
  (`WF/.../LootHistory.lua:527-543, 552`). Blizzard guards against "roll data present while the method is ML". That
  points to history being able to hold rolls under ML (for example after a method change, or rolls under the
  threshold), not to it never filling. **INFERRED**.
- Correction: drop "almost certainly does not populate". Say instead: "unknown; the tutorial check points slightly
  the other way". Leave it as open probe 10. The design must not assume either case.

### C4. Chat prefix: two exceptions to "all start with" (claim 10, §0 item 5)

- On Forever, other players' `LOOT_ROLL_DISENCHANT`, `LOOT_ROLL_ROLLED_DE`, `LOOT_ROLL_PASSED_AUTO(_FEMALE)` and
  `LOOT_ROLL_ROLLED_NEED_ROLE_BONUS` have **no** prefix (`KF gs:13903, 13923, 13919-13920, 13926`). So "`_ROLLED_*` all
  start with the link" in §0 is wrong for `_ROLLED_DE` and `_ROLE_BONUS`. **MEASURED**. The §6.2 table is right.
- On Retail some lines about other players **do** have the prefix: `LOOT_ROLL_ALL_PASSED`, `LOOT_ROLL_STARTED` and
  `LOOT_ROLL_WON_NO_SPAM_*` (`KL gs:13413, 13438, 13440-13444`). So "on Retail they do not" holds only for the
  choice/roll/won lines. **MEASURED**.
- Retail self lines carry **two** `%d` (prefix plus a trailing `[View Loot Rolls]` link); Forever self lines carry one
  (`KL gs:13417, 13427`; `KF gs:13906, 13916`). Self-line capture counts differ by client too. **MEASURED**.
- Retail `LOOT_ROLL_NEED_SELF_OFF_SPEC` says "Need (Off-Spec)". Forever's says plain "Need". The two Forever Need-self
  strings are identical, so a pattern table keyed by text would collide on Forever (`KF gs:13916-13917`). **MEASURED**.

### C5. Forever skips the roll popup when the gamepad UI is on (claim 2, §2.3)

- Routing is as claimed. But Forever's `GameEvent.HandleStartLootRoll` returns early if
  `InputUtil.IsGamepadUIEnabled()` and never calls `GroupLootContainer_AddRoll`
  (`WF/Blizzard_Game/Mainline/EventImplementation.lua:385-391`). Live has no such check
  (`WL/.../EventImplementation.lua:385-387`). **MEASURED**.
- For the popup-annotation feature on Forever with gamepad UI on, `GroupLootFrame1..4` do not show. Annotate
  `GamepadGroupLootRollFrame` too, or skip annotation then. **INFERRED**.
- `Blizzard_Game` also has a Camelot layer (`WF/Blizzard_Game/Blizzard_Game.toc:16-19`). Its `GameEvent.InitEvents`
  registers shared, then Mainline, then 12 Camelot handlers. None is a loot event
  (`WF/Blizzard_Game/Camelot/EventRouting.lua:3-26`). So the "Mainline routing" claim holds. **MEASURED**.

### C6. Minor citation and wording fixes

- Claim 1: the "only loot override" holds. One more Camelot file touches loot UI: `Blizzard_UnitPopup/Camelot/
  UnitPopupMenus.lua` (loaded at `Blizzard_UnitPopup.toc:15`). Its self-menu loot entries match Mainline
  (`Camelot/UnitPopupMenus.lua:8-12` vs `Mainline/UnitPopupMenus.lua:8-12`). Not a behavior change. **MEASURED**.
- Claim 3: "the same set" is true for roll and master-loot APIs. Forever adds `C_AutoLoot.SetUseAutoLootToggle`,
  `C_LootFrame.TryAutoLoot` and `UnitHasLootInteraction` (`§1.1` already says so). The event lists have no loot or
  roll difference at all. **MEASURED** (fresh Ketho diff).
- Claim 5: `UnitPopupButtons.lua:805-809` is the **loot threshold** button's `CanShow` (it hides the threshold under
  Personal). It is not a method entry. A per-method check looks like `:694-697` (Free for all). **MEASURED**.
- Claim 12: `bnSenderID` and `discordInfo` also lack `NeverSecret`
  (`WF/.../ChatInfoDocumentation.lua:1832, 1837`). **MEASURED**. None of these matter to DropWatcher.
- Claim 17: the Guild Order page says "have not been described in Blizzard's articles", not "not published".
  Invenglobal confirms the GDKP ban is NA/EU only. Warcraft Tavern confirms stats stay hidden "until it drops for someone
  on your server". The icy-veins article returned 403 for me. Icy Veins also confirms CN-only master loot in 12.0.5
  (https://www.icy-veins.com/wow/news/master-loot-makes-a-comeback-in-wow-12-0-5-but-only-for-cn-servers/).
  **REPORTED**.
