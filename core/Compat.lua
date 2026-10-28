local _, NS = ...
-- core/Compat.lua — the root of the compat family (compat, design spec §4), the only caller of
-- version-variant, deprecated and optional client APIs; core/CompatWorld.lua and core/CompatItem.lua
-- add stable reads to the same NS.Compat. Callers never name the client API. Every shim is tabled in
-- docs/compat-layer.md; the text parsing is core/TextParse.lua's (pure), handed this file's strings.
-- THE RULES. Client globals are read bare and at CALL time, never captured at load, so a late
-- namespace still wins and a suite can swap any rung. A value that may be secret meets nothing but
-- IsSecret before it is compared, matched, concatenated or formatted. No member raises on a missing
-- API: each answers its documented "absent" value (nil, false or an empty table). Enum values are
-- resolved by name, never by number, because Blizzard renumbers enums.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local TextParse = NS.TextParse -- core/TextParse.lua, above in the TOC: the pure parsers
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- ── Secret guards: LibKa0s-Compat-1.0 ───────────────────────────────────────────────────────
-- The library's answer, or the same one-rung body, on purpose: for a GUARD "the library is absent"
-- is not "the client has no secrets" (LibKa0s docs/api/Compat/version-1-docs.md, "Degradation").
-- Of that major's spell and spec readers, only the spec two are wired, behind PlayerSpecID.

--- True when `v` is a 12.0 secret value. Exactly one boolean.
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    return issecretvalue ~= nil and issecretvalue(v) and true or false
end

--- True when this context may read `v`. Exactly one boolean.
Compat.CanAccess = CompatLib and CompatLib.CanAccess or function(v)
    if canaccessvalue ~= nil then return canaccessvalue(v) and true or false end
    return not Compat.IsSecret(v)
end

--- True when `v` may be used as a table key: not secret, and not nil.
Compat.IsSafeKey = CompatLib and CompatLib.IsSafeKey or function(v)
    if Compat.IsSecret(v) then return false end
    return v ~= nil
end

-- A plain (non-secret) string, or nil.
local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

-- A plain (non-secret) number, or nil.
local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- A localized GlobalString by name, read at call time; nil when absent, empty or secret.
local function globalString(name)
    local s = plainString(_G[name])
    if s == nil or s == "" then return nil end
    return s
end

--- The client's GlobalString `name` (a LOOT_ITEM* line, an INVTYPE_* slot name, a chat type's
--- label), raw, read at call time; nil for a non-string name. On NS.Compat so the simulator's seam
--- answers it too (core/SimSetup.lua, DW-90): no module reads _G itself.
--- @param name any
--- @return any
function Compat.GlobalString(name)
    if type(name) ~= "string" then return nil end
    return _G[name]
end

-- ── Chat sending ────────────────────────────────────────────────────────────────────────────

--- The function that sends one chat message, `(text, chatType, languageID, target)`, or nil where
--- the client has none: C_ChatInfo.SendChatMessage, then the bare global (deprecated in 11.2.0).
--- The caller runs it in pcall (design spec §9.2 step 4); nil means the ask cannot be sent.
--- @return function|nil
function Compat.ChatSender()
    local chat = C_ChatInfo
    if chat and chat.SendChatMessage then return chat.SendChatMessage end
    return SendChatMessage
end

-- ── Pattern building and the duration decoder (design spec §7.4; the parsing is core/TextParse.lua's) ───

--- A Lua pattern from a printf-style GlobalString (pure); for the tests and modules/LootParser.lua.
function Compat.FormatToPattern(fmt) return TextParse.FormatToPattern(fmt) end

-- The client's unit templates, `{ template, seconds }`, read per call (a locale rewrite wins).
local function durationUnits()
    local units = {}
    for _, unit in ipairs(TextParse.DURATION_UNITS) do
        local template = globalString(unit.name)
        if template then units[#units + 1] = { template = template, seconds = unit.seconds } end
    end
    return units
end

--- Seconds in a localized duration ("1 hour 59 min"), or nil when the text is not wholly one.
--- @param text string
--- @return number|nil
function Compat.DecodeDuration(text)
    text = plainString(text)
    if not text then return nil end
    return TextParse.DecodeDuration(text, durationUnits(), globalString("TIME_UNIT_DELIMITER"))
end

--- Seconds left on a trade-time line (BIND_TRADE_TIME_REMAINING with its duration), else nil.
--- @param text string
--- @return number|nil
function Compat.ParseTradeTimeRemaining(text)
    text = plainString(text)
    local fmt = globalString("BIND_TRADE_TIME_REMAINING")
    if not (text and fmt) then return nil end
    return TextParse.TradeTimeRemaining(text, fmt, durationUnits(), globalString("TIME_UNIT_DELIMITER"))
end

-- ── The tooltip line reader ─────────────────────────────────────────────────────────────────

-- The numeric value of Enum.TooltipDataLineType[typeName], or nil when the client has no such
-- line type (then the reader falls back to the text).
local function lineTypeValue(typeName)
    local enum = Enum and Enum.TooltipDataLineType
    return enum and plainNumber(enum[typeName]) or nil
end

-- The first non-nil `parse` answer over the lines whose type is `wanted` (every line when nil):
-- the pure scan is core/TextParse.lua's, handed this file's secret guards.
local function scanLines(lines, wanted, parse)
    return TextParse.ScanLines(lines, wanted, parse, plainString, plainNumber)
end

--- The parsed value of a tooltip's `typeName` line, or nil: the lines of that type first, then
--- (none answered, or no such enum member) every line, first non-nil answer wins, so `parse` must
--- reject foreign lines. `data` is a C_TooltipInfo result.
--- @param data table|nil
--- @param typeName string  an Enum.TooltipDataLineType member name
--- @param parse function   (leftText, line) -> value|nil
--- @return any
function Compat.ReadTooltipLine(data, typeName, parse)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local wanted = lineTypeValue(typeName)
    if wanted ~= nil then
        local value = scanLines(data.lines, wanted, parse)
        if value ~= nil then return value end
    end
    return scanLines(data.lines, nil, parse)
end

-- A C_TooltipInfo getter's answer, or nil when the namespace or the getter is absent.
local function tooltipData(getter, ...)
    local tip = C_TooltipInfo
    local fn = tip and tip[getter]
    if not fn then return nil end
    return fn(...)
end

--- Seconds left to trade the item in bag `bag`, slot `slot` (design spec §7.4), or nil when the
--- tooltip has no trade-time line: the item is not tradeable, or its window has passed.
--- @return number|nil
function Compat.TradeTimeRemaining(bag, slot)
    return Compat.ReadTooltipLine(tooltipData("GetBagItem", bag, slot), "TradeTimeRemaining",
        Compat.ParseTradeTimeRemaining)
end

-- The item level on an ItemLevel line: the line's own numeric field where the client gives one,
-- else the number the ITEM_LEVEL format ("Item Level %d") captures.
local function parseItemLevel(text, line)
    local n = plainNumber(line.itemLevel)
    if n then return n end
    local fmt = globalString("ITEM_LEVEL")
    return fmt and TextParse.ItemLevel(text, fmt) or nil
end

--- The item level of `unit`'s item in inventory slot `slot`, read off its tooltip's ItemLevel line
--- (design spec §8: an inspected link carries the unscaled level), or nil.
--- @return number|nil
function Compat.InventoryItemLevel(unit, slot)
    return Compat.ReadTooltipLine(tooltipData("GetInventoryItem", unit, slot), "ItemLevel",
        parseItemLevel)
end

-- The track name and ranks on an ItemUpgradeLevel line, from ITEM_UPGRADE_TOOLTIP_FORMAT_STRING
-- ("Upgrade Level: %s %d/%d" in enUS).
local function parseUpgradeLine(text)
    local fmt = globalString("ITEM_UPGRADE_TOOLTIP_FORMAT_STRING")
    return fmt and TextParse.UpgradeLine(text, fmt) or nil
end

-- C_Item.GetItemUpgradeInfo's table, copied with plain fields only, or nil.
local function upgradeFromApi(link)
    local item = C_Item
    if not (item and item.GetItemUpgradeInfo) then return nil end
    local info = item.GetItemUpgradeInfo(link)
    if Compat.IsSecret(info) or type(info) ~= "table" then return nil end
    return {
        currentLevel = plainNumber(info.currentLevel), maxLevel = plainNumber(info.maxLevel),
        maxItemLevel = plainNumber(info.maxItemLevel), trackString = plainString(info.trackString),
        trackStringID = plainNumber(info.trackStringID), source = "api",
    }
end

--- The upgrade track of an item link: `{ trackString, trackStringID, currentLevel, maxLevel,
--- maxItemLevel, source }`, from C_Item.GetItemUpgradeInfo, else from the hyperlink tooltip's
--- ItemUpgradeLevel line (no trackStringID there; source "tooltip"). Nil for an item with no
--- track, an uncached item, or a client with neither.
--- @param link string
--- @return table|nil
function Compat.GetItemUpgradeInfo(link)
    if not plainString(link) then return nil end
    local info = upgradeFromApi(link)
    if info and info.trackString then return info end
    return Compat.ReadTooltipLine(tooltipData("GetHyperlink", link), "ItemUpgradeLevel",
        parseUpgradeLine)
end

-- ── Restrictions (12.0) ─────────────────────────────────────────────────────────────────────

--- True while the chat-messaging lockdown is in effect. A secret answer reads as locked; a client
--- without the API is never locked.
--- @return boolean
function Compat.InChatMessagingLockdown()
    local chat = C_ChatInfo
    if not (chat and chat.InChatMessagingLockdown) then return false end
    local locked = chat.InChatMessagingLockdown()
    if Compat.IsSecret(locked) then return true end
    return locked == true
end

--- Enum.AddOnRestrictionType (name -> value), or an empty table on a client without it.
--- @return table
function Compat.RestrictionTypes()
    local enum = Enum and Enum.AddOnRestrictionType
    return type(enum) == "table" and enum or {}
end

--- True when a restriction STATE (ADDON_RESTRICTION_STATE_CHANGED's second payload, or
--- GetAddOnRestrictionState's answer) is not Inactive: Activating counts (it fires just before the
--- restriction bites). A boolean payload (docs/midnight-quirks.md) answers itself; a secret state
--- reads as active, a missing or unreadable one as inactive.
--- @return boolean
function Compat.IsRestrictionStateActive(state)
    if Compat.IsSecret(state) then return true end
    if type(state) == "boolean" then return state end
    local n = plainNumber(state)
    if n == nil then return false end
    local enum = Enum and Enum.AddOnRestrictionState
    local inactive = enum and plainNumber(enum.Inactive) or 0
    return n ~= inactive
end

--- True while restriction `rtype` (an Enum.AddOnRestrictionType value) is in effect. A client
--- without C_RestrictedActions has no restrictions.
--- @return boolean
function Compat.IsRestrictionActive(rtype)
    local ra = C_RestrictedActions
    if not ra or rtype == nil then return false end
    if ra.IsAddOnRestrictionActive then
        local active = ra.IsAddOnRestrictionActive(rtype)
        if Compat.IsSecret(active) then return true end
        return active == true
    end
    if ra.GetAddOnRestrictionState then
        return Compat.IsRestrictionStateActive(ra.GetAddOnRestrictionState(rtype))
    end
    return false
end

-- ── Identity ────────────────────────────────────────────────────────────────────────────────

--- The player's realm as chat and unit names spell it: GetNormalizedRealmName (spaces and hyphens
--- dropped), which answers nil early in the login, then GetRealmName with the same characters
--- dropped. Nil when neither answers a plain, non-empty string.
--- @return string|nil
function Compat.NormalizedRealm()
    local realm = GetNormalizedRealmName and plainString(GetNormalizedRealmName())
    if realm and realm ~= "" then return realm end
    realm = GetRealmName and plainString(GetRealmName())
    realm = realm and realm:gsub("[%s%-]", "")
    if realm and realm ~= "" then return realm end
    return nil
end

--- The player's own specialization id: LibKa0s-Compat-1.0's GetSpecialization (the index) and
--- GetSpecializationInfo (its first return), each C_SpecializationInfo first and the global second.
--- Nil before the client knows the spec, for a secret answer, and with the library absent (the
--- major's reader stubs answer nil, so no rung is re-implemented here).
--- @return number|nil
function Compat.PlayerSpecID()
    if not (CompatLib and CompatLib.GetSpecialization and CompatLib.GetSpecializationInfo) then
        return nil
    end
    local index = plainNumber(CompatLib.GetSpecialization())
    if not index then return nil end
    return plainNumber((CompatLib.GetSpecializationInfo(index)))
end

-- ── Inventory and bags (the gear snapshot, design spec §4) ──────────────────────────────────

--- The link of the item `unit` wears in inventory slot `slot`, or nil (an empty slot, a secret
--- answer, or no API).
--- @return string|nil
function Compat.InventoryItemLink(unit, slot)
    if not GetInventoryItemLink then return nil end
    return plainString(GetInventoryItemLink(unit, slot))
end

-- C_Container[name], or nil. The bare container globals were removed in 10.0.2, so no client at
-- this TOC's interface has a second rung (compat: a dead rung is deleted, not shimmed).
local function containerApi(name)
    local container = C_Container
    return container and container[name] or nil
end

--- How many slots bag `bag` has: C_Container.GetContainerNumSlots. 0 for a missing bag, a secret
--- answer or no API.
--- @return number
function Compat.BagSlotCount(bag)
    local fn = containerApi("GetContainerNumSlots")
    if not fn then return 0 end
    return plainNumber(fn(bag)) or 0
end

--- The link of the item in bag `bag`, slot `slot`: C_Container.GetContainerItemLink. Nil for an
--- empty slot, a secret answer or no API.
--- @return string|nil
function Compat.BagItemLink(bag, slot)
    local fn = containerApi("GetContainerItemLink")
    if not fn then return nil end
    return plainString(fn(bag, slot))
end

-- ── Inspecting another player (the inspect broker, design spec §8) ──────────────────────────

--- The item id `unit` wears in inventory slot `slot`, or nil (an empty slot, data the client does
--- not hold, a secret answer, or no API). An id with no link is an incomplete read.
--- @return number|nil
function Compat.InventoryItemID(unit, slot)
    if not GetInventoryItemID then return nil end
    return plainNumber(GetInventoryItemID(unit, slot))
end

--- True when the client allows inspecting `unit` now (CanInspect). False for a secret answer or no
--- API.
--- @return boolean
function Compat.CanInspectUnit(unit)
    if not CanInspect then return false end
    local v = CanInspect(unit)
    if Compat.IsSecret(v) then return false end
    return v == true or v == 1
end

--- True when `unit` is within inspect range (CheckInteractDistance, index 1). A secret answer is
--- out of range; with no API the range is not known and the inspect is let through (its own
--- timeout answers).
--- @return boolean
function Compat.InInspectRange(unit)
    if not CheckInteractDistance then return true end
    local v = CheckInteractDistance(unit, 1)
    if Compat.IsSecret(v) then return false end
    return v == true or v == 1
end

--- Ask the client to inspect `unit` (NotifyInspect). True when it was called.
--- @return boolean
function Compat.NotifyInspect(unit)
    if not NotifyInspect then return false end
    NotifyInspect(unit)
    return true
end

--- Release the client's inspect target (ClearInspectPlayer). True when it was called.
--- @return boolean
function Compat.ClearInspectPlayer()
    if not ClearInspectPlayer then return false end
    ClearInspectPlayer()
    return true
end

--- The inspected unit's specialization id (GetInspectSpecialization), or nil: 0 (not known), a
--- secret answer or no API.
--- @return number|nil
function Compat.InspectSpecID(unit)
    if not GetInspectSpecialization then return nil end
    local id = plainNumber(GetInspectSpecialization(unit))
    if not id or id <= 0 then return nil end
    return id
end

--- True when Blizzard's inspect window is open (the player is inspecting someone).
--- @return boolean
function Compat.IsInspectFrameShown()
    local frame = InspectFrame
    if not (frame and frame.IsShown) then return false end
    local v = frame:IsShown()
    if Compat.IsSecret(v) then return false end
    return v == true
end

--- Run `fn(unit)` after every NotifyInspect call, anyone's (hooksecurefunc: the hook can never be
--- removed, so the caller guards its own state). `unit` is passed as the client gave it and may
--- be secret. True when the hook was installed.
--- @param fn function
--- @return boolean
function Compat.HookNotifyInspect(fn)
    if not (hooksecurefunc and NotifyInspect) then return false end
    hooksecurefunc("NotifyInspect", fn)
    return true
end

-- ── The loot sources beside chat (the feed, design spec §3) ─────────────────────────────────

-- The winner of a C_LootHistory drop, plain fields only, or nil.
local function lootWinner(w)
    if Compat.IsSecret(w) or type(w) ~= "table" then return nil end
    local guid = w.playerGUID
    if not (Compat.IsSafeKey(guid) and type(guid) == "string") then guid = nil end
    local isSelf = w.isSelf
    return { name = plainString(w.playerName), guid = guid, classFile = plainString(w.playerClass),
        isSelf = not Compat.IsSecret(isSelf) and isSelf == true }
end

--- A group-loot drop that has a winner, from C_LootHistory.GetSortedInfoForDrop: { link, name,
--- guid, classFile, isSelf }, every field plain. Nil while nobody has won it (rolls still open, or
--- everyone passed), for a secret or malformed answer, or with no API.
--- @param encounterID number
--- @param lootListID number
--- @return table|nil
function Compat.LootHistoryDrop(encounterID, lootListID)
    local api = C_LootHistory
    if not (api and api.GetSortedInfoForDrop) then return nil end
    if not (plainNumber(encounterID) and plainNumber(lootListID)) then return nil end
    local info = api.GetSortedInfoForDrop(encounterID, lootListID)
    if Compat.IsSecret(info) or type(info) ~= "table" then return nil end
    local link, winner = plainString(info.itemHyperlink), lootWinner(info.winner)
    if not (link and winner) or not (winner.name or winner.guid) then return nil end
    winner.link = link
    return winner
end

--- A keystone dungeon's name from C_ChallengeMode.GetMapUIInfo, or nil (no map, a secret answer,
--- or no API).
--- @param mapID number
--- @return string|nil
function Compat.ChallengeMapName(mapID)
    local api = C_ChallengeMode
    if not (api and api.GetMapUIInfo and plainNumber(mapID)) then return nil end
    local name = plainString((api.GetMapUIInfo(mapID)))
    if name == "" then return nil end
    return name
end

-- ── Bind helpers ────────────────────────────────────────────────────────────────────────────

-- C_Item.<fn>(link) as a plain boolean; false when the API is absent or the answer is secret.
local function itemFlag(fn, link)
    local item = C_Item
    if not (item and item[fn] and plainString(link)) then return false end
    local v = item[fn](link)
    if Compat.IsSecret(v) then return false end
    return v == true
end

--- True when the item binds to the account (warbound). Works on another player's link.
function Compat.IsItemBindToAccount(link)
    return itemFlag("IsItemBindToAccount", link)
end

--- True when the item is warbound until equipped. Works on another player's link.
function Compat.IsItemBindToAccountUntilEquip(link)
    return itemFlag("IsItemBindToAccountUntilEquip", link)
end

--- The GUID of the item in bag `bag`, slot `slot` (the trade timer's key, spec §7.4), or nil.
--- @return string|nil
function Compat.GetBagItemGUID(bag, slot)
    local item, loc = C_Item, ItemLocation
    if not (item and item.GetItemGUID and loc and loc.CreateFromBagAndSlot) then return nil end
    local location = loc:CreateFromBagAndSlot(bag, slot)
    if item.DoesItemExist and not item.DoesItemExist(location) then return nil end
    return plainString(item.GetItemGUID(location))
end

-- ── Item readers (the item facts, design spec §4 and §5.1) ──────────────────────────────────
-- Each takes a link, calls C_Item's spelling, copies plain fields only and answers nil (or false)
-- for an uncached item or a missing call. The bare globals are dead rungs (every client at this
-- interface has C_Item), so they are deleted, not shimmed. Caching is modules/ItemFacts.lua's.

-- C_Item[name], or nil.
local function itemApi(name)
    local item = C_Item
    return item and item[name] or nil
end

--- The equip location of an item link (`INVTYPE_*`, "" for an item you cannot wear) from
--- C_Item.GetItemInfoInstant, which needs no item cache. Nil for a secret or missing link, an
--- answer the client does not give, or no API.
--- @param link string
--- @return string|nil
function Compat.ItemEquipLoc(link)
    local fn = itemApi("GetItemInfoInstant")
    if not (fn and plainString(link)) then return nil end
    local _, _, _, equipLoc = fn(link)
    return plainString(equipLoc)
end

--- True when the client can be asked to load an item (C_Item.RequestLoadItemDataByID) and can
--- call back later (C_Timer.After): LibKa0s-Item-1.0's LoadItem is inert without either.
--- @return boolean
function Compat.CanRequestItemLoad()
    local item, timer = C_Item, C_Timer
    return (item and item.RequestLoadItemDataByID and timer and timer.After) and true or false
end

--- The cached fields of an item link: `{ name, quality, itemLevel, equipLoc, classID, subClassID,
--- bindType, setID }`, from C_Item.GetItemInfo. Nil while the item
--- is not cached (the name is nil then), and for a secret or missing link.
--- @param link string
--- @return table|nil
function Compat.GetItemInfo(link)
    local fn = itemApi("GetItemInfo")
    if not (fn and plainString(link)) then return nil end
    local name, _, quality, itemLevel, _, _, _, _, equipLoc, _, _, classID, subClassID, bindType,
        _, setID = fn(link)
    name = plainString(name)
    if not name then return nil end
    return {
        name = name, quality = plainNumber(quality), itemLevel = plainNumber(itemLevel),
        equipLoc = plainString(equipLoc), classID = plainNumber(classID),
        subClassID = plainNumber(subClassID), bindType = plainNumber(bindType),
        setID = plainNumber(setID),
    }
end

--- The effective item level of a link (its upgrades and bonus ids applied), from
--- C_Item.GetDetailedItemLevelInfo. Nil when it answers no number, or is absent.
--- @param link string
--- @return number|nil
function Compat.GetDetailedItemLevel(link)
    local fn = itemApi("GetDetailedItemLevelInfo")
    if not (fn and plainString(link)) then return nil end
    return plainNumber((fn(link)))
end

--- The stats of a link as `{ [STAT_KEY] = n }` (keys such as ITEM_MOD_STRENGTH_SHORT), from
--- C_Item.GetItemStats. A key the addon does not know is copied all the same;
--- secret keys and values are skipped. An empty table when the client answers nothing.
--- @param link string
--- @return table
function Compat.GetItemStats(link)
    local fn = itemApi("GetItemStats")
    local out = {}
    if not (fn and plainString(link)) then return out end
    local stats = fn(link)
    if Compat.IsSecret(stats) or type(stats) ~= "table" then return out end
    for key, value in pairs(stats) do
        if plainString(key) and plainNumber(value) then out[key] = value end
    end
    return out
end

--- The specializations an item is for, as a set `{ [specID] = true }`, from C_Item.GetItemSpecInfo.
--- Nil when the client answers no list or an empty one (the item names no spec).
--- @param link string
--- @return table|nil
function Compat.GetItemSpecs(link)
    local fn = itemApi("GetItemSpecInfo")
    if not (fn and plainString(link)) then return nil end
    local list = fn(link)
    if Compat.IsSecret(list) or type(list) ~= "table" then return nil end
    local set
    for _, specID in ipairs(list) do
        if plainNumber(specID) then
            set = set or {}
            set[specID] = true
        end
    end
    return set
end

-- C_Item.GetItemUniquenessByID's (isUnique, categoryName, categoryCount, categoryID).
local function uniqueFromApi(fn, link)
    local isUnique, _, count, catID = fn(link)
    catID, count = plainNumber(catID), plainNumber(count)
    if catID and catID > 0 then return catID, count or 1 end
    if not Compat.IsSecret(isUnique) and isUnique == true then return nil, 1 end
    return nil, nil
end

--- How many of this item (or of its unique category) may be equipped at once: `(categoryID,
--- max)`, with categoryID nil when the item is unique on its own. `(nil, nil)` when it is not
--- unique or the client lacks C_Item.GetItemUniquenessByID.
--- @param link string
--- @return number|nil categoryID, number|nil max
function Compat.GetItemUniqueness(link)
    if not plainString(link) then return nil, nil end
    local item = C_Item
    if item and item.GetItemUniquenessByID then return uniqueFromApi(item.GetItemUniquenessByID, link) end
    return nil, nil
end

-- CanIMogIt (an optional dependency): its API is called, never copied, each call in pcall so its
-- error never becomes this addon's. `CanIMogIt:Method(link)`; nil for a missing method, a raise or
-- an answer that is not a plain boolean.
local function canIMogIt(method, link)
    local cimi = CanIMogIt
    local fn = type(cimi) == "table" and cimi[method]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, cimi, link)
    if not ok or Compat.IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

-- CanIMogIt's answer: true or false when it knows, nil to ask the client instead. An item it says
-- has no appearance to collect answers `nil, true`.
local function transmogFromCanIMogIt(link)
    if canIMogIt("IsTransmogable", link) == false then return nil, true end
    return canIMogIt("PlayerKnowsTransmog", link), false
end

-- The client's answer: C_TransmogCollection.PlayerHasTransmogByItemInfo, nil when absent or secret.
local function transmogFromClient(link)
    local tc = C_TransmogCollection
    if not (tc and tc.PlayerHasTransmogByItemInfo) then return nil end
    local known = tc.PlayerHasTransmogByItemInfo(link)
    if Compat.IsSecret(known) or type(known) ~= "boolean" then return nil end
    return known
end

--- Whether you have collected this item's appearance (design spec §4, transmog-known): CanIMogIt's
--- PlayerKnowsTransmog when that addon is loaded (it knows the appearance from any source), else
--- C_TransmogCollection's PlayerHasTransmogByItemInfo. Nil when neither answers, the answer is
--- secret, or CanIMogIt says the item has no appearance to collect.
--- @param link string
--- @return boolean|nil
function Compat.PlayerHasTransmog(link)
    if not plainString(link) then return nil end
    local known, noAppearance = transmogFromCanIMogIt(link)
    if noAppearance then return nil end
    if known ~= nil then return known end
    return transmogFromClient(link)
end

--- Which source answers PlayerHasTransmog now: "CanIMogIt", "C_TransmogCollection" or "none". For
--- the diagnostics' integrations section.
--- @return string
function Compat.TransmogSource()
    local cimi = CanIMogIt
    if type(cimi) == "table" and type(cimi.PlayerKnowsTransmog) == "function" then return "CanIMogIt" end
    local tc = C_TransmogCollection
    if tc and tc.PlayerHasTransmogByItemInfo then return "C_TransmogCollection" end
    return "none"
end

-- Localized class name -> classFile, from the client's LOCALIZED_CLASS_NAMES_MALE and _FEMALE.
local function classFilesByName()
    local out = {}
    for _, map in ipairs({ LOCALIZED_CLASS_NAMES_MALE, LOCALIZED_CLASS_NAMES_FEMALE }) do
        if type(map) == "table" then
            for classFile, name in pairs(map) do
                if plainString(name) and plainString(classFile) then out[name] = classFile end
            end
        end
    end
    return out
end

-- The classes on a RestrictedRaceClass line ("Classes: Warrior, Paladin"), as a set of classFiles,
-- or nil when the line is not that one or names no class the client knows.
local function parseClasses(text)
    local fmt = globalString("ITEM_CLASSES_ALLOWED")
    if not fmt then return nil end
    return TextParse.ClassSet(text, fmt, globalString("LIST_DELIMITER"), classFilesByName)
end

--- The classes an item is restricted to (a tier token, a class set piece), as a set
--- `{ [classFile] = true }`, read off the hyperlink tooltip's RestrictedRaceClass line with the
--- localized ITEM_CLASSES_ALLOWED. Nil when the item names no class.
--- @param link string
--- @return table|nil
function Compat.ItemClassRestriction(link)
    if not plainString(link) then return nil end
    return Compat.ReadTooltipLine(tooltipData("GetHyperlink", link), "RestrictedRaceClass",
        parseClasses)
end

-- Each primary stat's tooltip GlobalString, by the GetItemStats key it answers for.
local PRIMARY_STAT_LINES = {
    ITEM_MOD_STRENGTH_SHORT = "ITEM_MOD_STRENGTH", ITEM_MOD_AGILITY_SHORT = "ITEM_MOD_AGILITY",
    ITEM_MOD_INTELLECT_SHORT = "ITEM_MOD_INTELLECT",
}

--- Every primary stat an item carries, as `{ [STAT_KEY] = n }`, read off its hyperlink tooltip with
--- the localized ITEM_MOD_* lines; nil when it shows none. GetItemStats answers the primary stat of
--- the spec playing alone, but the tooltip lists them all, the inactive ones grayed.
--- @param link string
--- @return table|nil
function Compat.ItemPrimaryStats(link)
    if not plainString(link) then return nil end
    local data = tooltipData("GetHyperlink", link)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local out
    for key, name in pairs(PRIMARY_STAT_LINES) do
        local fmt = globalString(name)
        local value = fmt and scanLines(data.lines, nil, function(text) return TextParse.StatLine(text, fmt) end)
        if value then
            out = out or {}
            out[key] = value
        end
    end
    return out
end

-- ── The Pawn seam (optional dependency; design spec §5.4) ───────────────────────────────────
-- Pawn is CC BY-NC-ND: its API is called, never copied. Every call is behind PawnIsReady and in
-- pcall (its error is never this addon's). Nil means "not ready yet": the scorer retries. The
-- shapes below are Pawn 2.13.6's (Pawn.lua; line numbers cite that file).

--- True when Pawn is loaded and has finished initializing: Pawn's own PawnIsReady() (line 4916),
--- which answers its file-local PawnIsInitialized (line 28; true, or nil while it initializes).
--- Without that function, a global PawnIsInitialized (flag or function) is read instead.
--- @return boolean
function Compat.PawnIsReady()
    local flag = type(PawnIsReady) == "function" and PawnIsReady or PawnIsInitialized
    if type(flag) == "function" then
        local ok, v = pcall(flag)
        return ok and v == true
    end
    return flag == true
end

-- pcall(fn, ...) when Pawn is ready and `fn` is a function; its first two returns, or nil.
local function pawnCall(fn, ...)
    if not (Compat.PawnIsReady() and type(fn) == "function") then return nil end
    local ok, v, w = pcall(fn, ...)
    if not ok then return nil end
    return v, w
end

--- Pawn's item object for a link (PawnGetItemData, line 1314), or nil while the item is not cached.
function Compat.PawnItemData(link)
    if not plainString(link) then return nil end
    return (pawnCall(PawnGetItemData, link))
end

--- Pawn's upgrade list for a link against YOUR gear (PawnIsItemAnUpgrade's first return, line
--- 3552): a list of `{ ScaleName, LocalizedScaleName, PercentUpgrade, ExistingItemLink }`, one per
--- visible scale it upgrades, empty when it upgrades nothing (Pawn answers nil); nil while not ready.
--- @return table|nil
function Compat.PawnUpgradeInfo(link)
    local data = Compat.PawnItemData(link)
    if data == nil then return nil end
    local list = pawnCall(PawnIsItemAnUpgrade, data)
    return type(list) == "table" and list or {}
end

--- The Pawn scale name for a class and spec, or nil when Pawn has none. `specID` is the client's
--- specID (71); Pawn's scales carry the spec's place in its class instead (Arms is 1;
--- PawnFindScaleForSpec, line 4531), so it is translated through NS.ClassData.SpecIndex.
--- @return string|nil
function Compat.PawnScaleForSpec(classID, specID)
    local index = classID and NS.ClassData.SpecIndex(specID)
    if index == nil then return nil end
    return (pawnCall(PawnFindScaleForSpec, classID, index))
end

-- Your visible scales for a class and spec index (PawnCommon.Scales and PawnIsScaleVisible, line
-- 5467): a scale that names another class or spec is skipped, and so is an abandoned provider's
-- (PawnGetAllScales, line 5168). A custom scale outranks a starter one, one that names your spec
-- outranks one that names none, and the name breaks a tie, so the answer never depends on order.
-- Whether a scale is one of yours for the class and spec index: it names neither another class nor
-- another spec, its provider (if any) is active, and Pawn shows it.
local function scaleFits(name, scale, classID, index)
    if type(name) ~= "string" or type(scale) ~= "table" then return false end
    if scale.ClassID ~= nil and scale.ClassID ~= classID then return false end
    if scale.SpecID ~= nil and scale.SpecID ~= index then return false end
    if scale.Provider ~= nil and not scale.ProviderActive then return false end
    return PawnIsScaleVisible(name) == true
end

-- A fitting scale's rank: a custom one (no provider) 2, one naming the spec 1 more.
local function scaleRank(scale, index)
    local r = scale.Provider == nil and 2 or 0
    if scale.SpecID == index then r = r + 1 end
    return r
end

local function visibleScale(classID, index)
    local scales = type(PawnCommon) == "table" and PawnCommon.Scales
    if type(scales) ~= "table" or type(PawnIsScaleVisible) ~= "function" then return nil end
    local best, rank
    for name, scale in pairs(scales) do
        local r = scaleFits(name, scale, classID, index) and scaleRank(scale, index)
        if r and (rank == nil or r > rank or (r == rank and name < best)) then best, rank = name, r end
    end
    return best
end

--- The Pawn scale YOU show in tooltips for your class and spec, or nil when none is visible: the
--- one Pawn itself values your gear on, your custom or imported scale included, where
--- PawnScaleForSpec answers a starter (provider) scale only. `specID` as PawnScaleForSpec's.
--- @return string|nil
function Compat.PawnVisibleScale(classID, specID)
    local index = classID and NS.ClassData.SpecIndex(specID)
    if index == nil then return nil end
    return (pawnCall(visibleScale, classID, index))
end

--- One item's value on scale `scale`, or nil while not ready. PawnGetSingleValueFromItem (line
--- 1663) answers the enchanted and the unenchanted value; the unenchanted one is kept, the value
--- Pawn's own upgrade test compares (PawnIsItemAnUpgrade), so worn enchants and gems do not
--- outweigh a bare drop. A Pawn that answers one value gives that one.
--- @return number|nil
function Compat.PawnItemValue(link, scale)
    if scale == nil then return nil end
    local data = Compat.PawnItemData(link)
    if data == nil then return nil end
    local v, unenchanted = pawnCall(PawnGetSingleValueFromItem, data, scale)
    if type(unenchanted) == "number" then return unenchanted end
    return type(v) == "number" and v or nil
end

-- ── Trade action (click-driven; the guards for range and combat are TradeHelper's, DW-29) ────

--- Opens a trade with `unit`. False when the API is absent.
--- @return boolean
function Compat.InitiateTrade(unit)
    if not InitiateTrade then return false end
    InitiateTrade(unit)
    return true
end

--- True when `unit` is within trade range (CheckInteractDistance, index 2). A secret answer is out
--- of range; with no API the range is not known and the trade is let through (the client refuses
--- one that is too far, with its own error). Read out of combat only: the trade helper refuses
--- combat first.
--- @return boolean
function Compat.InTradeRange(unit)
    if not CheckInteractDistance then return true end
    local v = CheckInteractDistance(unit, 2)
    if Compat.IsSecret(v) then return false end
    return v == true or v == 1
end

-- ── The trade window's contents (the history's trade completion, design spec §10) ───────────

-- The trade window's item slots that change hands: 1-6 (slot 7 is "will not be traded").
local TRADE_SLOTS = 6

-- The links one side's getter answers over the traded slots, plain strings only, in slot order.
local function tradeLinks(fn)
    local out = {}
    if not fn then return out end
    for i = 1, TRADE_SLOTS do
        local link = plainString(fn(i))
        if link and link ~= "" then out[#out + 1] = link end
    end
    return out
end

--- The items in the open trade window: what you give (GetTradePlayerItemLink) and what you get
--- (GetTradeTargetItemLink), slots 1-6, as lists of links. A secret, empty or absent answer is
--- left out; with no API both lists are empty.
--- @return table given, table received
function Compat.TradeItemLinks()
    return tradeLinks(GetTradePlayerItemLink), tradeLinks(GetTradeTargetItemLink)
end

--- Whether a UI_INFO_MESSAGE(messageType, message) is the client's "Trade complete.": its type is
--- LE_GAME_ERR_TRADE_COMPLETE, or (a client without that constant) its text is ERR_TRADE_COMPLETE.
--- False for a secret value, any other message, or neither global.
--- @param messageType any
--- @param message any
--- @return boolean
function Compat.IsTradeCompleteMessage(messageType, message)
    local id = plainNumber(LE_GAME_ERR_TRADE_COMPLETE)
    if id then return plainNumber(messageType) == id end
    local text = plainString(ERR_TRADE_COMPLETE)
    return text ~= nil and plainString(message) == text
end

--- Whom you are trading with (UnitName("NPC"), the trade window's partner unit), as `Name-Realm`
--- when the client names a realm, else `Name`. Nil for a secret or missing name.
--- @return string|nil
function Compat.TradePartnerName()
    if not UnitName then return nil end
    local name, realm = UnitName("NPC")
    name, realm = plainString(name), plainString(realm)
    if not name or name == "" then return nil end
    if realm and realm ~= "" then return name .. "-" .. realm end
    return name
end

--- Opens a context menu on `owner` with one button per entry ({ text, fn }), through
--- MenuUtil.CreateContextMenu. False when the client has no MenuUtil, so the caller acts directly.
--- @param owner table
--- @param entries table { { text = string, fn = function }, ... }
--- @return boolean
function Compat.ContextMenu(owner, entries)
    local fn = MenuUtil and MenuUtil.CreateContextMenu
    if not fn or type(entries) ~= "table" then return false end
    fn(owner, function(_, root)
        for _, e in ipairs(entries) do root:CreateButton(e.text, e.fn) end
    end)
    return true
end

-- ── The drop tables' item buttons and class colors (design spec §11.1) ──────────────────────

--- An item's icon texture (C_Item.GetItemIconByID, which takes an id or a link and needs no item
--- cache), or nil for no API, no item, or a secret or non-texture answer.
--- @param item number|string an item id or link
--- @return number|string|nil
function Compat.ItemIcon(item)
    local fn = C_Item and C_Item.GetItemIconByID
    if not fn or item == nil then return nil end
    local v = fn(item)
    if Compat.IsSecret(v) then return nil end
    if type(v) == "number" or type(v) == "string" then return v end
    return nil
end

--- A class's color as r, g, b: C_ClassColor.GetClassColor, then the RAID_CLASS_COLORS table. Nil
--- for an unknown class, a secret answer or neither source.
--- @param classFile string
--- @return number|nil r, number|nil g, number|nil b
function Compat.ClassColor(classFile)
    if type(classFile) ~= "string" or Compat.IsSecret(classFile) then return nil end
    local api = C_ClassColor and C_ClassColor.GetClassColor
    local c = api and api(classFile)
    if c == nil and type(RAID_CLASS_COLORS) == "table" then c = RAID_CLASS_COLORS[classFile] end
    if type(c) ~= "table" or Compat.IsSecret(c.r) or type(c.r) ~= "number" then return nil end
    return c.r, c.g, c.b
end

--- Puts `link` in the chat edit box (an item button's shift-click): ChatFrameUtil.InsertLink, the
--- newer spelling, then the ChatEdit_InsertLink global. True when one was called.
--- @param link string
--- @return boolean
function Compat.InsertChatLink(link)
    local util = ChatFrameUtil and ChatFrameUtil.InsertLink
    local fn = util or ChatEdit_InsertLink
    if type(link) ~= "string" or not fn then return false end
    fn(link)
    return true
end

--- Shows `link` in the dressing room (an item button's ctrl-click): DressUpItemLink, then the
--- older DressUpLink. True when one was called.
--- @param link string
--- @return boolean
function Compat.DressUpItem(link)
    local fn = DressUpItemLink or DressUpLink
    if type(link) ~= "string" or not fn then return false end
    fn(link)
    return true
end

--- A specialization's localized name (the detail card's looter spec): GetSpecializationInfoByID's
--- second return. Nil for no API, an unknown or non-number id, or a secret or empty answer.
--- @param specID number
--- @return string|nil
function Compat.SpecName(specID)
    if type(specID) ~= "number" or Compat.IsSecret(specID) then return nil end
    local fn = GetSpecializationInfoByID
    if not fn then return nil end
    local _, name = fn(specID)
    if Compat.IsSecret(name) or type(name) ~= "string" or name == "" then return nil end
    return name
end

-- ── The Encounter Journal (the simulator's item pool, simulator spec §3) ────────────────────
-- Reads and selections only; the save and restore, the async wait and the fallback are SimPool's.

--- The journal's selection: { shown, tiers, tier, difficulty, classID, specID, slot, instanceID,
--- encounterID, keystoneLevel } (shown and the two ids are the frame's, nil before it loads;
--- keystoneLevel is the loot preview's Mythic+ level, nil without GetPreviewMythicPlusLevel). Nil
--- without EJ_*.
--- @return table|nil
function Compat.JournalSelection()
    if not (EJ_GetNumTiers and EJ_GetCurrentTier and EJ_GetDifficulty and EJ_GetLootFilter) then return nil end
    local ej, frame = C_EncounterJournal, EncounterJournal
    local shown = frame and frame.IsShown and frame:IsShown()
    local classID, specID = EJ_GetLootFilter()
    return { shown = not Compat.IsSecret(shown) and shown == true, tiers = plainNumber(EJ_GetNumTiers()),
        tier = EJ_GetCurrentTier(), difficulty = EJ_GetDifficulty(), classID = classID, specID = specID,
        slot = ej and ej.GetSlotFilter and ej.GetSlotFilter(), instanceID = frame and frame.instanceID,
        encounterID = frame and frame.encounterID,
        keystoneLevel = ej and ej.GetPreviewMythicPlusLevel and plainNumber(ej.GetPreviewMythicPlusLevel()) }
end

local function journalExtras(ej, sel)
    if sel.encounterID and EJ_SelectEncounter then EJ_SelectEncounter(sel.encounterID) end
    if sel.slot == nil and ej.ResetSlotFilter then ej.ResetSlotFilter() end
    if sel.slot ~= nil and ej.SetSlotFilter then ej.SetSlotFilter(sel.slot) end
    -- The preview level is set only where it can be read back, so a save and restore can undo it.
    if sel.keystoneLevel and ej.GetPreviewMythicPlusLevel and ej.SetPreviewMythicPlusLevel then
        ej.SetPreviewMythicPlusLevel(sel.keystoneLevel)
    end
end

--- Select what `sel` names, in the journal's order: tier, instanceID, difficulty, the class filter
--- (classID 0 or nil: every class), encounterID, the slot filter (nil: every slot), the loot
--- preview's Mythic+ level (`keystoneLevel`, when the client can read it back). False without.
--- @return boolean
function Compat.JournalSelect(sel)
    if not (EJ_SelectTier and EJ_SelectInstance and EJ_SetDifficulty and EJ_SetLootFilter) then return false end
    if sel.tier then EJ_SelectTier(sel.tier) end
    if sel.instanceID then EJ_SelectInstance(sel.instanceID) end
    if sel.difficulty then EJ_SetDifficulty(sel.difficulty) end
    EJ_SetLootFilter(sel.classID or 0, sel.specID or 0)
    journalExtras(C_EncounterJournal or {}, sel)
    return true
end

--- The selected tier's instances as { { id, name, worldBoss } }: its raids when `isRaid`, else its
--- dungeons. `worldBoss` is true for the tier's world bosses, the one raid entry the journal shows
--- without a difficulty (EJ_GetInstanceInfo's ninth return, shouldDisplayDifficulty, false).
--- @return table
function Compat.JournalInstances(isRaid)
    local out = {}
    for i = 1, EJ_GetInstanceByIndex and 200 or 0 do
        local id, name = EJ_GetInstanceByIndex(i, isRaid == true)
        if not plainNumber(id) then break end
        local shows
        if isRaid == true and EJ_GetInstanceInfo then shows = select(9, EJ_GetInstanceInfo(id)) end
        out[#out + 1] = { id = id, name = plainString(name), worldBoss = shows == false or nil }
    end
    return out
end

--- An encounter's name (EJ_GetEncounterInfo's first return), or nil for no API, an unknown id or a
--- secret or empty answer.
--- @param encounterID number|nil
--- @return string|nil
function Compat.JournalEncounterName(encounterID)
    if not (plainNumber(encounterID) and EJ_GetEncounterInfo) then return nil end
    local name = plainString((EJ_GetEncounterInfo(encounterID)))
    return name ~= "" and name or nil
end

--- The selected instance's loot under the filters, { { itemID, link, encounterID } }, and how many
--- entries are not loaded yet (no link; EJ_LOOT_DATA_RECIEVED follows). Empty without the API.
--- @return table loot, number pending
function Compat.JournalLoot()
    local ej, out, pending = C_EncounterJournal, {}, 0
    if not (EJ_GetNumLoot and ej and ej.GetLootInfoByIndex) then return out, 0 end
    for i = 1, plainNumber(EJ_GetNumLoot()) or 0 do
        local info = ej.GetLootInfoByIndex(i)
        local link = type(info) == "table" and plainString(info.link)
        if link then out[#out + 1] = { itemID = plainNumber(info.itemID), link = link,
            encounterID = plainNumber(info.encounterID) } else pending = pending + 1 end
    end
    return out, pending
end
