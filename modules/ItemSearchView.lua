local _, NS = ...
-- modules/ItemSearchView.lua — the Item Search window's pure half (DropWatcher#17, Item Search spec
-- §4.5; Item Search feedback spec §5.2, §5.3): what the search box's text asks for, the matches it
-- lists and their sorts, where a source stands, the item header's line, the footer's line and the
-- ForeverDB notice, each a plain value the frame edge (modules/ItemSearchWindow.lua) draws. The
-- tabs' rows are modules/ItemSearchCells.lua's and their columns modules/ItemSearchTabs.lua's. No
-- client call and no setting read here: every input arrives in `ctx`, so a case drives it with
-- invented values.
--
-- THE SEARCH (spec §4.5). All digits look the id up directly, which works without ForeverDB: the
-- database's row once it is loaded, else the client's cached item, else a bare "Item <id>" row the
-- player can still open (Crafting is the shipped table's and needs no name). Any other text of two
-- characters or more is ForeverDB's SearchItems, read only while it is loaded (a read never loads
-- it, spec §2); before the load the list says "ForeverDB: loading…", without it the spec §1 line.
-- The matches' Sort (feedback spec §5.2): Best match (SearchItems' own order), Name, Item id.
--
-- RECENT SEARCHES ARE GONE (feedback spec §5.2, W4): the list, its store and its setting went in
-- ISF-DW-05 (schema step 17 deletes what was saved).
--
-- THE FIRST MAP (own call): a source's map is the one with the most spots, the lower id on a tie, so
-- the zone and the pin name where it mostly stands; the pin is that map's first spot.

NS.ItemSearchView = NS.ItemSearchView or {}
local ISV = NS.ItemSearchView
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

-- An id search: ForeverDB's row once loaded, else the client's cached item, else a bare row.
local function idMatch(id, ctx, loaded)
    local it = loaded and ctx.db.Item(id) or nil
    if type(it) ~= "table" and type(ctx.clientItem) == "function" then it = ctx.clientItem(id) end
    return { matchRow(id, it) }, nil
end

--- The matches for the box's text. `ctx`: `{ state, db, clientItem, limit }` (state is
--- NS.ItemSearch.State's answer; `db` is read only in "loaded"). Answers the rows
--- `{ { id, name, quality, icon, requiredLevel } }` and a note: nil, "loading", "failed" (installed
--- but did not load), "missing", "short" or "none" (no match).
--- @param text string|nil
--- @param ctx table
--- @return table rows, string|nil note
function ISV.Matches(text, ctx)
    ctx = ctx or {}
    local q = ISV.Classify(text)
    local loaded = ctx.state == "loaded" and type(ctx.db) == "table"
    if q.kind == "id" then return idMatch(q.id, ctx, loaded) end
    if q.kind == "short" then return {}, "short" end
    if q.kind ~= "name" then return {}, nil end
    if not loaded then
        return {}, (ctx.state == "loading" or ctx.state == "failed") and ctx.state or "missing"
    end
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
    if note == "failed" then return L["ForeverDB did not load: drop sources, quests and name search are unavailable"] end
    if note == "missing" then return L["ForeverDB not installed: drop sources, quests and name search are unavailable"] end
    if note == "short" then return L["Type two letters or more, or an item id."] end
    if note == "none" then return L["No item by that name."] end
    return nil
end

-- The matches' sorts (feedback spec §5.2), in the Sort menu's order.
ISV.MATCH_SORTS = { "best", "name", "id" }
ISV.MATCH_SORT_LABEL = { best = L["Best match"], name = L["Name"], id = L["Item id"] }

-- A name for the sort: the row's, lower-cased; nil sorts last.
local function sortName(r)
    return type(r.name) == "string" and r.name:lower() or nil
end

--- The matches in `mode`'s order, a new array: "best" keeps SearchItems' order, "name" sorts by
--- name (an unnamed row last, then by id), "id" by item id. An unknown mode is "best".
--- @param rows table ISV.Matches' rows
--- @param mode string|nil
--- @return table
function ISV.SortMatches(rows, mode)
    local out = {}
    for i, r in ipairs(list(rows)) do out[i] = r end
    if mode == "id" then
        table.sort(out, function(a, b) return a.id < b.id end)
    elseif mode == "name" then
        table.sort(out, function(a, b)
            local na, nb = sortName(a), sortName(b)
            if na ~= nb then
                if na == nil then return false end
                if nb == nil then return true end
                return na < nb
            end
            return a.id < b.id
        end)
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

--- A level range as the window writes it: `10–12` (an en dash, feedback spec §5.4), `10`, or nil.
--- @return string|nil
function ISV.LevelText(minLevel, maxLevel)
    minLevel, maxLevel = num(minLevel), num(maxLevel)
    if not minLevel or minLevel <= 0 then return nil end
    if maxLevel and maxLevel ~= minLevel then return ("%d–%d"):format(minLevel, maxLevel) end
    return tostring(minLevel)
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
--- its TOC) gives one, then " · Full" while ForeverDB_Full is loaded too (round 3 spec §4.6).
--- @param state string NS.ItemSearch.State's answer
--- @param version string|nil
--- @param full boolean|nil ForeverDB_Full is loaded
--- @return string
function ISV.FooterText(state, version, full)
    local words = STATE_WORDS[state] or STATE_WORDS.missing
    local text
    if type(version) == "string" and version ~= "" then
        text = L["ForeverDB %s · %s"]:format(version, words)
    else
        text = L["ForeverDB · %s"]:format(words)
    end
    if full == true then text = L["%s · Full"]:format(text) end
    return text
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
