-- tests/test_header_band.lua — every window's header on the skin's title band (R5-WIN of
-- Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND5, feedback items 2 and 5, the lead's calls 2, 3
-- and 6). Ka0s Loot History is the reference: the band sits flush inside the window's edge at
-- Shell's own inset (`win.borderSize` in from a flat edge, else 1), `title.height` high, with no
-- strip of body color between the edge and the band, and every header child (the title, the close
-- mark, the header buttons, the badge) is anchored LEFT, CENTER or RIGHT to the band at y 0, so it
-- sits on the band's geometric middle in every skin.
--
-- The windows: the main window (its title bar is a child under `noTopBar`, so the bar takes the
-- band's rect), and the two popovers, the Offer panel and the Edit message box, which keep the
-- band S.Shell draws and put their title and close on it. The detail card is the Drops table's
-- expanded row and has no header; the toast opts out of the band (LibKa0s Toast minor 3).
--
-- Headless, only the anchor shape can be measured: a LEFT, CENTER or RIGHT point at y 0 on the band
-- IS its vertical middle. The glyphs' own baseline is the owner's smoke check (SKIN-48).

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local OWNER = "DropWatcher"
local THICK = "dw-thick-edge"
local LINK = "|cffa335ee|Hitem:211::|h[Crown of Tides]|h|r"

--- A test skin with a 2 px flat edge (WoW Midnight's), left-aligned titles, then applied.
local function toThick(m)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if not Skin:GetSkin(THICK) then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["win.borderStyle"], tokens["win.borderSize"] = "flat", 2
        tokens["title.align"] = "LEFT"
        Skin:RegisterSkin({ key = THICK, label = THICK, tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", THICK)
end

--- The mock's frames answer SetAllPoints with nothing: record its relative frame, on every frame made
--- after this (the window is built on its first show).
local function recordAllPoints(m)
    local create = m.CreateFrame
    m.CreateFrame = function(...)
        local f = create(...)
        if type(f) == "table" then
            rawset(f, "SetAllPoints", function(self, rel) self.__points, self.__allPoints = {}, rel or self.__parent end)
        end
        return f
    end
end

local function shown()
    local NS, _, m = T.enableAddon()
    recordAllPoints(m)
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

local function lastPoint(r) return r.__points[#r.__points] end

--- The band holder S.Shell lays for `f`: anchored TOPLEFT and TOPRIGHT at (inset, -inset), `h` high.
local function assertBand(NS, f, inset, h, what)
    local band = NS.Skin.Band(f)
    assertTrue(band ~= nil, what .. ": a band")
    local a, b = band.__points[1], band.__points[2]
    assertEqual(a[1], "TOPLEFT", what .. ": band top left"); assertEqual(a[2], f, what .. ": on the window")
    assertEqual(a[4], inset, what .. ": band x"); assertEqual(a[5], -inset, what .. ": band y")
    assertEqual(b[1], "TOPRIGHT", what .. ": band top right"); assertEqual(b[4], -inset, what .. ": band right")
    assertEqual(band:GetHeight(), h, what .. ": band height")
    return band
end

--- `r` has one anchor, its point LEFT, CENTER or RIGHT, on `rel` at y 0.
local function assertMiddle(r, rel, what)
    assertTrue(r ~= nil, what .. ": built")
    assertEqual(#r.__points, 1, what .. ": one anchor")
    local p = r.__points[1]
    assertTrue(p[1] == "LEFT" or p[1] == "CENTER" or p[1] == "RIGHT", what .. ": a middle point, not " .. tostring(p[1]))
    assertEqual(p[2], rel, what .. ": on the band")
    assertEqual(p[5] or 0, 0, what .. ": at y 0")
end

-- ── the main window ──────────────────────────────────────────────────────────────────────────

local function assertWindowOnBand(NS, f, inset, what)
    local band = assertBand(NS, f, inset, 30, what)
    assertEqual(f.titleBar.__allPoints, band, what .. ": the title bar takes the band's rect")
    for _, key in ipairs({ "closeButton", "minimizeButton", "modeButton" }) do
        local p = lastPoint(f[key])
        assertEqual(p[1], "RIGHT", what .. ": " .. key .. " RIGHT")
        assertEqual(p[5] or 0, 0, what .. ": " .. key .. " at y 0")
    end
    assertEqual(select(2, f.closeButton:GetPoint(1)), f.titleBar, what .. ": close on the bar")
    local t = lastPoint(f.title)
    assertEqual(t[2], f.titleBar, what .. ": title on the bar"); assertEqual(t[5] or 0, 0, what .. ": title at y 0")
end

test("header band: the main window's title bar is the band, flush at Shell's inset, in every edge width", function()
    local NS, f, m = shown()
    assertWindowOnBand(NS, f, 1, "Ka0s Default")
    toThick(m)
    assertWindowOnBand(NS, f, 2, "2 px edge")
end)

test("header band: the main window draws one band, the bar's, through a switch", function()
    local _, f, m = shown()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local top = Skin.painted[f].regions.top
    assertTrue(top == nil or not top:IsShown(), "no Shell band under the bar")
    toThick(m)
    top = Skin.painted[f].regions.top
    assertTrue(top == nil or not top:IsShown(), "still none after a switch")
end)

test("header band: minimized, the window is the band and its two edges", function()
    local NS, f, m = shown()
    NS.Window.SetMinimized(true)
    assertEqual(f:GetHeight(), 32, "Ka0s Default: 1 + 30 + 1")
    toThick(m)
    assertEqual(f:GetHeight(), 34, "a 2 px edge: 2 + 30 + 2, the band never under the edge")
    NS.Window.SetMinimized(false)
    assertTrue(f:GetHeight() > 34, "expanded again")
end)

-- ── the popovers ─────────────────────────────────────────────────────────────────────────────

local function ownDrop()
    return { id = 1, at = 100, link = LINK, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 600 }, expiresAt = 700 },
        candidates = {} }
end

local function withDrop()
    local NS, _, m = T.enableAddon()
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

local function assertPopover(NS, m, p, what, content)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    for _, case in ipairs({ { "Ka0s Default", 1 }, { "2 px edge", 2 } }) do
        local label, inset = what .. ", " .. case[1], case[2]
        if inset == 2 then toThick(m) end
        local band = assertBand(NS, p, inset, 30, label)
        local top = Skin.painted[p].regions.top
        assertTrue(top ~= nil and top:IsShown(), label .. ": the band S.Shell draws shows")
        assertMiddle(p.title, band, label .. ": title")
        assertMiddle(p.closeButton, band, label .. ": close")
        assertEqual(p.closeButton.__points[1][1], "RIGHT", label .. ": close at the right")
        local y = select(5, content:GetPoint(1))
        assertTrue(y <= -(inset + 30 + 2), label .. ": the content starts below the band, at " .. tostring(y))
    end
end

test("header band: the Offer panel keeps S.Shell's band and centers its title and close on it", function()
    local NS, m = withDrop()
    NS.OfferPanel.Open(1)
    local p = NS.OfferPanel.Drawn().panel
    assertPopover(NS, m, p, "Offer panel", p.item)
    assertEqual(p.kind.__points[#p.kind.__points][2], p.title, "the YOUR DROP word follows the title")
end)

test("header band: the Edit message box keeps S.Shell's band and centers its title and close on it", function()
    local NS, m = withDrop()
    NS.Asks.Preview = function() return { text = "hi", length = 2 } end
    local e = NS.DetailCard.OpenEditor(1, "announce")
    assertTrue(e ~= nil and e:IsShown(), "the box opens")
    -- The box's edit field holder is the first frame anchored to the editor at its top left.
    local field = e.box:GetParent()
    assertPopover(NS, m, e, "Edit message box", field)
end)

test("header band: without the library no band is asked for and the headers keep their builders' anchors", function()
    local src = io.open("core/SkinSetup.lua", "rb"):read("*a")
    assertTrue(src:find('"Band", "Header"', 1, true) ~= nil, "the degraded facade answers Band and Header")
end)
