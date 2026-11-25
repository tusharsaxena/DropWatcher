local _, NS = ...
-- modules/ItemSearchCells.lua — the Item Search window's table rows, pure (Item Search feedback spec
-- §5.4, §5.6; mockups V2Window and V2Tabs): one builder per tab turns an item's facts
-- (NS.ItemSearch.Get's answer) into display rows, each a plain table the frame edge
-- (modules/ItemSearchGrid.lua) draws and modules/ItemSearchTabs.lua filters and sorts. No client
-- call and no setting read here: every input arrives in `me` (NS.ItemSearch.Me's context) and `ctx`.
--
-- A ROW is
--   { best, cells = { [column key] = cell }, sort = { [column key] = value }, tip, spot, itemID,
--     flags... }
-- `best` is the row's place in the section's ranking (IS.Rank.<section>, spec §3: "Best for you",
-- the tables' default sort). A cell is `{ text, tone }` (a C.TONE key), `{ text, quality }` (an
-- item's name in its quality color), `{ parts = { { text, tone } } }` (the skill breakpoints),
-- `{ pct, fraction, known }` (a chance bar), `{ craft = row }` (the recipe glyph, NS.ItemSearchTip's
-- CraftMark) or `{ mark }` (a quest's state mark). `sort` holds each sortable column's value (a
-- number or a lower-cased string; nil sorts last). `tip` is `{ title, rows = { { label, value } },
-- hints }`, or `{ item = id }` for the item's own game tooltip (a container, spec §5.6). A row's
-- flags are what the tabs' filters read: `kind`, `here` (a spot in your zone), `band` (in your
-- level band; nil where there is no level), `other` (a vendor of the other side only), `state`,
-- `mine` (a profession you have), `known`.
--
-- `ctx`: { spots(kind, id), mapName(map), npc(id), object(id), quest(id), item(id) -> { name,
-- quality }, profession(skillLine), coin(copper) -> text }. Each is optional; a missing one leaves
-- its cell at the dim dash.
--
-- THE CLIENT GIVES NO DATA FOR (spec §5.4 lets such a column go): Sold by's Stock and Requires
-- (ForeverDB's vendx is not in LibKa0s-ForeverDB-1.0's surface) and Quests' objective count. The
-- price is the item's lowest price seen at any vendor (VendorPrice), on the vendor it was seen at.

NS.ItemSearchCells = NS.ItemSearchCells or {}
local ISC = NS.ItemSearchCells
local IS  = NS.ItemSearch
local ISV = NS.ItemSearchView
local L   = NS.L

local floor = math.floor

local DASH = "–"

-- The Skinning skill line (the Skinned from tab's Skill column, spec §5.4).
ISC.SKINNING = 393

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function list(v)
    if type(v) == "table" then return v end
    return {}
end

local function call(fn, ...)
    if type(fn) == "function" then return fn(...) end
    return nil
end

local function lower(s)
    return type(s) == "string" and s:lower() or nil
end

-- A text cell: `text` in `tone` (plain by default), or the dim dash when there is no text.
local function textCell(text, tone)
    if text == nil then return { text = DASH, tone = "muted" } end
    return { text = text, tone = tone or "plain" }
end

local function numText(v)
    return num(v) and tostring(v) or nil
end

-- ── levels ──────────────────────────────────────────────────────────────────────────────────

--- The highest level that reads gray (trivial) for a player of `level`: the classic quest-color
--- rule (own call, spec §5.4 "the game's quest-difficulty colors"), no gray below level 6.
--- @param level number
--- @return number
function ISC.GrayLevel(level)
    level = num(level) or 0
    if level <= 5 then return 0 end
    if level <= 39 then return level - 5 - floor(level / 10) end
    if level <= 59 then return level - 1 - floor(level / 5) end
    return level - 9
end

--- A level's difficulty tone against the player's (the game's quest-difficulty colors): `red` five
--- or more above, `skillOrange` three or four above, `skillYellow` within two, `skillGreen` below
--- that and above gray, `skillGray` trivial. Either level unknown: `plain`.
--- @param level number|nil
--- @param myLevel number|nil
--- @return string a C.TONE key
function ISC.LevelTone(level, myLevel)
    level, myLevel = num(level), num(myLevel)
    if not (level and myLevel) then return "plain" end
    local d = level - myLevel
    if d >= 5 then return "red" end
    if d >= 3 then return "skillOrange" end
    if d >= -2 then return "skillYellow" end
    if level > ISC.GrayLevel(myLevel) then return "skillGreen" end
    return "skillGray"
end

-- A level cell: the range in its difficulty tone, or the dim dash.
local function levelCell(minLevel, maxLevel, myLevel)
    local text = ISV.LevelText(minLevel, maxLevel)
    if not text then return { text = DASH, tone = "muted" } end
    return { text = text, tone = ISC.LevelTone(minLevel, myLevel) }
end

-- ── where a source stands ───────────────────────────────────────────────────────────────────

--- Where a source stands, from its spots `{ [uiMapID] = { { x, y }, ... } }`: `{ map, spot, zone,
--- zones, counts }`. The map is your zone (`here`) when it has a spot there, else the one with the
--- most spots (the lower id on a tie); `spot` is that map's first spot; `zones` how many maps it
--- stands on; `counts` each map's `{ zone, n }`, the most spots first. Nil with no spot.
--- @param spots table|nil
--- @param here number|nil the player's zone
--- @param mapName function|nil
--- @return table|nil
function ISC.Where(spots, here, mapName)
    local first = ISV.SpotOf(spots)
    if not first then return nil end
    local map = first.map
    local own = here and list(spots)[here]
    if own and #own > 0 then map = here end
    local counts = {}
    for m, points in pairs(spots) do
        local n = #list(points)
        if num(m) and n > 0 then
            counts[#counts + 1] = { map = m, zone = call(mapName, m) or L["Map %d"]:format(m), n = n }
        end
    end
    table.sort(counts, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.map < b.map end)
    local p = spots[map][1]
    local spot = type(p) == "table" and num(p.x) and num(p.y) and { map = map, x = p.x, y = p.y } or nil
    return { map = map, spot = spot, zone = call(mapName, map), zones = #counts, counts = counts }
end

--- A Zone cell: the zone, "+N zones" after it when it stands on more than one, the dim dash when
--- unknown.
--- @param where table|nil ISC.Where's answer
--- @return table cell
function ISC.ZoneCell(where)
    if not (where and where.zone) then return { text = DASH, tone = "muted" } end
    local extra = where.zones - 1
    if extra == 1 then return { text = L["%s +1 zone"]:format(where.zone), tone = "plain" } end
    if extra > 1 then return { text = L["%s +%d zones"]:format(where.zone, extra), tone = "plain" } end
    return { text = where.zone, tone = "plain" }
end

-- A merged object's spots (spec §2: `ids`) are the union of every part's, map by map.
local function unionSpots(kind, ids, spots)
    local out, any = {}, false
    for _, id in ipairs(ids) do
        for map, points in pairs(list(call(spots, kind, id))) do
            local into = out[map] or {}
            out[map] = into
            for _, p in ipairs(list(points)) do into[#into + 1] = p; any = true end
        end
    end
    return any and out or nil
end

local function spotsOf(kind, row, ctx)
    if kind ~= "npc" and kind ~= "object" then return nil end
    local ids = list(row.ids)
    if #ids > 1 then return unionSpots(kind, ids, ctx.spots) end
    return call(ctx.spots, kind, row.id)
end

-- The tooltip's zone rows: "Fixture Vale (2 spots)" per map.
local function zoneRows(rows, where)
    for _, c in ipairs(where and where.counts or {}) do
        local spots = c.n == 1 and L["1 spot"] or L["%d spots"]:format(c.n)
        rows[#rows + 1] = { L["Zone"], ("%s (%s)"):format(c.zone, spots) }
    end
end

local function pinHint(hints, where)
    if where and where.spot then hints[#hints + 1] = L["Click the pin: set a waypoint"] end
end

-- A chance cell: the percent and the bar's fraction of the top chance.
local function chanceCell(chance, top)
    chance = num(chance)
    return { pct = IS.Percent(chance) or L["rate unknown"], fraction = (chance and top > 0) and chance / top or 0,
        known = chance ~= nil }
end

local function topChance(rows)
    local top = 0
    for _, r in ipairs(list(rows)) do
        if num(r.chance) and r.chance > top then top = r.chance end
    end
    return top
end

-- ── Drops from ──────────────────────────────────────────────────────────────────────────────

local RANK_TYPE = { [1] = L["Elite"], [2] = L["Rare Elite"], [3] = L["Boss"], [4] = L["Rare"] }
-- The Type column's sort order: creatures by rank, then objects, then containers.
local TYPE_ORDER = { [0] = 1, [1] = 2, [4] = 3, [2] = 4, [3] = 5 }

--- A drop source's Type: Creature, Elite, Rare, Rare Elite or Boss (its `rank`), Object (with ×N
--- for a merged one), Container.
--- @param s table a drop row (`kind`, `rank`, `ids`)
--- @return string text, number order
function ISC.TypeOf(s)
    if s.kind == "item" then return L["Container"], 7 end
    if s.kind == "object" then
        local n = #list(s.ids)
        return n > 1 and L["Object ×%d"]:format(n) or L["Object"], 6
    end
    local rank = num(s.rank) or 0
    return RANK_TYPE[rank] or L["Creature"], TYPE_ORDER[rank] or 1
end

local function sourceCell(s, ctx)
    if s.kind == "item" then
        local it = call(ctx.item, s.id)
        return { text = s.name, quality = type(it) == "table" and num(it.quality) or nil }
    end
    if not s.named then return { text = s.name, tone = "muted" } end
    return { text = s.name, tone = s.kind == "npc" and "red" or "plain" }
end

local function dropTip(s, typeText, where, me)
    local rows, hints = {}, {}
    local level = ISV.LevelText(s.minLevel, s.maxLevel)
    rows[1] = { L["Type"], level and L["%s, level %s"]:format(typeText, level) or typeText }
    zoneRows(rows, where)
    rows[#rows + 1] = { L["Chance"], IS.Percent(s.chance) or L["rate unknown"] }
    local n = #list(s.ids)
    if n > 1 then rows[#rows + 1] = { L["Merged"], L["%d kinds of %s"]:format(n, s.name) } end
    if s.kind == "npc" and level then
        hints[#hints + 1] = IS.InBand(s.minLevel, s.maxLevel, me.level) and L["In your level band"]
            or L["Outside your level band"]
    end
    pinHint(hints, where)
    return { title = s.name, rows = rows, hints = hints }
end

local function dropRow(s, i, top, me, ctx)
    local where = ISC.Where(spotsOf(s.kind, s, ctx), me.mapID, ctx.mapName)
    local typeText, typeOrder = ISC.TypeOf(s)
    local chance = chanceCell(s.chance, top)
    local hasLevel = num(s.minLevel) ~= nil
    return {
        best = i, kind = s.kind, id = s.id, spot = where and where.spot or nil,
        itemID = s.kind == "item" and s.id or nil,
        here = where ~= nil and me.mapID ~= nil and where.map == me.mapID,
        band = (s.kind == "npc" and hasLevel) and IS.InBand(s.minLevel, s.maxLevel, me.level) or nil,
        cells = { source = sourceCell(s, ctx), type = { text = typeText, tone = "muted" },
            level = levelCell(s.minLevel, s.maxLevel, me.level), zone = ISC.ZoneCell(where), chance = chance },
        sort = { source = lower(s.name), type = typeOrder, level = num(s.minLevel), zone = lower(where and where.zone),
            chance = num(s.chance) },
        tip = s.kind == "item" and { item = s.id } or dropTip(s, typeText, where, me),
    }
end

-- The World drop row: anywhere from its level, always the last row whatever the sort.
local function worldRow(minLevel, n)
    local level = L["level %d+"]:format(minLevel)
    return {
        best = n, kind = "world", world = true, here = true,
        cells = { source = { text = L["World drop"], tone = "muted" }, type = { text = DASH, tone = "muted" },
            level = { text = level, tone = "muted" }, zone = { text = DASH, tone = "muted" },
            chance = { pct = DASH, fraction = 0, known = false } },
        sort = {},
        tip = { title = L["World drop"], rows = { { L["Drops"], L["anywhere, from level %d"]:format(minLevel) } }, hints = {} },
    }
end

--- DROPS FROM's rows, best for you first (IS.Rank.drops), then the World drop row.
--- @param facts table
--- @param me table
--- @param ctx table|nil
--- @return table
function ISC.Drops(facts, me, ctx)
    me, ctx = me or {}, ctx or {}
    local ranked = IS.Rank.drops(facts.drops, me)
    local top = topChance(ranked)
    local out = {}
    for i, s in ipairs(ranked) do out[i] = dropRow(s, i, top, me, ctx) end
    if num(facts.worldMinLevel) then out[#out + 1] = worldRow(facts.worldMinLevel, #out + 1) end
    return out
end

-- ── Sold by ─────────────────────────────────────────────────────────────────────────────────

local FACTION = { A = L["Alliance"], H = L["Horde"], AH = L["Both"] }

--- A vendor's Faction cell: Alliance, Horde or Both, "can't buy" in red for the other side alone,
--- the dim dash when ForeverDB names no side.
--- @param v table a vendor row (`faction`)
--- @param me table
--- @return table cell
function ISC.FactionCell(v, me)
    if IS.OtherSide(v, me) then return { text = L["can't buy"], tone = "red" } end
    local text = FACTION[v.faction]
    if not text then return { text = DASH, tone = "muted" } end
    return { text = text, tone = "plain" }
end

local function vendorTip(v, where, priceText, faction)
    local rows, hints = {}, {}
    if v.subname then rows[#rows + 1] = { L["Title"], v.subname } end
    if where and where.zone then rows[#rows + 1] = { L["Zone"], where.zone } end
    rows[#rows + 1] = { L["Price"], priceText and L["%s (the lowest seen)"]:format(priceText) or L["not seen here"] }
    rows[#rows + 1] = { L["Faction"], faction.text }
    pinHint(hints, where)
    return { title = v.name, rows = rows, hints = hints }
end

local function vendorRow(v, i, price, me, ctx)
    local where = ISC.Where(call(ctx.spots, "npc", v.id), me.mapID, ctx.mapName)
    local mine = price and price.npc == v.id and num(price.price) or nil
    local priceText = mine and (call(ctx.coin, mine) or tostring(mine)) or nil
    local faction = ISC.FactionCell(v, me)
    local level = ISV.LevelText(v.minLevel, v.maxLevel)
    return {
        best = i, id = v.id, spot = where and where.spot or nil, other = IS.OtherSide(v, me),
        cells = { vendor = textCell(v.name), level = textCell(level), zone = ISC.ZoneCell(where), faction = faction,
            price = textCell(priceText) },
        sort = { vendor = lower(v.name), level = num(v.minLevel), zone = lower(where and where.zone),
            faction = lower(faction.text), price = mine },
        tip = vendorTip(v, where, priceText, faction),
    }
end

--- SOLD BY's rows, best for you first (IS.Rank.vendors).
--- @return table
function ISC.Vendors(facts, me, ctx)
    me, ctx = me or {}, ctx or {}
    local price = type(facts.vendorPrice) == "table" and facts.vendorPrice or nil
    local out = {}
    for i, v in ipairs(IS.Rank.vendors(facts.vendors, me)) do out[i] = vendorRow(v, i, price, me, ctx) end
    return out
end

-- ── Quests ──────────────────────────────────────────────────────────────────────────────────

ISC.ROLE_LABEL = { needs = L["Needs it"], rewards = L["Rewards it"], starts = L["Starts it"] }
local ROLE_ORDER = { needs = 1, rewards = 2, starts = 3 }
local STATUS_ORDER = { log = 1, can = 2, high = 3, done = 4 }

--- A quest's status for the player: "log" (in your log), "can" (can pick up now), "high" (its
--- minimum level is above yours) or "done".
--- @param state string "log" | "done" | "todo"
--- @param minLevel number|nil
--- @param level number|nil the player's
--- @return string
function ISC.QuestStatus(state, minLevel, level)
    if state == "log" or state == "done" then return state end
    minLevel, level = num(minLevel), num(level)
    if minLevel and level and level < minLevel then return "high" end
    return "can"
end

local function statusText(status, minLevel)
    if status == "log" then return L["In your log"] end
    if status == "done" then return L["Completed"] end
    if status == "high" then return L["Requires level %d"]:format(minLevel) end
    return L["Can pick up"]
end

-- The quest rows of every role: the objectives, then the rewards, then the quest the item starts.
local function questInputs(facts)
    local out = {}
    for _, q in ipairs(list(facts.quests)) do
        out[#out + 1] = { id = q.id, title = q.title, level = num(q.level), minLevel = num(q.minLevel), state = q.state,
            role = "needs" }
    end
    for _, q in ipairs(list(facts.rewardFrom)) do
        out[#out + 1] = { id = q.id, title = q.title, level = num(q.level), role = "rewards" }
    end
    local s = facts.startsQuest
    if type(s) == "table" and num(s.id) then
        out[#out + 1] = { id = s.id, title = s.title, level = num(s.level), role = "starts" }
    end
    return out
end

-- The quest's first giver: its name and where it stands.
local function giverOf(info, me, ctx)
    local g = type(info) == "table" and list(info.givers)[1] or nil
    if type(g) ~= "table" or not num(g.id) then return nil, nil end
    local reader = g.kind == "object" and ctx.object or ctx.npc
    local row = call(reader, g.id)
    local name = type(row) == "table" and row.name or nil
    local where = ISC.Where(call(ctx.spots, g.kind, g.id), me.mapID, ctx.mapName)
    return name, where
end

local function giverText(name, where)
    if not name then return DASH end
    if where and where.zone then return L["%s · %s"]:format(name, where.zone) end
    return name
end

local function questTip(q, title, status, giver, where)
    local rows, hints = { { L["Role"], ISC.ROLE_LABEL[q.role] } }, {}
    local level = q.level and tostring(q.level) or DASH
    rows[#rows + 1] = { L["Level"], q.minLevel and L["%s, from %d"]:format(level, q.minLevel) or level }
    rows[#rows + 1] = { L["Status"], statusText(status, q.minLevel) }
    if giver then rows[#rows + 1] = { L["Giver"], giverText(giver, where) } end
    pinHint(hints, where)
    return { title = title, rows = rows, hints = hints }
end

-- The quest's title and levels, where its own row lacks them, from ForeverDB's quest row.
local function fillQuest(q, info)
    if type(info) ~= "table" then return end
    q.title = q.title or info.title
    q.level = q.level or num(info.level)
    q.minLevel = q.minLevel or num(info.minLevel)
end

local function questCells(q, status, title, giver, where, me)
    return { mark = { mark = status }, quest = textCell(title, ISC.LevelTone(q.level, me.level)),
        role = textCell(ISC.ROLE_LABEL[q.role]), level = textCell(numText(q.level)), min = textCell(numText(q.minLevel)),
        status = textCell(statusText(status, q.minLevel), status == "done" and "good" or "muted"),
        giver = giver and textCell(giverText(giver, where)) or textCell(nil) }
end

local function questRow(q, i, me, ctx)
    local info = call(ctx.quest, q.id)
    fillQuest(q, info)
    q.state = q.state or call(me.questState, q.id) or "todo"
    local status = ISC.QuestStatus(q.state, q.minLevel, me.level)
    local title = q.title or L["Quest %d"]:format(q.id)
    local giver, where = giverOf(info, me, ctx)
    return {
        best = i, id = q.id, state = q.state, role = q.role, spot = where and where.spot or nil,
        cells = questCells(q, status, title, giver, where, me),
        sort = { mark = STATUS_ORDER[status], quest = lower(title), role = ROLE_ORDER[q.role], level = q.level,
            min = q.minLevel, status = STATUS_ORDER[status], giver = lower(giver) },
        tip = questTip(q, title, status, giver, where),
    }
end

--- QUESTS' rows: every quest that needs the item, rewards it or the one it starts, as rows with a
--- Role (spec §5.3), best for you first (IS.Rank.quests).
--- @return table
function ISC.Quests(facts, me, ctx)
    me, ctx = me or {}, ctx or {}
    local inputs = questInputs(facts)
    for _, q in ipairs(inputs) do
        local info = call(ctx.quest, q.id)
        if type(info) == "table" then q.minLevel = q.minLevel or num(info.minLevel) end
        q.state = q.state or call(me.questState, q.id)
    end
    local out = {}
    for i, q in ipairs(IS.Rank.quests(inputs, me)) do out[i] = questRow(q, i, me, ctx) end
    return out
end

-- ── Crafting ────────────────────────────────────────────────────────────────────────────────

local COLOR_WORDS = {
    orange = L["Orange: sure to skill up"], yellow = L["Yellow: likely to skill up"],
    green = L["Green: unlikely to skill up"], gray = L["Gray: no skill-up"],
}

--- A recipe's breakpoints as colored parts: orange (its minimum, only above 1: the shipped table's
--- 1 is a placeholder), yellow, green and gray; `{}` without breakpoints.
--- @param r table a crafting row
--- @return table
function ISC.SkillParts(r)
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

--- Whether the player has the recipe's profession: a rank in its skill line, or no skill line, or
--- the skills not read yet (spec §4).
--- @return boolean
function ISC.HasProfession(r, ranks)
    if not r.skillLine or not IS.SkillsRead(ranks) then return true end
    return num(ranks[r.skillLine]) ~= nil
end

--- A recipe's Status: Known; "No <profession>" for a profession you don't have; "Learn at N" only
--- when its minimum is above 1 and above your rank; else Not known.
--- @return string text, string tone, number order
function ISC.CraftStatus(r, ranks, professionName)
    if r.known then return L["Known"], "good", 1 end
    if not ISC.HasProfession(r, ranks) then
        return L["No %s"]:format(professionName or L["profession"]), "muted", 4
    end
    local min, rank = num(r.min), num(r.rank)
    if min and min > 1 and (not rank or min > rank) then return L["Learn at %d"]:format(min), "muted", 3 end
    return L["Not known"], "muted", 2
end

local function craftTip(r, profession, product, rank)
    local rows = { { L["Profession"], profession or DASH } }
    if rank then
        local words = COLOR_WORDS[r.color]
        rows[#rows + 1] = { L["Your rank"], words and ("%d · %s"):format(rank, words) or tostring(rank) }
    end
    if num(r.count) then rows[#rows + 1] = { L["Uses"], L["%d of this item"]:format(r.count) } end
    if product then rows[#rows + 1] = { L["Makes"], product } end
    return { title = r.name or L["Recipe %d"]:format(r.spell), rows = rows, hints = {} }
end

local function productOf(r, ctx)
    if not num(r.made) then return nil, nil end
    local it = call(ctx.item, r.made)
    local name = type(it) == "table" and it.name or L["Item %d"]:format(r.made)
    return name, type(it) == "table" and num(it.quality) or nil
end

local function craftCells(r, name, profession, status, tone, ctx)
    local product, quality = productOf(r, ctx)
    local parts = ISC.SkillParts(r)
    local makes = textCell(product)
    makes.quality = quality
    return { glyph = { craft = r }, recipe = textCell(name, r.known and "plain" or "muted"),
        profession = textCell(profession), uses = textCell(num(r.count) and L["×%d"]:format(r.count) or nil),
        makes = makes, skill = #parts > 0 and { parts = parts } or textCell(nil), status = textCell(status, tone) }, product
end

local function craftRow(r, i, me, ctx)
    local profession = call(ctx.profession, r.skillLine)
    local status, tone, order = ISC.CraftStatus(r, me.ranks, profession)
    local name = r.name or L["Recipe %d"]:format(r.spell)
    local cells, product = craftCells(r, name, profession, status, tone, ctx)
    return {
        best = i, spell = r.spell, known = r.known == true, mine = ISC.HasProfession(r, me.ranks),
        makesID = num(r.made),
        cells = cells,
        sort = { glyph = i, recipe = lower(name), profession = lower(profession), uses = num(r.count),
            makes = lower(product), skill = num(r.yellow), status = order },
        tip = craftTip(r, profession, product, num(r.rank)),
    }
end

--- CRAFTING's rows: every recipe using the item, best for you first (IS.Rank.crafting); the
--- profession filter is the tab's (modules/ItemSearchTabs.lua), so every row is here.
--- @return table
function ISC.Crafting(facts, me, ctx)
    me, ctx = me or {}, ctx or {}
    local out = {}
    for i, r in ipairs(IS.Rank.crafting(facts.crafting, me)) do out[i] = craftRow(r, i, me, ctx) end
    return out
end

-- ── Skinned from ────────────────────────────────────────────────────────────────────────────

--- The Skinning skill a creature of `level` needs: level × 5 above level 20, (level − 10) × 10
--- from 11 to 20, 1 below (spec §5.4). Nil for no level.
--- @param level number|nil
--- @return number|nil
function ISC.SkinSkill(level)
    level = num(level)
    if not level then return nil end
    if level > 20 then return level * 5 end
    return math.max(1, (level - 10) * 10)
end

local function skinSkillCell(need, rank)
    if not need then return { text = DASH, tone = "muted" } end
    if rank and need > rank then return { text = tostring(need), tone = "red" } end
    return { text = tostring(need), tone = rank and "plain" or "muted" }
end

local function skinTip(c, where, need, rank)
    local rows, hints = {}, {}
    local level = ISV.LevelText(c.minLevel, c.maxLevel)
    if level then rows[#rows + 1] = { L["Level"], level } end
    if need then
        rows[#rows + 1] = { L["Skinning"], rank and L["%d (you %d)"]:format(need, rank) or tostring(need) }
    end
    zoneRows(rows, where)
    rows[#rows + 1] = { L["Chance"], IS.Percent(c.chance) or L["rate unknown"] }
    pinHint(hints, where)
    return { title = c.name, rows = rows, hints = hints }
end

local function skinRow(c, i, top, me, ctx)
    local where = ISC.Where(call(ctx.spots, "npc", c.id), me.mapID, ctx.mapName)
    local need = ISC.SkinSkill(c.maxLevel or c.minLevel)
    local ranks = type(me.ranks) == "table" and me.ranks or {}
    local rank = num(ranks[ISC.SKINNING])
    return {
        best = i, id = c.id, spot = where and where.spot or nil, here = where ~= nil and me.mapID ~= nil and where.map == me.mapID,
        cells = { creature = { text = c.name, tone = "plain" }, level = levelCell(c.minLevel, c.maxLevel, me.level),
            skill = skinSkillCell(need, rank), zone = ISC.ZoneCell(where), chance = chanceCell(c.chance, top) },
        sort = { creature = lower(c.name), level = num(c.minLevel), skill = need, zone = lower(where and where.zone),
            chance = num(c.chance) },
        tip = skinTip(c, where, need, rank),
    }
end

--- SKINNED FROM's rows, best for you first (IS.Rank.skinned).
--- @return table
function ISC.Skinned(facts, me, ctx)
    me, ctx = me or {}, ctx or {}
    local ranked = IS.Rank.skinned(facts.skinnedFrom, me)
    local top = topChance(ranked)
    local out = {}
    for i, c in ipairs(ranked) do out[i] = skinRow(c, i, top, me, ctx) end
    return out
end

-- ── every tab's rows ────────────────────────────────────────────────────────────────────────

ISC.BUILDERS = { drops = ISC.Drops, vendors = ISC.Vendors, quests = ISC.Quests, crafting = ISC.Crafting,
    skinned = ISC.Skinned }

--- Every tab's rows for `facts`: `{ drops, vendors, quests, crafting, skinned }`, each best first.
--- @param facts table|nil
--- @param me table|nil
--- @param ctx table|nil
--- @return table
function ISC.Build(facts, me, ctx)
    local out = {}
    for key, build in pairs(ISC.BUILDERS) do out[key] = facts and build(facts, me, ctx) or {} end
    return out
end
