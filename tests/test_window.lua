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
    assertEqual(minW, 972, "the least width is the default width (feedback-4 spec §4)")
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
