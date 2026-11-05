local _, NS = ...
-- modules/InsightsRows.lua — what the Insights tab draws, as plain data (issue #12, Insights design
-- spec §1.3, §1.4, §3.4, §4.2, §5): the eight cards' figures and hovers, the card grid, the filter
-- bar's wrap, the period caption, the empty lines and every chart section's rows.
-- modules/InsightsSections.lua and modules/WindowInsights.lua put them on screen.
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
-- THE SECTIONS (spec §1.4). One builder a section (OutcomeRows, InstanceRows, BossRows, RateRows,
-- GenerousRows, GainRows, DayBuckets, MixRows) answers the rows its Charts renderer takes, colors as
-- `{ r, g, b }` tables, and `{}` when there is nothing to draw.
--
-- PURE: plain tables in, strings and numbers out; NS.L, NS.HistoryRetention.Label, the calendar
-- (`date`), the color readers (NS.Compat.ClassColor, NS.QualityColor, NS.Constants.TONE,
-- NS.SkinColor) and the label readers (NS.WindowCells, NS.CollectCells, NS.Item,
-- NS.InsightsStats.SEGMENTS) are read at call time, so its TOC position is conventional. test_insights_rows drives it.

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

-- ── the sections' rows (spec §1.4) ──────────────────────────────────────────────────────────
--
-- Each builder turns one part of InsightsStats' answer into the rows a LibKa0s-Charts-1.0 renderer
-- takes. Colors come as `{ r, g, b }` tables: a class's and a quality's from the client's triples,
-- a tone's from NS.Constants.TONE (refilled on a skin switch), nil for the library's own bar color;
-- a stacked segment is never nil (the renderer has no default for one): see segColor.
-- No builder draws, and an empty answer is `{}`, the section's cue to show its muted line instead.

IR.TOP = 10           -- a ranked section's rows (Charts' K.LIST_MAX for the list panels)
IR.TIP_ITEMS = 8      -- the items a generous member's hover names

local function rgb(r, g, b)
    if r == nil then return nil end
    return { r, g, b }
end

--- A tone's color (`good`, `red`, ...), or nil for one the palette does not fill.
--- @param tone string|nil
--- @return table|nil
function IR.ToneColor(tone)
    local t = tone and NS.Constants.TONE[tone]
    if type(t) ~= "table" or t.r == nil then return nil end
    return { t.r, t.g, t.b }
end

--- A class's color, or nil.
function IR.ClassColor(class) return rgb(NS.Compat.ClassColor(class)) end

--- A quality's color, or nil (an unknown quality).
function IR.QualityColor(q)
    if type(q) ~= "number" then return nil end
    return rgb(NS.QualityColor(q))
end

-- The library's `chart.other` (kept drops), else IR.OTHER_FALLBACK: a stacked segment needs a color,
-- and the degraded arm (no Skin library) has no `chart.other`.
IR.OTHER_FALLBACK = { 0.55, 0.62, 0.72 }   -- LibKa0s' own `chart.other` under its default skin
local function otherColor()
    local c = rgb(NS.SkinColor("chart.other")) or IR.OTHER_FALLBACK
    return { c[1], c[2], c[3] }
end

--- A signed whole number (`+7`, `-3`, `0`): the range section's values and its scale.
--- @param v number
--- @return string
function IR.Signed(v)
    local r = math.floor(v + 0.5)
    if r == 0 then return "0" end
    return ("%+d"):format(r)
end

-- `n` of `total` as a hover line's share: `8 (3%)`.
local function share(count, total)
    return L["%d (%s)"]:format(count, IR.Percent(total > 0 and count / total or nil))
end

local function plural(count, one, many)
    if count == 1 then return one end
    return many:format(count)
end

local function firstOf(list, max)
    local out = {}
    for i = 1, math.min(#list, max) do out[i] = list[i] end
    return out
end

-- ── A: drops by outcome ─────────────────────────────────────────────────────────────────────

-- Each segment's words and tone; the same meaning is the same color in every row.
IR.OUTCOME = {
    received = { label = L["Traded to me"], tone = "good" },
    tradedAway = { label = L["Traded away"], tone = "cyan" },
    asked = { label = L["Asked, no trade"], tone = "yellow" },
    offered = { label = L["Offered, no trade"], tone = "cyan" },
    declined = { label = L["Declined"], tone = "redMuted" },
    expired = { label = L["Expired"], tone = "warn" },
    kept = { label = L["Kept by the looter"] },
}
local OUTCOME_ROWS = {
    { key = "others", segs = "others", label = L["Others' drops"] },
    { key = "upgrades", segs = "others", label = L["Upgrades for me"], sublabel = L["looted by others"] },
    { key = "mine", segs = "mine", label = L["Your drops"] },
}
-- The legend: one chip a color; Offered shares Traded away's `dw.offer` (spec §4.4).
local OUTCOME_LEGEND = {
    { key = "received", label = L["Traded to me"] },
    { key = "tradedAway", label = L["Traded/offered"], tip = L["Traded away, or offered and no trade followed"] },
    { key = "asked", label = L["Asked"], tip = L["Asked, and no trade followed"] },
    { key = "declined", label = L["Declined"] }, { key = "expired", label = L["Expired"] },
    { key = "kept", label = L["Kept"], tip = L["Kept by the looter"] },
}

-- Never nil: a tone the palette has not filled falls to the kept color.
local function segColor(key)
    local o = IR.OUTCOME[key]
    return o.tone and IR.ToneColor(o.tone) or otherColor()
end

local function outcomeTotal(counts, keys)
    local sum = 0
    for _, k in ipairs(keys) do sum = sum + n(counts[k]) end
    return sum
end

local function outcomeRow(spec, counts, keys, total, top)
    local row = { label = spec.label, sublabel = spec.sublabel, value = tostring(total), segments = {},
        tip = { spec.sublabel and (spec.label .. " " .. spec.sublabel) or spec.label } }
    for _, k in ipairs(keys) do
        local c = n(counts[k])
        if c > 0 then
            local line = L["%s: %s"]:format(IR.OUTCOME[k].label, share(c, total))
            row.segments[#row.segments + 1] = { frac = c / top, color = segColor(k), tip = line }
            row.tip[#row.tip + 1] = line
        end
    end
    return row
end

--- Section A: others' drops, the upgrades among them and your own, each split by what became of
--- it; a row with no drop is left out, and the fracs are over the largest row's total.
--- @param stats table InsightsStats.Compute's
--- @return table rows, table legend
function IR.OutcomeRows(stats)
    local outcomes, segs = stats.outcomes or {}, NS.InsightsStats.SEGMENTS
    local top, totals = 0, {}
    for i, spec in ipairs(OUTCOME_ROWS) do
        totals[i] = outcomeTotal(outcomes[spec.key] or {}, segs[spec.segs])
        top = math.max(top, totals[i])
    end
    local rows = {}
    for i, spec in ipairs(OUTCOME_ROWS) do
        if totals[i] > 0 then
            rows[#rows + 1] = outcomeRow(spec, outcomes[spec.key], segs[spec.segs], totals[i], top)
        end
    end
    local legend = {}
    if #rows > 0 then
        for i, c in ipairs(OUTCOME_LEGEND) do
            legend[i] = { label = c.label, color = segColor(c.key), tip = c.tip or c.label }
        end
    end
    return rows, legend
end

-- ── B, C, D: where the upgrades come from ───────────────────────────────────────────────────

--- Section B: the instances with the most upgrades for you, each split into yours and others'
--- (`colors.mine`, `colors.others`, the chart palette's first two), top IR.TOP.
--- @param stats table
--- @param colors table { mine, others }
--- @return table rows, table legend, number more (the instances left out)
function IR.InstanceRows(stats, colors)
    local list = stats.byInstance or {}
    local shown = firstOf(list, IR.TOP)
    local top = shown[1] and shown[1].upgrades or 0
    local rows = {}
    for i, b in ipairs(shown) do
        local mine, others = L["%d by you"]:format(b.mine), L["%d by others"]:format(b.others)
        rows[i] = { label = b.key, value = tostring(b.upgrades),
            tip = { b.key, plural(b.upgrades, L["1 upgrade for you"], L["%d upgrades for you"]), mine, others },
            segments = { { frac = b.mine / top, color = colors.mine, tip = mine },
                { frac = b.others / top, color = colors.others, tip = others } } }
    end
    local legend = {}
    if #rows > 0 then
        legend = { { label = L["By you"], color = colors.mine, tip = L["Looted by you"] },
            { label = L["By others"], color = colors.others, tip = L["Looted by others"] } }
    end
    return rows, legend, #list - #shown
end

--- Section C: the boss kills with the most upgrades for you, each under its instance and
--- difficulty, top IR.TOP. Only encounter groups count: a Mythic+ key is kept as one run.
--- @param stats table
--- @return table rows, number more
function IR.BossRows(stats)
    local list = stats.byBoss or {}
    local rows = {}
    for i, b in ipairs(firstOf(list, IR.TOP)) do
        local sub = b.instance
        if b.difficulty and b.difficulty ~= "none" then sub = L["%s · %s"]:format(sub, b.difficulty) end
        rows[i] = { label = b.label, sublabel = sub, frac = b.upgrades, value = tostring(b.upgrades),
            tip = { b.label, sub, plural(b.upgrades, L["1 upgrade for you"], L["%d upgrades for you"]) } }
    end
    return rows, #list - #rows
end

--- Section D: the instances that give the most upgrades a visit (two visits or more).
--- @param stats table
--- @return table rows (a list panel's)
function IR.RateRows(stats)
    local rows = {}
    for i, r in ipairs(firstOf(stats.topRate or {}, IR.TOP)) do
        rows[i] = { name = r.key, right = L["%.2f / visit"]:format(r.rate),
            tip = { r.key, L["%d upgrades in %d visits"]:format(r.upgrades, r.visits) } }
    end
    return rows
end

-- ── E, F: what was traded to you ────────────────────────────────────────────────────────────

local function itemName(e)
    return NS.WindowCells.ItemName(e.itemLink) or L["Unknown"]
end

--- Section E: the group members who traded you the most, then the most recent, in their class
--- color; the hover names the items.
--- @param stats table
--- @return table rows (a list panel's)
function IR.GenerousRows(stats)
    local rows = {}
    for i, g in ipairs(firstOf(stats.generous or {}, IR.TOP)) do
        local lines = { g.looter, L["%s, the last on %s"]:format(plural(g.n, L["1 item"], L["%d items"]), IR.Day(g.last)) }
        for k = 1, math.min(#g.items, IR.TIP_ITEMS) do lines[#lines + 1] = itemName(g.items[k]) end
        rows[i] = { name = NS.WindowCells.ShortName(g.looter), nameColor = IR.ClassColor(g.class),
            right = tostring(g.n), tip = lines }
    end
    return rows
end

local GAIN_TONE = { [1] = "good", [0] = "muted", [-1] = "red" }

local function gainRow(r)
    local e, gain = r.e, r.gain
    local name, when = itemName(e), IR.Day(e.settledAt or r.at)
    local sub = L["from %s · %s"]:format(NS.WindowCells.ShortName(r.looter), when)
    local lines = { name, L["%s item levels"]:format(IR.Signed(gain)),
        L["From %s on %s"]:format(r.looter or L["Unknown"], when) }
    if r.legacy then
        sub = L["%s · as last judged"]:format(sub)
        lines[#lines + 1] = L["Received before the verdict was kept at the trade, so this is how it was last judged."]
    end
    local sign = gain > 0 and 1 or (gain < 0 and -1 or 0)
    return { label = name, labelColor = IR.QualityColor(e.quality), sublabel = sub, lo = math.min(0, gain),
        hi = math.max(0, gain), mark = 0, value = IR.Signed(gain), color = IR.ToneColor(GAIN_TONE[sign]), tip = lines }
end

local function byAbsGain(a, b)
    local x, y = math.abs(a.gain), math.abs(b.gain)
    if x ~= y then return x > y end
    return a.at < b.at
end

local function byAt(a, b) return a.at < b.at end

--- Section F: one range bar from 0 to each received item's gain, oldest first (the IR.TOP biggest
--- when there are more), and the heading's suffix: the gains summed, the items left out and those
--- with no item level comparison.
--- @param stats table
--- @return table rows, string|nil suffix
function IR.GainRows(stats)
    local list, t = {}, stats.totals or {}
    for i, r in ipairs(stats.received or {}) do list[i] = r end
    local more = math.max(0, #list - IR.TOP)
    if more > 0 then
        table.sort(list, byAbsGain)
        list = firstOf(list, IR.TOP)
    end
    table.sort(list, byAt)
    local rows, parts = {}, {}
    for i, r in ipairs(list) do rows[i] = gainRow(r) end
    if n(t.gainN) > 0 then parts[#parts + 1] = L["%s in all"]:format(IR.Signed(n(t.gainSum))) end
    if more > 0 then parts[#parts + 1] = L["%d more"]:format(more) end
    if n(t.gainNone) > 0 then parts[#parts + 1] = L["%d not compared"]:format(n(t.gainNone)) end
    return rows, #parts > 0 and table.concat(parts, " · ") or nil
end

-- ── G, H: per day ───────────────────────────────────────────────────────────────────────────

local function bucketHead(b, weekly)
    if weekly then return L["Week of %s"]:format(IR.Day(b.day)) end
    return IR.Day(b.day)
end

local STRIP = {
    asks = function(b)
        return b.asks, L["%s, %s"]:format(plural(b.asks, L["1 ask"], L["%d asks"]),
            plural(b.offers, L["1 offer"], L["%d offers"]))
    end,
    drops = function(b)
        return b.drops, L["%s, %s"]:format(plural(b.drops, L["1 drop"], L["%d drops"]),
            plural(b.upgrades, L["1 upgrade for you"], L["%d upgrades for you"]))
    end,
}

--- Sections G and H: one bucket a day (a week past InsightsStats.WEEK_AFTER days), for `kind`
--- `asks` (asks sent that day) or `drops` (drops seen), the hover naming the day and its counts.
--- @param stats table
--- @param kind string `asks` | `drops`
--- @return table buckets, number total
function IR.DayBuckets(stats, kind)
    local out, total = {}, 0
    for i, b in ipairs(stats.perDay or {}) do
        local count, line = STRIP[kind](b)
        total = total + count
        out[i] = { count = count, label = IR.Day(b.day), info = { bucketHead(b, stats.weekly), line } }
    end
    return out, total
end

-- ── I..N: the mixes ─────────────────────────────────────────────────────────────────────────

local VERDICT = {
    upgrade = { L["Upgrade"], "good" }, sidegrade = { L["Sidegrade"], "yellow" },
    downgrade = { L["Downgrade"], "red" }, cantUse = { L["Can't use"], "redMuted" },
    doesntWant = { L["Doesn't want"], "bad" }, unknown = { L["Unknown"], "muted" },
    newCollect = { L["New to your collection"], "good" }, collected = { L["Already collected"], "bad" },
    collectUnknown = { L["Collection unknown"], "muted" },
}
local TRADE = { yes = L["Yes"], likely = L["Likely"], no = L["No"], unknown = L["Unknown"] }

local function unknownOr(fn)
    return function(k)
        if k == "unknown" then return L["Unknown"] end
        return fn(k) or tostring(k)
    end
end

-- Each mix's list in the stats, its words and its color (nil: the bar color).
IR.MIX = {
    byClass = { label = unknownOr(function(k) return NS.Compat.ClassDisplayName(k) end), color = IR.ClassColor },
    byQuality = { label = unknownOr(function(k) return NS.Item.QualityLabel(k) end), color = IR.QualityColor },
    bySlot = { label = tostring },
    byCategory = { label = function(k) return NS.CollectCells.KindLabel(k) or tostring(k) end },
    verdicts = {
        label = function(k) return VERDICT[k] and VERDICT[k][1] or tostring(k) end,
        color = function(k) return IR.ToneColor(VERDICT[k] and VERDICT[k][2] or "muted") end,
    },
    tradeStates = {
        label = function(k) return TRADE[k] or tostring(k) end,
        color = function(k) return IR.ToneColor(NS.WindowCells.TRADE_TONE[k] or "muted") end,
    },
}

-- A mix row's hover: the label, its share, and for Can't use the drops another spec could use.
local function mixTip(key, k, label, count, total, stats)
    local lines = { label, L["%s drops"]:format(share(count, total)) }
    if key == "verdicts" and k == "cantUse" and n(stats.cantUseOff) > 0 then
        lines[#lines + 1] = L["%d usable on another spec"]:format(stats.cantUseOff)
    end
    return lines
end

--- Sections I..N: one bar per value of the mix `key` (an IR.MIX key), in the stats' order.
--- @param stats table
--- @param key string
--- @return table rows
function IR.MixRows(stats, key)
    local spec, list, total = IR.MIX[key], stats[key] or {}, 0
    for _, r in ipairs(list) do total = total + r.n end
    local rows = {}
    for i, r in ipairs(list) do
        local label = spec.label(r.key)
        rows[i] = { label = label, frac = r.n, value = tostring(r.n), color = spec.color and spec.color(r.key) or nil,
            tip = mixTip(key, r.key, label, r.n, total, stats) }
    end
    return rows
end
