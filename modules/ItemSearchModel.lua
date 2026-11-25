local _, NS = ...
-- modules/ItemSearchModel.lua — Item Search's pure model (DropWatcher#17, Item Search spec §4.3):
-- everything Drop Watcher knows about one item, for the tooltip block and the Item Search window.
-- No client call and no setting read here: every input arrives in `ctx`, so a case drives it with
-- invented values. modules/ItemSearch.lua builds the context, caches the answer and gates it.
--
-- IS.Facts(itemID, ctx) answers
--   { id, item, drops, worldMinLevel, vendors, vendorPrice, quests, crafting, rewardFrom,
--     startsQuest, skinnedFrom, unnamedObjects, ranks, fdb }
-- in two halves. IS.Static(itemID, ctx) is the part that cannot change in a session (ForeverDB is
-- static data, the recipe table is shipped, a quest's masks and the player's race and class are
-- fixed), so modules/ItemSearch.lua keeps it per item. IS.Live(static, ctx) copies it and adds what
-- is read live: each quest's state, each recipe's known mark, the player's rank and the skill-up
-- color, and the ranks themselves (`ranks`, for the ranking's context). What is shown first and
-- how many rows a section shows are the ranking's and the cap's, below (feedback spec §3, §7).
--
-- THE CONTEXT. Static half:
--   fdb        "loaded" | "loading" | "missing" | "failed" | "off" | "client" (ForeverDB's state)
--   db         the LibKa0s-ForeverDB-1.0 reader, read only when fdb == "loaded" (spec §2: a read
--              never loads)
--   clientItem function(itemID) -> the client's cached item (NS.Compat.ItemInfoByID's shape) or nil
--   recipes    NS.RecipeReagents.Get()'s table ({ recipes, byReagent }) or nil
--   learned    the profession window's recipes, `{ [spell] = { skillLine, reagents, made, name } }`
--   race, class the player's race and class ids (nil: no filter)
-- Live half:
--   questState function(questID) -> "done" | "ready" | "log" | "todo" ("ready": in the log and
--              complete, not turned in; round 3 spec §4.2)
--   knows      function(spell) -> boolean|nil
--   ranks      { [skillLine] = rank } or nil
--
-- DROPS AND VENDORS are SF-DW-01's model, moved here when Item Search retired that feature's
-- detail card chip (modules/ItemSources.lua, removed in IS-DW-07): the creatures, objects and
-- containers merged into one list, a known chance first, the higher first, an unknown rate last,
-- then creature, object, container, then the id. A creature carries its level range.
--
-- OBJECTS (Item Search feedback spec §2, W15) are named through the reader's Object(id) (LibKa0s
-- v1.116.0, ForeverDB minor 3). An object with no name is DROPPED, from the tooltip and the window
-- alike: never an "Object <id>" row; how many went is the static facts' `unnamedObjects`, which
-- modules/ItemSearch.lua writes to the debug log. Objects with the SAME NAME become one row
-- (IS.MergeNamedObjects): the same chest under several spawn ids. The row keeps the highest chance
-- of its parts (summing them would mislead) and `ids`, every object id it stands for (a lone object
-- has none: its `id` is its one part), so the window unions their map spots and its row tooltip
-- counts them (`#ids`, "6 kinds of Large Solid Chest").
--
-- CRAFTING is the recipes that use the item as a reagent: the shipped table's (byReagent) in its
-- order, then the profession window's learned ones the table lacks, by spell id. A row is
--   { spell, name, skillLine, count, made, min, yellow, green, gray, learned, known, rank, color }
-- where green is floor((yellow + gray) / 2) and color is "orange" below yellow, "yellow" from it,
-- "green" from green and "gray" from gray (spec §4.2, the classic rule). A row with no breakpoints
-- (a learned recipe, or a table row whose yellow and gray are both 0) and a player without the
-- profession have no color.

NS.ItemSearch = NS.ItemSearch or {}
local IS = NS.ItemSearch
local L = NS.L

local floor = math.floor

-- The tooltip's rows per section (Item Search feedback spec §7: itemSearch.tooltip.rows, 5 by
-- default, a whole 1 to 20; it replaced the drops-only dropsShown, 3, through schema step 16).
IS.TIP_ROWS, IS.TIP_ROWS_MIN, IS.TIP_ROWS_MAX = 5, 1, 20

local KIND_ORDER = { npc = 1, object = 2, item = 3 }

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function list(v)
    if type(v) == "table" then return v end
    return {}
end

-- ── sources (SF-DW-01's model) ──────────────────────────────────────────────────────────────

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

--- Every drop source of an ItemSources answer, merged over its three lists, most likely first:
--- new rows `{ kind = "npc"|"object"|"item", id, chance }`.
--- @param src table|nil LibKa0s-ForeverDB-1.0's ItemSources answer
--- @return table
function IS.MergeSources(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for kind, rows in pairs({ npc = src.creatures, object = src.objects, item = src.items }) do
        for _, s in ipairs(list(rows)) do
            if type(s) == "table" and num(s.id) then
                out[#out + 1] = { kind = kind, id = s.id, chance = num(s.chance) }
            end
        end
    end
    table.sort(out, before)
    return out
end

-- An object's name from the reader's Object(id) (minor 3), or nil: no row, no string, or an empty one.
local function objectName(db, id)
    local o = type(db.Object) == "function" and db.Object(id) or nil
    local name = type(o) == "table" and o.name or nil
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

-- A source's name, level range and whether the name is real, from the reader; nil for an object
-- with no name (dropped, spec §2).
local function describe(db, s)
    if s.kind == "npc" then
        local n = db.NPC(s.id)
        if type(n) == "table" and n.name then
            s.name, s.named, s.minLevel, s.maxLevel = n.name, true, num(n.minLevel), num(n.maxLevel)
            s.rank = num(n.rank)
            return s
        end
        s.name, s.named = L["Creature %d"]:format(s.id), false
    elseif s.kind == "item" then
        local it = db.Item(s.id)
        if type(it) == "table" and it.name then s.name, s.named = it.name, true; return s end
        s.name, s.named = L["Item %d"]:format(s.id), false
    else
        local name = objectName(db, s.id)
        if not name then return nil end
        s.name, s.named = name, true
    end
    return s
end

--- Same-named objects of a described drop list merged into one row (spec §2): the first one in the
--- list's order stands for them, with the highest chance of its parts (an unknown rate only when
--- every part's is) and `ids`, every object id in list order. An object no other shares a name
--- with carries no `ids` (its own `id` stands for it; the static facts are built once per item, and
--- a table per object would be spent for nothing). Creatures and containers pass untouched. A new
--- list, sorted as IS.MergeSources sorts.
--- @param drops table rows `{ kind, id, chance, name, ids }`
--- @return table
function IS.MergeNamedObjects(drops)
    local out, byName = {}, {}
    for _, s in ipairs(list(drops)) do
        local first = s.kind == "object" and s.name and byName[s.name] or nil
        if first then
            first.ids = first.ids or { first.id }
            if type(s.ids) == "table" then
                for _, id in ipairs(s.ids) do first.ids[#first.ids + 1] = id end
            else
                first.ids[#first.ids + 1] = s.id
            end
            if s.chance and (not first.chance or s.chance > first.chance) then first.chance = s.chance end
        else
            if s.kind == "object" and s.name then byName[s.name] = s end
            out[#out + 1] = s
        end
    end
    table.sort(out, before)
    return out
end

-- ── the skill-up color ─────────────────────────────────────────────────────────────────────

--- The green breakpoint: floor((yellow + gray) / 2); nil without both.
--- @return number|nil
function IS.Green(yellow, gray)
    yellow, gray = num(yellow), num(gray)
    if not (yellow and gray) then return nil end
    return floor((yellow + gray) / 2)
end

--- The skill-up color of a recipe at `rank`: "orange", "yellow", "green" or "gray"; nil without a
--- rank, or without breakpoints (yellow and gray both missing or both 0).
--- @param rank number|nil
--- @param yellow number|nil
--- @param gray number|nil
--- @return string|nil
function IS.SkillColor(rank, yellow, gray)
    rank, yellow, gray = num(rank), num(yellow), num(gray)
    if not (rank and yellow and gray) or (yellow <= 0 and gray <= 0) then return nil end
    if rank >= gray then return "gray" end
    if rank >= IS.Green(yellow, gray) then return "green" end
    if rank >= yellow then return "yellow" end
    return "orange"
end

--- A recipe's breakpoints as colored parts: orange (its minimum, only above 1: the shipped table's
--- 1 is a placeholder), yellow, green and gray, each `{ text, tone }` (a C.TONE key); `{}` without
--- breakpoints. The window's Skill column draws them (NS.ItemSearchCells.SkillParts is this) and so
--- does the tooltip's crafting row (round 3 spec §4.2, item 4).
--- @param r table a crafting row
--- @return table
function IS.SkillParts(r)
    local out = {}
    local yellow, gray = num(r.yellow), num(r.gray)
    if not (yellow and gray) or (yellow <= 0 and gray <= 0) then return out end
    local min = num(r.min)
    if min and min > 1 then out[#out + 1] = { text = tostring(min), tone = "skillOrange" } end
    out[#out + 1] = { text = tostring(yellow), tone = "skillYellow" }
    if num(r.green) then out[#out + 1] = { text = tostring(r.green), tone = "skillGreen" } end
    out[#out + 1] = { text = tostring(gray), tone = "skillGray" }
    return out
end

-- ── quests ──────────────────────────────────────────────────────────────────────────────────

--- Whether a race or class mask lets `id` in: a nil mask or a nil id means any; otherwise the
--- mask's bit `id - 1` is set.
--- @param mask number|nil
--- @param id number|nil
--- @return boolean
function IS.MaskAllows(mask, id)
    mask, id = num(mask), num(id)
    if not mask or mask <= 0 or not id or id < 1 then return true end
    return floor(mask / 2 ^ (id - 1)) % 2 == 1
end

local function questRows(db, itemID, ctx)
    local out = {}
    for _, q in ipairs(list(db.QuestsForItem(itemID))) do
        if type(q) == "table" and num(q.id) and IS.MaskAllows(q.races, ctx.race)
            and IS.MaskAllows(q.classes, ctx.class) then
            out[#out + 1] = { id = q.id, title = q.title, level = num(q.level), minLevel = num(q.minLevel),
                preQuests = list(q.preQuests) }
        end
    end
    return out
end

-- ── crafting ────────────────────────────────────────────────────────────────────────────────

local function tableRow(spell, r, itemID)
    local yellow, gray = num(r.yellow), num(r.gray)
    return {
        spell = spell, name = r.name, skillLine = num(r.skillLine), count = num(list(r.reagents)[itemID]),
        made = num(r.made), min = num(r.min), yellow = yellow, green = IS.Green(yellow, gray), gray = gray,
        learned = false,
    }
end

local function learnedRows(learned, shipped, itemID)
    local spells = {}
    for spell, r in pairs(list(learned)) do
        if num(spell) and type(r) == "table" and not shipped[spell] and num(list(r.reagents)[itemID]) then
            spells[#spells + 1] = spell
        end
    end
    table.sort(spells)
    local out = {}
    for _, spell in ipairs(spells) do
        local r = learned[spell]
        out[#out + 1] = { spell = spell, name = r.name, skillLine = num(r.skillLine),
            count = num(r.reagents[itemID]), made = num(r.made), learned = true }
    end
    return out
end

--- The recipes that use `itemID` as a reagent: the shipped table's, then the learned ones it
--- lacks. Static rows (no known mark, rank or color).
--- @return table
function IS.CraftingRows(itemID, recipes, learned)
    local shipped = type(recipes) == "table" and list(recipes.recipes) or {}
    local out = {}
    for _, spell in ipairs(type(recipes) == "table" and list(list(recipes.byReagent)[itemID]) or {}) do
        local r = shipped[spell]
        if type(r) == "table" then out[#out + 1] = tableRow(spell, r, itemID) end
    end
    for _, row in ipairs(learnedRows(learned, shipped, itemID)) do out[#out + 1] = row end
    return out
end

-- ── the static half ─────────────────────────────────────────────────────────────────────────

-- The item's facts: ForeverDB's row when loaded, the client's cached item filling what it lacks.
local function itemFacts(itemID, ctx, db)
    local out = { id = itemID }
    local client = type(ctx.clientItem) == "function" and ctx.clientItem(itemID) or nil
    local sources = { db and db.Item(itemID) or false, client or false }
    for i = 1, 2 do
        local src = sources[i]
        if type(src) == "table" then
            for k, v in pairs(src) do if out[k] == nil then out[k] = v end end
        end
    end
    return out
end

-- A creature's level range and side (`nfac`: "A", "H", "AH" or nil), for the ranking (spec §3),
-- and its subname (a vendor's "Invented Goods"), for the window's Sold by tooltip (spec §5.6); then
-- its name, "Creature <id>" when the reader names none. One NPC read: each builds a new table.
local function npcFacts(db, id)
    local n = db.NPC(id)
    if type(n) ~= "table" then return nil, nil, nil, nil, L["Creature %d"]:format(id) end
    return num(n.minLevel), num(n.maxLevel), n.faction, type(n.subname) == "string" and n.subname or nil,
        n.name or L["Creature %d"]:format(id)
end

local function vendorsOf(db, src)
    local out = {}
    for _, id in ipairs(list(type(src) == "table" and src.vendors)) do
        if num(id) then
            local minLevel, maxLevel, faction, subname, name = npcFacts(db, id)
            out[#out + 1] = { id = id, name = name, minLevel = minLevel, maxLevel = maxLevel,
                faction = faction, subname = subname }
        end
    end
    return out
end

local function skinRows(db, itemID)
    local out = {}
    for _, s in ipairs(list(db.SkinnedFrom(itemID))) do
        if type(s) == "table" and num(s.id) then
            local minLevel, maxLevel = npcFacts(db, s.id)
            out[#out + 1] = { id = s.id, name = s.name or L["Creature %d"]:format(s.id), chance = num(s.chance),
                minLevel = minLevel, maxLevel = maxLevel }
        end
    end
    return out
end

-- The ForeverDB half of the static facts, onto `out`.
local function fromForeverDB(out, db, itemID, ctx)
    local src = db.ItemSources(itemID)
    local drops, unnamed, objects = {}, 0, 0
    for _, s in ipairs(IS.MergeSources(src)) do
        local d = describe(db, s)
        if d then drops[#drops + 1] = d else unnamed = unnamed + 1 end
        if d and d.kind == "object" then objects = objects + 1 end
    end
    -- Fewer than two named objects: nothing to merge, and MergeSources' order already stands.
    out.drops, out.unnamedObjects = objects > 1 and IS.MergeNamedObjects(drops) or drops, unnamed
    out.worldMinLevel = type(src) == "table" and num(src.worldMinLevel) or nil
    out.vendors = vendorsOf(db, src)
    local price, npc = db.VendorPrice(itemID)
    if num(price) then out.vendorPrice = { price = price, npc = num(npc) } end
    out.quests = questRows(db, itemID, ctx)
    out.rewardFrom = list(db.RewardFrom(itemID))
    local starts = db.StartsQuest(itemID)
    out.startsQuest = type(starts) == "table" and starts or nil
    out.skinnedFrom = skinRows(db, itemID)
end

--- The facts about `itemID` that cannot change in a session (see the header for `ctx`). ForeverDB's
--- parts are empty unless ctx.fdb is "loaded"; crafting comes from the shipped table either way.
--- @param itemID number
--- @param ctx table
--- @return table|nil nil for no item id
function IS.Static(itemID, ctx)
    itemID = num(itemID)
    if not itemID or itemID < 1 then return nil end
    ctx = ctx or {}
    local db = ctx.fdb == "loaded" and type(ctx.db) == "table" and ctx.db or nil
    local out = {
        id = itemID, fdb = ctx.fdb or "missing", item = itemFacts(itemID, ctx, db),
        drops = {}, vendors = {}, quests = {}, rewardFrom = {}, skinnedFrom = {},
        crafting = IS.CraftingRows(itemID, ctx.recipes, ctx.learned),
    }
    if db then fromForeverDB(out, db, itemID, ctx) end
    return out
end

-- ── the live half ───────────────────────────────────────────────────────────────────────────

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function liveQuests(quests, ctx)
    local out = {}
    for i, q in ipairs(quests) do
        local row = copy(q)
        row.state = type(ctx.questState) == "function" and ctx.questState(q.id) or "todo"
        out[i] = row
    end
    return out
end

local function liveCrafting(rows, ctx)
    local out = {}
    local ranks = type(ctx.ranks) == "table" and ctx.ranks or {}
    for i, r in ipairs(rows) do
        local row = copy(r)
        row.known = type(ctx.knows) == "function" and ctx.knows(r.spell) == true or false
        row.rank = r.skillLine and num(ranks[r.skillLine]) or nil
        row.color = IS.SkillColor(row.rank, r.yellow, r.gray)
        out[i] = row
    end
    return out
end

--- A new facts table: `static`'s fields with the live reads added (see the header for `ctx`).
--- `static` itself is never changed, so a cached one can be read again.
--- @param static table IS.Static's answer
--- @param ctx table
--- @return table
function IS.Live(static, ctx)
    ctx = ctx or {}
    local out = copy(static)
    out.quests = liveQuests(static.quests, ctx)
    out.crafting = liveCrafting(static.crafting, ctx)
    out.ranks = type(ctx.ranks) == "table" and ctx.ranks or nil
    return out
end

--- Everything Drop Watcher knows about `itemID`: IS.Live(IS.Static(itemID, ctx), ctx), or nil for
--- no item id.
--- @param itemID number
--- @param ctx table
--- @return table|nil
function IS.Facts(itemID, ctx)
    local static = IS.Static(itemID, ctx)
    if not static then return nil end
    return IS.Live(static, ctx)
end

-- ── what is shown first: the ranking (Item Search feedback spec §3) ────────────────────────
--
-- IS.Rank.<section>(rows, me) answers a NEW array of the same rows, best for the player first; the
-- tooltip and the window's default sort ("Best for you") both use it. Each row gets a tier (best
-- first), ties fall to the section's own rule, then to the name, then to the id. Pure: `me` is the
-- context, every field optional (a missing one ranks as unknown, never as an error):
--   level        the player's level
--   mapID        the player's zone (the best map, walked up to its zone)
--   continentID  that zone's continent; continentOf(map) -> a map's continent
--   faction      "A" | "H" (UnitFactionGroup's first letter)
--   ranks        { [skillLine] = rank }
--   known(spell) -> boolean, for a row that carries no `known`
--   questState(id) -> "done" | "ready" | "log" | "todo", for a row that carries no `state`
--   spots(kind, id) -> ForeverDB's Spots answer, `{ [uiMapID] = { { x, y }, ... } }`
--
-- THE LEVEL BAND. A creature is in your band when its level range overlaps
-- [level - IS.LEVEL_BAND.below, level + IS.LEVEL_BAND.above]: a little below you is easy to farm,
-- well above is not (the spec's call).

IS.LEVEL_BAND = { below = 5, above = 3 }
IS.Rank = IS.Rank or {}
local Rank = IS.Rank

local SKILL_UP = { orange = 1, yellow = 2, green = 3 }

--- Whether a level range overlaps the band around `level`. A missing level on either side: false.
--- @param minLevel number|nil
--- @param maxLevel number|nil
--- @param level number|nil
--- @return boolean
function IS.InBand(minLevel, maxLevel, level)
    minLevel, level = num(minLevel), num(level)
    if not (minLevel and level) then return false end
    local maxL = num(maxLevel) or minLevel
    return minLevel <= level + IS.LEVEL_BAND.above and maxL >= level - IS.LEVEL_BAND.below
end

-- THE SPOT MEMO (the feedback review's perf finding). ForeverDB's Spots builds new point tables on
-- every call, and the ranking asks it for every npc and object row on every hover. A source's spots
-- never move in a session, so the set of maps it has a spot on is read once per spots reader (a weak
-- key: ForeverDB's Spots in the client, a test's fake in the suite) and kept:
-- `{ [spots] = { [kind] = { [id] = { [map] = true } | false } } }`. IS.ForgetSpots empties it when
-- ForeverDB's state moves (modules/ItemSearch.lua's IS.State).
local spotMaps = setmetatable({}, { __mode = "k" })

--- Empty the spot memo (ForeverDB's state moved, or a test swapped the fake's rows).
function IS.ForgetSpots()
    spotMaps = setmetatable({}, { __mode = "k" })
end

-- The maps `id` (of `kind`) has a spot on, `{ [map] = true }`, or nil; read once per reader.
local function mapsOf(spots, kind, id)
    if id == nil then return nil end
    local byKind = spotMaps[spots]
    if not byKind then byKind = {}; spotMaps[spots] = byKind end
    local byId = byKind[kind]
    if not byId then byId = {}; byKind[kind] = byId end
    local maps = byId[id]
    if maps == nil then
        maps = false
        for map, points in pairs(list(spots(kind, id))) do
            if #list(points) > 0 then
                maps = maps or {}
                maps[map] = true
            end
        end
        byId[id] = maps
    end
    return maps or nil
end

-- Whether one source has a spot on `zone` (a map id), or, with `continent`, on a map of it.
local function spotHit(me, kind, id, zone, continent)
    local maps = mapsOf(me.spots, kind, id)
    if not maps then return false end
    if zone then return maps[zone] == true end
    for map in pairs(maps) do
        if me.continentOf(map) == continent then return true end
    end
    return false
end

-- Whether any of the row's ids (a merged object's every part, else its own) has a spot there.
local function anySpot(me, kind, row, zone, continent)
    if type(me.spots) ~= "function" then return false end
    local ids = row.ids
    if type(ids) == "table" and #ids > 0 then
        for _, id in ipairs(ids) do
            if spotHit(me, kind, id, zone, continent) then return true end
        end
        return false
    end
    return spotHit(me, kind, row.id, zone, continent)
end

local function inZone(me, kind, row)
    local zone = num(me.mapID)
    if not zone then return false end
    return anySpot(me, kind, row, zone, nil)
end

local function onContinent(me, kind, row)
    local continent = num(me.continentID)
    if not continent or type(me.continentOf) ~= "function" then return false end
    return anySpot(me, kind, row, nil, continent)
end

-- A higher chance first, an unknown one last (chance is 0..1).
local function chanceKey(chance)
    chance = num(chance)
    return chance and -chance or 1
end

-- A row's name for the tie-break, or nil.
local function nameOf(row)
    return type(row.name) == "string" and row.name or nil
end

-- `a` before `b` by name (a named row before an unnamed one), then by id; nil for a full tie.
local function nameBefore(a, b)
    local na, nb = nameOf(a), nameOf(b)
    if na ~= nb then
        if na == nil then return false end
        if nb == nil then return true end
        return na < nb
    end
    local ia, ib = num(a.id) or num(a.spell) or 0, num(b.id) or num(b.spell) or 0
    if ia ~= ib then return ia < ib end
    return nil
end

-- The sort's keys: two scratch tables, row -> tier and row -> within-tier key, emptied after each
-- sort (they keep their size, so a hover's ranking allocates no key table and no comparator: the
-- feedback review's perf finding). Nothing in a keyOf sorts, so one pair serves every call.
local tierOf, subOf = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })

local function keyOrder(a, b)
    if tierOf[a] ~= tierOf[b] then return tierOf[a] < tierOf[b] end
    if subOf[a] ~= subOf[b] then return subOf[a] < subOf[b] end
    return nameBefore(a, b) == true
end

-- A new array of `rows` sorted by `keyOf(row, me)`: two numbers, a tier and a within-tier key, the
-- lower first, then the name, then the id. A run of one row or none is not sorted at all.
local function sortBy(rows, keyOf, me)
    local out = {}
    for i, row in ipairs(list(rows)) do out[i] = row end
    if #out < 2 then return out end
    for _, row in ipairs(out) do tierOf[row], subOf[row] = keyOf(row, me) end
    table.sort(out, keyOrder)
    for _, row in ipairs(out) do tierOf[row], subOf[row] = nil, nil end
    return out
end

local function dropTier(row, me)
    local kind = row.kind or "npc"
    if (kind == "npc" or kind == "object") and inZone(me, kind, row) then return 1 end
    if kind ~= "npc" then return 2 end
    return IS.InBand(row.minLevel, row.maxLevel, me.level) and 2 or 3
end

local function dropKey(row, me)
    return dropTier(row, me), chanceKey(row.chance)
end

--- DROPS FROM: a spot in your zone; then a creature in your band, or an object or container (no
--- level); then a creature outside the band. Within a tier, the higher chance first.
--- @param rows table facts.drops
--- @param me table
--- @return table
function Rank.drops(rows, me)
    me = me or {}
    return sortBy(rows, dropKey, me)
end

-- Whether a vendor's side (`nfac`) leaves the player out: it names the other side alone.
local function otherSide(row, me)
    local f, mine = row.faction, me.faction
    if type(f) ~= "string" or (mine ~= "A" and mine ~= "H") then return false end
    return f:find(mine, 1, true) == nil
end

--- Whether a vendor serves only the other side (`nfac` names the other side alone): the window's
--- "can't buy" and its "Only my faction" filter (feedback spec §5.4, §5.5). No known side: false.
--- @param row table a vendor row (`faction`)
--- @param me table IS.Rank's context (`faction`)
--- @return boolean
function IS.OtherSide(row, me)
    return otherSide(row, me or {})
end

local function vendorTier(row, me)
    if otherSide(row, me) then return 4 end
    if inZone(me, "npc", row) then return 1 end
    if onContinent(me, "npc", row) then return 2 end
    return 3
end

local function vendorKey(row, me)
    return vendorTier(row, me), 0
end

--- SOLD BY: in your zone, then on your continent, then elsewhere, last a vendor your side can't
--- use. Within a tier, the name. (The spec's "unlimited stock before limited" waits on LibKa0s
--- exposing ForeverDB's vendor stock, docs/known-limitations.md: the adapter gives no stock today.)
--- @param rows table facts.vendors
--- @param me table
--- @return table
function Rank.vendors(rows, me)
    me = me or {}
    return sortBy(rows, vendorKey, me)
end

local function questStateOf(row, me)
    if row.state then return row.state end
    if type(me.questState) == "function" then return me.questState(row.id) end
    return "todo"
end

local function questTier(row, me)
    local state = questStateOf(row, me)
    if state == "log" or state == "ready" then return 1 end
    if state == "done" then return 4 end
    local level, minLevel = num(me.level), num(row.minLevel)
    if not (level and minLevel) or level >= minLevel then return 2 end
    return 3
end

-- Within the log's tier, a quest ready to turn in comes before every one still in progress.
local READY_FIRST = 1e6

local function questKey(row, me)
    local tier = questTier(row, me)
    local level = num(row.level) or math.huge
    if tier == 1 and questStateOf(row, me) == "ready" then level = (num(row.level) or 0) - READY_FIRST end
    return tier, level
end

--- QUESTS: in your log (ready to turn in first), then can pick up now (your level at least its
--- minimum, not done), then too high for you now, last completed. Within a tier, the lower quest
--- level first.
--- @param rows table facts.quests (or the Reward from / Starts rows)
--- @param me table
--- @return table
function Rank.quests(rows, me)
    me = me or {}
    return sortBy(rows, questKey, me)
end

local function knownOf(row, me)
    if row.known ~= nil then return row.known == true end
    return type(me.known) == "function" and me.known(row.spell) == true
end

local function rankOf(row, me)
    local ranks = type(me.ranks) == "table" and me.ranks or nil
    return num(row.rank) or (ranks and row.skillLine and num(ranks[row.skillLine])) or nil
end

-- A crafting row's tier and its within-tier key.
local function craftKey(row, me)
    local rank = rankOf(row, me)
    if knownOf(row, me) then
        local color = row.color or IS.SkillColor(rank, row.yellow, row.gray)
        local up = SKILL_UP[color]
        if up then return 1, up end
        return 2, 0
    end
    if rank then
        local yellow = num(row.yellow)
        return 3, yellow and math.abs(yellow - rank) or math.huge
    end
    return 4, 0
end

--- CRAFTING: known and can skill up (orange, then yellow, then green), then known with no skill-up
--- (gray, or no breakpoints), then not known in a profession you have (the yellow breakpoint
--- nearest your rank first; the shipped `min` is 1 for nearly every recipe, so it cannot order
--- them), last a profession you don't have.
--- @param rows table facts.crafting (live: `known`, `rank`, `color`)
--- @param me table
--- @return table
function Rank.crafting(rows, me)
    me = me or {}
    return sortBy(rows, craftKey, me)
end

local function skinTier(row, me)
    if inZone(me, "npc", row) then return 1 end
    return IS.InBand(row.minLevel, row.maxLevel, me.level) and 2 or 3
end

local function skinKey(row, me)
    return skinTier(row, me), chanceKey(row.chance)
end

--- SKINNED FROM: a spot in your zone, then in your level band, then the rest. Within a tier, the
--- higher chance first.
--- @param rows table facts.skinnedFrom
--- @param me table
--- @return table
function Rank.skinned(rows, me)
    me = me or {}
    return sortBy(rows, skinKey, me)
end

-- ── the professions you know (spec §4) and the cap (spec §7) ───────────────────────────────

--- Whether the player's skills have been read: a ranks table with at least one line. Before that,
--- the profession filter lets everything through (spec §4).
--- @param ranks table|nil
--- @return boolean
function IS.SkillsRead(ranks)
    return type(ranks) == "table" and next(ranks) ~= nil
end

--- The crafting rows in professions the player has a rank in (spec §4), and how many were left
--- out. With `on` false, or before the skills are read, every row passes (0 left out). A row with
--- no skill line passes.
--- @param rows table
--- @param ranks table|nil
--- @param on boolean
--- @return table kept, number hidden
function IS.FilterProfessions(rows, ranks, on)
    local kept, hidden = {}, 0
    local filter = on == true and IS.SkillsRead(ranks)
    for _, row in ipairs(list(rows)) do
        if filter and row.skillLine and not num(ranks[row.skillLine]) then
            hidden = hidden + 1
        else
            kept[#kept + 1] = row
        end
    end
    return kept, hidden
end

--- A rows-per-section value as the tooltip uses it: a whole IS.TIP_ROWS_MIN..IS.TIP_ROWS_MAX,
--- IS.TIP_ROWS for anything not a number.
--- @param v any
--- @return number
function IS.ClampRows(v)
    v = num(tonumber(v))
    if not v then return IS.TIP_ROWS end
    return math.max(IS.TIP_ROWS_MIN, math.min(IS.TIP_ROWS_MAX, floor(v)))
end

--- The first `n` of `rows` (a new array) and how many are past them ("and N more", spec §7).
--- @param rows table
--- @param n number
--- @return table shown, number more
function IS.Cap(rows, n)
    rows = list(rows)
    n = IS.ClampRows(n)
    local shown = {}
    for i = 1, math.min(n, #rows) do shown[i] = rows[i] end
    return shown, #rows - #shown
end

--- Every section ranked for `me` (spec §3), the crafting rows filtered first when `mine` (spec §4):
--- `{ drops, vendors, quests, crafting, craftHidden, skinned }`, new arrays.
--- @param facts table IS.Live's answer
--- @param me table
--- @param mine boolean only the professions you know
--- @return table
function IS.Ranked(facts, me, mine)
    me = me or {}
    local crafting, hidden = IS.FilterProfessions(facts.crafting, me.ranks, mine)
    return {
        drops = Rank.drops(facts.drops, me), vendors = Rank.vendors(facts.vendors, me),
        quests = Rank.quests(facts.quests, me), crafting = Rank.crafting(crafting, me), craftHidden = hidden,
        skinned = Rank.skinned(facts.skinnedFrom, me),
    }
end
