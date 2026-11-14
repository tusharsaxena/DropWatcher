# 05 — Prior art: roll display, roll-frame annotation, master loot

Date: 2026-11-13. Scope: how shipping addons show everyone's loot rolls, mark Blizzard's roll popup, and
handle master loot, on Retail 12.1.5 and on WoW Forever 1.60.1. Read-only research. Nothing in the repo
changed except this note.

Tags: **MEASURED** = seen in source or API docs. **REPORTED** = third-party changelog, comment or web.
**INFERRED** = my reading, not proven.

Paths used below:

- `FV/` = `/mnt/g/Games/Blizzard/World of Warcraft/_forever_/Interface/AddOns/` (installed, Forever)
- `RT/` = `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/` (installed, Retail)
- `WUS-F/` = Gethe/wow-ui-source branch `forever`, 1.60.1 (70888), scratch clone
- `WUS-L/` = Gethe/wow-ui-source branch `live`, 12.1.5 (70783), scratch clone
- `KETHO-F/` = Ketho/BlizzardInterfaceResources branch `forever` (Events.lua, GlobalStrings enUS)
- `XL/` = github.com/Xuerian/XLoot @ 0c336bc (2026-11-09)
- `GG/` = github.com/papa-smurf/Gargul @ e3b8d0f (2026-11-01)
- `RC/` = github.com/evil-morfar/RCLootCouncil2 @ e078396 (2026-11-06)

---

## 1. Short answer

1. **Everyone's rolls come from `C_LootHistory`, on both clients.** Forever ships the modern
   encounter-based API (`GetAllEncounterInfos`, `GetSortedDropsForEncounter`, `GetSortedInfoForDrop`,
   `LOOT_HISTORY_UPDATE_DROP`). Its drop info carries `rollInfos[]` with every player's name, GUID, class,
   state and roll number. MEASURED: `WUS-F/Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua:11-174`.
2. **One rename matters.** Retail calls the drop key `lootListID`. Forever calls it `lootListKey`, in the
   function argument, the event payload and the drop table field. MEASURED: Forever doc lines 66, 102, 113, 151;
   Retail `WUS-L/.../LootHistoryDocumentation.lua:66,102,113,151`. RPGLootFeed reads both:
   `dropInfo.lootListID or dropInfo.lootListKey` (`FV/RPGLootFeed/Features/LootRolls/LootRolls.lua:273-274`).
   The event and the function take the key positionally, so only the table field read needs the fallback.
3. **The old Classic API is gone on Forever.** `LOOT_HISTORY_ROLL_CHANGED` and `LOOT_HISTORY_ROLL_COMPLETE`
   are not in Forever's event list. MEASURED: absent from `KETHO-F/Events.lua` (present: `LOOT_ROLLS_COMPLETE`
   :1256, `OPEN_MASTER_LOOT_LIST` :1260, `LOOT_HISTORY_UPDATE_DROP` :1278, `PARTY_LOOT_METHOD_CHANGED` :1418).
   XLoot shipped a bug that registered `LOOT_HISTORY_ROLL_CHANGED` on Forever and errored on every login.
   REPORTED: `XL/CHANGELOG.md:130-134`.
4. **Nobody has a roll ID ↔ loot-history bridge.** `START_LOOT_ROLL` gives a `rollID`. Loot history gives
   `(encounterID, lootListID/Key)`. Both RPGLootFeed and XLoot join the two by **item ID**, picking an
   unclaimed drop. MEASURED: `FV/RPGLootFeed/.../LootRolls.lua:253-376`; `XL/Modules/Group/Group.lua:598-631`
   (comment at :607 "rollID and lootListID are unrelated ID spaces with no bridge").
5. **Annotating Blizzard's roll popup is done with non-secure hooks plus a child frame.** Pawn parents its own
   button to `GroupLootFrame1..4` in XML and uses `HookScript("OnShow")`. RPGLootFeed and GearQuestForever use
   `hooksecurefunc` on the open function. Pawn and GearQuestForever are installed and run on Forever.
   MEASURED: `FV/Pawn/Pawn.lua:373-380`, `FV/Pawn/PawnUI.xml:373-376`; `FV/RPGLootFeed/BlizzOverrides/LootRollFrames.lua:17-26`.
6. **Master loot detection is `C_PartyInfo.GetLootMethod() == Enum.LootMethod.Masterlooter`.** Every
   modern addon looked at does this. MEASURED: `XL/Modules/Master/Retail.lua:103-106`, `XL/helpers.lua:269-284`,
   `GG/Utils/Shims.lua:175-221`. No addon tracks a *pending* master-loot item for non-ML players. They only see
   the award later, as a `CHAT_MSG_LOOT` line. INFERRED from absence in all sources read.
7. **Forever names are "First Last".** `UnitName` returns the last name where the realm goes. Whisper targets
   need "First-Last". MEASURED/REPORTED: `GG/Utils/PlayerNames.lua:4-6`; `FV/RPGLootFeed/Features/PartyLoot/PartyLoot.lua:71-74`;
   `FV/RPGLootFeed/Features/ItemLoot/ItemLoot.lua:668-671`. This matters for keying rolls by name and for the
   "Ask the master looter" whisper.

---

## 2. Blizzard ground truth (both clients)

### 2.1 Roll lifecycle events

| Event | Payload | Source |
|---|---|---|
| `START_LOOT_ROLL` | `rollID, rollTime, lootHandle?` | MEASURED `WUS-F/.../LootDocumentation.lua:406-417` |
| `CANCEL_LOOT_ROLL` | `rollID` | MEASURED `WUS-F/.../LootDocumentation.lua:97-100` |
| `LOOT_ROLLS_COMPLETE` | `lootHandle` | MEASURED `WUS-F/.../LootDocumentation.lua:239-246` |
| `LOOT_ITEM_ROLL_WON` | `itemLink, rollQuantity, rollType, roll, upgraded` (no rollID) | MEASURED `WUS-F/.../LootDocumentation.lua:204-215` |
| `MAIN_SPEC_NEED_ROLL` | `rollID, roll, isWinning` | MEASURED `WUS-F/.../LootDocumentation.lua:270-279` |
| `LOOT_HISTORY_UPDATE_DROP` | `encounterID, lootListKey` | MEASURED `WUS-F/.../LootHistoryDocumentation.lua:106-114` |
| `LOOT_HISTORY_UPDATE_ENCOUNTER` | `encounterID` | MEASURED same file :117-124 |
| `LOOT_HISTORY_CLEAR_HISTORY` | none | MEASURED same file :79-82 |
| `OPEN_MASTER_LOOT_LIST` / `UPDATE_MASTER_LOOT_LIST` | none | MEASURED `WUS-F/.../LootDocumentation.lua:281-285,424-428` |

`LOOT_ITEM_ROLL_WON` has no rollID. RPGLootFeed notes this and marks only the first unresolved roll with
that item ID. MEASURED: `FV/RPGLootFeed/.../LootRolls.lua:448-462`.

### 2.2 Drop info shape (Forever)

`EncounterLootDropInfo`: `lootListKey, itemHyperlink, playerRollState, currentLeader?, isTied, winner?,
allPassed, rollInfos[], startTime, duration`. `EncounterLootDropRollInfo`: `playerName, playerGUID,
playerClass, isSelf, state, isWinner, roll?`. MEASURED: `WUS-F/.../LootHistoryDocumentation.lua:147-175`.

`Enum.EncounterLootDropRollState`: 0 NeedMainSpec, 1 NeedOffSpec, 2 Transmog, 3 Greed, 4 NoRoll, 5 Pass.
Same on both clients. There is **no Disenchant state**. MEASURED: Forever doc :131-144; Retail doc :138-143.
`roll` is nil until the roll number exists, so "live" = state chosen but `roll` nil; "final" = `winner` set or
`allPassed`. MEASURED (Nilable flags); semantics INFERRED, matching XLoot and RPGLootFeed below.

### 2.3 How Blizzard opens the roll popup

- `START_LOOT_ROLL` is routed by a **local, anonymous frame** in `Blizzard_Game`. Addons cannot reach it to
  unregister it. MEASURED: `WUS-F/Blizzard_Game/Shared/EventRouting.lua:1-17`; handler
  `WUS-F/Blizzard_Game/Mainline/EventRouting.lua:103` → `Mainline/EventImplementation.lua:385-391` →
  `GroupLootContainer_AddRoll(rollID, rollTime)`.
- Forever loads the Mainline family here. `[Family]` lines load for camelot, and only
  `EventImplementationUtils` is swapped. MEASURED: `WUS-F/Blizzard_Game/Blizzard_Game.toc:10-20`. INFERRED:
  `[Family]` resolves to Mainline on camelot, as the roll-frame file lives under `Mainline/`.
- `GroupLootContainer_OpenNewFrame(rollID, rollTime)` picks the first hidden `GroupLootFrame1..4`, sets
  `frame.rollID`, and shows it. MEASURED: `WUS-F/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:162-174`.
  Same name on Retail: `WUS-L/.../GroupLootFrame.lua:108`.
- `GroupLootFrame_OnShow` calls `GroupLootFrame_SetupItemDisplay`, which reads `GetLootRollItemInfo(self.rollID)`.
  MEASURED: Forever `GroupLootFrame.lua:312-381`.
- Only four frames exist. Extra rolls wait in `GroupLootContainer.waitingRolls`. MEASURED: :1, :156-160.
- A separate gamepad roll UI exists (`GamepadGroupLootRollFrameMixin`), and the MKB handler returns early when
  the gamepad UI is on. MEASURED: Forever `GroupLootFrame.lua:1040-1230`; `EventImplementation.lua:386-388`.
- The XLoot trick `UIParent:UnregisterEvent("START_LOOT_ROLL")` (`XL/Modules/Group/Group.lua:150`) does nothing
  on these clients, because UIParent does not own that event any more. INFERRED from
  `WUS-F/Blizzard_UIParent/UIParent.lua` (11 lines, no loot events). XLoot also hides the frames directly,
  which is what actually works for it (:110-133).

### 2.4 Blizzard's own loot history UI on Forever

- Forever runs the Mainline `GroupLootHistoryFrame` code with `lootListKey`. MEASURED:
  `WUS-F/Blizzard_FrameXML/Mainline/LootHistory.lua:17-24,201-206,405,546`.
- A Camelot override turns off auto-open. MEASURED: `WUS-F/Blizzard_FrameXML/Camelot/LootHistory.lua:2-4`,
  loaded by `Blizzard_FrameXML.toc:126` `[AllowLoadGameType camelot]`.
- The help tip is suppressed under master loot (`C_PartyInfo.GetLootMethod() ~= Enum.LootMethod.Masterlooter`).
  MEASURED: `LootHistory.lua:552`. INFERRED: master-loot drops may still land in loot history on Forever.
  Not proven. See open probes.
- The tooltip groups rolls by state, with `NoRoll` as "waiting". MEASURED: `LootHistory.lua:46-110,243-286`.

### 2.5 Master loot on Forever

- `Enum.LootMethod`: 0 Freeforall, 1 Roundrobin, 2 Masterlooter, 3 Group, 4 Needbeforegreed, 5 Personal.
  `Enum.LootMethodStyles`: 0 Mainline, 1 Vanilla. MEASURED: `WUS-F/.../LootConstantsDocumentation.lua:6-31`.
- `C_PartyInfo.GetLootMethod()` returns `method, masterLootPartyID?, masterLooterRaidID?`.
  `C_PartyInfo.GetLootMethodStyle()` returns the style. MEASURED: `WUS-F/.../PartyInfoDocumentation.lua:287-305`.
- `LootConsts_Camelot.MasterLootQualityThreshold = 4`. MEASURED: `WUS-F/.../LootConstants_MainlineDocumentation.lua:39-44`.
  Retail has `LootConsts.MasterLootQualityThreshold = 5`. MEASURED: `WUS-L/.../LootConstantsDocumentation.lua:48-52`.
- Forever's own UI reads `Constants.LootConsts.MasterLootQualityThreshold`, not the `_Camelot` name, for the
  "confirm distribution" popup. MEASURED: `WUS-F/Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:988`.
  Forever's docs do not list a plain `LootConsts`. So either the runtime has both, or this path is broken on
  Forever. INFERRED. Probe it.
- The ML menu is opened by `OPEN_MASTER_LOOT_LIST` through `EventRegistry:RegisterFrameEventAndCallback` on the
  roll frames. MEASURED: Forever `GroupLootFrame.lua:196-310`.

### 2.6 Chat strings that carry rolls

Forever GlobalStrings have the full roll line family, each with a `|HlootHistory:%d|h[Loot]|h` link:
`LOOT_ROLL_NEED`, `LOOT_ROLL_GREED`, `LOOT_ROLL_PASSED`, `LOOT_ROLL_ROLLED_NEED/GREED` ("Need Roll - %d for %s by
%s"), `LOOT_ROLL_WON`, `LOOT_ROLL_ALL_PASSED`, `LOOT_ROLL_WON_NO_SPAM_*`, `LOOT_ROLL_YOU_WON*`. MEASURED:
`KETHO-F` GlobalStrings enUS (scratch `forever_enUS.lua:13902-13940`). RPGLootFeed drops any `CHAT_MSG_LOOT`
line with `HlootHistory:` in its item-loot parser so roll lines are not counted as loot. MEASURED:
`FV/RPGLootFeed/Features/ItemLoot/ItemLoot.lua:659-664`. Nobody I read parses these lines for rolls. They
all use `C_LootHistory`.

---

## 3. Per-addon findings

### 3.1 RPGLootFeed v1.39.2 (installed on both; proven on Forever)

TOC: `## Interface: 11509, 16001, 20506, 50504, 120105` (`FV/RPGLootFeed/RPGLootFeed.toc:1`). MEASURED.

**Flavor detection.**
- `IsForever()` = `WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT`
  (`utils/AddonMethods.lua:82-84`). `IsRetail()` includes Forever (`:49-51`).
- The roll path does not branch on flavor. It branches on capability:
  `HasModernLootHistoryAPI()` = `C_LootHistory.GetAllEncounterInfos ~= nil` (`:59-61`). Forever takes the
  modern path. MEASURED.

**Data source for others' rolls.** `C_LootHistory` only. No chat parsing, no addon comms.
- Modern path: `LOOT_HISTORY_UPDATE_DROP` and `LOOT_HISTORY_UPDATE_ENCOUNTER`, plus a 1 s
  `C_Timer.NewTicker` poll while any roll row is open (`LootRolls.lua:101-109,663-688`).
- Classic path (not Forever): `GetNumItems/GetItem/GetPlayerInfo` with `LOOT_HISTORY_ROLL_CHANGED/COMPLETE`
  (`:482-626`).

**Keying a roll to an item.**
- Row key `"LootRoll_" .. rollID` (`:31-38`). `_activeRolls[rollID] = {itemLink, itemID, lootHandle}` (`:157`).
- `_lootHandleMap[lootHandle][rollID]` groups rolls so `LOOT_ROLLS_COMPLETE(lootHandle)` resolves them (`:159-168,221-249`).
- Drop match: scan every encounter's drops, filter by `GetItemInfoInstant` item ID, sort newest first by
  `startTime`, take the first unclaimed `(encounterID, lootListID)` (`:256-291,343-373`).
- `_claimedDrops` keeps every claimed drop for the session, so a new roll never latches onto an older boss's
  finished drop of the same item (`:24-27,304-316`).
- Once matched, `HandleHistoryDropUpdate` pushes `GetSortedInfoForDrop` to the row on each event (`:400-426`).

**Live vs final.** `SetRollResults(dropInfo)` in `LootDisplay/.../LootRollRowMixin.lua:436-560`:
- counts `state == 4` (NoRoll) as waiting; "Waiting on N player(s)" in the second line;
- final text from `dropInfo.winner` ("X won (Need, 87)") or all-pass; "X leads (N)" from `currentLeader`
  after you rolled;
- resolved = `winner` or all passed or (no one waiting and you rolled);
- a signature `waiting|text` skips redraws, because the 1 s poll resends the same data and redraws broke
  the item tooltip (`:513-523`).
- Tooltip lists players grouped waiting / need / greed / disenchant / transmog / pass, class-coloured
  (`:260-417`). `LOOT_HISTORY_WAITING_ON` may be missing on Classic, so it falls back to a literal (`:271-274`).
- State 0/1/2/3 must be remapped before passing to code that expects `LOOT_ROLL_TYPE_*` (1 need, 2 greed,
  3 DE, 4 transmog). Passing `.state` straight through showed a Greed win as Disenchant (`LootRolls.lua:378-395`).
- Replays open rolls after `/reload` through `GetActiveLootRollIDs()` + `C_Loot.GetLootRollDuration` (`:690-701`).

**Roll frame handling.** `BlizzOverrides/LootRollFrames.lua`:
- `SecureHook("GroupLootContainer_OpenNewFrame")` on Mainline/Forever, else `GroupLootFrame_OpenNewFrame`
  (`:17-26`).
- It does **not** call Blizzard's layout code. It sets alpha 0 and turns mouse off on the frame and children,
  because "calling that from addon code risks spreading taint to protected frames laid out with it" (`:10-15,50-82`).
- `Refresh()` walks `GroupLootFrame1..NUM_GROUP_LOOT_FRAMES` and reads `frame.rollID` (`:87-98`).
- Also unregisters `LOOT_HISTORY_GO_TO_ENCOUNTER` on `GroupLootHistoryFrame` to stop auto-open
  (`BlizzOverrides/LootHistory.lua:13-62`).

**Master loot.** Not handled. No `GetLootMethod` call in the addon. MEASURED (grep).

**Other Forever notes.** `UnitName` second return is the last name on Forever, so it uses
`GetUnitName(unit, false)` (`Features/PartyLoot/PartyLoot.lua:69-74`). Own-loot detection also compares the
"First Last" sender (`ItemLoot.lua:666-675`). MEASURED.

### 3.2 XLoot (Group + Master) — revival fork, TOC lists 16001

TOC `## Interface: 11509, 16001, 20506, 50504, 120105, 120100, 120007` (`XL/Modules/Group/XLoot_Group.toc:1`). MEASURED.

**Flavor detection.** `XLoot.IS_RETAIL_ENGINE = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or WOW_PROJECT_ID ==
WOW_PROJECT_CAMELOT`, with the comment "Forever runs the retail engine but reports its own project ID,
WOW_PROJECT_CAMELOT, since build 70170" (`XL/XLoot.lua:27-28`). MEASURED. A Forever build change once made
XLoot treat Forever as Classic and register the dead Classic events. REPORTED (`XL/CHANGELOG.md:130-134`).
Its test preview uses Classic items on Forever since Retail items do not load there. REPORTED (`:122-125`).

**Data source.** `C_LootHistory.GetSortedInfoForDrop` on `LOOT_HISTORY_UPDATE_DROP`, gated by the
`roll_status` option (`Group.lua:688-764`). Classic path uses `GetItem/GetPlayerInfo` (`:514-580`). The
module caches the API at load and guards nil: "C_LootHistory is nil on some Classic builds" (`:12-17`). MEASURED.

**Keying.** `DropKey = encounterID * 100000 + lootListID` (`:598-600`). `ResolveRetailFrame` binds by item
ID, **oldest roll first (FIFO)**, never to a frame already bound or finished, and never binds a drop that
is already complete (`:607-631`). Note: RPGLootFeed picks newest drop; XLoot picks oldest roll. Both are
heuristics. INFERRED that they agree for one drop per item, and may differ for two identical drops.
Secret values are checked before reading the link (`:602-605`). XLoot also notes the game reuses rollIDs;
a stale bar once showed the wrong winner (`XL/CHANGELOG.md:101-104`). REPORTED.

**Live vs final.**
- Live: per-button counts of need / greed / transmog / pass from `rollInfos[].state` (`:715-731`).
- After you roll: `HoldForResult` hides the buttons and shows "awaiting", with a 360 s timeout
  (`:22-23,647-656`); the status line then shows `currentLeader` (`:701-714`).
- Final: `winner` or `allPassed` → class-coloured winner, with a need/greed/transmog icon; expire timers
  differ for won and lost (`:658-686`).
- Hovering a button lists who picked it, with roll number once known; "Retail and WoW Forever". REPORTED
  (`XL/CHANGELOG.md:30-34`), code at `Group.lua:900-1060`.

**Roll frame.** XLoot replaces Blizzard's frames. It calls `UnregisterAllEvents()` on `GroupLootFrame1..4`,
hides them, routes through `GroupLootContainer_RemoveFrame`, and `hooksecurefunc(f, "Show", HideRollFrame)`
(`:110-133`). It calls `RollOnLoot` from its own buttons. This is the heavy approach. INFERRED: it is
more taint-prone than RPGLootFeed's alpha-only conceal, and DropWatcher should not copy it.

**Master loot.**
- Detection: `C_PartyInfo.GetLootMethod()` with `Enum.LootMethod.Masterlooter`, fallback to the old string
  `GetLootMethod()`, last resort `GetMasterLootCandidate(1, 1) ~= nil` while a loot window is open
  (`XL/helpers.lua:266-296`). `IsMasterLooter` uses the raid or party ID that comes back (`:286-296`). MEASURED.
- `XLoot_Master/Retail.lua` loads on Retail and Forever (`:1-2`). It removes Blizzard's
  `OPEN_MASTER_LOOT_LIST` callback from each roll frame with `EventRegistry:UnregisterFrameEventAndCallback`
  (`:50-62`). It awards with `GiveMasterLoot(slot, index)` (`:252,291`).
- Auto-roll is skipped under master loot (`Group.lua:255`). MEASURED.
- No pending-item view for non-ML players. MEASURED (absent).

### 3.3 Pawn 2.14.1 (installed on Forever, `## Interface: 16001`)

**Roll frame annotation**, the closest match to "show my verdict on Blizzard's popup":
- XML: `PawnUI_LootUpgradeAdvisor1..4` buttons, `parent="GroupLootFrame1..4"`, a `GlowBoxTemplate`
  callout (`FV/Pawn/PawnUI.xml:345-376`). MEASURED.
- `GroupLootFrameN:HookScript("OnShow", PawnUI_GroupLootFrame_OnShow)` and
  `GroupLootFrameN.IconFrame:HookScript("OnMouseUp", ...)` for right-click compare (`FV/Pawn/Pawn.lua:365-380`). MEASURED.
- The handler reads `self.rollID`, `GetLootRollItemLink(rollID)`, runs `PawnIsItemAnUpgrade`, writes text,
  sizes and shows the callout, or hides it (`FV/Pawn/PawnUI.lua:2335-2426`). MEASURED.
- It hooks `LootHistoryFrame_UpdateItemFrame` only when the old `LootHistoryFrame` exists; the author says the
  10.1 rewrite is "more challenging to override" (`Pawn.lua:382-387`). So Pawn does not annotate the modern
  history frame on either client. MEASURED.
- `hooksecurefunc("LootWonAlertFrame_SetUp", ...)` marks the loot-won toast (`Pawn.lua:390`). MEASURED.
- Taint stance: only `HookScript` and `hooksecurefunc`, no writes to Blizzard fields. INFERRED safe; it runs
  on the installed Forever client.

Pawn also exposes `PawnIsItemIDAnUpgrade`, which XLoot calls for its "+" mark (`XL/helpers.lua:88-94`). MEASURED.

### 3.4 GearQuestForever 1.1.4 (installed on Forever)

- `HookFunction("GroupLootFrame_OpenNewFrame", ...)` guarded by `type(_G[name]) == "function"`
  (`FV/GearQuestForever/Indicator.lua:1791-1796,1810-1812`). On Forever that function does not exist; the
  Mainline name is `GroupLootContainer_OpenNewFrame`. So the hook silently never installs. INFERRED from
  `WUS-F/.../GroupLootFrame.lua:162` (only `GroupLootContainer_OpenNewFrame` is defined).
- It still works, because it also registers `START_LOOT_ROLL` and calls `UpdateGroupLootFrames()`
  (`:1856`, `:1600-1610`). That walks `GroupLootFrame1..4`, reads `frame.rollID`, and draws an indicator.
  MEASURED. Lesson: hook the Mainline name, and keep an event fallback.

### 3.5 EllesmereUI Forever Essentials 9.8.4 — loot feed (installed on Forever)

- Registers `LOOT_HISTORY_UPDATE_DROP` when `C_LootHistory` exists (`FV/EllesmereUIForeverEssentials/EllesmereUIForeverEssentials_LootFeed.lua:1121`).
- Shows a drop once, when `winner` or `allPassed == true`; key `"roll:" .. encounterID .. ":" .. lootListID`
  (`:1002-1021`). Final-only, no live state. MEASURED.
- Every field goes through `Plain(v, kind)`: `not issecretvalue(v) and type(v) == kind` (`:57-59`). Roll
  label from `Enum.EncounterLootDropRollState` (`:963-972`). MEASURED. DropWatcher's `Compat.LootHistoryDrop`
  already follows this pattern (`core/Compat.lua:409-434`).

### 3.6 Gargul (GitHub; TOC has `## Interface-Camelot: 16001`)

- Flavor: `GL.isForever = tocVersion >= 16000 and < 17000`, "vanilla rules on the modern codebase, so Era
  behavior but not Era APIs" (`GG/bootstrap.lua:28-30`). TOC uses per-flavor `## Interface-Camelot:` lines
  (`GG/Gargul.toc`). MEASURED.
- Loot method: `GetLootMethod()` if present, else `C_PartyInfo.GetLootMethod()` mapped to strings
  (0 freeforall … 2 master … 5 personalloot). For a party, ML index comes from
  `select(11, GetRaidRosterInfo(i))` (`GG/Utils/Shims.lua:175-221`). MEASURED.
- Roll popup: on `START_LOOT_ROLL`, walk `GroupLootFrame1..NUM_GROUP_LOOT_FRAMES`, read `frame.rollID`,
  glow the frame for soft-reserved / wishlisted items (`GG/Classes/GroupLoot.lua:20,44-56`). MEASURED.
- ML: `OPEN_MASTER_LOOT_LIST` listener shows a reminder; `MasterLooterFrame:HookScript("OnHide")`
  (`GG/Classes/DroppedLoot.lua:55-68`). Its own rolls are `/roll` results parsed from `RANDOM_ROLL_RESULT`
  (`GG/Classes/RollOff.lua:17`). MEASURED.
- Forever names: "Forever has no realms, every character has a last name instead … UnitName returns the last
  name where the realm normally goes … WoW functions that take a name (whisper, invite, Unit*) get
  'Cline-Gloomhaunt'" (`GG/Utils/PlayerNames.lua:4-6`). The GUID path is marked "Assumed, not verified"
  (`GG/Classes/Player.lua:38-43`). REPORTED.

### 3.7 RCLootCouncil (GitHub; Retail only)

- TOC `## Interface: 120105`; `IsCorrectVersion()` = `WOW_PROJECT_MAINLINE == WOW_PROJECT_ID`, else it
  disables itself (`RC/core.lua:278-283,2217`). It does not run on Forever. MEASURED.
- Others' choices come from **addon comms** (its council protocol), not loot history. It treats the group
  leader as "ML" (`RC/core.lua:2046-2067`). MEASURED.
- Roll frame: on `START_LOOT_ROLL` it may auto-pass/auto-roll, then hides the matching Blizzard frame with
  `GroupLootContainer_RemoveFrame(GroupLootContainer, frame)` (`RC/Classes/Utils/GroupLoot.lua:46-100,251-279`).
  MEASURED. This calls Blizzard layout code from addon code, the thing RPGLootFeed avoids.

### 3.8 Others checked

- **ls_Toasts** (installed on Retail, TOC lists 16001): only `LOOT_ITEM_ROLL_WON` for your own win toast
  (`RT/ls_Toasts/systems/standard/loot_special.lua:184-186,236`). MEASURED.
- **RaiderIO** (Retail): reads the Classic `C_LootHistory.GetItem` shape, which includes an `isMasterLoot`
  return (`RT/RaiderIO/core.lua:14118-14119`). MEASURED. That flag exists only in the Classic API. Forever's
  modern drop info has no master-loot field (§2.2). INFERRED.
- **AtlasLootClassic, Questie, AddOnSkins, EllesmereUIBlizzardSkin**: no roll-data code. Skins only restyle.
  MEASURED (grep of `START_LOOT_ROLL|C_LootHistory|GetLootMethod|GroupLootFrame`).
- **teksLoot** (web): a rewrite of XLoot Group. REPORTED (github.com/TekNoLogic/teksLoot, search result).
  Not read.

---

## 4. Comparison table

| Addon | Others' rolls source | Roll ↔ drop key | Live view | Final view | Blizzard popup | ML detect | Forever |
|---|---|---|---|---|---|---|---|
| RPGLootFeed | `C_LootHistory` modern + 1 s poll | itemID, newest unclaimed drop, session claim set | waiting count, leader, tooltip by state | winner + roll / all passed | alpha 0 + mouse off; hook `GroupLootContainer_OpenNewFrame` | none | yes, capability-gated |
| XLoot Group | `C_LootHistory` modern (option) | itemID, oldest unbound roll FIFO | per-button counts; "awaiting" + leader | class-coloured winner | replaced; frames hidden, events off | `C_PartyInfo.GetLootMethod` | yes, `IS_RETAIL_ENGINE` |
| Pawn | n/a | n/a | n/a | n/a | child callout parented to `GroupLootFrameN`, `HookScript OnShow` | n/a | yes |
| GearQuestForever | n/a | n/a | n/a | n/a | `START_LOOT_ROLL` walk of frames | n/a | yes (hook name dead) |
| Ellesmere FE | `LOOT_HISTORY_UPDATE_DROP` | `encounterID:lootList` | none | winner once | none | none | yes |
| Gargul | own comms + `/roll` parse | own | own | own | glow on frames | `GetLootMethod` shim | yes, toc-range |
| RCLootCouncil | addon comms | own session | own | own | `GroupLootContainer_RemoveFrame` | group leader | no |

---

## 5. What this means for DropWatcher (INFERRED recommendations)

1. **Source.** Use `C_LootHistory` modern API on both clients. Read `drop.lootListID or drop.lootListKey`.
   Never register `LOOT_HISTORY_ROLL_CHANGED/COMPLETE`. Gate on the function, not the project ID, like
   RPGLootFeed (`HasModernLootHistoryAPI`).
2. **Key.** History rows can be keyed by `(encounterID, lootListKey)` alone. That needs no rollID. Join a live
   `START_LOOT_ROLL` row to a drop only for the "your popup" annotation, by item ID with a session claim set.
   Keep both RPGLootFeed guards: never rebind a finished drop, and track claimed drops for the whole session.
3. **Live vs final.** `rollInfos[].state == NoRoll` means waiting. `roll == nil` with a chosen state means
   picked but not rolled. Final is `winner ~= nil or allPassed`. Use `isTied` for ties. Do not map `state`
   to `LOOT_ROLL_TYPE_*` by number.
4. **Annotate the popup** the Pawn way: own child frame per `GroupLootFrame1..4`, `HookScript("OnShow")`,
   and `hooksecurefunc("GroupLootContainer_OpenNewFrame")` as a second trigger. Read `frame.rollID` only.
   Do not hide, move, re-layout, or call `GroupLootContainer_*`. Expect Pawn's own callout on the same frame;
   anchor so the two do not overlap. Skip the gamepad roll UI, or treat it as out of scope.
5. **Master loot.** Detect with `C_PartyInfo.GetLootMethod()`; the 2nd/3rd returns give the ML's party or raid
   index. Watch `PARTY_LOOT_METHOD_CHANGED`. No addon shows a pending ML item to non-ML players, so the
   "awaiting master looter" row is new ground. The likely inputs are `ENCOUNTER_LOOT_RECEIVED`-style boss
   loot lists and loot history drops, if ML drops appear there on Forever. Prove that in game first.
6. **Names.** On Forever, store "First Last" and whisper "First-Last" (Gargul). Compare rollInfo
   `playerGUID` where you can, not names.
7. **Secrets.** Wrap every field from `C_LootHistory` in the existing `Compat` plain-value guards (Ellesmere and
   XLoot both do).

---

## 6. Open probes (in-game)

Run on Forever unless noted, in a group with Group Loot on.

1. `/dump C_LootHistory.GetSortedDropsForEncounter(select(1, C_LootHistory.GetAllEncounterInfos()[1].encounterID))`
   after one roll. Look for `lootListKey` (not `lootListID`), `rollInfos[*].roll` nil vs set, `isTied`.
2. `/run local f=CreateFrame("Frame") f:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") f:SetScript("OnEvent",function(_,e,a,b) local d=C_LootHistory.GetSortedInfoForDrop(a,b) print(e,a,b,d and #d.rollInfos, d and d.winner and d.winner.playerName) end)`
   then roll. Count how many updates fire per roll, and whether one fires per player choice.
3. Under Master Loot: `/dump C_PartyInfo.GetLootMethod(), C_PartyInfo.GetLootMethodStyle()`. Expect
   `2, <partyIdx|nil>, <raidIdx|nil>` and `1` (Vanilla). Then kill a boss and run probe 1. Do master-loot
   drops appear in loot history at all, and with what `playerRollState`?
4. `/dump Constants.LootConsts, Constants.LootConsts_Camelot`. Which table exists at runtime? Forever's
   Blizzard code reads `Constants.LootConsts` (`GroupLootFrame.lua:988`).
5. `/dump GroupLootContainer_OpenNewFrame ~= nil, GroupLootFrame_OpenNewFrame ~= nil, NUM_GROUP_LOOT_FRAMES`.
   Expect `true, false, nil` (the 4 is a file local). Confirms the hook name.
6. With Pawn on, open a roll and `/dump PawnUI_LootUpgradeAdvisor1:IsShown(), PawnUI_LootUpgradeAdvisor1:GetPoint()`.
   Shows where Pawn's callout sits, so DropWatcher's badge can avoid it.
7. `/dump UnitName("party1"), GetUnitName("party1", true), UnitGUID("party1")` and compare with a
   `rollInfos[i].playerName`. Is the roll-info name "First", "First Last", or "First-Last"?
8. Under Master Loot as a **non-ML** member: do `START_LOOT_ROLL` or `LOOT_READY` fire for you at all when the
   ML opens the corpse? Register both and print. Also print `CHAT_MSG_LOOT` when the ML awards.
9. Retail: repeat probe 2 in a Group Loot dungeon to confirm the same update cadence there.
