local _, NS = ...
-- core/CompatItem.lua — the exact item reads at a bag location, the game tooltip's item
-- setters (ui spec §0, DW-80) and a tooltip's line by number (feedback-7 spec §3: a grid's cells
-- anchor to the lines it reserved, modules/TipGrid.lua), published on NS.Compat so the simulator's answer seam
-- (core/SimSetup.lua) answers them too: a simulated drop sits in a bag slot the client does not
-- have.
--
-- WHY HERE. None of these APIs is version-variant (C_Item.GetCurrentItemLevel and GetItemQuality
-- on an ItemLocation, GameTooltip's SetBagItem, SetInventoryItem and SetHyperlink), so the compat
-- rule does not need them in core/Compat.lua, which keeps the variant ones under its 1000-line
-- cap; core/CompatWorld.lua is the same split, and core/CompatJournal.lua keeps it there. libs/LibKa0s/VerdictFacts.lua reads the location; the drop
-- tables' item buttons (modules/WindowGroup.lua) show the tooltip.
--
-- THE RULES are core/Compat.lua's: globals read bare at call time, a value that may be secret
-- meets nothing but IsSecret first, a missing API answers its documented absent value and never
-- raises.

NS.Compat = NS.Compat or {}
local Compat = NS.Compat

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

--- The font string of `tip`'s line `n`, its left column (`<name>TextLeft<n>`, the client's own
--- global for a named tooltip); nil for an unnamed tooltip or a line it does not have.
--- @param tip table a GameTooltip
--- @param n number
--- @return table|nil
local function lineString(tip, side, n)
    if type(tip) ~= "table" or type(tip.GetName) ~= "function" or type(n) ~= "number" then return nil end
    local name = tip:GetName()
    if type(name) ~= "string" or Compat.IsSecret(name) then return nil end
    local fs = _G[name .. side .. n]
    return type(fs) == "table" and fs or nil
end

function Compat.TooltipLeftLine(tip, n)
    return lineString(tip, "TextLeft", n)
end
