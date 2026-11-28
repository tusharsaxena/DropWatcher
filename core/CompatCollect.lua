local _, NS = ...
-- core/CompatCollect.lua — the collection-side reads this addon still makes itself (issue #13,
-- categories design spec §2), published on NS.Compat like the rest of the compat family, split out of
-- core/Compat.lua to keep it under the 1000-line band: the cosmetic flag, a class's client name (a
-- tier token's Type cell, modules/CollectCells.lua, DW-CAT4) and the link of a curated sample's id
-- (modules/SimPool.lua, spec §8, DW-CAT6). The mount, pet, toy, recipe, profession, tier-token slot
-- and use-text reads the verdict engine makes are LibKa0s-Verdict-1.0's own (lib.Reads), covered by
-- the simulator's seam over the instance's reads (core/VerdictSetup.lua, LibKa0s#111).
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local function plainString(v)
    if Compat.IsSecret(v) or type(v) ~= "string" then return nil end
    return v
end

local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function plainBool(v)
    if Compat.IsSecret(v) or type(v) ~= "boolean" then return nil end
    return v
end

-- A positive plain number (an item, mount or species id), or nil.
local function plainId(v)
    v = plainNumber(v)
    return v and v > 0 and v or nil
end

-- ── Cosmetics ───────────────────────────────────────────────────────────────────────────────

--- True when the client flags an item cosmetic (C_Item.IsCosmeticItem: cosmetic armor, and the
--- cosmetic weapons, which are Weapon-class); false for no API, a secret or a non-string link.
--- @param link string
--- @return boolean
function Compat.IsCosmeticItem(link)
    local item = C_Item
    if not (plainString(link) and item and item.IsCosmeticItem) then return false end
    return plainBool(item.IsCosmeticItem(link)) == true
end

-- ── Class names (DW-CAT4) ───────────────────────────────────────────────────────────────────

--- A class's name as the client writes it (LOCALIZED_CLASS_NAMES_MALE), or nil: no table, an
--- unknown class or a secret answer. A tier token's Type cell lists its classes by these names.
--- @param classFile string
--- @return string|nil
function Compat.ClassDisplayName(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    if not (plainString(classFile) and type(names) == "table") then return nil end
    return plainString(names[classFile])
end

-- ── The simulator's samples (DW-CAT6) ───────────────────────────────────────────────────────

--- An item's link from its id (C_Item.GetItemInfo's second return), or nil: no API, an item the
--- client has not cached yet, or a secret answer. The simulator's curated collectible samples
--- (NS.SimPool.COLLECTIBLE_SAMPLES) are ids, and a loot line needs the link.
--- @param itemID number
--- @return string|nil
function Compat.ItemLinkByID(itemID)
    local item = C_Item
    if not (plainId(itemID) and item and item.GetItemInfo) then return nil end
    local _, link = item.GetItemInfo(itemID)
    link = plainString(link)
    if not (link and link:find("|Hitem:", 1, true)) then return nil end
    return link
end
