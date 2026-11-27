-- LibKa0s-Verdict-1.0 -- the client reads an instance makes, as `lib.Reads`: the item cache, the
-- worn and bagged items, the tooltip lines, the collections, the talent tree and role, and the Pawn
-- seam. Moved from Ka0s Drop Watcher's compat family (core/Compat.lua, core/CompatClient.lua,
-- core/CompatWorld.lua, core/CompatItem.lua, core/CompatCollect.lua) and the tooltip line parsers of
-- its core/TextParse.lua (DropWatcher#19), each member under the name it had on Drop Watcher's
-- NS.Compat, so a host hands its own compat members over one for one.
--
-- THE OVERRIDE. An instance never calls these directly: every read it makes is
-- `host.reads[name] or lib.Reads[name]`, looked up at call time (Verdict.lua's `v.R`), so a host
-- that keeps its own seam over a read (Drop Watcher's simulator guards its compat members) hands
-- that member in `host.reads` and the instance reads through it. A member's arguments and answers
-- are Drop Watcher's, so its compat member is a drop-in. Two take a trailing `client` it did not
-- (PawnScaleForSpec, PawnVisibleScale: the class list Pawn's spec index is read from), which a
-- host's member may ignore. PlayerRole reads LibKa0s-Role-1.0 with no store (no override, no saved
-- answer); a host with a role store hands its own.
--
-- THE RULES are Drop Watcher's compat rules: every client global is read bare at CALL time, never
-- captured at load; a value that may be secret meets nothing but IsSecret before it is compared,
-- matched or concatenated; no member raises on a missing API, each answers its documented "absent"
-- value (nil, false, 0 or an empty table); enum values are resolved by name. Pawn and CanIMogIt are
-- optional addons, called (never copied), each call in pcall, so their error is never the host's.
-- Client reads inside a library major need no compat file in the consumer (compat binds the calls a
-- consumer makes outside the library's majors).
--
-- Depends on the Verdict shell (Verdict.lua) and VerdictClassData.lua; LibKa0s-Compat-1.0 (IsSecret),
-- LibKa0s-Item-1.0 (the link helpers and the item load) and LibKa0s-Role-1.0 (the spec, the talent
-- groups and the role) are read at call time, each optional.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.ClassData then return end

local READS_MINOR = 1
-- Minor 1 (DropWatcher#19, task B2): Drop Watcher's compat reads the verdict engine makes.
if lib.__readsMinor and lib.__readsMinor >= READS_MINOR
  and lib.__readsShellMinor == lib.MINOR then return end
lib.__readsMinor      = READS_MINOR
lib.__readsShellMinor = lib.MINOR

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictReads = READS_MINOR

local R = {}
lib.Reads = R

-- The sibling majors, looked up at call time (a host may load them after this file).
local function compatLib() return LibStub("LibKa0s-Compat-1.0", true) end
local function itemLib() return LibStub("LibKa0s-Item-1.0", true) end
local function roleLib() return LibStub("LibKa0s-Role-1.0", true) end

-- ---------------------------------------------------------------------------------------------
-- Secret guards and plain values
-- ---------------------------------------------------------------------------------------------

--- True when `v` is a 12.0 secret value: LibKa0s-Compat-1.0's answer, else the same one-rung body.
--- @return boolean
function R.IsSecret(v)
  local c = compatLib()
  if c and c.IsSecret then return c.IsSecret(v) end
  return issecretvalue ~= nil and issecretvalue(v) and true or false
end

local function plainString(v)
  if R.IsSecret(v) or type(v) ~= "string" then return nil end
  return v
end

local function plainNumber(v)
  if R.IsSecret(v) or type(v) ~= "number" then return nil end
  return v
end

local function plainBool(v)
  if R.IsSecret(v) or type(v) ~= "boolean" then return nil end
  return v
end

-- A positive plain number (an item, mount or species id), or nil.
local function plainId(v)
  v = plainNumber(v)
  return v and v > 0 and v or nil
end

--- The client's GlobalString `name`, raw, read at call time; nil for a non-string name.
--- @param name any
--- @return any
function R.GlobalString(name)
  if type(name) ~= "string" then return nil end
  return _G[name]
end

-- A localized GlobalString by name; nil when absent, empty or secret.
local function globalString(name)
  local s = plainString(R.GlobalString(name))
  if s == nil or s == "" then return nil end
  return s
end

-- ---------------------------------------------------------------------------------------------
-- The tooltip line parsers (Drop Watcher's core/TextParse.lua, its tooltip part; pure)
-- ---------------------------------------------------------------------------------------------

local function escapePattern(s)
  return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- A Lua pattern from a printf-style GlobalString: `%s` captures text, `%d` digits, the positional
-- forms read as their plain spelling, every other character literal.
local function formatToPattern(fmt)
  local marked = fmt:gsub("%%%d+%$", "%%"):gsub("%%s", "\1"):gsub("%%d", "\2")
  return (escapePattern(marked):gsub("\1", "(.+)"):gsub("\2", "(%%d+)"))
end

local function parseLevelText(text, fmt)
  return tonumber(text:match("^" .. formatToPattern(fmt)))
end

-- The value on a stat line (ITEM_MOD_AGILITY's "%c%s Agility", `%c` the sign), its grouping
-- marks dropped ("+1,689" reads 1689), or nil.
local function parseStatLine(text, fmt)
  local pattern = formatToPattern((fmt:gsub("%%c", "\3"))):gsub("\3", "[%%+%%-]")
  local value = text:match("^" .. pattern .. "$")
  if not value then return nil end
  return tonumber((value:gsub("%D", "")))
end

local function parseUpgradeText(text, fmt)
  local track, cur, max = text:match("^" .. formatToPattern(fmt) .. "$")
  if not (track and tonumber(cur) and tonumber(max)) then return nil end
  return { trackString = track, currentLevel = tonumber(cur), maxLevel = tonumber(max), source = "tooltip" }
end

local function parseClassSet(text, fmt, delim, byName)
  local list = text:match("^" .. formatToPattern(fmt) .. "$")
  if not list then return nil end
  delim = delim or ", "
  local map, set = byName(), nil
  for name in (list .. delim):gmatch("(.-)" .. escapePattern(delim)) do
    local classFile = map[name]
    if classFile then
      set = set or {}
      set[classFile] = true
    end
  end
  return set
end

-- The first non-nil `parse(text, line)` over the lines whose type is `wanted` (every line when nil).
local function scanLines(lines, wanted, parse)
  for _, line in ipairs(lines) do
    if type(line) == "table" then
      local text = plainString(line.leftText)
      if text and (wanted == nil or plainNumber(line.type) == wanted) then
        local value = parse(text, line)
        if value ~= nil then return value end
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------------------------
-- The tooltip line reader
-- ---------------------------------------------------------------------------------------------

local function lineTypeValue(typeName)
  local enum = Enum and Enum.TooltipDataLineType
  return enum and plainNumber(enum[typeName]) or nil
end

--- The parsed value of a tooltip's `typeName` line, or nil: the lines of that type first, then
--- every line, first non-nil answer wins. `data` is a C_TooltipInfo result.
--- @param data table|nil
--- @param typeName string an Enum.TooltipDataLineType member name
--- @param parse function (leftText, line) -> value|nil
--- @return any
function R.ReadTooltipLine(data, typeName, parse)
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

-- An item's hyperlink tooltip data, or nil: no API, a secret link or a secret or malformed answer.
local function hyperlinkData(link)
  if not plainString(link) then return nil end
  local data = tooltipData("GetHyperlink", link)
  if R.IsSecret(data) or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  return data
end

-- True when any line carries a secret left text: "no such line" could not be told from "a line we
-- may not read".
local function anySecretLine(data)
  for _, line in ipairs(data.lines) do
    if type(line) == "table" and R.IsSecret(line.leftText) then return true end
  end
  return false
end

-- ---------------------------------------------------------------------------------------------
-- Worn items, bags and the item cache
-- ---------------------------------------------------------------------------------------------

local function parseItemLevel(text, line)
  local n = plainNumber(line.itemLevel)
  if n then return n end
  local fmt = globalString("ITEM_LEVEL")
  return fmt and parseLevelText(text, fmt) or nil
end

--- The item level of `unit`'s item in inventory slot `slot`, off its tooltip's ItemLevel line, or nil.
--- @return number|nil
function R.InventoryItemLevel(unit, slot)
  return R.ReadTooltipLine(tooltipData("GetInventoryItem", unit, slot), "ItemLevel", parseItemLevel)
end

--- The link of the item `unit` wears in slot `slot`, or nil (empty, secret, no API).
--- @return string|nil
function R.InventoryItemLink(unit, slot)
  if not GetInventoryItemLink then return nil end
  return plainString(GetInventoryItemLink(unit, slot))
end

local function containerApi(name)
  local container = C_Container
  return container and container[name] or nil
end

--- How many slots bag `bag` has; 0 for a missing bag, a secret answer or no API.
--- @return number
function R.BagSlotCount(bag)
  local fn = containerApi("GetContainerNumSlots")
  if not fn then return 0 end
  return plainNumber(fn(bag)) or 0
end

--- The link of the item in bag `bag`, slot `slot`, or nil.
--- @return string|nil
function R.BagItemLink(bag, slot)
  local fn = containerApi("GetContainerItemLink")
  if not fn then return nil end
  return plainString(fn(bag, slot))
end

--- The exact item level and quality of the item in bag `bag`, slot `slot` (its ItemLocation); each
--- nil for an empty slot, a secret or missing answer, or no API.
--- @return number|nil level, number|nil quality
function R.BagItemLevelQuality(bag, slot)
  local item, loc = C_Item, ItemLocation
  if not (item and loc and loc.CreateFromBagAndSlot) then return nil, nil end
  if type(bag) ~= "number" or type(slot) ~= "number" then return nil, nil end
  local location = loc:CreateFromBagAndSlot(bag, slot)
  if item.DoesItemExist and not item.DoesItemExist(location) then return nil, nil end
  local level = item.GetCurrentItemLevel and plainNumber(item.GetCurrentItemLevel(location)) or nil
  local quality = item.GetItemQuality and plainNumber(item.GetItemQuality(location)) or nil
  return level, quality
end

local function itemApi(name)
  local item = C_Item
  return item and item[name] or nil
end

-- C_Item.<fn>(link) as a plain boolean; false when absent or secret.
local function itemFlag(fn, link)
  local f = itemApi(fn)
  if not (f and plainString(link)) then return false end
  local v = f(link)
  if R.IsSecret(v) then return false end
  return v == true
end

--- True when the item binds to the account (warbound).
function R.IsItemBindToAccount(link) return itemFlag("IsItemBindToAccount", link) end

--- True when the item is warbound until equipped.
function R.IsItemBindToAccountUntilEquip(link) return itemFlag("IsItemBindToAccountUntilEquip", link) end

--- An item link's equip location from C_Item.GetItemInfoInstant (no item cache needed), or nil.
--- @return string|nil
function R.ItemEquipLoc(link)
  local fn = itemApi("GetItemInfoInstant")
  if not (fn and plainString(link)) then return nil end
  local _, _, _, equipLoc = fn(link)
  return plainString(equipLoc)
end

--- True when the client can be asked to load an item and call back later.
--- @return boolean
function R.CanRequestItemLoad()
  local item, timer = C_Item, C_Timer
  return (item and item.RequestLoadItemDataByID and timer and timer.After) and true or false
end

--- The cached fields of a link, `{ name, quality, itemLevel, equipLoc, classID, subClassID,
--- bindType, setID }`; nil while the item is not cached, and for a secret or missing link.
--- @return table|nil
function R.GetItemInfo(link)
  local fn = itemApi("GetItemInfo")
  if not (fn and plainString(link)) then return nil end
  local name, _, quality, itemLevel, _, _, _, _, equipLoc, _, _, classID, subClassID, bindType,
    _, setID = fn(link)
  name = plainString(name)
  if not name then return nil end
  return {
    name = name, quality = plainNumber(quality), itemLevel = plainNumber(itemLevel),
    equipLoc = plainString(equipLoc), classID = plainNumber(classID),
    subClassID = plainNumber(subClassID), bindType = plainNumber(bindType), setID = plainNumber(setID),
  }
end

--- The effective item level of a link (C_Item.GetDetailedItemLevelInfo), or nil.
--- @return number|nil
function R.GetDetailedItemLevel(link)
  local fn = itemApi("GetDetailedItemLevelInfo")
  if not (fn and plainString(link)) then return nil end
  return plainNumber((fn(link)))
end

--- The stats of a link as `{ [STAT_KEY] = n }`; secret keys and values skipped; empty when none.
--- @return table
function R.GetItemStats(link)
  local fn = itemApi("GetItemStats")
  local out = {}
  if not (fn and plainString(link)) then return out end
  local stats = fn(link)
  if R.IsSecret(stats) or type(stats) ~= "table" then return out end
  for key, value in pairs(stats) do
    if plainString(key) and plainNumber(value) then out[key] = value end
  end
  return out
end

--- The specializations an item is for, `{ [specID] = true }`; nil for no list or an empty one.
--- @return table|nil
function R.GetItemSpecs(link)
  local fn = itemApi("GetItemSpecInfo")
  if not (fn and plainString(link)) then return nil end
  local list = fn(link)
  if R.IsSecret(list) or type(list) ~= "table" then return nil end
  local set
  for _, specID in ipairs(list) do
    if plainNumber(specID) then
      set = set or {}
      set[specID] = true
    end
  end
  return set
end

--- How many of this item (or of its unique category) may be equipped: `(categoryID, max)`,
--- categoryID nil when unique on its own; `(nil, nil)` when not unique or with no API.
--- @return number|nil categoryID, number|nil max
function R.GetItemUniqueness(link)
  local fn = itemApi("GetItemUniquenessByID")
  if not (fn and plainString(link)) then return nil, nil end
  local isUnique, _, count, catID = fn(link)
  catID, count = plainNumber(catID), plainNumber(count)
  if catID and catID > 0 then return catID, count or 1 end
  if not R.IsSecret(isUnique) and isUnique == true then return nil, 1 end
  return nil, nil
end

local function parseUpgradeLine(text)
  local fmt = globalString("ITEM_UPGRADE_TOOLTIP_FORMAT_STRING")
  return fmt and parseUpgradeText(text, fmt) or nil
end

local function upgradeFromApi(link)
  local fn = itemApi("GetItemUpgradeInfo")
  if not fn then return nil end
  local info = fn(link)
  if R.IsSecret(info) or type(info) ~= "table" then return nil end
  return {
    currentLevel = plainNumber(info.currentLevel), maxLevel = plainNumber(info.maxLevel),
    maxItemLevel = plainNumber(info.maxItemLevel), trackString = plainString(info.trackString),
    trackStringID = plainNumber(info.trackStringID), source = "api",
  }
end

--- The upgrade track of a link, `{ trackString, trackStringID, currentLevel, maxLevel, maxItemLevel,
--- source }`: C_Item.GetItemUpgradeInfo, else the tooltip's ItemUpgradeLevel line; nil for none.
--- @return table|nil
function R.GetItemUpgradeInfo(link)
  if not plainString(link) then return nil end
  local info = upgradeFromApi(link)
  if info and info.trackString then return info end
  return R.ReadTooltipLine(tooltipData("GetHyperlink", link), "ItemUpgradeLevel", parseUpgradeLine)
end

-- CanIMogIt (an optional addon): `CanIMogIt:Method(link)` in pcall; nil for anything not a boolean.
local function canIMogIt(method, link)
  local cimi = CanIMogIt
  local fn = type(cimi) == "table" and cimi[method]
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, cimi, link)
  if not ok or R.IsSecret(v) or type(v) ~= "boolean" then return nil end
  return v
end

--- Whether you have collected this item's appearance: CanIMogIt's answer when loaded, else
--- C_TransmogCollection's. Nil when neither answers, or CanIMogIt says it has no appearance.
--- @return boolean|nil
function R.PlayerHasTransmog(link)
  if not plainString(link) then return nil end
  if canIMogIt("IsTransmogable", link) == false then return nil end
  local known = canIMogIt("PlayerKnowsTransmog", link)
  if known ~= nil then return known end
  local tc = C_TransmogCollection
  if not (tc and tc.PlayerHasTransmogByItemInfo) then return nil end
  return plainBool(tc.PlayerHasTransmogByItemInfo(link))
end

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

local function parseClasses(text)
  local fmt = globalString("ITEM_CLASSES_ALLOWED")
  if not fmt then return nil end
  return parseClassSet(text, fmt, globalString("LIST_DELIMITER"), classFilesByName)
end

--- The classes an item is restricted to, `{ [classFile] = true }`, off its RestrictedRaceClass line.
--- @return table|nil
function R.ItemClassRestriction(link)
  if not plainString(link) then return nil end
  return R.ReadTooltipLine(tooltipData("GetHyperlink", link), "RestrictedRaceClass", parseClasses)
end

local PRIMARY_STAT_LINES = {
  ITEM_MOD_STRENGTH_SHORT = "ITEM_MOD_STRENGTH", ITEM_MOD_AGILITY_SHORT = "ITEM_MOD_AGILITY",
  ITEM_MOD_INTELLECT_SHORT = "ITEM_MOD_INTELLECT",
}

--- Every primary stat an item carries, `{ [STAT_KEY] = n }`, off its tooltip's ITEM_MOD_* lines;
--- nil when it shows none (GetItemStats answers the playing spec's alone).
--- @return table|nil
function R.ItemPrimaryStats(link)
  if not plainString(link) then return nil end
  local data = tooltipData("GetHyperlink", link)
  if type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
  local out
  for key, name in pairs(PRIMARY_STAT_LINES) do
    local fmt = globalString(name)
    local value = fmt and scanLines(data.lines, nil, function(text) return parseStatLine(text, fmt) end)
    if value then
      out = out or {}
      out[key] = value
    end
  end
  return out
end

-- ---------------------------------------------------------------------------------------------
-- The player: class, level, spec, talent tree and role
-- ---------------------------------------------------------------------------------------------

--- UnitClass(unit), raw: localized name, classFile, classID.
function R.UnitClass(unit)
  if not UnitClass then return nil end
  return UnitClass(unit)
end

--- UnitLevel(unit) as a plain level: nil for a secret, a non-number, 0 or less, or no API.
--- @return number|nil
function R.UnitLevel(unit)
  if not UnitLevel then return nil end
  local level = UnitLevel(unit)
  if R.IsSecret(level) or type(level) ~= "number" or level <= 0 then return nil end
  return level
end

--- The player's specialization id: LibKa0s-Role-1.0's Spec() (class-wide on WoW Forever), else
--- LibKa0s-Compat-1.0's spec pair; nil before the client knows, for a secret, or with neither.
--- @return number|nil
function R.PlayerSpecID()
  local role = roleLib()
  if role and role.Spec then return plainNumber((role.Spec())) end
  local c = compatLib()
  if not (c and c.GetSpecialization and c.GetSpecializationInfo) then return nil end
  local index = plainNumber(c.GetSpecialization())
  if not index then return nil end
  return plainNumber((c.GetSpecializationInfo(index)))
end

--- The player's talent tree on WoW Forever: the LibKa0s-Role-1.0 group with the most points, as
--- `{ index, name }`; nil on Retail, on a tie, with no points, and without the library.
--- @return table|nil
function R.PlayerTalentTree()
  local role = roleLib()
  if not (role and role.Groups) then return nil end
  local best, tied
  for _, group in ipairs(role.Groups()) do
    local spent = plainNumber(group.spent) or 0
    if spent > 0 and (not best or spent > best.spent) then
      best, tied = { index = group.index, name = plainString(group.name), spent = spent }, false
    elseif best and spent == best.spent then
      tied = true
    end
  end
  if not best or tied then return nil end
  return { index = best.index, name = best.name }
end

--- A specialization's localized name (the settings section's spec strip): GetSpecializationInfoByID's
--- second return. Nil for no API, an unknown or non-number id, or a secret or empty answer.
--- @param specID number
--- @return string|nil
function R.SpecName(specID)
  if type(specID) ~= "number" or R.IsSecret(specID) then return nil end
  local fn = GetSpecializationInfoByID
  if not fn then return nil end
  local _, name = fn(specID)
  name = plainString(name)
  if not name or name == "" then return nil end
  return name
end

--- The player's talent trees' names on WoW Forever, by their index in display order
--- (LibKa0s-Role-1.0's Groups()): `{ [index] = name }`, a name the client does not give left out.
--- Empty on Retail and without the library (the settings section's spec strip).
--- @return table
function R.TalentTreeNames()
  local out = {}
  local role = roleLib()
  if not (role and role.Groups) then return out end
  for _, group in ipairs(role.Groups()) do
    local name = plainString(group.name)
    if type(group.index) == "number" and name and name ~= "" then out[group.index] = name end
  end
  return out
end

--- The role the player plays: LibKa0s-Role-1.0's Resolve with no store (no override, no saved
--- answer), else the group's assignment. `role, source, detail`, each nil when unknown.
--- @return string|nil, string|nil, string|nil
function R.PlayerRole()
  local role = roleLib()
  if role and role.Resolve then return role.Resolve(nil) end
  local assigned = UnitGroupRolesAssigned and plainString(UnitGroupRolesAssigned("player")) or nil
  if assigned == "TANK" or assigned == "HEALER" or assigned == "DAMAGER" then return assigned, "assigned", nil end
  return nil, nil, nil
end

-- ---------------------------------------------------------------------------------------------
-- The collections
-- ---------------------------------------------------------------------------------------------

--- The mount an item teaches, or nil.
function R.MountFromItem(itemID)
  local mj = C_MountJournal
  if not (plainId(itemID) and mj and mj.GetMountFromItem) then return nil end
  return plainId(mj.GetMountFromItem(itemID))
end

--- Whether the account has collected a mount (GetMountInfoByID's 11th return), or nil.
function R.MountCollected(mountID)
  local mj = C_MountJournal
  if not (plainId(mountID) and mj and mj.GetMountInfoByID) then return nil end
  return plainBool((select(11, mj.GetMountInfoByID(mountID))))
end

--- The battle pet species a companion item teaches (GetPetInfoByItemID's 13th return), or nil.
function R.PetSpeciesFromItem(itemID)
  local pj = C_PetJournal
  if not (plainId(itemID) and pj and pj.GetPetInfoByItemID) then return nil end
  return plainId((select(13, pj.GetPetInfoByItemID(itemID))))
end

--- How many of a species the account has and may have, or nil, nil.
function R.PetCollected(speciesID)
  local pj = C_PetJournal
  if not (plainId(speciesID) and pj and pj.GetNumCollectedInfo) then return nil, nil end
  local count, limit = pj.GetNumCollectedInfo(speciesID)
  count, limit = plainNumber(count), plainNumber(limit)
  if not count then return nil, nil end
  return count, limit
end

--- True when an item is a toy (C_ToyBox.GetToyInfo answers it).
function R.IsToy(itemID)
  local tb = C_ToyBox
  if not (plainId(itemID) and tb and tb.GetToyInfo) then return false end
  local id = tb.GetToyInfo(itemID)
  if R.IsSecret(id) then return false end
  return id ~= nil
end

--- Whether the account has a toy, or nil.
function R.ToyCollected(itemID)
  if not (plainId(itemID) and PlayerHasToy) then return nil end
  return plainBool(PlayerHasToy(itemID))
end

--- True when the client flags an item cosmetic.
function R.IsCosmeticItem(link)
  local fn = itemApi("IsCosmeticItem")
  if not (fn and plainString(link)) then return false end
  return plainBool(fn(link)) == true
end

--- Whether a recipe is already known: true for a line that EQUALS ITEM_SPELL_KNOWN, false when the
--- tooltip was read with none, nil when it could not be read (or a line is secret).
--- @return boolean|nil
function R.RecipeKnown(link)
  local known = plainString(R.GlobalString("ITEM_SPELL_KNOWN"))
  if not (known and known ~= "") then return nil end
  local data = hyperlinkData(link)
  if not data or anySecretLine(data) then return nil end
  return R.ReadTooltipLine(data, "None", function(text) return text == known or nil end) == true
end

--- The skill lines of the player's professions, `{ [skillLine] = true }`: empty for none, nil for
--- no answer (no API, or a slot whose index or line is secret or unreadable).
--- @return table|nil
function R.ProfessionSkillLines()
  if not (GetProfessions and GetProfessionInfo) then return nil end
  local indices, out = { GetProfessions() }, {}
  for i = 1, 5 do
    if indices[i] ~= nil then
      local index = plainId(indices[i])
      local line = index and plainId((select(7, GetProfessionInfo(index))))
      if not line then return nil end
      out[line] = true
    end
  end
  return out
end

-- The slots a tier token can make, by the GlobalString that names each.
local TOKEN_SLOT_STRINGS = { "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_HAND", "INVTYPE_LEGS" }

--- The slot a tier token's tooltip names: the INVTYPE_* key of the first line that EQUALS one of
--- the localized slot names, or nil.
--- @return string|nil
function R.TierTokenSlot(link)
  local data = hyperlinkData(link)
  if not data then return nil end
  local names = {}
  for _, key in ipairs(TOKEN_SLOT_STRINGS) do
    local text = plainString(R.GlobalString(key))
    if text and text ~= "" then names[text] = key end
  end
  return R.ReadTooltipLine(data, "None", function(text) return names[text] end)
end

--- Whether an item opens: `locked` for a line that EQUALS LOCKED, `opens` for ITEM_OPENABLE, false
--- once read with neither; nil when it could not be read.
--- @return string|false|nil
function R.ItemOpens(link)
  local locked = plainString(R.GlobalString("LOCKED"))
  local openable = plainString(R.GlobalString("ITEM_OPENABLE"))
  local data = (locked or openable) and hyperlinkData(link)
  if not data or anySecretLine(data) then return nil end
  return R.ReadTooltipLine(data, "None", function(text)
    if text == locked then return "locked" end
    if text == openable then return "opens" end
    return nil
  end) or false
end

-- The use spell's text: the text, false for no use spell, nil when unreadable (and the spell id
-- when its description came back empty: not loaded yet).
local function spellUseText(link)
  local item, spell = C_Item, C_Spell
  if not (item and item.GetItemSpell and spell and spell.GetSpellDescription) then return nil end
  local _, spellID = item.GetItemSpell(link)
  if R.IsSecret(spellID) then return nil end
  if spellID == nil then return false end
  spellID = plainId(spellID)
  local text = spellID and plainString(spell.GetSpellDescription(spellID))
  if text == "" then return nil, spellID end
  return text
end

local function tooltipUseText(link)
  local data = hyperlinkData(link)
  if not data then return nil end
  local prefix = (plainString(R.GlobalString("ITEM_SPELL_TRIGGER_ONUSE")) or "Use:"):lower()
  return R.ReadTooltipLine(data, "None", function(text)
    if text:lower():sub(1, #prefix) ~= prefix then return nil end
    local rest = text:sub(#prefix + 1):match("^%s*(.-)%s*$")
    return rest ~= "" and rest or nil
  end)
end

--- What an item does when used, without the "Use:" prefix, or nil; with no text, the second return
--- is the use spell's id when its description is not loaded yet.
--- @return string|nil text, number|nil loadingSpellID
function R.ItemUseText(link)
  if not plainString(link) then return nil end
  local text, loading = spellUseText(link)
  if text == false then return nil end
  text = text or tooltipUseText(link)
  if text then return text end
  return nil, loading
end

--- True when the client can be asked to load a spell's data and a timer can wait for it.
--- @return boolean
function R.CanRequestSpellLoad()
  local spell, timer = C_Spell, C_Timer
  return (spell and spell.RequestLoadSpellData and timer and timer.After) and true or false
end

--- Ask the client to load a spell's data; whether it asked.
--- @return boolean
function R.RequestSpellLoad(spellID)
  local spell = C_Spell
  spellID = plainId(spellID)
  if not (spellID and spell and spell.RequestLoadSpellData) then return false end
  spell.RequestLoadSpellData(spellID)
  return true
end

-- ---------------------------------------------------------------------------------------------
-- LibKa0s-Item-1.0's link helpers and the item load
-- ---------------------------------------------------------------------------------------------

--- The item id in a link (LibKa0s-Item-1.0), or nil.
function R.ItemIDFromLink(link)
  local item = itemLib()
  if not (item and item.ItemIDFromLink) then return nil end
  return item.ItemIDFromLink(link)
end

--- A link's quality from its color (LibKa0s-Item-1.0), or nil.
function R.QualityFromLink(link)
  local item = itemLib()
  if not (item and item.QualityFromLink) then return nil end
  return item.QualityFromLink(link)
end

--- Ask the client to load item `id` and call `cb` back (LibKa0s-Item-1.0); inert without it.
function R.LoadItem(id, cb)
  local item = itemLib()
  if item and item.LoadItem then item.LoadItem(id, cb) end
end

-- ---------------------------------------------------------------------------------------------
-- The Pawn seam (an optional addon). Every call behind PawnIsReady and in pcall; nil is "not
-- ready yet", which the scorer answers as "pending" and the instance retries.
-- ---------------------------------------------------------------------------------------------

--- True when Pawn is loaded and has finished initializing (PawnIsReady, else PawnIsInitialized).
--- @return boolean
function R.PawnIsReady()
  local flag = type(PawnIsReady) == "function" and PawnIsReady or PawnIsInitialized
  if type(flag) == "function" then
    local ok, v = pcall(flag)
    return ok and v == true
  end
  return flag == true
end

local function pawnCall(fn, ...)
  if not (R.PawnIsReady() and type(fn) == "function") then return nil end
  local ok, v, w = pcall(fn, ...)
  if not ok then return nil end
  return v, w
end

--- Pawn's item object for a link, or nil while the item is not read.
function R.PawnItemData(link)
  if not plainString(link) then return nil end
  return (pawnCall(PawnGetItemData, link))
end

--- Pawn's upgrade list for a link against your gear (one row per visible scale it upgrades; empty
--- when it upgrades nothing); nil while not ready.
--- @return table|nil
function R.PawnUpgradeInfo(link)
  local data = R.PawnItemData(link)
  if data == nil then return nil end
  local list = pawnCall(PawnIsItemAnUpgrade, data)
  return type(list) == "table" and list or {}
end

-- Pawn's scale index for a class and spec (and on WoW Forever a tree and role), by `client`'s list.
local function pawnIndex(classID, specID, tree, role, client)
  if classID == nil then return nil end
  local CD = lib.ClassData.ForClient(client)
  local classFile
  for file, id in pairs(CD.CLASS_ID or {}) do
    if id == classID then classFile = file end
  end
  return CD.SpecIndex(specID, tree, role, classFile)
end

--- The Pawn starter scale for a class and spec, or nil. `client` names the class list the spec's
--- index is read from (Retail's when nil).
--- @return string|nil
function R.PawnScaleForSpec(classID, specID, tree, role, client)
  local index = pawnIndex(classID, specID, tree, role, client)
  if index == nil then return nil end
  return (pawnCall(PawnFindScaleForSpec, classID, index))
end

local function scaleFits(name, scale, classID, index)
  if type(name) ~= "string" or type(scale) ~= "table" then return false end
  if scale.ClassID ~= nil and scale.ClassID ~= classID then return false end
  if scale.SpecID ~= nil and scale.SpecID ~= index then return false end
  if scale.Provider ~= nil and not scale.ProviderActive then return false end
  return PawnIsScaleVisible(name) == true
end

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

--- The Pawn scale you show for your class and spec (a custom scale outranks a starter), or nil.
--- The arguments as PawnScaleForSpec's.
--- @return string|nil
function R.PawnVisibleScale(classID, specID, tree, role, client)
  local index = pawnIndex(classID, specID, tree, role, client)
  if index == nil then return nil end
  return (pawnCall(visibleScale, classID, index))
end

--- Your visible custom scale for a class (no provider, naming no spec), or nil.
--- @return string|nil
function R.PawnCustomScale(classID)
  if classID == nil then return nil end
  return (pawnCall(visibleScale, classID, nil, true))
end

local function classScales(classID)
  local scales = type(PawnCommon) == "table" and PawnCommon.Scales
  local out = {}
  if type(scales) ~= "table" then return out end
  for name, scale in pairs(scales) do
    if type(name) == "string" and type(scale) == "table" and scale.ClassID == classID
      and scale.Provider ~= nil and scale.ProviderActive then
      out[#out + 1] = { name = name, index = scale.SpecID }
    end
  end
  table.sort(out, function(a, b)
    local x, y = tonumber(a.index) or math.huge, tonumber(b.index) or math.huge
    if x ~= y then return x < y end
    return a.name < b.name
  end)
  return out
end

--- Every starter scale Pawn has for a class, `{ { name, index }, ... }` sorted by tree; empty
--- without Pawn or while it is not ready.
--- @return table
function R.PawnClassScales(classID)
  if classID == nil then return {} end
  return pawnCall(classScales, classID) or {}
end

--- One item's unenchanted value on `scale` (the one Pawn's own upgrade test compares), or nil.
--- @return number|nil
function R.PawnItemValue(link, scale)
  if scale == nil then return nil end
  local data = R.PawnItemData(link)
  if data == nil then return nil end
  local v, unenchanted = pawnCall(PawnGetSingleValueFromItem, data, scale)
  if type(unenchanted) == "number" then return unenchanted end
  return type(v) == "number" and v or nil
end
