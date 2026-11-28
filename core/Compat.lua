local _, NS = ...
-- core/Compat.lua — the root of the compat family (compat, design spec §4), the only caller of
-- version-variant, deprecated and optional client APIs; core/CompatClient.lua, core/CompatWorld.lua,
-- core/CompatItem.lua, core/CompatJournal.lua, core/CompatCollect.lua and core/CompatLoot.lua add reads to the same NS.Compat. Callers never name the client API. Every shim is tabled in
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
-- Of that major's readers, the client helpers and the character-name readers are routed below.
-- The player's spec, talent tree and the item, collection and Pawn reads the verdict engine makes
-- are LibKa0s-Verdict-1.0's own (lib.Reads), covered by the simulator's seam over the instance's
-- reads (core/VerdictSetup.lua, LibKa0s#111); this addon keeps no copy of them.

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

-- ── The client: LibKa0s-Compat-1.0's, with the stub arm (clients-§3) ─────────────────────────
-- The stub is the library's body, both constants read bare at call time; the nil guard keeps a
-- client with neither from reading as Forever. No other file reads a WOW_PROJECT_* global.

local function isForeverStub()
    return WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT
end

local function isRetailStub()
    return WOW_PROJECT_MAINLINE ~= nil and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and not isForeverStub()
end

local function clientKeyStub()
    if isForeverStub() then return "forever" end
    if isRetailStub() then return "retail" end
    return nil
end

local CLIENT_TOKENS = { retail = true, forever = true, both = true }

local function forClientStub(clients)
    if clients == nil or clients == "both" then return true end
    if type(clients) ~= "table" then error('ForClient: unknown client "' .. tostring(clients) .. '"', 2) end
    local key, hit = clientKeyStub(), false
    for _, token in ipairs(clients) do
        if not CLIENT_TOKENS[token] then error('ForClient: unknown client "' .. tostring(token) .. '"', 2) end
        hit = hit or token == "both" or token == key
    end
    return hit
end

--- Whether this is a WoW Forever client. Exactly one boolean.
Compat.IsForever = CompatLib and CompatLib.IsForever or isForeverStub

--- Whether this is a Retail client (the mainline project id and NOT Forever). Exactly one boolean.
Compat.IsRetail = CompatLib and CompatLib.IsRetail or isRetailStub

--- The client's key: "retail", "forever", or nil when the project constants say neither.
Compat.ClientKey = CompatLib and CompatLib.ClientKey or clientKeyStub

--- Whether a `clients` declaration (nil, "both", or an array of "retail" / "forever" / "both")
--- includes this client; nil means both (clients-§4). An unknown token raises on any client.
Compat.ForClient = CompatLib and CompatLib.ForClient or forClientStub

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

--- Whether character names are unique per region (LibKa0s Compat.RegionalNames, forever-quirks-§4):
--- true on WoW Forever, where a character is its first name and surname together and carries no
--- realm. The stub reads RegionalUniqueNamesEnabled itself; false where it is absent. One boolean.
--- @return boolean
Compat.RegionalNames = CompatLib and CompatLib.RegionalNames or function()
    return RegionalUniqueNamesEnabled ~= nil and RegionalUniqueNamesEnabled() == true
end

--- A unit's whole character name and its realm (LibKa0s Compat.UnitCharacterName, forever-quirks-§4):
--- "Traxex Silentshot" and a nil realm with regional names (WoW Forever); UnitName's name and realm
--- otherwise (the realm nil on the player's own). With the library absent, UnitName's first value,
--- and its second as the realm only without regional names: never a surname read as a realm. The
--- name is nil for no unit, a secret or ""; the realm nil for a secret or "".
--- @param unit string
--- @return string|nil name, string|nil realm
function Compat.UnitCharacterName(unit)
    local read = CompatLib and CompatLib.UnitCharacterName or UnitName
    if not (unit and read) then return nil end
    local name, realm = read(unit)
    name = plainString(name)
    if not name or name == "" then return nil end
    realm = plainString(realm)
    if realm == "" or (not CompatLib and Compat.RegionalNames()) then realm = nil end
    return name, realm
end

--- The player's character key, AceDB-3.0 40's (LibKa0s Compat.CharacterKey): "First Surname" with
--- regional names, "Name - Realm" otherwise. Nil until the client can answer, for a secret, and
--- with the library absent.
--- @return string|nil
function Compat.CharacterKey()
    if not (CompatLib and CompatLib.CharacterKey) then return nil end
    return plainString(CompatLib.CharacterKey())
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
-- The loot history (the feed's won group-loot drops, and everyone's rolls) is core/CompatLoot.lua's.

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
-- interface has C_Item), so they are deleted, not shimmed. Caching is libs/LibKa0s/VerdictFacts.lua's.

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

--- Which source answers the verdict engine's PlayerHasTransmog read now (LibKa0s-Verdict-1.0's
--- lib.Reads): "CanIMogIt", "C_TransmogCollection" or "none". For the diagnostics' integrations
--- section.
--- @return string
function Compat.TransmogSource()
    local cimi = CanIMogIt
    if type(cimi) == "table" and type(cimi.PlayerKnowsTransmog) == "function" then return "CanIMogIt" end
    local tc = C_TransmogCollection
    if tc and tc.PlayerHasTransmogByItemInfo then return "C_TransmogCollection" end
    return "none"
end

-- ── The Pawn seam (optional dependency; design spec §5.4) ───────────────────────────────────
-- Pawn is CC BY-NC-ND: its API is called, never copied. Every call is behind PawnIsReady and in
-- pcall (its error is never this addon's). Nil means "not ready yet": the scorer retries. Line
-- numbers cite Pawn 2.14.1's Pawn.lua (the WoW Forever install, Forever port research R4 §10);
-- the two that research did not re-read (PawnIsInitialized, PawnGetAllScales) still cite 2.13.6's.
--
-- THE SCALE INDEX. Pawn numbers a class's scales by their place in the class (Arms is 1); on WoW
-- Forever it has no specs and one Classic scale per talent tree, its SpecID the tree's index (the
-- Druid's are four: Balance 1, Feral 2 for damage and 3 to tank, Restoration 4). Both clients
-- translate through NS.ClassData.SpecIndex(specID, tree, role, classFile), the active list's:
-- Retail's answers by specID, Forever's by the talent tree's row.

--- True when Pawn is loaded and has finished initializing: Pawn's own PawnIsReady() (line 4949),
--- which answers its file-local PawnIsInitialized (2.13.6 line 28; true, or nil while it
--- initializes). Without that function, a global PawnIsInitialized (flag or function) is read instead.
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

-- The classFile of a classID, read off the active class list's CLASS_ID.
local function classFileOf(classID)
    for file, id in pairs(NS.ClassData.CLASS_ID or {}) do
        if id == classID then return file end
    end
    return nil
end

-- Pawn's scale index for a class, a spec and (on Forever) a talent tree and role; nil when unknown.
local function pawnIndex(classID, specID, tree, role)
    if classID == nil then return nil end
    return NS.ClassData.SpecIndex(specID, tree, role, classFileOf(classID))
end

--- The Pawn scale name for a class and spec, or nil when Pawn has none. `specID` is the client's
--- specID (71); Pawn's scales carry the spec's place in its class instead (Arms is 1;
--- PawnFindScaleForSpec, line 4565), so it is translated through NS.ClassData.SpecIndex. On WoW
--- Forever `tree` is the talent tree's index (the specID is class-wide) and `role` the role played
--- ("TANK" makes the Druid's Feral Pawn 3); with no tree there, there is no scale.
--- @return string|nil
function Compat.PawnScaleForSpec(classID, specID, tree, role)
    local index = pawnIndex(classID, specID, tree, role)
    if index == nil then return nil end
    return (pawnCall(PawnFindScaleForSpec, classID, index))
end

-- Your visible scales for a class and spec index (PawnCommon.Scales and PawnIsScaleVisible, line
-- 5500): a scale that names another class or spec is skipped, and so is an abandoned provider's
-- (PawnGetAllScales, 2.13.6 line 5168). A custom scale outranks a starter one, one that names your
-- spec outranks one that names none, and the name breaks a tie, so the answer never depends on
-- order. With no index (`index` nil) only a scale that names no spec fits.
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
    if index ~= nil and scale.SpecID == index then r = r + 1 end
    return r
end

local function visibleScale(classID, index, customOnly)
    local scales = type(PawnCommon) == "table" and PawnCommon.Scales
    if type(scales) ~= "table" or type(PawnIsScaleVisible) ~= "function" then return nil end
    local best, rank
    for name, scale in pairs(scales) do
        local fits = scaleFits(name, scale, classID, index) and not (customOnly and scale.Provider ~= nil)
        local r = fits and scaleRank(scale, index)
        if r and (rank == nil or r > rank or (r == rank and name < best)) then best, rank = name, r end
    end
    return best
end

--- The Pawn scale YOU show in tooltips for your class and spec, or nil when none is visible: the
--- one Pawn itself values your gear on, your custom or imported scale included, where
--- PawnScaleForSpec answers a starter (provider) scale only. The arguments as PawnScaleForSpec's.
--- @return string|nil
function Compat.PawnVisibleScale(classID, specID, tree, role)
    local index = pawnIndex(classID, specID, tree, role)
    if index == nil then return nil end
    return (pawnCall(visibleScale, classID, index))
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

--- The client's physical-pixel-to-UI-unit factor (PixelUtil.GetPixelToUIUnitFactor: 768 over the
--- screen's pixel height), or nil with no PixelUtil. Over a frame's effective scale it is one pixel
--- in that frame's units (the item icons' edge, R5-ICON).
--- @return number|nil
function Compat.PixelFactor()
    local pu = PixelUtil
    local fn = type(pu) == "table" and pu.GetPixelToUIUnitFactor
    if type(fn) ~= "function" then return nil end
    local v = fn()
    if type(v) ~= "number" or Compat.IsSecret(v) or v <= 0 then return nil end
    return v
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
