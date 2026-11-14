# 02 — Everyone's loot rolls: what an addon can read, on Retail and on Forever

Research note for the Forever port run (2026-11-13). Read-only research. No code was changed.

Tags: **MEASURED** = seen in Blizzard source, the generated API docs, or Ketho's dumps.
**REPORTED** = a third party says so. **INFERRED** = my reading; it needs a probe or a test.

## 0. The short version

1. `C_LootHistory` gives every roller on a group-loot drop, on both clients. Each drop has `rollInfos[]`,
   one row per eligible player, with name, GUID, class, state, roll number and a winner flag. **MEASURED**.
2. Players who have not chosen yet are in the list, with state `NoRoll`. Blizzard builds its "Waiting on:"
   line from them. **MEASURED** (consumer code, §4).
3. Roll numbers can exist while the roll is still open. Blizzard shows `currentLeader.roll` before there is a
   winner. **MEASURED** (consumer code). When each number appears (on choice or only at close) is **not**
   settled by source. Probe P1.
4. `LOOT_HISTORY_UPDATE_DROP(encounterID, key)` is the per-drop refresh signal. Blizzard re-reads the whole
   drop on every fire. It does not say that it fires once per choice. Probe P2.
5. **The one hard API difference:** the drop key field is named `lootListID` on Retail and `lootListKey` on
   Forever. That is the field name in `EncounterLootDropInfo` and in Blizzard's own code. Read
   `drop.lootListID or drop.lootListKey`. **MEASURED** (§2.2).
6. `C_LootHistory` has no secret-return flags on either client. Its three getters take
   `SecretArguments = "AllowedWhenUntainted"`: pass only plain numbers. **MEASURED**.
7. `CHAT_MSG_LOOT` has no `SecretInChatMessagingLockdown` flag on either client. `CHAT_MSG_SYSTEM` and
   whispers do. **MEASURED**. So roll chat lines are a usable fallback in instances, per the docs.
8. The roll chat strings differ a lot. On Forever every roll line starts with a `|HlootHistory:<encounterID>|h`
   link. On Retail only your own lines and the summary lines carry it. **MEASURED** (§9).
9. The roll popups (`GroupLootFrame1..4`) are plain, unprotected frames on both clients. No secure template.
   The safest annotation is an own frame anchored to them, driven by `HookScript("OnShow"/"OnHide")`.
   **MEASURED** (frame XML) + **INFERRED** (method). The button layout differs between the clients (§10).

## 1. Sources

- Forever UI source: Gethe/wow-ui-source, branch `forever`, commit `4cd0ab7` "1.60.1 (70888)". Local sparse
  clone: `scratchpad/wus-forever` (below, paths start at `Interface/AddOns/`). **MEASURED**.
- Retail UI source: Gethe/wow-ui-source, branch `live`, commit `297d7aa` "12.1.5 (70783)". Local sparse clone:
  `scratchpad/wus-live`. **MEASURED**.
- Ketho/BlizzardInterfaceResources, branches `forever` and `live`: `Resources/GlobalStrings/enUS.lua`,
  `Resources/Events.lua`, `Resources/GlobalAPI.lua`, `Resources/LuaEnum.lua`. Local copies under
  `scratchpad/ketho/` and `scratchpad/luaenum/`.
- warcraft.wiki.gg: https://warcraft.wiki.gg/wiki/Event:LOOT_HISTORY_UPDATE_DROP and
  https://warcraft.wiki.gg/wiki/API_C_LootHistory.GetSortedDropsForEncounter (no firing details, no trash
  details). **REPORTED**.
- DropWatcher today: `core/Compat.lua:409-436`, `modules/LootFeed.lua:1018-1046`.

`F:` = forever file, `L:` = live file, both relative to `Interface/AddOns/`.

## 2. The C_LootHistory surface

### 2.1 Functions (same on both clients)

Ketho's GlobalAPI lists the same five functions on both branches. **MEASURED**
(`ketho/fn_forever.lua`, `ketho/fn_live.lua`, filtered set identical).

| Function | Args | Returns | Secret note |
|---|---|---|---|
| `GetAllEncounterInfos()` | none | `EncounterLootInfo[]` | none |
| `GetInfoForEncounter(encounterID)` | number | `EncounterLootInfo?` | `SecretArguments = "AllowedWhenUntainted"` |
| `GetLootHistoryTime()` | none | number (the clock for `startTime`) | none |
| `GetSortedDropsForEncounter(encounterID)` | number | `EncounterLootDropInfo[]?` | `AllowedWhenUntainted` |
| `GetSortedInfoForDrop(encounterID, key)` | number, number | `EncounterLootDropInfo?` | `AllowedWhenUntainted` |

Evidence: `F:Blizzard_APIDocumentationGenerated/LootHistoryDocumentation.lua:10-73`;
`L:` same file, same lines. **MEASURED**.

### 2.2 Structures

`EncounterLootInfo` = `{ encounterName, encounterID, startTime, duration }`
(`F:...LootHistoryDocumentation.lua:186-196`). **MEASURED**.

`EncounterLootDropInfo` (`F:...LootHistoryDocumentation.lua:146-162`). **MEASURED**:

| Field | Type | Note |
|---|---|---|
| `lootListKey` (Forever) / `lootListID` (Retail) | number | **Name differs.** `L:` line 151 says `lootListID`; `F:` line 151 says `lootListKey`. |
| `itemHyperlink` | string | |
| `playerRollState` | `EncounterLootDropRollState` | your own state |
| `currentLeader` | `EncounterLootDropRollInfo?` | leader while open |
| `isTied` | bool | |
| `winner` | `EncounterLootDropRollInfo?` | set once resolved |
| `allPassed` | bool | |
| `rollInfos` | `EncounterLootDropRollInfo[]` | never nil |
| `startTime`, `duration` | number | per drop, on the `GetLootHistoryTime()` clock |

`EncounterLootDropRollInfo` = `{ playerName, playerGUID, playerClass, isSelf, state, isWinner, roll? }`
(`F:...LootHistoryDocumentation.lua:163-176`). `roll` is the only nilable field. **MEASURED**.

`Enum.EncounterLootDropRollState`: NeedMainSpec 0, NeedOffSpec 1, Transmog 2, Greed 3, NoRoll 4, Pass 5
(`F:...LootHistoryDocumentation.lua:130-145`; also `luaenum/forever.lua:3072-3079`). Same on Retail.
**MEASURED**. The order matters: Blizzard compares `state < NoRoll` to mean "made a real roll"
(`F:Blizzard_FrameXML/Mainline/LootHistory.lua:80`, `:542`).

The `lootListID` → `lootListKey` rename runs through all of Blizzard's code on Forever. `diff` of the two
`LootHistory.lua` files shows every `lootListID` turned into `lootListKey` (`F:Blizzard_FrameXML/Mainline/LootHistory.lua:19-21`,
`:201-205`, `:382-385`, `:405-409`, `:546`). **MEASURED**. The event payload is positional, so DropWatcher's
`LF.OnLootHistoryDrop(encounterID, lootListID)` (`modules/LootFeed.lua:1019`) is fine on both. Any new code that
reads the key **from the drop table** (for example to walk `GetSortedDropsForEncounter`) must read both names.
**INFERRED** from the docs. Probe P8 confirms the runtime field name.

### 2.3 Events (same set on both clients)

Ketho's Events lists the same five `LOOT_HISTORY_*` events on both (`ketho/ev_forever.lua:1274-1279`).
The 48 events with LOOT or ROLL in the name are identical on both branches. **MEASURED** (sorted diff empty).

| Event | Payload | Flag | Blizzard listens |
|---|---|---|---|
| `LOOT_HISTORY_UPDATE_DROP` | encounterID, key | `UniqueEvent` | each visible row, and the frame while shown |
| `LOOT_HISTORY_UPDATE_ENCOUNTER` | encounterID | `UniqueEvent` | frame while shown → full refresh |
| `LOOT_HISTORY_ONE_HUNDRED_ROLL` | encounterID, key | `SynchronousEvent` | frame while shown → "perfect roll" animation |
| `LOOT_HISTORY_CLEAR_HISTORY` | none | `SynchronousEvent` | frame always → wipes its view |
| `LOOT_HISTORY_GO_TO_ENCOUNTER` | encounterID | `UniqueEvent` | frame always → opens to that encounter |

Evidence: `F:...LootHistoryDocumentation.lua:76-126`; listeners at
`F:Blizzard_FrameXML/Mainline/LootHistory.lua:7-10`, `:209-215`, `:301-311`, `:363-389`. **MEASURED**.

`UniqueEvent` is not defined in the docs. My reading is that duplicate fires are merged (one per frame or
per key). **INFERRED**. That would mean several choices in one frame can arrive as one event. Always re-read
the whole drop; never count events. Blizzard does the same (§5).

## 3. When things happen during a roll

What the source proves. **MEASURED**:

- Blizzard refreshes a row only on `LOOT_HISTORY_UPDATE_DROP` for that `(encounterID, key)`
  (`F:Blizzard_FrameXML/Mainline/LootHistory.lua:17-25`). There is no polling of roll data. The only
  `OnUpdate` is the timer bar (`:494-519`). So Blizzard relies on `UPDATE_DROP` to show live changes:
  new choices, the moving leader, the winner.
- While a drop has no winner, the row shows "pending" and, if `currentLeader` is set, "Name (roll)"
  (`:144-163`). A roll number is therefore readable **before** the roll closes, at least for the leader.
- The tooltip lists rows with `roll.roll` numbers and notes "If there are any roll numbers, they will be at
  the top of the roll list" (`:73-75`). So the list is sorted: numbered rolls first.
- The timer ends when every drop has `winner` or `allPassed`, or `duration` has passed
  (`:498-519`).

What the source does not prove:

- Whether `UPDATE_DROP` fires once for every single choice. **INFERRED yes**, because Blizzard's live tooltip
  ("Waiting on: A, B") would go stale otherwise. Probe P2.
- Whether each player's number appears the moment they choose, or all at once at close. The
  `currentLeader.roll` display suggests numbers appear as people choose. **INFERRED**. Probe P1.
- Whether `UPDATE_DROP` fires once at drop start with everyone at `NoRoll`. **INFERRED likely**
  (`LOOT_ROLL_STARTED` chat line exists, §9). Probe P2.

## 4. Who is in `rollInfos`

**MEASURED** from Blizzard's tooltip code (`F:Blizzard_FrameXML/Mainline/LootHistory.lua:58-106`):

- Players at `NoRoll` are in the list. Blizzard appends each one's class-coloured name to "Waiting on: "
  (`:87-96`) and shows that line while there is no winner (`:99-105`).
- Players at `Pass` are in the list. They get the pass icon (`:251-252`).
- `isSelf` marks you. Blizzard always shows your own row once you have chosen (`:80`).
- `isWinner` marks the winner. A check mark is drawn (`:277-281`).
- Rows can be "in a weird state due to multiple item instance win protection": a row with a higher roll
  than the winner who is not the winner. Blizzard hides those (`:77-78`). DropWatcher should treat
  `isWinner` / `winner` as the truth, not "highest roll".
- Blizzard only shows rows whose state is at or above the top state (`roll.state <= topRollState`, `:80`).
  It hides Greed rows when someone Needed. DropWatcher can show all; the data is there.
- Off-spec Need is its own state (`NeedOffSpec`), shown with "(Off-Spec)" (`:272-274`).

`playerName` format is not documented (bare name, or name-realm for cross-realm). Forever may also have
surname issues seen elsewhere in the collection. **INFERRED** risk. Probe P5. Prefer `playerGUID` as the key.

## 5. How Blizzard reads and refreshes (the pattern to copy)

**MEASURED** (`F:Blizzard_FrameXML/Mainline/LootHistory.lua`; Retail is the same minus gamepad code):

1. On show: pick the first entry of `GetAllEncounterInfos()` (`:336-344`).
2. Full refresh: `GetInfoForEncounter(id)` for the timer, then `GetSortedDropsForEncounter(id)` for the
   rows; each row stores `(encounterID, key)` (`:521-547`).
3. Each row calls `GetSortedInfoForDrop(encounterID, key)` on set-up and on every matching
   `UPDATE_DROP` (`:201-207`, `:17-25`).
4. `UPDATE_ENCOUNTER` for the shown encounter → full refresh (`:370-374`). This is how new drops appear.
5. `ONE_HUNDRED_ROLL` → queue an animation and full refresh (`:381-387`).
6. `CLEAR_HISTORY` → drop all state (`:375-380`).
7. Your own state per drop is `dropInfo.playerRollState`. Passed drops sort under a "Passed" header
   (`:531-541`).
8. The tutorial is skipped when `C_PartyInfo.GetLootMethod() == Enum.LootMethod.Masterlooter` (`:552`).
   That is the only loot-method check in the file.

Recommended model for DropWatcher (**INFERRED**): listen to `UPDATE_ENCOUNTER` (new drops) and
`UPDATE_DROP` (changes) at all times, not only while a window is open. On each, re-read with
`GetSortedInfoForDrop`. Copy the plain fields out at once (§7). Store by `encounterID:key`. Mark the drop
final when `winner` or `allPassed` is set. This is the same key DropWatcher's feed already uses
(`modules/LootFeed.lua:1022`).

## 6. Encounter IDs, and trash

- `encounterID` is a plain number in the payloads and the link (§9). **MEASURED**.
- The loot-history link handler reads the first field of `|HlootHistory:...|h` as the encounter ID and opens
  that encounter (`F:Blizzard_UIPanels_Game/Mainline/ItemRefHandlers.lua:99-102`; same in `L:`).
  **MEASURED**. This answers sibling note 03's open probe 8: the link id is the **encounterID**, not the key.
- What ID trash or open-world group drops get is **not in the source or the docs**. The wiki is silent.
  **REPORTED gap**. Possibilities: a real `DungeonEncounter` ID only for bosses, and a synthetic ID (for
  example the instance or a session counter) with an `encounterName` like the zone. **INFERRED**. Probe P3.
- Hint: the info text differs. Retail: "Loot rolls from dungeons and raids are displayed here". Forever:
  "Loot rolls from group content are displayed here" (`ketho/live_enUS.lua:13362`,
  `ketho/forever_enUS.lua:13851`). **MEASURED** text; the meaning (Forever rolls in the open world too) is
  **INFERRED**.
- Do not assume `encounterID` matches `ENCOUNTER_START`'s ID for trash. Use it only as an opaque key plus the
  `encounterName` from `GetInfoForEncounter`.

## 7. Secret values (Midnight rules) on both clients

**MEASURED** from the generated docs:

- `LootHistoryDocumentation.lua` on both branches has only `SecretArguments = "AllowedWhenUntainted"` on
  `GetInfoForEncounter`, `GetSortedDropsForEncounter`, `GetSortedInfoForDrop`. No `SecretReturns`,
  `ConditionalSecret`, `SecretWhen*`, or `SecretInChatMessagingLockdown` on any function, field or event.
- `AllowedWhenUntainted` means addon (tainted) code must not pass a secret argument. Passing the event
  payload numbers is fine if they are plain. DropWatcher already checks with `plainNumber` before the call
  (`core/Compat.lua:428`). Keep that.
- `C_Loot.GetLootRollDuration(rollID)` has the same `AllowedWhenUntainted` flag
  (`F:...LootDocumentation.lua:11-13`). The legacy roll globals (`GetLootRollItemInfo`, `GetLootRollItemLink`,
  `GetLootRollTimeLeft`, `RollOnLoot`, `GetActiveLootRollIDs`) are not in the generated docs at all, so they
  carry no flags. **MEASURED** absence.
- `CHAT_MSG_LOOT` has no `SecretInChatMessagingLockdown` flag on either client
  (`L:...ChatInfoDocumentation.lua:1786-1810`, `F:` same at `:1813-1837`). Its `text`, `playerName` and `guid`
  are not marked `NeverSecret`, though. **MEASURED**.
- `CHAT_MSG_SYSTEM` (where `/roll` results arrive as `RANDOM_ROLL_RESULT`) and `CHAT_MSG_WHISPER` **are**
  `SecretInChatMessagingLockdown` on both. The predicate covers "encounter, challenge mode, or PvP match
  addon restrictions ... and when the player is on a communication-restricted map such as a dungeon or raid"
  (`F:...SecretPredicatesDocumentation.lua:65-68`; same on `L:`). **MEASURED**.
- Both clients expose `issecretvalue`, `canaccessvalue`, `issecrettable`, `canaccesstable`,
  `C_ChatInfo.InChatMessagingLockdown`, `hooksecurefunc` (`ketho/fn_*.lua`). **MEASURED**.

Rules to keep (**INFERRED**, defensive, matching `core/Compat.lua:409-436`):

1. Treat every returned field as possibly secret anyway. The docs can lag the runtime. Guard the table, each
   string, each number and each bool, as `lootWinner` already does.
2. Copy plain values out once; never keep the Blizzard table.
3. Never use a secret value as a table key (`Compat.IsSafeKey` on GUIDs, as now).
4. For the "Ask the master looter" whisper: check `C_ChatInfo.InChatMessagingLockdown()` before
   `SendChatMessage`. Whispers are restricted in instances during lockdown. (Out of scope here; flagged
   for the master-loot note.)

Forever is the same Midnight-era engine (same predicate list, same flags on these APIs). Whether Forever
actually turns lockdown on in its dungeons is not knowable from source. Probe P6.

## 8. Your own roll: START_LOOT_ROLL and mapping to a drop

**MEASURED**:

- `START_LOOT_ROLL(rollID, rollTime, lootHandle?)`, `SynchronousEvent` (`F:...LootDocumentation.lua:405-416`;
  identical on `L:`, the two `LootDocumentation.lua` files are byte-identical).
- Also: `CANCEL_LOOT_ROLL(rollID)`, `CANCEL_ALL_LOOT_ROLLS`, `MAIN_SPEC_NEED_ROLL(rollID, roll, isWinning)`,
  `LOOT_ROLLS_COMPLETE(lootHandle)`, `LOOT_ITEM_ROLL_WON(itemLink, rollQuantity, rollType, roll, upgraded)`,
  `CONFIRM_LOOT_ROLL(rollID, rollType, confirmReason)` (`F:...LootDocumentation.lua:91-127`, `:204-216`,
  `:239-247`, `:269-279`).
- `GetLootRollItemInfo(rollID)` returns `texture, name, count, quality, bindOnPickUp, canNeed, canGreed,
  canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired, canTransmog`
  (Blizzard's own call: `F:Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:317`,
  `L:` same file `:163`). `bindOnPickUp` is what the Forever "only BoE can change hands" rule needs.
- `GetLootRollItemLink(rollID)` exists on both (`ketho/fn_*.lua`).
- Blizzard routes `START_LOOT_ROLL` to `GroupLootContainer_AddRoll(rollID, rollTime)`
  (`L:Blizzard_Game/Mainline/EventImplementation.lua:385-387`; routing `Mainline/EventRouting.lua:103`).
  On Forever the same handler returns early in gamepad mode (`F:` same file `:385-391`), and the gamepad
  list frame takes the event itself (`F:Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:1206-1220`).
- On login and reload, open rolls are rebuilt from `GetActiveLootRollIDs()` with
  `C_Loot.GetLootRollDuration` (`L:Blizzard_Game/Mainline/EventImplementation.lua:821-824`;
  Forever gamepad `GroupLootFrame.lua:1488-1493`). DropWatcher can do the same after `/reload`.
- Roll type IDs for `RollOnLoot(rollID, type)`: Pass 0, Need 1, Greed 2, Disenchant 3, Transmog 4. These
  are the button `id`s in both XML files (`L:...GroupLootFrame.xml:371-418`, `F:` `:491-538`).
  `Enum.LootRollType` with these values exists on Forever (`luaenum/forever.lua:5552-5558`) but is not in the
  Retail enum dump. **REPORTED** (Ketho). Use literals or a guarded lookup.

**Mapping rollID → (encounterID, key):** there is no API that does it. **MEASURED** absence (no function
takes a rollID and returns a loot-history key; no history struct carries a rollID). Options, best first.
All **INFERRED**:

1. **Chat link on start.** `LOOT_ROLL_STARTED = "|HlootHistory:%d|h[Loot]|h: %s"` on both clients
   (§9) gives encounterID + item link right when the roll opens. Match that link to
   `GetLootRollItemLink(rollID)`.
2. **Item-link match.** Walk `GetSortedDropsForEncounter(encounterID)` for an open drop (no `winner`, not
   `allPassed`) whose `itemHyperlink` equals `GetLootRollItemLink(rollID)` and whose `playerRollState` is
   `NoRoll`. Break ties by `startTime` closest to the `START_LOOT_ROLL` time.
3. **Your own choice line.** After you click, `LOOT_ROLL_NEED_SELF` etc. carry the encounterID on both
   clients.

Two identical items on one boss is the hard case. Then key order (`startTime`, then key) is the only hint.
Probe P4 also checks whether `rollID` happens to equal the key.

## 9. CHAT_MSG_LOOT roll lines (fallback and cross-check)

Roll choice and result lines arrive on `CHAT_MSG_LOOT`. **REPORTED / INFERRED** (they use the LOOT_ROLL_*
GlobalStrings; DropWatcher's own test fires "Someone has selected Need for:" as `CHAT_MSG_LOOT`,
`tests/test_diagnostics.lua:108`). Probe P7 confirms the event per line.

Key strings (`ketho/forever_enUS.lua:13902-13940`, `ketho/live_enUS.lua:13413-13450`). **MEASURED**.
`LH(%d)` below stands for `|HlootHistory:%d|h[Loot]|h: `; the `%d` is the encounterID (§6).

| Key | Retail 12.1.5 | Forever 1.60.1 |
|---|---|---|
| `LOOT_ROLL_STARTED` | `LH(%d)%s` | same |
| `LOOT_ROLL_NEED` | `%s has selected Need for: %s` | `LH(%d)%s has selected Need for: %s` |
| `LOOT_ROLL_GREED` | `%s has selected Greed for: %s` | `LH(%d)...` prefix |
| `LOOT_ROLL_PASSED` | `%s passed on: %s` | `LH(%d)...` prefix |
| `LOOT_ROLL_NEED_SELF` | `LH(%d)You have selected Need for: %s |HlootHistory:%d|h[View Loot Rolls]|h` | `LH(%d)You have selected Need for: %s` |
| `LOOT_ROLL_NEED_SELF_OFF_SPEC` | `... Need (Off-Spec) for: %s` + View link | **same text as main-spec** |
| `LOOT_ROLL_GREED_SELF`, `..._PASSED_SELF`, `..._PASSED_SELF_AUTO` | with trailing View link (two `%d`) | no trailing link (one `%d`) |
| `LOOT_ROLL_ROLLED_NEED` | `Need Roll - %d for %s by %s` | `LH(%d)Need Roll - %d for %s by %s` |
| `LOOT_ROLL_ROLLED_GREED` | `Greed Roll - %d for %s by %s` | `LH(%d)...` prefix |
| `LOOT_ROLL_ROLLED_TRANSMOG` | **absent** | `LH(%d)Transmog Roll - %d for %s by %s` |
| `LOOT_ROLL_ROLLED_DE`, `..._NEED_ROLE_BONUS` | no link | no link (same) |
| `LOOT_ROLL_WON` | `%s won: %s` | `LH(%d)%s won: %s` |
| `LOOT_ROLL_YOU_WON` | `You won: %s` | `LH(%d)You won: %s` |
| `LOOT_ROLL_WON_NO_SPAM_*`, `LOOT_ROLL_YOU_WON_NO_SPAM_*` | `LH(%d)...` | same |
| `LOOT_ROLL_ALL_PASSED`, `LOOT_ROLL_LOST_ROLL` | `LH(%d)...` | same |
| `LOOT_ROLL_PASSED_AUTO(_FEMALE)` | no link | no link |
| `RANDOM_ROLL_RESULT` (`/roll`, on `CHAT_MSG_SYSTEM`) | `%s rolls %d (%d-%d)` | same |

What this means. **INFERRED**:

- Build patterns from the GlobalStrings at run time. Never hard-code the text. DropWatcher's parser
  already does this for receipt lines.
- On Forever, every per-player line carries the encounterID. On Retail, other players' choice and number
  lines do not. So on Retail the chat fallback maps a line to a drop by item link only.
- On Forever, the off-spec self line is the same text as main-spec. Chat cannot tell them apart; the history
  `state` can.
- The "View Loot Rolls" suffix and the extra `%d` on Retail self lines must be allowed for by the pattern
  builder (two `%d` captures, the second repeated).
- Chat lines are a fallback and a cross-check, not the primary source. `C_LootHistory` has the full roster,
  GUIDs and the winner flag; chat has neither the `NoRoll` list nor GUIDs.

## 10. The Blizzard roll popups, and how to annotate them

### 10.1 What exists

| | Retail 12.1.5 | Forever 1.60.1 |
|---|---|---|
| Container | `GroupLootContainer`, `ContainedAlertFrame` inheriting `BottomManagedFrameTemplate` (`L:...GroupLootFrame.xml:537-545`) | same (`F:` `:632-640`) |
| Popups | `GroupLootFrame1..4` inherit `GroupLootFrameTemplate` (`L:` `:290`, `:546-549`) | `GroupLootFrame1..4` inherit `MKBGroupLootFrameTemplate` → `GroupLootFrameBaseTemplate` (`DefaultDialogPanelTemplate`) (`F:` `:291`, `:482`, `:641-644`) |
| Buttons | `frame.NeedButton`, `.PassButton`, `.GreedButton`, `.TransmogButton`; array `frame.LootButtons` (`L:` `:371-418`; `GroupLootFrame.lua:187-205`, `:258`) | `frame.LootButtonContainer.NeedButton` etc.; array `frame.LootButtonContainer.LootButtons` (`F:` `:484-538`; `GroupLootFrame.lua:339-360`, `:440`) |
| Button click | `RollOnLoot(self:GetParent().rollID, self:GetID())` (`L:` `:6-7`) | `RollOnLoot(self:GetParent():GetParent().rollID, self:GetID())` (`F:` `:6-7`) |
| Set-up | inline in `GroupLootFrame_OnShow` (`L:GroupLootFrame.lua:162-212`) | `GroupLootFrame_OnShow` calls global `GroupLootFrame_SetupItemDisplay(self)` (`F:` `:312-381`) |
| Frame fields | `rollID`, `rollTime` set by `GroupLootContainer_OpenNewFrame` (`L:` `:108-120`) | same (`F:` `:162-174`), plus `canNeed`, `canGreed`, `canTransmog` (`:364-366`) |
| Gamepad mode | none | `GamepadGroupLootRollFrame` (mixin `GamepadGroupLootRollFrameMixin`) with ScrollBox cards from `GamepadGroupLootRollFrameTemplate`; `GroupLootFrame1..4` are not used (`F:...GroupLootFrame.xml:551-630`; `GroupLootFrame.lua:1058-1493`; `Blizzard_Game/Mainline/EventImplementation.lua:385-391`) |
| Loaded | `Blizzard_UIPanels_Game_Mainline.toc:43-44` | `Blizzard_UIPanels_Game.toc:129-130` `[Family]\GroupLootFrame.* [AllowLoadGameType mainline]`; Forever's family is Mainline |

At most 4 popups show; more rolls queue in `GroupLootContainer.waitingRolls` and open as slots free
(`F:GroupLootFrame.lua:76-99`, `:156-160`). **MEASURED**.

Protection. **MEASURED**: no `protected="true"`, no `Secure*` template, no secure attributes on any of these
frames in either XML (grep of both `GroupLootFrame.xml` files). `RollOnLoot` is called from plain Lua
`OnClick`. These are ordinary frames.

### 10.2 Safest way to annotate (**INFERRED**, ordered)

1. **Own overlay frame, anchored, driven by `HookScript`.** Create one small frame per popup, parented to
   `UIParent` (or the popup), anchored to `GroupLootFrameN` (for example beside `.Name` or below the frame).
   Call `GroupLootFrameN:HookScript("OnShow", ...)` and `("OnHide", ...)`. In the hook, read
   `GroupLootFrameN.rollID` and look up the verdict. This works on both clients with no client branch for
   the hook. It writes nothing into Blizzard's frame or tables.
2. **`hooksecurefunc` on a global that Blizzard calls by name.** `GroupLootContainer_OpenNewFrame(rollID,
   rollTime)` is looked up as a global from `GroupLootContainer_AddRoll` on both clients, so a post-hook
   fires after the frame is set up and shown, including for queued rolls. On Forever,
   `GroupLootFrame_SetupItemDisplay(self)` is also a by-name call and a clean hook.
3. **Do not** `hooksecurefunc("GroupLootFrame_OnShow", ...)`. The XML binds `<OnShow function="GroupLootFrame_OnShow"/>`
   (`L:` `:531`, `F:` `:475`). My reading is that the XML stores the function value at load, so replacing
   the global afterwards does not reach the frame's script. **INFERRED**; `HookScript` avoids the question.
4. **Do not** reposition, re-parent, or `SetScript` on the popups or their buttons, and do not add keys to
   Blizzard's frame tables. The container is managed by the alert/bottom layout
   (`GroupLootContainer_Update` calls `self.layoutParent:Layout()`, `F:` `:114-137`). Writing into it is the
   classic way to spread taint into the managed layout. Anchoring **to** it is read-only and safe.
5. Do not anchor in a way that makes Blizzard's frame depend on ours (never `GroupLootFrameN:SetPoint(..., ourFrame)`).
6. Forever gamepad mode uses different frames. Either skip the annotation when
   `InputUtil.IsGamepadUIEnabled()` is true, or hook the card initializer later. Low priority.

Combat: since none of these frames are protected, hooks and anchoring work in combat. A new overlay frame
should still be created at load, not first in combat, to stay simple. **INFERRED**.

## 11. Every difference found, Retail live vs Forever

| Area | Retail 12.1.5 (70783) | Forever 1.60.1 (70888) | Evidence | Tag |
|---|---|---|---|---|
| Drop key field | `lootListID` | `lootListKey` | `LootHistoryDocumentation.lua:66,102,113,151` both | MEASURED |
| C_LootHistory functions, events, flags | 5 / 5, AllowedWhenUntainted on 3 | identical | docs diff, Ketho | MEASURED |
| `LootDocumentation.lua` (START_LOOT_ROLL etc.) | — | byte-identical | `diff` exit 0 | MEASURED |
| Loot history frame auto-opens on GO_TO_ENCOUNTER | yes (unconditional `Show`) | no (`ShouldAutoOpen` → false) | `L:LootHistory.lua:342-344`; `F:Blizzard_FrameXML/Camelot/LootHistory.lua:2-4`, toc `:126` | MEASURED |
| Loot history gamepad / smart-nav | none | added (`LootHistoryExtraTooltip`, `SmartNavigation_*`) | `F:LootHistory.lua:14,30-43,628-664` | MEASURED |
| Roll popup template | `GroupLootFrameTemplate`, buttons on frame | `MKBGroupLootFrameTemplate`, buttons in `LootButtonContainer` | §10.1 | MEASURED |
| Gamepad roll list | none | `GamepadGroupLootRollFrame` | §10.1 | MEASURED |
| Master-loot assign menu | simple menu | adds a per-player assign menu for gamepad | `F:GroupLootFrame.lua:196-310` vs `L:` `:141-160` | MEASURED |
| Master loot quality threshold | `Constants.LootConsts.MasterLootQualityThreshold = 5` | doc name `LootConsts_Camelot` = 4; runtime dump shows `Constants.LootConsts.MasterLootQualityThreshold = 4` | `L:LootConstantsDocumentation.lua:47-54`; `F:LootConstants_MainlineDocumentation.lua:39-45`; `luaenum/live.lua:9378-9380`, `luaenum/forever.lua:9783-9784` | MEASURED / REPORTED |
| `Enum.LootRollType`, `Enum.LootRollDisabledReason` | not in docs or enum dump | present | `F:LootConstants_MainlineDocumentation.lua:5-36`; `luaenum/forever.lua:5552` | MEASURED / REPORTED |
| `Enum.LootMethod` | Freeforall 0 … Personal 5 | same | `LootConstantsDocumentation.lua:6-19` both | MEASURED |
| Roll chat strings | other players' lines have no link; self lines have View link | every line has `LH(encounterID)` prefix; no View link; transmog roll line added; off-spec self text = main-spec | §9 | MEASURED |
| `LOOT_HISTORY_INFO_TEXT` | "dungeons and raids" | "group content" | §6 | MEASURED |
| CHAT_MSG_LOOT / SYSTEM / WHISPER secret flags | none / lockdown / lockdown | same | §7 | MEASURED |

## 12. What this means for the design (**INFERRED**)

1. **Primary source: `C_LootHistory`**, on both clients. One Compat reader, `Compat.LootHistoryRolls(encounterID,
   key)`, returns `{ link, key, startTime, duration, allPassed, isTied, leader, winner, rolls = { {name, guid,
   classFile, isSelf, state, roll, isWinner}, ... } }`, plain fields only. Read `lootListID or lootListKey`.
   Extend today's `Compat.LootHistoryDrop` rather than add a second call path.
2. **Live updates:** register `LOOT_HISTORY_UPDATE_ENCOUNTER` (new drops) next to the existing
   `LOOT_HISTORY_UPDATE_DROP`. Re-read on every fire; diff against the stored copy; publish a bus message.
   Stop treating "no winner" as a refusal: today `noWinner` drops are refused
   (`modules/LootFeed.lua:1021`); the new feature needs them as "rolling" records.
3. **Final:** `winner` or `allPassed` set, or `startTime + duration` passed. Save the final roll table to
   History.
4. **`CLEAR_HISTORY`:** keep DropWatcher's own copy; only drop the live mapping.
5. **Chat fallback:** parse `LOOT_ROLL_*` lines only to fill gaps (for example a missed `UPDATE_DROP`) and
   to map `rollID` → encounterID at roll start. Build patterns from GlobalStrings per client.
6. **Own roll and popup verdict:** `START_LOOT_ROLL` → `GetLootRollItemLink` + `GetLootRollItemInfo` → verdict;
   annotate `GroupLootFrameN` by `HookScript` + anchored overlay (§10.2).
7. **Forever master loot:** rolls do not happen; there is no `rollInfos` to show. `DoMasterLootRoll` ("Request
   Roll") does exist on Forever (`F:GroupLootFrame.lua:204-206`); whether that path feeds `C_LootHistory` is
   unknown. Probe P9.
8. **Sim:** fake `GetSortedInfoForDrop` answers with `rollInfos`, fire `UPDATE_ENCOUNTER` once and
   `UPDATE_DROP` per step, per sibling note 03 §13.

## 13. Open probes (in game only)

- **P1 — when numbers appear.** In a group roll, run on each `UPDATE_DROP`:
  `/run local f=CreateFrame("Frame") f:RegisterEvent("LOOT_HISTORY_UPDATE_DROP") f:SetScript("OnEvent",function(_,_,e,k) local d=C_LootHistory.GetSortedInfoForDrop(e,k) for _,r in ipairs(d.rollInfos) do print(GetTime(),e,k,r.playerName,r.state,r.roll,r.isWinner) end print("leader",d.currentLeader and d.currentLeader.roll,"winner",d.winner and d.winner.playerName) end)`.
  Look for: does `roll` become non-nil when a player picks, or only on the final fire?
- **P2 — fire count.** Same frame. Count fires per drop versus the number of choices. Look for: one fire at
  start with all `NoRoll`; one per choice; one at close. Also note whether two choices in the same instant
  merge (UniqueEvent).
- **P3 — trash.** Roll on a trash drop, then `/dump C_LootHistory.GetAllEncounterInfos()`. Look for: the
  `encounterID` and `encounterName` used, and whether it equals any `ENCOUNTER_START` ID. Do it on both
  clients, and in the open world on Forever.
- **P4 — rollID vs key.** On `START_LOOT_ROLL`:
  `/run local f=CreateFrame("Frame") f:RegisterEvent("START_LOOT_ROLL") f:SetScript("OnEvent",function(_,_,id,t,h) print("roll",id,t,h,GetLootRollItemLink(id)) end)`
  and compare with the `k` printed by P1. Look for: equal or not; a stable relation.
- **P5 — names.** From P1 output, note `playerName` for a same-realm, a cross-realm and (Forever) a player
  with a surname. Look for: "Name" vs "Name-Realm", and anything odd on Forever.
- **P6 — secrets in an instance.** Inside a dungeon, during and after a boss:
  `/run local d=C_LootHistory.GetSortedDropsForEncounter((C_LootHistory.GetAllEncounterInfos()[1] or {}).encounterID or 0) print(d and #d, d and d[1] and issecretvalue(d[1].itemHyperlink), C_ChatInfo.InChatMessagingLockdown())`.
  Look for: any secret field; lockdown state on Forever.
- **P7 — chat event.** `/run local f=CreateFrame("Frame") for _,e in ipairs({"CHAT_MSG_LOOT","CHAT_MSG_SYSTEM"}) do f:RegisterEvent(e) end f:SetScript("OnEvent",function(_,e,t) if t:find("lootHistory") or t:find("Roll") or t:find("selected") then print(e,(t:gsub("|","||"))) end end)`.
  Look for: which event each roll line uses; the exact link payload (only encounterID, or more fields).
- **P8 — field name.** During a roll: `/dump C_LootHistory.GetSortedDropsForEncounter(<encounterID>)[1]`.
  Look for: `lootListID` (Retail) vs `lootListKey` (Forever) at run time.
- **P9 — master loot on Forever.** With master loot on, loot an Epic. As the master looter, use
  "Request Roll". Then `/dump C_LootHistory.GetAllEncounterInfos()` and P1/P7 output. Look for: whether
  anything lands in loot history, and which chat lines appear.
- **P10 — popup frames.** With a roll open: `/dump GroupLootFrame1.rollID, GroupLootFrame1:IsProtected(), GroupLootFrame1.LootButtonContainer ~= nil, GroupLootFrame1.NeedButton ~= nil`.
  Look for: not protected on both; button path as in §10.1.

## Skeptic corrections

Second-pass check, 2026-11-13. Same local sources as §1 (`wus-forever` 1.60.1.70888, `wus-live` 12.1.5.70783,
`ketho/*_enUS.lua`, `luaenum/*.lua`). Claims not listed here were re-checked and hold.

1. **§0 item 8 and §9: "every per-player roll line on Forever carries the link" is too broad.** REFUTED in part.
   Forever `LOOT_ROLL_DISENCHANT = "%s has selected Disenchant for: %s"` has no `|HlootHistory|h` prefix
   (`ketho/forever_enUS.lua:13903`). The same is true of `LOOT_ROLL_ROLLED_DE`, `LOOT_ROLL_ROLLED_NEED_ROLE_BONUS`
   and `LOOT_ROLL_PASSED_AUTO(_FEMALE)` (`:13923`, `:13926`, `:13919-13920`). MEASURED. The §9 table lists the
   last three but leaves out `LOOT_ROLL_DISENCHANT`. A pattern builder must not assume the prefix on Forever.
   (Whether Forever ever offers Disenchant rolls is UNKNOWN; the string exists.)
2. **§9: not every Retail self line has the trailing "[View Loot Rolls]" link.** Retail `LOOT_ROLL_DISENCHANT_SELF`
   and `LOOT_ROLL_LOST_ROLL` have one `%d` only (`ketho/live_enUS.lua:13415`, `:13425`). MEASURED. The ones with
   the second link are NEED_SELF, NEED_SELF_OFF_SPEC, GREED_SELF, PASSED_SELF, PASSED_SELF_AUTO (`:13417`,
   `:13427-13428`, `:13432-13433`).
3. **§9: the trailing link text is wrapped in a colour code.** The exact Retail suffix is
   `|HlootHistory:%d|h|cnLOOT_LINK_COLOR:[View Loot Rolls]|r|h` (`ketho/live_enUS.lua:13417`). MEASURED. The
   note's shorthand drops `|cnLOOT_LINK_COLOR:` and `|r`. Patterns built from the GlobalString handle this for
   free; hand-written ones would not.
4. **§3 and §0 item 4: UPDATE_DROP is not the only refresh path, and there is per-frame polling.**
   - `LOOT_HISTORY_ONE_HUNDRED_ROLL` also triggers `DoFullRefresh()`, which re-reads every drop
     (`F:Blizzard_FrameXML/Mainline/LootHistory.lua:381-387`; `L:` same file `:357-363`). MEASURED.
   - While the timer runs, `UpdateTimer` calls `C_LootHistory.GetSortedDropsForEncounter` on every frame
     (`F:...LootHistory.lua:494-506`). It reads `winner` / `allPassed` to stop the bar. So "there is no polling of
     roll data" is wrong: Blizzard polls drop completion state each frame, though it does not redraw rows from
     it. MEASURED. This also shows a per-frame read of the drops list is something Blizzard itself does.
     INFERRED that a throttled poll is an acceptable fallback if UPDATE_DROP proves unreliable (probe P2).
5. **§2.3 table, "Blizzard listens" for UPDATE_DROP: the frame-level listener differs by client.** On Forever the
   history frame registers `LOOT_HISTORY_UPDATE_DROP` on itself while shown (`F:...LootHistory.lua:328`) and
   unregisters it on hide (`:622-626`), but `LootHistoryFrameMixin:OnEvent` has no branch for it (`:363-389`), so it
   is a no-op there. On Retail the frame does not register it at all (no such line in `L:...LootHistory.lua`,
   see the `diff`). Only the row elements act on it, on both clients (`:209-215`, `:17-25`). MEASURED. No
   effect on DropWatcher's design.
6. **§10.2 item 1: an OnShow hook can fire for a popup that closes at once.** Both clients' `GroupLootFrame_OnShow`
   remove the frame again when `GetLootRollItemInfo(self.rollID)` returns no name (`L:Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua:162-166`;
   `F:` same file `:312-320` and `:371-378`, where in gamepad mode the frame is not removed). MEASURED. The overlay's
   OnShow hook runs after Blizzard's handler, so it should re-check `frame:IsShown()` and a non-nil `rollID`
   before drawing. INFERRED.
7. **§6 / claim on the `|HlootHistory:%d|h` link payload.** Upheld, with a nuance: Blizzard's handler reads the
   first `:`-separated field as the encounterID (`ItemRefHandlers.lua:99-102`, both). That proves how Blizzard
   interprets it, not that the server never adds more fields. The GlobalStrings show one `%d` per link
   (`ketho/*_enUS.lua`, §9), so one field. MEASURED. Probe P7 still confirms the runtime text.

Re-checked and upheld (MEASURED unless noted): key-field rename (`LootHistoryDocumentation.lua:66,102,113,151`, diff
shows only those 4 lines differ); NoRoll/Pass rows in `rollInfos` (`F:LootHistory.lua:68-105`); `currentLeader.roll`
shown while pending, also when tied (`:150-158`); UniqueEvent/SynchronousEvent flags (`LootHistoryDocumentation.lua:79-120`);
win-protection skip (`:77-78`); only `SecretArguments = "AllowedWhenUntainted"` on 3 getters, identical on both;
`CHAT_MSG_LOOT` only `SynchronousEvent`, `CHAT_MSG_SYSTEM`/`WHISPER` `SecretInChatMessagingLockdown`
(`ChatInfoDocumentation.lua`, F:1816, L:1789); `LootDocumentation.lua` identical (same md5); no rollID→history API
(Ketho GlobalAPI lists only the 5 `C_LootHistory` functions plus legacy roll globals, none take or return both);
`GroupLootFrame.xml` has no `protected`/`Secure` on either client, button paths as stated (`L:` `:371-413`, `F:` `:484-538`);
Forever gamepad routing (`F:Blizzard_Game/Mainline/EventImplementation.lua:385-391`, `GroupLootFrame.lua:1047`,
`:1206-1220`); Camelot `ShouldAutoOpen` false (`F:Blizzard_FrameXML/Camelot/LootHistory.lua:2-4`, toc `:126`);
threshold 4 vs 5 (`F:LootConstants_MainlineDocumentation.lua:43`, `L:LootConstantsDocumentation.lua:52`,
`luaenum/forever.lua:9783-9784`, `luaenum/live.lua:9378-9379`; Blizzard reads `Constants.LootConsts.MasterLootQualityThreshold`
at `F:GroupLootFrame.lua:988`, `L:` `:790`); `Enum.LootRollType` in Forever docs and enum only. Trash encounterID:
still UNKNOWN; nothing in either source tree documents it.
