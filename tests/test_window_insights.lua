-- tests/test_window_insights.lua — the Insights tab (issue #12, Insights design spec §4, §5;
-- modules/WindowInsights.lua, the `ownBar` plumbing in modules/Window.lua): built once on its first
-- show; a bar of its own, so the shared bar and the footer's Sort stand aside and the mode strips sit
-- under the tabs; its seven data-driven dropdowns with counts, a pick redrawing the cards and Reset
-- putting every one back; the cache (an unrelated repaint computes nothing, HistoryChanged and
-- turning test mode off do); the period caption following the retention; the empty lines; the
-- degraded installs (no Charts: the unavailable line; no Widgets: no dropdowns, the cards still
-- draw); compact's two-column cards and wrapped bar.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local CHARTS = { "libs/LibKa0s/Charts.lua", "libs/LibKa0s/ChartsRender.lua" }

-- An enabled addon, test mode's sample history in force when `samples`, the window on Insights.
local function insights(opts)
    opts = opts or {}
    local NS, _, m = T.enableAddon({ skip = opts.skip })
    if opts.samples then
        m.seedGearJournal()
        NS.SetTestMode(true)
    end
    if opts.mode then NS.SetWindowMode(opts.mode) end
    NS.ShowWindow()
    NS.Window.SelectTab("insights")
    return NS, NS.Window.Frame(), m, NS.WindowInsights.Drawn()
end

local function cardValue(d, i) return d.cards[i].value:GetText() end

local function topOf(pane)
    for _, p in ipairs(pane.__points) do
        if p[1] == "TOPLEFT" then return p[5] end
    end
end

-- ── the tab and its bar ─────────────────────────────────────────────────────────────────────

test("insights tab: built once on its first show, with its chart context and eight cards", function()
    local NS, f, _, d = insights()
    assertTrue(d ~= nil, "drawn")
    assertTrue(d.ctx ~= nil, "a LibKa0s-Charts-1.0 context")
    assertEqual(#d.cards, 8)
    assertEqual(d.cards[1].caption, "Drops seen")
    local pane = d.pane
    NS.Window.SelectTab("history")
    NS.Window.SelectTab("insights")
    assertTrue(NS.WindowInsights.Drawn().pane == pane and pane.cards == d.cards, "built once")
    assertFalse(f.panes.insights.placeholder:IsShown(), "the body replaces the placeholder")
    assertTrue(NS.Window.TabOwnsBar("insights") and not NS.Window.TabOwnsBar("history"))
end)

test("insights tab: the shared bar hides and the pane starts under the tabs, then both come back on History", function()
    local NS, f = insights()
    local K = NS.Constants.WINDOW
    assertFalse(f.filterHost:IsShown(), "no shared bar on Insights")
    assertEqual(topOf(f.panes.insights), -(K.TAB_H + 4))
    NS.Window.SelectTab("history")
    assertTrue(f.filterHost:IsShown(), "the shared bar is back")
    assertEqual(topOf(f.panes.history), -(K.TAB_H + 4 + K.FILTER_H))
end)

test("insights tab: the test-mode strip sits under the tabs on Insights and under the bar on History", function()
    local NS, f = insights({ samples = true })
    local K = NS.Constants.WINDOW
    local pt = f.banner.__points[1]
    assertTrue(f.banner:IsShown())
    assertEqual(pt[2], f.body); assertEqual(pt[5], -(K.TAB_H + 6))
    assertEqual(topOf(f.panes.insights), -(K.TAB_H + 4 + NS.CompactChrome.BannerH()), "the pane under the strip")
    NS.Window.SelectTab("history")
    pt = f.banner.__points[1]
    assertEqual(pt[2], f.filterHost); assertEqual(pt[3], "BOTTOMLEFT"); assertEqual(pt[5], -2)
end)

test("insights tab: the footer's Sort is hidden on Insights and back on History", function()
    local NS = insights()
    local _, sort = NS.WindowFooter.Parts()
    assertFalse(sort:IsShown(), "no dead Sort under the charts")
    NS.Window.SelectTab("history")
    assertTrue(sort:IsShown())
end)

test("insights tab: switching in closes the compact Filters panel", function()
    local NS, _, m = T.enableAddon()
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    local p = NS.CompactChrome.Parts()
    p.filters:__fire("OnClick")
    assertTrue(p.panel:IsShown(), "open on History")
    NS.Window.SelectTab("insights")
    assertFalse(p.panel:IsShown(), "closed with the bar")
    assertTrue(m ~= nil)
end)

-- ── the filters ─────────────────────────────────────────────────────────────────────────────

test("insights tab: seven dropdowns, their heads closed with the number of values, rows with counts", function()
    local _, _, _, d = insights({ samples = true })
    local n = 0
    for _ in pairs(d.dropdowns) do n = n + 1 end
    assertEqual(n, 7)
    assertTrue(d.dropdowns.situation.text:GetText():match("^All situations %(%d+%)$") ~= nil,
        d.dropdowns.situation.text:GetText())
    local rows = d.dropdowns.situation._options
    assertEqual(rows[1].value, "all")
    assertTrue(rows[2].label:match("%(%d+%)$") ~= nil, "a value row carries its drop count")
end)

test("insights tab: a pick redraws the cards and the strip; Reset puts every filter back", function()
    local NS, _, _, d = insights({ samples = true })
    local all = tonumber(cardValue(d, 1))
    local before = d.computes
    local pick
    for _, o in ipairs(d.dropdowns.situation._options) do
        if o.value ~= "all" and o.count < all then pick = o end
    end
    assertTrue(pick ~= nil, "a situation narrower than the whole log")
    d.dropdowns.situation.onSelect(pick.value)
    d = NS.WindowInsights.Drawn()
    assertEqual(d.computes, before + 1)
    assertEqual(tonumber(cardValue(d, 1)), pick.count)
    assertEqual(d.dropdowns.situation.text:GetText(), pick.name, "closed on the pick's name")
    assertTrue(d.strip.info:GetText():find(pick.count .. " drops", 1, true) ~= nil, d.strip.info:GetText())
    d.strip.reset:__fire("OnClick")
    d = NS.WindowInsights.Drawn()
    assertEqual(NS.State.insightsFilters.situation, "all")
    assertEqual(tonumber(cardValue(d, 1)), all)
end)

test("insights tab: a date range with nothing in it says no drop matches, and the cards hide", function()
    local NS, _, m = T.enableAddon()
    local now = m.time()
    NS.History.Store().groups = { { key = "k", label = "Boss", kind = "encounter", instance = "Ruby Life Pools",
        situation = "dungeon", at = now - 3 * 86400, drops = { { itemLink = "x", itemID = 1, looter = "Brakk-Testrealm",
        outcome = "seen", at = now - 3 * 86400, quality = 4, equipLoc = "INVTYPE_HEAD" } } } }
    NS.ShowWindow()
    NS.Window.SelectTab("insights")
    local d = NS.WindowInsights.Drawn()
    assertEqual(cardValue(d, 1), "1"); assertTrue(d.cards[1].frame:IsShown())
    NS.WindowInsights.SetFilter("date", "today")
    d = NS.WindowInsights.Drawn()
    assertEqual(NS.State.insightsFilters.date, "today", "the dropdown just changed keeps its pick at 0")
    assertTrue(d.empty:IsShown()); assertEqual(d.empty:GetText(), "No drops match these filters.")
    assertFalse(d.cards[1].frame:IsShown())
end)

-- ── the cache ───────────────────────────────────────────────────────────────────────────────

test("insights tab: an unrelated repaint computes nothing; HistoryChanged and test mode off do", function()
    local NS, _, m, d = insights({ samples = true })
    local n = d.computes
    NS.Window.Refresh()
    NS.Window.Refresh()
    assertEqual(NS.WindowInsights.Drawn().computes, n, "nothing changed: the cache holds")
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
    m.advance(0.1)
    assertEqual(NS.WindowInsights.Drawn().computes, n + 1, "HistoryChanged recomputes")
    local shown = #NS.WindowInsights.Drawn().data.rows
    assertTrue(shown > 0, "the samples")
    NS.SetTestMode(false)
    NS.Window.Refresh()
    d = NS.WindowInsights.Drawn()
    assertTrue(d.computes > n + 1, "the account's log again, with no message")
    assertEqual(#d.data.rows, 0)
    assertTrue(d.empty:IsShown())
end)

test("insights tab: no work while the window is hidden; the show draws the tab afresh", function()
    -- red under: refresh with no on-screen guard (combat start recomputes on a just-hidden frame)
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)                -- test mode opens the window, so combat closes it again
    NS.Window.SelectTab("insights")
    local f = NS.Window.Frame()
    local n = NS.WindowInsights.Drawn().computes
    assertTrue(n > 0, "drawn once on screen")
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.State.testMode); assertFalse(f:IsShown(), "hidden with test mode")
    assertEqual(NS.WindowInsights.Drawn().computes, n, "the hidden window computed nothing")
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
    m.advance(0.1)
    NS.Window.Refresh()
    assertEqual(NS.WindowInsights.Drawn().computes, n, "nor on a later repaint while hidden")
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    NS.ShowWindow()
    f:__fire("OnShow")                  -- the client fires it on Show; the mock frame does not
    local d = NS.WindowInsights.Drawn()
    assertEqual(d.computes, n + 1, "the show computes the account's log")
    assertEqual(#d.data.rows, 0)
end)

test("insights tab: a skin switch recomputes the Quality rows' colors", function()
    -- red under: MarkLayout clearing the layout key alone (the options keep the old skin's colors)
    local NS, _, _, d = insights({ samples = true })
    local function qualityColor()
        for _, o in ipairs(d.dropdowns.quality._options) do
            if o.value ~= "all" and o.color then return table.concat(o.color, ",") end
        end
    end
    local before = qualityColor()
    assertTrue(before ~= nil, "a colored quality row")
    local real = NS.QualityColor
    NS.QualityColor = function() return 0.25, 0.5, 0.75 end   -- the new skin's q.* tokens
    NS.WindowInsights.MarkLayout()
    NS.Window.Refresh()
    d = NS.WindowInsights.Drawn()
    local after = qualityColor()
    NS.QualityColor = real
    assertEqual(after, "0.25,0.5,0.75")
end)

test("insights tab: a resize lays out again without computing", function()
    local NS, f, _, d = insights({ samples = true })
    local n = d.computes
    local w, x2 = d.cards[1].frame:GetWidth(), d.cards[2].frame.__points[1][4]
    local key = d.pane.layoutKey
    f:SetWidth(1200)
    NS.Window.Refresh()
    d = NS.WindowInsights.Drawn()
    assertEqual(d.computes, n, "the data is not computed again")
    assertTrue(d.pane.layoutKey ~= key, "a fresh layout key")
    assertTrue(d.cards[1].frame:GetWidth() > w, "the cards widen: " .. w .. " -> " .. d.cards[1].frame:GetWidth())
    assertTrue(d.cards[2].frame.__points[1][4] > x2, "the second card moves right")
end)

-- ── the strip, the cards and the empty lines ────────────────────────────────────────────────

test("insights tab: the strip names the period, and follows the retention", function()
    local NS, _, m, d = insights({ samples = true })
    assertTrue(d.strip.info:GetText():find("^Kept for 30 days: ") ~= nil, d.strip.info:GetText())
    assertEqual(d.strip.reset.label and d.strip.reset.label:GetText() or "Reset filters", "Reset filters")
    NS.SchemaRuntime.Set("global.history.retentionDays", 0)
    m.advance(0.1)
    d = NS.WindowInsights.Drawn()
    assertTrue(d.strip.info:GetText():find("^Every kept day: since ") ~= nil, d.strip.info:GetText())
end)

-- No test mode here: its own bus traffic repaints the window and would hide a missing repaint.
test("insights tab: a retention change that deletes nothing repaints the caption on its own", function()
    local NS, _, m, d = insights()
    assertTrue(d.strip.info:GetText():find("^Kept for 30 days: ") ~= nil, d.strip.info:GetText())
    assertEqual(NS.HistoryRetention.CountAll(180), 0, "a longer window deletes nothing")
    NS.SchemaRuntime.Set("global.history.retentionDays", 180)
    m.advance(0.1)
    d = NS.WindowInsights.Drawn()
    assertTrue(d.strip.info:GetText():find("^Kept for 180 days: ") ~= nil, d.strip.info:GetText())
    assertEqual(d.empty:GetText(), "No history yet. Drops your group receives are kept for 180 days.")
end)

test("insights tab: test mode fills the cards from the sample history", function()
    local _, _, _, d = insights({ samples = true })
    assertTrue(tonumber(cardValue(d, 1)) > 0, "Drops seen")
    assertTrue(tonumber(cardValue(d, 2)) > 0, "Upgrades for me")
    assertTrue(tonumber(cardValue(d, 4)) > 0, "Items received")
    assertTrue(cardValue(d, 5):find("%%$") ~= nil, "Ask success as a percentage")
    assertFalse(d.empty:IsShown())
    for _, c in ipairs(d.cards) do assertTrue(c.frame:IsShown()) end
end)

test("insights tab: test mode fills every card and every section, none with its empty line (DW-N4)", function()
    -- red under: samples with no stamps (Offers sent 0), no expired ask, one category, no legacy entry
    local NS, _, _, d = insights({ samples = true })
    local s = d.sections
    for _, key in ipairs({ "outcomes", "verdicts", "tradeStates", "byInstance", "byBoss", "topRate", "generous",
        "gain", "asks", "drops", "byClass", "byQuality", "bySlot", "byCategory" }) do
        assertTrue((s[key] or 0) > 0, key .. " drew rows")
    end
    for i, c in ipairs(d.cards) do
        local v = cardValue(d, i)
        assertTrue(v ~= "-" and v ~= "0", c.caption .. " reads " .. tostring(v))
    end
    assertTrue(s.byCategory >= 7, "every item kind: equipment, the token and the five collectibles")
    local _, empties = NS.Pool.Counts(d.ctx:Pool("empty"))
    assertEqual(empties, 0, "no section says it has nothing")
end)

test("insights tab: with no history the cards hide and one line says how long drops are kept", function()
    local _, _, _, d = insights()
    assertTrue(d.empty:IsShown())
    assertEqual(d.empty:GetText(), "No history yet. Drops your group receives are kept for 30 days.")
    for _, c in ipairs(d.cards) do assertFalse(c.frame:IsShown()) end
end)

test("insights tab: each recompute logs one line under UI", function()
    local NS = T.enableAddon()
    NS.State.debug = true
    NS.ShowWindow()
    NS.Window.SelectTab("insights")
    NS.Window.Refresh()
    local n = 0
    for _, l in ipairs(NS.DebugLog.buffer) do
        if l:find("insights: 0 drops, 0 after filters", 1, true) then n = n + 1 end
    end
    assertEqual(n, 1)
end)

test("insights tab: compact's empty line wraps inside the pane's width", function()
    local _, _, _, d = insights({ mode = "compact" })
    local e = d.empty
    assertTrue(e:IsShown())
    local anchors = {}
    for _, pt in ipairs(e.__points) do anchors[pt[1]] = pt end
    assertTrue(anchors.LEFT ~= nil and anchors.RIGHT ~= nil, "held between both sides")
    assertEqual(anchors.LEFT[2], d.pane.scroll); assertEqual(anchors.RIGHT[2], d.pane.scroll)
    assertTrue(anchors.LEFT[4] > 0 and anchors.RIGHT[4] < 0, "inset from both sides")
    assertTrue(e.__wordWrap == true, "wraps")
    assertEqual(e:GetJustifyH(), "CENTER")
end)

-- ── degraded ────────────────────────────────────────────────────────────────────────────────

test("insights tab: without LibKa0s-Charts-1.0 the bar and the strip draw and one line says why", function()
    local NS, _, _, d = insights({ skip = CHARTS, samples = true })
    assertTrue(NS.Charts == nil and type(NS.ChartsHost) == "function")
    assertTrue(d ~= nil and d.ctx == nil and d.cards == nil)
    assertTrue(d.empty:IsShown())
    assertEqual(d.empty:GetText(), "The charts need LibKa0s-Charts-1.0, which did not load.")
    assertTrue(d.dropdowns.char ~= nil, "the filters still draw")
    assertTrue(d.strip.info:GetText():find("drops in", 1, true) ~= nil)
end)

test("insights tab: without LibKa0s-Widgets-1.0 no dropdown draws and the cards still do", function()
    local skip = {}
    for _, rel in ipairs(T.loadAddon.libFiles) do
        if rel:find("/Widgets") then skip[#skip + 1] = rel end
    end
    local NS, _, _, d = insights({ skip = skip, samples = true })
    assertFalse(NS.HasWidgets())
    assertTrue(next(d.dropdowns) == nil, "no dropdown")
    assertTrue(tonumber(cardValue(d, 1)) > 0)
    assertEqual(NS.State.insightsFilters.char, "all")
end)

-- ── compact ─────────────────────────────────────────────────────────────────────────────────

test("insights tab: compact lays the cards out two to a row and wraps the bar", function()
    local NS, _, _, d = insights({ samples = true, mode = "compact" })
    local x1, x3 = d.cards[1].frame.__points[1][4], d.cards[3].frame.__points[1][4]
    assertEqual(x1, x3, "the third card starts a new row")
    assertTrue(d.cards[2].frame.__points[1][4] > x1)
    assertTrue(d.bar:GetHeight() > 2 * NS.InsightsRows.BAR_ROW_H, "more than two rows of dropdowns")
    NS.SetWindowMode("full")
    d = NS.WindowInsights.Drawn()
    assertTrue(d.cards[4].frame.__points[1][4] > d.cards[3].frame.__points[1][4], "four to a row")
    assertTrue(d.bar:GetHeight() <= NS.InsightsRows.BAR_ROW_H + 6, "one row")
end)
