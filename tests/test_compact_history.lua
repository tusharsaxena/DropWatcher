-- tests/test_compact_history.lua — the History tab in the compact layout (compact spec §3, DW-C3):
-- the kept entries drawn headless under the mock as pooled three-line cards under one-line
-- headers, each line what NS.CompactCards.History says (the outcome in its tone, the time, both
-- verdicts), the row menu on a right-click, the header's collapse, the strip without Clear history (it
-- lives in Settings) and every tooltip at the card's top right.

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
    -- red under: a header text left at the game's default CENTER
    assertEqual(drawn.headers[1].text:GetJustifyH(), "LEFT", "the header reads from the left")
    assertEqual(h1, "Boss New · Dungeon · 2m · 2 · Testchar", "the short form, then the recorder")
    assertTrue(h2:find("3d", 1, true) ~= nil, h2)
    assertTrue(plain(T.tipJoined(NS.Window.TooltipOf(drawn.headers[1]))):find("When  2m ago", 1, true) ~= nil,
        "the full time in the tooltip's rows")
    local card = cardWith(drawn, "Asked")
    local c = card.cells
    assertTrue(card.tipRow == true)
    assertEqual(card:GetHeight(), 64)
    assertEqual(textOf(c.item.text), "Item 501"); assertEqual(textOf(c.ilvl.text), "610")
    assertEqual(textOf(c.looter.text), "Brakk"); assertTrue(c.looter.glyph == nil, "no ⊕ after another realm's looter")
    assertEqual(plain(textOf(c.slot.text)), "· Neck")
    assertEqual(textOf(c.tradeLabel.text), "Trade"); assertEqual(textOf(c.trade.text), "Yes |cffb3b3b8Not their upgrade|r", "line 3, labeled")
    assertTrue(textOf(c.time.text):match("^%d%d:%d%d$") ~= nil, "the time within a day: " .. textOf(c.time.text))
    assertEqual(textOf(c.you.glyph) .. textOf(c.you.text), "▼4", "the verdict alone (feedback-6 spec §1)")
    assertEqual(textOf(c.you.level), "", "a kept entry holds no worn items")
    assertEqual(textOf(c.themLabel.text), "Them")
    -- feedback-10 spec §2: the level before the name, cut at the card's inset; gold labels, Them close after You.
    local CG, gold = NS.CompactGroup, NS.Constants.GOLD
    assertEqual(c.item.text.__points[1][2], c.ilvl.text); assertEqual(c.item.text.__points[2][2], card)
    assertEqual(c.themLabel.text.__points[1][2], c.you.text); assertEqual(c.themLabel.text.__points[1][4], CG.HALVES_GAP)
    -- feedback-25: Trade on line 3, You and Them under it on line 4, as on Drops' cards.
    local m = CG.Metrics(nil)
    local tp = c.tradeLabel.text.__points[1]
    assertEqual(tp[2], card); assertEqual(tp[5], CG.LineY(m, 3))
    tp = c.youLabel.text.__points[1]
    assertEqual(tp[2], c.tradeLabel.text); assertEqual(tp[4], 0); assertEqual(tp[5], -m.line)
    -- feedback-25: the outcome on line 2 and the time on line 3, at the right, where Drops' button is;
    -- Trade cut before the time.
    tp = c.outcome.text.__points[1]
    assertEqual(tp[1], "RIGHT"); assertEqual(tp[2], card); assertEqual(tp[5], CG.LineY(m, 2))
    tp = c.time.text.__points[1]
    assertEqual(tp[1], "RIGHT"); assertEqual(tp[2], card); assertEqual(tp[5], CG.LineY(m, 3))
    tp = c.trade.text.__points[2]
    assertEqual(tp[1], "RIGHT"); assertEqual(tp[2], c.time.text); assertEqual(tp[3], "LEFT")
    assertEqual(select(2, c.youLabel.text:GetTextColor()), gold.g)
    assertEqual(card.model.kind, "history")
    assertTrue(cardWith(drawn, "Expired") ~= nil)
end)

test("compact history: the outcome is in its tone, and every piece keeps its full-view tooltip", function()
    local NS, drawn = shownCompact()
    local C, W = NS.Constants, NS.Window
    local expired = cardWith(drawn, "Expired")
    assertEqual(select(1, expired.cells.outcome.text:GetTextColor()), C.TONE.red.r, "Expired in red (feedback-12 spec §0)")
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

test("compact history: the strip is the kept-history line and the toggle, no Clear history (feedback-15 spec §3)", function()
    local NS, drawn = shownCompact()
    local K = NS.Constants.WINDOW
    -- red under: Clear history on the compact strip beside the toggle
    assertTrue(drawn.strip.clear == nil, "Clear history lives in Settings")
    assertEqual(drawn.strip.fold:GetWidth(), K.FOOTER_ICON_W, "the toggle its icon (feedback-16)")
    assertEqual(textOf(drawn.strip.info), "2 groups, 3 drops · kept for 30 days")
    NS.SetWindowMode("full")
    drawn = NS.WindowHistory.Drawn()
    assertTrue(drawn.compact == nil and #drawn.rows == 2, "the table again")
    assertTrue(drawn.strip.clear == nil)
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
    assertEqual(card:GetHeight(), 80)
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

test("history: your own entry's looter reads Name [YOU] in both layouts, the mark in gold (feedback-7 spec §2)", function()
    local NS, drawn = shownCompact()
    local G = NS.Constants.GOLD
    local mine, theirs = cardWith(drawn, "Expired"), cardWith(drawn, "Asked")
    assertEqual(textOf(mine.cells.looter.text), "Testchar")
    assertTrue(mine.cells.looter.mark:IsShown()); assertEqual(textOf(mine.cells.looter.mark), "[YOU]")
    assertEqual(select(2, mine.cells.looter.mark:GetTextColor()), G.g)
    assertFalse(theirs.cells.looter.mark:IsShown())
    NS.SetWindowMode("full")
    local full = NS.WindowHistory.Drawn()
    local marked = 0
    for _, r in ipairs(full.rows) do
        local l = r.cells and r.cells.looter
        if l and l.mark:IsShown() then
            marked = marked + 1
            assertEqual(textOf(l.text), "Testchar"); assertEqual(textOf(l.mark), "[YOU]")
        end
    end
    assertEqual(marked, 1, "only your own entry is marked")
end)

