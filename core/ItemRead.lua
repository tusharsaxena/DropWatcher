local _, NS = ...
-- core/ItemRead.lua — how complete an item link is, which of two links to keep, and an item's
-- level and quality read the exact way (ui spec §0, DW-80: BUG-1, a drop read at its base level
-- and quality from a link without its bonus data).
--
-- LIBRARY-SHAPED. This file holds no Drop Watcher state and no policy of the feed's: it is the API
-- LibKa0s-Item-1.0 would take (the promotion is drafted in docs/superpowers/plans/
-- 2026-10-10-drop-watcher-v1/issues-to-file.md, adopters Loot History, Bank Ledger and Drop
-- Watcher). Until then its client reads stay behind NS.Compat seams (compat): GetItemInfo and
-- GetDetailedItemLevel (core/Compat.lua), BagItemLevelQuality (core/CompatItem.lua). The link
-- parsing is pure.
--
-- THE ITEM STRING. `item:` then, colon-separated: itemID, enchant, four gems, suffix, unique id,
-- link level, spec, modifiers mask, context, the bonus id count and the ids, the modifier count
-- and its (type, value) pairs, then the relic and crafter fields. The identity of an item is its
-- id and bonus ids; the unique id, link level, spec, context and modifiers change between two
-- reports of one item (the bag's copy and the chat line's), so a match ignores them.
--
-- WHY A LINK CAN BE WRONG. The client answers a link's level and quality from the data in that
-- link: a link with no bonus ids answers the base item (a level-scaling trinket at 19, Rare), a
-- complete one the real item (311, Epic). So the most complete link wins (BetterLink), quality is
-- the client's answer for that link, else the link's color, never the bare item id's, and an item
-- in your bags is read at its ItemLocation, which is always exact.

NS.ItemRead = NS.ItemRead or {}
local IR = NS.ItemRead

-- Enum.ItemClass.Weapon and .Armor: the item classes whose level means something.
IR.GEAR_CLASSES = { [2] = true, [4] = true }

-- Field positions after `item:` (1-based).
local F_ID, F_CONTEXT, F_BONUS_COUNT = 1, 12, 13

-- ── the link ────────────────────────────────────────────────────────────────────────────────

--- The `item:...` string inside a link (or the string itself when it is one), or nil.
--- @param link string
--- @return string|nil
function IR.ItemString(link)
    if type(link) ~= "string" then return nil end
    return link:match("item:[%-%d:]*")
end

-- The item string's fields, empty ones kept, as strings.
local function fields(itemString)
    local out = {}
    for v in (itemString:sub(6) .. ":"):gmatch("([^:]*):") do out[#out + 1] = v end
    return out
end

local function int(v) return tonumber(v) end

-- The bonus ids (in link order) and the modifiers ({ [type] = value }, and their count) from the
-- count fields on.
local function bonusAndModifiers(f)
    local bonus, at = {}, F_BONUS_COUNT + 1
    for i = 1, int(f[F_BONUS_COUNT]) or 0 do bonus[i] = int(f[at + i - 1]) end
    at = at + #bonus
    local mods, n = {}, int(f[at]) or 0
    for i = 1, n do
        local t = int(f[at + 2 * i - 1])
        if t then mods[t] = int(f[at + 2 * i]) end
    end
    return bonus, mods, n
end

--- How complete a link is: `{ itemString, itemID, context, bonusIDs = { id, ... }, modifiers =
--- { [type] = value }, numModifiers, complete, score }`. `complete` is true when the link carries
--- bonus or modifier data (what the client needs to answer the real item rather than the base
--- one); `score` orders two links of one item (more bonus ids and modifiers, then a context). Nil
--- for a string that holds no item.
--- @param link string
--- @return table|nil
function IR.LinkDetail(link)
    local s = IR.ItemString(link)
    local f = s and fields(s)
    local id = f and int(f[F_ID])
    if not id then return nil end
    local bonus, mods, n = bonusAndModifiers(f)
    local context = int(f[F_CONTEXT])
    return {
        itemString = s, itemID = id, context = context, bonusIDs = bonus, modifiers = mods,
        numModifiers = n, complete = #bonus > 0 or n > 0,
        score = (#bonus + n) * 2 + (context and context > 0 and 1 or 0),
    }
end

--- The more complete of two links of one item: `b` when it scores higher, else `a` (so a tie keeps
--- the first). A link that holds no item loses to one that does.
--- @param a string|nil
--- @param b string|nil
--- @return string|nil
function IR.BetterLink(a, b)
    local da, db = IR.LinkDetail(a), IR.LinkDetail(b)
    if not db then return da and a or nil end
    if not da then return b end
    return db.score > da.score and b or a
end

--- An item's identity: its id and bonus ids (`"159617|10390,6652"`), or nil. Two links with one
--- identity are the same item even when their unique id, link level, spec, context or modifiers
--- differ.
--- @param link string
--- @return string|nil
function IR.IdentityKey(link)
    local d = IR.LinkDetail(link)
    if not d then return nil end
    local bonus = {}
    for i, id in ipairs(d.bonusIDs) do bonus[i] = id end
    table.sort(bonus)
    return d.itemID .. "|" .. table.concat(bonus, ",")
end

--- True when two links name the same item by identity (IdentityKey).
--- @return boolean
function IR.SameItem(a, b)
    local ka = IR.IdentityKey(a)
    return ka ~= nil and ka == IR.IdentityKey(b)
end

-- ── level and quality ───────────────────────────────────────────────────────────────────────

local function isGear(info)
    return IR.GEAR_CLASSES[info.classID] == true and type(info.equipLoc) == "string" and info.equipLoc ~= ""
end

--- The exact level of the item in bag `bag`, slot `slot` (its ItemLocation), and the source
--- `"current"`; nil when the slot is empty or the client answers nothing.
--- @return number|nil, string|nil
function IR.ItemLevelAt(bag, slot)
    local level = NS.Compat.BagItemLevelQuality(bag, slot)
    if level then return level, "current" end
    return nil, nil
end

--- The exact quality of the item in bag `bag`, slot `slot`, and the source `"location"`; nil when
--- the slot is empty or the client answers nothing.
--- @return number|nil, string|nil
function IR.QualityAt(bag, slot)
    local _, quality = NS.Compat.BagItemLevelQuality(bag, slot)
    if quality then return quality, "location" end
    return nil, nil
end

--- A gear item's level and its source: at a location `{ bag, slot }` the exact one (`current`);
--- for a link the detailed level (`detailed`, its bonuses and upgrades applied), else the base
--- level (`base`). Nil for an item that is not gear (a weapon or armor with a slot), an uncached
--- item, or no answer.
--- @param where string|table a link, or { bag, slot }
--- @return number|nil, string|nil
function IR.EffectiveItemLevel(where)
    if type(where) == "table" then return IR.ItemLevelAt(where.bag, where.slot) end
    local info = NS.Compat.GetItemInfo(where)
    if not (info and isGear(info)) then return nil, nil end
    local detailed = NS.Compat.GetDetailedItemLevel(where)
    if detailed then return detailed, "detailed" end
    if info.itemLevel then return info.itemLevel, "base" end
    return nil, nil
end

--- A link's quality and its source: the client's answer for this link (`item`: for a complete link
--- the real item's, which is why the feed keeps the most complete link), else the link's color
--- (`link`, LibKa0s-Item-1.0's QualityFromLink: the client colors a link by its quality, so it
--- answers before the item is cached). Nil when neither answers. An item in your bags is read at
--- its location instead (QualityAt).
--- @param link string
--- @return number|nil, string|nil
function IR.QualityOf(link)
    local info = NS.Compat.GetItemInfo(link)
    if info and info.quality then return info.quality, "item" end
    local colored = NS.Item and NS.Item.QualityFromLink(link)
    if colored then return colored, "link" end
    return nil, nil
end
