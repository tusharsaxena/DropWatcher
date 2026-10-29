-- tests/test_compact_chrome.lua — the window's chrome in the compact layout (compact spec §4, DW-C4):
-- the short title with TEST and SIM, the badge's lock and count, the icon Scan group, the short tabs,
-- the one-row filter bar with View, the search box and the Filters panel (the full bar's own
-- Quality, Content and Character dropdowns and the footer's Sort), the shortened strip and the
-- one-line footer. The pure labels first, then the chrome drawn headless under the mock, and the
-- full layout taking every control back.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function shown(mode)
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    if mode then NS.SetWindowMode(mode) end
    return NS, NS.Window.Frame(), m
end

local function textOf(region) return region and region:GetText() end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

test("chrome: the tabs' labels are Drops and History in both layouts (feedback-5 spec §3)", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.TabText("group", true), "Drops")
    assertEqual(CC.TabText("history", true), "History")
    assertEqual(CC.TabText("group", false), "Drops")
    assertEqual(CC.TabText("history", false), "History")
end)

test("chrome: TEST MODE and SIMULATION shorten to TEST and SIM", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.ModeWord("test", true), "TEST"); assertEqual(CC.ModeWord("test", false), "TEST MODE")
    assertEqual(CC.ModeWord("sim", true), "SIM"); assertEqual(CC.ModeWord("sim", false), "SIMULATION")
end)

test("chrome: the compact badge shows the queued count beside its lock, or nothing", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.BadgeShort(2), "2"); assertEqual(CC.BadgeShort(0), ""); assertEqual(CC.BadgeShort(nil), "")
end)

test("chrome: the footer's one line is inspect freshness and the situation", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.FooterLine({ members = 4, good = 4, situation = "mythicPlus" }), "Inspect 4/4 · Mythic+")
    assertEqual(CC.FooterLine({ members = 0, situation = "solo" }), "No group · Solo")
    assertEqual(CC.FooterLine({ members = 2, good = 1, situation = "raid", sim = { members = 2 } }),
        "Inspect 1/2 · Sim: Raid")
    assertEqual(CC.FooterLine({ members = 3, good = 0, situation = "pvp", tracking = false }),
        "Inspect 0/3 · PvP (not tracked)")
    assertEqual(CC.FooterLine(nil), "No group · ?")
end)

test("chrome: the footer's tooltip carries every full segment", function()
    local NS = T.newAddon()
    local tip = NS.CompactChrome.FooterTip(NS.WindowFooter.Compose({ members = 4, good = 3, outOfRange = 1,
        lastLootAgo = 75, situation = "dungeon", tracking = true, pawn = "on" }))
    assertEqual(tip[1], "Status")
    assertEqual(T.tipPlain(tip[2]), "• Inspect 3/4 fresh · 1 out of range", "a row per segment (feedback-21)")
    assertEqual(T.tipPlain(tip[3]), "• Last loot 1m ago")
    assertEqual(T.tipPlain(tip[4]), "• Situation: Dungeon")
    assertEqual(T.tipPlain(tip[5]), "• Pawn: on")
    assertEqual(#tip, 6)
end)

local HONORS_ALL = { quality = true, content = true, char = true }

local function defaults(over)
    local d = { quality = "fixed", qualityDefault = "fixed", content = "instance", current = "Me-Realm" }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

test("chrome: the Filters count is Quality, Content and Character off their default, on a tab that honors them", function()
    local CC = T.newAddon().CompactChrome
    local st = { content = "instance", char = { ["Me-Realm"] = true }, sort = "ilvl" }
    assertEqual(CC.CountActive(st, HONORS_ALL, defaults()), 0, "Sort is not counted")
    assertEqual(CC.CountActive({ content = "instance", char = { current = true } }, HONORS_ALL, defaults()), 0,
        "the Current sentinel is the default too")
    st = { content = "all", char = {} }
    assertEqual(table.concat(CC.ActiveKeys(st, HONORS_ALL, defaults({ quality = "dynamicSlot" })), ","),
        "quality,content,char")
    assertEqual(CC.CountActive(st, { content = true, char = true }, defaults({ quality = "dynamicSlot" })), 2,
        "a tab that does not honor Quality does not count it")
    assertEqual(CC.CountActive(st, HONORS_ALL, defaults({ content = "all" })), 1, "the seeded Content is the default")
    assertFalse(CC.IsActive("sort", st, HONORS_ALL, defaults()))
    assertFalse(CC.IsActive("content", nil, HONORS_ALL, defaults()))
end)

test("chrome: the Filters label counts, and its tooltip lists each value, the active ones in yellow", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.FiltersLabel(0), "Filters"); assertEqual(CC.FiltersLabel(2), "Filters · 2")
    local tip = CC.FiltersTip({ quality = "Quality: Rare+", content = "Content: All", char = "Character: Current",
        sort = "Sort: Newest" }, { "content" })
    assertEqual(tip[1], "Filters")
    -- a row per control, its name once (feedback-21); the one off its default in yellow
    assertEqual(T.tipPlain(tip[2]), "• Quality: Rare+")
    assertEqual(T.tipPlain(tip[3]), "• Content: All")
    assertTrue(tip[3]:find("|cfffff56bAll|r", 1, true) ~= nil, "Content is off its default: yellow")
    assertTrue(tip[2]:find("|cfffff56b", 1, true) == nil, "Quality is at its default: plain")
    assertEqual(T.tipPlain(tip[4]), "• Character: Current")
    assertEqual(T.tipPlain(tip[5]), "• Sort: Newest")
    assertEqual(T.tipPlain(tip[6]), "Yellow: off its default.")
end)

-- ── the title bar ───────────────────────────────────────────────────────────────────────────

test("chrome: compact shows the short title; in test mode the strip marks it, so the title stays centered alone", function()
    local NS, f = shown("compact")
    assertEqual(textOf(f.title), "Drop Watcher")
    NS.SetTestMode(true)
    -- red under: PaintModeText showing TEST beside the title while the strip is on screen
    assertFalse(f.testText:IsShown(), "the strip is the marker (DW-10)")
    assertTrue(f.banner:IsShown())
    assertEqual(textOf(f.testText.text), "TEST")
    assertEqual(f.testText.text:GetTextColor(), 1, "the same red (sem.modeTest)")
    local pt = f.title.__points[1]
    assertEqual(pt[1], "CENTER"); assertEqual(pt[4], 0, "no word: the title alone, centered")
    NS.SetTestMode(false)
    assertEqual(f.title.__points[1][4], 0, "alone, the title is centered")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.title), NS.BRAND)
    assertEqual(textOf(f.testText.text), "TEST MODE")
    assertEqual(textOf(f.simText.text), "SIMULATION")
end)

test("chrome: compact and minimized in test mode, TEST shows beside the title and the two center together", function()
    local NS, f = shown("compact")
    NS.SetTestMode(true)
    NS.Window.SetMinimized(true)
    assertTrue(f.testText:IsShown(), "minimized: the strip is gone with the body, the word comes back")
    assertEqual(textOf(f.testText.text), "TEST")
    local pt = f.title.__points[1]
    assertEqual(pt[1], "CENTER"); assertTrue(pt[4] < 0, "shifted left by half the word")
    NS.Window.SetMinimized(false)
    assertFalse(f.testText:IsShown())
    assertEqual(f.title.__points[1][4], 0)
    NS.SetTestMode(false)
end)

test("chrome: a simulation reads SIM in compact, in its cyan; expanded, the sim strip marks it with the short wrapped line", function()
    local NS, f = shown("compact")
    assertEqual(textOf(f.simText.text), "SIM")
    assertEqual(f.simText.text:GetTextColor(), 0.35, "the strip's cyan, opaque (strip.sim's rgb)")
    assertTrue(T.simBare(NS):Start({ scenario = "test" }))
    NS.Window.Refresh()
    -- red under: no sim strip, the SIM word beside the title as the marker
    assertFalse(f.simText:IsShown(), "the sim strip is the marker (DW-10)")
    assertTrue(f.simBanner:IsShown())
    assertFalse(f.banner:IsShown())
    assertEqual(textOf(f.simBanner.text), "SIM: a made-up session. Nothing is sent; /dw sim stop ends it.")
    assertTrue(f.simBanner.text:GetWordWrap(), "compact: the short words may take two lines")
    assertEqual(f.title.__points[1][4], 0, "the title alone, centered")
    assertTrue(NS.CompactChrome.ModeStrip(f) == f.simBanner)
    NS.SetWindowMode("full")
    assertEqual(textOf(f.simBanner.text),
        "SIMULATION: a made-up group session through the real engine. Nothing is sent; /dw sim stop ends it.")
    assertFalse(f.simBanner.text:GetWordWrap())
    NS.Sim:Stop()
    NS.Window.Refresh()
    assertFalse(f.simBanner:IsShown(), "gone with the simulation")
    assertTrue(NS.CompactChrome.ModeStrip(f) == f.banner, "no mode: the test strip (hidden)")
end)

test("chrome: the panes reserve the sim strip's height while a simulation runs", function()
    local NS, f = shown()
    local K = NS.Constants.WINDOW
    local base = -(K.TAB_H + 4 + K.FILTER_H)
    assertEqual(f.panes.group.__points[1][5], base, "no mode: no reserve")
    assertTrue(T.simBare(NS):Start({ scenario = "test" }))
    NS.Window.Refresh()
    -- red under: layoutPanes reserving only in test mode
    assertEqual(f.panes.group.__points[1][5], base - K.BANNER_H)
    assertEqual(f.simBanner:GetHeight(), K.BANNER_H - 4, "CC.Paint sizes the strip in force")
    NS.Sim:Stop()
    NS.Window.Refresh()
    assertEqual(f.panes.group.__points[1][5], base)
end)

test("chrome: the badge collapses to its lock and the queued count at the left, its tooltip unchanged", function()
    local NS, f, m = shown("compact")
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, "encounter", false)
    m.advance(0)
    assertTrue(f.badge:IsShown())
    assertEqual(textOf(f.badge.text), "", "the lock alone")
    assertEqual(f.badge.__points[1][1], "LEFT"); assertEqual(f.badge.__points[1][2], f.titleBar)
    NS.Asks.Queued = function() return { { kind = "ask", target = "Seta-Realm" }, { kind = "offer", target = "Bo-Realm" } } end
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, 1, "queued", "ask", "Seta-Realm")
    assertEqual(textOf(f.badge.text), "2")
    local tip = NS.Window.TooltipOf(f.badge)
    assertEqual(tip[1], "Encounter"); assertEqual(T.tipPlain(tip[5]), "• Queued: Ask to Seta-Realm")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.badge.text), "Encounter · 2 queued")
    assertEqual(f.badge.__points[1][2], f.modeButton, "back beside the layout toggle (Scan group is the strip's)")
end)

test("chrome: the title bar has no Scan group in either layout; compact's is the Drops strip's icon", function()
    local NS, f = shown("compact")
    -- red under: compact's title bar carrying a second Scan group beside the strip's (feedback-16)
    assertTrue(f.scanButton == nil, "no Scan group in the title bar")
    local b = NS.WindowGroup.Drawn().pane.summary.scan
    assertTrue(b:IsShown(), "the strip's, as its icon")
    assertEqual(NS.Window.TooltipOf(b)[1], "Scan group")
    local scanned = 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    b:__fire("OnClick")
    assertEqual(scanned, 1)
    NS.SetWindowMode("full")
    assertTrue(f.scanButton == nil)
end)

-- ── the tabs ────────────────────────────────────────────────────────────────────────────────

test("chrome: the two tabs keep a reduced width, their names in their tooltips", function()
    local NS, f = shown("compact")
    local CC = NS.CompactChrome
    assertEqual(textOf(f.tabs.group.label), "Drops")
    assertEqual(textOf(f.tabs.history.label), "History")
    assertEqual(f.tabs.group:GetWidth(), CC.TAB_W)
    assertEqual(f.tabs.history.__points[1][4], CC.TAB_W + NS.Constants.WINDOW.TAB_GAP)
    assertEqual(NS.Window.TooltipOf(f.tabs.group)[1], "Drops")
    assertEqual(NS.Window.TooltipOf(f.tabs.history)[1], "History")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.tabs.group.label), "Drops")
    assertEqual(f.tabs.group:GetWidth(), NS.Constants.WINDOW.TAB_W)
end)

-- ── the filter bar ──────────────────────────────────────────────────────────────────────────

test("chrome: the bar is one row: View, the search box (Filter…) and Filters on the right", function()
    local NS, f = shown("compact")
    local c, p = NS.WindowFilterBar.Controls(), NS.CompactChrome.Parts()
    assertTrue(p.filters:IsShown())
    assertEqual(textOf(p.filters.label), "Filters")
    assertEqual(p.filters.__points[1][2], f.filterHost)
    assertEqual(c.view:GetWidth(), NS.CompactChrome.VIEW_W)
    assertTrue(c.search:IsShown())
    assertEqual(textOf(c.search.hint), "Filter…")
    local pts = c.search.__points
    assertEqual(pts[1][2], c.view); assertEqual(pts[2][2], p.filters)
    for _, key in ipairs({ "quality", "content", "char" }) do
        assertTrue(c[key]:GetParent() == p.panel, key .. " moved into the Filters panel")
    end
    local _, sort = NS.WindowFooter.Parts()
    assertTrue(sort:GetParent() == p.panel, "Sort moved into it too")
    assertFalse(p.panel:IsShown(), "closed until clicked")
end)

test("chrome: Filters opens the panel of the full bar's own dropdowns, and a pick there filters as it does", function()
    local NS, f = shown("compact")
    local FB, c, p = NS.WindowFilterBar, NS.WindowFilterBar.Controls(), NS.CompactChrome.Parts()
    p.filters:__fire("OnClick")
    assertTrue(p.panel:IsShown())
    assertTrue(c.char.multi, "the Character dropdown is still multi-select")
    c.content.onSelect("instance")   -- Drops has no All (feedback-15 spec §1)
    assertEqual(FB.State("group").content, "instance")
    assertEqual(textOf(p.filters.label), "Filters · 1")
    c.char:ToggleSelected("all")
    c.char.onMultiSelect(c.char._selected)
    assertEqual(next(FB.State("group").char), nil, "Character: All")
    assertEqual(textOf(p.filters.label), "Filters · 2")
    local tip = NS.Window.TooltipOf(p.filters)
    assertEqual(tip[1], "Filters")
    assertEqual(T.tipPlain(tip[3]), "• Content: This instance")
    assertTrue(tip[3]:find("|cfffff56b", 1, true) ~= nil, "off its default: yellow")
    assertEqual(T.tipPlain(tip[4]), "• Character: All")
    assertEqual(T.tipPlain(tip[5]), "• Sort: Newest")
    local _, sort = NS.WindowFooter.Parts()
    sort.onSelect("ilvl")
    assertEqual(FB.State("group").sort, "ilvl", "Sort in the panel sorts the tab")
    assertEqual(textOf(p.filters.label), "Filters · 2", "Sort is not counted")
    p.filters:__fire("OnClick")
    assertFalse(p.panel:IsShown(), "a second click closes it")
    NS.Window.SelectTab("history")
    assertEqual(textOf(p.filters.label), "Filters", "History starts from its own defaults, none counted (feedback-13 spec §0)")
    assertTrue(f:IsShown())
end)

test("chrome: the panel closes when the window hides, minimizes or goes back to full", function()
    local NS, f = shown("compact")
    local p = NS.CompactChrome.Parts()
    p.filters:__fire("OnClick")
    NS.Window.SetMinimized(true)
    assertFalse(p.panel:IsShown(), "minimized")
    NS.Window.SetMinimized(false)
    p.filters:__fire("OnClick")
    f:GetScript("OnHide")(f)
    assertFalse(p.panel:IsShown(), "hidden")
    p.filters:__fire("OnClick")
    NS.SetWindowMode("full")
    assertFalse(p.panel:IsShown(), "full")
end)

test("chrome: the full layout takes every control back to its place on the bar and the tab's strip", function()
    local NS, f = shown("compact")
    NS.SetWindowMode("full")
    local c, p = NS.WindowFilterBar.Controls(), NS.CompactChrome.Parts()
    assertFalse(p.filters:IsShown())
    assertEqual(c.view:GetWidth(), 132)
    assertTrue(c.quality:GetParent() == f.filterHost)
    assertEqual(c.quality.__points[1][2], c.view)
    assertEqual(c.char.__points[1][2], c.content)
    assertEqual(c.char:GetWidth(), 168)
    assertEqual(#c.search.__points, 2, "both edges anchored (feedback-4 spec §4)")
    assertEqual(c.search.__points[1][1], "LEFT"); assertEqual(c.search.__points[1][2], c.char)
    assertEqual(c.search.__points[1][4], 8, "the gap between the dropdowns")
    assertEqual(c.search.__points[2][1], "RIGHT")
    assertEqual(textOf(c.search.hint), "Filter looter or item…")
    assertTrue(c.search:GetWidth() > 0)
    local _, sort = NS.WindowFooter.Parts()
    assertTrue(sort:GetParent() == f.panes.group.summary, "Sort on Drops' strip (feedback-10 spec §3)")
    assertEqual(sort.__points[1][1], "RIGHT"); assertEqual(sort:GetWidth(), 150)
end)

-- ── the strip and the footer ────────────────────────────────────────────────────────────────

test("chrome: the test-mode strip keeps its tooltip with shorter words that may wrap", function()
    local NS, f = shown("compact")
    NS.SetTestMode(true)
    assertTrue(f.banner:IsShown())
    assertEqual(textOf(f.banner.text), "TEST: sample drops in every state. Nothing is whispered; combat ends it.")
    assertEqual(NS.Window.TooltipOf(f.banner)[1], "Test mode")
    local h = NS.CompactChrome.BannerH()
    assertTrue(h >= NS.Constants.WINDOW.BANNER_H)
    assertEqual(f.banner:GetHeight(), h - 4)
    NS.SetWindowMode("full")
    assertEqual(textOf(f.banner.text), "TEST MODE: sample drops of real items in every state. Nothing is whispered. Combat ends it.")
    assertEqual(NS.CompactChrome.BannerH(), NS.Constants.WINDOW.BANNER_H)
    assertEqual(f.banner:GetHeight(), NS.Constants.WINDOW.BANNER_H - 4)
end)

-- Retail bounds GetStringWidth by the width the strip's anchors give its words (the window's less
-- the insets and the art), so only the unbounded width tells a wrap.
test("chrome: the compact strip takes a second line exactly when its words wrap at the window's width", function()
    local NS, f, m = shown("compact")
    local K, CC = NS.Constants.WINDOW, NS.CompactChrome
    NS.SetTestMode(true)
    m.textCharWidth = 5   -- the compact words, 72 characters: 360 wide on one line
    local function at(width)
        f:SetWidth(width)
        f.banner.text.__boundWidth = width - 2 * K.INSET - 30
        NS.Window.Refresh()
        return CC.BannerH()
    end
    assertEqual(at(380), K.BANNER_H + CC.WRAP_H, "380 wide: the words wrap")
    assertEqual(f.banner:GetHeight(), K.BANNER_H + CC.WRAP_H - 4)
    assertEqual(at(520), K.BANNER_H, "520 wide: one line")
    assertEqual(f.banner:GetHeight(), K.BANNER_H - 4)
end)

test("chrome: the compact sim strip takes a second line when its words wrap at 380 px", function()
    local NS, f, m = shown("compact")
    local K, CC = NS.Constants.WINDOW, NS.CompactChrome
    assertTrue(T.simBare(NS):Start({ scenario = "test" }))
    m.textCharWidth = 6   -- the compact sim words, 63 characters: 378 wide on one line
    local function at(width)
        f:SetWidth(width)
        f.simBanner.text.__boundWidth = width - 2 * K.INSET - 30
        NS.Window.Refresh()
        return CC.BannerH()
    end
    -- red under: BannerH measuring f.banner, whose words are not the ones on screen
    assertEqual(at(380), K.BANNER_H + CC.WRAP_H, "380 wide: the words wrap")
    assertEqual(f.simBanner:GetHeight(), K.BANNER_H + CC.WRAP_H - 4)
    assertEqual(f.panes.group.__points[1][5], -(K.TAB_H + 4 + K.FILTER_H + K.BANNER_H + CC.WRAP_H), "the panes move down")
    assertEqual(at(520), K.BANNER_H, "520 wide: one line")
    NS.Sim:Stop()
end)

test("chrome: the footer is one line, inspect and situation, the rest in its tooltip, ticker included", function()
    local NS = shown("compact")
    local segs = NS.WindowFooter.Parts()
    assertEqual(textOf(segs.inspect.text), "No group · Solo (not tracked)")
    for _, key in ipairs({ "loot", "situation", "pawn" }) do assertFalse(segs[key]:IsShown(), key) end
    local tip = NS.Window.TooltipOf(segs.inspect)
    assertEqual(tip[1], "Status"); assertEqual(T.tipPlain(tip[2]), "• Inspect: no group")
    assertEqual(T.tipPlain(tip[3]), "• No loot seen yet")
    NS.WindowFooter.Refresh()   -- the ticker's own repaint stays compact
    assertEqual(textOf(segs.inspect.text), "No group · Solo (not tracked)")
    NS.SetWindowMode("full")
    assertEqual(textOf(segs.inspect.text), "Inspect: no group")
    for _, key in ipairs({ "loot", "situation", "pawn" }) do assertTrue(segs[key]:IsShown(), key) end
end)

test("chrome: switching the chrome keeps every tab's filter state and builds no second window", function()
    local NS, f = shown()
    local FB = NS.WindowFilterBar
    FB.Set("group", "content", "session")
    FB.Set("group", "search", "crown")
    NS.ToggleWindowMode()
    assertEqual(FB.State("group").content, "session")
    assertEqual(NS.WindowFilterBar.Controls().search:GetText(), "crown")
    assertTrue(NS.Window.Frame() == f)
    NS.ToggleWindowMode()
    assertEqual(FB.State("group").search, "crown")
end)
