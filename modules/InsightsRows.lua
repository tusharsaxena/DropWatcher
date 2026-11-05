local _, NS = ...
-- modules/InsightsRows.lua — what the Insights tab draws, as plain data (issue #12, Insights design
-- spec §1.3, §3.4, §4.2, §5): the eight cards' figures and hovers, the card grid, the filter bar's
-- wrap, the period caption and the empty lines. modules/WindowInsights.lua puts them on screen.
--
-- THE CARDS (spec §1.3). CARDS lists them in grid order, each { key, caption }; CARD_FILL[key]
-- (totals) answers the figure, its hover lines and a tone (`good` for an ask success of 50% or more,
-- else nil, the heading color). A figure with nothing to show is a dash. A count inferred from a
-- legacy entry (settled before the stamps existed) says so in its hover.
--
-- THE GRID AND THE BAR (spec §4.2). CardGrid packs n cards in rows of `cols` (4 full, 2 compact),
-- a short last row stretched across the width. BarPlan packs the seven dropdowns left to right at
-- a BAR_MIN_W floor each: one row in the full window, two to a row (four rows) at compact's 400.
--
-- THE PERIOD (spec §3.4). PeriodText names what the rows cover: the kept window and its dates for
-- All kept days, `since` its first day under Never delete, a shorter range with its dates and the
-- window it sits in, then the drops and groups shown.
--
-- PURE: plain tables in, strings and numbers out; NS.L, NS.HistoryRetention.Label and the calendar
-- (`date`) are read at call time, so its TOC position is conventional. test_insights_rows drives it.

NS.InsightsRows = NS.InsightsRows or {}
local IR = NS.InsightsRows
local L = NS.L

IR.DASH = "–"
IR.SUCCESS_GOOD = 0.5   -- an ask success at or above it is green
IR.BAR_MIN_W = 130      -- one dropdown's narrowest
IR.BAR_GAP = 6          -- between two dropdowns, across and down
IR.BAR_ROW_H = 24       -- one row of the bar: a control (K.CONTROL_H 20) and its gap
IR.CARD_GAP = 6         -- between two cards, across and down

-- ── the cards ───────────────────────────────────────────────────────────────────────────────

IR.CARDS = {
    { key = "drops",      caption = L["Drops seen"] },
    { key = "upgrades",   caption = L["Upgrades for me"] },
    { key = "asks",       caption = L["Asks sent"] },
    { key = "received",   caption = L["Items received"] },
    { key = "success",    caption = L["Ask success"] },
    { key = "activeDays", caption = L["Active days"] },
    { key = "offers",     caption = L["Offers sent"] },
    { key = "tradedAway", caption = L["Traded away"] },
}

local CAPTION = {}
for _, c in ipairs(IR.CARDS) do CAPTION[c.key] = c.caption end

local function n(v) return type(v) == "number" and v or 0 end

--- A day as the strip and the hovers name it: `Nov 5`.
--- @param t number|nil
--- @return string
function IR.Day(t)
    if type(t) ~= "number" then return IR.DASH end
    return (date("%b %d", t):gsub(" 0(%d)$", " %1"))
end

--- A percentage, rounded: `89%`; a dash for nil.
--- @param frac number|nil
--- @return string
function IR.Percent(frac)
    if type(frac) ~= "number" then return IR.DASH end
    return ("%d%%"):format(math.floor(frac * 100 + 0.5))
end

-- The hover: the caption, then each line given.
local function tip(key, ...)
    local out = { CAPTION[key] }
    for i = 1, select("#", ...) do
        local line = select(i, ...)
        if line then out[#out + 1] = line end
    end
    return out
end

IR.CARD_FILL = {
    drops = function(t)
        return tostring(n(t.drops)), tip("drops", L["%d yours, %d by others"]:format(n(t.mine), n(t.others)))
    end,
    upgrades = function(t)
        local mine = n(t.upgradesMine)
        return tostring(n(t.upgrades)), tip("upgrades", L["%d looted by you, %d by others; %d on another spec"]:format(
            mine, n(t.upgrades) - mine, n(t.upgradesOff)))
    end,
    asks = function(t)
        local k = n(t.asksLegacy)
        return tostring(n(t.asks)), tip("asks", L["Asks you sent for others' drops."],
            k > 0 and L["%d recorded before asks were stamped (counted from items received)"]:format(k) or nil)
    end,
    received = function(t)
        return tostring(n(t.received)), tip("received", L["From %d group members"]:format(n(t.givers)))
    end,
    success = function(t)
        local s = t.success
        if type(s) ~= "number" then return IR.DASH, tip("success", L["No asks in these filters."]) end
        return IR.Percent(s), tip("success", L["%d of %d asks ended in a trade"]:format(n(t.askHits), n(t.asks)),
            n(t.asksLegacy) > 0 and L["Legacy asks are inferred from items received, so the rate reads high."] or nil),
            s >= IR.SUCCESS_GOOD and "good" or nil
    end,
    activeDays = function(t)
        local d = n(t.activeDays)
        if d == 0 then return "0", tip("activeDays") end
        return tostring(d), tip("activeDays", L["%s to %s"]:format(IR.Day(t.first), IR.Day(t.last)))
    end,
    offers = function(t)
        local k = n(t.offersLegacy)
        return tostring(n(t.offers)), tip("offers", L["Offers and announcements you sent for your own drops."],
            k > 0 and L["%d recorded before offers were stamped (counted from items traded away)"]:format(k) or nil)
    end,
    tradedAway = function(t)
        return tostring(n(t.tradedAway)), tip("tradedAway", L["Your own drops you traded to someone."])
    end,
}

--- One card's figure, hover lines and tone (nil: the heading color).
--- @param key string a CARDS key
--- @param totals table|nil InsightsStats' totals
--- @return string value, table tip, string|nil tone
function IR.Card(key, totals)
    return IR.CARD_FILL[key](type(totals) == "table" and totals or {})
end

-- ── the grid and the bar ────────────────────────────────────────────────────────────────────

--- Where n cells go in rows of `cols` across `width`, a short last row stretched: { { x, y, w } },
--- `y` counted down from the top, and the height they take.
--- @param count number
--- @param width number
--- @param cols number
--- @param gap number
--- @param h number one cell's height
--- @return table cells, number height
function IR.CardGrid(count, width, cols, gap, h)
    local cells = {}
    cols = math.max(1, cols)
    local rows = math.ceil(count / cols)
    for r = 1, rows do
        local k = math.min(cols, count - (r - 1) * cols)
        local w = (width - (k - 1) * gap) / k
        for c = 1, k do
            cells[#cells + 1] = { x = (c - 1) * (w + gap), y = (r - 1) * (h + gap), w = w }
        end
    end
    return cells, rows > 0 and (rows * h + (rows - 1) * gap) or 0
end

--- The filter bar's wrap: as many dropdowns to a row as fit at BAR_MIN_W, each row's widths even.
--- @param width number the bar's width
--- @param count number the dropdowns
--- @return table cells { { x, y, w } }, number rows, number perRow
function IR.BarPlan(width, count)
    local per = math.max(1, math.floor((width + IR.BAR_GAP) / (IR.BAR_MIN_W + IR.BAR_GAP)))
    per = math.min(per, math.max(count, 1))
    local w = (width - (per - 1) * IR.BAR_GAP) / per
    local cells = {}
    for i = 1, count do
        local r, c = math.floor((i - 1) / per), (i - 1) % per
        cells[i] = { x = c * (w + IR.BAR_GAP), y = r * IR.BAR_ROW_H, w = w }
    end
    return cells, math.ceil(count / per), per
end

-- ── the period and the empty lines ──────────────────────────────────────────────────────────

-- `Oct 11 – Nov 5`, or one day alone.
local function span(from, to)
    local a, b = IR.Day(from), IR.Day(to)
    if a == b then return a end
    return L["%s – %s"]:format(a, b)
end

local function head(p)
    local days, range = n(p.days), p.range or "all"
    if range == "all" then
        if not p.from then return days > 0 and L["Kept for %s"]:format(NS.HistoryRetention.Label(days)) or L["Every kept day"] end
        if days <= 0 then return L["Every kept day: since %s"]:format(IR.Day(p.from)) end
        return L["Kept for %s: %s"]:format(NS.HistoryRetention.Label(days), span(p.from, p.to))
    end
    local named = range == "today" and L["Today (%s)"]:format(IR.Day(p.to))
        or L["Last %d days (%s)"]:format(tonumber(range) or 0, span(p.from, p.to))
    if days > 0 then return L["%s of %d kept"]:format(named, days) end
    return named
end

--- The strip's caption: the period, then what it holds (`Kept for 30 days: Oct 11 – Nov 5 · 452
--- drops in 160 groups`).
--- @param period table NS.InsightsFilters.Period's
--- @return string
function IR.PeriodText(period)
    local p = type(period) == "table" and period or {}
    return L["%s · %d drops in %d groups"]:format(head(p), n(p.drops), n(p.groups))
end

--- The line a tab with nothing to draw shows: no history at all (saying how long drops are kept), or
--- no drop through these filters.
--- @param logDrops number the drops the log holds
--- @param days number|nil the retention
--- @return string
function IR.EmptyText(logDrops, days)
    if n(logDrops) > 0 then return L["No drops match these filters."] end
    if n(days) > 0 then
        return L["No history yet. Drops your group receives are kept for %s."]:format(NS.HistoryRetention.Label(days))
    end
    return L["No history yet. Drops your group receives are kept until you clear them."]
end
