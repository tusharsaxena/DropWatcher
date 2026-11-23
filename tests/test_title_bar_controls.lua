-- tests/test_title_bar_controls.lua — every title-bar control on Drop Watcher's own windows (SR-DW of
-- Ka0sAddonsCommonTasks docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS, smoke round 1's rulings 2 to 4):
--
--   * a hover shows a tooltip with a non-empty first line, in the skin's `gtip.title`, placed by
--     LibKa0s-Tooltip-1.0's PlaceAttached (above the control, flipped below only without room);
--   * at rest a mark paints `icon.tint`, under the pointer `text.link`, and back on leave; a close
--     X rests in `close.rest` (which follows `icon.tint`) and lights `close.hot`;
--   * both pinned under Ka0s Default and Obsidian.
--
-- The windows: the main window (close, settings, minimize, the layout toggle, the lock), the Rolls
-- panel (close, settings, Expand all / Collapse all), the Offer panel (close, settings) and the Edit
-- message box (close; it opts out of the settings mark, AD-86-DW). The
-- lock's state is its alpha and desaturation, not its color, so it follows the tint rule too.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DropWatcher"
local LINK = "|cffa335ee|Hitem:211::|h[Crown of Tides]|h|r"
local SKINS = { "ka0s", "obsidian" }

local function near(label, got, want)
    assertTrue(type(got) == "table", label .. ": nothing painted")
    assertTrue(type(want) == "table", label .. ": no token")
    for i = 1, 3 do
        assertTrue(math.abs((got[i] or 1) - (want[i] or 1)) < 1e-6,
            ("%s[%d]: %s, want %s"):format(label, i, tostring(got[i]), tostring(want[i])))
    end
end

local function token(NS, name) return { NS.Skin.Color(name) } end

-- The tooltip's first line and its color, and every element PlaceAttached was asked to place.
local function spyTips(m)
    local spy = { placed = {} }
    local tip = m.GameTooltip
    local setText = tip.SetText
    tip.SetText = function(self, text, r, g, b, ...)
        spy.text, spy.color = text, { r, g, b }
        return setText(self, text, r, g, b, ...)
    end
    local Tip = m.LibStub("LibKa0s-Tooltip-1.0")
    local place = Tip.PlaceAttached
    Tip.PlaceAttached = function(t, el, ...)
        spy.placed[el] = true
        return place(t, el, ...)
    end
    return spy
end

local function assertTip(NS, spy, ctl, what)
    assertTrue(ctl ~= nil, what .. ": built")
    spy.text, spy.color, spy.placed = nil, nil, {}
    ctl:__fire("OnEnter")
    assertTrue(type(spy.text) == "string" and spy.text ~= "", what .. ": a tooltip line")
    near(what .. ": the title color", spy.color, token(NS, "gtip.title"))
    assertTrue(spy.placed[ctl] == true, what .. ": placed by PlaceAttached")
    ctl:__fire("OnLeave")
end

-- A mark's art (or its glyph when the art did not resolve): rest, hover, rest again.
local function markColor(b)
    if b.art and b.art:IsShown() then return b.art.__vertex end
    if b.icon then return b.icon.__vertex end   -- the library's own mark (the settings mark, AD-86-DW)
    return { b.glyph:GetTextColor() }
end

local function assertMarkColors(NS, b, what)
    near(what .. ": rest", markColor(b), token(NS, "icon.tint"))
    b:__fire("OnEnter")
    near(what .. ": hover", markColor(b), token(NS, "text.link"))
    b:__fire("OnLeave")
    near(what .. ": rest again", markColor(b), token(NS, "icon.tint"))
end

local function closeColor(b)
    if b.icon then return b.icon.__vertex end
    return { b.glyph:GetTextColor() }
end

local function assertCloseColors(NS, b, what)
    near(what .. ": close.rest follows icon.tint", token(NS, "close.rest"), token(NS, "icon.tint"))
    near(what .. ": rest", closeColor(b), token(NS, "close.rest"))
    b:__fire("OnEnter")
    near(what .. ": hover", closeColor(b), token(NS, "close.hot"))
    b:__fire("OnLeave")
    near(what .. ": rest again", closeColor(b), token(NS, "close.rest"))
end

local function setSkin(m, key) m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", key) end

-- ── the windows ──────────────────────────────────────────────────────────────────────────────

local function mainWindow()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    NS.ShowWindow()
    local f = NS.Window.Frame()
    return NS, m, { marks = { minimize = f.minimizeButton, mode = f.modeButton, lock = f.lockButton,
        settings = f.settingsButton }, close = f.closeButton }
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
    -- A companion (FB-DW-01): Expand all / Collapse all and the close, no settings mark.
    return NS, m, { marks = { fold = p.foldButton }, close = p.closeButton }
end

local function ownDrop()
    return { id = 1, at = 100, link = LINK, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 600 }, expiresAt = 700 },
        candidates = {} }
end

local function withDrop()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    m.__now = 100
    T.withPlayer(m)
    local d = ownDrop()
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
    local p = NS.OfferPanel.Drawn().panel
    -- A companion (FB-DW-01): the close alone.
    return NS, m, { marks = {}, close = p.closeButton }
end

local function editBox()
    local NS, m = withDrop()
    NS.Asks.Preview = function() return { text = "hi", length = 2 } end
    local e = NS.DetailCard.OpenEditor(1, "announce")
    return NS, m, { marks = {}, close = e.closeButton }
end

local WINDOWS = {
    { "the main window", mainWindow },
    { "the Rolls panel", rollsPanel },
    { "the Offer panel", offerPanel },
    { "the Edit message box", editBox },
}

-- ── the cases ────────────────────────────────────────────────────────────────────────────────

for _, w in ipairs(WINDOWS) do
    local name, open = w[1], w[2]

    -- red under: a title-bar control with no tooltip, one at the pointer or below it (ANCHOR_BOTTOM),
    -- or one whose title is not the skin's tooltip title color
    test("title bar: every control on " .. name .. " shows its tooltip above it, in gtip.title", function()
        local NS, m, ctl = open()
        local spy = spyTips(m)
        for _, key in ipairs(SKINS) do
            setSkin(m, key)
            assertTip(NS, spy, ctl.close, name .. ", " .. key .. ": close")
            for mark, b in pairs(ctl.marks) do assertTip(NS, spy, b, name .. ", " .. key .. ": " .. mark) end
        end
    end)

    -- red under: a mark at rest in icon.hot, a hover that only glows, or a close off its tokens
    test("title bar: " .. name .. "'s marks rest in icon.tint and light text.link; its close close.rest and close.hot",
        function()
        local NS, m, ctl = open()
        for _, key in ipairs(SKINS) do
            setSkin(m, key)
            assertCloseColors(NS, ctl.close, name .. ", " .. key)
            for mark, b in pairs(ctl.marks) do assertMarkColors(NS, b, name .. ", " .. key .. ": " .. mark) end
        end
    end)
end

test("title bar: the two skins pinned give the marks different rest and hover colors", function()
    -- The cases above are falsifiable only if Obsidian's tokens are not Ka0s Default's.
    local NS, m = mainWindow()
    local d = { tint = token(NS, "icon.tint"), link = token(NS, "text.link") }
    setSkin(m, "obsidian")
    local o = { tint = token(NS, "icon.tint"), link = token(NS, "text.link") }
    assertTrue(d.tint[1] ~= o.tint[1] or d.tint[3] ~= o.tint[3], "icon.tint moves between the two")
    assertTrue(d.link[1] ~= o.link[1] or d.link[2] ~= o.link[2] or d.link[3] ~= o.link[3],
        "text.link moves between the two")
    assertEqual(#SKINS, 2)
end)
