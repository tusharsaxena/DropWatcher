-- tests/test_window.lua — the main window's shell: the show decision, geometry, lock and test mode
-- (standalone-windows, preview-mode, options-ui-§15).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

test("window: built lazily, on the first show, and not before", function()
    local NS = T.enableAddon()
    assertTrue(NS.Window.Frame() == nil)
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertTrue(f ~= nil and f:IsShown())
    assertEqual(f.__name, "DropWatcherWindow")
end)

test("window: a tooltip shows on a disabled button too, so the gray No action says why", function()
    local NS, _, m = T.newAddon()
    local b = m.CreateFrame("Button")
    local motion
    rawset(b, "SetMotionScriptsWhileDisabled", function(_, v) motion = v end)
    NS.Window.AttachTooltip(b, function() return "No action", "why" end)
    -- red under: a disabled button fires no OnEnter, so the reason never showed
    assertEqual(motion, true)
end)

test("window: Escape closes it (UISpecialFrames) and it wears the shared close mark", function()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    local listed = false
    for _, name in ipairs(m.UISpecialFrames) do if name == "DropWatcherWindow" then listed = true end end
    assertTrue(listed)
    assertTrue(NS.Window.Frame().closeButton ~= nil)
end)

test("window: General visibility `never` keeps it hidden even when opened", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("visibility", "never")
    NS.ShowWindow()
    assertFalse(NS.IsWindowShown())
    NS.SchemaRuntime.Set("visibility", "always")
    assertTrue(NS.IsWindowShown(), "the player's choice is kept for the next show")
end)

test("window: `inCombat` shows it only in combat, re-read on both combat edges", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("visibility", "inCombat")
    NS.ShowWindow()
    assertFalse(NS.IsWindowShown())
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertTrue(NS.IsWindowShown())
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertFalse(NS.IsWindowShown())
end)

test("window: a drag stores the point, and Reset position forgets it", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "TOPLEFT", 40, -60)
    f.titleBar:GetScript("OnDragStop")(f.titleBar)
    local pt = NS.addon.db.profile.window.geometry.full.point
    assertEqual(table.concat(pt, ","), "TOPLEFT,TOPLEFT,40,-60")
    NS.Window.ResetPosition()
    assertTrue(NS.addon.db.profile.window.geometry == nil)
    assertEqual(f:GetPoint(1), "CENTER")
end)

test("window: locked, a drag does not start", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    NS.SetLocked(true)
    f.__userPlaced = false
    f.titleBar:GetScript("OnDragStart")(f.titleBar)
    assertFalse(f.__userPlaced, "StartMoving was not called")
    NS.SetLocked(false)
    f.titleBar:GetScript("OnDragStart")(f.titleBar)
    assertTrue(f.__userPlaced)
end)

test("window: resizable from the corner grip, with the design's minimum size", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertTrue(f:IsResizable())
    local minW, minH = f:GetResizeBounds()
    assertEqual(minW, 1080, "the least width is the default width (feedback-4 spec §4)")
    assertEqual(minH, 260)
end)

test("window: test mode shows the banner and the TEST MODE text, and its rows replace the empty state", function()
    local NS = T.enableAddon()
    NS.SetTestMode(true)
    local f = NS.Window.Frame()
    local empty = NS.WindowGroup.Drawn().empty
    assertTrue(f.banner:IsShown())
    assertTrue(f.testText:IsShown())
    assertFalse(empty:IsShown())
    NS.SetTestMode(false)
    NS.ShowWindow()
    assertFalse(f.banner:IsShown())
    assertFalse(f.testText:IsShown())
    assertTrue(empty:IsShown())
end)

-- DW-06 (LibKa0s#48): the strip is the library's; DW passes its words and its info mark, anchors it
-- and tips it.
test("window: the test banner is LibKa0s-Widgets' TestStrip with DW's text and the info mark", function()
    local NS, _, m = T.enableAddon()
    local W = m.LibStub("LibKa0s-Widgets-1.0")
    local real, calls = W.TestStrip, {}
    W.TestStrip = function(parent, opts)
        calls[#calls + 1] = { parent = parent, opts = opts }
        return real(parent, opts)
    end
    NS.ShowWindow()
    W.TestStrip = real
    -- red under: buildBanner drawing its own band
    assertEqual(#calls, 1, "one strip, built once with the window")
    local opts = calls[1].opts
    assertEqual(opts.text, "TEST MODE: sample drops of real items in every state. Nothing is whispered. Combat ends it.")
    assertTrue(type(opts.icon) == "string" and opts.icon:find("info", 1, true) ~= nil, "the catalog's info mark")
    assertEqual(opts.icon, NS.Icon("info"))
    local f = NS.Window.Frame()
    assertTrue(calls[1].parent == f.body)
    local p1, p2 = f.banner.__points[1], f.banner.__points[2]
    assertEqual(table.concat({ p1[1], p1[3], p1[4], p1[5] }, ","), "TOPLEFT,BOTTOMLEFT,0,-2")
    assertEqual(table.concat({ p2[1], p2[3], p2[4], p2[5] }, ","), "TOPRIGHT,BOTTOMRIGHT,0,-2")
    assertTrue(p1[2] == f.filterHost and p2[2] == f.filterHost)
    assertEqual(NS.Window.TooltipOf(f.banner)[1], "Test mode", "DW still tips it")
end)

test("window: K.BANNER_H - 4 == W.TEST_STRIP.HEIGHT", function()
    local NS, _, m = T.newAddon()
    local W = m.LibStub("LibKa0s-Widgets-1.0")
    -- red under: a BANNER_H that no longer leaves a 2 px gap above and below the library's strip
    assertEqual(NS.Constants.WINDOW.BANNER_H - 4, W.TEST_STRIP.HEIGHT)
end)

test("compact chrome: the full layout's text has a RIGHT point and no wrap; compact wraps", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    NS.SetTestMode(true)
    local text = f.banner.text
    local function hasRight()
        for _, pt in ipairs(text.__points) do if pt[1] == "RIGHT" then return true end end
        return false
    end
    -- red under: layoutStrip clearing the text's points and re-anchoring LEFT only in full
    assertTrue(hasRight(), "full: a long line truncates against the strip's right edge")
    assertFalse(text:GetWordWrap(), "full: one line")
    NS.SetWindowMode("compact")
    assertTrue(hasRight())
    assertTrue(text:GetWordWrap(), "compact: the short words may take two lines")
    assertEqual(text:GetText(), "TEST: sample drops in every state. Nothing is whispered; combat ends it.")
    NS.SetWindowMode("full")
    assertFalse(text:GetWordWrap())
    assertTrue(hasRight())
end)

test("window: with no Widgets the window builds, test mode on raises nothing, f.banner is nil, the panes reserve 0 and the title word shows", function()
    local skip = {}
    for _, rel in ipairs(T.loadAddon.libFiles) do
        if rel:find("/Widgets") then skip[#skip + 1] = rel end
    end
    assertTrue(#skip >= 1)
    local NS, _, m = T.enableAddon({ skip = skip })
    assertFalse(NS.HasWidgets())
    assertTrue(NS.MakeTestStrip(m.UIParent, "x") == nil, "the seam answers nil")
    NS.ShowWindow()
    local f = NS.Window.Frame()
    -- red under: a buildBanner that draws its own band when the library is absent
    assertTrue(f.banner == nil, "no strip")
    NS.SetTestMode(true)
    assertTrue(NS.State.testMode == true)
    assertTrue(f.testText:IsShown(), "the TEST MODE title word still marks the mode")
    local K = NS.Constants.WINDOW
    assertEqual(NS.CompactChrome.BannerH(), 0)
    assertEqual(f.panes.group.__points[1][5], -(K.TAB_H + 4 + K.FILTER_H), "no reserve")
    NS.SetWindowMode("compact")
    NS.Window.Refresh()
    assertEqual(NS.CompactChrome.BannerH(), 0)
    assertTrue(f.testText:IsShown())
    NS.SetTestMode(false)
end)

test("window: combat ends test mode, and test mode cannot start in combat", function()
    local NS, _, m = T.enableAddon()
    NS.SetTestMode(true)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    -- red under: drop the OnCombatStart test-mode branch in core/DropWatcher.lua
    assertFalse(NS.State.testMode)
    assertFalse(NS.SetTestMode(true), "refused in combat")
    assertFalse(NS.State.testMode)
end)

test("window: with test mode on, Close and Toggle still change what is shown", function()
    local NS = T.enableAddon()
    NS.SetTestMode(true)
    assertTrue(NS.IsWindowShown(), "turning test mode on opens the window")
    -- red under: ShouldShow answering true for test mode alone
    NS.HideWindow()
    assertFalse(NS.IsWindowShown(), "Close wins over test mode")
    NS.ToggleWindow()
    assertTrue(NS.IsWindowShown())
    NS.ToggleWindow()
    assertFalse(NS.IsWindowShown())
    NS.SchemaRuntime.Set("alpha", 0.5)
    assertFalse(NS.IsWindowShown(), "a settings repaint does not bring it back")
end)

test("window: turning test mode off closes the window only when test mode opened it", function()
    local NS = T.enableAddon()
    NS.SetTestMode(true)
    NS.SetTestMode(false)
    assertFalse(NS.IsWindowShown(), "test mode opened it, so off closes it")
    NS.ShowWindow()
    NS.SetTestMode(true)
    NS.SetTestMode(false)
    assertTrue(NS.IsWindowShown(), "the player opened it, so it stays")
end)

test("window: the combat edge decides, even while the player's combat flag lags it", function()
    local NS, _, m = T.enableAddon()
    NS.SchemaRuntime.Set("visibility", "outOfCombat")
    NS.ShowWindow()
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertFalse(NS.IsWindowShown())
    -- the flag still reads "in combat" (a pet, a DoT) when the regen edge arrives
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(NS.IsWindowShown(), "PLAYER_REGEN_ENABLED shows it")
    m.inCombat = false
end)

test("window: a resize saves the anchor with the size, so a settings repaint does not move it", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    f.resizeGrip:__fire("OnMouseDown", "LeftButton")
    -- the client re-anchors the frame while it is sized from the corner
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", 300, 700)
    f:SetSize(640, 400)
    f.resizeGrip:__fire("OnMouseUp", "LeftButton")
    local g = NS.addon.db.profile.window.geometry.full
    assertEqual(g.width, 640)
    assertEqual(table.concat(g.point, ","), "TOPLEFT,BOTTOMLEFT,300,700")
    NS.SetLocked(true)
    local point, _, rel, x, y = f:GetPoint(1)
    assertEqual(table.concat({ point, rel, x, y }, ","), "TOPLEFT,BOTTOMLEFT,300,700")
end)

test("window: the least width is the sum of Drops' columns, their gaps, the row lead and the chrome (feedback-5 §4, feedback-6 §1)", function()
    local NS = T.newAddon()
    local K, WG = NS.Constants.WINDOW, NS.WindowGroup
    local cols, fixed = WG.COLUMNS, 0
    for _, col in ipairs(cols) do fixed = fixed + (col.width or 0) + K.CELL_GAP end
    assertEqual(fixed, 866, "nine fixed columns (Me and Them 127, Trade 112, Trade window 76, Actions 84) and ten gaps")
    assertEqual(WG.LEAD, K.ROW_INDENT + K.CHEVRON_X + K.ROW_CHEVRON + K.CHEVRON_GAP)
    assertEqual(K.MIN_WIDTH, fixed + K.ITEM_MIN + WG.LEAD + K.SCROLL_W + 2 * K.INSET)
    assertEqual(K.MIN_WIDTH, 1080); assertEqual(K.WIDTH, 1080)
    local byKey = {}
    for _, col in ipairs(cols) do byKey[col.key] = col end
    assertEqual(byKey.tradeWindow.width, 76); assertEqual(byKey.actions.width, 84)
    assertEqual(byKey.me.width, 127); assertEqual(byKey.them.width, 127)
    assertEqual(NS.WindowFilterBar.SearchWidth(K.MIN_WIDTH), 374, "the search box keeps its room")
end)
