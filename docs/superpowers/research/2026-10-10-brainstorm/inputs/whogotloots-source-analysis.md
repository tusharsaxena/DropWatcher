# WhoGotLoots v1.8.2: analysis report (read-only; nothing was modified)

Path: `/mnt/g/Games/Blizzard/World of Warcraft/_retail_/Interface/AddOns/WhoGotLoots`. The TOC declares `## Interface: 120007` (Midnight), `## Version: 1.8.2` and `## SavedVariables: WhoGotLootsSavedData`. I read every Lua file in full. For the XML I read only the template and font names, and I skimmed the middle of UIBuilder.lua (the stat-chip layout helpers at lines 1070-1250).

## 4. Code organization, size, libraries (first, for orientation)

The addon uses **no libraries**: no LibStub, Ace3, LibDataBroker or minimap icon. It is plain globals and `CreateFrame`. The TOC loads files in this order:

| File | Lines | Role |
|---|---|---|
| Art/Fonts.xml | 46 | 11 virtual fonts (`WGLFont_*`), bundled OpenSans and HK Grotesk TTFs |
| Art/UIElements.xml | 350 | Virtual templates `WGLCheckBoxTemplate`, `WGLCloseBtn`, `WGLGeneralButton`, `WGLInfoBtn`, `LoadingIcon` (generic global name), `WGLOptionsBtn`, `WGLSlider` |
| ItemsDB.lua | 582 | `WGLItemsDB.IsAppropriate`; class→spec-ID map `class_specs`; `ClassAndGearDB` (armor type and weapon subclass per class/spec, three-valued true/false/nil) |
| util.lua | 167 | `WGLU`: main stat, name→unit resolution, lerp/clamp, debug print, quality text |
| ItemComparison.lua | 716 | `WGLItemComparison`: slot replacement plans, stat reads, upgrade-track parse, uniqueness, local comparison builder |
| UIBuilder.lua | 1359 | `WGLUIBuilder`: main header frame, message editors, text formatters, stat "chips", 9-slice backgrounds |
| ItemBox.lua | 372 | Pool of 10 loot cards (`WGL_FrameManager`, `WhoGotLootsFrames`) |
| CacheHandler.lua | 941 | `WGLCache`: the inspection broker (queue, throttle, snapshot cache, warm-ups, debug overlay) |
| GroupUpgradeFrame.lua | 874 | `WGLGroupUpgrade`: the "WHO COULD USE THIS? / YOUR DROP" panel, trade and whisper per member |
| WhoGotLoots.lua | 1164 | Event entry point, `AddLootFrame`, click handlers, tooltip placement, test gallery, slash commands |
| OptionsMenu.lua | 461 | Custom options flyout (not a Settings panel) |
| Localization.lua | 23 | **Not in the TOC**, so dead code |

Lua total is about 6,660 lines; the two XML files add 396.

**Saved variables.** `WhoGotLootsSavedData` is one account-wide flat table holding:
- `FirstBoot`, `SavedPos` (a `{point, relativeTo, relativePoint, x, y}` array)
- `SavedSize`, `LockWindow`, `AutoCloseOnEmpty`, `HideUnequippable`, `ProtectActiveHeirlooms`, `SoundEnabled`, `ShowOwnLoot`
- `ShowDuringRaid`, `ShowDuringLFR`, `MinQuality`, `ShowUpgradesBelowMinQuality`, `HideStatBreakdown`, `HideItemComparison`
- `WhisperMessage`, `IDontNeedMessage`, `OfferWhisperMessage`

There is no profile system, no per-character data and no schema version.

## 1. Feature inventory

**Main header window.** Created at UIBuilder.lua:279. It is a small 130x50 draggable title plate. On hover, the options gear and close button slide in from the right and the info "i" from the left (an OnUpdate animation at :405-445). Loot cards stack below it (`ResortFrames`, WhoGotLoots.lua:906). The window auto-closes when empty if `AutoCloseOnEmpty` is set. The info tooltip at UIBuilder.lua:337-349 documents the key bindings.

**Loot card** (ItemBox.lua:29, 10 pooled, 60 s lifetime with a progress bar; hovering pauses the timer). It shows:
- Item icon, a quality accent stripe, the quality-coloured name, and "BY <class-coloured looter>".
- A **primary** chip row and a **secondary** stat row.
- A pulsing green **upgrade glow** when the item is an upgrade for you and is not an upgrade for the looter.
- A loading spinner while the looter's gear is being inspected.

**Primary row contents:**
- Initially `UPGRADE YOU +N`, `ILVL YOU -N`, `ILVL YOU =`, or a warning such as "Comparison is protected" (WhoGotLoots.lua:471-499, formatters at UIBuilder.lua:147-184).
- After inspect, it becomes `FormatItemLevelSummary(playerDelta, looterDelta, takeaway)` (UIBuilder.lua:204). This produces **`ASK  YOU +19 / LOOTER -23`**. The takeaway is "ASK" when the item is an upgrade for you, is not bonus loot, is eligible for you, and `looterDelta <= 0` (CacheHandler.lua:353-358). Otherwise it is "UPGRADE" if your delta is above 0, else "ILVL".
  - The looter's sign colours are inverted: + is amber because they need it, - is green because it is likely tradeable (UIBuilder.lua:186-202).
- **Track row:** `YOU TRACK  CHAMPION 1/6 → HERO 3/6`, plus `LOOTER TRACK …` after inspect (UIBuilder.lua:217-242). The destination is green for a higher track and red for a lower one. It is **suppressed when the track names are equal** (:218-219), so the same track at a different rank shows nothing.
- **Badges:** "Is BoP", "Bonus Roll - Not Tradeable", "Heirloom scales through level N".
- **On failure:** `THEM <reason>` ("Out of inspect range", "Player unavailable", "Inspection timed out", "Equipment unavailable") and a clickable **"Try Inspect"** retry chip (CacheHandler.lua:433-488).

**Secondary row contents:**
- Stat deltas such as **`+130 Haste  -119 Mastery`**, from `BuildStatDeltas` (ItemComparison.lua:540). They are sorted gains first, then by a fixed order (primary, stamina, armor, secondaries, tertiaries, sockets). Tertiaries such as Indestructible render as flags (`+ Leech`).
- **These deltas are against *your* equipped gear, not the looter's.**
- Warnings: "Level N", "Unique Equipped", "Can't equip <subclass>", "<Subclass> - Undesired Type", "No <MainStat>", "Protected stat data: …".

**Card mouse actions** (WhoGotLoots.lua:694-776):

| Action | Effect |
|---|---|
| Shift-click | Link the item in chat |
| Alt-click | `InspectUnit` |
| Ctrl-click | `InitiateTrade` (requires `CheckInteractDistance(unit,2)`) |
| Double-click own loot | `C_Item.EquipItemByName` (out of combat only) |
| Middle-click someone else's loot | Whisper the `WhisperMessage` template |
| Middle-click own loot | Send `IDontNeedMessage` to INSTANCE_CHAT / RAID / PARTY / SAY |
| Right-click | Dismiss |

**"WHO COULD USE THIS? / YOUR DROP" panel** (GroupUpgradeFrame.lua:424-561).
- **Trigger:** your own drop that is not bonus loot, not "BoP", is eligible for you and has `delta <= 0`. The trigger also requires being **in a party and not a raid** (`BeginPartyCheck`, :731-732).
- **Header:** item icon and name, plus `You: -5 ilvl | 684 ilvl`.
- **Rows:** up to 4 party members (:308-422), each showing:
  - a class stripe and the name;
  - `equipped > candidate` (e.g. `670 > 684`, :583);
  - a status pill: `+14  UPGRADE`, `EQUAL`, `-12  NO UPGRADE`, `CAN'T USE`, `CHECKING...` or `UNAVAILABLE` (STATUS_STYLE :41-78);
  - a **trade button**.
- **Trade button:** `TradeItemToMember`, :202-254. It finds the exact bag slot by item GUID (preferring `C_NewItems.IsNewItem`), then calls `C_Container.PickupContainerItem` and `C_Item.DropItemOnUnit(unit)`, which opens the trade with the item placed.
- **Middle-click a row:** whisper `OfferWhisperMessage` to the member's Name-Realm.
- **Middle-click the panel:** announce `IDontNeedMessage`.

**Options flyout** (OptionsMenu.lua; defaults at :21-33):

| Setting | Default |
|---|---|
| AutoCloseOnEmpty | true |
| LockWindow | false |
| ShowOwnLoot | true |
| HideUnequippable | false |
| ProtectActiveHeirlooms | true |
| MinQuality | 3 = Rare (slider 1-4, with joke labels "Meh/Okay/Neat!/Omgg", util.lua:145) |
| ShowUpgradesBelowMinQuality | true |
| HideStatBreakdown | false |
| HideItemComparison | false |
| ShowDuringRaid | true |
| ShowDuringLFR | false |
| SoundEnabled | true (sound 145739) |
| SavedSize | 1.0 (slider 0.5-2.0) |

There are also three message editors (160-character cap):
- Whisper: "Greetings, %n! I sense you hold %i. If it does not align with your destiny, would you consider trading it? Many thanks!"
- I-don't-need: "I don't need %i if anyone wants it!"
- Offer: "Hi %n, I don't need %i. Would you like it?"

These defaults are at UIBuilder.lua:4-13. `%n` is the name and `%i` the item link.

**Slash commands** `/wgl` and `/whogotloots` (WhoGotLoots.lua:1100-1164):

| Command | Effect |
|---|---|
| (none) | Toggle the window |
| `add <id\|link>` | Fake loot on your target or yourself |
| `test` | 5-card layout gallery |
| `groupcheck` / `testgroup [item]` | 4-member panel preview |
| `debug` | Toggle debug prints and the inspection-broker overlay |

## 2. Data flow

**Events.**
- WhoGotLoots.lua:14-15: only `ADDON_LOADED` and **`CHAT_MSG_LOOT`**.
- CacheHandler.lua:790-793: `INSPECT_READY`, `GROUP_ROSTER_UPDATE`, `PLAYER_ENTERING_WORLD`, `UNIT_INVENTORY_CHANGED`.
- It does **not** use `ENCOUNTER_LOOT_RECEIVED`, `START_LOOT_ROLL`, `LOOT_*` or `TRADE_*`.

**Parsing who looted what** (WhoGotLoots.lua:117-163).
- It scrapes item links from arg1 with `"|c.-|H.-:.-|h.-|h|r"`, takes the name from arg2, and takes the **GUID from arg12**. The unit comes from `UnitTokenFromGUID`, falling back to `WGLU.GetPlayerUnitByName` (realm-normalized party or raid scan, util.lua:90-139).
- It filters item-upgrade echoes by rebuilding Blizzard's `CHANGED_OWN_ITEM` format (:28-34).
- It detects bonus rolls with a localized pattern built from `LOOT_ITEM_BONUS_ROLL` and `LOOT_ITEM_BONUS_ROLL_SELF`, plus an enUS literal fallback (:40-81).
- Messages with several links process only the first link.

**Pipeline** (`AddLootFrame`, :214-692):
1. Self, raid and LFR filters.
2. Pool eviction (oldest first).
3. `Item:ContinueOnItemLoad`.
4. Quality filter.
5. Armor and weapon only.
6. Cosmetics skipped.
7. `WGLItemComparison.BuildLocal`.
8. Either the own-drop branch to the group panel, or a card plus a `WGLCache.CreateRequest` for the looter.

**Getting the looter's equipment** is a proper inspect broker (CacheHandler.lua):
- Requests are grouped into one **job per player identity** (GUID, else Name-Realm, else `UnitIsUnit`) and fanned out to every pending card (:534-570).
- **Throttle:** one active job, `NotifyInspect` at least 2 s apart (`WGLCache_NotifyInterval`). It waits 2.5 s for `INSPECT_READY`, then reads 0.15 s later with a 1.5 s read deadline. It makes at most 2 attempts, waits up to 25 s for inspect range and 10 s for identity (:19-27, :666-743, :851-886).
- **It respects other addons:** `hooksecurefunc("NotifyInspect")` re-queues its own job when someone else inspects (:839-849). It uses a `SendingNotifyInspect` guard to ignore its own calls.
- **Snapshot:** for each slot it takes `GetInventoryItemLink(unit, slot)`, and the item level comes from **`C_TooltipInfo.GetInventoryItem(unit, slot)`'s ItemLevel line** (`Enum.TooltipDataLineType.ItemLevel` or a hard-coded 31) or `overrideItemLevel` (:159-218). The comment says this is because inspected hyperlinks show the unscaled level. The spec comes from `GetInspectSpecialization`.
- **Fast path:** if the link data is already cached client-side, it completes without an inspect (:695-699).
- **Cache:** snapshots live 600 s. They are invalidated on `UNIT_INVENTORY_CHANGED` for party or raid tokens, then re-warmed after 0.5 s (:799-812).
- **Pre-warming:** whole-group warm-ups at 0.5, 2 and 5 s after a roster change or entering the world, plus every 60 s (:612-624, :748-759, :877-883). The cache is memory-only and is not saved.

**Upgrade / downgrade / sidegrade.**
- The decision is pure item-level delta. The candidate comes from `C_Item.GetDetailedItemLevelInfo(link)` and the equipped item from `C_Item.GetCurrentItemLevel(ItemLocation)` (ItemComparison.lua:178, :294).
- Delta > 0 is an upgrade, 0 is "Equal", and < 0 is a downgrade.
- Nothing is stat-weighted; the stat deltas are informational only.
- Your "upgrade" is suppressed while an equipped heirloom still scales (WhoGotLoots.lua:196-208).

**Equippability (local player)** (ItemComparison.lua:661-672, 626-633):
- `C_Item.IsEquippableItem` gives CanEquip.
- `C_Item.GetItemSpecInfo(link)` must contain your current spec ID; this is the loot-spec table, so it covers armor type, weapon type and class/spec restrictions. A nil or empty table counts as unrestricted.
- The primary-stat check reads `GetItemStats`, with neck, finger and trinket exempt. The main stat comes from `GetSpecializationInfo` field 6 (1=Str, 2=Agi, 4=Int; util.lua:4-16).
- `WGLItemsDB` (hand-maintained tables) is used **only** for the party panel's pre-inspect armor-type gate (GroupUpgradeFrame.lua:743-744). After inspect, the panel uses `IsForSpec(link, inspectedSpecID)` (:790).
- Party rows never check the primary stat.

**Slot plans** (`ResolveReplacementPlan`, ItemComparison.lua:316-338):
- Rings and trinkets use "lowest" of the two slots.
- A 1H `INVTYPE_WEAPON` uses "lowest" of MH and OH for dual-wield specs (a hard-coded list at :26-37), otherwise MH only.
- A **2H uses "aggregate"**, the rounded average of MH and OH. Fury (72, Titan's Grip) uses "lowest" instead.
- MH-only, OH, shield and holdable items map directly to their slot.
- Unique-equipped categories (`C_Item.GetItemUniqueness`) redirect the comparison to the conflicting ring or trinket and emit "Unique Equipped" (:476-514, :686-693).
- Track comparison for aggregate weapons returns a value only if both hands share the same track and rank (:400-413).

**Tradeability.** There is **no real detection**: no tooltip scan for `BIND_TRADE_TIME_REMAINING` and no trade-window logic. Two weak signals stand in for it:
- "Is BoP" actually comes from **`C_Item.IsItemBindToAccountUntilEquip`** (WhoGotLoots.lua:387), which tests Warbound-until-equipped, not BoP. The label is wrong, and real BoP raid and dungeon drops are not flagged.
- Bonus-roll items are marked "Not Tradeable".

The "ASK" logic implicitly mirrors Blizzard's personal-loot trade rule: an item is tradeable if it is not an ilvl upgrade for the looter (`looterDelta <= 0`).

**Upgrade track.** It parses `C_TooltipInfo.GetHyperlink(link)` left-text for the English `"Upgrade Level:%s*(.-)%s+(%d+)/(%d+)"`, falling back to the English track names Explorer, Adventurer, Veteran, Champion, Hero and Myth (ItemComparison.lua:95-102, :192-233). It does not use `C_ItemUpgrade`, bonus IDs or `C_Item.GetItemUpgradeInfo`.

## 3. Addon comms and integrations

**There are none.** No `SendAddonMessage`, no prefix and no `CHAT_MSG_ADDON`, and there is no Pawn, RCLootCouncil or other integration (grep confirmed). All looter data comes from inspection. The only outbound messages are player-visible `SendChatMessage` whispers and group announcements.

## 5. Weaknesses, bugs and Midnight concerns

**Bugs and fragility**

1. **Hard `error()` everywhere inside `ContinueOnItemLoad`** (ItemComparison.lua `Fail`, :104; WhoGotLoots.lua:317, 329, 541, 565). Each of these drops the whole card and raises a Lua error for an edge case:
   - an unknown `GetItemStats` key (:156-158), e.g. any new Midnight stat or socket key;
   - "player has no active specialization" (:114-116), which hits low-level or unspecced characters on every loot;
   - a non-number `IsEquippableItem` result;
   - `GetItemUniqueness` returning a secret value.
2. **The party panel can throw on armor.** `IsForSpec` requires a numeric spec (:424-426). `RequireSpec` is set only for weapons (GroupUpgradeFrame.lua:779), so an armor comparison whose `GetInspectSpecialization` returns 0 or nil calls `IsForSpec(link, nil)` and errors. The error is pcall-caught and sent to `geterrorhandler`, and the member never renders. Separately, `GetInspectSpecialization` at :786-787 is not secret-guarded.
3. **The "BoP" label uses the Warbound API** (WhoGotLoots.lua:387). It is mislabelled, and true BoP is never detected.
4. **Off-hand and shield comparisons for a 2H user** compare against an empty off-hand at ilvl 0, which shows a huge false "UPGRADE". The ranged and 1H-versus-2H mismatch has no equivalent smoothing.
5. **The cross-realm whisper is broken on cards.** Line 768 uses `UnitName(player)` without the realm, and `%n` substitution uses the bare name. The group panel does this correctly with Name-Realm.
6. **`C_Item.IsEquippableItem` means "equippable at all", not "by you"**, so the "Can't equip X" branch almost never fires. All real gating comes from `GetItemSpecInfo`.
7. **`SavedPos` stores `relativeTo` from `GetPoint()`** (UIBuilder.lua:400-401), which is a frame object, into SavedVariables. That serializes as a junk table (or nil) and is passed back to `SetPoint` on load. This is fragile.
8. **`SplitCommands`** (WhoGotLoots.lua:1120) compares a single character to `"|r"`, so it never matches and stops splitting on spaces after the first `|`.
9. **Global namespace pollution:**
   - globals: `HandleEvents`, `AddLootFrame`, `GetSpecByNumber`, `class_specs`, `ClassAndGearDB`, `FrameTextures`, `UpdateQueueDebugList`, `CacheDebugFrame`;
   - generically named global frames `"ScrollFrame"` and `"ContentFrame"` (OptionsMenu.lua:147, 152);
   - XML template `"LoadingIcon"`;
   - `WhoLootFrameData` is redefined to `{}` in ItemBox.lua:3.
10. **Spec data is stale for Midnight.** There is no Devourer Demon Hunter in `class_specs` or `ClassAndGearDB` (ItemsDB.lua:86-89, 349-362), nor in `DualWieldSpecializations`.
11. **English-only parsing:** "Upgrade Level:", the track names, and the bonus-loot fallback. Localization.lua is not loaded, and all UI strings are hard-coded English.
12. Smaller issues:
    - Raids get loot cards but **no group panel**.
    - Stat deltas are always relative to *you*, even on someone else's card.
    - A track change within the same track (e.g. Hero 2/6 → Hero 5/6) is invisible.
    - Always-on `OnUpdate` frames: `TimerFrame` and the 5 Hz broker tick, which also calls `UpdateQueueDebugList` every tick.
    - `ClearInspectPlayer()` on job release could clear an inspect the user started.
    - `SendChatMessage(..., "SAY")` outside a group will fail or be blocked outdoors.

**Midnight (12.x) API concerns**

- **Secret values.** Handling is extensive (`IsSecret` and `SafeEquals` helpers in every module; the GUID, unit and names are guarded). However, **the `CHAT_MSG_LOOT` message itself (`args[1]`) is not checked for secrecy before `gmatch`** (WhoGotLoots.lua:132). If Blizzard makes loot chat secret during encounters, this errors. `UnitIsUnit('player', player)` at :229 is also unguarded.
- **`SendChatMessage`:** the global is the legacy entry point. In 12.x this should go through `C_ChatInfo.SendChatMessage`, and chat sends in instances or combat may be restricted. This needs verifying against current 12.0.x documentation.
- **Other restricted APIs:** `CheckInteractDistance`, `InitiateTrade`, `InspectUnit` and `NotifyInspect` are restricted in combat or instances. The code partly guards these (in-combat checks, secret-guarded range).
- The tooltip line-type fallback is a magic number (`31`).

**Worth emulating**

- **The inspection broker design** (CacheHandler.lua): one job per identity with fan-out to many requests, generation-tokened cancellation (`Frame.Generation`, `IsActive` closures), a hook on `NotifyInspect` to yield to other addons, a cache plus roster warm-up so the first loot often needs no inspect, separate range and identity timeouts, and an on-screen debug overlay of the queue.
- **Reading inspected item levels from `C_TooltipInfo.GetInventoryItem`** rather than the hyperlink, because of scaling.
- **The replacement-plan abstraction:** single, lowest or aggregate per equip location, plus unique-equipped redirection. It is a clean, testable kernel.
- **Locale-safe message classification** built from Blizzard's global format strings (`CHANGED_OWN_ITEM`, `LOOT_ITEM_BONUS_ROLL*`) with exact-link anchoring.
- **The trade helper:** GUID-tracked bag lookup that prefers `C_NewItems`, then `PickupContainerItem` and `C_Item.DropItemOnUnit`, guarded for cursor, lock and range.
- **UX:**
  - the "ASK" takeaway, with looter deltas colour-inverted so the looter's perspective reads at a glance;
  - an explicit "Comparison unavailable" state that never leaves a blank row;
  - hover pauses card lifetime;
  - the `/wgl test` and `/wgl groupcheck` preview galleries.
