local _, NS = ...
-- core/Compat.lua — the only caller of version-variant, deprecated and optional client APIs
-- (compat, design spec §4). Feature modules call NS.Compat.X and never name the client API.
--
-- What lives here, in the order of the file:
--   * the secret guards (IsSecret, CanAccess, IsSafeKey), routed through LibKa0s-Compat-1.0, with
--     the one-rung bodies re-implemented for a library-absent load (that major's "Degradation");
--   * the chat sender (C_ChatInfo.SendChatMessage, then the deprecated global);
--   * the tooltip line reader (C_TooltipInfo, matched by Enum.TooltipDataLineType NAME, with a
--     localized-text fallback) and its three readers: the trade timer on a bag item, the item level
--     of an equipped item, and the upgrade track;
--   * the localized duration decoder behind the trade timer (spec §7.4);
--   * the restriction APIs (C_RestrictedActions, C_ChatInfo.InChatMessagingLockdown);
--   * the player's normalized realm (GetNormalizedRealmName, then GetRealmName) and own spec
--     (LibKa0s-Compat-1.0's GetSpecialization and GetSpecializationInfo);
--   * the bind helpers (C_Item's account binds, the bag item's GUID);
--   * the inventory and bag readers (GetInventoryItemLink, C_Container's slot count and link);
--   * the inspect calls (CanInspect, CheckInteractDistance, NotifyInspect and its hook,
--     ClearInspectPlayer, GetInspectSpecialization, the inventory item id, InspectFrame);
--   * the loot sources beside chat (C_LootHistory's won drops, a keystone's map name);
--   * the item readers behind the item facts (info, effective level, stats, specs, uniqueness,
--     transmog, the class restriction line);
--   * the Pawn seam (an optional dependency, every call behind PawnIsInitialized and pcall);
--   * the trade actions (PickupContainerItem, DropItemOnUnit, InitiateTrade).
--
-- THE RULES. Client globals are read bare and at CALL time, never captured at load, so a late
-- namespace still wins and a suite can swap any rung. A value that may be secret meets nothing but
-- IsSecret before it is compared, matched, concatenated or formatted. No member raises on a missing
-- API: each answers its documented "absent" value (nil, false or an empty table). Enum values are
-- resolved by name, never by number, because Blizzard renumbers enums.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)

-- ---------------------------------------------------------------------------------------------
-- Secret guards: LibKa0s-Compat-1.0
-- ---------------------------------------------------------------------------------------------
--
-- The library's answer, or the same one-rung body. A deliberate duplication: for a GUARD,
-- "the library is absent" is not "the client has no secrets system", so a stub answering
-- IsSecret -> false would send a secret into a comparison on exactly the degraded path. See
-- LibKa0s docs/api/Compat/version-1-docs.md, "Degradation". Of that major's six spell and spec
-- readers, the two spec readers are wired, behind PlayerSpecID (Identity, below); nothing here
-- reads a spell.

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

-- ---------------------------------------------------------------------------------------------
-- Chat sending
-- ---------------------------------------------------------------------------------------------

--- The function that sends one chat message, `(text, chatType, languageID, target)`, or nil where
--- the client has none. The bare SendChatMessage global is deprecated since 11.2.0 in favor of
--- C_ChatInfo.SendChatMessage, which takes the same arguments. The caller runs it inside pcall
--- (design spec §9.2 step 4); a nil here means the ask cannot be sent and says so.
--- @return function|nil
function Compat.ChatSender()
    local chat = C_ChatInfo
    if chat and chat.SendChatMessage then return chat.SendChatMessage end
    return SendChatMessage
end

-- ---------------------------------------------------------------------------------------------
-- Pattern building from localized GlobalStrings
-- ---------------------------------------------------------------------------------------------

-- Lua pattern magic characters, escaped.
local function escapePattern(s)
    return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

--- A Lua pattern from a printf-style GlobalString: `%s` captures text, `%d` captures digits, the
--- positional forms (`%1$s`) read as their plain spelling and every other character is literal.
--- Pure; exported for the tests and for modules/LootParser.lua, which recovers a positional
--- string's argument order itself.
--- @param fmt string
--- @return string
function Compat.FormatToPattern(fmt)
    local marked = fmt:gsub("%%%d+%$", "%%"):gsub("%%s", "\1"):gsub("%%d", "\2")
    return (escapePattern(marked):gsub("\1", "(.+)"):gsub("\2", "(%%d+)"))
end

-- Every spelling of a template's `|4singular:plural;` grammar (some locales carry three forms), as
-- a list of plain templates. A template without the grammar is its own one spelling.
local function expandPlural(template)
    local head, forms, tail = template:match("^(.-)|4([^;]*);(.*)$")
    if not head then return { template } end
    local out = {}
    for form in (forms .. ":"):gmatch("([^:]*):") do
        for _, rest in ipairs(expandPlural(tail)) do out[#out + 1] = head .. form .. rest end
    end
    return out
end

-- ---------------------------------------------------------------------------------------------
-- The duration decoder (design spec §7.4)
-- ---------------------------------------------------------------------------------------------
--
-- The client writes a remaining time as unit terms joined by TIME_UNIT_DELIMITER, each term
-- formatted from INT_SPELL_DURATION_<UNIT> ("%d |4hour:hrs;", "%d min", "%d sec" in enUS). The
-- decoder reads the text back with the same globals, so it works in every client language: it
-- walks the text from the left, matching one unit term anchored at the cursor, then skipping one
-- delimiter. Splitting on the delimiter instead would break, because a term ("2 hrs") can contain
-- it. Written here from that idea; no other addon's code was copied.

local DURATION_UNITS = {
    { name = "INT_SPELL_DURATION_DAYS",  seconds = 86400 },
    { name = "INT_SPELL_DURATION_HOURS", seconds = 3600 },
    { name = "INT_SPELL_DURATION_MIN",   seconds = 60 },
    { name = "INT_SPELL_DURATION_SEC",   seconds = 1 },
}

-- Every unit term as an anchored pattern with its multiplier, longest spelling first so "hrs" is
-- tried before a "hr" that is its prefix. Built per call: the globals may change under a locale
-- rewrite, and the trade timer reads a handful of items at most.
local function durationTerms()
    local terms = {}
    for _, unit in ipairs(DURATION_UNITS) do
        local template = globalString(unit.name)
        if template then
            for _, spelling in ipairs(expandPlural(template)) do
                terms[#terms + 1] = { spelling = spelling, seconds = unit.seconds,
                    pattern = "^" .. Compat.FormatToPattern(spelling) }
            end
        end
    end
    table.sort(terms, function(a, b) return #a.spelling > #b.spelling end)
    return terms
end

-- One unit term at `pos`: the seconds it is worth and the position after it, or nil.
local function matchTerm(text, pos, terms)
    for _, term in ipairs(terms) do
        local s, e, n = text:find(term.pattern, pos)
        if s and n then return tonumber(n) * term.seconds, e + 1 end
    end
    return nil
end

--- Seconds in a localized duration ("1 hour 59 min"), or nil when the text is not one. Every term
--- must be a known unit; anything left over makes the whole text unreadable rather than a guess.
--- @param text string
--- @return number|nil
function Compat.DecodeDuration(text)
    text = plainString(text)
    if not text then return nil end
    text = text:match("^%s*(.-)%s*$")
    local terms = durationTerms()
    if text == "" or #terms == 0 then return nil end
    local delim = globalString("TIME_UNIT_DELIMITER") or " "
    local total, pos = 0, 1
    while pos <= #text do
        local seconds, nextPos = matchTerm(text, pos, terms)
        if not seconds then return nil end
        total, pos = total + seconds, nextPos
        if text:sub(pos, pos + #delim - 1) == delim then pos = pos + #delim end
    end
    return total
end

--- Seconds left on a trade-time line (BIND_TRADE_TIME_REMAINING with its duration), or nil when
--- the text is not that line.
--- @param text string
--- @return number|nil
function Compat.ParseTradeTimeRemaining(text)
    text = plainString(text)
    local fmt = globalString("BIND_TRADE_TIME_REMAINING")
    if not (text and fmt) then return nil end
    local duration = text:match("^" .. Compat.FormatToPattern(fmt) .. "$")
    return duration and Compat.DecodeDuration(duration) or nil
end

-- ---------------------------------------------------------------------------------------------
-- The tooltip line reader
-- ---------------------------------------------------------------------------------------------

-- The numeric value of Enum.TooltipDataLineType[typeName], or nil when the client has no such
-- line type (then the reader falls back to the text).
local function lineTypeValue(typeName)
    local enum = Enum and Enum.TooltipDataLineType
    return enum and plainNumber(enum[typeName]) or nil
end

-- `parse(leftText)` for one line, guarded: a secret or missing text answers nil.
local function parseLine(line, parse)
    if type(line) ~= "table" then return nil end
    local text = plainString(line.leftText)
    if not text then return nil end
    return parse(text, line)
end

--- The parsed value of a tooltip's `typeName` line, or nil. With the line type known, only lines
--- of that type are parsed; without it (a client that renamed or dropped the enum member), every
--- line is offered to `parse` and the first non-nil answer wins, so `parse` must reject foreign
--- lines. `data` is a C_TooltipInfo result.
--- @param data table|nil
--- @param typeName string  an Enum.TooltipDataLineType member name
--- @param parse function   (leftText, line) -> value|nil
--- @return any
function Compat.ReadTooltipLine(data, typeName, parse)
    if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local wanted = lineTypeValue(typeName)
    for _, line in ipairs(data.lines) do
        local lineType = type(line) == "table" and plainNumber(line.type) or nil
        if wanted == nil or lineType == wanted then
            local value = parseLine(line, parse)
            if value ~= nil then return value end
        end
    end
    return nil
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
    if not fmt then return nil end
    local level = text:match("^" .. Compat.FormatToPattern(fmt))
    return tonumber(level)
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
    if not fmt then return nil end
    local track, cur, max = text:match("^" .. Compat.FormatToPattern(fmt) .. "$")
    if not (track and tonumber(cur) and tonumber(max)) then return nil end
    return { trackString = track, currentLevel = tonumber(cur), maxLevel = tonumber(max),
        source = "tooltip" }
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

-- ---------------------------------------------------------------------------------------------
-- Restrictions (12.0)
-- ---------------------------------------------------------------------------------------------

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

--- True when a restriction STATE (the second payload of ADDON_RESTRICTION_STATE_CHANGED, or
--- GetAddOnRestrictionState's answer) is anything but Inactive: Activating counts, because the
--- event fires just before the restriction bites. The event has been seen carrying a boolean
--- instead (docs/midnight-quirks.md), which answers itself. A secret state reads as active; a
--- missing or otherwise unreadable one as inactive.
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

-- ---------------------------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------------------------
-- Inventory and bags (the gear snapshot, design spec §4)
-- ---------------------------------------------------------------------------------------------

--- The link of the item `unit` wears in inventory slot `slot`, or nil (an empty slot, a secret
--- answer, or no API).
--- @return string|nil
function Compat.InventoryItemLink(unit, slot)
    if not GetInventoryItemLink then return nil end
    return plainString(GetInventoryItemLink(unit, slot))
end

-- C_Container[name] when present, else the deprecated global `fallback` (a function or nil).
local function containerApi(name, fallback)
    local container = C_Container
    if container and container[name] then return container[name] end
    return fallback
end

--- How many slots bag `bag` has: C_Container.GetContainerNumSlots, else the deprecated global. 0
--- for a missing bag, a secret answer or no API.
--- @return number
function Compat.BagSlotCount(bag)
    local fn = containerApi("GetContainerNumSlots", GetContainerNumSlots)
    if not fn then return 0 end
    return plainNumber(fn(bag)) or 0
end

--- The link of the item in bag `bag`, slot `slot`: C_Container.GetContainerItemLink, else the
--- deprecated global. Nil for an empty slot, a secret answer or no API.
--- @return string|nil
function Compat.BagItemLink(bag, slot)
    local fn = containerApi("GetContainerItemLink", GetContainerItemLink)
    if not fn then return nil end
    return plainString(fn(bag, slot))
end

-- ---------------------------------------------------------------------------------------------
-- Inspecting another player (the inspect broker, design spec §8)
-- ---------------------------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------------------------
-- The loot sources beside chat (the feed, design spec §3)
-- ---------------------------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------------------------
-- Bind helpers
-- ---------------------------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------------------------
-- Item readers (the item facts, design spec §4 and §5.1)
-- ---------------------------------------------------------------------------------------------
--
-- Each item reader takes a link, prefers C_Item's spelling and falls back to the deprecated
-- global, copies plain fields only and answers nil (or false) when the item is not cached yet or
-- the client has neither rung. Caching and the load retry are modules/ItemFacts.lua's.

-- C_Item[name] when present, else the global `fallback` (a function or nil).
local function itemApi(name, fallback)
    local item = C_Item
    if item and item[name] then return item[name] end
    return fallback
end

--- True when the client can be asked to load an item (C_Item.RequestLoadItemDataByID) and can
--- call back later (C_Timer.After): LibKa0s-Item-1.0's LoadItem is inert without either.
--- @return boolean
function Compat.CanRequestItemLoad()
    local item, timer = C_Item, C_Timer
    return (item and item.RequestLoadItemDataByID and timer and timer.After) and true or false
end

--- The cached fields of an item link: `{ name, quality, itemLevel, equipLoc, classID, subClassID,
--- bindType, setID }`, from C_Item.GetItemInfo, else the GetItemInfo global. Nil while the item
--- is not cached (the name is nil then), and for a secret or missing link.
--- @param link string
--- @return table|nil
function Compat.GetItemInfo(link)
    local fn = itemApi("GetItemInfo", GetItemInfo)
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
--- C_Item.GetDetailedItemLevelInfo, else the global. Nil when neither answers a number.
--- @param link string
--- @return number|nil
function Compat.GetDetailedItemLevel(link)
    local fn = itemApi("GetDetailedItemLevelInfo", GetDetailedItemLevelInfo)
    if not (fn and plainString(link)) then return nil end
    return plainNumber((fn(link)))
end

--- The stats of a link as `{ [STAT_KEY] = n }` (keys such as ITEM_MOD_STRENGTH_SHORT), from
--- C_Item.GetItemStats, else the global. A key the addon does not know is copied all the same;
--- secret keys and values are skipped. An empty table when the client answers nothing.
--- @param link string
--- @return table
function Compat.GetItemStats(link)
    local fn = itemApi("GetItemStats", GetItemStats)
    local out = {}
    if not (fn and plainString(link)) then return out end
    local stats = fn(link)
    if Compat.IsSecret(stats) or type(stats) ~= "table" then return out end
    for key, value in pairs(stats) do
        if plainString(key) and plainNumber(value) then out[key] = value end
    end
    return out
end

--- The specializations an item is for, as a set `{ [specID] = true }`, from C_Item.GetItemSpecInfo,
--- else the global. Nil when the client answers no list or an empty one (the item names no spec).
--- @param link string
--- @return table|nil
function Compat.GetItemSpecs(link)
    local fn = itemApi("GetItemSpecInfo", GetItemSpecInfo)
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

-- The GetItemUniqueness global's (family, maxEquipped); family -1 is the item's own uniqueness.
local function uniqueFromGlobal(link)
    local family, max = GetItemUniqueness(link)
    family, max = plainNumber(family), plainNumber(max)
    if family and family > 0 then return family, max or 1 end
    if family == -1 then return nil, max or 1 end
    return nil, nil
end

--- How many of this item (or of its unique category) may be equipped at once: `(categoryID,
--- max)`, with categoryID nil when the item is unique on its own. `(nil, nil)` when it is not
--- unique or the client has neither C_Item.GetItemUniquenessByID nor the global.
--- @param link string
--- @return number|nil categoryID, number|nil max
function Compat.GetItemUniqueness(link)
    if not plainString(link) then return nil, nil end
    local item = C_Item
    if item and item.GetItemUniquenessByID then return uniqueFromApi(item.GetItemUniquenessByID, link) end
    if GetItemUniqueness then return uniqueFromGlobal(link) end
    return nil, nil
end

--- Whether you have collected this item's appearance: C_TransmogCollection's
--- PlayerHasTransmogByItemInfo. Nil when the API is absent or the answer is secret.
--- @param link string
--- @return boolean|nil
function Compat.PlayerHasTransmog(link)
    local tc = C_TransmogCollection
    if not (tc and tc.PlayerHasTransmogByItemInfo and plainString(link)) then return nil end
    local known = tc.PlayerHasTransmogByItemInfo(link)
    if Compat.IsSecret(known) or type(known) ~= "boolean" then return nil end
    return known
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
    local list = text:match("^" .. Compat.FormatToPattern(fmt) .. "$")
    if not list then return nil end
    local delim = globalString("LIST_DELIMITER") or ", "
    local byName, set = classFilesByName(), nil
    for name in (list .. delim):gmatch("(.-)" .. escapePattern(delim)) do
        local classFile = byName[name]
        if classFile then
            set = set or {}
            set[classFile] = true
        end
    end
    return set
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

-- ---------------------------------------------------------------------------------------------
-- The Pawn seam (optional dependency; design spec §5.4)
-- ---------------------------------------------------------------------------------------------
--
-- Pawn is CC BY-NC-ND: its API is called, its code is never copied. Every call is behind
-- PawnIsReady and runs under pcall, because a third-party addon's error must not become this
-- addon's. Nil from a reader means "not ready yet": the scorer answers `pending` and retries.

--- True when Pawn is loaded and has finished initializing. PawnIsInitialized is a global flag in
--- Pawn; a function spelling is accepted too.
--- @return boolean
function Compat.PawnIsReady()
    local flag = PawnIsInitialized
    if type(flag) == "function" then
        local ok, v = pcall(flag)
        return ok and v == true
    end
    return flag == true
end

-- pcall(fn, ...) when Pawn is ready and `fn` is a function; the first return, or nil.
local function pawnCall(fn, ...)
    if not (Compat.PawnIsReady() and type(fn) == "function") then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return v
end

--- Pawn's item object for a link, or nil while the item is not cached.
function Compat.PawnItemData(link)
    if not plainString(link) then return nil end
    return pawnCall(PawnGetItemData, link)
end

--- Pawn's upgrade list for a link against YOUR gear: a list of `{ ScaleName, LocalizedScaleName,
--- PercentUpgrade, ExistingItemLink }`, empty when it upgrades nothing; nil while not ready.
--- @return table|nil
function Compat.PawnUpgradeInfo(link)
    local data = Compat.PawnItemData(link)
    if data == nil then return nil end
    local list = pawnCall(PawnIsItemAnUpgrade, data)
    return type(list) == "table" and list or {}
end

--- The Pawn scale name for a class and spec, or nil when Pawn has none.
--- @return string|nil
function Compat.PawnScaleForSpec(classID, specID)
    return pawnCall(PawnFindScaleForSpec, classID, specID)
end

--- One item's value on scale `scale`, or nil while not ready.
--- @return number|nil
function Compat.PawnItemValue(link, scale)
    if scale == nil then return nil end
    local data = Compat.PawnItemData(link)
    if data == nil then return nil end
    local v = pawnCall(PawnGetSingleValueFromItem, data, scale)
    return type(v) == "number" and v or nil
end

-- ---------------------------------------------------------------------------------------------
-- Trade actions (click-driven; the guards for range and combat are TradeHelper's, DW-29)
-- ---------------------------------------------------------------------------------------------

--- Picks up the item in bag `bag`, slot `slot` onto the cursor. C_Container's spelling first, the
--- deprecated global second. False when the client has neither.
--- @return boolean
function Compat.PickupBagItem(bag, slot)
    local container = C_Container
    if container and container.PickupContainerItem then
        container.PickupContainerItem(bag, slot)
        return true
    end
    if PickupContainerItem then
        PickupContainerItem(bag, slot)
        return true
    end
    return false
end

--- Drops the cursor item on `unit`, which opens a trade with it. False when the API is absent.
--- @return boolean
function Compat.DropItemOnUnit(unit)
    if not DropItemOnUnit then return false end
    DropItemOnUnit(unit)
    return true
end

--- Opens a trade with `unit`. False when the API is absent.
--- @return boolean
function Compat.InitiateTrade(unit)
    if not InitiateTrade then return false end
    InitiateTrade(unit)
    return true
end
