# 02: Platform constraints (Midnight 12.x)

The primary source is Blizzard's generated API documentation, build 12.1.0 (69933, 2026-09-22), read from
`Gethe/wow-ui-source`. The current live build is 12.1.5, so re-check before building. Details and URLs are
in `inputs/doyouneedthat-and-wow-api-research.md` §3–§4.

## 1. Restrictions: what is blocked, and when

| Thing | State | Consequence for the design |
|---|---|---|
| `CHAT_MSG_LOOT` | **Not** flagged `SecretInChatMessagingLockdown` in the 12.1.0 docs. The text, playerName and guid fields are not NeverSecret. | Readable in theory. **Still check each payload with `issecretvalue`**, because one 12.0 changelog (Loot Pro) says otherwise and PLT reports a secret looter during encounters. Add `ENCOUNTER_LOOT_RECEIVED` and `C_LootHistory` as second sources. |
| Restriction types | `Enum.AddOnRestrictionType`: Combat, Encounter, ChallengeMode, PvPMatch, Map, Chat. `ADDON_RESTRICTION_STATE_CHANGED(type, state)` fires *just before* a restriction activates. | One `Restrictions` module tracks the state. The UI shows a lock badge and the number of queued sends. |
| Sending whispers | `C_ChatInfo.SendChatMessage` is `HasRestrictions` and restricted during encounters for observable chat types. It is unconfirmed whether an addon whisper from a click works mid-encounter. | Enable Ask only outside lockdown. Otherwise **queue the ask** and send after `ENCOUNTER_END`, `CHALLENGE_MODE_COMPLETED` or when the restriction goes Inactive. Always `pcall`, and leave the ask retryable if it fails. |
| Reading whispers | `CHAT_MSG_WHISPER` and `CHAT_MSG_PARTY`/`RAID`/`INSTANCE_CHAT` are lockdown-secret. | Do not build features that parse replies inside instances. "Did they say yes?" is not detectable there. |
| Addon comms | `SendAddonMessage` returns `AddOnMessageLockdown` during encounters and keys. Limits: 255-byte messages, 16-character prefix, 10 messages per prefix refilling at 1 per second. | Comms are later-phase only. When added, queue the essential messages and drop the rest, following RCLC's `CommsRestrictions.lua`. |
| Unit identity | `UnitGUID` and `UnitClass` are secret only for units that are *not* in your group. | Group members' names, GUIDs, classes and inspect specs are safe. |
| Combat log | CLEU is gone for addons. | Not needed. |
| Inspect | `NotifyInspect` needs `CanInspect` and range (`CheckInteractDistance(unit,1)`, blocked in combat). The server throttles silently. | Inspect only out of combat. Park requests during combat and resume on `PLAYER_REGEN_ENABLED`. |
| Trade | `InitiateTrade` and `DropItemOnUnit` need range, and are protected or blocked in combat. | Trade buttons are disabled in combat and show the reason. |

**Developer tool:** CVar `addonChatRestrictionsForced 1` forces chat lockdown outside instances, which lets
the queueing be tested. The setting does not persist.

## 2. Loot sources

| Source | Gives | Notes |
|---|---|---|
| `CHAT_MSG_LOOT` | text, playerName, guid | Build patterns from `LOOT_ITEM`, `LOOT_ITEM_SELF`, `LOOT_ITEM_MULTIPLE*`, `LOOT_ITEM_BONUS_ROLL*`, `LOOT_ITEM_PUSHED*`, `CHANGED_OWN_ITEM` (upgrade echoes) and `LOOT_ITEM_CREATED_SELF` (crafting noise). Rebuild them if PrettyChat rewrites the globals; Ka0s LootHistory already does this. |
| `ENCOUNTER_LOOT_RECEIVED` | encounterID, itemID, link, qty, playerName, classFile | The name has no realm, so use the class to tell same-named players apart. Gives the encounter context for free. |
| `C_LootHistory` + `LOOT_HISTORY_UPDATE_DROP` | winner {name, GUID, class}, rolls | **Group-loot drops only.** Personal loot never appears here. Decisive for raids if Midnight raids use group loot. |
| `CHALLENGE_MODE_COMPLETED` | the end of an M+ run | The ChallengeMode restriction clears here, so it is a good flush point for queued asks. |

Use a **dedupe key** of (looter GUID, itemID, bonus-string hash) within a short window, and keep the most
detailed link. DYNI does this.

## 3. Item facts that can be read in a locale-safe way

| Need | API |
|---|---|
| Item level | `C_Item.GetDetailedItemLevelInfo(link)`. For your own items use `C_Item.GetCurrentItemLevel(ItemLocation)`. For the looter's equipped items, read the tooltip ItemLevel line from `C_TooltipInfo.GetInventoryItem(unit, slot)`, because inspected links show unscaled levels (from WGL). |
| Upgrade track | **`C_Item.GetItemUpgradeInfo(link)`**, which returns `{currentLevel, maxLevel, maxItemLevel, trackString, trackStringID}`. Fall back to the tooltip line type `ItemUpgradeLevel` (32). Never parse English. |
| Bind and warbound | `bindType` from `GetItemInfo`. `C_Item.IsItemBindToAccount(link)` and `IsItemBindToAccountUntilEquip(link)` both work on links. Warbound items cannot be traded. |
| Your own trade timer | `C_TooltipInfo.GetBagItem(bag, slot)` → line type `TradeTimeRemaining` (36). Fall back to the `BIND_TRADE_TIME_REMAINING` pattern with RCLC's localised duration decoder. |
| Equippability | `GetItemInfoInstant` (classID, subclassID, equipLoc). `C_Item.GetItemSpecInfo(link)` lists the specs that can need the item, covering armour type, weapon type and primary stat in one call. `DoesItemContainSpec`, `IsItemSpecificToPlayerClass` (tier tokens). Neck, ring, trinket and cloak are universal. Keep a small class proficiency table as a fallback before the looter's spec is known. |
| Stats | `C_Item.GetItemStats(link)`. **Unknown stat keys must degrade, never error** (WGL bug). |
| Unique-equipped | `C_Item.GetItemUniqueness`. Check for secret values. |
| Set and tier | `setID` is the 16th return of `GetItemInfo`. `C_Item.GetSetBonusesForSpecializationByItemID`. |

## 4. Trade eligibility rules (estimate; the owner must verify in game)

- **Personal loot (M+, and possibly raid):**
  - the looter may trade a BoP drop within **2 hours**
  - only to players who were eligible for the same loot
  - only if the drop is **not an ilvl upgrade over what the looter owns** in that slot
  - It is unconfirmed whether "owns" means equipped only, or equipped plus bags. One forum post suggests the comparison is by item type.
- **Group loot (Dragonflight-era raids):** "all item level restrictions … removed entirely" inside the raid. Midnight Season 2's raid mode is contradicted by low-quality sources.
- **Never tradeable:** bonus-roll (Void Core) loot, and warbound or account-bound items.
- **Design response:** a **data-driven rule table keyed by content type** (Raid, M+, Dungeon, Delve, Open world). Each rule yields Yes, Likely, Unknown or No plus a reason string. The owner confirms the raid row in game before v1.

## 5. Pawn

- **Officially recommended for third parties:** `PawnShouldItemLinkHaveUpgradeArrow(link, checkLevel)`. It returns true, false or **nil**, where nil means "not ready, retry". It is CPU-throttled.
- **For detail:** `PawnIsItemAnUpgrade(PawnGetItemData(link))` returns a list of `{ScaleName, PercentUpgrade, ExistingItemLink}`.
- **To score a looter's item:** `PawnGetSingleValueFromItem(item, scale)` scores a single item against a scale. Pawn itself compares only against *your* gear, so scoring the looter's equipped item and the drop is a Ka0s-side calculation.
- **For the looter's spec:** `PawnFindScaleForSpec(classID, specID)` gives a scale. Use it only if a matching scale exists.
- Guard every call with `PawnIsInitialized`. Make Pawn an `OptionalDeps` dependency, call it through one seam, and keep it **CC BY-NC-ND**: call the API, never copy code.

## 6. Upgrade tracks in Season 2 (reference only, never hard-coded)

| Track | ilvl range |
|---|---|
| Adventurer | 266–282 |
| Veteran | 279–295 |
| Champion | 292–308 |
| Hero | 305–321 |
| Myth | 318–334 |

Each track has six ranks, and adjacent tracks overlap by two ranks. Read the track from `GetItemUpgradeInfo().trackString`.

## 7. Facts to verify in game before building

1. Whether `CHAT_MSG_LOOT` can be read during an active encounter and an active key, tested with `addonChatRestrictionsForced`.
2. Whether a whisper sent from a click during an encounter succeeds.
3. The raid loot mode in Midnight Season 2, and whether the ilvl trade rule applies there.
4. Whether the trade rule compares against items equipped, or equipped plus bags, and whether it compares by slot or by item type.
5. Whether `GetItemUpgradeInfo(link)` works on another player's drop link.
6. Whether `ENCOUNTER_LOOT_RECEIVED` fires for personal loot in M+ end-of-run chests.
