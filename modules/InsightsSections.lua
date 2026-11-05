local _, NS = ...
-- modules/InsightsSections.lua — the Insights tab's chart sections (issue #12, Insights design spec
-- §1.4, §5): the layout pass under the cards, each section on a LibKa0s-Charts-1.0 renderer, its rows
-- from NS.InsightsRows, every number in its hover.
--
-- THE ORDER (spec §5). Four groups under a divider each: LOOT (A drops by outcome, M your verdicts,
-- N trade estimates), UPGRADES (B by instance, C by boss, D top instances beside E most generous
-- members, stacked in compact), TRADES (F item level gained, G asks per day) and ACTIVITY (H drops
-- per day, I looter class, J quality, K slot, L category). SECTIONS walks them, each answering the
-- cursor under what it drew; a list panel's height is turned into one here.
--
-- EMPTY (spec §5.3). The bar, stacked, range and strip renderers hide their heading for no rows, so
-- a section checks its rows first and, with none, places its heading itself with one muted line
-- under it (the `empty` pool's, a host widget in the context's pools). A list panel keeps its title
-- and holds the line. `drawn[key]` records each section's row count for the suites.
--
-- CHROME. The headings, dividers, strips and list panels are the context's chrome, made once in
-- Build and hidden at the start of every pass (Hide); a section shows what it places. Everything
-- else is pooled, so a second pass builds no frame. The headings are retitled each pass, because
-- some carry a suffix (F's gains summed, a ranked section's "n more") or a week's wording.
--
-- Reads NS.Charts (the major, core/ChartsSetup.lua), NS.InsightsRows and NS.L at call time, so its
-- TOC position is conventional; modules/WindowInsights.lua builds and calls it.

NS.InsightsSections = NS.InsightsSections or {}
local SX = NS.InsightsSections
local L = NS.L

SX.EMPTY_H = 16        -- a muted line's least height (its wrapped height when the client measures more)
SX.DIVIDER_GAP = 4     -- under a divider
SX.RATE_W = 80         -- D's value column: `0.43 / visit`

--- The headings, by section, each with its title (and a weekly one for the strips).
SX.HEADERS = {
    { key = "outcomes", title = L["Drops by outcome"] },
    { key = "verdicts", title = L["Your verdicts"] },
    { key = "tradeStates", title = L["Trade estimates on others' drops"] },
    { key = "byInstance", title = L["Upgrades for me by instance"] },
    { key = "byBoss", title = L["Upgrades for me by boss"] },
    { key = "gain", title = L["Item level gained from items received"] },
    { key = "asks", title = L["Asks per day"], weekly = L["Asks per week"] },
    { key = "drops", title = L["Drops per day"], weekly = L["Drops per week"] },
    { key = "byClass", title = L["Drops by looter class"] },
    { key = "byQuality", title = L["Drops by quality"] },
    { key = "bySlot", title = L["Drops by slot"] },
    { key = "byCategory", title = L["Drops by category"] },
}
SX.DIVIDERS = {
    { key = "loot", title = L["Loot"] }, { key = "upgrades", title = L["Upgrades"] },
    { key = "trades", title = L["Trades"] }, { key = "activity", title = L["Activity"] },
}
SX.PANELS = {
    { key = "topRate", title = L["Top instances for upgrades"] },
    { key = "generous", title = L["Most generous group members"] },
}

-- Each section's line when it has nothing to draw.
SX.EMPTY = {
    outcomes = L["No drops match these filters."],
    verdicts = L["No verdicts in these filters."],
    tradeStates = L["No drops by others in these filters."],
    byInstance = L["No upgrades for you in these filters."],
    byBoss = L["No upgrades for you from a boss kill in these filters. Mythic+ keys are kept as whole runs."],
    topRate = L["No instance with an upgrade for you and two visits or more."],
    generous = L["No items received in these filters."],
    gain = L["No items received in these filters."],
    gainNone = L["No item received here has an item level comparison."],
    asks = L["No asks in these filters."],
    drops = L["No drops match these filters."],
    byClass = L["No drops match these filters."],
    byQuality = L["No drops match these filters."],
    bySlot = L["No drops match these filters."],
    byCategory = L["No drops match these filters."],
}

local TITLE = {}
for _, h in ipairs(SX.HEADERS) do TITLE[h.key] = h end

local function CK() return NS.Charts.K end

-- ── construction ────────────────────────────────────────────────────────────────────────────

local function keep(p, region)
    p.chrome[#p.chrome + 1] = region
    region:Hide()
    return region
end

--- Make the sections' chrome on the pane's chart context (once, when the pane is built).
--- @param p table the Insights pane: { ctx, content }
function SX.Build(p)
    local ctx, content = p.ctx, p.content
    p.chrome, p.headers, p.dividers, p.panels, p.drawn = {}, {}, {}, {}, {}
    for _, h in ipairs(SX.HEADERS) do p.headers[h.key] = keep(p, ctx:sectionHeader(content, h.title)) end
    for _, d in ipairs(SX.DIVIDERS) do p.dividers[d.key] = keep(p, ctx:sectionDivider(content, d.title)) end
    for _, s in ipairs(SX.PANELS) do p.panels[s.key] = keep(p, ctx:listPanel(content, s.title)) end
    p.strips = { asks = keep(p, ctx:strip(content)), drops = keep(p, ctx:strip(content)) }
end

--- Hide every piece of chrome (a pass starts here, after the context's ReleaseAll).
--- @param p table
function SX.Hide(p)
    for _, region in ipairs(p.chrome or {}) do region:Hide() end
end

-- ── the shared pieces ───────────────────────────────────────────────────────────────────────

local function paintMuted(ctx, f) ctx.paint(f.text, ctx.colors.muted) end

-- The empty line: a host widget in the context's `empty` pool, repainted by its Reskin.
local function emptyLine(ctx, parent)
    local f = CreateFrame("Frame", nil, parent)
    f.text = ctx.text(f, ctx.fonts.label, "LEFT")
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f.text:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    f.text:SetWordWrap(true)
    f._reskin = paintMuted
    paintMuted(ctx, f)
    return f
end

-- Place one muted line in `parent` at (x, y), `width` wide; answers its height.
local function placeLine(p, parent, text, x, y, width)
    local f = p.ctx:acquire(p.ctx:Pool("empty"), emptyLine, parent)
    f:SetParent(parent)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetWidth(math.max(1, width))
    f.text:SetText(text)
    local measured = f.text:GetStringHeight()
    local h = math.max(SX.EMPTY_H, type(measured) == "number" and math.ceil(measured) or 0)
    f:SetHeight(h)
    return h
end

-- A heading's text for this pass: its title (the weekly one when the strip buckets by week), and a
-- suffix after a middle dot.
local function retitle(p, key, suffix, weekly)
    local h = TITLE[key]
    local title = weekly and h.weekly or h.title
    if suffix then title = L["%s · %s"]:format(title, suffix) end
    p.headers[key]:SetText(title)
end

--- A section with nothing to draw: its heading at the cursor and one muted line under it.
--- @return number the cursor under it
function SX.Empty(p, key, text, y, w, pad)
    y = p.ctx:placeHeader(p.headers[key], y, pad)
    local h = placeLine(p, p.content, text, pad, y, w - pad * 2)
    p.drawn[key] = 0
    return y - h - CK().SECTION_GAP
end

local function bars(p, key, rows, y, w, pad)
    p.drawn[key] = #rows
    if #rows == 0 then return SX.Empty(p, key, SX.EMPTY[key], y, w, pad) end
    return p.ctx:renderBarSection(p.ctx:Pool(key), p.headers[key], rows, y, w, pad)
end

local function stacked(p, key, rows, legend, y, w, pad)
    p.drawn[key] = #rows
    if #rows == 0 then return SX.Empty(p, key, SX.EMPTY[key], y, w, pad) end
    local ctx = p.ctx
    y = ctx:renderStackedBarSection(ctx:Pool(key), p.headers[key], rows, y, w, pad)
    return ctx:renderLegend(ctx:Pool(key .. "Legend"), legend, y + CK().SECTION_GAP, w, pad)
end

local function moreSuffix(more)
    if more > 0 then return L["%d more"]:format(more) end
    return nil
end

-- ── the sections ────────────────────────────────────────────────────────────────────────────

local function divider(key)
    return function(p, _, y, w, pad)
        local f = p.dividers[key]
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", p.content, "TOPLEFT", pad, y)
        f:SetWidth(math.max(1, w - pad * 2))
        f:Show()
        return y - CK().DIVIDER_H - SX.DIVIDER_GAP
    end
end

-- A: others' drops, the upgrades among them and yours, by what became of each.
local function sOutcomes(p, stats, y, w, pad)
    local rows, legend = NS.InsightsRows.OutcomeRows(stats)
    retitle(p, "outcomes")
    return stacked(p, "outcomes", rows, legend, y, w, pad)
end

-- M, N, I..L: one bar a value of a mix.
local function mix(key)
    return function(p, stats, y, w, pad)
        retitle(p, key)
        return bars(p, key, NS.InsightsRows.MixRows(stats, key), y, w, pad)
    end
end

-- B: the instances with the most upgrades for you, yours and others' in the palette's first two.
local function sInstances(p, stats, y, w, pad)
    local ctx = p.ctx
    local rows, legend, more = NS.InsightsRows.InstanceRows(stats,
        { mine = ctx:paletteColor(1), others = ctx:paletteColor(2) })
    retitle(p, "byInstance", moreSuffix(more))
    return stacked(p, "byInstance", rows, legend, y, w, pad)
end

-- C: the boss kills with the most upgrades for you.
local function sBosses(p, stats, y, w, pad)
    local rows, more = NS.InsightsRows.BossRows(stats)
    retitle(p, "byBoss", moreSuffix(more))
    return bars(p, "byBoss", rows, y, w, pad)
end

-- One list panel at (x, y), `colW` wide; with no rows its title stays and one line says why.
-- Answers its height.
local function listPanel(p, key, rows, y, colW, x, rightW)
    local panel = p.panels[key]
    local h = p.ctx:renderListPanel(p.ctx:Pool(key), panel, rows, y, colW, x, rightW)
    p.drawn[key] = #rows
    if #rows > 0 then return h end
    local top = CK().LIST_TITLE_H
    h = top + placeLine(p, panel, SX.EMPTY[key], 8, -top, colW - 16) + 4
    panel:SetHeight(h)
    return h
end

-- D beside E (full), or D over E (compact).
local function sLists(p, stats, y, w, pad, compact)
    local gap, IR = NS.InsightsRows.CARD_GAP, NS.InsightsRows
    local inner = w - pad * 2
    local colW = compact and inner or (inner - gap) / 2
    local hD = listPanel(p, "topRate", IR.RateRows(stats), y, colW, pad, SX.RATE_W)
    if compact then
        local hE = listPanel(p, "generous", IR.GenerousRows(stats), y - hD - gap, colW, pad)
        return y - hD - gap - hE - CK().SECTION_GAP
    end
    local hE = listPanel(p, "generous", IR.GenerousRows(stats), y, colW, pad + colW + gap)
    return y - math.max(hD, hE) - CK().SECTION_GAP
end

-- F: the item level each received item gained you, on one scale through 0.
local function sGain(p, stats, y, w, pad)
    local rows, suffix = NS.InsightsRows.GainRows(stats)
    retitle(p, "gain", suffix)
    p.drawn.gain = #rows
    if #rows == 0 then
        local none = (stats.totals and stats.totals.gainNone or 0) > 0
        return SX.Empty(p, "gain", none and SX.EMPTY.gainNone or SX.EMPTY.gain, y, w, pad)
    end
    local ctx = p.ctx
    return ctx:renderRangeSection(ctx:Pool("gain"), p.headers.gain, rows, y, w, pad, ctx:Pool("gainScale"),
        NS.InsightsRows.Signed)
end

-- G, H: one column a day (or a week), a zero day a faint stub.
local function strip(key)
    return function(p, stats, y, w, pad)
        local buckets, total = NS.InsightsRows.DayBuckets(stats, key)
        retitle(p, key, nil, stats.weekly)
        p.drawn[key] = total > 0 and #buckets or 0
        if total == 0 then return SX.Empty(p, key, SX.EMPTY[key], y, w, pad) end
        return p.ctx:renderStrip(p.ctx:Pool(key), p.headers[key], p.strips[key], buckets, y, w, pad)
    end
end

SX.SECTIONS = {
    divider("loot"), sOutcomes, mix("verdicts"), mix("tradeStates"),
    divider("upgrades"), sInstances, sBosses, sLists,
    divider("trades"), sGain, strip("asks"),
    divider("activity"), strip("drops"), mix("byClass"), mix("byQuality"), mix("bySlot"), mix("byCategory"),
}

--- Lay every section out from the cursor `y` across `w` (the content's width, `pad` its margins),
--- after the cards; answers the cursor under the last. The chrome is hidden and the pools released
--- by the caller first.
--- @param p table the Insights pane
--- @param stats table InsightsStats.Compute's
--- @param y number
--- @param w number
--- @param pad number
--- @param compact boolean
--- @return number
function SX.Layout(p, stats, y, w, pad, compact)
    p.drawn = {}
    for _, section in ipairs(SX.SECTIONS) do y = section(p, stats, y, w, pad, compact) end
    return y
end
