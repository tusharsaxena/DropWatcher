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

test("chrome: the tabs' compact labels are Group, Mine · n and History; full keeps its own", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.TabText("group", 0, true), "Group")
    assertEqual(CC.TabText("mine", 3, true), "Mine · 3")
    assertEqual(CC.TabText("mine", 0, true), "Mine")
    assertEqual(CC.TabText("history", 9, true), "History")
    assertEqual(CC.TabText("group", 0, false), "Group drops")
    assertEqual(CC.TabText("mine", 2, false), "My drops · 2")
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
    assertEqual(tip[2], "Inspect 3/4 fresh · 1 out of range")
    assertEqual(tip[3], "Last loot 1m ago")
    assertEqual(tip[4], "Situation: Dungeon")
    assertEqual(tip[5], "Pawn: on")
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

test("chrome: the Filters label counts, and its tooltip lists each value with a dot on the active ones", function()
    local CC = T.newAddon().CompactChrome
    assertEqual(CC.FiltersLabel(0), "Filters"); assertEqual(CC.FiltersLabel(2), "Filters · 2")
    local tip = CC.FiltersTip({ quality = "Quality: Rare+", content = "Content: All", char = "Character: Current",
        sort = "Sort: Newest" }, { "content" })
    assertEqual(tip[1], "Filters")
    assertEqual(tip[2], "  Quality: Rare+")
    assertEqual(tip[3], "• Content: All")
    assertEqual(tip[4], "  Character: Current")
    assertEqual(tip[5], "  Sort: Newest")
    assertTrue(tip[6]:find("A dot marks", 1, true) ~= nil)
end)

-- ── the title bar ───────────────────────────────────────────────────────────────────────────

test("chrome: compact shows the short title, TEST beside it, the title and the word centered together", function()
    local NS, f = shown("compact")
    assertEqual(textOf(f.title), "Drop Watcher")
    NS.SetTestMode(true)
    assertTrue(f.testText:IsShown())
    assertEqual(textOf(f.testText.text), "TEST")
    assertEqual(f.testText.text:GetTextColor(), NS.WindowTitleBar.TEST_TONE.r, "the same red")
    local pt = f.title.__points[1]
    assertEqual(pt[1], "CENTER"); assertTrue(pt[4] < 0, "shifted left by half the word")
    NS.SetTestMode(false)
    assertEqual(f.title.__points[1][4], 0, "alone, the title is centered")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.title), NS.BRAND)
    assertEqual(textOf(f.testText.text), "TEST MODE")
    assertEqual(textOf(f.simText.text), "SIMULATION")
end)

test("chrome: a simulation reads SIM in compact, in its cyan", function()
    local NS, f = shown("compact")
    assertEqual(textOf(f.simText.text), "SIM")
    assertTrue(NS.Sim.Start({ scenario = "test" }))
    NS.Window.Refresh()
    assertTrue(f.simText:IsShown())
    assertEqual(f.simText.text:GetTextColor(), NS.WindowTitleBar.SIM_TONE.r)
    assertTrue(f.title.__points[1][4] < 0)
    NS.Sim.Stop()
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
    assertEqual(tip[1], "Encounter"); assertEqual(tip[3], "Queued: Ask to Seta-Realm")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.badge.text), "Encounter · 2 queued")
    assertEqual(f.badge.__points[1][2], f.scanButton, "back beside Scan group")
end)

test("chrome: Scan group becomes an icon button, with its tooltip and its click", function()
    local NS, f = shown("compact")
    local b = f.scanButton
    assertEqual(b:GetWidth(), NS.Constants.WINDOW.ICON + 4)
    assertFalse(b.label:IsShown())
    assertEqual(b.art.__points[1][1], "CENTER")
    assertEqual(NS.Window.TooltipOf(b)[1], "Scan group")
    local scanned = 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    b:__fire("OnClick")
    assertEqual(scanned, 1)
    NS.SetWindowMode("full")
    assertEqual(b:GetWidth(), 96); assertTrue(b.label:IsShown()); assertEqual(b.art.__points[1][1], "LEFT")
end)

-- ── the tabs ────────────────────────────────────────────────────────────────────────────────

test("chrome: the tabs keep three at a reduced width, short labels, full names in their tooltips", function()
    local NS, f = shown("compact")
    local CC = NS.CompactChrome
    assertEqual(textOf(f.tabs.group.label), "Group")
    assertEqual(textOf(f.tabs.mine.label), "Mine")
    assertEqual(textOf(f.tabs.history.label), "History")
    assertEqual(f.tabs.mine:GetWidth(), CC.TAB_W)
    assertEqual(f.tabs.history.__points[1][4], 2 * (CC.TAB_W + NS.Constants.WINDOW.TAB_GAP))
    assertEqual(NS.Window.TooltipOf(f.tabs.group)[1], "Group drops")
    assertEqual(NS.Window.TooltipOf(f.tabs.mine)[1], "My drops")
    NS.SetWindowMode("full")
    assertEqual(textOf(f.tabs.group.label), "Group drops")
    assertEqual(f.tabs.mine:GetWidth(), NS.Constants.WINDOW.TAB_W)
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
    c.content.onSelect("all")
    assertEqual(FB.State("group").content, "all")
    assertEqual(textOf(p.filters.label), "Filters · 1")
    c.char:ToggleSelected("all")
    c.char.onMultiSelect(c.char._selected)
    assertEqual(next(FB.State("group").char), nil, "Character: All")
    assertEqual(textOf(p.filters.label), "Filters · 2")
    local tip = NS.Window.TooltipOf(p.filters)
    assertEqual(tip[1], "Filters")
    assertEqual(tip[3], "• Content: All")
    assertEqual(tip[4], "• Character: All")
    assertEqual(tip[5], "  Sort: Newest")
    local _, sort = NS.WindowFooter.Parts()
    sort.onSelect("ilvl")
    assertEqual(FB.State("group").sort, "ilvl", "Sort in the panel sorts the tab")
    assertEqual(textOf(p.filters.label), "Filters · 2", "Sort is not counted")
    p.filters:__fire("OnClick")
    assertFalse(p.panel:IsShown(), "a second click closes it")
    NS.Window.SelectTab("mine")
    assertEqual(textOf(p.filters.label), "Filters", "My drops starts from its own state")
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

test("chrome: the full layout takes every control back to its place on the bar and in the footer", function()
    local NS, f = shown("compact")
    NS.SetWindowMode("full")
    local c, p = NS.WindowFilterBar.Controls(), NS.CompactChrome.Parts()
    assertFalse(p.filters:IsShown())
    assertEqual(c.view:GetWidth(), 132)
    assertTrue(c.quality:GetParent() == f.filterHost)
    assertEqual(c.quality.__points[1][2], c.view)
    assertEqual(c.char.__points[1][2], c.content)
    assertEqual(c.char:GetWidth(), 168)
    assertEqual(#c.search.__points, 1); assertEqual(c.search.__points[1][1], "RIGHT")
    assertEqual(textOf(c.search.hint), "Filter looter or item…")
    assertTrue(c.search:GetWidth() > 0)
    local _, sort = NS.WindowFooter.Parts()
    assertTrue(sort:GetParent() == f.footerHost)
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

test("chrome: the footer is one line, inspect and situation, the rest in its tooltip, ticker included", function()
    local NS = shown("compact")
    local segs = NS.WindowFooter.Parts()
    assertEqual(textOf(segs.inspect.text), "No group · Solo (not tracked)")
    for _, key in ipairs({ "loot", "situation", "pawn" }) do assertFalse(segs[key]:IsShown(), key) end
    local tip = NS.Window.TooltipOf(segs.inspect)
    assertEqual(tip[1], "Status"); assertEqual(tip[2], "Inspect: no group"); assertEqual(tip[3], "No loot seen yet")
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
