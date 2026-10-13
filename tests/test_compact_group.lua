-- tests/test_compact_group.lua — the Group drops tab in the compact layout (compact spec §2, DW-C2):
-- the card's metrics and the scroll carry-over (pure), the stacked detail card's flow (pure), then
-- the cards drawn headless under the mock: pooled three-line cards that say what NS.CompactCards
-- says, the one-line headers, the stacked detail card inline, Ask, the text size, and
-- every tooltip at the card's top right.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local RING = "|cffa335ee|Hitem:213::|h[Band of Embers]|h|r"
local OLD1 = "|cffa335ee|Hitem:300::|h[Old Band]|h|r"

local NONE = {}

local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { chat = 1 },
        looter = { name = "Seta-Otherrealm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4, track = { name = "Hero", rank = 2, max = 6 } },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = OLD1, ilvl = 292 } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function seed(NS, groups, drops)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Groups = function() return groups end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
end

local GROUP = { key = "enc:3", label = "Commander Ri'mok", kind = "encounter", situation = "dungeon", at = 90,
    drops = { 1, 2 } }

-- The window in the compact layout, two drops shown (View: All).
local function shownCards()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    m.normalizedRealm = "Testrealm"
    local d2 = drop({ id = 2, link = RING, looter = { name = "Littlewolf-Testrealm", guid = "Player-1-0000000B",
        classFile = "ROGUE" }, facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "cantUse", reasons = { { key = "armorType" } } }, them = NONE,
        inspect = { status = "outOfRange" }, trade = { state = "unknown", reasonKey = "noInspect", args = { "outOfRange" } } })
    seed(NS, { GROUP }, { drop(), d2 })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    return NS, NS.WindowGroup.Drawn(), m
end

local function cardFor(drawn, id)
    for _, c in ipairs(drawn.rows) do if c.dropId == id then return c end end
end

local function textOf(region) return region and region:GetText() end

-- A text with its color escapes taken out.
local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function yOf(frame) return select(5, frame:GetPoint(1)) end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

test("compact group: a card is three lines at the text size, about 50 pixels at Default, the icon spanning them", function()
    local CG = T.newAddon().CompactGroup
    local m = CG.Metrics(nil)
    assertEqual(m.size, 10); assertEqual(m.line, 14); assertEqual(m.height, 50); assertEqual(m.icon, 36)
    local big = CG.Metrics(14)
    assertEqual(big.line, 18); assertEqual(big.height, 62); assertEqual(big.icon, 48, "capped")
    assertEqual(CG.Metrics(8).icon, 30)
    assertEqual(CG.LineY(m, 1), -11); assertEqual(CG.LineY(m, 3), -39)
    assertEqual(CG.TextLeft(m), 4 + 2 + 36 + 6)
    assertEqual(CG.HalfX(348, m), 48 + 148, "line 3's second half starts halfway across the text")
end)

test("compact group: switching layouts carries the scroll offset over as a fraction of the range", function()
    local CG = T.newAddon().CompactGroup
    assertEqual(CG.CarryScroll(100, 400, 1000), 250)
    assertEqual(CG.CarryScroll(900, 400, 1000), 1000, "never past the end")
    assertEqual(CG.CarryScroll(50, 0, 1000), 0, "nothing to scroll in the old layout")
    assertEqual(CG.CarryScroll(50, 400, 0), 0, "nothing to scroll in the new one")
    assertEqual(CG.CarryScroll(nil, nil, nil), 0)
end)

test("compact group: the stacked detail card flows its actions into lines and grows by them", function()
    local NS = T.newAddon()
    local DCard, K = NS.DetailCard, NS.Constants.WINDOW
    local wide, lines = DCard.FlowActions(2000)
    assertEqual(lines, 1); assertEqual(wide.trade.x, 92 + 100 + 92 + 96 + 4 * 6)
    assertTrue(wide.hide == nil, "no Hide this item (feedback-4 spec §2)")
    local narrow, n = DCard.FlowActions(324)
    assertEqual(n, 2)
    assertEqual(narrow.ask.line .. narrow.edit.line .. narrow.link.line, "000")
    assertEqual(narrow.retry.line .. narrow.trade.line, "11")
    assertEqual(narrow.retry.x, 0); assertEqual(narrow.trade.x, 96 + 6)
    local P = K.CARD_PAD
    local one = P + K.CARD_ICON + P + 2 * K.SIDE_H + K.TRADE_BOX_H + 3 * P + K.ACTION_H + P
    assertEqual(DCard.StackedHeight(2000), one)
    assertEqual(DCard.StackedHeight(340), one + (K.ACTION_H + 4))
    assertEqual(DCard.ChipsThatFit({ 50, 50, 50 }, 108), 2)
    assertEqual(DCard.ChipsThatFit({ 50, 50 }, 500), 2)
    assertEqual(DCard.ChipsThatFit({}, 10), 0)
end)

-- ── the cards, headless ─────────────────────────────────────────────────────────────────────

test("compact group: one pooled card per drop under a one-line header, each line what CompactCards says", function()
    local NS, drawn = shownCards()
    assertTrue(drawn.compact == true)
    assertEqual(#drawn.headers, 1); assertEqual(#drawn.rows, 2)
    local h = drawn.headers[1]
    assertEqual(textOf(h.text), "Commander Ri'mok · Dungeon · 10s · 2")
    assertTrue(h.tipRow == true)
    local tip = NS.Window.TooltipOf(h)
    assertTrue(#tip >= 3, "the long form and its lines in the tooltip")
    local card = cardFor(drawn, 1)
    assertTrue(card.tipRow == true)
    local c = card.cells
    assertEqual(card:GetHeight(), 50)
    assertEqual(textOf(c.item.text), "Crown of Roaring Storms")
    assertEqual(textOf(c.ilvl.text), "311")
    assertEqual(textOf(card.ask.label), "Ask"); assertTrue(card.ask:IsShown())
    assertEqual(textOf(c.looter.text), "Seta"); assertEqual(textOf(c.looter.glyph), "⊕", "from another realm")
    assertEqual(plain(textOf(c.slot.text)), "· Head"); assertEqual(plain(textOf(c.trade.text)), "· Likely")
    assertEqual(textOf(c.fresh.text), "40s")
    assertEqual(textOf(c.youLabel.text), "You")
    assertEqual(textOf(c.you.glyph) .. " " .. textOf(c.you.text), "▲ +19")
    assertEqual(textOf(c.themLabel.text), "Them")
    assertEqual(textOf(c.them.glyph) .. " " .. textOf(c.them.text), "▽ -13")
    local model = NS.CompactCards.Plain(card.model)
    assertTrue(model[1]:find("Crown of Roaring Storms  311  Ask", 1, true) ~= nil, model[1])
    local other = cardFor(drawn, 2).cells
    assertEqual(textOf(other.looter.glyph), "", "same realm: no mark")
    assertEqual(textOf(other.you.glyph) .. " " .. textOf(other.you.text), "⊘ Can't use")
    assertEqual(textOf(other.fresh.text), "range")
end)

test("compact group: the pieces are colored by quality, class and tone, the worn levels dimmed", function()
    local NS, drawn, m = shownCards()
    local C = NS.Constants
    local c = cardFor(drawn, 1).cells
    local q = m.ITEM_QUALITY_COLORS and m.ITEM_QUALITY_COLORS[4]
    if q then assertEqual(select(1, c.item.text:GetTextColor()), q.r, "the item in its quality color") end
    local good = C.TONE.good
    assertEqual(select(1, c.you.text:GetTextColor()), good.r, "an upgrade for you is green")
    assertEqual(select(2, c.them.glyph:GetTextColor()), C.TONE.red.g, "their downgrade is red, as yours is")
    local muted = C.TONE.muted
    assertEqual(select(1, c.fresh.text:GetTextColor()), muted.r)
    assertEqual(select(1, c.youLabel.text:GetTextColor()), muted.r)
end)

test("compact group: every piece keeps its full-view reason tooltip", function()
    local NS, drawn = shownCards()
    local W = NS.Window
    local c = cardFor(drawn, 1).cells
    local d = drop()
    local Cells = NS.WindowCells
    assertEqual(W.TooltipOf(c.trade.hit)[2], Cells.Trade(d).tip[2])
    assertEqual(W.TooltipOf(c.you.hit)[1], Cells.Me(d).tip[1])
    assertEqual(W.TooltipOf(c.them.hit)[1], "For Seta: Downgrade")
    assertEqual(W.TooltipOf(c.ilvl.hit)[1], "Item level 311")
    local looter = W.TooltipOf(c.looter.hit)
    assertEqual(looter[#looter], "From another realm: Otherrealm.")
    assertEqual(W.TooltipOf(c.fresh.hit)[1], "Inspect of Seta")
    assertEqual(#W.TooltipOf(c.item.hit), 0, "the item shows the game's own tooltip instead")
    assertTrue(c.item.hit.showItem == true)
    assertTrue(cardFor(drawn, 1).dismiss == nil, "no dismiss mark (feedback-4 spec §2)")
end)

-- The window at 200..580, its top at 800, on a 1920-wide screen; a 320-wide tooltip.
local function placeWindow(NS, m)
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 580 end
    win.GetTop = function() return 800 end
    m.UIParent.GetWidth = function() return 1920 end
    m.GameTooltip.GetWidth = function() return 320 end
    return win
end

test("compact group: every tooltip opens at the card's top right, just outside the window", function()
    local NS, drawn, m = shownCards()
    local win = placeWindow(NS, m)
    local card = cardFor(drawn, 1)
    card.GetTop = function() return 600 end
    local K = NS.Constants.WINDOW
    local frames = { card.cells.trade.hit, card.cells.you.hit, card.cells.slot.hit, card.cells.ilvl.hit, card.icon,
        card.cells.item.hit }
    card.ask.tipLines = { "Ask", "why" }
    frames[#frames + 1] = card.ask
    for i, f in ipairs(frames) do
        m.GameTooltip.__points = {}
        f:__fire("OnEnter")
        local point, rel, relPoint, x, y = m.GameTooltip:GetPoint(1)
        assertEqual(tostring(point) .. ">" .. tostring(relPoint), "BOTTOMLEFT>TOPRIGHT", "piece " .. i)
        assertTrue(rel == win, "piece " .. i .. ": beside the window")
        assertEqual(x, K.TIP_GAP); assertEqual(y, -200, "piece " .. i .. ": level with the card's top")
    end
end)

test("compact group: a card click opens the stacked detail card under it; the cards below move down", function()
    local NS, drawn = shownCards()
    local DCard = NS.DetailCard
    assertFalse(drawn.card:IsShown())
    assertTrue(drawn.card.stacked == true, "the compact pane's own card, stacked")
    local below = yOf(cardFor(drawn, 1)) < yOf(cardFor(drawn, 2)) and 1 or 2
    local top = below == 2 and 1 or 2
    local before = yOf(cardFor(drawn, below))
    cardFor(drawn, top):__fire("OnClick", "LeftButton")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.card:IsShown()); assertEqual(drawn.cardDropId, top)
    assertTrue(cardFor(drawn, top).selected:IsShown())
    local width = drawn.card:GetWidth()
    local h = DCard.StackedHeight(width)
    assertEqual(drawn.card:GetHeight(), h)
    assertEqual(yOf(drawn.card), yOf(cardFor(drawn, top)) - 50 - 2, "right under its card")
    assertEqual(yOf(cardFor(drawn, below)), before - h - 2, "the next card moves down")
    -- stacked: For the looter under For you, the trade box under both, all the card's width
    local _, rel = drawn.card.them:GetPoint(1)
    assertTrue(rel == drawn.card.me, "the comparisons stack")
    assertEqual(drawn.card.me:GetWidth(), width - 2 * NS.Constants.WINDOW.CARD_PAD)
    cardFor(drawn, below).cells.slot.hit:__fire("OnMouseUp", "LeftButton")
    assertEqual(NS.WindowGroup.Drawn().cardDropId, below, "a piece click is a card click; one at a time")
    NS.ToggleWindowMode()
    assertEqual(NS.WindowGroup.Drawn().cardDropId, below, "the full layout keeps the open card")
end)

test("compact group: Ask presses the ask; no card can be dismissed", function()
    local NS, drawn = shownCards()
    local asked
    NS.PressAsk = function(id) asked = id end
    cardFor(drawn, 1).ask:__fire("OnClick")
    assertEqual(asked, 1)
    assertTrue(cardFor(drawn, 2).dismiss == nil); assertTrue(NS.DismissDrop == nil)
end)

test("compact group: an ask in flight shows the full table's state; no ask offered shows the dash and why", function()
    local NS, _ = shownCards()
    NS.Asks.StateOf = function() return "sent" end
    NS.Window.Refresh()
    local card = cardFor(NS.WindowGroup.Drawn(), 1)
    assertEqual(textOf(card.ask.label), "Asked")
    assertTrue(card.ask.art:IsShown(), "with its icon")
    seed(NS, { GROUP }, { drop({ trade = { state = "no", reasonKey = "legacy", basis = "rule" } }) })
    NS.Window.Refresh()
    card = cardFor(NS.WindowGroup.Drawn(), 1)
    assertFalse(card.ask:IsShown()); assertTrue(card.dash:IsShown())
    assertEqual(textOf(card.dash), "–")
    assertEqual(NS.Window.TooltipOf(card.dashTip)[1], "No ask")
end)

test("compact group: the text follows the Font size row and the card's height follows the text", function()
    local NS = shownCards()
    NS.addon.db.profile.window.fontSize = 14
    NS.Window.Refresh()
    local card = NS.WindowGroup.Drawn().rows[1]
    assertEqual(card:GetHeight(), 62)
    assertEqual(select(2, card.cells.trade.text:GetFont()), 14)
    assertEqual(select(2, card.cells.you.glyph:GetFont()), 14, "the glyph face too")
    assertEqual(card.icon:GetWidth(), 48)
end)

test("compact group: cards are pooled: a repaint reuses them and builds none", function()
    local NS, drawn = shownCards()
    local first = drawn.rows[1]
    local pool = drawn.pane.compactView.cardPool
    NS.Window.Refresh()
    NS.Window.Refresh()
    local free, active = NS.Pool.Counts(pool)
    assertEqual(free + active, 2, "two cards ever built")
    assertTrue(NS.WindowGroup.Drawn().rows[1] == first)
end)

test("compact group: a header click collapses its group, and the filters' line and empty state still show", function()
    local NS, drawn = shownCards()
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 0); assertEqual(#drawn.headers, 1)
    NS.WindowFilterBar.Set("group", "search", "nobody")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.headers, 0)
    assertTrue(drawn.pane.placeholder:IsShown())
    assertFalse(drawn.pane.colHead:IsShown(), "no column labels in the compact layout")
end)

test("compact group: test mode fills a card for every sample, no piece blank, and each opens its card", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == true)
    assertTrue(#drawn.rows >= 6, "the samples, as cards: " .. #drawn.rows)
    for _, card in ipairs(drawn.rows) do
        local c = card.cells
        for _, key in ipairs({ "item", "ilvl", "looter", "slot", "trade", "fresh", "you", "them" }) do
            local t = textOf(c[key].text)
            assertTrue(t ~= nil and t ~= "", "card " .. tostring(card.dropId) .. ": " .. key)
        end
        assertTrue(card.ask:IsShown() or card.dash:IsShown(), "Ask or its dash")
    end
    for _, card in ipairs(drawn.rows) do NS.WindowGroup.ToggleExpand(card.dropId) end
    assertTrue(NS.WindowGroup.Drawn().card:IsShown(), "the last one opened")
end)

-- ── the expand indicator and the indent (feedback-5 spec §0) ────────────────────────────────

local function xOf(frame) return select(4, frame:GetPoint(1)) end

test("compact group: each card is indented under its header and draws the row chevron on line 1, before the icon", function()
    local NS, drawn = shownCards()
    local K, C, CG = NS.Constants.WINDOW, NS.Constants, NS.CompactGroup
    local card, h = cardFor(drawn, 1), drawn.headers[1]
    assertEqual(xOf(h), 0); assertEqual(xOf(card), K.ROW_INDENT)
    assertEqual(card:GetWidth(), h:GetWidth() - K.ROW_INDENT)
    local ch = card.chevron
    assertEqual(ch:GetTexture(), NS.Icon("chevron-down"))
    local m = CG.Metrics(nil)
    local p = ch.__points[1]
    assertEqual(p[1] .. "," .. p[3], "LEFT,TOPLEFT"); assertEqual(p[2], card)
    assertEqual(p[4], CG.PAD + CG.QUALITY_W, "after the quality bar"); assertEqual(p[5], CG.LineY(m, 1), "centered on line 1")
    assertEqual(select(4, card.icon:GetPoint(1)), p[4] + K.ROW_CHEVRON + K.CHEVRON_GAP, "the icon after it and a gap")
    assertEqual(select(4, ch:GetVertexColor()), C.CHEVRON_ROW.a, "muted white")
    assertEqual(CG.TextLeft(m, CG.LEAD), CG.TextLeft(m) + K.ROW_CHEVRON + K.CHEVRON_GAP)
    assertEqual(card.ask:GetWidth(), K.ASK_W, "the full table's Ask width")
end)

test("compact group: the open card's chevron points up and its detail card indents with it; the header chevron is gold", function()
    local NS, drawn = shownCards()
    local K, G = NS.Constants.WINDOW, NS.Constants.GOLD
    assertEqual(select(2, drawn.headers[1].chevron:GetVertexColor()), G.g, "gold header chevron")
    cardFor(drawn, 2):__fire("OnClick", "LeftButton")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(cardFor(drawn, 2).chevron:GetTexture(), NS.Icon("chevron-up"))
    assertEqual(cardFor(drawn, 1).chevron:GetTexture(), NS.Icon("chevron-down"))
    assertEqual(xOf(drawn.card), K.ROW_INDENT)
end)
