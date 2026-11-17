-- tests/test_header_marks.lua — every Drop Watcher window's title-bar marks are LibKa0s-Widgets-1.0's
-- HeaderButtons (AD-86-DW of Ka0sAddonsCommonTasks docs/2026-11-17-LIBKA0S_V1_105_ADOPTION, LibKa0s#86;
-- standalone-windows, *Title-bar controls*, v2.113.0): right-aligned, left to right extras · settings
-- · close, one 18 px size and one 6 px pitch, and a settings mark on every window that opens this
-- addon's settings through the opener its launcher registered.
--
-- The windows: the main window (lock, layout, minimize, settings, close), the Rolls panel (Expand all
-- / Collapse all, settings, close), the Offer panel (settings, close) and the Edit message box, which
-- opts out of the settings mark with its reason (a modal over the window). The detail card is the
-- Drops table's expanded row and has no title bar; the toast is a notification, not a window.

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
    { "the Rolls panel", rollsPanel, { "fold", "settings", "close" }, { fold = "foldButton" } },
    { "the Offer panel", offerPanel, { "settings", "close" }, {} },
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

-- red under: a settings mark on the modal, or an opt-out with no reason
test("header marks: the Edit message box opts out of the settings mark, with its reason", function()
    local _, _, e = editBox()
    local hb = e.headerButtons
    assertTrue(type(hb) == "table", "built by HeaderButtons")
    assertTrue(hb.settings == nil, "no settings mark on the modal")
    assertTrue(type(hb.optOut) == "string" and hb.optOut ~= "", "the reason is recorded")
    assertEqual(table.concat(hb.order, ","), "close")
    assertEqual(e.closeButton, hb.close)
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
