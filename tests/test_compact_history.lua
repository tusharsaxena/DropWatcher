-- tests/test_compact_history.lua — the History tab in the compact layout (compact spec §3, DW-C3):
-- the kept entries drawn headless under the mock as pooled three-line cards under one-line
-- headers, each line what NS.CompactCards.History says (the outcome in its tone, the time, both
-- verdicts), the row menu on a right-click, the header's collapse, the shortened Clear button and
-- every tooltip at the card's top right.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local DAY = 86400

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function entry(over)
    local e = { itemLink = link(500), itemID = 500, looter = "Brakk-Otherrealm", class = "WARRIOR", outcome = "seen",
        at = 1, seenBy = "Testchar-Testrealm", ilvl = 610, equipLoc = "INVTYPE_NECK", quality = 4,
        me = { verdict = "downgrade", ilvlDelta = -4 }, them = { verdict = "sidegrade", ilvlDelta = 0 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} } }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

-- Two kept groups, then the History tab in the compact layout.
local function shownCompact()
    local NS, _, m = T.enableAddon()
    m.normalizedRealm = "Testrealm"
    local now = m.time()
    local hist = NS.History.Store()
    hist.groups = {
        { key = "old", label = "Boss Old", kind = "encounter", situation = "raid", at = now - 3 * DAY, drops = {
            entry({ at = now - 3 * DAY, outcome = "received" }),
        } },
        { key = "new", label = "Boss New", kind = "encounter", situation = "dungeon", at = now - 120, drops = {
            entry({ at = now - 120, itemLink = link(501), outcome = "asked" }),
            entry({ at = now - 100, itemLink = link(502), outcome = "expired", isMine = true, looter = "Testchar-Testrealm" }),
        } },
    }
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    return NS, NS.WindowHistory.Drawn(), m
end

local function textOf(region) return region and region:GetText() end

local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function cardWith(drawn, outcome)
    for _, c in ipairs(drawn.rows) do
        if textOf(c.cells.outcome.text) == outcome then return c end
    end
end

test("compact history: kept groups as one-line headers, the newest open, each entry a three-line card", function()
    local NS, drawn = shownCompact()
    assertTrue(drawn.compact == true)
    assertEqual(#drawn.headers, 2); assertEqual(#drawn.rows, 2, "the older group is collapsed")
    assertFalse(drawn.pane.scroll:IsShown()); assertFalse(drawn.pane.colHead:IsShown())
    local h1, h2 = plain(textOf(drawn.headers[1].text)), plain(textOf(drawn.headers[2].text))
    assertEqual(h1, "Boss New · Dungeon · 2m · 2 · Testchar", "the short form, then the recorder")
    assertTrue(h2:find("3d", 1, true) ~= nil, h2)
    assertTrue(NS.Window.TooltipOf(drawn.headers[1])[2]:find("2m ago", 1, true) ~= nil, "the long form in the tooltip")
    local card = cardWith(drawn, "Asked")
    local c = card.cells
    assertTrue(card.tipRow == true)
    assertEqual(card:GetHeight(), 50)
    assertEqual(textOf(c.item.text), "Item 501"); assertEqual(textOf(c.ilvl.text), "610")
    assertEqual(textOf(c.looter.text), "Brakk"); assertEqual(textOf(c.looter.glyph), "⊕", "from another realm")
    assertEqual(plain(textOf(c.slot.text)), "· Neck"); assertEqual(plain(textOf(c.trade.text)), "· Likely")
    assertTrue(textOf(c.time.text):match("^%d%d:%d%d$") ~= nil, "the time within a day: " .. textOf(c.time.text))
    assertEqual(textOf(c.you.glyph) .. " " .. textOf(c.you.text), "▽ -4")
    assertEqual(textOf(c.themLabel.text), "Them")
    assertEqual(card.model.kind, "history")
    assertTrue(cardWith(drawn, "Expired") ~= nil)
end)

test("compact history: the outcome is in its tone, and every piece keeps its full-view tooltip", function()
    local NS, drawn = shownCompact()
    local C, W = NS.Constants, NS.Window
    local expired = cardWith(drawn, "Expired")
    assertEqual(select(1, expired.cells.outcome.text:GetTextColor()), C.TONE.bad.r)
    local asked = cardWith(drawn, "Asked")
    assertEqual(W.TooltipOf(asked.cells.outcome.hit)[1], "Outcome: Asked")
    assertEqual(W.TooltipOf(asked.cells.time.hit)[1], "When")
    assertEqual(W.TooltipOf(asked.cells.ilvl.hit)[1], "Item level 610")
    assertEqual(#W.TooltipOf(asked.cells.item.hit), 0, "the game's own tooltip instead")
    assertTrue(#W.TooltipOf(asked.cells.them.hit) >= 1)
end)

test("compact history: a right-click on a card, or on any piece of it, opens the row menu", function()
    local NS, drawn = shownCompact()
    local opened = {}
    NS.WindowHistory.OpenMenu = function(e, owner) opened[#opened + 1] = { e, owner } end
    local card = cardWith(drawn, "Asked")
    card:__fire("OnMouseUp", "RightButton")
    card.cells.trade.hit:__fire("OnMouseUp", "RightButton")
    card.cells.trade.hit:__fire("OnMouseUp", "LeftButton")
    assertEqual(#opened, 2, "a left click opens nothing")
    assertEqual(opened[1][1].outcome, "asked"); assertTrue(opened[2][2] == card)
end)

test("compact history: marking an entry declined repaints its card", function()
    local NS, drawn, m = shownCompact()
    local card = cardWith(drawn, "Asked")
    NS.History.SetEntryDeclined(card.entry, true)
    m.advance(0)
    assertTrue(cardWith(NS.WindowHistory.Drawn(), "Declined") ~= nil)
end)

test("compact history: a header click opens a collapsed group", function()
    local NS, drawn = shownCompact()
    drawn.headers[2]:__fire("OnClick")
    drawn = NS.WindowHistory.Drawn()
    assertEqual(#drawn.rows, 3)
    assertTrue(cardWith(drawn, "Received") ~= nil)
end)

test("compact history: every tooltip opens at the card's top right, just outside the window", function()
    local NS, drawn, m = shownCompact()
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 580 end
    win.GetTop = function() return 800 end
    m.UIParent.GetWidth = function() return 1920 end
    m.GameTooltip.GetWidth = function() return 320 end
    local card = cardWith(drawn, "Asked")
    card.GetTop = function() return 600 end
    for i, f in ipairs({ card.cells.outcome.hit, card.cells.time.hit, card.cells.you.hit, card.cells.looter.hit }) do
        m.GameTooltip.__points = {}
        f:__fire("OnEnter")
        local point, rel, relPoint, _, y = m.GameTooltip:GetPoint(1)
        assertEqual(tostring(point) .. ">" .. tostring(relPoint), "BOTTOMLEFT>TOPRIGHT", "piece " .. i)
        assertTrue(rel == win, "piece " .. i)
        assertEqual(y, -200, "piece " .. i)
    end
end)

test("compact history: Clear history is shortened in the compact layout and put back in the full one", function()
    local NS, drawn = shownCompact()
    local K, CH = NS.Constants.WINDOW, NS.CompactHistory
    local clear = drawn.strip.clear
    assertEqual(textOf(clear.label), "Clear"); assertEqual(clear:GetWidth(), CH.CLEAR_W)
    assertEqual(NS.Window.TooltipOf(clear)[1], "Clear history", "the tooltip is unchanged")
    assertEqual(textOf(drawn.strip.info), "2 groups, 3 drops · kept for 30 days")
    NS.SetWindowMode("full")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.compact == nil and #drawn.rows == 2, "the table again")
    assertEqual(textOf(clear.label), "Clear history"); assertEqual(clear:GetWidth(), K.CLEAR_W)
end)

test("compact history: cards are pooled and follow the Font size row", function()
    local NS, drawn = shownCompact()
    local pool = drawn.pane.compactView.cardPool
    NS.Window.Refresh()
    NS.Window.Refresh()
    local free, active = NS.Pool.Counts(pool)
    assertEqual(free + active, 2)
    NS.SchemaRuntime.Set("window.fontSize", 14)
    local card = NS.WindowHistory.Drawn().rows[1]
    assertEqual(card:GetHeight(), 62)
    assertEqual(select(2, card.cells.outcome.text:GetFont()), 14)
end)

test("compact history: test mode's kept samples fill a card each, no piece blank", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    local drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.compact == true)
    for _, h in ipairs(drawn.headers) do
        if h.collapsed then h:__fire("OnClick") end
    end
    drawn = NS.WindowHistory.Drawn()
    assertTrue(#drawn.rows >= 1, "the samples, as cards: " .. #drawn.rows)
    for _, card in ipairs(drawn.rows) do
        for _, key in ipairs({ "item", "ilvl", "outcome", "looter", "slot", "trade", "time", "you", "them" }) do
            local t = textOf(card.cells[key].text)
            assertTrue(t ~= nil and t ~= "", "card " .. tostring(card.dropId) .. ": " .. key)
        end
    end
end)
