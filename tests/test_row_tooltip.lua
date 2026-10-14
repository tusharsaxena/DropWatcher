-- tests/test_row_tooltip.lua — the one placement of a table row's tooltips (feedback-3 spec §2,
-- DW-B2; modules/RowTooltip.lua): the tooltip's BOTTOMLEFT at the row's top, just outside the right
-- edge of the frame the row sits in (Ka0s Loot History's ANCHOR_RIGHT on a full-width row), else its
-- BOTTOMRIGHT outside the left edge; the docked Offer panel counts as part of the window (DW-A9).
-- Then every row tooltip on the two tabs and the Offer panel, built headless, placed by it.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- A plain frame for RowTooltip.Place: its edges, width, scale and parent, and the points it is given.
local function box(t)
    local f = { pts = {}, tipHost = t.tipHost, dock = t.dock, tipDocked = t.tipDocked, tipRow = t.tipRow }
    if t.shown ~= nil then function f.IsShown() return t.shown end end
    function f.GetLeft() return t.left end
    function f.GetRight() return t.right end
    function f.GetTop() return t.top end
    function f.GetWidth() return t.width end
    function f.GetEffectiveScale() return t.scale or 1 end
    function f.GetParent() return t.parent end
    function f.ClearAllPoints(self) self.pts = {} end
    function f.SetPoint(self, ...) self.pts[#self.pts + 1] = { ... } end
    return f
end

local function placed(NS, m, screen, row, tip)
    m.UIParent.GetWidth = function() return screen end
    return NS.RowTooltip.Place(tip, row)
end

test("row tooltip: it rises from the row's top right, just outside the window", function()
    local NS, _, m = T.newAddon()
    local gap = NS.Constants.WINDOW.TIP_GAP
    local win = box({ left = 400, right = 1400, top = 900 })
    local row = box({ top = 700, parent = box({ top = 720, parent = win }) })
    local tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, row, tip), "right")
    assertEqual(#tip.pts, 1)
    local p = tip.pts[1]
    assertEqual(p[1] .. ">" .. p[3], "BOTTOMLEFT>TOPRIGHT")
    assertTrue(p[2] == win, "beside the window, not the row")
    assertEqual(p[4], gap); assertEqual(p[5], -200)
end)

test("row tooltip: with no room on the right it rises from the row's top left, outside the window", function()
    local NS, _, m = T.newAddon()
    local gap = NS.Constants.WINDOW.TIP_GAP
    local win = box({ left = 600, right = 1700, top = 900 })
    local row = box({ top = 850, parent = win })
    local tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, row, tip), "left")
    local p = tip.pts[1]
    assertEqual(p[1] .. ">" .. p[3], "BOTTOMRIGHT>TOPLEFT")
    assertTrue(p[2] == win)
    assertEqual(p[4], -gap); assertEqual(p[5], -50)
end)

test("row tooltip: the room is measured at the UI scale (a scaled-down window, a full-size tooltip)", function()
    local NS, _, m = T.newAddon()
    -- 2000 window units at 0.64 is 1280 px: 300 px of tooltip fit in 1920.
    local win = box({ left = 500, right = 2000, top = 1200, scale = 0.64 })
    local row = box({ top = 1000, scale = 0.64, parent = win })
    local tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, row, tip), "right")
    assertEqual(tip.pts[1][5], -128, "the row's top in the tooltip's own units")
    -- The tooltip at 2.2: 300 units are 660 px, and 1280 + 660 is past 1920.
    local big = box({ width = 300, scale = 2.2 })
    assertEqual(placed(NS, m, 1920, row, big), "left")
end)

test("row tooltip: unknown geometry places nothing; a marked panel is the frame it goes beside", function()
    local NS, _, m = T.newAddon()
    local tip = box({ width = 300 })
    assertTrue(placed(NS, m, 1920, box({ top = 10 }), tip) == nil)
    assertEqual(#tip.pts, 0, "left to the caller's fallback")
    local win = box({ left = 100, right = 900, top = 900 })
    local panel = box({ left = 904, right = 1344, top = 900, parent = win, tipHost = true })
    local row = box({ top = 800, parent = panel })
    assertEqual(placed(NS, m, 1920, row, tip), "right")
    assertTrue(tip.pts[1][2] == panel, "the Offer panel's own edge, not the window's under it")
end)

-- M10 review (FB2-10): with the Offer panel docked beside the window, a tooltip opens beside the
-- pair, never over the panel (a window row) or over the window (a panel row).
local function dockedPair(side, shown)
    local win = box({ left = 500, right = 1300, top = 900 })
    local panel = side == "right"
        and box({ left = 1304, right = 1744, top = 900, parent = win, tipHost = true, dock = side, shown = shown })
        or box({ left = 56, right = 496, top = 900, parent = win, tipHost = true, dock = side, shown = shown })
    win.tipDocked = panel
    return win, panel
end

test("row tooltip: a window row's tooltip goes beside the docked Offer panel, not over it", function()
    local NS, _, m = T.newAddon()
    local gap = NS.Constants.WINDOW.TIP_GAP
    local win, panel = dockedPair("right", true)
    local row = box({ top = 700, parent = win })
    local tip = box({ width = 150 })
    -- red under: the window's own right edge (1300), under the panel
    assertEqual(placed(NS, m, 1920, row, tip), "right")
    assertTrue(tip.pts[1][2] == panel, "beyond the panel's right edge")
    assertEqual(tip.pts[1][4], gap); assertEqual(tip.pts[1][5], -200)
    -- no room right of the panel: the window's other side
    tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, row, tip), "left")
    assertTrue(tip.pts[1][2] == win)
    -- a panel docked on the left: the tooltip's left side starts at the panel
    local win2, left = dockedPair("left", true)
    tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1700, box({ top = 700, parent = win2 }), tip), "right")
    assertTrue(tip.pts[1][2] == win2)
    assertEqual(placed(NS, m, 1310, box({ top = 700, parent = win2 }), tip), "left")
    assertTrue(tip.pts[1][2] == left, "beyond the panel's left edge")
end)

test("row tooltip: a docked panel's row never opens over the window; a hidden or floating panel is ignored", function()
    local NS, _, m = T.newAddon()
    local win, panel = dockedPair("right", true)
    local tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, box({ top = 800, parent = panel }), tip), "left")
    assertTrue(tip.pts[1][2] == win, "beyond the window's left edge, not over it")
    win = dockedPair("right", false)
    assertEqual(placed(NS, m, 1920, box({ top = 800, parent = win }), tip), "right")
    assertTrue(tip.pts[1][2] == win, "a hidden panel takes no room")
    win, panel = dockedPair("right", true)
    panel.dock = "float"
    assertEqual(placed(NS, m, 1920, box({ top = 800, parent = win }), tip), "right")
    assertTrue(tip.pts[1][2] == win, "a floating panel sits inside the window")
end)


test("row tooltip: a cell, a button or an icon in a marked row opens at the row's top, not its own", function()
    local NS, _, m = T.newAddon()
    local win = box({ left = 400, right = 1400, top = 900 })
    local row = box({ top = 700, parent = win, tipRow = true })
    local cell = box({ top = 690, parent = row })
    local icon = box({ top = 685, parent = cell })
    assertTrue(NS.RowTooltip.RowOf(icon) == row)
    assertTrue(NS.RowTooltip.RowOf(win) == win, "no marked row: the hovered frame itself")
    local tip = box({ width = 300 })
    assertEqual(placed(NS, m, 1920, icon, tip), "right")
    assertEqual(tip.pts[1][5], -200, "the row's top, not the icon's")
    assertTrue(tip.pts[1][2] == win)
end)

test("row tooltip: unknown geometry falls back to the hovered frame's top right", function()
    local NS = T.newAddon()
    local tip = box({ width = 300 })
    local owner = box({ top = 10 })
    assertEqual(NS.RowTooltip.PlaceOrFallback(tip, owner), "owner")
    assertEqual(#tip.pts, 1)
    assertEqual(tip.pts[1][1] .. ">" .. tip.pts[1][3], "BOTTOMLEFT>TOPRIGHT")
    assertTrue(tip.pts[1][2] == owner)
end)

-- ── every row tooltip on the two tabs and the Offer panel ───────────────────────────────────

-- The window at 200..1200, its top at 800, on a 1920-wide screen; a 320-wide tooltip.
local function placeWindow(NS, m, screen)
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 1200 end
    win.GetTop = function() return 800 end
    m.UIParent.GetWidth = function() return screen or 1920 end
    m.GameTooltip.GetWidth = function() return 320 end
    return win
end

-- Hover `w` inside `row` (its top at 600) and answer where the tooltip went.
local function hover(m, row, w)
    row.GetTop = function() return 600 end
    m.GameTooltip.__points = {}
    w:__fire("OnEnter")
    local point, rel, relPoint, x, y = m.GameTooltip:GetPoint(1)
    return tostring(point) .. ">" .. tostring(relPoint), rel, x, y
end

local function expectRowTop(NS, m, win, row, w, label)
    local pts, rel, x, y = hover(m, row, w)
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", label)
    assertEqual(pts, "BOTTOMLEFT>TOPRIGHT", label .. ": at the row's top right")
    assertTrue(rel == win, label .. ": just outside the window")
    assertEqual(x, NS.Constants.WINDOW.TIP_GAP, label)
    assertEqual(y, -200, label .. ": level with the row's top")
end

local function testWindow()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, m
end

test("row tooltip: Drops, every cell, Ask and the header open at the row's top right", function()
    local NS, m = testWindow()
    local win = placeWindow(NS, m)
    local drawn = NS.WindowGroup.Drawn()
    local row = drawn.rows[1]
    assertTrue(row ~= nil and row.tipRow == true, "a drop row, marked")
    for key, cell in pairs(row.cells) do
        if key ~= "actions" and cell.tooltip then expectRowTop(NS, m, win, row, cell, "group " .. key) end
    end
    local a = row.cells.actions
    a.ask.tipLines = { "Ask", "why" }
    expectRowTop(NS, m, win, row, a.ask, "group ask")
    local h = drawn.headers[1]
    assertTrue(h.tipRow == true)
    expectRowTop(NS, m, win, h, h, "group header")
end)

test("row tooltip: with no room on the right a row tooltip rises from the row's top left, outside the window", function()
    local NS, m = testWindow()
    local win = placeWindow(NS, m, 1400)
    local row = NS.WindowGroup.Drawn().rows[1]
    local pts, rel, x, y = hover(m, row, row.cells.trade)
    assertEqual(pts, "BOTTOMRIGHT>TOPLEFT")
    assertTrue(rel == win)
    assertEqual(x, -NS.Constants.WINDOW.TIP_GAP); assertEqual(y, -200)
end)

test("row tooltip: your own drops' rows on Drops and their Offer open at the row's top right", function()
    local NS, m = testWindow()
    NS.WindowFilterBar.Set("group", "view", {})
    local win = placeWindow(NS, m)
    local row
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do
        if r.drop.isMine and r.cells.actions.ask:IsShown() then row = r; break end
    end
    assertTrue(row ~= nil and row.tipRow == true, "a row of yours, marked")
    for key, cell in pairs(row.cells) do
        if key ~= "actions" and cell.tooltip then expectRowTop(NS, m, win, row, cell, "own " .. key) end
    end
    local b = row.cells.actions.ask
    assertTrue(b.offer, "its Offer")
    expectRowTop(NS, m, win, row, b, "own offer")
end)

test("row tooltip: History rows and headers open at the row's top right", function()
    local NS, m = testWindow()
    NS.Window.SelectTab("history")
    local win = placeWindow(NS, m)
    local drawn = NS.WindowHistory.Drawn()
    local row = drawn.rows[1]
    assertTrue(row ~= nil and row.tipRow == true, "a History row, marked")
    for key, cell in pairs(row.cells) do
        if cell.tooltip then expectRowTop(NS, m, win, row, cell, "history " .. key) end
    end
    local h = drawn.headers[1]
    assertTrue(h ~= nil and h.tipRow == true)
    expectRowTop(NS, m, win, h, h, "history header")
end)

test("row tooltip: the column labels and the tabs keep their own anchor (rows only)", function()
    local NS, m = testWindow()
    placeWindow(NS, m)
    NS.WindowGroup.Drawn().pane.colHead.labels.item:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_BOTTOM", "a column label")
    NS.Window.Frame().tabs.group:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_BOTTOM", "a tab")
end)
