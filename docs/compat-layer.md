# Compat layer — Ka0s Drop Watcher

`core/Compat.lua` is the only file that names a version-variant, deprecated or optional client API
(compat; design spec §4). It is the root of the addon's compat family: `core/CompatWorld.lua` and
`core/CompatItem.lua` add stable reads to the same `NS.Compat` (below), and the root's header names
both. The family follows compat's family rule (standard v2.79.0). Feature modules call `NS.Compat.X`; `luacheck` declares those client
globals for this one file only, and `test_compat`'s last case fails if any other shipped file names
one in code. It loads in `# Core` right after `core/TextParse.lua`, needs `LibStub` and `NS.TextParse` at
load, and is read inside functions only.

The text parsing behind the pattern, duration and tooltip-line shims (`FormatToPattern`, the
duration decoder, the tooltip line scan (`ScanLines`, handed this file's secret guards), and the
item level, upgrade track and class list lines) lives in
`core/TextParse.lua` (`NS.TextParse`, DW-61). That module is pure: it calls no client API and
reads no global, so it is not a compat file. `core/Compat.lua` reads the localized GlobalStrings
at call time, guards them, and passes them in; its members of the same names are one-line
delegators and stay counted below. `test_text_parse` drives the parsers with the strings passed
in; `test_compat` drives them through the shims.

**Eighty-seven shims** across the family, counted the way documentation-§3 counts them
(`cat core/Compat*.lua | grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'` answers `87`): the
root `core/Compat.lua` publishes 65, `core/CompatWorld.lua` 17 and `core/CompatItem.lua` 5. The three
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
| Strings | `GlobalString(name)` | none: `_G[name]`, read at call time and answered raw (the caller guards it): the `LOOT_ITEM*` lines, a slot's `INVTYPE_*` name, a chat type's label. Not version-variant; it is a member so the simulator's seam answers it (DW-90), in the root because a GlobalString read is not a world read (`core/CompatWorld.lua`'s one topic) | `nil` for a non-string name |
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
| | `GetItemStats(link)` | `C_Item.GetItemStats`; every plain string key with a plain number, unknown keys included. The client answers the primary stat of the spec playing alone, so `ItemPrimaryStats` supplies the others | `{}` |
| | `ItemPrimaryStats(link)` | `C_TooltipInfo.GetHyperlink`'s lines read with `ITEM_MOD_STRENGTH`, `_AGILITY` and `_INTELLECT` (`%c` the sign, grouping marks dropped): every primary stat the item carries, the grayed ones included, as `{ [ITEM_MOD_*_SHORT] = n }` | `nil` |
| | `GetItemSpecs(link)` | `C_Item.GetItemSpecInfo`; the list as a set `{ [specID] = true }`, nil for an empty list. The client lists the specs of the class playing alone, so `modules/ItemFacts.lua` records that class as `specsClass` | `nil` |
| | `GetItemUniqueness(link)` | `C_Item.GetItemUniquenessByID`'s `(isUnique, name, count, categoryID)`; answers `(categoryID, max)`, categoryID nil for an item unique on its own | `nil, nil` |
| | `PlayerHasTransmog(link)` | CanIMogIt's `PlayerKnowsTransmog` when that optional addon is loaded (the look known from any source; its `IsTransmogable` false answers nil), each call in `pcall` with a non-boolean answer ignored; else `C_TransmogCollection.PlayerHasTransmogByItemInfo`; a secret answer is nil | `nil` |
| | `TransmogSource()` | which source answers `PlayerHasTransmog` now: `CanIMogIt`, `C_TransmogCollection` or `none` (the diagnostics' integrations section) | `"none"` |
| | `ItemClassRestriction(link)` | `C_TooltipInfo.GetHyperlink`'s `RestrictedRaceClass` line read with `ITEM_CLASSES_ALLOWED`, split on `LIST_DELIMITER`, each name mapped to its classFile through `LOCALIZED_CLASS_NAMES_MALE` and `_FEMALE`; a set | `nil` |
| Pawn | `PawnIsReady()` | Pawn's own `PawnIsReady()` (its `PawnIsInitialized` is a file local); without that function, a global `PawnIsInitialized` flag or function | `false` |
| | `PawnItemData(link)` | `PawnGetItemData`; nil while the item is not cached | `nil` |
| | `PawnUpgradeInfo(link)` | `PawnIsItemAnUpgrade(PawnGetItemData(link))`: the list of `{ ScaleName, LocalizedScaleName, PercentUpgrade, ExistingItemLink }`, `{}` when it upgrades nothing, `nil` while not ready | `nil` |
| | `PawnScaleForSpec(classID, specID)` | `PawnFindScaleForSpec(classID, index)`, `index` the spec's place in its class (`NS.ClassData.SpecIndex`; Pawn's scales are numbered so, not by specID) | `nil` |
| | `PawnVisibleScale(classID, specID)` | The scale you show in Pawn's tooltips (`PawnCommon.Scales` and `PawnIsScaleVisible`) for your class and spec: one naming another class or spec, or an abandoned provider's, is skipped; a custom scale before a starter one, one naming your spec before one naming none, then by name | `nil` |
| | `PawnItemValue(link, scale)` | `PawnGetSingleValueFromItem(PawnGetItemData(link), scale)`'s unenchanted value (its second return, what Pawn's own upgrade test compares), else its first; a number | `nil` |
| Trade | `InitiateTrade(unit)` | `InitiateTrade` | `false` |
| | `InTradeRange(unit)` | `CheckInteractDistance(unit, 2)`, the trade distance; a secret answer is out of range | `true` (the client refuses a trade too far itself) |
| Trade window | `TradeItemLinks()` | `GetTradePlayerItemLink(i)` and `GetTradeTargetItemLink(i)` over slots 1-6 (slot 7 is not traded): answers `given, received`, two lists of links, a secret or empty answer left out | `{}, {}` |
| | `TradePartnerName()` | `UnitName("NPC")`, the trade window's partner, as `Name-Realm` when a realm is named, else `Name`; a secret or empty name is nil | `nil` |
| | `IsTradeCompleteMessage(messageType, message)` | whether a `UI_INFO_MESSAGE` is the client's "Trade complete.": its type is `LE_GAME_ERR_TRADE_COMPLETE`, or, without that constant, its text is `ERR_TRADE_COMPLETE`; a secret value is no match | `false` |
| Row menu | `ContextMenu(owner, entries)` | `MenuUtil.CreateContextMenu(owner, generator)`, one `CreateButton(text, fn)` per entry; `true` when built | `false` (the caller acts at once) |
| Drop tables | `ItemIcon(item)` | `C_Item.GetItemIconByID` (an id or a link; needs no item cache); a secret or non-texture answer is nil | `nil` |
| | `ClassColor(classFile)` | `C_ClassColor.GetClassColor` → the `RAID_CLASS_COLORS` table; answers `r, g, b`; a secret answer is nil | `nil` |
| | `InsertChatLink(link)` | `ChatFrameUtil.InsertLink`, the newer spelling → the `ChatEdit_InsertLink` global (an item button's shift-click); `true` when called | `false` |
| | `DressUpItem(link)` | `DressUpItemLink` → the older `DressUpLink` (an item button's ctrl-click); `true` when called | `false` |
| Detail card | `SpecName(specID)` | `GetSpecializationInfoByID`'s second return (the looter's spec, in words); a secret, empty or non-string answer is nil | `nil` |
| Toast | `PlayAlertSound()` | `PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST → SOUNDKIT.RAID_WARNING, "Master")` (`toast.sound`); `true` when played | `false` (no `PlaySound`, no `SOUNDKIT` or neither entry) |
| Encounter Journal | `JournalSelection()` | `EJ_GetNumTiers`, `EJ_GetCurrentTier`, `EJ_GetDifficulty`, `EJ_GetLootFilter`, `C_EncounterJournal.GetSlotFilter`, `C_EncounterJournal.GetPreviewMythicPlusLevel` (nil without it), and the `EncounterJournal` frame's `IsShown`, `instanceID` and `encounterID` (nil before the frame loads): `{ shown, tiers, tier, difficulty, classID, specID, slot, instanceID, encounterID, keystoneLevel }`; a secret `shown` is not shown | `nil` |
| | `JournalSelect(sel)` | `EJ_SelectTier` → `EJ_SelectInstance` → `EJ_SetDifficulty` → `EJ_SetLootFilter(classID or 0, specID or 0)` → `EJ_SelectEncounter` → `C_EncounterJournal.SetSlotFilter` (`ResetSlotFilter` for a nil slot) → `C_EncounterJournal.SetPreviewMythicPlusLevel(keystoneLevel)` (only where `GetPreviewMythicPlusLevel` can read it back, so the restore undoes it; feedback-17), each field only when given; the save and the restore of a read both go through it | `false` |
| | `JournalInstances(isRaid)` | `EJ_GetInstanceByIndex(i, isRaid)` until it answers no id: `{ { id, name, worldBoss } }` of the selected tier; `worldBoss` is true for a raid entry `EJ_GetInstanceInfo` shows without a difficulty (its ninth return, shouldDisplayDifficulty, false: the tier's world bosses, feedback-17) | `{}` |
| | `JournalEncounterName(encounterID)` | `EJ_GetEncounterInfo(encounterID)`'s first return, the boss's name; secret or empty is nil | `nil` |
| | `JournalLoot()` | `EJ_GetNumLoot` and `C_EncounterJournal.GetLootInfoByIndex`: the loaded entries `{ itemID, link, encounterID }` and how many have no link yet (they load later, announced by `EJ_LOOT_DATA_RECIEVED`) | `{}, 0` |

`InitiateTrade` returns `true` when it called the client. They guard nothing: the range, combat
and restriction checks are the trade helper's (`modules/TradeHelper.lua`), which calls them only
from a click, and reads `InTradeRange` only once `NS.Restrictions.CanTrade()` has said the player
is out of combat.

## The simulator's seam

`core/SimSeam.lua` loads right after this file (simulator spec §2, §5, DW-70). It names no client
API and adds no shim, so the count above stands. At load it wraps every member here that answers
for the client, which is every one but the secret guards and the pure text helpers (`IsSecret`,
`CanAccess`, `IsSafeKey`, `FormatToPattern`, `DecodeDuration`, `ParseTradeTimeRemaining`,
`ReadTooltipLine`, `IsRestrictionStateActive`). While `NS.Sim.active` is true, a wrapped call goes
to `NS.Sim.Answer(name, live, ...)`. That answer comes from the simulator's provider for the member
(`NS.Sim.SetProvider`), which may hand anything it does not invent back to the live member. Without
a provider, the live member answers. With no simulation running, the wrap costs one boolean test.

The **guarded** members never reach the client while a simulation runs, whatever a provider does:
`ChatSender` hands out a sender that prints `[sim] <channel> to <target>: <text>` (nothing is
whispered or posted), `NotifyInspect` and `ClearInspectPlayer` answer `true` with no call (a real
player is never inspected), and `InitiateTrade`
answers `true` with no call (no trade opens; the trade is printed).
`NS.Sim.Live(fn)` runs `fn` with the ordinary members answering for the client again, which is how
the simulator's own safety checks read the real world. `test_sim_core` holds all of this.

## The world reads

`core/CompatWorld.lua` loads between this file and `core/SimSeam.lua` (simulator spec §2, DW-72). It
adds the stable reads of the group, a unit and the instance to `NS.Compat`: `GroupSize`
(`GetNumGroupMembers`), `InRaid`, `InGroup(category)`, `InstanceGroupCategory`
(`LE_PARTY_CATEGORY_INSTANCE`), `UnitGUID`, `UnitName`, `UnitClass`, `UnitIsConnected`,
`InstanceState` (`IsInInstance`), `InstanceInfo` (`GetInstanceInfo`; its fifth answer the instance map id, the
client's eighth, since feedback-15 spec §0), `DifficultyKnown`
(`GetDifficultyInfo`) and `ChallengeModeActive` (`C_ChallengeMode.IsChallengeModeActive`); since
DW-B4 (feedback-3 spec §4) `DifficultyName` (`GetDifficultyInfo`'s name, plain, else nil) and
`KeystoneLevel` (`C_ChallengeMode.GetActiveKeystoneInfo`'s level, else
`C_ChallengeMode.GetChallengeCompletionInfo().level` while a completed run's chest is looted, else
nil), which name a group header's difficulty; and,
since DW-90 (sim feedback §0), whether you are fighting, `InCombatLockdown` and `PlayerInCombat`
(`UnitAffectingCombat("player")`), each a plain boolean; and since DW-P20 whether an optional addon
is loaded, `IsAddOnLoaded(name)` (`C_AddOns.IsAddOnLoaded`, a plain boolean, false without the API),
the one read behind the Pawn and CanIMogIt presence lines. (`GlobalString(name)` is the root's, in the
table above: a GlobalString read is not a world read.) None is version-variant, so the compat rule
does not ask for them here, and they are not counted above; they are `NS.Compat` members so the
seam wraps them, because a module reading the global would bypass a running simulation and see the
real, empty group. They answer the client's raw values (secrets included) and each caller guards
them as before. No other file names these globals: `.luacheckrc` declares them for
`core/CompatWorld.lua` alone (`C_ChallengeMode` and `UnitName` also for `core/Compat.lua`), and
`tests/test_sim_e2e.lua` scans every shipped file and fails one that does (the engine's modules for
`_G` too; `UNKNOWNOBJECT` and `C_AddOns.IsAddOnLoaded` are on its list).

While a simulation runs, `modules/SimWorld.lua` answers them for the invented group and place (raid1
is you in a raid, for every unit read; Raid Finder is an instance group, answering `InGroup` for the
instance category alone), `modules/SimEvents.lua` answers the two combat flags `true` while its
simulated combat edge is up (the client's answer otherwise, so real combat is never hidden), and
answers the inspect members (`NotifyInspect`, guarded, schedules the reply; `InventoryItemLink`,
`InventoryItemID`, `InventoryItemLevel` (the roster's worn level) and `InspectSpecID` answer until
`ClearInspectPlayer`),
the bag members for your simulated drops (`BagSlotCount`, `BagItemLink`, `GetBagItemGUID`,
`TradeTimeRemaining`, and `core/CompatItem.lua`'s `BagItemLevelQuality` and `TooltipBagItem`), `InTradeRange`, `ChallengeMapName`, `KeystoneLevel` (the simulated run's level) and the trade window's members
(`TradePartnerName`, `TradeItemLinks`, `IsTradeCompleteMessage`). `test_sim_events` holds these.

## The item reads at a location and the tooltip setters

`core/CompatItem.lua` loads after `core/CompatWorld.lua` and before `core/SimSeam.lua` (ui spec §0,
DW-80), on the same terms: none of its calls is version-variant, so they are not counted above, and
they are `NS.Compat` members so the seam answers them.

| Member | Client call | Absent answer |
|---|---|---|
| `BagItemLevelQuality(bag, slot)` | `C_Item.GetCurrentItemLevel` and `C_Item.GetItemQuality` on the slot's `ItemLocation` (`ItemLocation:CreateFromBagAndSlot`, after `C_Item.DoesItemExist`): the exact level and quality, every bonus, upgrade and scaling applied | `nil, nil` for an empty slot or no API; each `nil` for a secret or missing answer |
| `TooltipBagItem(tip, bag, slot)` | `tip:SetBagItem(bag, slot)`: the client's own tooltip, with its trade-time line | `false` when the tooltip has no such method |
| `TooltipInventoryItem(tip, unit, slot)` | `tip:SetInventoryItem(unit, slot)` | `false` |
| `TooltipHyperlink(tip, link)` | `tip:SetHyperlink(link)` | `false`, also for a secret or non-string link |
| `TooltipLeftLine(tip, n)` | `_G[tip:GetName() .. "TextLeft" .. n]` | `nil`, also for an unnamed tooltip or a missing line |

`core/ItemRead.lua` reads `BagItemLevelQuality` (its `ItemLevelAt` and `QualityAt`); the drop tables'
item buttons (`NS.WindowGroup.SetItemTooltip`) call the three setters: your own drop matched to its
bag item shows the bag slot, an item you wear your inventory slot, anything else its link. While a
simulation runs, `modules/SimWorld.lua` answers `BagItemLevelQuality` (the link's detailed level and
quality) and `TooltipBagItem` (the link's tooltip) for a simulated bag slot, which the client does
not have. `test_item_read` and `test_sim_events` hold these.

## The duration decoder

The client writes a remaining time as unit terms joined by `TIME_UNIT_DELIMITER`, each term formatted
from an `INT_SPELL_DURATION_<UNIT>` global (`"%d |4hour:hrs;"`, `"%d min"` and `"%d sec"` in enUS).
`DecodeDuration` reads the text back with the same globals (the walk is `TextParse.DecodeDuration`;
the shim reads the globals and passes them in):

1. Each unit's template is expanded into every spelling of its `|4…;` plural grammar (two forms in
   enUS and deDE, three in ruRU), plus the template itself unexpanded (the 12.1.5 bag tooltip line
   carries `3 |4hour:hrs; 49 min` raw), and each spelling becomes an anchored pattern through
   `FormatToPattern` (`TextParse.ExpandPlural`, `TextParse.FormatToPattern`).
2. The spellings are tried longest first, so `hrs` is never cut short by a shorter spelling that is
   its prefix.
3. The decoder walks the text from the left: one term anchored at the cursor, then one optional
   delimiter, until the text is used up. Splitting on the delimiter instead would break, because an
   enUS term (`2 hrs`) contains the delimiter itself.
4. Anything left over makes the whole text unreadable (`nil`), never a partial guess.

The globals are read on every call, so a locale rewrite takes effect at once. The idea is the one
the brainstorm research credits to RCLootCouncil; the code is written here and copies none of
theirs. `test_compat` drives it in enUS, in a deDE shape and in a ruRU shape with a `", "`
delimiter; `test_text_parse` drives the pure walk with the templates passed in.

## Who calls what

| Caller | Shims |
|---|---|
| `modules/Restrictions.lua` | `InChatMessagingLockdown`, `RestrictionTypes`, `IsRestrictionStateActive`, `IsRestrictionActive`; `InCombatLockdown` (`core/CompatWorld.lua`) |
| `modules/Roster.lua` | `NormalizedRealm`, `GlobalString` (`UNKNOWNOBJECT`, a name not yet arrived); `GroupSize`, `InRaid`, `InGroup`, `UnitGUID`, `UnitName`, `UnitClass`, `UnitIsConnected` (`core/CompatWorld.lua`) |
| `modules/GroupRoster.lua` | `NormalizedRealm` |
| `modules/CharFilter.lua` | `NormalizedRealm`; `UnitName`, `UnitClass` (`core/CompatWorld.lua`: your own key and class) |
| `modules/Situations.lua` | `InstanceState`, `InstanceInfo`, `DifficultyKnown`, `ChallengeModeActive`, `InGroup`, `InRaid` (`core/CompatWorld.lua`) |
| `core/ItemRead.lua` | `GetItemInfo`, `GetDetailedItemLevel`; `BagItemLevelQuality` (`core/CompatItem.lua`) |
| `modules/ItemFacts.lua` | `CanRequestItemLoad`, `GetItemInfo`, `GetDetailedItemLevel`, `GetItemStats`, `GetItemSpecs`, `GetItemUniqueness`, `GetItemUpgradeInfo`, `IsItemBindToAccount`, `IsItemBindToAccountUntilEquip`, `ItemClassRestriction`, `ItemPrimaryStats`, `PlayerHasTransmog`; `UnitClass` (`core/CompatWorld.lua`: the class a spec list was read for) |
| `modules/Gear.lua` | `PlayerSpecID`, `InventoryItemLink`, `InventoryItemLevel`, `BagSlotCount`, `BagItemLink`, `ItemEquipLoc`; `UnitClass` (`core/CompatWorld.lua`) |
| `modules/LootParser.lua` | `FormatToPattern`, `GlobalString`; `UnitName`, `UnitGUID` (`core/CompatWorld.lua`) |
| `modules/Inspect.lua` | `CanInspectUnit`, `InInspectRange`, `NotifyInspect`, `ClearInspectPlayer`, `InspectSpecID`, `IsInspectFrameShown`, `HookNotifyInspect`, `InventoryItemID`, `InventoryItemLink`, `InventoryItemLevel`; `UnitGUID`, `InstanceState` (`core/CompatWorld.lua`) |
| `modules/LootFeed.lua` | `LootHistoryDrop`, `ChallengeMapName`; `InstanceState`, `InstanceInfo`, `UnitName` (`core/CompatWorld.lua`) |
| `modules/GroupPlace.lua` | `IsSecret`; `InstanceState`, `InstanceInfo`, `DifficultyName`, `KeystoneLevel` (`core/CompatWorld.lua`: a group's instance and difficulty name) |
| `modules/TradeTimer.lua` | `TradeTimeRemaining`, `GetBagItemGUID`, `BagSlotCount`, `BagItemLink` |
| `modules/TradeHelper.lua` | `InitiateTrade`, `InTradeRange` |
| `modules/Asks.lua` | `ChatSender`, `GlobalString`; `InGroup`, `InRaid`, `InstanceGroupCategory` (`core/CompatWorld.lua`) |
| `modules/Scoring.lua` | `PawnIsReady`, `PawnUpgradeInfo`, `PawnVisibleScale`, `PawnScaleForSpec`, `PawnItemValue` |
| `modules/Session.lua` | `IsSecret`; `InstanceState`, `InstanceInfo` (`core/CompatWorld.lua`: the instance map id This instance is kept by) |
| `modules/History.lua` | `TradeItemLinks`, `TradePartnerName`, `IsTradeCompleteMessage` |
| `modules/HistoryCard.lua` | `InsertChatLink` |
| `modules/WindowGroup.lua` | `ItemIcon`, `ClassColor`, `InsertChatLink`, `DressUpItem`, `BagItemLink`, `InventoryItemLink`; `TooltipBagItem`, `TooltipInventoryItem`, `TooltipHyperlink` (`core/CompatItem.lua`) |
| `modules/DetailCard.lua` | `InsertChatLink`, `SpecName` |
| `modules/OffSpecCells.lua` | `SpecName` |
| `modules/WindowCells.lua` | `ClassColor` |
| `modules/TipMarks.lua` | `ClassColor` |
| `modules/WindowFilterBar.lua` | `ClassColor` |
| `modules/CompactGroup.lua` | `ClassColor`, `NormalizedRealm` |
| `modules/CompactHistory.lua` | `NormalizedRealm` |
| `modules/WindowHistory.lua` | `ContextMenu`, `ClassColor` |
| `modules/WindowFooter.lua` | `PawnIsReady` |
| `modules/TipGrid.lua` | `IsSecret` (a grid cell's width and the tooltip's line count, read in combat; feedback-14 spec §0); `TooltipLeftLine` (`core/CompatItem.lua`) |
| `modules/Toast.lua` | `PlayAlertSound`; `InCombatLockdown` (`core/CompatWorld.lua`) |
| `modules/Window.lua` | `PlayerInCombat` (`core/CompatWorld.lua`: the show decision off a combat edge) |
| `core/DropWatcher.lua` | `InCombatLockdown` (`core/CompatWorld.lua`: test mode's refusal); `IsAddOnLoaded` (`core/CompatWorld.lua`: the optional-addon line at logging on) |
| `modules/TestMode.lua` | `UnitName`, `UnitClass`, `UnitGUID` (`core/CompatWorld.lua`: you, as a placeholder's looter) |
| `modules/Diagnostics.lua` | `PawnIsReady`, `PawnVisibleScale`, `PawnScaleForSpec`, `TransmogSource`; `IsAddOnLoaded` (`core/CompatWorld.lua`: the optional-addon line) |
| `settings/PageEditors.lua` | `SpecName`; `PlayerSpecID` (the editors open on your spec); `UnitClass` (`core/CompatWorld.lua`) |
| `settings/SlashVerbs.lua` | `BagSlotCount`, `BagItemLink` (`/dw offer` finds the bag item) |
| `modules/Sim.lua` | `RestrictionTypes` |
| `modules/SimPool.lua` | `JournalSelection`, `JournalSelect`, `JournalInstances`, `JournalEncounterName`, `JournalLoot`; `ItemEquipLoc`, `GetDetailedItemLevel`, `GetItemInfo` (the entries' facts); `InventoryItemLink`, `BagSlotCount`, `BagItemLink` (the own-items fallback, read past the seam) |
| `modules/SimRoster.lua` | `NormalizedRealm` (who shares your realm) |
| `modules/SimWorld.lua` | `NormalizedRealm`, `BagSlotCount` (read past the seam); `GetDetailedItemLevel` (a member's slot level); `InstanceGroupCategory`. Its providers answer the members listed under the world reads; `TooltipHyperlink` (`core/CompatItem.lua`: a member's item level read off the tooltip) |
| `modules/SimEvents.lua` | `GroupSize`, `UnitName`, `UnitGUID`, `NormalizedRealm`, `GlobalString`, `InCombatLockdown` (the encounter's group size, your own loot line, who shares your realm, the `LOOT_ITEM*` lines, the stop's combat check). Its providers answer `InCombatLockdown` and `PlayerInCombat` |

The secret guards (`IsSecret`, `IsSafeKey`) are read by most of the edges above on every client
payload. `DecodeDuration`, `ParseTradeTimeRemaining`, `ReadTooltipLine` and `PawnItemData` are
called inside the seam itself. Item buttons elsewhere (the detail card, the History tab, the toast,
the Offer panel) reach `ItemIcon`, `InsertChatLink` and `DressUpItem` through
`modules/WindowGroup.lua`'s shared item button.
