-- tests/test_layers.lua — the frame-layering map (frame-layering, standard v2.88.0; item 030): the one
-- NS.Constants.LAYERS table, and every frame class the addon creates pinned to its strata, level and
-- toplevel through the kit's frame-layer recorder (tests/_kit/mock_layers.lua, which tests/wow_mock.lua
-- installs on every instance before any source loads). Levels are read relative to the window's own level W: the window at MEDIUM and
-- toplevel, the docked Offer panel W+1, the floating Offer panel W+30 and the compact Filters panel
-- W+35 in the window's strata, the Edit message box on DIALOG at W+40 and toplevel, the toast on
-- HIGH and toplevel (LibKa0s-Toast-1.0's T5 tier); inside an item button, its border +1 and the
-- glow +2. Last, a static scan: no strata literal and no absolute level anywhere in the addon's own
-- source (frame-layering-§3, §5).

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function enabled() return T.enableAddon() end

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local NOW = 1000

-- One drop of yours, tradeable, with one member it upgrades: enough for Offer and the Edit box.
local function mine()
    return {
        id = 1, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = { ["Player-1-Seta"] = { guid = "Player-1-Seta", name = "Seta-Realm", classFile = "PRIEST",
            status = "ready", eval = { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291 }, reasons = {} } } },
    }
end

local function shownWithDrop(mode)
    local NS, _, m = enabled()
    m.__now = NOW
    local d = mine()
    NS.LootFeed.Get = function(id) return id == 1 and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.LootFeed.Groups = function() return {} end
    NS.ShowWindow()
    if mode then NS.SetWindowMode(mode) end
    return NS, NS.Window.Frame(), m
end

local function place(m, win, left, right, screen)
    win.GetLeft = function() return left end
    win.GetRight = function() return right end
    m.UIParent.GetWidth = function() return screen end
end

-- ── the table ───────────────────────────────────────────────────────────────────────────────

test("layers: one table names the addon's strata by the standard's tier keys", function()
    local NS = T.newAddon()
    local L = NS.Constants.LAYERS
    assertEqual(L.STRATA.WINDOW, "MEDIUM")
    assertEqual(L.STRATA.ALERT, "HIGH")
    assertEqual(L.STRATA.MODAL, "DIALOG")
end)

test("layers: the level bands keep border < glow, content < grip < popovers < modal", function()
    local NS = T.newAddon()
    local V = NS.Constants.LAYERS.LEVEL
    assertTrue(V.BORDER < V.EFFECT, "the icon border under the glow")
    assertEqual(NS.Glow.FRAME_LEVEL, V.EFFECT, "the glow's level is the table's")
    assertTrue(V.CONTENT_MAX < V.GRIP, "window content stays under the library grip")
    assertTrue(V.GRIP < V.POPOVER_OFFER, "a popover over every content level and the grip")
    assertTrue(V.POPOVER_OFFER < V.POPOVER_FILTERS, "the Filters panel over the floating Offer panel")
    assertTrue(V.POPOVER_FILTERS < V.MODAL, "the Edit box over every popover")
end)

-- ── the frames ──────────────────────────────────────────────────────────────────────────────

test("layers: the main window is MEDIUM, toplevel and clamped", function()
    local _, win, m = shownWithDrop()
    local s = m.__layers(win)
    assertEqual(s.strata, "MEDIUM"); assertTrue(s.toplevel, "a click raises it"); assertTrue(s.clamped)
end)

test("layers: the Offer panel stays in the window's strata; floating, it is W+30, docked W+1", function()
    local NS, win, m = shownWithDrop()
    T.withPlayer(m)   -- someone to offer to (DW-07)
    local V = NS.Constants.LAYERS.LEVEL
    place(m, win, 200, 1200, 1920)
    NS.OfferPanel.Open(1)
    local p = NS.OfferPanel.Drawn().panel
    local W = win:GetFrameLevel()
    assertEqual(p.dock, "right")
    assertEqual(m.__layers(p).strata, "MEDIUM"); assertEqual(p:GetFrameLevel(), W + V.DOCKED)
    place(m, win, 200, 1200, 1300)
    NS.Window.Refresh()
    assertEqual(p.dock, "float")
    assertEqual(m.__layers(p).strata, "MEDIUM", "no strata jump to float")
    assertEqual(p:GetFrameLevel(), W + V.POPOVER_OFFER, "over the window's rows by level")
    place(m, win, 200, 1200, 1920)
    NS.Window.Refresh()
    assertEqual(p.dock, "right"); assertEqual(p:GetFrameLevel(), W + V.DOCKED)
end)

test("layers: the compact Filters panel is W+35 in the window's strata, its dropdowns over it", function()
    local NS, win, m = shownWithDrop("compact")
    local V = NS.Constants.LAYERS.LEVEL
    local parts = NS.CompactChrome.Parts()
    parts.filters:__fire("OnClick")
    local p = parts.panel
    assertTrue(p:IsShown())
    assertEqual(m.__layers(p).strata, "MEDIUM")
    assertEqual(p:GetFrameLevel(), win:GetFrameLevel() + V.POPOVER_FILTERS)
    local dd = NS.WindowFilterBar.Controls().quality
    assertTrue(dd:GetParent() == p, "reparented into the panel")
    assertEqual(dd:GetFrameLevel(), p:GetFrameLevel() + 1)
    assertEqual(m.__layers(dd).strata, "MEDIUM")
end)

test("layers: the Edit message box is DIALOG at W+40 and toplevel", function()
    local NS, win, m = shownWithDrop()
    local V = NS.Constants.LAYERS.LEVEL
    local e = NS.DetailCard.OpenEditor(1)
    assertTrue(e:IsShown())
    local s = m.__layers(e)
    assertEqual(s.strata, "DIALOG"); assertTrue(s.toplevel)
    assertEqual(e:GetFrameLevel(), win:GetFrameLevel() + V.MODAL)
end)

test("layers: the toast is HIGH, above the window and under the modal", function()
    local NS, _, m = enabled()
    local d = { id = 1, link = "|cffa335ee|Hitem:500::|h[Item 500]|h|r", itemID = 500, isMine = false,
        looter = { name = "Seta-Testrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} } }
    NS.LootFeed.Get = function(id) return id == 1 and d or nil end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    local f = NS.Toast.Frame()
    assertTrue(f ~= nil, "the toast was built")
    assertEqual(m.__layers(f).strata, "HIGH"); assertEqual(m.__layers(f).strata, NS.Constants.LAYERS.STRATA.ALERT)
    -- LibKa0s-Toast-1.0 draws frame-layering's T5 tier: toplevel and clamped (the shell's own frame).
    assertTrue(m.__layers(f).toplevel)
end)

test("layers: an item button's border is button + 1, explicit, and the glow button + 2", function()
    local NS, _, m = enabled()
    local V = NS.Constants.LAYERS.LEVEL
    assertTrue(NS.SchemaRuntime.Set("icons.borderShow", true))
    local b = m.CreateFrame("Button", nil, m.UIParent)
    b.art = { SetTexCoord = function() end }
    b:SetFrameLevel(7)
    NS.IconStyle.Apply(b, BRACERS)
    local f = b.iconBorderFrame
    assertTrue(f ~= nil, "the border frame was made")
    assertTrue(rawget(f, "__level") ~= nil, "an explicit level, not the CreateFrame default")
    assertEqual(f:GetFrameLevel(), 7 + V.BORDER)
    assertEqual(NS.Glow.FRAME_LEVEL, V.EFFECT); assertEqual(V.EFFECT, V.BORDER + 1)
end)

-- ── the source ──────────────────────────────────────────────────────────────────────────────

test("layers: no strata literal and no absolute level in the addon's own source", function()
    local bad = {}
    for path in io.popen('ls core/*.lua modules/*.lua settings/*.lua 2>/dev/null'):lines() do
        local fh = assert(io.open(path, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            local code = line:gsub("%-%-.*$", "")
            if code:find('SetFrameStrata%(%s*["\']') or code:find("SetFrameLevel%(%s*%d") then
                bad[#bad + 1] = path .. ":" .. n
            end
        end
        fh:close()
    end
    assertEqual(table.concat(bad, ", "), "", "every strata and level reads NS.Constants.LAYERS")
end)
