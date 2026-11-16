-- tests/test_skin_host.lua — this addon's own surfaces on the skin's primitives (FS-DW-FIX, causes
-- A1, L4, L8 and L9 of Ka0sAddonsCommonTasks docs/2026-11-01-FULL_SKINNING): the flat button's box,
-- label and mark, the detail card's boxes, the tabs, the column head band, the row hover, the footer
-- band, the title bar and the Situations table's faces. Each case reads what the drawing setter was
-- told, on a test skin that moves the token.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local OWNER = "DropWatcher"

local function near(a, b) return math.abs(a - b) < 1e-6 end
local function same(got, want, label)
    assertTrue(type(got) == "table", label .. ": nothing drawn")
    for i = 1, 3 do assertTrue(near(got[i], want[i]), ("%s[%d]: %s, want %s"):format(label, i, tostring(got[i]), tostring(want[i]))) end
end

local function shown()
    local NS, _, m = T.enableAddon()
    NS.ShowWindow()
    return NS, NS.Window.Frame(), m
end

--- A test skin moving the tokens these cases read, then applied.
local function toSkin(m)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    if not Skin:GetSkin("dw-host") then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["btn.text"], tokens["btn.icon"] = { 0.1, 0.2, 0.3, 1 }, { 0.3, 0.2, 0.1, 1 }
        tokens["btn.hover"] = { 0.7, 0.1, 0.1, 1 }
        tokens["list.hover"] = { 0.2, 0.4, 0.6, 0.5 }
        tokens["list.header.bg"] = { 0.5, 0.1, 0.5, 0.5 }
        tokens["foot.bg"] = { 0.1, 0.5, 0.1, 0.5 }
        tokens["tab.onText"], tokens["tab.text"] = { 0.9, 0.1, 0.1, 1 }, { 0.1, 0.9, 0.1, 1 }
        tokens["title.align"] = "LEFT"
        Skin:RegisterSkin({ key = "dw-host", label = "dw-host", tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", "dw-host")
    return Skin
end

local function hover(frame, on)
    local fn = frame:GetScript(on and "OnEnter" or "OnLeave")
    assertTrue(fn ~= nil, "no hover script")
    fn(frame)
end

-- ── the flat button (A1, L8) ─────────────────────────────────────────────────────────────────

test("skin host: an untoned button's label and mark read btn.text and btn.icon, live", function()
    local NS, f, m = shown()
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    same({ b.label:GetTextColor() }, { NS.Skin.Color("btn.text") }, "label")
    same(b.art.__vertex, { NS.Skin.Color("btn.icon") }, "mark, Ka0s Default's gray")
    toSkin(m)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "label switched")
    same(b.art.__vertex, { 0.3, 0.2, 0.1 }, "mark switched")
end)

test("skin host: hover draws btn.hover on an untoned label and leaves a state's tone alone", function()
    local NS, f, m = shown()
    toSkin(m)
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    hover(b, true)
    same({ b.label:GetTextColor() }, { 0.7, 0.1, 0.1 }, "hot")
    hover(b, false)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "rest")
    NS.WindowGroup.ToneButton(b, "sent")
    local tone = { b.label:GetTextColor() }
    hover(b, true)
    same({ b.label:GetTextColor() }, tone, "a toned label keeps its tone under the pointer (D1)")
    hover(b, false)
    same({ b.label:GetTextColor() }, tone, "and after")
    same(b.art.__vertex, tone, "a toned mark takes the tone")
    NS.WindowGroup.ToneButton(b, nil)
    same({ b.label:GetTextColor() }, { 0.1, 0.2, 0.3 }, "untoned again: btn.text")
    same(b.art.__vertex, { 0.3, 0.2, 0.1 }, "untoned again: btn.icon")
end)

test("skin host: the button's and the detail box's frames are the library's primitives", function()
    local NS, f, m = shown()
    local b = NS.Window.TextButton(f, 80, "chat", "Send", function() end)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    assertTrue(Skin.painted[b] ~= nil and Skin.painted[b].calls.Button ~= nil, "S.Button recorded it")
    assertEqual(Skin.painted[b].calls.Button[1].tokens.bg, "dw.btnBg", "Ka0s Default keeps the owner's fill")
end)

-- ── the tabs (A1) ────────────────────────────────────────────────────────────────────────────

test("skin host: the tabs are the skin's, and selection moves their label color", function()
    local NS, f, m = shown()
    toSkin(m)
    same({ f.tabs.group.label:GetTextColor() }, { 0.9, 0.1, 0.1 }, "active: tab.onText")
    same({ f.tabs.history.label:GetTextColor() }, { 0.1, 0.9, 0.1 }, "idle: tab.text")
    NS.Window.SelectTab("history")
    same({ f.tabs.history.label:GetTextColor() }, { 0.9, 0.1, 0.1 }, "the new active tab")
    same({ f.tabs.group.label:GetTextColor() }, { 0.1, 0.9, 0.1 }, "the old one")
end)

test("skin host: without the library the tabs keep their text roles and underline", function()
    local NS = T.enableAddon{ skip = T.loadAddon.libFiles }
    NS.ShowWindow()
    local f = NS.Window.Frame()
    assertTrue(f.tabs.group.underline:IsShown())
    assertFalse(f.tabs.history.underline:IsShown())
end)

-- ── the column heads, the footer, the row hover (A1) ─────────────────────────────────────────

test("skin host: the column heads wear list.header.bg and the footer foot.bg", function()
    local NS, f, m = shown()
    local Skin = toSkin(m)
    local head = f.panes.group.colHead
    assertTrue(Skin.painted[head].calls.SortHeaderBar ~= nil, "S.SortHeaderBar on the Drops head")
    -- red under: the retired dark band (S.Footer's foot.bg) under the library's footer
    assertTrue(not (Skin.painted[f.footerHost] and Skin.painted[f.footerHost].calls.Footer), "no S.Footer band")
    NS.Window.SelectTab("history")
    assertTrue(Skin.painted[f.panes.history.colHead].calls.SortHeaderBar ~= nil, "and on History's")
end)

test("skin host: a row takes list.hover under the pointer, from a cell inside it too", function()
    local NS, f, m = shown()
    local Skin = toSkin(m)
    local row = m.CreateFrame("Button", nil, f)
    row.tipRow = true
    NS.WindowRows.HoverWash(row)
    local cell = m.CreateFrame("Frame", nil, row)
    NS.Window.AttachTooltip(cell, function() return "x" end, "row")
    hover(row, true)
    local wash = Skin.painted[row].regions.hover
    assertTrue(wash ~= nil and wash:IsShown(), "the hover wash")
    same(wash.__colorTexture, { 0.2, 0.4, 0.6 }, "list.hover")
    hover(row, false)
    assertFalse(wash:IsShown())
    hover(cell, true)
    assertTrue(wash:IsShown(), "a cell's hover is the row's")
    hover(cell, false)
    assertFalse(wash:IsShown())
end)

-- Every row and card builder, from the rest and from the frames inside it the pointer moves onto.
local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"

local function assertWashes(Skin, row, label, inside)
    hover(row, true)
    local wash = Skin.painted[row].regions.hover
    assertTrue(wash ~= nil and wash:IsShown(), label .. ": the row's own hover")
    same(wash.__colorTexture, { 0.2, 0.4, 0.6 }, label .. ": list.hover")
    hover(row, false)
    assertFalse(wash:IsShown(), label .. ": off when the pointer leaves")
    for name, frame in pairs(inside) do
        hover(frame, true)
        assertTrue(wash:IsShown(), label .. ": from " .. name)
        hover(frame, false)
        assertFalse(wash:IsShown(), label .. ": off, from " .. name)
    end
end

local function drop(id, over)
    local d = { id = id, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = RING, ilvl = 292 } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 } }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

--- The Drops tab with `d` listed, in `mode`.
local function shownDrop(d, mode)
    local NS, _, m = T.enableAddon()
    m.__now = 100
    T.withPlayer(m)
    NS.LootFeed.Groups = function()
        return { { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { d.id } } }
    end
    NS.LootFeed.Get = function(id) return id == d.id and d or nil end
    NS.LootFeed.Drops = function() return { d } end
    NS.WindowFilterBar.Set("group", "view", "all")
    if mode then NS.SetWindowMode(mode) end
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn().rows[1], toSkin(m)
end

--- The History tab with one kept entry, in `mode`.
local function shownHistory(mode)
    local NS, _, m = T.enableAddon()
    local now = m.time()
    NS.History.Store().groups = { { key = "new", label = "Boss", kind = "encounter", situation = "raid", at = now - 60,
        drops = { { itemLink = LINK, itemID = 212, looter = "Brakk-Realm", class = "WARRIOR", outcome = "seen", at = now - 60,
            seenBy = "Testchar-Testrealm", ilvl = 610, equipLoc = "INVTYPE_NECK", quality = 4,
            me = { verdict = "downgrade", ilvlDelta = -4 }, them = { verdict = "sidegrade", ilvlDelta = 0 },
            trade = { state = "likely", reasonKey = "notUpgrade", args = {} } } } } }
    if mode then NS.SetWindowMode(mode) end
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    return NS.WindowHistory.Drawn().rows[1], toSkin(m)
end

test("skin host: a Drops row washes, from its item, its item's button and a worn icon too", function()
    local _, row, Skin = shownDrop(drop(1))
    assertWashes(Skin, row, "Drops row", { item = row.cells.item, button = row.cells.item.button,
        worn = row.cells.me.icons[1] })
end)

test("skin host: WG.ItemHover's own frame washes its row, with no cell tooltip to do it", function()
    local NS, f, m = shown()
    local Skin = toSkin(m)
    local row = m.CreateFrame("Button", nil, f)
    row.tipRow = true
    NS.WindowRows.HoverWash(row)
    local name = m.CreateFrame("Frame", nil, row)
    NS.WindowGroup.ItemHover(name, NS.WindowGroup.ItemButton(row, 16))
    assertWashes(Skin, row, "a name beside an item", { name = name })
end)

test("skin host: a History row washes, from its item and its button too", function()
    local row, Skin = shownHistory()
    assertWashes(Skin, row, "History row", { item = row.cells.item, button = row.cells.item.button })
end)

test("skin host: a compact Drops card washes, from its icon too", function()
    local _, card, Skin = shownDrop(drop(1), "compact")
    assertWashes(Skin, card, "compact Drops card", { icon = card.icon })
end)

test("skin host: a compact History card washes, from its icon too", function()
    local card, Skin = shownHistory("compact")
    assertWashes(Skin, card, "compact History card", { icon = card.icon })
end)

test("skin host: an Offer panel row washes, from its Their eq icon too", function()
    local NS, _, Skin = shownDrop(drop(1, { isMine = true,
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        candidates = { ["Player-1-S"] = { guid = "Player-1-S", name = "Seta-Realm", classFile = "PRIEST", status = "ready",
            eval = { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291, link = RING }, reasons = {} } } } }))
    NS.OfferPanel.Open(1)
    local row = NS.OfferPanel.Drawn().rows[1]
    assertWashes(Skin, row, "Offer row", { eq = row.eq, icon = row.eq.icons[1] })
end)

-- ── the title bar (L9) ───────────────────────────────────────────────────────────────────────

test("skin host: title.bg is one layer, the bar's, and stays one through a skin switch", function()
    local _, f, m = shown()
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local function oneLayer(label)
        local top = Skin.painted[f].regions.top
        assertTrue(top ~= nil and not top:IsShown(), label .. ": no Shell band under the bar")
        -- The mock's frames all take a backdrop; a client's plain frame gets the `fill` region.
        local bar = Skin.painted[f.titleBar].regions
        assertTrue(bar.backdrop ~= nil or bar.fill ~= nil, label .. ": the bar's own box")
    end
    oneLayer("Ka0s Default")
    toSkin(m)
    oneLayer("switched")
end)

test("skin host: the title bar is placed by the skin's height and alignment", function()
    local _, f, m = shown()
    assertEqual(f.titleBar:GetHeight(), 30, "Ka0s Default's title.height")
    toSkin(m)
    local p = f.title.__points[#f.title.__points]
    assertEqual(p[1], "LEFT", "title.align moves the title's anchor")
end)

-- A skin of Ka0s Default's tokens with its title aligned `align`, chosen.
local function alignedSkin(m, align)
    local Skin = m.LibStub("LibKa0s-Skin-1.0")
    local key = "dw-align-" .. align
    if not Skin:GetSkin(key) then
        local tokens = {}
        for name, v in pairs(Skin:ResolveSkin(Skin.DEFAULT)) do tokens[name] = v end
        tokens["title.align"] = align
        Skin:RegisterSkin({ key = key, label = key, tokens = tokens })
    end
    Skin:SetChoice(OWNER, "ka0s", key)
end

local function titlePoint(f)
    local p = f.title.__points[#f.title.__points]
    return p[1], p[4]
end

-- The right-hand cluster's width: close, minimize, the layout toggle and the lock, 4 apart, 6 in.
local function cluster(f)
    return 6 + f.closeButton:GetWidth() + 4 + f.minimizeButton:GetWidth() + 4 + f.modeButton:GetWidth()
        + 4 + f.lockButton:GetWidth()
end

-- red under: a RIGHT title 8 px in from the bar's edge, under the close, minimize, layout and lock
-- marks (RX-30)
test("rx30: a RIGHT-aligned title stays clear of the right-hand cluster, and of the badge beside it", function()
    local NS, f, m = shown()
    alignedSkin(m, "RIGHT")
    NS.Window.Refresh()
    local point, x = titlePoint(f)
    local TB = NS.WindowTitleBar
    assertEqual(point, "RIGHT")
    assertEqual(x, -(cluster(f) + TB.TITLE_RESERVE), "clear of the cluster: " .. tostring(x))
    -- The full layout's restriction badge stands left of the lock: the title clears it too.
    NS.Window.RestrictionReason = function() return "combat" end
    NS.Window.Refresh()
    assertTrue(f.badge:IsShown(), "the badge up")
    x = select(2, titlePoint(f))
    assertEqual(x, -(cluster(f) + 8 + f.badge:GetWidth() + TB.TITLE_RESERVE), "and the badge")
end)

-- red under: the title placed (CompactChrome.Paint) before the minimized paint shows the `n new`
-- counter, so in the pass that shows it a RIGHT title is laid over it (RX-30 review)
test("rx30: minimized with new drops, a RIGHT title clears the n new counter in the same pass", function()
    local NS, f, m = shown()
    alignedSkin(m, "RIGHT")
    NS.Window.SetMinimized(true)
    NS.Window.Refresh()
    local _, before = titlePoint(f)
    local rec = { id = 1, at = 100, link = "|cffa335ee|Hitem:1::|h[Crown]|h|r", looter = { name = "Seta-Realm" },
        me = { verdict = "upgrade", ilvlDelta = 19 }, trade = { state = "likely" }, facts = { ilvl = 311 } }
    NS.LootFeed.Get = function() return rec end
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, rec.id)
    NS.Window.Refresh()
    assertTrue(NS.Window.NewCount() > 0 and f.newChip:IsShown(), "the counter shows")
    local _, x = titlePoint(f)
    assertEqual(x, before - (8 + f.newChip:GetWidth()), "the title moved clear of it in that pass")
end)

-- red under: a LEFT title 8 px in, over the compact layout's badge at the bar's left; or the compact
-- pass putting every title back on the center whatever the skin aligns (RX-30)
test("rx30: in compact a LEFT-aligned title starts past the restriction badge at the bar's left", function()
    local NS, f, m = shown()
    alignedSkin(m, "LEFT")
    NS.SetWindowMode("compact")
    NS.Window.Refresh()
    local TB, CC = NS.WindowTitleBar, NS.CompactChrome
    local point, x = titlePoint(f)
    assertEqual(point, "LEFT", "the skin's alignment holds in compact")
    assertEqual(x, TB.TITLE_RESERVE, "no badge: the plain reserve")
    NS.Window.RestrictionReason = function() return "combat" end
    NS.Window.Refresh()
    assertTrue(f.badge:IsShown(), "the badge up")
    x = select(2, titlePoint(f))
    assertEqual(x, CC.BADGE_X + CC.BADGE_W + TB.TITLE_RESERVE, "past the badge")
    -- A CENTER skin is centered as before.
    alignedSkin(m, "CENTER")
    NS.Window.Refresh()
    assertEqual((titlePoint(f)), "CENTER")
end)

-- ── the Situations table's faces (L4) ────────────────────────────────────────────────────────

test("skin host: the Situations table's heads and labels take the panel's Text, kept off while ignored", function()
    local src = io.open("settings/PageEditors.lua", "rb"):read("*a")
    assertTrue(src:find('NS.Skin.Text(fs, "text.headingAlt", PANEL)', 1, true) ~= nil, "the header's face")
    assertTrue(src:find('NS.Skin.Text(fs, "text.bodyAlt", PANEL)', 1, true) ~= nil, "the label's face")
end)
