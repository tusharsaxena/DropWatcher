# Research report: designing a Retail loot-tracking addon (Midnight 12.x)

The facts marked **[docs]** come from Blizzard's own generated API documentation, which I read from a sparse clone of `Gethe/wow-ui-source` at build **12.1.0 (69933), dated 2026-09-22**. Nothing else here outranks that source. warcraft.wiki.gg already lists 12.1.5 as the current standard build, so re-check against 12.1.5 before you rely on anything. I only wrote files to the scratchpad: clones of DoYouNeedThat, Do You Need It?, RCLootCouncil2, Pawn and the UI docs.

---

## 1. DoYouNeedThat (DYNT): the reference design

- **CurseForge:** https://www.curseforge.com/wow/addons/doyouneedthat
  - Author Kraffs/Morfin. Last release 1.1.7 on 2020-11-23, Interface 90002. About 26k downloads. **It has been abandoned since Shadowlands.**
- **Source:** https://github.com/kraffslol/DoYouNeedThat
  - The licence is custom, linked from CurseForge.
  - It is small: `Core.lua` 379 lines, `Frame.lua` 478, `Util.lua` 247.
  - Libraries: LibStub, CallbackHandler, **LibInspect**, LibDataBroker and LibDBIcon. It does not use Ace3.

### How it works (from the source)
- **When it listens.** It registers `CHAT_MSG_LOOT` and `BOSS_KILL` only inside instances, switching them on and off in `PLAYER_ENTERING_WORLD` by checking `GetInstanceInfo()` for an instance type of `none`.
- **Loot parsing.** It turns `LOOT_ITEM` into a pattern with `gsub(LOOT_ITEM, '%%s', '(.+)')` and matches each message to get the item link. The looter's name comes from the fifth argument of the event.
- **Filter.** The filter asks one question: is this item useful to *me*?
  - The item must pass `IsEquippableItem`, be armour or a weapon, be rare or epic (legendaries excluded), and pass `IsEquippableForClass`, a hard-coded class-to-armour/weapon table in `Util.ValidGear`.
  - It must also pass `DoesItemContainSpec(item, playerClassId)`.
  - The item's ilvl must be at least my equipped ilvl in that slot minus `minDelta`, a 0–30 slider. Rings, trinkets and one-hand weapons are checked against both slots.
- **Tradeability: none.** It never checks whether the looter can actually trade the item. Its TODO list also mentions "Pawn support", `ENCOUNTER_LOOT_RECEIVED` and version checking, none of which were built.
- **Looter equipment.**
  - A 7-second `C_Timer.NewTicker` walks `raidN`/`partyN` one unit per tick, skipping anyone who is offline, cannot be inspected, or when I am in combat (`InCombatLockdown`).
  - It calls `LibInspect:RequestData("items", unit)` and caches the result by GUID for 600 seconds.
  - Each row shows the looter's item in the same slot, or both items for rings and trinkets.
- **Whisper.** One template, `"Do you need [item]?"`, where `[item]` is replaced by the link and sent with `SendChatMessage(msg,"WHISPER",nil,looter)`. The button hides itself after one use.
- **No addon comms at all.**
- **Window behaviour.**
  - The window opens after `BOSS_KILL`, except in M+ (difficulty 8).
  - The list is cleared on each boss kill.
  - It has a `/dynt`, `/dynt clear`, `/dynt test <link>` and `/dynt debug` command, a keybinding, and a LibDBIcon minimap button. Right-clicking the minimap button locks it.

### Look and feel (`Frame.lua`)
- **Window.** 380×200, frame strata DIALOG, clamped to the screen, movable by its header. The position is saved as `{point,x,y}`.
- **Theme.** A flat dark theme drawn with `WHITE8x8` backdrops and a 1px black border:
  - window background `.1,.1,.1,.8`
  - header `.1,.1,.1,1`, 24px tall
  - title text "DoYouNeedThat" in `#FF6B6B`
- **Font.** The bundled **Roboto-Medium.ttf**, in three sizes: 14 for the title, 12 for buttons and headers, 11 for rows. All text has a 1,-1 black shadow.
- **Header buttons.**
  - Minimize `-`/`+`: light grey `.219`, hover `.27`. It collapses the window to 380×24 and hides the table.
  - Close `x`: red `.6,.1,.1,.6`, hover alpha 1.
- **Table.** Column headers sit above the table at x offsets: Item 10, ILvl 50, Looter 90, Looter Eq 175.
  - The table is inset 10px left, 50px from the top, 30px right and 10px from the bottom.
  - It uses a plain `ScrollFrame` with a skinned `UIPanelScrollBarTemplate` slider that is 16px wide.
- **Rows.** 20 rows are pooled and created up front. Each row is 24px tall, overlaps the next by 2px, and has a white backdrop at 0.1 alpha.
  - Item icon: 20×20, `SetTexCoord(.08,.92,.08,.92)`, border tinted to the item's quality colour.
  - ilvl text, then the looter's name in class colour.
  - One or two 20×20 icons for the looter's equipped gear.
  - A blue "Whisper" button (45×20, colour `0,.55,.85,.6`) and a red "x" button (25×20) on the right.
  - Rows are sorted by ilvl, highest first.
  - The icons are proper item buttons: hovering shows the item tooltip, shift-click links the item, ctrl-click opens dress-up.

---

## 2. Comparable and current addons

**Do You Need It? (DYNI)** is the closest modern equivalent and already targets Midnight.
- Pages: https://www.curseforge.com/wow/addons/do-you-need-it and https://github.com/Antrakt92/Do-You-Need-It-
- Author antrakt92. Version 0.6.3, 2026-10-04, Interface 120100 and 120105. About 9k lines of Lua with a headless test harness.
- **Licence warning.** The "Antrakt Attribution and CurseForge Rewards License 1.2" requires credit and *reward sharing* for "substantial reuse", which it defines as adapting the implementation of a meaningful user-facing feature. **Borrow its ideas, not its code.**
- **What is worth borrowing:**
  - **Trade status per row: Yes / Likely / Unknown / No.**
    - "Yes" when a trade timer was detected.
    - "Likely" for BoE gear, or BoP gear that is no higher ilvl than the looter's inspected item in that slot.
    - "No" for warbound or account-bound items, or an explicit restriction.
  - **Two loot sources, de-duplicated.** It listens to both `ENCOUNTER_LOOT_RECEIVED` and `CHAT_MSG_LOOT`, keeps "the most detailed item variant", and covers bonus-roll patterns (`LOOT_ITEM_BONUS_ROLL[_SELF]`) and the `_MULTIPLE` variants.
  - **Inspect handling.**
    - A `/dyni scan` command to scan the group's gear before a pull.
    - Inspect requests are parked during combat and resumed on `PLAYER_REGEN_ENABLED`.
    - Out-of-range checks use `CheckInteractDistance(unit,1)`; a failed range check does not spend a retry.
    - It inspects one unit at a time, with a 0.8s retry and a 2.5s scan timeout.
    - Cached results are labelled "Cached:".
  - **Whispers.**
    - Optional auto-whisper, off by default, with a 3–30s delay. It is cancelled if the looter leaves the group.
    - Sends are paced with one in flight at a time, and the send runs on a clean stack through `C_Timer.After(0)`.
    - The send is wrapped in `pcall(C_ChatInfo.SendChatMessage,…)` so a protected failure leaves the Ask button retryable.
    - Sub-second repeats are treated as throttled.
  - **History and UX.** Loot history keeps 50 session drops and the last 10 boss or run groups. There is a "New loot" button that avoids scroll jumps, Escape closes the window, `/dyni test` shows demo rows, and a self-test diagnostics report.
  - **Secret-value safety.** Every value goes through an `issecretvalue`/`pcall` guard (`CleanString`, `CleanNumber`).

**RCLootCouncil**
- Pages: https://www.curseforge.com/wow/addons/rclootcouncil and https://github.com/evil-morfar/RCLootCouncil2
- Version 3.23.3, 2026-08-31.
- Its features:
  - council voting
  - configurable response buttons
  - notes to the council
  - loot history with export
  - trading as automatic as a click allows once in range
  - a whisper fallback for players without the addon
- Two pieces of code are good models:
  - `core.lua:1445 GetContainerItemTradeTimeRemaining` reads the trade time off the tooltip.
    - It returns `math.huge` for an unbound item, seconds left inside the trade window, or 0 once bound.
    - It builds a pattern from `BIND_TRADE_TIME_REMAINING` and decodes "1 hour 59 min" using `INT_SPELL_DURATION_HOURS/MIN/SEC` and `TIME_UNIT_DELIMITER`. This was tested across all 11 client languages.
  - `Classes/Services/CommsRestrictions.lua` handles the comms restrictions (see §4).

**Loothing**
- Page: https://www.curseforge.com/wow/addons/loothing (version 2.1.0, 2026-10-09, Midnight only).
- A loot council that detects tradeable items after a kill and tracks the trade timers.
- Clicking the winner starts the trade.
- Loot history with CSV/TSV import and export and guild sync.
- Players without the addon can whisper `!need`/`!greed`/`!pass`.
- "Messages queue during boss fights and replay after."

**Personal Loot Helper (PLH)**
- Page: https://www.curseforge.com/wow/addons/personal-loot-helper (version 2.47, 2026-09-05, GPLv3).
- The looter chooses Keep or Offer.
- Other PLH users answer Main spec / Off spec / Transmog / Pass. PLH runs a roll and shows each requester's ilvl difference.
- A whisper button for players without PLH, limited to one whisper per item.

**LootPlanner**
- Page: https://www.curseforge.com/wow/addons/lootplanner (version 12.1.0, 2026-08-20).
- A wishlist per slot, drawn from loot tables.
- Imports a SimC string or **Droptimizer results**. The Droptimizer import is labelled experimental.
- Shows a popup of wishlisted items when you enter an instance, and tooltip notes for "drops from" and "on wishlist".

**Others seen but not studied:** Personal Loot Trader, Loot Whisperer (very new, about 30 downloads) and Transmog Loot Helper (Alt-click to whisper for transmog).

### Feature ideas worth borrowing (ranked)
1. **An honest trade status per row** (Yes / Likely / Unknown / No), plus a countdown for my own tradeable items read from the tooltip.
2. **An upgrade signal from more than ilvl:**
   - Pawn's upgrade arrow or percentage (§3e)
   - the upgrade track and rank of the drop against mine ("Hero 2/6 vs your Champion 6/6")
   - tier set awareness
   - an optional BiS or wishlist match from a SimC or Droptimizer import, LootPlanner-style
3. **Whispers.**
   - A whisper button with several templates using `{item}`, `{ilvl}` and `{slot}` tokens.
   - A one-whisper-per-item guard.
   - Optional delayed auto-whisper that waits for the restriction to lift.
4. **History.** Loot history grouped by encounter or key, with "who got what" and the outcome (asked / received / declined).
5. **Self-loot.** For my own tradeable drops, an "Offer" helper: it posts to group chat after the encounter, or shows which group members could use the item.
6. **Before the pull.** A group gear scan, plus a "Cached" age label on gear data.
7. **Edge cases.** Hide warbound and account-bound items, and catalyst-eligible items (vault and catalyst awareness).

---

## 3. WoW API facts (Midnight 12.x)

### 3a. Restrictions: the critical part
- **The restriction types [docs].** `Enum.AddOnRestrictionType` has six values:
  - `Combat` (0)
  - `Encounter` (1)
  - `ChallengeMode` (2): an active, incomplete keystone
  - `PvPMatch` (3)
  - `Map` (4)
  - `Chat` (5)
- **API and event [docs].**
  - `C_RestrictedActions.IsAddOnRestrictionActive(type)` and `GetAddOnRestrictionState`.
  - The event `ADDON_RESTRICTION_STATE_CHANGED(type, state)`, where state is Inactive, Activating or Active.
  - It fires "the immediate moment before a restriction activates, or after it deactivates" (wiki, Dec 8).
- **Chat lockdown [docs].** `C_ChatInfo.InChatMessagingLockdown()` returns true while the chat-messaging restrictions are in effect. The definition of the `SecretInChatMessagingLockdown` predicate:
  > "Guarded APIs and events produce secret values when encounter, challenge mode, or PvP match addon restrictions are in effect, and when the player is on a communication-restricted map such as a dungeon or raid."
- **`CHAT_MSG_LOOT` is NOT flagged `SecretInChatMessagingLockdown` [docs].** It is in the readable set, along with:
  - `CHAT_MSG_ADDON`, `CHAT_MSG_CURRENCY`, `CHAT_MSG_MONEY`, `CHAT_MSG_GUILD_ITEM_LOOTED`, `CHAT_MSG_ACHIEVEMENT`
  - the `CHAT_MSG_COMBAT_*` events and a few others
- **Events that ARE secret in lockdown [docs].** These include:
  - `CHAT_MSG_WHISPER`, `CHAT_MSG_WHISPER_INFORM`, the BN whispers
  - `CHAT_MSG_PARTY`, `CHAT_MSG_RAID`, `CHAT_MSG_INSTANCE_CHAT`
  - `CHAT_MSG_SYSTEM` (so the roll text is secret)
  - `CHAT_MSG_SAY`, `CHAT_MSG_GUILD`
  - `GetChatLineText`, `GetChatLineSenderName` and `GetChatLineSenderGUID`
  - So you **cannot read whisper replies** in a dungeon or raid.
- **The blanket in-instance ban was relaxed.** The 12.0 alpha secreted all chat and blocked comms throughout instances. The Oct 11 alpha narrowed this to "an active keystone run, an active PvP match, or an encounter in progress". In the Dec 10 beta, loot-type chat events such as `GUILD_ITEM_LOOTED` were made non-secret because they "are not exploit risks". (Wiki: https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes)
- **The fields of `CHAT_MSG_LOOT` [docs].**
  - `text`, `playerName`, `playerName2`, `guid` and `bnSenderID` carry no NeverSecret flag. All the other fields are NeverSecret.
  - Since the event itself is not lockdown-secret, the text should be readable.
- **⚠ Uncertain: one conflicting source.** The Loot Pro addon's 12.0 changelog says loot chat is hidden during M+, boss fights and rated PvP (https://www.wowinterface.com/downloads/info27123-LootPro.html). That contradicts the 12.1.0 docs; it may describe an earlier beta.
  - **Mitigation:** guard every payload with `issecretvalue()`, and also listen to `ENCOUNTER_LOOT_RECEIVED`.
  - Test with the CVar `addonChatRestrictionsForced 1`, which forces lockdown and does not persist across restarts.
- **Unit identity [docs].** `UnitGUID` and `UnitClass` are `SecretWhenUnitIdentityRestricted`, which applies only when "the unit isn't player-controlled or in the party/raid". So **party and raid members' names, GUIDs and classes stay readable.** In instances, creature names, GUIDs and IDs are secret.
- **Combat log.** `COMBAT_LOG_EVENT_UNFILTERED` is no longer available to addons (wiki, Oct 1). Loot tracking does not need it.

### 3b. Loot detection
- **`CHAT_MSG_LOOT`:** `text, playerName, …, guid` [docs].
  - Build the patterns from the globals: `LOOT_ITEM` ("%s receives loot: %s."), `LOOT_ITEM_SELF`, `LOOT_ITEM_MULTIPLE`, `LOOT_ITEM_SELF_MULTIPLE`, `LOOT_ITEM_BONUS_ROLL`, `LOOT_ITEM_BONUS_ROLL_SELF`, and `LOOT_ITEM_PUSHED*`.
  - Escape the magic characters and replace `%s`/`%d` with captures. Cross-realm names include `-Realm`.
- **`ENCOUNTER_LOOT_RECEIVED`** [docs] has a payload of `encounterID, itemID, itemLink, quantity, itemName, fileName`.
  - In practice, argument 5 is the **player's name** (a short name without realm) and argument 6 is the **class file name**. DYNI handles it that way.
  - Same-name looters can be ambiguous, so disambiguate by class.
- **`C_LootHistory`** [docs] belongs to the group-loot (Need/Greed) system:
  - `GetAllEncounterInfos`, `GetSortedDropsForEncounter(encounterID)` and `GetSortedInfoForDrop(encounterID, lootListID)`.
  - `EncounterLootDropInfo` contains `itemHyperlink`, `winner {playerName, playerGUID, playerClass, isSelf, state, roll}` and `rollInfos`.
  - Events: `LOOT_HISTORY_UPDATE_DROP` and `LOOT_HISTORY_UPDATE_ENCOUNTER`.
  - Use it to get winners for **group-loot** drops. Personal loot never appears here.
- **Other events:** `START_LOOT_ROLL`, `CHALLENGE_MODE_COMPLETED` (the M+ end-of-run loot; the ChallengeMode restriction clears on completion), and `ENCOUNTER_START`/`ENCOUNTER_END`.

### 3c. Inspect
- **`NotifyInspect(unit)` [docs].**
  - No restriction predicate other than `AllowedWhenUntainted`.
  - Gate it with `CanInspect(unit)` and `CheckInteractDistance(unit,1)`.
  - The server silently throttles: no event and no error ("Patch 3.3.5" note at https://warcraft.wiki.gg/wiki/API_NotifyInspect). Queue one request at a time and time out after about 1–2.5s.
- **Reading the result.**
  - `INSPECT_READY(inspecteeGUID)` [docs] fires when the data is ready.
  - Then read `GetInventoryItemLink(unit, slot)` for slots 1–17.
  - Call `ClearInspectPlayer()` when done.
  - Links can arrive incomplete. Retry, or wait for the item data to load with `Item:ContinueOnItemLoad`.
- **Other inspect calls.** `C_PaperDollInfo.GetInspectItemLevel(unit)` [docs] and `GetInspectSpecialization(unit)`, which is `SecretWhenUnitIdentityRestricted` [docs] and so fine for group members.
- **Common practice is to avoid inspecting in combat**, as both DYNT and DYNI do.
- **Pitfall:** never call `NotifyInspect` while the player's Inspect frame is open. That is general knowledge, not something I verified here.

### 3d. Tradeability
- **Tooltip line types [docs].** `Enum.TooltipDataLineType` includes `TradeTimeRemaining = 36`, `ItemBinding = 20` and `ItemUpgradeLevel = 32`.
  - On your *own* bag item, `C_TooltipInfo.GetBagItem(bag, slot)` can be scanned by line type rather than by localised text.
  - The text fallback is the global `BIND_TRADE_TIME_REMAINING`: "You may trade this item with players that were also eligible to loot this item for the next %s (including time offline)." Use RCLootCouncil's localised duration decoder (above).
- **⚠ The trade timer cannot be seen on someone else's loot.** It belongs to the item instance in the looter's bags. A hyperlink tooltip of their drop will not show it.
  - So for other people's drops, tradeability can only be *estimated*. That is exactly why DYNI reports "Likely" and "Unknown".
  - Only addon comms from the looter's own client could confirm it, and comms are blocked during encounters.
- **Account and warband binding [docs].** `C_Item.IsItemBindToAccount(link)`, which is new in 12.0, and `C_Item.IsItemBindToAccountUntilEquip(link)`. Both work on hyperlinks, so they work on other people's loot.
  - `C_Item.IsBound(itemLocation)` and `IsBoundToAccountUntilEquip(itemLocation)` need an `ItemLocation`, so they only work on your own items.
  - Warbound items cannot be traded to other players.
- **The ilvl rule (for the looter):**
  - Under personal loot, the *looter* can trade a BoP drop to other group members who were eligible for the same loot, within **2 hours**, only if it is **not an ilvl upgrade for the looter**: equal or lower ilvl than what they own in that slot.
  - Community sources say the comparison is against items the looter **owns**, equipped or possibly in bags. One forum report says the comparison is by item type rather than strict slot. **Unconfirmed.**
  - Sources: https://warcraft.wiki.gg/wiki/Personal_loot, https://blog.askmrrobot.com/?p=18927, https://us.forums.blizzard.com/en/wow/t/personal-loot-trading-restrictions/1155299
- **⚠ The raid loot mode in Midnight is uncertain.**
  - In Dragonflight, raids used Group Loot only, and "While inside a raid, all item level restrictions placed on trading between members of that group are removed entirely" (Blizzard via BlizzardWatch, 2022-09-29, https://blizzardwatch.com/?p=159754).
  - One boosting-site guide says Midnight Season 2's raid (The Venomous Abyss) "uses personal loot" with the ilvl rule (https://koroboost.com/guide/midnight-raid-loot-guide). That is low reliability.
  - Patch 12.0.1 put all instances up to and including Dragonflight into "Legacy Loot Mode".
  - **Treat the raid rules as needing in-game verification.** Design the trade logic to be data-driven by content type.

### 3e. Item level, upgrade tracks, equippability
- **Item level.**
  - `C_Item.GetDetailedItemLevelInfo(link)` returns `actualItemLevel, previewLevel, sparseItemLevel` [docs].
  - `C_Item.GetCurrentItemLevel(itemLocation)` for your own items.
- **Upgrade tracks [docs].** **`C_Item.GetItemUpgradeInfo(itemInfo)`** takes a link and returns `{currentLevel, maxLevel, maxItemLevel, trackString, trackStringID}`.
  - This is a clean, non-tooltip way to get "Hero 3/6". I am not sure which patch added it; it is present in the 12.1.0 docs.
  - The fallback is the tooltip line of type `ItemUpgradeLevel`, or the localised `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING`.
  - The 12.1.0 docs also list `C_Item.DoesItemMatchTrackJump(itemLoc)`.
- **Track item levels.** Each track has 6 ranks, overlapping by 2 ranks with the next track.
  - **Midnight Season 1** (2026-03-17 to 2026-08-11, Dawncrests):
    - Adventurer 220–237
    - Veteran 233–250
    - Champion 246–263
    - Hero 259–276
    - Myth 272–289
    - There is no "Explorer" track. https://warcraft.wiki.gg/wiki/Season_41
  - **Midnight Season 2 (current, since 2026-08-18, Mistcrests, patch 12.1.0):**
    - Adventurer 266–282
    - Veteran 279–295
    - Champion 292–308
    - Hero 305–321
    - Myth 318–334
    - Raid: The Venomous Abyss, 8 bosses. Tier 36 tokens by armour type: Woven, Cured, Cast, Forged. https://warcraft.wiki.gg/wiki/Season_42
  - **Don't hard-code the numbers.** Use `GetItemUpgradeInfo().trackString`.
- **Equippability [docs].**
  - `C_Item.GetItemInfo` returns `classID`/`subclassID`, `equipLoc`, `bindType` and `setID` (16th), plus a new 18th return, `itemDescription`.
  - `C_Item.GetItemInfoInstant` works synchronously.
  - `C_Item.IsEquippableItem`.
  - `C_Item.DoesItemContainSpec(item, classID, specID=0)`.
  - `C_Item.GetItemSpecInfo(item)` returns the list of specIDs. Use it to filter wrong-primary-stat gear for a spec.
  - `C_Item.IsItemSpecificToPlayerClass(item)`, useful for tier tokens.
  - `C_Item.GetSetBonusesForSpecializationByItemID` and `GetItemStats`/`GetItemStatDelta`.
  - Armour type per class and weapon proficiencies still need a lookup table, as DYNT's `ValidGear` does. Keep cloak, neck, ring and trinket universal.
- **Tier tokens.** Their item class is Miscellaneous, not armour. Detect them by spec info or a "Classes:" restriction, and give them their own handling. (From general knowledge; verify in game.)

### 3f. Pawn integration
- **Source:** https://github.com/VgerMods/Pawn (version 2.13.17, Interface 120100).
- **Licence:** CC BY-NC-ND. Call its API; do not copy its code.
- **`PawnShouldItemLinkHaveUpgradeArrow(link, checkLevel)`** is the officially recommended call for third-party addons, as described in `PawnBags.lua`.
  - It returns true, false, or **nil**, meaning "not known yet, or over budget; retry on a timer".
  - It is wrapped in a CPU budget throttle.
- **`PawnIsItemAnUpgrade(PawnGetItemData(link))`** gives the details. It returns `UpgradeInfo` as a list of `{ScaleName, LocalizedScaleName, PercentUpgrade, ExistingItemLink}`, plus `ItemLevelIncrease`, `BestItemFor`, `SecondBestItemFor` and `NeedsEnhancements`.
- **`PawnIsItemDefinitivelyAnUpgrade(link, checkLevel)`** returns true, false or nil.
- **Other calls:**
  - `PawnGetSingleValueFromItem(item, scaleName)`
  - `PawnGetItemValue(...)`
  - `PawnGetAllScalesEx()`, which returns `{Name, LocalizedName, Header, IsVisible, IsProvider}`
  - `PawnIsScaleVisible(name)`, true for the active scale or scales of the current character
  - `PawnFindScaleForSpec(classID, specID)`
  - `PawnRegisterThirdPartyBag(name, {RefreshAll=fn})` notifies you when settings change
- **Raw scales** are in `PawnCommon.Scales[name]`; `.PerCharacterOptions[PawnPlayerFullName].Visible` marks the active one.
- **Guards.**
  - Check `PawnIsInitialized` before calling.
  - Pawn compares against *my* gear only, so it cannot evaluate the looter's gear.

---

## 4. Messaging in Midnight
- **`C_ChatInfo.SendAddonMessage` [docs].**
  - Returns `Enum.SendAddonMessageResult`, which includes **`AddOnMessageLockdown` (11)**, `AddonMessageThrottle` (3) and `ChannelThrottle` (8).
  - Prefix at most 16 characters, message at most 255.
  - Per-prefix allowance of 10 messages, refilling at 1 per second. Whispers outside instances are exempt from that limit.
  - Using AceComm or ChatThrottleLib is recommended. (https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage)
- **In practice:** comms are blocked during an active `Encounter` or `ChallengeMode` restriction.
  - RCLootCouncil treats bits 1–2 (Encounter and ChallengeMode) of `ADDON_RESTRICTION_STATE_CHANGED` as "restricted". It drops non-essential messages and queues "guaranteed" ones until the restriction lifts.
  - Its code comment: "Combat seems to be the exception… comms still work when [Map] is enabled in instances."
  - Its changelog: "you can no longer do anything that results in sending addon messages during boss encounters."
  - Loothing does the same.
  - The wiki mentions Club-API comms workarounds being closed before 12.0.1.
- **`C_ChatInfo.SendChatMessage` [docs]** is flagged `HasRestrictions` and `RestrictedForMacroChatMessages`, which "Restricts sending chat messages on chat types that can be observed by external players. Only applies during instance encounters for messages initiated from macros."
  - Community reports say that during encounters, macros can whisper only targets inside the same instance (https://www.mmo-champion.com/threads/2667054-Midnight-Macro-Changes-Now-Live-Target-Markers-and-Chat-Messages).
  - The WhisperPeople and Whisper Messenger addons say addon-sent chat is blocked or unreliable during M+ and boss fights. DYNI wraps the send in `pcall` and keeps it retryable.
  - **⚠ Whether an addon's whisper on a button click succeeds mid-encounter is unconfirmed.**
- **Recommendation for the design:**
  - Defer all whispers and comms until `ENCOUNTER_END` or `CHALLENGE_MODE_COMPLETED`, or until the restriction state goes Inactive.
  - Enable the Whisper button only when `InChatMessagingLockdown()` is false and the Encounter and ChallengeMode restrictions are inactive. Otherwise queue it.
  - Always `pcall` the send.
  - Expect replies to be unreadable while in a dungeon or raid, because `CHAT_MSG_WHISPER` is lockdown-secret.

---

## Key uncertainties to verify in game
1. Is `CHAT_MSG_LOOT` text readable during an active encounter or key? The docs say yes; Loot Pro says no. Test with `addonChatRestrictionsForced`.
2. Does an addon whisper sent from a hardware click succeed during an encounter?
3. What are the raid loot mode and ilvl-trade rule in Midnight Season 2: personal loot with the rule, or group loot without it?
4. Does the trade ilvl comparison use equipped items only, or bags too? Is it per slot or per item type?
5. In which patch did `C_Item.GetItemUpgradeInfo` arrive, and does it work on another player's loot link?

## Main sources
- Blizzard API docs: https://github.com/Gethe/wow-ui-source (`Blizzard_APIDocumentationGenerated`: ChatInfo, ChatConstants, RestrictedActionsConstants, SecretPredicates, Item, LootHistory, Loot, PaperDollInfo, TooltipInfoShared)
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/Planned_API_changes
- https://warcraft.wiki.gg/wiki/Patch_12.0.0/API_changes
- https://warcraft.wiki.gg/wiki/CHAT_MSG_LOOT
- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendAddonMessage
- https://warcraft.wiki.gg/wiki/API_C_ChatInfo.SendChatMessage
- https://warcraft.wiki.gg/wiki/API_NotifyInspect
- https://warcraft.wiki.gg/wiki/Season_41
- https://warcraft.wiki.gg/wiki/Season_42
- https://warcraft.wiki.gg/wiki/Personal_loot
- https://github.com/kraffslol/DoYouNeedThat
- https://github.com/Antrakt92/Do-You-Need-It-
- https://github.com/evil-morfar/RCLootCouncil2
- https://github.com/VgerMods/Pawn
- https://www.curseforge.com/wow/addons/loothing
- https://www.curseforge.com/wow/addons/personal-loot-helper
- https://www.curseforge.com/wow/addons/lootplanner
- https://blizzardwatch.com/?p=159754
- https://www.icy-veins.com/wow/news/combat-addon-restrictions-eased-in-midnight/
- https://www.wowinterface.com/downloads/info27123-LootPro.html
