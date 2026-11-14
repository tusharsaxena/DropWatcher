-- tests/test_window_autoclose.lua — auto-close (rolls UX design §3.6, owner ruling 4, RX-10): a
-- window that opened by itself closes X seconds (`window.autoClose.seconds`, default 10) after
-- nothing is rolling and no new drop has arrived; a new drop, roll or pending item resets the
-- count, hovering restarts it, and a manual show, a drag or a click inside cancels it for that show.
-- The count is one C_Timer.NewTimer handle, read off the mock's timer queue.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function drop(id)
    return { id = id, at = 100, link = "|cffa335ee|Hitem:1::|h[Crown of Roaring Storms]|h|r",
        looter = { name = "Seta-Realm" }, me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely" }, facts = { ilvl = 311 }, seenBy = "Testchar-Testrealm" }
end

-- Answer `rec` for every NS.LootFeed.Get, and announce it.
local function announce(NS, rec)
    NS.LootFeed.Get = function() return rec end
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, rec.id)
end

-- An enabled addon in a heroic dungeon (an auto-open situation on both clients).
-- The kit's paint recorder is on (tests/_kit/mock_paint.lua), so the window built at the open
-- answers GetChildren over its own frames, as the client does: the press and hover hooks reach the
-- frames under the window through it.
local function inDungeon(over)
    local NS, _, m = T.enableAddon()
    dofile("tests/_kit/mock_paint.lua")(m)
    for path, v in pairs(over or {}) do NS.SchemaRuntime.Set(path, v) end
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    assertEqual(NS.Situations.Current(), "dungeon")
    return NS, m
end

-- Auto-opened by a drop: answers NS, the mock and the frame.
local function autoOpened(over)
    local NS, m = inDungeon(over)
    announce(NS, drop(1))
    assertTrue(NS.IsWindowShown(), "the drop opened the window")
    return NS, m, NS.Window.Frame()
end

-- The live auto-close timers on the mock's queue (its handle is the module's own).
local function liveCountdowns(NS, m)
    local n, mine = 0, NS.WindowAutoClose.Timer()
    for _, h in ipairs(m.__timers()) do
        if mine ~= nil and h == mine then n = n + 1 end
    end
    return n
end

-- ── defaults ────────────────────────────────────────────────────────────────────────────────

test("autoclose: on by default with 10 seconds, on this client", function()
    local NS = T.enableAddon()
    local d = NS.C.PROFILE.window.autoClose
    assertTrue(d ~= nil, "window.autoClose defaults exist")
    assertEqual(d.enabled, true, "on by default")
    assertEqual(d.seconds, 10, "10 seconds by default")
    assertEqual(NS.Setting("window.autoClose.enabled"), true)
    assertEqual(NS.Setting("window.autoClose.seconds"), 10)
end)

test("autoclose: the seconds row is a 5 to 120 slider, and refuses a value outside it", function()
    local NS = T.enableAddon()
    local row = NS.SchemaRuntime.FindRow("window.autoClose.seconds")
    assertTrue(row ~= nil, "the seconds row exists")
    assertEqual(row.min, 5); assertEqual(row.max, 120)
    assertFalse(NS.SchemaRuntime.Set("window.autoClose.seconds", 4), "below 5 refused")
    assertFalse(NS.SchemaRuntime.Set("window.autoClose.seconds", 121), "above 120 refused")
    assertTrue(NS.SchemaRuntime.Set("window.autoClose.seconds", 30))
end)

test("autoclose: both rows sit on Drops › Situations and dim while auto-open (or auto-close) is off", function()
    local NS = T.enableAddon()
    local on = NS.SchemaRuntime.FindRow("window.autoClose.enabled")
    local secs = NS.SchemaRuntime.FindRow("window.autoClose.seconds")
    assertEqual(on.page, "feed"); assertEqual(on.group, "Situations")
    assertEqual(secs.page, "feed"); assertEqual(secs.group, "Situations")
    assertFalse(on.disabledIf(), "live while auto-open is on")
    assertFalse(secs.disabledIf())
    NS.SchemaRuntime.Set("window.autoClose.enabled", false)
    assertTrue(secs.disabledIf(), "the seconds dim while auto-close is off")
    NS.SchemaRuntime.Set("window.autoClose.enabled", true)
    NS.SchemaRuntime.Set("autoOpen", false)
    assertTrue(on.disabledIf(), "auto-open off dims auto-close")
    assertTrue(secs.disabledIf(), "and its seconds")
    assertTrue(on.tooltip:find("Needs Auto-open the window.", 1, true) ~= nil, "a dependent row says so")
end)

-- ── the countdown ───────────────────────────────────────────────────────────────────────────

test("autoclose: an auto-opened window closes 10 seconds after the drop, once idle", function()
    local NS, m = autoOpened()
    assertTrue(NS.WindowAutoClose.Armed(), "an auto-open arms it")
    assertEqual(liveCountdowns(NS, m), 1, "one countdown queued")
    m.advance(9.9)
    assertTrue(NS.IsWindowShown(), "not yet")
    m.advance(0.2)
    assertFalse(NS.IsWindowShown(), "closed at 10 seconds")
    assertFalse(NS.WindowAutoClose.Armed(), "and disarmed")
    assertEqual(liveCountdowns(NS, m), 0, "no countdown left behind")
    assertEqual(NS.State.windowOpen, false, "a close, not a ladder hide")
end)

test("autoclose: the seconds setting sets the count", function()
    local NS, m = autoOpened({ ["window.autoClose.seconds"] = 30 })
    m.advance(29.9)
    assertTrue(NS.IsWindowShown())
    m.advance(0.2)
    assertFalse(NS.IsWindowShown())
end)

test("autoclose: a new drop resets the count", function()
    local NS, m = autoOpened()
    m.advance(8)
    announce(NS, drop(2))
    m.advance(8)
    assertTrue(NS.IsWindowShown(), "16 s after the open, 8 after the last drop")
    m.advance(2.1)
    assertFalse(NS.IsWindowShown(), "10 s after the last drop")
end)

test("autoclose: while Rolling now holds an item it waits, and a roll or pending change resets it", function()
    local NS, m = autoOpened()
    local held = 1
    NS.Pending.Count = function() return held end
    NS.addon:SendMessage(NS.MSG.PENDING_CHANGED, 7, "open")
    m.advance(25)
    assertTrue(NS.IsWindowShown(), "something is rolling: no close")
    m.advance(5)
    held = 0
    NS.addon:SendMessage(NS.MSG.PENDING_CHANGED, 7, "closed")
    m.advance(9.9)
    assertTrue(NS.IsWindowShown(), "the count starts over when the last roll closes")
    m.advance(0.2)
    assertFalse(NS.IsWindowShown())
end)

test("autoclose: hovering the window restarts the count, and the pointer over it holds it open", function()
    local NS, m, f = autoOpened()
    m.advance(8)
    f:__fire("OnEnter")
    m.advance(8)
    assertTrue(NS.IsWindowShown(), "the hover restarted the count")
    f.__mouseOver = true
    m.advance(30)
    assertTrue(NS.IsWindowShown(), "never closes under the pointer")
    f.__mouseOver = false
    m.advance(10.1)
    assertFalse(NS.IsWindowShown(), "closes a full count after the pointer left")
end)

test("autoclose: a manually opened window never closes by itself", function()
    local NS, m = inDungeon()
    NS.ShowWindow()
    assertFalse(NS.WindowAutoClose.Armed(), "a manual open arms nothing")
    assertEqual(liveCountdowns(NS, m), 0)
    announce(NS, drop(1))
    m.advance(60)
    assertTrue(NS.IsWindowShown(), "open by hand, a drop does not make it close")
end)

test("autoclose: a manual show, a drag or a click inside cancels it for that show", function()
    local NS, m = autoOpened()
    NS.ShowWindow()
    m.advance(60)
    assertTrue(NS.IsWindowShown(), "a manual show over an auto-open")
    local NS2, m2, f2 = autoOpened()
    f2.titleBar:__fire("OnDragStart")
    f2.titleBar:__fire("OnDragStop")
    m2.advance(60)
    assertTrue(NS2.IsWindowShown(), "a drag")
    local NS3, m3, f3 = autoOpened()
    f3:__fire("OnMouseDown", "LeftButton")
    m3.advance(60)
    assertTrue(NS3.IsWindowShown(), "a click inside")
    local NS4, m4, f4 = autoOpened()
    f4.titleBar:__fire("OnMouseDown", "LeftButton")
    m4.advance(60)
    assertTrue(NS4.IsWindowShown(), "a click on the title bar")
end)

-- A press lands on the control under the pointer and never bubbles to the frame, so the window's
-- tabs, title bar buttons and rows (most of its face) must hear it themselves.
test("autoclose: a press on a tab, a title bar button or a control built after the open cancels it too", function()
    local NS, m, f = autoOpened()
    f.tabs.history:__fire("OnMouseDown", "LeftButton")
    m.advance(60)
    assertTrue(NS.IsWindowShown(), "a press on a tab")
    local NS2, m2, f2 = autoOpened()
    f2.minimizeButton:__fire("OnMouseDown", "LeftButton")
    m2.advance(60)
    assertTrue(NS2.IsWindowShown(), "a press on the minimize button")
    -- A control built after the count was armed (a pooled row a repaint adds) is reached at the
    -- next repaint.
    local NS3, m3, f3 = autoOpened()
    local late = m3.CreateFrame("Button", nil, m3.CreateFrame("Frame", nil, f3))
    NS3.Window.Refresh()
    late:__fire("OnMouseDown", "LeftButton")
    m3.advance(60)
    assertTrue(NS3.IsWindowShown(), "a press on a control the repaint reached")
end)

test("autoclose: off, or with auto-open off, an auto-opened window stays", function()
    local NS, m = autoOpened({ ["window.autoClose.enabled"] = false })
    assertFalse(NS.WindowAutoClose.Armed())
    m.advance(60)
    assertTrue(NS.IsWindowShown(), "auto-close off")
    -- Turned off while armed: the count finds it off and lets go.
    local NS2, m2 = autoOpened()
    NS2.SchemaRuntime.Set("window.autoClose.enabled", false)
    m2.advance(60)
    assertTrue(NS2.IsWindowShown(), "turned off mid-count")
    -- Auto-open off: nothing opens, so nothing arms, and a manual open stays.
    local NS3, m3 = inDungeon({ autoOpen = false })
    announce(NS3, drop(1))
    assertFalse(NS3.IsWindowShown())
    NS3.ShowWindow()
    m3.advance(60)
    assertTrue(NS3.IsWindowShown())
end)

test("autoclose: a window the player closes disarms, and the next auto-open arms again", function()
    local NS, m = autoOpened()
    NS.HideWindow()
    assertFalse(NS.WindowAutoClose.Armed())
    assertEqual(liveCountdowns(NS, m), 0, "the close cancels the countdown")
    announce(NS, drop(2))
    assertTrue(NS.IsWindowShown() and NS.WindowAutoClose.Armed(), "the next auto-open arms again")
    m.advance(10.1)
    assertFalse(NS.IsWindowShown())
end)

test("autoclose: the stand-down cancels the countdown", function()
    local NS, m = autoOpened()
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.WindowAutoClose.Armed())
    assertEqual(liveCountdowns(NS, m), 0)
end)

-- RX-12 review fix: the visibility ladder can hide an auto-opened window (General visibility
-- outOfCombat, in combat). The count waits while it is hidden, and starts over once it shows.
-- red under: fire reading only NS.State.windowOpen (it closed the hidden window)
test("autoclose: a window the combat ladder hides is not closed; the count starts when it shows", function()
    local NS, m = inDungeon({ visibility = "outOfCombat" })
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    announce(NS, drop(1))
    assertEqual(NS.State.windowOpen, true, "the drop auto-opened it")
    assertFalse(NS.IsWindowShown(), "the ladder hides it in combat")
    m.advance(45)
    assertEqual(NS.State.windowOpen, true, "not closed while hidden")
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertTrue(NS.IsWindowShown(), "combat over: the auto-open shows")
    NS.Window.Frame():__fire("OnShow")  -- the client fires it on Show; the mock frame does not
    m.advance(9.9)
    assertTrue(NS.IsWindowShown(), "a full count after it showed")
    m.advance(0.2)
    assertFalse(NS.IsWindowShown())
end)

-- RX-12 review fix: the pointer leaving starts a full count, whenever it leaves.
-- red under: no OnLeave hook (the count that restarted under the pointer ran out 0.6 s after it left)
test("autoclose: the pointer leaving the window starts a full count from then", function()
    local NS, m, f = autoOpened()
    f.__mouseOver = true
    f:__fire("OnEnter")
    m.advance(19.5)
    assertTrue(NS.IsWindowShown(), "held open under the pointer")
    f.__mouseOver = false
    f:__fire("OnLeave")
    m.advance(9.9)
    assertTrue(NS.IsWindowShown(), "a full count after the pointer left")
    m.advance(0.2)
    assertFalse(NS.IsWindowShown())
end)
