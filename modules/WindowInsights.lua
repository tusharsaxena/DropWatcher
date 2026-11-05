local _, NS = ...
-- modules/WindowInsights.lua — the Insights tab's body (issue #12, Insights design spec §4.3, §5):
-- its own filter bar, the KPI cards and the chart sections over the kept history (the sections'
-- layout pass is modules/InsightsSections.lua) and the strip naming the period it covers, drawn
-- through LibKa0s-Charts-1.0 (NS.Charts, core/ChartsSetup.lua).
--
-- A BAR OF ITS OWN. The tab registers with `ownBar`, so the window hides the shared filter bar and
-- the footer's Sort while it shows (modules/Window.lua). Its seven dropdowns (Character, Instance,
-- Difficulty, Situation, Date, Quality, Category) are single-select, data-driven and session-only
-- (NS.State.insightsFilters): each lists the values present once the other six apply, with their
-- counts (NS.InsightsFilters.Options), and a pick that empties another dropdown puts that one back
-- to All (Normalize). The bar wraps to the width (NS.InsightsRows.BarPlan). Reset filters, on the
-- strip, puts every one back to All.
--
-- THE PASS. refresh runs on every window repaint, so it compares a cache key first: the log's
-- identity and its groups' (test mode swaps the groups of one persistent table, and turning it off
-- sends no message), this tab's HistoryChanged revision, the test-mode and simulation flags, the
-- filters, the retention, the day, the width and the layout. The data changed: Rows, Normalize,
-- Filter, Period and the one stats pass (NS.InsightsStats.Compute), then the layout. Only the width
-- or the layout changed: the layout alone. Nothing changed: nothing. H.Log() already answers test
-- mode's sample log and a running simulation's, so both fill the tab with no code of their own.
--
-- DEGRADED. Without LibKa0s-Charts-1.0 the bar and the strip are built and one line says the charts
-- are unavailable (no drawing stub, anti-pattern #73). Without LibKa0s-Widgets-1.0 NS.MakeDropdown
-- answers nil: no dropdowns, the filters stay All, and the cards still draw.

NS.WindowInsights = NS.WindowInsights or {}
local WI = NS.WindowInsights
local K = NS.Constants.WINDOW
local L = NS.L
local Perf = NS.Perf
local IF = NS.InsightsFilters

local TAG = "UI"
local PAD = 8           -- the content's left and right margin
local SCROLL_STEP = 40  -- one wheel notch
local revision = 0      -- bumped by each HistoryChanged

-- ── the filters ─────────────────────────────────────────────────────────────────────────────

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function filters()
    local f = NS.State.insightsFilters
    if type(f) ~= "table" then
        f = copy(IF.DEFAULTS)
        NS.State.insightsFilters = f
    end
    return f
end

local function signature(f)
    local out = {}
    for i, key in ipairs(IF.ORDER) do out[i] = tostring(f[key]) end
    return table.concat(out, "\31")
end

local function pane()
    local f = NS.Window.Frame()
    return f and f.panes and f.panes.insights
end

-- Repaint the shown window now: a pick is the player's own click.
local function changed() NS.Window.OnFilterChanged("insights") end

--- Pick one filter's value; the other picks are checked against it on the next pass.
--- @param key string an InsightsFilters.ORDER key
--- @param value any
function WI.SetFilter(key, value)
    filters()[key] = value
    local p = pane()
    if p then p.keep = key end
    changed()
end

--- Every filter back to All.
function WI.ResetFilters()
    NS.State.insightsFilters = copy(IF.DEFAULTS)
    NS.Debug(TAG, "insights: filters reset")
    changed()
end

--- Mark the tab for a fresh layout on the next repaint (a skin switch: the colors the cards were
--- bound with are read again).
function WI.MarkLayout()
    local p = pane()
    if p then p.layoutKey = nil end
    NS.Window.ScheduleRepaint()
end

-- ── construction ────────────────────────────────────────────────────────────────────────────

local function buildBar(p)
    local bar = CreateFrame("Frame", nil, p)
    bar:SetPoint("TOPLEFT", p, "TOPLEFT", 0, 0)
    bar:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, 0)
    bar:SetHeight(1)
    p.bar, p.dropdowns = bar, {}
    for _, key in ipairs(IF.ORDER) do
        local dd = NS.MakeDropdown(bar, NS.InsightsRows.BAR_MIN_W)
        if dd then
            dd.onSelect = function(v) WI.SetFilter(key, v) end
            p.dropdowns[key] = dd
        end
    end
end

local function buildStrip(p)
    local strip = CreateFrame("Frame", nil, p)
    strip:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(K.STRIP_H)
    strip.line = strip:CreateTexture(nil, "ARTWORK")
    NS.SkinPaint(strip.line, function(t) t:SetColorTexture(NS.SkinColor("dw.rule")) end)
    strip.line:SetHeight(1)
    strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
    strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
    strip.info = strip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    NS.Skin.Text(strip.info, "disabled")
    strip.info:SetJustifyH("LEFT")
    strip.info:SetWordWrap(false)
    strip.reset = NS.FooterRow.Button(strip, "reset", L["Reset filters"], function() WI.ResetFilters() end)
    p.strip = strip
end

local function buildScroll(p)
    local scroll = CreateFrame("ScrollFrame", nil, p, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = self:GetVerticalScrollRange() or 0
        self:SetVerticalScroll(math.max(0, math.min(max, (self:GetVerticalScroll() or 0) - delta * SCROLL_STEP)))
    end)
    p.scroll, p.content = scroll, content
end

local function buildCards(p)
    p.cards = {}
    for i, c in ipairs(NS.InsightsRows.CARDS) do p.cards[i] = p.ctx:card(p.content, c.caption) end
end

local function build(p)
    buildBar(p)
    buildStrip(p)
    buildScroll(p)
    p.empty = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    NS.Skin.Text(p.empty, "text.muted")
    -- Held between both sides of the scroll and wrapped, so a long line fits compact's width.
    p.empty:SetPoint("LEFT", p.scroll, "LEFT", 2 * PAD, 0)
    p.empty:SetPoint("RIGHT", p.scroll, "RIGHT", -2 * PAD, 0)
    p.empty:SetJustifyH("CENTER")
    p.empty:SetWordWrap(true)
    p.empty:Hide()
    if NS.Charts then
        p.ctx = NS.Charts:New(p.content, NS.ChartsHost())
        buildCards(p)
        NS.InsightsSections.Build(p)
    else
        NS.Debug(TAG, "insights: LibKa0s-Charts-1.0 absent, the tab draws no charts")
    end
end

-- ── the pass ────────────────────────────────────────────────────────────────────────────────

local function isCompact() return NS.WindowCompact.Mode() == "compact" end

local function paneWidth(p)
    local w = p:GetWidth()
    if not w or w <= 0 then
        local f = NS.Window.Frame()
        w = (f and f:GetWidth() or K.WIDTH) - 2 * K.INSET
    end
    return w
end

local function options()
    return { current = NS.CharFilter.CurrentKey(), classColor = NS.Compat.ClassColor,
        qualityColor = NS.QualityColor, days = NS.HistoryRetention.Days() }
end

local function dataKey(log, groups, f, now)
    return table.concat({ tostring(log), tostring(groups), revision, tostring(NS.State.testMode == true),
        tostring(NS.Sim:IsActive()), signature(f), NS.HistoryRetention.Days(), IF.Midnight(now) }, "|")
end

local function compute(p, log, groups, now)
    local t0 = Perf.on and debugprofilestop()
    local opts = options()
    local rows = IF.Rows(groups)
    local f, opt = IF.Normalize(rows, filters(), now, p.keep, opts)
    NS.State.insightsFilters, p.keep = f, nil
    local shown = IF.Filter(rows, f, now)
    local period = IF.Period(shown, opts.days, f.date, now)
    p.data = { rows = rows, shown = shown, options = opt, period = period, days = opts.days,
        stats = NS.InsightsStats.Compute(shown, period) }
    p.dataKey = dataKey(log, groups, f, now)
    p.computes = (p.computes or 0) + 1
    NS.Debug(TAG, "insights: %d drops, %d after filters", #rows, #shown)
    if t0 then Perf.Note("insights.compute", debugprofilestop() - t0, "window.refresh") end
end

-- The dropdowns' rows and their closed labels, from the last pass.
local function paintBar(p)
    local f, opt = filters(), p.data.options
    for key, dd in pairs(p.dropdowns) do
        dd:SetOptions(opt[key])
        dd:SetValue(f[key], IF.ClosedLabel(opt[key], f[key]))
    end
end

-- The bar wrapped to the width; answers its height (0 with no dropdowns).
local function placeBar(p, width)
    local keys = {}
    for _, key in ipairs(IF.ORDER) do
        if p.dropdowns[key] then keys[#keys + 1] = key end
    end
    if #keys == 0 then p.bar:SetHeight(1); return 0 end
    local cells, rows = NS.InsightsRows.BarPlan(width, #keys)
    for i, key in ipairs(keys) do
        local dd, c = p.dropdowns[key], cells[i]
        dd:ClearAllPoints()
        dd:SetPoint("TOPLEFT", p.bar, "TOPLEFT", c.x, -(c.y + 5))
        dd:SetWidth(c.w)
    end
    local h = rows * NS.InsightsRows.BAR_ROW_H + 6
    p.bar:SetHeight(h)
    return h
end

local function placeStrip(p, compact)
    local strip, FR = p.strip, NS.FooterRow
    if strip.dwPlacedCompact ~= compact then
        strip.dwPlacedCompact = compact
        FR.SetCompact(strip.reset, compact)
        local slots = FR.Slots({ { key = "reset", w = FR.Width(compact) } }, FR.GAP, 0)
        FR.Place(strip, strip.reset, slots.reset)
        FR.PlaceInfo(strip, strip.info, slots.left)
    end
    strip.info:SetText(NS.InsightsRows.PeriodText(p.data.period))
end

local function placeScroll(p, barH)
    if p.scrollTop == barH then return end
    p.scrollTop = barH
    p.scroll:ClearAllPoints()
    p.scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -barH)
    p.scroll:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -K.SCROLL_W, K.STRIP_H)
end

local function toneColor(tone)
    if not tone then return nil end
    local r, g, b = NS.SkinColor(NS.Constants.TONE_TOKEN[tone])
    return r and { r, g, b } or nil
end

-- The cards in their grid from the top of the content; answers the cursor under them.
local function placeCards(p, width, compact)
    local cw = width - 2 * PAD
    local cells, h = NS.InsightsRows.CardGrid(#p.cards, cw, compact and 2 or 4,
        NS.InsightsRows.CARD_GAP, NS.Charts.K.CARD_H)
    local totals = p.data.stats.totals
    for i, card in ipairs(p.cards) do
        local c = cells[i]
        card.frame:ClearAllPoints()
        card.frame:SetPoint("TOPLEFT", p.content, "TOPLEFT", PAD + c.x, -(PAD + c.y))
        card.frame:SetWidth(c.w)
        local value, tip, tone = NS.InsightsRows.Card(NS.InsightsRows.CARDS[i].key, totals)
        p.ctx:setCard(card, value, tip, c.w - 12, toneColor(tone))
        card.frame:Show()
    end
    return -(PAD + h + NS.Charts.K.SECTION_GAP)
end

local function showCards(p, on)
    for _, card in ipairs(p.cards or {}) do card.frame:SetShown(on) end
end

local function emptyLine(p)
    if not p.ctx then return L["The charts need LibKa0s-Charts-1.0, which did not load."] end
    if #p.data.shown == 0 then return NS.InsightsRows.EmptyText(#p.data.rows, p.data.days) end
    return nil
end

local function layout(p, width, compact)
    local t0 = Perf.on and debugprofilestop()
    placeScroll(p, placeBar(p, width))
    placeStrip(p, compact)
    paintBar(p)
    local line = emptyLine(p)
    p.empty:SetShown(line ~= nil)
    if line then p.empty:SetText(line) end
    local cw = width - K.SCROLL_W
    if p.ctx then
        p.ctx:ReleaseAll()
        NS.InsightsSections.Hide(p)
    end
    showCards(p, line == nil)
    local y = -PAD
    if line == nil then
        y = NS.InsightsSections.Layout(p, p.data.stats, placeCards(p, cw, compact), cw, PAD, compact)
    end
    p.content:SetSize(cw, math.max(1, PAD - y))
    if t0 then Perf.Note("insights.layout", debugprofilestop() - t0, "window.refresh") end
end

local function refresh(p)
    local now = time()
    local log = NS.History.Log()
    local groups = log and log.groups or {}
    if p.dataKey ~= dataKey(log, groups, filters(), now) or p.keep then
        compute(p, log, groups, now)
        p.layoutKey = nil
    end
    local width, compact = paneWidth(p), isCompact()
    local key = p.dataKey .. "|" .. width .. "|" .. tostring(compact)
    if p.layoutKey == key then return end
    p.layoutKey = key
    layout(p, width, compact)
end

--- The drawn pane, for the suites: { pane, dropdowns, cards, strip, empty, data, computes, ctx, bar,
--- headers, dividers, panels, strips, sections (each section's row count this pass) } or nil.
--- @return table|nil
function WI.Drawn()
    local p = pane()
    if not (p and p.strip) then return nil end
    return { pane = p, dropdowns = p.dropdowns, cards = p.cards, strip = p.strip, empty = p.empty,
        data = p.data, computes = p.computes or 0, ctx = p.ctx, bar = p.bar, headers = p.headers,
        dividers = p.dividers, panels = p.panels, strips = p.strips, sections = p.drawn }
end

NS.Window.RegisterTab("insights", { build = build, refresh = refresh, ownBar = true })

-- ── the bus ─────────────────────────────────────────────────────────────────────────────────

-- HistoryChanged moves the revision, so the next pass recomputes, and asks for one repaint on the
-- next frame through the window's coalesced repaint.
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.HISTORY_CHANGED, function()
        revision = revision + 1
        NS.Window.ScheduleRepaint()
    end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
