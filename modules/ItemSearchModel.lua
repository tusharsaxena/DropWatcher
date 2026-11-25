local _, NS = ...
-- modules/ItemSearchModel.lua — Item Search's pure model (DropWatcher#17, Item Search spec §4.3):
-- everything Drop Watcher knows about one item, for the tooltip block and the Item Search window.
-- No client call and no setting read here: every input arrives in `ctx`, so a case drives it with
-- invented values. modules/ItemSearch.lua builds the context, caches the answer and gates it.
--
-- IS.Facts(itemID, ctx) answers
--   { id, item, drops, dropMore, worldMinLevel, vendors, vendorPrice, quests, crafting,
--     rewardFrom, startsQuest, skinnedFrom, fdb }
-- in two halves. IS.Static(itemID, ctx) is the part that cannot change in a session (ForeverDB is
-- static data, the recipe table is shipped, a quest's masks and the player's race and class are
-- fixed), so modules/ItemSearch.lua keeps it per item. IS.Live(static, ctx) copies it and adds what
-- is read live: each quest's state, each recipe's known mark, the player's rank and the skill-up
-- color, and how many drop sources are past the shown ones.
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
--   questState function(questID) -> "log" | "done" | "todo"
--   knows      function(spell) -> boolean|nil
--   ranks      { [skillLine] = rank } or nil
--   dropsShown how many drop sources are shown before "and N more" (default IS.DROPS_SHOWN)
--
-- DROPS AND VENDORS are SF-DW-01's model, moved here (modules/ItemSources.lua reads IS.Percent and
-- IS.MergeSources): the creatures, objects and containers merged into one list, a known chance
-- first, the higher first, an unknown rate last, then creature, object, container, then the id. A
-- creature carries its level range; an object its stand-in name (the library reads no object name).
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

IS.DROPS_SHOWN = 3   -- the tooltip's default count of drop sources (spec §4.7: 3, range 1 to 10)

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

-- A source's name, level range and whether the name is real, from the reader.
local function describe(db, s)
    if s.kind == "npc" then
        local n = db.NPC(s.id)
        if type(n) == "table" and n.name then
            s.name, s.named, s.minLevel, s.maxLevel = n.name, true, num(n.minLevel), num(n.maxLevel)
            return s
        end
        s.name, s.named = L["Creature %d"]:format(s.id), false
    elseif s.kind == "item" then
        local it = db.Item(s.id)
        if type(it) == "table" and it.name then s.name, s.named = it.name, true; return s end
        s.name, s.named = L["Item %d"]:format(s.id), false
    else
        s.name, s.named = L["Object %d"]:format(s.id), false
    end
    return s
end

local function npcName(db, id)
    local n = db.NPC(id)
    if type(n) == "table" and n.name then return n.name end
    return L["Creature %d"]:format(id)
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

local function vendorsOf(db, src)
    local out = {}
    for _, id in ipairs(list(type(src) == "table" and src.vendors)) do
        if num(id) then out[#out + 1] = { id = id, name = npcName(db, id) } end
    end
    return out
end

local function skinRows(db, itemID)
    local out = {}
    for _, s in ipairs(list(db.SkinnedFrom(itemID))) do
        if type(s) == "table" and num(s.id) then
            out[#out + 1] = { id = s.id, name = s.name or L["Creature %d"]:format(s.id), chance = num(s.chance) }
        end
    end
    return out
end

-- The ForeverDB half of the static facts, onto `out`.
local function fromForeverDB(out, db, itemID, ctx)
    local src = db.ItemSources(itemID)
    for _, s in ipairs(IS.MergeSources(src)) do out.drops[#out.drops + 1] = describe(db, s) end
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
    local shown = num(ctx.dropsShown) or IS.DROPS_SHOWN
    out.dropMore = math.max(0, #static.drops - shown)
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
