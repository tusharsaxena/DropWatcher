-- tests/test_compact_group.lua — the Drops tab in the compact layout (compact spec §2, DW-C2):
-- the card's metrics and the scroll carry-over (pure), the stacked detail card's flow (pure), then
-- the cards drawn headless under the mock: pooled three-line cards that say what NS.CompactCards
-- says, the one-line headers, the stacked detail card inline, Ask, the text size, and
-- every tooltip at the card's top right; last, line 2 at its fullest fits the least width.

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

test("compact group: a card is four lines at the text size, about 64 pixels at Default, the icon spanning them", function()
    local CG = T.newAddon().CompactGroup
    local m = CG.Metrics(nil)
    assertEqual(m.size, 10); assertEqual(m.line, 14); assertEqual(m.height, 64); assertEqual(m.icon, 50)
    local big = CG.Metrics(14)
    assertEqual(big.line, 18); assertEqual(big.height, 80); assertEqual(big.icon, 60, "capped")
    assertEqual(CG.Metrics(8).icon, 42)
    assertEqual(CG.LineY(m, 1), -11); assertEqual(CG.LineY(m, 3), -39); assertEqual(CG.LineY(m, 4), -53)
    assertEqual(CG.TextLeft(m), 4 + 2 + 50 + 6)
    assertTrue(CG.HalfX == nil, "Them follows You, not half the card's width (feedback-10 spec §2)")
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
    assertEqual(textOf(h.text), "Commander R… · Dungeon · 10s · 2")
    -- red under: a header text left at the game's default CENTER, centered across the sized line
    assertEqual(h.text:GetJustifyH(), "LEFT", "the header reads from the left")
    assertTrue(h.tipRow == true)
    local tip = NS.Window.TooltipOf(h)
    assertTrue(#tip >= 3, "the long form and its lines in the tooltip")
    local card = cardFor(drawn, 1)
    assertTrue(card.tipRow == true)
    local c = card.cells
    assertEqual(card:GetHeight(), 64)
    assertEqual(textOf(c.item.text), "Crown of Roaring Storms")
    assertEqual(textOf(c.ilvl.text), "311")
    assertEqual(textOf(card.ask.label), "Ask"); assertTrue(card.ask:IsShown())
    assertEqual(textOf(c.looter.text), "Seta"); assertTrue(c.looter.glyph == nil, "no ⊕ after another realm's looter")
    assertEqual(plain(textOf(c.slot.text)), "· Head")
    assertEqual(textOf(c.tradeLabel.text), "Trade"); assertEqual(textOf(c.trade.text), "Yes |cffb3b3b8Not their upgrade|r", "line 4, labeled: the word, then its reason in the muted gray")
    assertEqual(textOf(c.fresh.text), "(40s)", "in brackets (feedback-10 spec §2)")
    assertEqual(textOf(c.youLabel.text), "You")
    assertEqual(textOf(c.you.glyph) .. textOf(c.you.text), "▲19")
    assertEqual(textOf(c.themLabel.text), "Them")
    assertEqual(textOf(c.them.glyph) .. textOf(c.them.text), "▼13")
    assertEqual(textOf(c.you.level), "empty", "nothing worn there (the mock's gear), before the verdict")
    assertEqual(c.you.level.__points[1][2], c.youLabel.text, "the level after the label")
    assertEqual(c.you.glyph.__points[1][2], c.you.level, "the glyph after the level")
    assertEqual(c.you.text.__points[1][2], c.you.glyph, "the difference after the glyph")
    local model = NS.CompactCards.Plain(card.model)
    assertEqual(model[1], "311 Crown of Roaring Storms (40s)")
    assertEqual(model[2]:sub(-5), "  Ask", model[2])
    -- feedback-10 spec §2: the level then the name on line 1, the freshness at its right; the button
    -- at line 2's right; Them a fixed gap after You's last piece.
    local m3 = NS.CompactGroup.Metrics(nil)
    local CG = NS.CompactGroup
    local p = c.ilvl.text.__points[1]
    assertEqual(p[1], "LEFT"); assertEqual(p[2], card); assertEqual(p[4], CG.TextLeft(m3, CG.LEAD)); assertEqual(p[5], CG.LineY(m3, 1))
    p = c.item.text.__points[1]
    assertEqual(p[2], c.ilvl.text); assertEqual(p[3], "RIGHT"); assertEqual(p[4], CG.ILVL_GAP, "the name right after the level")
    assertTrue(c.item.text.__points[2] == nil, "one anchor: the name's width is set, not stretched")
    p = c.fresh.text.__points[1]
    assertEqual(p[1], "LEFT"); assertEqual(p[2], c.item.text); assertEqual(p[3], "RIGHT", "the freshness right after the name")
    p = card.ask.__points[1]
    assertEqual(p[1], "RIGHT"); assertEqual(p[2], card)
    assertEqual(p[5], -(CG.PAD + 2 * m3.line), "the button spans lines 2 and 3, centered between them (feedback-23)")
    assertEqual(card.ask:GetHeight(), 2 * m3.line, "two lines tall")
    assertEqual(card.ask.label.__points[1][1], "CENTER", "its label centered")
    p = c.themLabel.text.__points[1]
    assertEqual(p[2], c.you.text); assertEqual(p[3], "RIGHT"); assertEqual(p[4], CG.HALVES_GAP)
    assertTrue(card.cells.countdown == nil and card.bar == nil, "no trade window on the card")
    local other = cardFor(drawn, 2).cells

    assertEqual(textOf(other.you.glyph) .. " " .. textOf(other.you.text), "⊘ Can't use")
    assertEqual(textOf(other.them.level), "range", "the gear part says why")
    assertEqual(textOf(other.them.text), "", "so the ? goes")
    assertEqual(textOf(other.fresh.text), "(range)")
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
    assertEqual(select(2, c.youLabel.text:GetTextColor()), C.GOLD.g, "You in gold (feedback-10 spec §2)")
    assertEqual(select(2, c.themLabel.text:GetTextColor()), C.GOLD.g, "Them in gold")
end)

test("compact group: every piece keeps its full-view reason tooltip", function()
    local NS, drawn = shownCards()
    local W = NS.Window
    local c = cardFor(drawn, 1).cells
    local d = drop()
    local Cells = NS.WindowCells
    assertEqual(W.TooltipOf(c.trade.hit)[2], Cells.Trade(d).tip[2])
    local you, them = W.TooltipOf(c.you.hit), W.TooltipOf(c.them.hit)
    assertEqual(you[1], Cells.Me(d).tip[1], "the verdict's title first, then the gear grid (feedback-7 spec §3)")
    assertTrue(NS.TipMarks.IsGrid(you[2]), "the worn gear as a grid")
    local function has(tip, line)
        for _, l in ipairs(tip) do if l == line then return true end end
        return false
    end
    assertTrue(has(you, Cells.Me(d).tip[1]), "then the verdict's")
    assertTrue(has(them, "For Seta: Downgrade"))
    assertEqual(W.TooltipOf(c.ilvl.hit)[1], "Item level 311")
    local looter = W.TooltipOf(c.looter.hit)
    assertEqual(T.tipPlain(looter[#looter]), "• Realm: Otherrealm")
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
    assertEqual(yOf(drawn.card), yOf(cardFor(drawn, top)) - 64 - 2, "right under its card")
    assertEqual(yOf(cardFor(drawn, below)), before - h - 2, "the next card moves down")
    -- stacked: the trade box first (feedback-22), For you under it, For the looter under For you, all the card's width
    local _, rel = drawn.card.them:GetPoint(1)
    assertTrue(rel == drawn.card.me, "the comparisons stack")
    local _, meRel = drawn.card.me:GetPoint(1)
    assertTrue(meRel == drawn.card.trade, "For you under the trade box")
    local _, tradeRel = drawn.card.trade:GetPoint(1)
    assertTrue(tradeRel == drawn.card, "the trade box right under the header")
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

test("compact group: an ask in flight shows the full table's state; no ask offered shows No action and why", function()
    local NS, _ = shownCards()
    local ready = cardFor(NS.WindowGroup.Drawn(), 1).ask
    assertTrue(ready.art:IsShown() and ready.art:GetTexture() == NS.Icon("chat"), "Ask wears chat (feedback-7 spec §1)")
    NS.Asks.StateOf = function() return "sent" end
    NS.Window.Refresh()
    local card = cardFor(NS.WindowGroup.Drawn(), 1)
    assertEqual(textOf(card.ask.label), "Asked")
    assertTrue(card.ask.art:IsShown(), "with its icon")
    seed(NS, { GROUP }, { drop({ trade = { state = "no", reasonKey = "legacy", basis = "rule" } }) })
    NS.Window.Refresh()
    card = cardFor(NS.WindowGroup.Drawn(), 1)
    assertTrue(card.ask:IsShown()); assertTrue(card.dash == nil and card.dashTip == nil, "a button, no dash (feedback-11 spec §1)")
    assertEqual(textOf(card.ask.label), "No action"); assertFalse(card.ask:IsEnabled()); assertEqual(card.ask.tone, "bad")
    assertEqual(NS.Window.TooltipOf(card.ask)[1], "No action", "its reason in the tooltip")
end)

test("compact group: the text follows the Font size row and the card's height follows the text", function()
    local NS = shownCards()
    NS.addon.db.profile.window.fontSize = 14
    NS.Window.Refresh()
    local card = NS.WindowGroup.Drawn().rows[1]
    assertEqual(card:GetHeight(), 80)
    assertEqual(select(2, card.cells.trade.text:GetFont()), 14)
    assertEqual(select(2, card.cells.you.glyph:GetFont()), 14, "the glyph face too")
    assertEqual(card.icon:GetWidth(), 60)
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
    for _, g in ipairs(NS.LootFeed.Groups("test")) do NS.State.windowGroup.collapsed[g.key] = false end
    NS.Window.Refresh()
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == true)
    assertEqual(#drawn.rows, #NS.LootFeed.Drops("test"), "the samples, as cards, every group opened")
    for _, card in ipairs(drawn.rows) do
        local c = card.cells
        for _, key in ipairs({ "item", "ilvl", "looter", "slot", "trade", "you", "them" }) do
            local t = textOf(c[key].text)
            if c[key].level then t = textOf(c[key].level) .. (t or "") end   -- a half: its gear, then its verdict
            assertTrue(t ~= nil and t ~= "", "card " .. tostring(card.dropId) .. ": " .. key)
        end
        -- The freshness is left out where there is nothing to say, never a placeholder (feedback-10 spec §2).
        local mark = NS.CompactCards.FreshMark(card.model.fresh)
        assertEqual(textOf(c.fresh.text), mark or "", "card " .. tostring(card.dropId) .. ": fresh")
        assertEqual(c.fresh.text:IsShown(), mark ~= nil)
        assertTrue(card.ask:IsShown(), "Ask, Offer or No action: never an empty slot (feedback-11 spec §1)")
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

-- ── no trade window on the card (feedback-10 spec §2) ───────────────────────────────────────

test("compact group: no card shows a trade window; every card keeps its freshness on line 1", function()
    local NS, _, m = T.enableAddon()
    NS.addon.db.char = { session = { start = m.time() - 86400 } }   -- logged in a day ago: these drops are this session's (feedback-15 spec §1)
    m.__now = 100
    local group = { key = "enc:3", label = "Commander Ri'mok", kind = "encounter", situation = "dungeon", at = 90,
        drops = { 1, 2, 3 } }
    seed(NS, { group }, { drop(), drop({ id = 2, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
        drop({ id = 3, at = 100 - 7000 }) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    for id = 1, 3 do
        local card = cardFor(drawn, id)
        assertTrue(card.cells.countdown == nil and card.bar == nil and card.barBg == nil, id .. ": no countdown or bar")
        assertTrue(card.cells.fresh.text:IsShown(), id .. ": the freshness shows")
        assertEqual(textOf(card.cells.fresh.text), "(40s)")
    end
    assertFalse(NS.WindowGroup.LiveCountdown(), "nothing on the cards ticks; nothing of yours on the strip")
end)

test("compact group: a second's tick leaves the cards as they are", function()
    local NS, drawn, m = shownCards()
    local before = NS.CompactCards.Plain(cardFor(drawn, 1).model)
    m.advance(1)
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    local after = NS.CompactCards.Plain(cardFor(NS.WindowGroup.Drawn(), 1).model)
    assertEqual(table.concat(after, "|"), table.concat(before, "|"))
end)

-- ── the least width (feedback-5 spec §4) ────────────────────────────────────────────────────

-- Line 2 at its fullest: a twelve-letter looter (the game's longest name) with slot, type and trade on
-- the left, the action button on the right (feedback-10 spec §2). Measured at 5px a character (the
-- small template's average; a color code takes no room), the left pieces end a gap before the button
-- at COMPACT_MIN_W, on another player's two-hander from another realm and on your own counted drop.
local function cand(name, gain)
    return { guid = "Player-1-" .. name, name = name .. "-Testrealm", classFile = "MAGE", status = "ready",
        eval = { verdict = "upgrade", ilvlDelta = gain, baseline = { ilvl = 280 }, reasons = {} } }
end

local FULLEST = {
    theirs = { looter = { name = "Bloodthornxx-Otherrealm", guid = "Player-1-0000000A", classFile = "WARRIOR" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_2HWEAPON", quality = 4 } },
    yours = { isMine = true, looter = { name = "Bloodthornyy-Testrealm", guid = "Player-1-ME", classFile = "PALADIN",
        isSelf = true }, facts = { ilvl = 311, equipLoc = "INVTYPE_SHOULDER", quality = 4, classID = 4,
        subClassID = 4 }, me = { verdict = "downgrade", ilvlDelta = -9, reasons = {} },
        candidates = { a = cand("Seta", 4), b = cand("Butterz", 11), c = cand("Vaela", 2) } },
}

test("compact group: at the least width line 2's pieces end before the action button", function()
    for which, over in pairs(FULLEST) do
        local NS, _, m = T.enableAddon()
        local K, CG = NS.Constants.WINDOW, NS.CompactGroup
        m.__now = 100
        m.normalizedRealm = "Testrealm"
        m.textCharWidth = 5
        seed(NS, { GROUP }, { drop(over) })
        NS.WindowFilterBar.Set("group", "view", "all")
        NS.SetWindowMode("compact")
        NS.ShowWindow()
        assertEqual(NS.Window.Frame():GetWidth(), K.COMPACT_MIN_W)
        local card = cardFor(NS.WindowGroup.Drawn(), 1)
        local c = card.cells
        local function w(fs)   -- the visible characters' width (a UTF-8 glyph is one)
            local s = (fs:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("[\128-\191]", "")
            return #s * m.textCharWidth
        end
        assertTrue(card.ask:IsShown(), which .. ": the button shows")
        local leftEnd = CG.TextLeft(CG.Metrics(nil), CG.LEAD) + w(c.looter.text)
            + 4 + w(c.slot.text) + 4 + w(c.armorType.text)
        local rightStart = card:GetWidth() - CG.PAD - K.ASK_W
        assertTrue(leftEnd + 4 <= rightStart,
            ("%s: line 2 ends at %d, the button starts at %d"):format(which, leftEnd, rightStart))
    end
end)

-- Line 3 at its fullest (feedback-6 spec §1): both halves on a trinket, two worn levels each
-- (`321/308`), then ⊘ and the longest word (`Not wanted`). Measured as line 2 is: You ends before
-- the action button (lines 2 and 3's since feedback-23); Them does not fit after it there, so it
-- starts line 4 under You's label and ends inside the card, Trade CG.HALVES_GAP after it.
test("compact group: at the least width line 3's fullest halves fit, Them on line 4 when not beside You", function()
    local NS, _, m = T.enableAddon()
    local K, CG = NS.Constants.WINDOW, NS.CompactGroup
    m.__now = 100
    m.textCharWidth = 5
    local unwanted = { verdict = "doesntWant", reasons = { { key = "undesired" } } }
    local trinkets = { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD1, ilvl = 308 } }
    seed(NS, { GROUP }, { drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_TRINKET", quality = 4 }, me = unwanted,
        them = unwanted, trade = { state = "unknown", reasonKey = "noInspect", basis = "inspect", args = { "pending" } } }) })
    NS.Gear.Snapshot = function() return { equipped = trinkets } end
    NS.Inspect.Get = function() return { status = "fresh", at = 60, gear = trinkets } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    assertEqual(NS.Window.Frame():GetWidth(), K.COMPACT_MIN_W)
    local card = cardFor(NS.WindowGroup.Drawn(), 1)
    local c = card.cells
    local function w(fs)   -- the visible characters' width (a UTF-8 glyph is one, a color escape none)
        local t = (fs:GetText() or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return #(t:gsub("[\128-\191]", "")) * m.textCharWidth
    end
    local function halfEnd(key, x)
        local h = c[key]
        return x + w(c[key .. "Label"].text) + CG.HALF_GAP + w(h.level) + CG.HALF_GAP + w(h.glyph)
            + CG.HALF_GLYPH_GAP + w(h.text)
    end
    assertEqual(NS.CompactCards.HalfText(card.model.you), "You 321/308 ⊘ Not wanted")
    assertEqual(NS.CompactCards.HalfText(card.model.them), "Them 321/308 ⊘ Not wanted")
    local m3 = CG.Metrics(nil)
    local x = CG.TextLeft(m3, CG.LEAD)
    local youEnd = halfEnd("you", x)
    local buttonAt = card:GetWidth() - CG.PAD - K.ASK_W
    assertTrue(youEnd + CG.ASK_GAP <= buttonAt, ("You ends at %d, the button at %d"):format(youEnd, buttonAt))
    -- Trade's last piece is bounded at the card's right inset, cut there rather than past it (feedback-11 spec §0).
    local rp = c.trade.text.__points[2]
    assertEqual(rp[1], "RIGHT"); assertEqual(rp[2], card); assertEqual(rp[4], -CG.PAD)
    assertTrue(c.you.text.__points[2] == nil, "You is not bounded")
    -- Line 4: Them under You's label, a line down, then Trade after Them's last piece (feedback-23).
    local tp = c.themLabel.text.__points[1]
    assertEqual(tp[2], c.youLabel.text); assertEqual(tp[4], 0); assertEqual(tp[5], -m3.line)
    tp = c.tradeLabel.text.__points[1]
    assertEqual(tp[2], c.them.text); assertEqual(tp[3], "RIGHT"); assertEqual(tp[4], CG.HALVES_GAP)
    local themEnd = halfEnd("them", x)
    assertEqual(NS.CompactCards.HalfText(card.model.trade), "Trade ? Not inspected")
    local tradeEnd = themEnd + CG.HALVES_GAP + w(c.tradeLabel.text) + CG.HALF_GAP + w(c.trade.text)
    assertTrue(tradeEnd <= card:GetWidth() - CG.PAD, ("Trade ends at %d, the card at %d"):format(tradeEnd,
        card:GetWidth() - CG.PAD))
end)

-- Line 3 with two dual marks (feedback-21 H7): both halves on trinkets read in full, each worn item's
-- level, glyph and two-digit difference, `You 321 ▼10 / 324 ▼13`. The first part and its `/` sit
-- between the label and the single pieces. At the least width You ends before the action button
-- (lines 2 and 3's, feedback-23) and Them, not fitting after it, starts line 4 under You's label and
-- ends inside the card: both rings read on both halves, never the one mark.
test("compact group: at the least width line 3's two dual marks fit, each worn item its own mark (H7)", function()
    local NS, _, m = T.enableAddon()
    local K, CG, C = NS.Constants.WINDOW, NS.CompactGroup, NS.Constants
    m.__now = 100
    m.textCharWidth = 5
    local down = { verdict = "downgrade", ilvlDelta = -10, either = true, reasons = {} }   -- judged against the lower, 321
    local trinkets = { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD1, ilvl = 324 } }
    seed(NS, { GROUP }, { drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_TRINKET", quality = 4 }, me = down,
        them = down, trade = { state = "unknown", reasonKey = "noInspect", basis = "inspect", args = { "pending" } } }) })
    NS.Gear.Snapshot = function() return { equipped = trinkets } end
    NS.Inspect.Get = function() return { status = "fresh", at = 60, gear = trinkets } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    assertEqual(NS.Window.Frame():GetWidth(), K.COMPACT_MIN_W)
    local card = cardFor(NS.WindowGroup.Drawn(), 1)
    local c = card.cells
    assertEqual(NS.CompactCards.HalfText(card.model.you), "You 321 ▼10 / 324 ▼13")
    assertEqual(NS.CompactCards.HalfText(card.model.them), "Them 321 ▼10 / 324 ▼13")
    local you = c.you
    assertEqual(you.leadLevel:GetText(), "321"); assertEqual(you.leadGlyph:GetText(), "▼"); assertEqual(you.leadText:GetText(), "10")
    assertEqual(you.sep:GetText(), "/"); assertEqual(you.level:GetText(), "324"); assertEqual(you.text:GetText(), "13")
    assertEqual(you.leadLevel.__points[1][2], c.youLabel.text, "the first part after the label")
    assertEqual(you.level.__points[1][2], you.sep, "the second part after the separator")
    assertEqual(select(2, you.leadText:GetTextColor()), C.TONE.red.g, "each part in its tone")
    local tp = c.themLabel.text.__points[1]
    assertEqual(tp[2], c.youLabel.text, "Them under You's label (feedback-23)"); assertEqual(tp[5], -CG.Metrics(nil).line)
    assertEqual(c.them.sep:GetText(), "/", "Them keeps both rings")
    local function w(fs) return #((fs:GetText() or ""):gsub("[\128-\191]", "")) * m.textCharWidth end
    local function halfEnd(key, x)
        local h = c[key]
        return x + w(c[key .. "Label"].text) + CG.HALF_GAP + w(h.leadLevel) + CG.HALF_GAP + w(h.leadGlyph)
            + CG.HALF_GLYPH_GAP + w(h.leadText) + CG.HALF_GAP + w(h.sep) + CG.HALF_GAP + w(h.level) + CG.HALF_GAP
            + w(h.glyph) + CG.HALF_GLYPH_GAP + w(h.text)
    end
    local x = CG.TextLeft(CG.Metrics(nil), CG.LEAD)
    local youEnd, buttonAt = halfEnd("you", x), card:GetWidth() - CG.PAD - K.ASK_W
    assertTrue(youEnd + CG.ASK_GAP <= buttonAt, ("You ends at %d, the button at %d"):format(youEnd, buttonAt))
    local themEnd = halfEnd("them", x)
    assertTrue(themEnd <= card:GetWidth() - CG.PAD, ("Them ends at %d, the card at %d"):format(themEnd,
        card:GetWidth() - CG.PAD))
end)

-- feedback-21 R5: at a larger Font size line 3's dual marks would push You into the action button
-- at the least width, Them moved to line 4 or not (feedback-23); they give way to the one mark each,
-- and the line reads as before H7.
test("compact group: line 3's dual marks that do not fit the card are the one mark instead (R5)", function()
    local NS, _, m = T.enableAddon()
    m.__now = 100
    m.textCharWidth = 14
    local down = { verdict = "downgrade", ilvlDelta = -10, either = true, reasons = {} }
    local trinkets = { [13] = { link = OLD1, ilvl = 321 }, [14] = { link = OLD1, ilvl = 324 } }
    seed(NS, { GROUP }, { drop({ facts = { ilvl = 311, equipLoc = "INVTYPE_TRINKET", quality = 4 }, me = down,
        them = down, trade = { state = "unknown", reasonKey = "noInspect", basis = "inspect", args = { "pending" } } }) })
    NS.Gear.Snapshot = function() return { equipped = trinkets } end
    NS.Inspect.Get = function() return { status = "fresh", at = 60, gear = trinkets } end
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    local card = cardFor(NS.WindowGroup.Drawn(), 1)
    local c = card.cells
    assertTrue(card.model.you.parts ~= nil, "the model keeps the dual mark")
    for _, key in ipairs({ "you", "them" }) do
        local h = c[key]
        assertFalse(h.sep:IsShown() or h.leadLevel:IsShown(), key .. ": no lead pieces")
        assertEqual(h.level:GetText(), "321/324"); assertEqual(h.glyph:GetText(), "▼"); assertEqual(h.text:GetText(), "10")
        assertEqual(h.level.__points[1][2], c[key .. "Label"].text, key .. ": the level after the label")
    end
end)
