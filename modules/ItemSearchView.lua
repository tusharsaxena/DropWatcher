local _, NS = ...
-- modules/ItemSearchView.lua — the Item Search window's pure half (DropWatcher#17, Item Search spec
-- §4.5, mockup board 2): what the search box's text asks for, the matches it lists, the recent
-- searches, and every row of the detail pane, each a plain table the frame edge
-- (modules/ItemSearchWindow.lua) draws. No client call and no setting read here: every input
-- arrives in `ctx`, so a case drives it with invented values.
--
-- THE SEARCH (spec §4.5). All digits look the id up directly, which works without ForeverDB: the
-- database's row once it is loaded, else the client's cached item, else a bare "Item <id>" row the
-- player can still open (Crafting is the shipped table's and needs no name). Any other text of two
-- characters or more is ForeverDB's SearchItems, read only while it is loaded (a read never loads
-- it, spec §2); before the load the list says "ForeverDB: loading…", without it the spec §1 line.
--
-- THE DETAIL PANE. DROPS FROM lists every source (not the tooltip's top 3): its name, the creature's
-- level range, the zone (the source's first map, named through the client), a bar scaled to the
-- highest chance, the percent and a pin target, plus the World drop row with its minimum level.
-- SOLD BY lists the vendors, the cheapest one with its price. QUESTS carries each quest's mark,
-- title, zone (its first giver's) and state. CRAFTING carries the breakpoints against your rank,
-- or "learnable at N" for a recipe you do not know. ALSO is Reward from, Starts quest and Skinned
-- from.
--
-- THE FIRST MAP (own call): a source's map is the one with the most spots, the lower id on a tie, so
-- the zone and the pin name where it mostly stands; the pin is that map's first spot.

NS.ItemSearchView = NS.ItemSearchView or {}
local ISV = NS.ItemSearchView
local IS  = NS.ItemSearch
local L   = NS.L

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function list(v)
    if type(v) == "table" then return v end
    return {}
end

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- ── the search box ──────────────────────────────────────────────────────────────────────────

--- What the box's text asks for: `{ kind = "none" }` (empty), `{ kind = "id", id }` (all digits),
--- `{ kind = "short" }` (one character) or `{ kind = "name", query }`.
--- @param text string|nil
--- @return table
function ISV.Classify(text)
    local t = trim(text)
    if t == "" then return { kind = "none" } end
    if t:match("^%d+$") then
        local id = tonumber(t)
        if id and id > 0 then return { kind = "id", id = id } end
        return { kind = "none" }
    end
    if #t < 2 then return { kind = "short" } end
    return { kind = "name", query = t }
end

-- One match row from a database or client item.
local function matchRow(id, it)
    it = type(it) == "table" and it or {}
    return { id = id, name = it.name, quality = num(it.quality), icon = it.icon,
        requiredLevel = num(it.requiredLevel) }
end

--- The matches for the box's text. `ctx`: `{ state, db, clientItem, limit }` (state is
--- NS.ItemSearch.State's answer; `db` is read only in "loaded"). Answers the rows
--- `{ { id, name, quality, icon, requiredLevel } }` and a note: nil, "loading", "missing",
--- "short" or "none" (no match).
--- @param text string|nil
--- @param ctx table
--- @return table rows, string|nil note
function ISV.Matches(text, ctx)
    ctx = ctx or {}
    local q = ISV.Classify(text)
    local loaded = ctx.state == "loaded" and type(ctx.db) == "table"
    if q.kind == "id" then
        local it = loaded and ctx.db.Item(q.id) or nil
        if type(it) ~= "table" and type(ctx.clientItem) == "function" then it = ctx.clientItem(q.id) end
        return { matchRow(q.id, it) }, nil
    end
    if q.kind == "short" then return {}, "short" end
    if q.kind ~= "name" then return {}, nil end
    if not loaded then return {}, ctx.state == "loading" and "loading" or "missing" end
    local out = {}
    for _, r in ipairs(list(ctx.db.SearchItems(q.query, ctx.limit))) do
        if type(r) == "table" and num(r.id) then out[#out + 1] = matchRow(r.id, r) end
    end
    if #out == 0 then return out, "none" end
    return out, nil
end

--- The line the matches list shows for a note (ISV.Matches' second answer), or nil.
--- @param note string|nil
--- @return string|nil
function ISV.NoteText(note)
    if note == "loading" then return L["ForeverDB: loading…"] end
    if note == "missing" then return L["ForeverDB not installed: drop sources, quests and name search are unavailable"] end
    if note == "short" then return L["Type two letters or more, or an item id."] end
    if note == "none" then return L["No item by that name."] end
    return nil
end

--- `ids` with `id` moved to the front, each id once, at most `max` (a new list).
--- @param ids table|nil
--- @param id number
--- @param max number
--- @return table
function ISV.PushRecent(ids, id, max)
    local out = {}
    if num(id) then out[1] = id end
    for _, v in ipairs(list(ids)) do
        if #out >= max then break end
        if num(v) and v ~= id then out[#out + 1] = v end
    end
    return out
end

-- ── where a source stands ───────────────────────────────────────────────────────────────────

--- A source's map and spot from a ForeverDB Spots answer: the map with the most spots (the lower id
--- on a tie) and its first spot, as `{ map, x, y }`; nil for none.
--- @param spots table|nil `{ [uiMapID] = { { x, y }, ... } }`
--- @return table|nil
function ISV.SpotOf(spots)
    local best, bestN
    for map, points in pairs(list(spots)) do
        local n = #list(points)
        if num(map) and n > 0 and (not best or n > bestN or (n == bestN and map < best)) then
            best, bestN = map, n
        end
    end
    if not best then return nil end
    local p = spots[best][1]
    if type(p) ~= "table" or not (num(p.x) and num(p.y)) then return nil end
    return { map = best, x = p.x, y = p.y }
end

-- `{ spot, zone }` for a creature or object id, through ctx.spots and ctx.mapName.
local function whereOf(kind, id, ctx)
    if kind ~= "npc" and kind ~= "object" then return nil, nil end
    local spot = type(ctx.spots) == "function" and ISV.SpotOf(ctx.spots(kind, id)) or nil
    local zone = spot and type(ctx.mapName) == "function" and ctx.mapName(spot.map) or nil
    return spot, zone
end

--- A level range as the window writes it: `10-12`, `10`, or nil.
--- @return string|nil
function ISV.LevelText(minLevel, maxLevel)
    minLevel, maxLevel = num(minLevel), num(maxLevel)
    if not minLevel or minLevel <= 0 then return nil end
    if maxLevel and maxLevel ~= minLevel then return ("%d-%d"):format(minLevel, maxLevel) end
    return tostring(minLevel)
end

-- ── the detail pane's rows ──────────────────────────────────────────────────────────────────

--- DROPS FROM: every source, most likely first, `{ name, named, level, zone, pct, fraction, spot }`
--- (fraction = chance / the top chance, 0 for an unknown rate), then the World drop row
--- `{ world = true, name, level }`. `ctx`: `{ spots(kind, id), mapName(map) }`.
--- @param facts table NS.ItemSearch.Get's answer
--- @param ctx table|nil
--- @return table
function ISV.DropRows(facts, ctx)
    ctx = ctx or {}
    local top = 0
    for _, s in ipairs(list(facts.drops)) do
        if num(s.chance) and s.chance > top then top = s.chance end
    end
    local out = {}
    for _, s in ipairs(list(facts.drops)) do
        local spot, zone = whereOf(s.kind, s.id, ctx)
        local chance = num(s.chance)
        out[#out + 1] = {
            name = s.name, named = s.named == true, level = ISV.LevelText(s.minLevel, s.maxLevel), zone = zone,
            pct = IS.Percent(chance) or L["rate unknown"], fraction = (chance and top > 0) and chance / top or 0,
            spot = spot, known = chance ~= nil,
        }
    end
    if num(facts.worldMinLevel) then
        out[#out + 1] = { world = true, name = L["World drop"], level = L["level %d+"]:format(facts.worldMinLevel) }
    end
    return out
end

--- SOLD BY: `{ name, level, zone, price, spot }` per vendor; `price` (copper) on the cheapest one.
--- `ctx`: `{ npc(id), spots(kind, id), mapName(map) }`.
--- @return table
function ISV.VendorRows(facts, ctx)
    ctx = ctx or {}
    local cheapest = type(facts.vendorPrice) == "table" and facts.vendorPrice or nil
    local out = {}
    for _, v in ipairs(list(facts.vendors)) do
        local n = type(ctx.npc) == "function" and ctx.npc(v.id) or nil
        local spot, zone = whereOf("npc", v.id, ctx)
        out[#out + 1] = {
            name = v.name, level = type(n) == "table" and ISV.LevelText(n.minLevel, n.maxLevel) or nil,
            zone = zone, spot = spot, price = cheapest and cheapest.npc == v.id and num(cheapest.price) or nil,
        }
    end
    return out
end

local QUEST_STATE = { log = L["In your log"], done = L["Completed"], todo = L["Not picked up"] }

--- A quest state's words: "In your log", "Completed" or "Not picked up".
--- @param state string
--- @return string
function ISV.QuestStateText(state)
    return QUEST_STATE[state] or QUEST_STATE.todo
end

--- QUESTS: `{ id, state, title, level, zone, spot, stateText }` per quest, completed ones left out
--- while `hideCompleted`. The zone is the quest's first giver's. `ctx`: `{ quest(id), spots,
--- mapName, hideCompleted }`.
--- @return table
function ISV.QuestRows(facts, ctx)
    ctx = ctx or {}
    local out = {}
    for _, q in ipairs(list(facts.quests)) do
        if not (ctx.hideCompleted and q.state == "done") then
            local info = type(ctx.quest) == "function" and ctx.quest(q.id) or nil
            local giver = type(info) == "table" and list(info.givers)[1] or nil
            local spot, zone
            if type(giver) == "table" then spot, zone = whereOf(giver.kind, giver.id, ctx) end
            out[#out + 1] = {
                id = q.id, state = q.state, title = q.title or L["Quest %d"]:format(q.id), level = num(q.level),
                zone = zone, spot = spot, stateText = ISV.QuestStateText(q.state),
            }
        end
    end
    return out
end

--- A crafting row's breakpoints: `{ { tone, text } ... }`, the four skill-up colors and your rank
--- for a recipe you know, "learnable at N" for one you don't (N its minimum rank), `{}` without
--- breakpoints.
--- @param row table a crafting row (IS.Live's)
--- @return table
function ISV.Breakpoints(row)
    if not row.known then
        local at = num(row.min)
        if at and at > 0 then return { { tone = "muted", text = L["learnable at %d"]:format(at) } } end
        return {}
    end
    local out = {}
    local function add(tone, v) if num(v) then out[#out + 1] = { tone = tone, text = tostring(v) } end end
    if num(row.yellow) and num(row.gray) and (row.yellow > 0 or row.gray > 0) then
        add("skillOrange", num(row.min) or 1)
        add("skillYellow", row.yellow)
        add("skillGreen", row.green)
        add("skillGray", row.gray)
    end
    if num(row.rank) then out[#out + 1] = { tone = "plain", text = L["you %d"]:format(row.rank) } end
    return out
end

--- CRAFTING: `{ spell, known, color, name, profession, breakpoints, stateText }` per recipe.
--- `ctx.profession(skillLine)` names the profession.
--- @return table
function ISV.CraftRows(facts, ctx)
    ctx = ctx or {}
    local out = {}
    for _, r in ipairs(list(facts.crafting)) do
        out[#out + 1] = {
            spell = r.spell, known = r.known == true, color = r.color,
            name = r.name or L["Recipe %d"]:format(r.spell),
            profession = type(ctx.profession) == "function" and ctx.profession(r.skillLine) or nil,
            breakpoints = ISV.Breakpoints(r), stateText = r.known and L["Known"] or L["Not known"],
        }
    end
    return out
end

--- ALSO: `{ label, text, right }` rows: each quest that rewards the item, the quest it starts and
--- each creature it is skinned from (with its chance).
--- @return table
function ISV.AlsoRows(facts)
    local out = {}
    for _, q in ipairs(list(facts.rewardFrom)) do
        out[#out + 1] = { label = L["Reward from"], text = q.title or L["Quest %d"]:format(q.id),
            right = num(q.level) and L["level %d"]:format(q.level) or nil }
    end
    local s = facts.startsQuest
    if type(s) == "table" then
        out[#out + 1] = { label = L["Starts quest"], text = s.title or L["Quest %d"]:format(s.id),
            right = num(s.level) and L["level %d"]:format(s.level) or nil }
    end
    for _, c in ipairs(list(facts.skinnedFrom)) do
        out[#out + 1] = { label = L["Skinned from"], text = c.name, right = IS.Percent(c.chance) or L["rate unknown"] }
    end
    return out
end

-- ── the item header and the footer ──────────────────────────────────────────────────────────

--- The header's second line: quality · class · subclass · required level · id, each part only
--- where known. `ctx`: `{ qualityName(q), classNames(classID, subclassID) }`.
--- @param item table the facts' item
--- @param ctx table|nil
--- @return string
function ISV.ItemLine(item, ctx)
    ctx = ctx or {}
    local parts = {}
    local q = type(ctx.qualityName) == "function" and ctx.qualityName(item.quality) or nil
    if q then parts[#parts + 1] = q end
    if type(ctx.classNames) == "function" then
        local class, sub = ctx.classNames(item.classID, item.subclassID)
        if class then parts[#parts + 1] = class end
        if sub and sub ~= class then parts[#parts + 1] = sub end
    end
    local req = num(item.requiredLevel)
    if req and req > 0 then parts[#parts + 1] = L["Requires level %d"]:format(req) end
    parts[#parts + 1] = L["id %d"]:format(item.id)
    return table.concat(parts, " · ")
end

local STATE_WORDS = {
    loaded = L["loaded"], loading = L["loading…"], missing = L["not installed"], failed = L["did not load"],
    off = L["off"],
}

--- The footer's left line: "ForeverDB <version> · <state>", the version where the database (or
--- its TOC) gives one.
--- @param state string NS.ItemSearch.State's answer
--- @param version string|nil
--- @return string
function ISV.FooterText(state, version)
    local words = STATE_WORDS[state] or STATE_WORDS.missing
    if type(version) == "string" and version ~= "" then
        return L["ForeverDB %s · %s"]:format(version, words)
    end
    return L["ForeverDB · %s"]:format(words)
end

--- The detail pane's notice about ForeverDB, or nil while it is loaded: the spec §1 line without
--- it, "ForeverDB: loading…" before its load.
--- @param state string
--- @return string|nil
function ISV.Notice(state)
    if state == "loaded" then return nil end
    if state == "loading" then return L["ForeverDB: loading…"] end
    if state == "failed" then return L["ForeverDB did not load: drop sources, quests and name search are unavailable"] end
    return L["ForeverDB not installed: drop sources, quests and name search are unavailable"]
end
