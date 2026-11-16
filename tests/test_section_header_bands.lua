-- tests/test_section_header_bands.lua — the section headers' band (SR-DW of Ka0sAddonsCommonTasks
-- docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS, smoke round 1's ruling 5, LibKa0s SR-L4). A group header
-- (WindowGroup.NewHeader: the Drops tab, History, Pending and every compact header, which are the same
-- button) and a Rolls panel item header paint `list.header.bg` as a full-row band behind the header,
-- with their text and chevron in `list.header.text`, so a header stands apart from a plain row, a
-- stripe and a hover in every skin; each repaints on a skin switch with no reload.

local T = _G.DW_TEST
local test, assertTrue = T.test, T.assertTrue

local OWNER = "DropWatcher"
local LINK = "|cffa335ee|Hitem:211::|h[Crown of Tides]|h|r"

local function near(label, got, want)
    assertTrue(type(got) == "table", label .. ": nothing painted")
    assertTrue(type(want) == "table", label .. ": no token")
    for i = 1, #want do
        assertTrue(math.abs((got[i] or 1) - (want[i] or 1)) < 1e-6,
            ("%s[%d]: %s, want %s"):format(label, i, tostring(got[i]), tostring(want[i])))
    end
end

local function token(NS, name) return { NS.Skin.Color(name) } end
local function setSkin(m, key) m.LibStub("LibKa0s-Skin-1.0"):SetChoice(OWNER, "ka0s", key) end

local function assertBand(NS, h, what, withText)
    near(what .. ": the band", h.fill.__colorTexture, token(NS, "list.header.bg"))
    assertTrue(h.fill:IsShown(), what .. ": the band shows")
    near(what .. ": the chevron", h.chevron.__vertex, token(NS, "list.header.text"))
    if withText then near(what .. ": the text", { h.text:GetTextColor() }, token(NS, "list.header.text")) end
end

-- red under: a header band in `list.box` (Ka0s Default white .06, fainter than a .08 stripe), or a
-- band that keeps the old skin's color after a switch
test("section header bands: a group header paints list.header.bg and repaints on a skin switch", function()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    NS.ShowWindow()
    local h = NS.WindowGroup.NewHeader(NS.Window.Frame())
    assertBand(NS, h, "Ka0s Default", true)
    near("Ka0s Default's value", h.fill.__colorTexture, { 0, 0, 0, 0.35 })
    setSkin(m, "obsidian")
    assertBand(NS, h, "Obsidian", true)
    near("Obsidian's value", h.fill.__colorTexture, { 0, 0, 0 })
end)

test("section header bands: the band is told apart from the stripe and the plain box in both skins", function()
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    for _, key in ipairs({ "ka0s", "obsidian" }) do
        setSkin(m, key)
        local bg, stripe = token(NS, "list.header.bg"), token(NS, "list.stripe")
        local same = true
        for i = 1, 4 do if math.abs((bg[i] or 1) - (stripe[i] or 1)) > 1e-6 then same = false end end
        assertTrue(not same, key .. ": the band is not the stripe")
    end
end)

local function info(name, guid, class, state, roll, isSelf)
    return { playerName = name, playerGUID = guid, playerClass = class, isSelf = isSelf == true, state = state,
        roll = roll, isWinner = false }
end

test("section header bands: a Rolls panel item header paints list.header.bg and repaints on a skin switch", function()
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
    local h = NS.RollsPanel.Drawn().headers[1]
    assertTrue(h ~= nil, "an item header")
    assertBand(NS, h, "Rolls, Ka0s Default", false)
    setSkin(m, "obsidian")
    assertBand(NS, h, "Rolls, Obsidian", false)
end)

test("section header bands: the compact layout's headers are WindowGroup.NewHeader's", function()
    local src = io.open("modules/CompactGroup.lua", "rb"):read("*a")
    assertTrue(src:find("NS.WindowGroup.NewHeader(", 1, true) ~= nil, "compact builds its headers with NewHeader")
    assertTrue(src:find('"list.box"', 1, true) == nil, "and paints no band of its own")
end)
