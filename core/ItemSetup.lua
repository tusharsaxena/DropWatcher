local _, NS = ...
-- core/ItemSetup.lua — NS.Item from LibKa0s-Item-1.0: id and quality from a link, the quality
-- label, and the cache-then-callback load.
--
-- It holds NO policy about what an uncached item means: that decision is the item-facts module's
-- (design spec §4, ItemFacts), and it is written down there.

local Item = LibStub and LibStub("LibKa0s-Item-1.0", true)

-- English fallbacks for a client that leaves the ITEM_QUALITY<n>_DESC globals nil.
local QUALITY_LABEL_EN = {
    [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare",
    [4] = "Epic", [5] = "Legendary", [6] = "Artifact", [7] = "Heirloom", [8] = "WoW Token",
}

local qualityByHex

local function hexMap()
    if qualityByHex then return qualityByHex end
    local map, any = {}, false
    if type(ITEM_QUALITY_COLORS) == "table" then
        for q = 0, 8 do
            local c = ITEM_QUALITY_COLORS[q]
            if c and c.hex then map[c.hex:sub(-6):lower()] = q; any = true end
        end
    end
    if any then qualityByHex = map end
    return map
end

-- The library-absent stand-in: the same four members, the same answers on the common inputs.
NS.Item = Item or {
    ItemIDFromLink = function(link)
        if type(link) ~= "string" then return nil end
        return tonumber(link:match("item:(%d+)"))
    end,
    QualityFromLink = function(link)
        if type(link) ~= "string" then return nil end
        local iq = link:match("|cnIQ(%d+)")
        if iq then return tonumber(iq) end
        local hex = link:match("|c%x%x(%x%x%x%x%x%x)")
        return hex and hexMap()[hex:lower()] or nil
    end,
    QualityLabel = function(q)
        q = q or 0
        return _G["ITEM_QUALITY" .. q .. "_DESC"] or QUALITY_LABEL_EN[q] or tostring(q)
    end,
    LoadItem = function(id, cb)
        if not (id and C_Item and C_Item.RequestLoadItemDataByID) then return end
        C_Item.RequestLoadItemDataByID(id)
        if cb and C_Timer and C_Timer.After then C_Timer.After(0.4, cb) end
    end,
}
