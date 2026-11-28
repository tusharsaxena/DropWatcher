-- tests/test_row_tooltip.lua — where the addon's own tooltips open (modules/RowTooltip.lua, the seam
-- onto LibKa0s-Tooltip-1.0; AD-92-DW, LibKa0s#92; WowAddonStandards standalone-windows, *Tooltip
-- placement*), driven on the kit's fake screen (tests/_kit/mock_screen.lua).
--
-- RE-PINNED by AD-92-DW. These cases pinned the feedback-3 placement (DW-B2): the tooltip's
-- BOTTOMLEFT at the row's top, on the right edge of the frame the row sat in (Loot History's
-- ANCHOR_RIGHT corner). The standard rules that corner out. They now pin the body rule: the
-- tooltip's TOPLEFT a TIP_GAP right of the WINDOW GROUP's right edge (else its TOPRIGHT a TIP_GAP
-- left of its left edge), its top level with the row's, one absolute point on UIParent; a docked
-- panel's own rows prefer its side away from the window; no room on either side attaches it
-- centered above the row. The chrome rule (RT.PlaceChrome) is pinned here too.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local GAP = 2   -- TIP_GAP, the standard's and the library's

-- A frame on the fake screen from its screen rect: left, bottom, right, top.
local function box(scr, l, b, r, t, extra)
    extra = extra or {}
    local f = scr.frame({ left = l, bottom = b, width = r - l, height = t - b, parent = extra.parent,
        scale = extra.scale, shown = extra.shown })
    f.tipRow, f.dock = extra.tipRow, extra.dock
    return f
end

-- The tooltip's point: `point>relPoint`, the frame, x and y.
local function pt(tip)
    local p = tip.__point
    if not p then return nil end
    return p.point .. ">" .. p.relPoint, p.rel, p.x, p.y
end

local function setup(screenW, tipW, tipScale)
    local NS, _, m = T.newAddon()
    local scr = T.tipScreen(m, { width = screenW or 1920, height = 1080 })
    local tip = scr.tooltip({ width = tipW or 300, height = 100, scale = tipScale })
    return NS, m, scr, tip
end

test("row tooltip: it opens beside the window, TOPLEFT a TIP_GAP right of its edge, level with the row", function()
    local NS, m, scr, tip = setup()
    assertEqual(NS.Constants.WINDOW.TIP_GAP, GAP, "the addon's gap is the standard's")
    local win = box(scr, 400, 200, 1400, 900)
    local row = box(scr, 400, 680, 1400, 700, { parent = box(scr, 400, 300, 1400, 720, { parent = win }) })
    -- red under: the row's top-right corner (BOTTOMLEFT>TOPRIGHT on the window, ANCHOR_RIGHT's place)
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    local p, rel, x, y = pt(tip)
    assertEqual(p, "TOPLEFT>BOTTOMLEFT"); assertTrue(rel == m.UIParent, "one absolute point")
    assertEqual(x, 1400 + GAP); assertEqual(y, 700, "level with the row's top")
    assertEqual(tip.__anchorType, "ANCHOR_RIGHT", "its comparison tooltips further out on the right")
end)

test("row tooltip: with no room on the right it opens left of the window, TOPRIGHT a TIP_GAP left", function()
    local NS, m, scr, tip = setup()
    local win = box(scr, 600, 200, 1700, 900)
    local row = box(scr, 600, 830, 1700, 850, { parent = win })
    assertEqual(NS.RowTooltip.Place(tip, row), "left")
    local p, rel, x, y = pt(tip)
    assertEqual(p, "TOPRIGHT>BOTTOMLEFT"); assertTrue(rel == m.UIParent)
    assertEqual(x, 600 - GAP); assertEqual(y, 850)
    assertEqual(tip.__anchorType, "ANCHOR_LEFT")
end)

test("row tooltip: the room is measured at each frame's effective scale", function()
    local NS, _, scr, tip = setup()
    -- the window's own 1100..2200 at 0.64 is 704..1408 screen units: 300 of tooltip fit right
    local win = scr.frame({ left = 1100, bottom = 300, width = 1100, height = 900, scale = 0.64 })
    local row = scr.frame({ left = 1100, bottom = 980, width = 1100, height = 20, scale = 0.64, parent = win })
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    local _, _, x, y = pt(tip)
    assertTrue(math.abs(x - (1408 + GAP)) < 1e-6, "a gap past the window's scaled right edge: " .. tostring(x))
    assertTrue(math.abs(y - 640) < 1e-6, "the row's top in screen units")
    -- the tooltip at 2: 300 units are 600, and 1410 + 600 is past 1920; 702 - 600 is not: left
    local big = scr.tooltip({ width = 300, height = 100, scale = 2 })
    assertEqual(NS.RowTooltip.Place(big, row), "left")
    local l, _, r = scr.rectOf(big)
    assertTrue(math.abs(r - (704 - GAP)) < 1e-6, "its right edge a gap left of the window: " .. tostring(r))
    assertTrue(l >= 0)
end)

test("row tooltip: unreadable geometry places nothing; the fallback attaches it above the row", function()
    local NS, _, scr, tip = setup()
    local loose = scr.frame({})   -- unplaced: every edge nil
    assertTrue(NS.RowTooltip.Place(tip, loose) == nil)
    assertEqual(#tip.__points, 0, "left to the caller's fallback")
    -- red under: the hovered frame's top-right corner (BOTTOMLEFT>TOPRIGHT, ANCHOR_RIGHT's place)
    assertEqual(NS.RowTooltip.PlaceOrFallback(tip, loose), "attached")
    local p, rel, x, y = pt(tip)
    assertEqual(p, "BOTTOM>TOP"); assertTrue(rel == loose, "attached to the element, never the cursor")
    assertEqual(x, 0); assertEqual(y, GAP)
    local row = scr.frame({ parent = scr.frame({}) })
    row.tipRow = true
    local cell = scr.frame({ parent = row })
    NS.RowTooltip.PlaceOrFallback(tip, cell)
    assertTrue(select(2, pt(tip)) == row, "the row the cell sits in")
end)

-- With the Offer panel docked beside the window, a window row's tooltip opens beside the whole
-- group, never over the panel (M10 review, FB2-10).
local function dockedPair(scr, side, shown)
    local win = box(scr, 500, 200, 1300, 900)
    local panel = side == "right"
        and box(scr, 1304, 200, 1744, 900, { parent = win, dock = side, shown = shown })
        or box(scr, 340, 200, 496, 900, { parent = win, dock = side, shown = shown })
    win.tipDocks = { offer = panel }
    return win, panel
end

test("row tooltip: a window row's tooltip goes beside the docked Offer panel, not over it", function()
    local NS, _, scr = setup()
    local win = dockedPair(scr, "right", true)
    local row = box(scr, 500, 680, 1300, 700, { parent = win })
    local tip = scr.tooltip({ width = 150, height = 100 })
    -- red under: the window's own right edge (1300), under the panel
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    assertEqual(select(3, pt(tip)), 1744 + GAP, "beyond the panel's right edge")
    tip = scr.tooltip({ width = 300, height = 100 })
    assertEqual(NS.RowTooltip.Place(tip, row), "left", "no room right of the panel")
    assertEqual(select(3, pt(tip)), 500 - GAP, "the window's other side")
    local win2 = dockedPair(scr, "left", true)
    local row2 = box(scr, 500, 680, 1300, 700, { parent = win2 })
    assertEqual(NS.RowTooltip.Place(tip, row2), "right")
    assertEqual(select(3, pt(tip)), 1300 + GAP)
    scr.resize(1310, 1080)
    assertEqual(NS.RowTooltip.Place(tip, row2), "left")
    assertEqual(select(3, pt(tip)), 340 - GAP, "beyond the left panel's left edge")
end)

-- RX-28: the Rolls panel docked beside the window is part of the group too. A docked panel's own row
-- prefers the panel's side away from the window (body rule 1, the library's companion side).
test("row tooltip: the docked Rolls panel is part of the window group; an Offer row prefers its own side", function()
    local NS, _, scr, tip = setup()
    local win = box(scr, 700, 200, 1300, 900)
    local rolls = box(scr, 1300, 200, 1590, 900, { parent = win, dock = "right", shown = true })
    win.tipDocks = { rolls = rolls }
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 700, 680, 1300, 700, { parent = win })), "right")
    assertEqual(select(3, pt(tip)), 1590 + GAP, "beyond the Rolls panel's right edge")
    local offer = box(scr, 360, 200, 696, 900, { parent = win, dock = "left", shown = true })
    win.tipDocks.offer = offer
    -- re-pinned (was: right, past the window and the Rolls panel): the panel's side away from the window
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 360, 780, 696, 800, { parent = offer })), "left")
    assertEqual(select(3, pt(tip)), 360 - GAP)
    scr.resize(1700, 1080)
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 700, 680, 1300, 700, { parent = win })), "left")
    assertEqual(select(3, pt(tip)), 360 - GAP, "no room right: beyond the Offer panel's left edge")
end)

-- AF-DW-TIP (the owner's img-15 and img-16, 2026-11-19): a window row's tooltip sits flush beside the
-- window, and goes past a docked panel only when that flush spot would overlap it. The Rolls panel here
-- is short (600..900), as the live one is: rows lower on the window clear it.
local function shortRolls(scr, side)
    local win = box(scr, 700, 200, 1300, 900)
    local rolls = side == "left"
        and box(scr, 410, 600, 698, 900, { parent = win, dock = "left", shown = true })
        or box(scr, 1302, 600, 1590, 900, { parent = win, dock = "right", shown = true })
    win.tipDocks = { rolls = rolls }
    return win, rolls
end

test("row tooltip: a window row below a short Rolls panel opens flush beside the window (AF-DW-TIP)", function()
    local NS, m, scr, tip = setup()
    local win = shortRolls(scr)
    local row = box(scr, 700, 380, 1300, 400, { parent = win, tipRow = true })
    -- red under: beyond the Rolls panel (1590 + GAP), the whole group's edge
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    local p, rel, x, y = pt(tip)
    assertEqual(p, "TOPLEFT>BOTTOMLEFT"); assertTrue(rel == m.UIParent, "one absolute point")
    assertEqual(x, 1300 + GAP, "flush to the window, the panel above it not in the way")
    assertEqual(y, 400, "level with the row")
    assertTrue(NS.RowTooltip.FlushOverlaps(tip, row, NS.RowTooltip.GroupOf(row)) == false)
    -- the flush spot 300..400 tall never meets the panel's 600..900; from a row at 700 (600..700) it does
    row = box(scr, 700, 680, 1300, 700, { parent = win, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    assertEqual(select(3, pt(tip)), 1590 + GAP, "level with the panel: beyond it, as img-16")
end)

test("row tooltip: flush on the left too, beyond a left Rolls panel only where it overlaps (AF-DW-TIP)", function()
    local NS, _, scr, tip = setup(1400)
    local win = shortRolls(scr, "left")
    -- 1302 + 300 is past 1400: the left side, 698 - 300 = 398 .. 698
    local low = box(scr, 700, 380, 1300, 400, { parent = win, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, low), "left")
    assertEqual(select(3, pt(tip)), 700 - GAP, "flush to the window's left edge")
    local high = box(scr, 700, 780, 1300, 800, { parent = win, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, high), "left")
    assertEqual(select(3, pt(tip)), 410 - GAP, "beyond the panel it would cover")
end)

test("row tooltip: a hidden panel or a panel's own row keeps today's rule; an unmeasured flush keeps the group", function()
    local NS, _, scr, tip = setup()
    local win, rolls = shortRolls(scr)
    local inPanel = box(scr, 1302, 780, 1590, 800, { parent = rolls, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, inPanel), "right", "the panel's side away from the window")
    assertEqual(select(3, pt(tip)), 1590 + GAP)
    local lowInPanel = box(scr, 1302, 610, 1590, 630, { parent = rolls, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, lowInPanel), "right")
    assertEqual(select(3, pt(tip)), 1590 + GAP, "a panel row is never flush to the window")
    local row = box(scr, 700, 680, 1300, 700, { parent = win, tipRow = true })
    rolls:Hide()
    assertEqual(NS.RowTooltip.Place(tip, row), "right")
    assertEqual(select(3, pt(tip)), 1300 + GAP, "a hidden panel takes no room")
    rolls:Show()
    local unsized = scr.tooltip({})
    assertTrue(NS.RowTooltip.FlushOverlaps(unsized, row, NS.RowTooltip.GroupOf(row)) == true,
        "no tooltip size: the flush spot cannot be predicted")
end)

test("row tooltip: a docked panel's row never opens over the window; a hidden or floating panel is ignored", function()
    local NS, _, scr, tip = setup()
    local _, panel = dockedPair(scr, "right", true)
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 1304, 780, 1744, 800, { parent = panel })), "left")
    assertEqual(select(3, pt(tip)), 500 - GAP, "beyond the window's left edge, not over it")
    local win = dockedPair(scr, "right", false)
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 500, 780, 1300, 800, { parent = win })), "right")
    assertEqual(select(3, pt(tip)), 1300 + GAP, "a hidden panel takes no room")
    win, panel = dockedPair(scr, "right", true)
    panel.dock = "float"
    assertEqual(NS.RowTooltip.Place(tip, box(scr, 500, 780, 1300, 800, { parent = win })), "right")
    assertEqual(select(3, pt(tip)), 1300 + GAP, "a floating panel sits inside the window")
end)

test("row tooltip: GroupOf is the outermost frame and its docked panels, in name order", function()
    local NS, _, scr = setup()
    local win = box(scr, 700, 200, 1300, 900)
    local rolls = box(scr, 1300, 200, 1590, 900, { parent = win, dock = "right" })
    local offer = box(scr, 360, 200, 696, 900, { parent = win, dock = "left" })
    local floating = box(scr, 800, 200, 1000, 900, { parent = win, dock = "float" })
    win.tipDocks = { rolls = rolls, offer = offer, other = floating }
    local g = NS.RowTooltip.GroupOf(box(scr, 360, 780, 696, 800, { parent = offer }))
    assertTrue(g.main == win, "the window")
    assertEqual(#g.panels, 2, "the floating one left out")
    assertTrue(g.panels[1] == offer and g.panels[2] == rolls)
end)

test("row tooltip: a cell, a button or an icon in a marked row opens at the row's top, not its own", function()
    local NS, _, scr, tip = setup()
    local win = box(scr, 400, 200, 1400, 900)
    local row = box(scr, 400, 680, 1400, 700, { parent = win, tipRow = true })
    local cell = box(scr, 500, 682, 600, 690, { parent = row })
    local icon = box(scr, 500, 683, 510, 685, { parent = cell })
    assertTrue(NS.RowTooltip.RowOf(icon) == row)
    assertTrue(NS.RowTooltip.RowOf(win) == win, "no marked row: the hovered frame itself")
    assertEqual(NS.RowTooltip.Place(tip, icon), "right")
    assertEqual(select(4, pt(tip)), 700, "the row's top, not the icon's")
end)

test("row tooltip: a group as wide as the screen falls back above the row, centered (body rule 4)", function()
    local NS, _, scr, tip = setup()
    local win = box(scr, 0, 200, 1920, 900)
    local row = box(scr, 100, 680, 900, 700, { parent = win, tipRow = true })
    assertEqual(NS.RowTooltip.Place(tip, row), "above")
    local p, _, x, y = pt(tip)
    assertEqual(p, "BOTTOM>BOTTOMLEFT"); assertEqual(x, 500, "centered on the row"); assertEqual(y, 700 + GAP)
end)

test("chrome tooltip: centered TIP_GAP above the control, below only without room above", function()
    local NS, _, scr, tip = setup()
    local ctl = box(scr, 1000, 500, 1100, 520)
    -- red under: the control's top-right corner (Window.PlaceAbove's BOTTOMLEFT>TOPRIGHT)
    assertEqual(NS.RowTooltip.PlaceChrome(tip, ctl), "above")
    local p, _, x, y = pt(tip)
    assertEqual(p, "BOTTOM>BOTTOMLEFT"); assertEqual(x, 1050); assertEqual(y, 520 + GAP)
    local high = box(scr, 1000, 1000, 1100, 1020)
    assertEqual(NS.RowTooltip.PlaceChrome(tip, high), "below")
    p, _, x, y = pt(tip)
    assertEqual(p, "TOP>BOTTOMLEFT"); assertEqual(x, 1050); assertEqual(y, 1000 - GAP)
    local edge = box(scr, 1880, 500, 1920, 520)
    NS.RowTooltip.PlaceChrome(tip, edge)
    assertEqual(select(3, pt(tip)), 1920 - 150, "slid left only as far as the screen's edge")
    local loose = scr.frame({})
    assertEqual(NS.RowTooltip.PlaceChrome(tip, loose), "attached")
    p = pt(tip)
    assertEqual(p, "BOTTOM>TOP", "unreadable: attached above it, never the cursor")
end)

-- ── every row tooltip on the two tabs and the Offer panel ───────────────────────────────────

-- The window at 200..1200 (bottom 100, top 800) on a 1920 x 1080 screen; a 320 x 100 tooltip.
local function placeWindow(NS, m, screen)
    local scr = T.tipScreen(m, { width = screen or 1920, height = 1080 })
    local win = T.tipRect(NS.Window.Frame(), 200, 100, 1200, 800)
    return win, scr
end

-- Hover `w` inside `row` (its top at 600) and answer where the tooltip went.
local function hover(m, row, w)
    T.tipRect(row, 200, 580, 1200, 600)
    m.GameTooltip.__points = {}
    w:__fire("OnEnter")
    return T.tipPoint(m)
end

local function expectRowTop(m, spy, win, row, w, label)
    spy.reset()
    local pts, rel, x, y = hover(m, row, w)
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", label)
    local c = spy.first()
    assertTrue(c and c.fn == "PlaceBeside", label .. ": the body rule")
    assertTrue(c.el == row, label .. ": the row it sits in")
    assertTrue(type(c.group) == "table" and c.group.main == win, label .. ": the window group")
    assertEqual(pts, "TOPLEFT>BOTTOMLEFT", label .. ": beside the window")
    assertTrue(rel == m.UIParent, label)
    assertEqual(x, 1200 + GAP, label .. ": a gap past the window's right edge")
    assertEqual(y, 600, label .. ": level with the row's top")
end

local function testWindow()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    return NS, m
end

test("row tooltip: Drops, every cell, Ask and the header open beside the window, level with the row", function()
    local NS, m = testWindow()
    local win = placeWindow(NS, m)
    local spy = T.tipSpy(m)
    local drawn = NS.WindowGroup.Drawn()
    local row = drawn.rows[1]
    assertTrue(row ~= nil and row.tipRow == true, "a drop row, marked")
    for key, cell in pairs(row.cells) do
        if key ~= "actions" and cell.tooltip then expectRowTop(m, spy, win, row, cell, "group " .. key) end
    end
    local a = row.cells.actions
    a.ask.tipLines = { "Ask", "why" }
    expectRowTop(m, spy, win, row, a.ask, "group ask")
    local h = drawn.headers[1]
    assertTrue(h.tipRow == true)
    expectRowTop(m, spy, win, h, h, "group header")
end)

test("row tooltip: with no room on the right a row tooltip opens left of the window", function()
    local NS, m = testWindow()
    T.tipScreen(m, { width = 1400, height = 1080 })
    T.tipRect(NS.Window.Frame(), 500, 100, 1200, 800)   -- 1202 + 320 is past 1400; 498 - 320 is not
    local row = NS.WindowGroup.Drawn().rows[1]
    local pts, rel, x, y = hover(m, row, row.cells.trade)
    assertEqual(pts, "TOPRIGHT>BOTTOMLEFT")
    assertTrue(rel == m.UIParent)
    assertEqual(x, 500 - GAP); assertEqual(y, 600)
end)

test("row tooltip: your own drops' rows on Drops and their Offer open beside the window", function()
    local NS, m = testWindow()
    NS.WindowFilterBar.Set("group", "view", {})
    local win = placeWindow(NS, m)
    local spy = T.tipSpy(m)
    local row
    for _, r in ipairs(NS.WindowGroup.Drawn().rows) do
        if r.drop.isMine and r.cells.actions.ask:IsShown() then row = r; break end
    end
    assertTrue(row ~= nil and row.tipRow == true, "a row of yours, marked")
    for key, cell in pairs(row.cells) do
        if key ~= "actions" and cell.tooltip then expectRowTop(m, spy, win, row, cell, "own " .. key) end
    end
    local b = row.cells.actions.ask
    assertTrue(b.offer, "its Offer")
    expectRowTop(m, spy, win, row, b, "own offer")
end)

test("row tooltip: History rows and headers open beside the window", function()
    local NS, m = testWindow()
    NS.Window.SelectTab("history")
    local win = placeWindow(NS, m)
    local spy = T.tipSpy(m)
    local drawn = NS.WindowHistory.Drawn()
    local row = drawn.rows[1]
    assertTrue(row ~= nil and row.tipRow == true, "a History row, marked")
    for key, cell in pairs(row.cells) do
        if cell.tooltip then expectRowTop(m, spy, win, row, cell, "history " .. key) end
    end
    local h = drawn.headers[1]
    assertTrue(h ~= nil and h.tipRow == true)
    expectRowTop(m, spy, win, h, h, "history header")
end)

-- Re-pinned by AD-92-DW (was: the column labels and the tabs kept ANCHOR_BOTTOM). A column label is
-- a body element (the standard's *Terms*: a list's column-header row); a tab is chrome.
test("row tooltip: a column label opens beside the window; a tab is attached above itself", function()
    local NS, m = testWindow()
    local win = placeWindow(NS, m)
    local spy = T.tipSpy(m)
    local label = NS.WindowGroup.Drawn().pane.colHead.labels.item
    label:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", "a column label")
    assertTrue(spy.first().fn == "PlaceBeside" and spy.first().group.main == win, "a column label: the body rule")
    spy.reset()
    local tab = T.tipRect(NS.Window.Frame().tabs.group, 210, 760, 290, 780)
    tab:__fire("OnEnter")
    assertEqual(m.GameTooltip.__anchor, "ANCHOR_NONE", "a tab")
    assertTrue(spy.first().fn == "PlaceAttached" and spy.first().el == tab, "a tab: the chrome rule")
    local pts, _, x, y = T.tipPoint(m)
    assertEqual(pts, "BOTTOM>BOTTOMLEFT"); assertEqual(x, 250); assertEqual(y, 780 + GAP)
end)

-- DW#20 characterization: RT.FlushOverlaps' every branch, pinned before it was split into named
-- helpers (behavior-neutral, CCN <= 15): the unreadable window, no room beside it, the tooltip's own
-- scale, the flush spot's top clamped up to the tooltip's height and down to the screen's top, and a
-- panel the flush spot meets, misses, or that is hidden.
test("row tooltip: FlushOverlaps reads each case the same (DW#20 characterization)", function()
    local NS, _, scr, tip = setup()
    local RT = NS.RowTooltip
    local win = box(scr, 700, 200, 1300, 900)
    local row = box(scr, 700, 380, 1300, 400, { parent = win, tipRow = true })
    assertTrue(RT.FlushOverlaps(tip, row, { main = win, panels = {} }) == false, "room right, no panels")
    assertTrue(RT.FlushOverlaps(tip, row, { main = {}, panels = {} }) == true, "an unreadable window")
    assertTrue(RT.FlushOverlaps(tip, {}, { main = win, panels = {} }) == true, "an unreadable row")
    -- No room on either side of a wide window: unpredictable, so the whole group.
    local wide = box(scr, 100, 200, 1800, 900)
    local wideRow = box(scr, 100, 380, 1800, 400, { parent = wide, tipRow = true })
    assertTrue(RT.FlushOverlaps(tip, wideRow, { main = wide, panels = {} }) == true, "no room beside it")
    -- The tooltip's own scale: 300 wide at scale 2 is 600, too wide for either side of 400..1400.
    local NS2, _, scr2, big = setup(1920, 300, 2)
    local mid = box(scr2, 400, 200, 1400, 900)
    local midRow = box(scr2, 400, 380, 1400, 400, { parent = mid, tipRow = true })
    assertTrue(NS2.RowTooltip.FlushOverlaps(big, midRow, { main = mid, panels = {} }) == true, "scaled: no room")
    local _, _, scr3, small = setup(1920, 300, 1)
    local mid3 = box(scr3, 400, 200, 1400, 900)
    local midRow3 = box(scr3, 400, 380, 1400, 400, { parent = mid3, tipRow = true })
    assertTrue(NS2.RowTooltip.FlushOverlaps(small, midRow3, { main = mid3, panels = {} }) == false, "unscaled: room")
    -- A row near the screen's bottom: the spot is raised to 0..100, so a panel at 70..90 is met
    -- (unclamped, -50..50, it would miss).
    local low = box(scr, 700, 30, 1300, 50, { parent = win, tipRow = true })
    local lowPanel = box(scr, 1302, 70, 1590, 90, { parent = win, dock = "right", shown = true })
    assertTrue(RT.FlushOverlaps(tip, low, { main = win, panels = { lowPanel } }) == true, "clamped up")
    -- A row above the screen's top: the spot is lowered to 980..1080, meeting a panel at 1000..1050.
    local high = box(scr, 700, 1180, 1300, 1200, { parent = win, tipRow = true })
    local highPanel = box(scr, 1302, 1000, 1590, 1050, { parent = win, dock = "right", shown = true })
    assertTrue(RT.FlushOverlaps(tip, high, { main = win, panels = { highPanel } }) == true, "clamped down")
    -- A panel the spot misses, one it meets, and the same one hidden.
    local far = box(scr, 1302, 600, 1590, 900, { parent = win, dock = "right", shown = true })
    assertTrue(RT.FlushOverlaps(tip, row, { main = win, panels = { far } }) == false, "a panel it misses")
    local near = box(scr, 1302, 250, 1590, 350, { parent = win, dock = "right", shown = true })
    assertTrue(RT.FlushOverlaps(tip, row, { main = win, panels = { far, near } }) == true, "a panel it meets")
    near:Hide()
    assertTrue(RT.FlushOverlaps(tip, row, { main = win, panels = { far, near } }) == false, "hidden: no room taken")
    -- An unmeasurable panel takes no room.
    assertTrue(RT.FlushOverlaps(tip, row, { main = win, panels = { {} } }) == false, "an unmeasured panel")
end)
