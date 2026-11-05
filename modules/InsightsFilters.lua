local _, NS = ...
-- modules/InsightsFilters.lua — the Insights tab's rows and its seven filters (issue #12, Insights
-- design spec §1.1, §3): one row per kept drop with its facets read once, the filter, the
-- data-driven dropdown options, the normalize step, the date ranges and the period they cover.
--
-- THE ROWS. Rows(groups) answers one row per History entry ({ e, g, char, charClass, instance,
-- difficulty, situation, quality, category, at, day }), each facet read with its legacy fallback:
-- the recorder is the drop's, else the group's, else `unknown` (Not recorded); the instance the
-- group's, else Open world for an area, else the group's label; no difficulty is `none`; no
-- situation or quality is `unknown`; an entry with no category reads `equipment`, unless its slot is
-- INVTYPE_NON_EQUIP_IGNORE, which only a tier token has (the run plan's #12 Q3). `day` is the local
-- midnight of `at`, from the calendar, so a DST change never moves a day. `at` is the drop's, else
-- the group's; a drop with neither is skipped, so a malformed row never reaches back to the epoch.
--
-- THE OPTIONS (spec §3.2). One pass over the rows: a row that fails no filter counts toward every
-- dropdown, one that fails exactly one counts toward that dropdown alone, one that fails two or more
-- toward none. So each dropdown lists the values present once the other six filters apply, each
-- with its count, the current pick always (at 0 when nothing matches it), under an "all" head that
-- carries the total and `choices`, the number of values. The date ranges nest, so every one is
-- listed. Normalize(rows, f, now, keep) puts any other pick whose count is 0 back to "all", in
-- ORDER, recounting after each; it never writes `f`.
--
-- THE DATES (spec §3.4). The ranges are All kept, Today and the retention row's day counts below
-- the kept window (all of them under Never delete). Since(range, now) is the local midnight the
-- range starts at; Period names what the rows cover.
--
-- PURE: every function takes plain tables and the clock; it reads `date` / `time`, NS.L, the
-- constants' orders (NS.Constants.SITUATIONS, CATEGORIES), NS.HistoryRetention.DAYS and the label
-- readers (NS.WindowFooter.SituationLabel, NS.Item.QualityLabel, NS.CollectCells.KindLabel,
-- NS.CharFilter.IconMarkup) at call time, so its TOC position is conventional. Colors and your
-- recorder key come in through `opts` ({ current, classColor, qualityColor }, each optional; a color
-- reader answers r, g, b or nil). test_insights_filters drives it.

NS.InsightsFilters = NS.InsightsFilters or {}
local IF = NS.InsightsFilters
local L = NS.L

IF.DAY = 86400
IF.TOKEN_SLOT = "INVTYPE_NON_EQUIP_IGNORE"

IF.ORDER = { "char", "instance", "difficulty", "situation", "date", "quality", "category" }
IF.DEFAULTS = { char = "all", instance = "all", difficulty = "all", situation = "all", date = "all",
    quality = "all", category = "all" }

-- Each dropdown's head, before its count.
local HEAD = {
    char = L["All characters"], instance = L["All instances"], difficulty = L["All difficulties"],
    situation = L["All situations"], date = L["All kept days"], quality = L["All qualities"],
    category = L["All categories"],
}

-- ── the rows ────────────────────────────────────────────────────────────────────────────────

local function str(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

--- The local midnight of an epoch time, from the calendar (DST-safe).
--- @param t number
--- @return number
function IF.Midnight(t)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day, hour = 0 })
end

--- The local midnight `n` calendar days after the one `t` falls on (n may be negative).
--- @param t number
--- @param n number
--- @return number
function IF.DayAfter(t, n)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day + n, hour = 0 })
end

local function instanceOf(g)
    if str(g.instance) then return g.instance end
    if g.kind == "area" then return L["Open world"] end
    return str(g.label) or "unknown"
end

--- A drop's category: its own, else `equipment`, or `tierToken` for a slot only a token has.
--- @param e table a History entry
--- @return string
function IF.CategoryOf(e)
    if str(e.category) then return e.category end
    return e.equipLoc == IF.TOKEN_SLOT and "tierToken" or "equipment"
end

-- The drop's time, else its group's; nil when neither is a number (a malformed row, skipped).
local function atOf(e, g)
    if type(e.at) == "number" and e.at == e.at then return e.at end
    if type(g.at) == "number" and g.at == g.at then return g.at end
    return nil
end

-- A pass's midnights by quarter hour (every zone's offset is a multiple of one, so a quarter hour
-- never straddles a local midnight): one calendar read per quarter hour the log touches.
IF.QUARTER = 900

local function midnightIn(memo, at)
    local q = math.floor(at / IF.QUARTER)
    local m = memo[q]
    if not m then m = IF.Midnight(at); memo[q] = m end
    return m
end

local function rowOf(e, g, memo)
    local at = atOf(e, g)
    if not at then return nil end
    return {
        e = e, g = g, char = str(e.seenBy) or str(g.seenBy) or "unknown",
        charClass = str(e.seenByClass) or str(g.seenByClass), instance = instanceOf(g),
        difficulty = str(g.difficulty) or "none", situation = str(g.situation) or "unknown",
        quality = type(e.quality) == "number" and e.quality or "unknown", category = IF.CategoryOf(e),
        at = at, day = midnightIn(memo, at),
    }
end

--- One row per kept drop, its facets read once; anything that is not a table, or that has no time
--- (no numeric `at` on the drop or its group), is skipped.
--- @param groups table|nil History groups
--- @return table rows
function IF.Rows(groups)
    local out, memo = {}, {}
    for _, g in ipairs(type(groups) == "table" and groups or {}) do
        for _, e in ipairs(type(g) == "table" and type(g.drops) == "table" and g.drops or {}) do
            if type(e) == "table" then out[#out + 1] = rowOf(e, g, memo) end -- nil appends nothing
        end
    end
    return out
end

-- ── the dates ───────────────────────────────────────────────────────────────────────────────

--- The date values offered, in order: `all`, `today`, then each retention day count (as a string)
--- shorter than the kept window; every one under Never delete (0).
--- @param retentionDays number|nil
--- @return table
function IF.Ranges(retentionDays)
    local days = tonumber(retentionDays) or 0
    local out = { "all", "today" }
    for _, n in ipairs(NS.HistoryRetention.DAYS) do
        if n > 0 and (days <= 0 or n < days) then out[#out + 1] = tostring(n) end
    end
    return out
end

--- When a range starts: today's local midnight, or the one N-1 days before it; nil for `all`.
--- @param range string|nil
--- @param now number
--- @return number|nil
function IF.Since(range, now)
    if range == "today" then return IF.Midnight(now) end
    local n = tonumber(range)
    if not n or n < 1 then return nil end
    return IF.DayAfter(now, -(n - 1))
end

local function dateLabel(range)
    if range == "all" then return HEAD.date end
    if range == "today" then return L["Today"] end
    return L["Last %d days"]:format(tonumber(range) or 0)
end

--- What the rows cover: { from, to, first, last, days, range, groups, drops }. `from` is the range's
--- start; for `all` the kept window's start, or the first drop when that is later (or the window is
--- Never delete).
--- @param rows table
--- @param days number|nil the retention
--- @param range string|nil
--- @param now number
--- @return table
function IF.Period(rows, days, range, now)
    days = tonumber(days) or 0
    local first, last, seen, groups = nil, nil, {}, 0
    for _, r in ipairs(rows) do
        if not first or r.at < first then first = r.at end
        if not last or r.at > last then last = r.at end
        if not seen[r.g] then seen[r.g], groups = true, groups + 1 end
    end
    local from = IF.Since(range, now)
    if not from then
        local window = days > 0 and (now - days * IF.DAY) or nil
        from = (window and first and math.max(window, first)) or window or first
    end
    return { from = from, to = now, first = first, last = last, days = days, range = range or "all",
        groups = groups, drops = #rows }
end

-- ── the filter ──────────────────────────────────────────────────────────────────────────────

local function passes(row, key, f, since)
    local want = f[key]
    if want == nil or want == "all" then return true end
    if key == "date" then return since == nil or row.at >= since end
    return row[key] == want
end

--- The rows that pass every filter, in order.
--- @param rows table
--- @param f table|nil the picks (DEFAULTS when nil)
--- @param now number
--- @return table
function IF.Filter(rows, f, now)
    f = f or IF.DEFAULTS
    local since, out = IF.Since(f.date, now), {}
    for _, r in ipairs(rows) do
        local ok = true
        for _, key in ipairs(IF.ORDER) do
            if not passes(r, key, f, since) then ok = false; break end
        end
        if ok then out[#out + 1] = r end
    end
    return out
end

-- ── the options ─────────────────────────────────────────────────────────────────────────────

-- The one filter a row fails, `true` when it fails none, false when it fails two or more.
local function missedSlot(row, f, since)
    local missed
    for _, key in ipairs(IF.ORDER) do
        if not passes(row, key, f, since) then
            if missed then return false end
            missed = key
        end
    end
    return missed or true
end

-- The difficulty names in their natural order: Mythic+ (highest key first), Mythic, Heroic, Normal,
-- the raid finder, Timewalking, Delves, any other, No difficulty last.
local DIFFICULTY_RANK = {
    { "^Mythic%+", 1 }, { "^Mythic", 2 }, { "^Heroic", 3 }, { "^Normal", 4 }, { "Looking For Raid", 5 },
    { "Raid Finder", 5 }, { "^Timewalking", 6 }, { "^Delve", 7 },
}

local function difficultyRank(v)
    if v == "none" then return 9, 0 end
    for _, p in ipairs(DIFFICULTY_RANK) do
        if v:find(p[1]) then return p[2], -(tonumber(v:match("(%d+)")) or 0) end
    end
    return 8, 0
end

local function byDifficulty(a, b)
    local ra, sa = difficultyRank(a.value)
    local rb, sb = difficultyRank(b.value)
    if ra ~= rb then return ra < rb end
    if sa ~= sb then return sa < sb end
    return a.value < b.value
end

local function positionsOf(list, field)
    local out = {}
    for i, v in ipairs(list) do out[v[field] or v] = i end
    return out
end

-- A comparator by a fixed position table; anything unlisted after, by name; `unknown` last.
local function byPosition(pos)
    return function(a, b)
        local pa = a.value == "unknown" and 1e9 or pos[a.value] or 1e6
        local pb = b.value == "unknown" and 1e9 or pos[b.value] or 1e6
        if pa ~= pb then return pa < pb end
        return tostring(a.value) < tostring(b.value)
    end
end

local function byName(a, b) return tostring(a.value):lower() < tostring(b.value):lower() end

local function byQuality(a, b)
    local qa = type(a.value) == "number" and a.value or -1
    local qb = type(b.value) == "number" and b.value or -1
    return qa > qb
end

local function byChar(current)
    return function(a, b)
        if (a.value == current) ~= (b.value == current) then return a.value == current end
        if (a.value == "unknown") ~= (b.value == "unknown") then return b.value == "unknown" end
        if a.count ~= b.count then return a.count > b.count end
        return a.value:lower() < b.value:lower()
    end
end

local SORT = {
    instance = function() return byName end,
    difficulty = function() return byDifficulty end,
    situation = function() return byPosition(positionsOf(NS.Constants.SITUATIONS, "key")) end,
    quality = function() return byQuality end,
    category = function() return byPosition(positionsOf(NS.Constants.CATEGORIES, "key")) end,
    char = function(opts) return byChar(opts.current) end,
}

local function wrap(r, g, b)
    if r == nil then return nil end
    return { r, g, b }
end

-- A value's name and color, by its dropdown.
local NAME = {
    char = function(v, opts, class)
        if v == "unknown" then return L["Not recorded"] end
        local icon = NS.CharFilter.IconMarkup(class)
        return icon ~= "" and (icon .. " " .. v) or v,
            class and opts.classColor and wrap(opts.classColor(class)) or nil
    end,
    instance = function(v) return v == "unknown" and L["Unknown"] or v end,
    difficulty = function(v) return v == "none" and L["No difficulty"] or v end,
    situation = function(v) return v == "unknown" and L["Unknown"] or NS.WindowFooter.SituationLabel(v) end,
    quality = function(v, opts)
        if v == "unknown" then return L["Unknown"] end
        return NS.Item.QualityLabel(v), opts.qualityColor and wrap(opts.qualityColor(v)) or nil
    end,
    category = function(v) return NS.CollectCells.KindLabel(v) or v end,
    date = function(v) return dateLabel(v) end,
}

local function countLabel(name, n) return L["%s (%d)"]:format(name, n) end

local function optionRow(key, value, count, opts, class)
    local name, color = NAME[key](value, opts, class)
    return { value = value, name = name, count = count, label = countLabel(name, count), color = color }
end

-- The counts each dropdown sees: { [key] = { total, values = { [v] = n }, class = { [v] = class } } }.
local function tally(rows, f, now)
    local since, t, ats = IF.Since(f.date, now), {}, {}
    for _, key in ipairs(IF.ORDER) do t[key] = { total = 0, values = {}, class = {} } end
    for _, r in ipairs(rows) do
        local slot = missedSlot(r, f, since)
        for _, key in ipairs(IF.ORDER) do
            if slot == true or slot == key then
                local c = t[key]
                c.total = c.total + 1
                if key ~= "date" then c.values[r[key]] = (c.values[r[key]] or 0) + 1 end
                if key == "char" and r.charClass then c.class[r.char] = r.charClass end
                if key == "date" then ats[#ats + 1] = r.at end
            end
        end
    end
    return t, ats
end

-- The date rows: every offered range (they nest, so each is listed), and a pick no longer offered
-- (the retention moved), each counting the rows at or after its start.
local function dateOptions(ats, f, now, days)
    local ranges, listed, out = IF.Ranges(days), {}, {}
    for _, r in ipairs(ranges) do listed[r] = true end
    if f.date ~= nil and not listed[f.date] then ranges[#ranges + 1] = f.date end
    for _, range in ipairs(ranges) do
        if range ~= "all" then
            local since, n = IF.Since(range, now), 0
            for _, at in ipairs(ats) do
                if not since or at >= since then n = n + 1 end
            end
            out[#out + 1] = optionRow("date", range, n, {})
        end
    end
    return out
end

local function valueOptions(key, c, f, opts)
    local list = {}
    for v, n in pairs(c.values) do list[#list + 1] = optionRow(key, v, n, opts, c.class[v]) end
    local pick = f[key]
    if pick ~= nil and pick ~= "all" and not c.values[pick] then
        list[#list + 1] = optionRow(key, pick, 0, opts, c.class[pick])
    end
    table.sort(list, SORT[key](opts))
    return list
end

--- Each dropdown's rows, the "all" head first: { [key] = { { value, label, name, count, color?,
--- choices? (the head) }, ... } }. `opts.days` is the retention the date ranges follow.
--- @param rows table
--- @param f table|nil
--- @param now number
--- @param opts table|nil { current, classColor, qualityColor, days }
--- @return table
function IF.Options(rows, f, now, opts)
    f, opts = f or IF.DEFAULTS, opts or {}
    local t, ats = tally(rows, f, now)
    local out = {}
    for _, key in ipairs(IF.ORDER) do
        local c = t[key]
        local list = key == "date" and dateOptions(ats, f, now, opts.days) or valueOptions(key, c, f, opts)
        local head = { value = "all", name = HEAD[key], count = c.total, choices = #list,
            label = countLabel(HEAD[key], c.total) }
        table.insert(list, 1, head)
        out[key] = list
    end
    return out
end

local function countOf(list, value)
    for _, o in ipairs(list) do
        if o.value == value then return o.count end
    end
    return 0
end

--- The picks with every other zero-count pick put back to "all" (in ORDER, recounting after each),
--- and the options they give; `keep` (the dropdown just changed) is never put back. `f` is not
--- written; a missing key reads "all".
--- @param rows table
--- @param f table|nil
--- @param now number
--- @param keep string|nil
--- @param opts table|nil IF.Options'
--- @return table f, table options
function IF.Normalize(rows, f, now, keep, opts)
    local out = {}
    for _, key in ipairs(IF.ORDER) do out[key] = (f and f[key] ~= nil) and f[key] or "all" end
    local options = IF.Options(rows, out, now, opts)
    for _, key in ipairs(IF.ORDER) do
        if key ~= keep and out[key] ~= "all" and countOf(options[key], out[key]) == 0 then
            out[key] = "all"
            options = IF.Options(rows, out, now, opts)
        end
    end
    return out, options
end

--- A closed dropdown's text: the head with its number of values (`All instances (12)`), or the
--- picked value's name.
--- @param list table one dropdown's options
--- @param value any
--- @return string
function IF.ClosedLabel(list, value)
    for _, o in ipairs(list or {}) do
        if o.value == value then
            if value == "all" then return countLabel(o.name, o.choices or 0) end
            return o.name
        end
    end
    return tostring(value)
end
