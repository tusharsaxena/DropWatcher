-- tests/test_header_marks.lua — every Drop Watcher window's title-bar marks are LibKa0s-Widgets-1.0's
-- HeaderButtons (AD-86-DW of Ka0sAddonsCommonTasks docs/2026-11-17-LIBKA0S_V1_105_ADOPTION, LibKa0s#86;
-- standalone-windows, *Title-bar controls*, v2.113.0): right-aligned, left to right extras · settings
-- · close, one 18 px size and one 6 px pitch, and a settings mark on every window but a companion
-- (standard v2.119.0, *Settings is on every window but a companion*) that opens this addon's settings
-- through the opener its launcher registered.
--
-- The windows: the main window (lock, layout, minimize, settings, close). Its companions carry no
-- settings mark (FB-DW-01, W.HeaderButtons' companion = true): the Rolls panel (Expand all / Collapse
-- all, close) and the Offer panel (close), both docked beside the window and showing only its drops,
-- and the Edit message box (close), a modal over it. The detail card is the Drops table's expanded row
-- and has no title bar; the toast is a notification, not a window.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local LINK = "|cffa335ee|Hitem:211::|h[Crown of Tides]|h|r"

local function mainWindow()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    NS.ShowWindow()
    return NS, m, NS.Window.Frame()
end

local function info(name, guid, class, state, roll, isSelf)
    return { playerName = name, playerGUID = guid, playerClass = class, isSelf = isSelf == true, state = state,
        roll = roll, isWinner = false }
end

local function rollsPanel()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    m.__context.inInstance, m.__context.instanceType, m.__context.inGroup = true, "party", true
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    NS.ShowWindow()
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 800 end
    win.GetHeight = function() return 400 end
    m.UIParent.GetWidth = function() return 1920 end
    m.addItem(LINK, { name = "Item", quality = 4, ilvl = 620, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} })
    m.lootHistory["2900:1"] = { itemHyperlink = LINK, playerRollState = 5, isTied = false, allPassed = false,
        startTime = 100, duration = 60,
        rollInfos = { info("Brakk", "Player-1-0000000A", "WARRIOR", 0, 87),
            info("Testchar", "Player-0-00000001", "PALADIN", 5, nil, true) } }
    m.__fire("LOOT_HISTORY_UPDATE_ENCOUNTER", 2900)
    local p = NS.RollsPanel.Drawn().panel
    assertTrue(p ~= nil and p:IsShown(), "the Rolls panel opens")
    return NS, m, p
end

local function withDrop()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    m.__now = 100
    T.withPlayer(m)
    local d = { id = 1, at = 100, link = LINK, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 600 }, expiresAt = 700 },
        candidates = {} }
    NS.LootFeed.Groups = function()
        return { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } } }
    end
    NS.LootFeed.Get = function(id) return id == 1 and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.ShowWindow()
    return NS, m
end

local function offerPanel()
    local NS, m = withDrop()
    NS.OfferPanel.Open(1)
    return NS, m, NS.OfferPanel.Drawn().panel
end

local function editBox()
    local NS, m = withDrop()
    NS.Asks.Preview = function() return { text = "hi", length = 2 } end
    return NS, m, NS.DetailCard.OpenEditor(1, "announce")
end

-- The window, what its marks are, left to right, and the field each extra is kept in.
local WINDOWS = {
    { "the main window", mainWindow, { "lock", "mode", "minimize", "settings", "close" },
        { lock = "lockButton", mode = "modeButton", minimize = "minimizeButton" } },
}

-- The companions (FB-DW-01): docked beside the feed window or over it, each showing only its content.
local COMPANIONS = {
    { "the Rolls panel", rollsPanel, { "fold", "close" }, { fold = "foldButton" } },
    { "the Offer panel", offerPanel, { "close" }, {} },
    { "the Edit message box", editBox, { "close" }, {} },
}

local function markOf(hb, key)
    if key == "close" then return hb.close end
    if key == "settings" then return hb.settings end
    return hb.extras[key]
end

for _, w in ipairs(WINDOWS) do
    local name, open, order, fields = w[1], w[2], w[3], w[4]

    -- red under: a window whose marks are its own (no headerButtons), in another order, or with no
    -- settings mark
    test("header marks: " .. name .. " reads extras · settings · close through W.HeaderButtons", function()
        local _, _, f = open()
        local hb = f.headerButtons
        assertTrue(type(hb) == "table", name .. ": built by HeaderButtons")
        assertEqual(table.concat(hb.order, ","), table.concat(order, ","), name .. ": left to right")
        assertTrue(hb.settings ~= nil, name .. ": a settings mark")
        assertEqual(f.settingsButton, hb.settings, name .. ": kept as settingsButton")
        assertEqual(f.closeButton, hb.close, name .. ": the close is the strip's")
        for key, field in pairs(fields) do assertEqual(f[field], hb.extras[key], name .. ": " .. field) end
    end)

    -- red under: the old 4 px gaps, or a mark off the 18 px slot
    test("header marks: " .. name .. "'s marks are 18 px, 6 px in from the corner and 6 px apart", function()
        local _, _, f = open()
        local hb = f.headerButtons
        local off = 6
        for i = #order, 1, -1 do
            local key = order[i]
            local b = markOf(hb, key)
            assertEqual(b:GetWidth(), 18, name .. ": " .. key .. " is the 18 px slot")
            assertEqual(hb.offsets[key], -off, name .. ": " .. key .. "'s offset")
            off = off + 18 + 6
        end
    end)

    -- red under: no settings mark, or one whose click opens nothing
    test("header marks: " .. name .. "'s settings mark opens Drop Watcher's settings", function()
        local NS, _, f = open()
        local opened = 0
        NS.addon.OpenSettings = function() opened = opened + 1 end
        local b = f.headerButtons and f.headerButtons.settings
        assertTrue(b ~= nil, name .. ": a settings mark")
        b:__fire("OnClick", "LeftButton")
        assertEqual(opened, 1, name .. ": the launcher's opener, once")
    end)
end

for _, w in ipairs(COMPANIONS) do
    local name, open, order, fields = w[1], w[2], w[3], w[4]

    -- red under: a companion still building the gear, or opting out by the waiver instead
    test("header marks: " .. name .. " is a companion, its strip extras · close with no settings mark", function()
        local _, _, f = open()
        local hb = f.headerButtons
        assertTrue(type(hb) == "table", name .. ": built by HeaderButtons")
        assertEqual(hb.companion, true, name .. ": built as a companion")
        assertTrue(hb.settings == nil, name .. ": no settings mark")
        assertTrue(hb.optOut == nil, name .. ": the companion path, not the waiver")
        assertTrue(f.settingsButton == nil, name .. ": no settingsButton kept")
        assertEqual(table.concat(hb.order, ","), table.concat(order, ","), name .. ": left to right")
        assertEqual(f.closeButton, hb.close, name .. ": the close is the strip's")
        for key, field in pairs(fields) do assertEqual(f[field], hb.extras[key], name .. ": " .. field) end
    end)

    -- red under: a companion's marks off the 18 px slot or the 6 px pitch
    test("header marks: " .. name .. "'s marks are 18 px, 6 px in from the corner and 6 px apart", function()
        local _, _, f = open()
        local hb = f.headerButtons
        local off = 6
        for i = #order, 1, -1 do
            local key = order[i]
            local b = markOf(hb, key)
            assertEqual(b:GetWidth(), 18, name .. ": " .. key .. " is the 18 px slot")
            assertEqual(hb.offsets[key], -off, name .. ": " .. key .. "'s offset")
            off = off + 18 + 6
        end
    end)
end

-- red under: the settings mark's tooltip read from the library's HEADER_STRINGS, not this addon's L
test("header marks: the settings mark's tooltip is this addon's own string", function()
    local NS = T.enableAddon{ skin = "ka0s" }
    NS.L["Open settings"] = "Drop Watcher settings (localized)"
    NS.ShowWindow()
    local b = NS.Window.Frame().headerButtons.settings
    assertEqual(b.__tip, "Drop Watcher settings (localized)", "the tooltip comes from NS.L")
end)

-- red under: the host's TB.MARK_REST / TB.MARK_HOT drifting off the library's icon.tint / text.link,
-- which would leave an extra's two paint paths (the library's and the host's) disagreeing
test("header marks: an extra's host paint and the library's paint agree, at rest and on hover", function()
    local NS, _, f = mainWindow()
    local TB = NS.WindowTitleBar
    assertEqual(TB.MARK_REST, "icon.tint", "the host's rest token is the library's")
    assertEqual(TB.MARK_HOT, "text.link", "the host's hover token is the library's")
    local b = f.minimizeButton
    local function same(token, what)
        local r, g, bl = b.art:GetVertexColor()
        local er, eg, eb = NS.SkinColor(token)
        assertEqual(string.format("%.3f %.3f %.3f", r, g, bl), string.format("%.3f %.3f %.3f", er, eg, eb), what)
    end
    same("icon.tint", "at rest")
    b:__fire("OnEnter")
    same("text.link", "on hover")
    b:__fire("OnLeave")
    same("icon.tint", "after the pointer leaves")
end)

-- red under: the feed window losing its gear while its companions drop theirs
test("header marks: only the feed window carries the settings mark", function()
    local _, _, f = mainWindow()
    assertTrue(f.headerButtons.settings ~= nil and f.headerButtons.companion ~= true,
        "the feed window is no companion and keeps its gear")
end)

-- red under: a minimized window that loses its settings mark's reach, or a layout switch that moves it
test("header marks: the main window keeps its strip through minimize and the layout switch", function()
    local NS, _, f = mainWindow()
    local before = f.headerButtons.offsets.minimize
    NS.Window.SetMinimized(true)
    assertEqual(f.minimizeButton.mark, "add", "the expand mark while minimized")
    assertTrue(f.settingsButton:IsShown(), "settings stays on the bar while minimized")
    NS.Window.SetMinimized(false)
    NS.SetWindowMode("compact")
    assertEqual(f.headerButtons.offsets.minimize, before, "the same offset in compact")
    assertEqual(NS.WindowTitleBar.ClusterWidth(f), -f.headerButtons.offsets.lock + f.lockButton:GetWidth(),
        "the cluster reaches the lock's left edge")
end)

-- red under: no strip at all without LibKa0s-Widgets (the window's minimize and lock gone)
test("header marks: without LibKa0s-Widgets the window keeps its marks on the same pitch, with no settings mark", function()
    local NS = T.enableAddon{ skip = { "libs/LibKa0s/Widgets.lua" } }
    NS.ShowWindow()
    local f = NS.Window.Frame()
    local hb = f.headerButtons
    assertTrue(type(hb) == "table", "the host's strip")
    assertTrue(hb.settings == nil, "no settings mark without the library's opener")
    assertEqual(table.concat(hb.order, ","), "lock,mode,minimize,close")
    assertEqual(hb.offsets.minimize, -30, "6 in, 18 wide, 6 apart")
    f.minimizeButton:__fire("OnClick", "LeftButton")
    assertTrue(NS.Window.IsMinimized(), "minimize still works")
end)
