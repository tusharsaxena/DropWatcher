local _, NS = ...
-- core/CompatItem.lua — the exact item reads at a bag location, how many of an item you hold, the game tooltip's item
-- setters (ui spec §0, DW-80) and a tooltip's line by number (feedback-7 spec §3: a grid's cells
-- anchor to the lines it reserved, modules/TipGrid.lua), published on NS.Compat so the simulator's answer seam
-- (core/SimSetup.lua) answers them too: a simulated drop sits in a bag slot the client does not
-- have.
--
-- WHY HERE. None of these APIs is version-variant (C_Item.GetCurrentItemLevel and GetItemQuality
-- on an ItemLocation, GameTooltip's SetBagItem, SetInventoryItem and SetHyperlink), so the compat
-- rule does not need them in core/Compat.lua, which keeps the variant ones under its 1000-line
-- cap; core/CompatWorld.lua is the same split, and core/CompatJournal.lua keeps it there. core/ItemRead.lua reads the location; the drop
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

-- The equipped inventory slots (INVSLOT_FIRST_EQUIPPED .. INVSLOT_LAST_EQUIPPED: head to tabard).
local FIRST_WORN, LAST_WORN = 1, 19

-- How many of `itemID` you wear: GetInventoryItemID over the equipped slots (Compat.InventoryItemID).
local function wornCount(itemID)
    local n = 0
    for slot = FIRST_WORN, LAST_WORN do
        if Compat.InventoryItemID("player", slot) == itemID then n = n + 1 end
    end
    return n
end

--- How many of `itemID` you hold (round 4 addendum A1, R4-DW-11: the Item Search window's verdict
--- panel): in your bags, and in your bags and bank together, from C_Item.GetItemCount (the bank from
--- the client's cached count, so it answers with the bank closed). The client's count takes in what
--- you wear too; that is taken out again, so an item you only wear is not held. Each 0 for an id that
--- is not a number, a secret or missing answer, or no API.
--- @param itemID number
--- @return number bags, number total
function Compat.ItemCount(itemID)
    local item = C_Item
    if type(itemID) ~= "number" or not (item and item.GetItemCount) then return 0, 0 end
    local bags = plainNumber(item.GetItemCount(itemID, false)) or 0
    local total = plainNumber(item.GetItemCount(itemID, true)) or 0
    if bags <= 0 and total <= 0 then return 0, 0 end
    local worn = wornCount(itemID)
    bags = math.max(0, bags - worn)
    return bags, math.max(bags, total - worn)
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

--- The font string of `tip`'s line `n`, its left column (`<name>TextLeft<n>`, the client's own
--- global for a named tooltip); nil for an unnamed tooltip or a line it does not have.
--- @param tip table a GameTooltip
--- @param n number
--- @return table|nil
function Compat.TooltipLeftLine(tip, n)
    if type(tip) ~= "table" or type(tip.GetName) ~= "function" or type(n) ~= "number" then return nil end
    local name = tip:GetName()
    if type(name) ~= "string" or Compat.IsSecret(name) then return nil end
    local fs = _G[name .. "TextLeft" .. n]
    return type(fs) == "table" and fs or nil
end
