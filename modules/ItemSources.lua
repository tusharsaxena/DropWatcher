local _, NS = ...
-- modules/ItemSources.lua — where a drop comes from, on the detail card (SF-DW-01, LibKa0s#105):
-- the creatures, objects and containers that drop it, each with its chance, the minimum level of a
-- world drop, and the vendors that sell it. WoW Forever alone, from the optional ForeverDB addon,
-- read only through LibKa0s-ForeverDB-1.0 (core/ForeverDBSetup.lua, NS.ForeverDB; clients-§11).
--
-- THE GATE, in order (IS.For): the feature's client (C.FEATURE.itemSources, WoW Forever alone,
-- clients-§4: Retail has no row, no default and no read), the player's switch (`window.itemSources`,
-- Window > Layout > Detail card, on by default), an item id, then the library's Available(). That
-- last call is the first lookup, so opening a detail card is what loads ForeverDB (some 12 MB),
-- once a session; nothing here runs at login. Without ForeverDB (not installed, disabled, a load
-- that failed, a reshaped database) the answer is nil and the card draws the header it always drew;
-- the setting row's tooltip says the feature needs ForeverDB.
--
-- THE MODEL (IS.Model, pure): `src` is ItemSources' answer, `names` a reader of a source's name.
--   { top = { { kind = "npc"|"object"|"item", id, name, chance }, ... },  -- at most TOP, most likely first
--     more,                     -- drop sources past the top
--     worldMinLevel,            -- nil when it is no world drop
--     vendors = { name, ... },  -- at most TOP, in ForeverDB's order
--     vendorMore }              -- vendors past those
-- The three source lists are merged and sorted again (the library sorts each list on its own): a
-- known chance first, the higher first, an unknown rate (nil) last, then creature, object,
-- container, then the id.
--
-- THE CHIP (IS.Chip, pure): the header's last chip, `Drops from <name> 25%`, else `Sold by <name>`,
-- else `World drop`, its tooltip every line of the model. One chip, so the card's height and its
-- layout are unchanged (modules/DetailCard.lua paints it after NS.DetailCells.Chips).
--
-- The answer is kept per item id for the session (ForeverDB is static data), so a repaint of an
-- open card reads nothing again; the switch and the client are checked before the cache.

NS.ItemSources = NS.ItemSources or {}
local IS = NS.ItemSources
local C  = NS.Constants
local L  = NS.L

local floor = math.floor

IS.TOP = 3   -- the sources and the vendors the chip's tooltip names (spec §9: up to three)

local KIND_ORDER = { npc = 1, object = 2, item = 3 }

local cache = {}

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- A chance (0..1) as the tooltip writes it: `25%`, `2.5%`, `<0.1%`; nil for an unknown rate.
--- @param chance number|nil
--- @return string|nil
function IS.Percent(chance)
    chance = num(chance)
    if not chance or chance <= 0 then return nil end
    local p = chance * 100
    if p >= 10 then return ("%d%%"):format(floor(p + 0.5)) end
    if p >= 0.1 then return ("%.1f%%"):format(p) end
    return "<0.1%"
end

local function before(a, b)
    if a.chance ~= b.chance then
        if a.chance == nil then return false end
        if b.chance == nil then return true end
        return a.chance > b.chance
    end
    if a.kind ~= b.kind then return KIND_ORDER[a.kind] < KIND_ORDER[b.kind] end
    return a.id < b.id
end

-- Every drop source of `src`, merged over its three lists, most likely first.
local function merged(src)
    local out = {}
    for kind, list in pairs({ npc = src.creatures, object = src.objects, item = src.items }) do
        if type(list) == "table" then
            for _, s in ipairs(list) do
                if type(s) == "table" and num(s.id) then
                    out[#out + 1] = { kind = kind, id = s.id, chance = num(s.chance) }
                end
            end
        end
    end
    table.sort(out, before)
    return out
end

--- The card's model of where an item comes from, or nil when ForeverDB names nothing.
--- @param src table|nil LibKa0s-ForeverDB-1.0's ItemSources answer
--- @param names function(kind, id) -> string|nil, a source's name
--- @return table|nil
function IS.Model(src, names)
    if type(src) ~= "table" then return nil end
    local all = merged(src)
    local m = { top = {}, more = 0, vendors = {}, vendorMore = 0, worldMinLevel = num(src.worldMinLevel) }
    for i, s in ipairs(all) do
        if i <= IS.TOP then
            s.name = names(s.kind, s.id)
            m.top[#m.top + 1] = s
        else
            m.more = m.more + 1
        end
    end
    for _, id in ipairs(type(src.vendors) == "table" and src.vendors or {}) do
        if num(id) then
            if #m.vendors < IS.TOP then
                m.vendors[#m.vendors + 1] = names("npc", id)
            else
                m.vendorMore = m.vendorMore + 1
            end
        end
    end
    if #m.top == 0 and #m.vendors == 0 and not m.worldMinLevel then return nil end
    return m
end

-- A source's words: `Fixture Gnoll 25%`, or the name alone at an unknown rate.
local function sourceText(s)
    local p = IS.Percent(s.chance)
    return p and ("%s %s"):format(s.name, p) or s.name
end

local function chipText(m)
    if m.top[1] then return L["Drops from %s"]:format(sourceText(m.top[1])) end
    if m.vendors[1] then return L["Sold by %s"]:format(m.vendors[1]) end
    return L["World drop"]
end

local function vendorLine(m)
    local text = table.concat(m.vendors, ", ")
    if m.vendorMore > 0 then text = L["%s and %d more"]:format(text, m.vendorMore) end
    return text
end

--- The header's chip for `m` (IS.Model's), or nil: its text the likeliest source, its tooltip the
--- top sources with their chances, the world-drop level and the vendors.
--- @param m table|nil
--- @return table|nil chip { text, tip = { title, rows... } }
function IS.Chip(m)
    if type(m) ~= "table" then return nil end
    local TM = NS.TipMarks
    local tip = { L["Where it comes from"] }
    for _, s in ipairs(m.top) do tip[#tip + 1] = TM.Row(s.name, IS.Percent(s.chance) or L["rate unknown"]) end
    if m.more > 0 then tip[#tip + 1] = TM.Row(nil, L["and %d more"]:format(m.more)) end
    if m.worldMinLevel then tip[#tip + 1] = TM.Row(L["World drop"], L["from level %d"]:format(m.worldMinLevel)) end
    if #m.vendors > 0 then tip[#tip + 1] = TM.Row(L["Sold by"], vendorLine(m)) end
    tip[#tip + 1] = TM.Hint(L["From the ForeverDB addon."])
    return { text = chipText(m), tip = tip }
end

-- ── the reader ──────────────────────────────────────────────────────────────────────────────

-- A source's name through the library: a creature's or a vendor's from its NPC row, a
-- container's from its item row; an object's is not read in the library's version 1.
local function nameOf(kind, id)
    local FDB = NS.ForeverDB
    if kind == "npc" then
        local n = FDB.NPC(id)
        return n and n.name or L["Creature %d"]:format(id)
    end
    if kind == "item" then
        local it = FDB.Item(id)
        return it and it.name or L["Item %d"]:format(id)
    end
    return L["Object %d"]:format(id)
end

local function itemIDOf(drop)
    if type(drop) ~= "table" then return nil end
    return num(drop.itemID) or NS.Item.ItemIDFromLink(drop.link)
end

--- Where the item comes from (IS.Model's), or nil: off on Retail, with the switch off, without
--- ForeverDB, or when it names nothing. The first call that passes the switch loads ForeverDB.
--- @param itemID number|nil
--- @return table|nil
function IS.For(itemID)
    if not C.FEATURE.itemSources or NS.Setting("window.itemSources") ~= true then return nil end
    itemID = num(itemID)
    if not itemID then return nil end
    local hit = cache[itemID]
    if hit ~= nil then return hit or nil end
    local FDB = NS.ForeverDB
    if not FDB.Available() then return nil end
    local m = IS.Model(FDB.ItemSources(itemID), nameOf)
    cache[itemID] = m or false
    return m
end

--- The detail card's Sources chip for `drop`, or nil (IS.For's gate).
--- @param drop table
--- @return table|nil
function IS.ChipFor(drop)
    return IS.Chip(IS.For(itemIDOf(drop)))
end
