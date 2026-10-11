local _, NS = ...
-- core/CompatItem.lua — the exact item reads at a bag location and the game tooltip's item
-- setters (ui spec §0, DW-80), published on NS.Compat so the simulator's answer seam
-- (core/SimSeam.lua) answers them too: a simulated drop sits in a bag slot the client does not
-- have.
--
-- WHY HERE. None of these APIs is version-variant (C_Item.GetCurrentItemLevel and GetItemQuality
-- on an ItemLocation, GameTooltip's SetBagItem, SetInventoryItem and SetHyperlink), so the compat
-- rule does not need them in core/Compat.lua, which keeps the variant ones under its 1000-line
-- cap; core/CompatWorld.lua is the same split. core/ItemRead.lua reads the location; the drop
-- tables' item buttons (modules/WindowGroup.lua) show the tooltip.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

local function plainNumber(v)
    if Compat.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- The ItemLocation of an occupied bag slot, with C_Item; nil for an empty slot or no API.
local function bagLocation(bag, slot)
    local item, loc = C_Item, ItemLocation
    if not (item and loc and loc.CreateFromBagAndSlot) then return nil, nil end
    if type(bag) ~= "number" or type(slot) ~= "number" then return nil, nil end
    local location = loc:CreateFromBagAndSlot(bag, slot)
    if item.DoesItemExist and not item.DoesItemExist(location) then return nil, nil end
    return location, item
end

--- The exact item level and quality of the item in bag `bag`, slot `slot`: C_Item.GetCurrentItemLevel
--- and C_Item.GetItemQuality on its ItemLocation (every bonus, upgrade and scaling applied). Each
--- nil for an empty slot, a secret or missing answer, or no API.
--- @param bag number
--- @param slot number
--- @return number|nil level, number|nil quality
function Compat.BagItemLevelQuality(bag, slot)
    local location, item = bagLocation(bag, slot)
    if not location then return nil, nil end
    local level = item.GetCurrentItemLevel and plainNumber(item.GetCurrentItemLevel(location)) or nil
    local quality = item.GetItemQuality and plainNumber(item.GetItemQuality(location)) or nil
    return level, quality
end

-- tip[method](tip, ...) when the tooltip has it; true when called.
local function setTooltip(tip, method, ...)
    if type(tip) ~= "table" or type(tip[method]) ~= "function" then return false end
    tip[method](tip, ...)
    return true
end

--- Shows the bag item in bag `bag`, slot `slot` on `tip` (GameTooltip:SetBagItem): the client's own
--- tooltip, with its trade-time line. True when it was called.
--- @return boolean
function Compat.TooltipBagItem(tip, bag, slot)
    return setTooltip(tip, "SetBagItem", bag, slot)
end

--- Shows `unit`'s item in inventory slot `slot` on `tip` (GameTooltip:SetInventoryItem). True when
--- it was called.
--- @return boolean
function Compat.TooltipInventoryItem(tip, unit, slot)
    return setTooltip(tip, "SetInventoryItem", unit, slot)
end

--- Shows `link` on `tip` (GameTooltip:SetHyperlink). True when it was called.
--- @return boolean
function Compat.TooltipHyperlink(tip, link)
    if type(link) ~= "string" or Compat.IsSecret(link) then return false end
    return setTooltip(tip, "SetHyperlink", link)
end
