# Compat layer — Ka0s Drop Watcher

`core/Compat.lua` is the only file that names a version-variant, deprecated or optional client API
(compat; design spec §4). Feature modules call `NS.Compat.X`; `luacheck` declares those client
globals for this one file only, and `test_compat`'s last case fails if any other shipped file names
one in code. It loads in `# Core` right after `core/CoreSetup.lua`, needs only `LibStub` at load,
and is read inside functions only.

**Fifty-five shims**, counted the way documentation-§3 counts them
(`grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua` answers `55`). The three
secret guards, `IsSecret`, `CanAccess` and `IsSafeKey`, are `LibKa0s-Compat-1.0`'s members, wired
by assignment and not counted: their contract and their library-absent bodies are LibKa0s
`docs/api/Compat/version-1-docs.md`. The major's six spell and spec readers are not published as
members, and `test_surface_parity` lists them as unwired on purpose: the two spec readers are
called on the library inside `PlayerSpecID` only, and nothing reads a spell.

## The rules every shim keeps

- Client globals are read **bare, at call time**, never captured at load, so a late namespace
  still wins and a suite can remove any rung.
- A value that may be secret meets nothing but `IsSecret` (or `type()`) before it is compared,
  matched, concatenated or formatted.
- Enum values are resolved by **name** (`Enum.TooltipDataLineType.TradeTimeRemaining`), never by
  number.
- A missing API never raises; each shim answers its documented absent value, listed below.
- A dead fallback rung is deleted, not shimmed. The bare container globals (`GetContainerNumSlots`,
  `GetContainerItemLink`, `PickupContainerItem`, removed in 10.0.2) and the bare item globals
  (`GetItemInfo`, `GetItemStats`, `GetItemSpecInfo`, `GetDetailedItemLevelInfo`,
  `GetItemUniqueness`, whose `C_Item` spellings every client at this TOC's interface has) are
  therefore not rungs, and `luacheck` no longer declares them.
- Third-party code (Pawn) runs under `pcall`. Blizzard calls do not, so a client defect raises
  where it happens instead of reading as silence.

## The shims

| Group | Shim | Ladder | Absent answer |
|---|---|---|---|
| Chat | `ChatSender()` | `C_ChatInfo.SendChatMessage` → the deprecated `SendChatMessage` global. Returns the function; the caller runs it under `pcall` (spec §9.2) | `nil` |
| Patterns | `FormatToPattern(fmt)` | none: a Lua pattern from a printf-style GlobalString (`%s` → text capture, `%d` → digit capture, `%1$s` read as `%s`, every magic character escaped). The order a positional string gives its arguments is the caller's to recover; the loot parser does | n/a (pure) |
| Duration | `DecodeDuration(text)` | the localized `INT_SPELL_DURATION_DAYS/HOURS/MIN/SEC` and `TIME_UNIT_DELIMITER` globals; see below | `nil` |
| | `ParseTradeTimeRemaining(text)` | the `BIND_TRADE_TIME_REMAINING` pattern, then `DecodeDuration` on its capture | `nil` |
| Tooltip | `ReadTooltipLine(data, typeName, parse)` | the lines of `typeName` (an `Enum.TooltipDataLineType` member) first, when the enum has it; then, when none of them answers (the client tagged the line with another type, or has no such member), every line, first non-nil `parse` wins. `parse` rejects foreign lines | `nil` |
| | `TradeTimeRemaining(bag, slot)` | `C_TooltipInfo.GetBagItem` → the `TradeTimeRemaining` line → `ParseTradeTimeRemaining`; seconds | `nil` |
| | `InventoryItemLevel(unit, slot)` | `C_TooltipInfo.GetInventoryItem` → the `ItemLevel` line: its numeric `itemLevel` field, else the `ITEM_LEVEL` pattern | `nil` |
| | `GetItemUpgradeInfo(link)` | `C_Item.GetItemUpgradeInfo` (copied, plain fields only, `source = "api"`) → `C_TooltipInfo.GetHyperlink`'s `ItemUpgradeLevel` line read with `ITEM_UPGRADE_TOOLTIP_FORMAT_STRING` (`source = "tooltip"`, no `trackStringID`) | `nil` |
| Restrictions | `InChatMessagingLockdown()` | `C_ChatInfo.InChatMessagingLockdown`; a secret answer reads as locked | `false` |
| | `RestrictionTypes()` | `Enum.AddOnRestrictionType` | `{}` |
| | `IsRestrictionStateActive(state)` | anything but `Enum.AddOnRestrictionState.Inactive` (0 without the enum) is active, so `Activating` counts; a boolean (the event's other payload shape) answers itself; a secret state is active | `false` for nil |
| | `IsRestrictionActive(rtype)` | `C_RestrictedActions.IsAddOnRestrictionActive` → `GetAddOnRestrictionState` through `IsRestrictionStateActive` | `false` |
| Identity | `NormalizedRealm()` | `GetNormalizedRealmName` (nil early in the login) → `GetRealmName` with spaces and hyphens dropped; a secret answer is skipped | `nil` |
| | `PlayerSpecID()` | LibKa0s-Compat-1.0's `GetSpecialization` (the index) then `GetSpecializationInfo(index)`'s first return, each `C_SpecializationInfo` first and the global second; a secret answer is nil. With the library absent its reader stubs answer nil, so no rung is re-implemented here | `nil` |
| Inventory | `InventoryItemLink(unit, slot)` | `GetInventoryItemLink`; a secret answer is nil | `nil` |
| | `BagSlotCount(bag)` | `C_Container.GetContainerNumSlots`; a secret answer is 0 | `0` |
| | `BagItemLink(bag, slot)` | `C_Container.GetContainerItemLink`; a secret answer is nil | `nil` |
| Inspect | `InventoryItemID(unit, slot)` | `GetInventoryItemID`; a secret answer is nil. An id with no link is an incomplete inspect read | `nil` |
| | `CanInspectUnit(unit)` | `CanInspect`; a secret answer cannot allow an inspect | `false` |
| | `InInspectRange(unit)` | `CheckInteractDistance(unit, 1)`; a secret answer is out of range | `true` (the range is not known; the inspect's own timeout answers) |
| | `NotifyInspect(unit)` | `NotifyInspect`; `true` when called | `false` |
| | `ClearInspectPlayer()` | `ClearInspectPlayer`; `true` when called | `false` |
| | `InspectSpecID(unit)` | `GetInspectSpecialization`; 0 (not known) and a secret answer are nil | `nil` |
| | `IsInspectFrameShown()` | `InspectFrame:IsShown()`; a secret answer is not shown | `false` |
| | `HookNotifyInspect(fn)` | `hooksecurefunc("NotifyInspect", fn)`: anyone's call reaches `fn`, after the client's own; the hook can never be removed. `true` when installed | `false` |
| Loot sources | `LootHistoryDrop(encounterID, lootListID)` | `C_LootHistory.GetSortedInfoForDrop`: a drop with a winner as `{ link, name, guid, classFile, isSelf }`, every field plain (a secret GUID or flag dropped); nil while nobody has won it, and for a secret or malformed answer | `nil` |
| | `ChallengeMapName(mapID)` | `C_ChallengeMode.GetMapUIInfo`'s name; an empty or secret answer is nil | `nil` |
| Binds | `IsItemBindToAccount(link)` | `C_Item.IsItemBindToAccount`; a secret answer reads as not bound | `false` |
| | `IsItemBindToAccountUntilEquip(link)` | `C_Item.IsItemBindToAccountUntilEquip` | `false` |
| | `GetBagItemGUID(bag, slot)` | `ItemLocation:CreateFromBagAndSlot` → `C_Item.DoesItemExist` → `C_Item.GetItemGUID` | `nil` |
| Items | `CanRequestItemLoad()` | `C_Item.RequestLoadItemDataByID` and `C_Timer.After` both present (LibKa0s-Item-1.0's `LoadItem` is inert without either) | `false` |
| | `GetItemInfo(link)` | `C_Item.GetItemInfo`; copies `{ name, quality, itemLevel, equipLoc, classID, subClassID, bindType, setID }`, plain fields only. A nil or secret name means uncached | `nil` |
| | `ItemEquipLoc(link)` | `C_Item.GetItemInfoInstant`'s fourth return, the `INVTYPE_*` equip location (`""` for an item you cannot wear); needs no item cache, so the gear snapshot skips bag items with no slot plan before asking for their facts | `nil` |
| | `GetDetailedItemLevel(link)` | `C_Item.GetDetailedItemLevelInfo`; the effective level | `nil` |
| | `GetItemStats(link)` | `C_Item.GetItemStats`; every plain string key with a plain number, unknown keys included | `{}` |
| | `GetItemSpecs(link)` | `C_Item.GetItemSpecInfo`; the list as a set `{ [specID] = true }`, nil for an empty list | `nil` |
| | `GetItemUniqueness(link)` | `C_Item.GetItemUniquenessByID`'s `(isUnique, name, count, categoryID)`; answers `(categoryID, max)`, categoryID nil for an item unique on its own | `nil, nil` |
| | `PlayerHasTransmog(link)` | `C_TransmogCollection.PlayerHasTransmogByItemInfo`; a secret answer is nil | `nil` |
| | `ItemClassRestriction(link)` | `C_TooltipInfo.GetHyperlink`'s `RestrictedRaceClass` line read with `ITEM_CLASSES_ALLOWED`, split on `LIST_DELIMITER`, each name mapped to its classFile through `LOCALIZED_CLASS_NAMES_MALE` and `_FEMALE`; a set | `nil` |
| Pawn | `PawnIsReady()` | the `PawnIsInitialized` global flag (a function spelling is called) | `false` |
| | `PawnIsLoaded()` | `C_AddOns.IsAddOnLoaded("Pawn")`, ready or not (the scorer picks the Pawn adapter for a loaded Pawn) | `false` |
| | `PawnItemData(link)` | `PawnGetItemData`; nil while the item is not cached | `nil` |
| | `PawnUpgradeInfo(link)` | `PawnIsItemAnUpgrade(PawnGetItemData(link))`: the list of `{ ScaleName, LocalizedScaleName, PercentUpgrade, ExistingItemLink }`, `{}` when it upgrades nothing, `nil` while not ready | `nil` |
| | `PawnScaleForSpec(classID, specID)` | `PawnFindScaleForSpec` | `nil` |
| | `PawnItemValue(link, scale)` | `PawnGetSingleValueFromItem(PawnGetItemData(link), scale)`, a number | `nil` |
| Trade | `PickupBagItem(bag, slot)` | `C_Container.PickupContainerItem` | `false` |
| | `DropItemOnUnit(unit)` | `DropItemOnUnit` | `false` |
| | `InitiateTrade(unit)` | `InitiateTrade` | `false` |
| | `InTradeRange(unit)` | `CheckInteractDistance(unit, 2)`, the trade distance; a secret answer is out of range | `true` (the client refuses a trade too far itself) |
| | `CursorHasItem()` | `CursorHasItem`; a secret answer reads as empty | `false` |
| | `ClearCursor()` | `ClearCursor`, which puts the cursor's item back where it came from | `false` |
| Drop tables | `ItemIcon(item)` | `C_Item.GetItemIconByID` (an id or a link; needs no item cache); a secret or non-texture answer is nil | `nil` |
| | `ClassColor(classFile)` | `C_ClassColor.GetClassColor` → the `RAID_CLASS_COLORS` table; answers `r, g, b`; a secret answer is nil | `nil` |
| | `InsertChatLink(link)` | `ChatFrameUtil.InsertLink`, the newer spelling → the `ChatEdit_InsertLink` global (an item button's shift-click); `true` when called | `false` |
| | `DressUpItem(link)` | `DressUpItemLink` → the older `DressUpLink` (an item button's ctrl-click); `true` when called | `false` |
| Detail card | `SpecName(specID)` | `GetSpecializationInfoByID`'s second return (the looter's spec, in words); a secret, empty or non-string answer is nil | `nil` |

The trade actions return `true` when they called the client. They guard nothing: the range, combat
and restriction checks are the trade helper's (`modules/TradeHelper.lua`), which calls them only
from a click, and reads `InTradeRange` only once `NS.Restrictions.CanTrade()` has said the player
is out of combat.

## The duration decoder

The client writes a remaining time as unit terms joined by `TIME_UNIT_DELIMITER`, each term formatted
from an `INT_SPELL_DURATION_<UNIT>` global (`"%d |4hour:hrs;"`, `"%d min"` and `"%d sec"` in enUS).
`DecodeDuration` reads the text back with the same globals:

1. Each unit's template is expanded into every spelling of its `|4…;` plural grammar (two forms in
   enUS and deDE, three in ruRU), and each spelling becomes an anchored pattern through
   `FormatToPattern`.
2. The spellings are tried longest first, so `hrs` is never cut short by a shorter spelling that is
   its prefix.
3. The decoder walks the text from the left: one term anchored at the cursor, then one optional
   delimiter, until the text is used up. Splitting on the delimiter instead would break, because an
   enUS term (`2 hrs`) contains the delimiter itself.
4. Anything left over makes the whole text unreadable (`nil`), never a partial guess.

The globals are read on every call, so a locale rewrite takes effect at once. The idea is the one
the brainstorm research credits to RCLootCouncil; the code is written here and copies none of
theirs. `test_compat` drives it in enUS, in a deDE shape and in a ruRU shape with a `", "`
delimiter.

## Who calls what

The callers land in M2: Restrictions (DW-21) reads the restriction shims, the roster (DW-22)
`NormalizedRealm`, ItemFacts (DW-23) reads
the bind helpers, `GetItemUpgradeInfo` and the item readers, the gear snapshot (DW-24) reads
`PlayerSpecID`, the inventory and bag readers and `InventoryItemLevel`, the loot parser (DW-25) builds its patterns with
`FormatToPattern` and guards its line and GUID with `IsSecret` and `IsSafeKey`, the inspect broker (DW-26) the inspect shims, `InventoryItemLink` and `InventoryItemLevel`, the feed (DW-27)
`LootHistoryDrop`, `ChallengeMapName` and the secret guards on every event payload, TradeTimer (DW-28, landed) reads
`TradeTimeRemaining`, `GetBagItemGUID`, `BagSlotCount` and `BagItemLink`, the trade helper (DW-29, landed) the trade actions, `InTradeRange`, the cursor shims and `GetBagItemGUID`, `BagSlotCount`, the
messaging edge (DW-2A, landed: `modules/Asks.lua`) `ChatSender`, `IsSecret` on the recipient, the
slot name and a raise's message, the Group drops table (DW-31, landed: `modules/WindowGroup.lua`)
`ItemIcon`, `ClassColor`, `InsertChatLink` and `DressUpItem`, the detail card (DW-32, landed:
`modules/DetailCard.lua`) `SpecName`, `PawnIsReady`, `InsertChatLink` and the item button's three, and the scorers (DW-50, landed:
`modules/Scoring.lua`) the Pawn seam, `PawnIsLoaded` and `IsSecret` on the links.
