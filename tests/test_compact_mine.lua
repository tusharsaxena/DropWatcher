-- tests/test_compact_mine.lua — the My drops tab in the compact layout and the Offer panel beside the
-- compact window (compact spec §3, DW-C3): the candidates' colored line and the short summary
-- (pure), then the cards drawn headless under the mock: one pooled three-line card per row under a
-- one-line header, the countdown and its bar, Offer and Announce through the full table's
-- handlers, the shortened strip, every tooltip at the card's top right, and the panel docked beside
-- the compact window on whichever side has room.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local TRINKET = "|cffa335ee|Hitem:403::|h[Idol of Storms]|h|r"
local BOOTS = "|cffa335ee|Hitem:404::|h[Treads of Dawn]|h|r"

local NOW = 1000

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

local function candidates()
    local list = {
        cand("Seta", "PRIEST", "ready", { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291 }, reasons = {} }),
        cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { ilvl = 299 }, reasons = {} }),
        cand("Littlewolf", "ROGUE", "ready", { verdict = "sidegrade", ilvlDelta = 0, baseline = { ilvl = 305 }, reasons = {} }),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function drop(over)
    local d = {
        id = 1, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = candidates(),
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local function boardDrops()
    return {
        drop(),
        drop({ id = 3, at = NOW - 2000, link = TRINKET, facts = { ilvl = 305, equipLoc = "INVTYPE_TRINKET", quality = 4 },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 } }),
        drop({ id = 4, at = NOW - 100, link = BOOTS, facts = { ilvl = 311, equipLoc = "INVTYPE_FEET", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 6, reasons = {} },
            trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
    }
end

local function seed(NS, drops, groups)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.LootFeed.Groups = function() return groups or {} end
end

local GROUP = { key = "Den of Nalorakk", label = "Den of Nalorakk", kind = "encounter", at = NOW - 3000,
    drops = { 1, 3, 4 }, instance = "Zul'Aman", difficulty = "Heroic", seenBy = "Me-Realm", seenByClass = "PALADIN" }

-- My drops in the compact layout.
local function shownCompact()
    local NS, _, m = T.enableAddon()
    m.__now = NOW
    seed(NS, boardDrops(), { GROUP })
    NS.Asks.StateOf = function() return "ready" end
    NS.TradeHelper.CanGive = function() return false, "range" end
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    NS.Window.SelectTab("mine")
    return NS, NS.WindowMine.Drawn(), m
end

local function cardFor(drawn, id)
    for _, c in ipairs(drawn.rows) do if c.dropId == id then return c end end
end

local function textOf(region) return region and region:GetText() end

local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

test("compact mine: the candidates read in class colors, then +n more; nobody named keeps the cell's text", function()
    local CM = T.newAddon().CompactMine
    local colors = { PRIEST = { 1, 1, 1 }, MAGE = { 0.25, 0.78, 0.92 } }
    local colorOf = function(cf) local c = colors[cf]; if c then return c[1], c[2], c[3] end end
    local c = { text = "Seta +14 · Butterz +6", parts = { { text = "Seta +14", classFile = "PRIEST" },
        { text = "Butterz +6", classFile = "MAGE" }, { text = "Odd +2", classFile = "NONE" } }, more = "+1 more" }
    local text, colored = CM.CandidatesText(c, colorOf)
    assertTrue(colored)
    assertEqual(text, "|cffffffffSeta +14|r · |cff40c7ebButterz +6|r · Odd +2 · +1 more")
    local none, col = CM.CandidatesText({ text = "No upgrade for anyone", parts = {} }, colorOf)
    assertEqual(none, "No upgrade for anyone"); assertFalse(col)
end)

test("compact mine: the strip's summary is shortened", function()
    local CM = T.newAddon().CompactMine
    assertEqual(CM.SummaryText({ count = 3, next = 521 }), "3 tradeable · next 0:08:41")
    assertEqual(CM.SummaryText({ count = 1 }), "1 tradeable")
    assertEqual(CM.SummaryText({ count = 0 }), "0 tradeable")
end)

test("compact mine: the Offer panel keeps its own least height beside the compact window", function()
    local NS = T.newAddon()
    local K = NS.Constants.WINDOW
    assertEqual(NS.OfferPanel.CompactHeight(220), K.OFFER_MIN_H)
    assertEqual(NS.OfferPanel.CompactHeight(700), 700)
    assertEqual(NS.OfferPanel.CompactHeight(nil), K.OFFER_MIN_H)
end)

-- ── the cards, headless ─────────────────────────────────────────────────────────────────────

test("compact mine: one pooled card per drop of yours under a one-line header, each line what CompactCards says", function()
    local NS, drawn = shownCompact()
    assertTrue(drawn.compact == true)
    assertEqual(#drawn.headers, 1); assertEqual(#drawn.rows, 3)
    assertFalse(drawn.pane.scroll:IsShown(), "the table is hidden"); assertTrue(drawn.scroll:IsShown())
    assertFalse(drawn.pane.colHead:IsShown(), "no column labels")
    local h = plain(textOf(drawn.headers[1].text))
    assertTrue(h:find("Zul'Aman · Den of Nalorakk · Heroic · 50m · 3", 1, true) == 1, h)
    assertTrue(h:find("drops", 1, true) == nil and h:find("ago", 1, true) == nil, "the short form: " .. h)
    local card = cardFor(drawn, 1)
    local c = card.cells
    assertTrue(card.tipRow == true)
    assertEqual(card:GetHeight(), 50)
    assertEqual(textOf(c.item.text), "Bracers of the Tide"); assertEqual(textOf(c.ilvl.text), "305")
    assertTrue(card.offer:IsShown()); assertFalse(card.dash:IsShown())
    assertEqual(textOf(card.offer.label), "Offer")
    assertEqual(textOf(c.forYouLabel.text), "For you")
    assertEqual(textOf(c.forYou.glyph) .. " " .. textOf(c.forYou.text), "▽ -5")
    assertEqual(textOf(c.trade.text), "1:47:12")
    assertEqual(plain(textOf(c.candidates.text)), "Seta +14 · Butterz +6")
    assertTrue(textOf(c.candidates.text):find("|c", 1, true) ~= nil, "the names in class colors")
    assertTrue(card.announce:IsShown()); assertTrue(card.hide == nil)
    assertEqual(textOf(card.announce.label), "Announce")
    local lines = NS.CompactCards.Plain(card.model)
    assertEqual(lines[1], "Bracers of the Tide  305  Offer")
end)

test("compact mine: the countdown's bar follows the time left and turns amber when it warns", function()
    local NS, drawn = shownCompact()
    local C, CM = NS.Constants, NS.CompactMine
    local card = cardFor(drawn, 1)
    local widths, colors = {}, {}
    rawset(card.bar, "SetWidth", function(self, w) widths[#widths + 1] = w; return self end)
    rawset(card.bar, "SetColorTexture", function(self, r) colors[#colors + 1] = r; return self end)
    NS.Window.Refresh()
    card = cardFor(NS.WindowMine.Drawn(), 1)
    assertTrue(card.bar:IsShown())
    assertTrue(math.abs(widths[#widths] - CM.BAR_W * 6432 / 7200) < 1e-6, tostring(widths[#widths]))
    assertEqual(colors[#colors], C.TONE.good.r)
    local soon = cardFor(drawn, 3)
    assertEqual(textOf(soon.cells.trade.text), "0:08:41 ending soon")
    assertEqual(select(1, soon.cells.trade.text:GetTextColor()), C.TONE.warn.r)
    local dead = cardFor(drawn, 4)
    assertEqual(textOf(dead.cells.trade.text), "Not tradeable")
    assertFalse(dead.bar:IsShown(), "no bar on a drop that cannot be traded")
end)

test("compact mine: a drop that cannot be traded shows the dash and no Announce; nothing hides it", function()
    local NS, drawn = shownCompact()
    local W = NS.Window
    local dead = cardFor(drawn, 4)
    assertFalse(dead.offer:IsShown()); assertTrue(dead.dash:IsShown())
    assertEqual(textOf(dead.dash), "–")
    assertEqual(W.TooltipOf(dead.dashTip)[1], "No offer")
    assertFalse(dead.announce:IsShown()); assertTrue(dead.hide == nil, "no Hide (feedback-4 spec §2)")
    assertEqual(#drawn.rows, 3, "the dead drop stays listed")
end)

test("compact mine: Announce goes through the shared handler and shows the ask's state", function()
    local NS, drawn = shownCompact()
    local calls, state = {}, "ready"
    NS.Asks.Press = function(kind, target, id) calls[#calls + 1] = { kind, tostring(target), id }; state = "sent"; return "sent" end
    NS.Asks.StateOf = function(kind) return kind == "announce" and state or "ready" end
    cardFor(drawn, 1).announce:__fire("OnClick")
    assertEqual(table.concat(calls[1], ","), "announce,nil,1")
    NS.Window.Refresh()
    local b = cardFor(NS.WindowMine.Drawn(), 1).announce
    assertEqual(textOf(b.label), "Announced"); assertFalse(b:IsEnabled())
end)

test("compact mine: TradeTimerTick moves the countdown on the card", function()
    local NS, _, m = shownCompact()
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(textOf(cardFor(NS.WindowMine.Drawn(), 1).cells.trade.text), "1:47:00")
end)

test("compact mine: every piece keeps its full-view reason tooltip", function()
    local NS, drawn = shownCompact()
    local W, MC = NS.Window, NS.MineCells
    local card = cardFor(drawn, 1)
    local d = drop()
    assertEqual(W.TooltipOf(card.cells.trade.hit)[1], MC.TradeWindow(d, NOW, NS.TradeTimer.WarnAt()).tip[1])
    assertEqual(W.TooltipOf(card.cells.forYou.hit)[1], MC.ForMe(d).tip[1])
    assertEqual(W.TooltipOf(card.cells.candidates.hit)[1], MC.BestCandidates(d, false).tip[1])
    assertEqual(W.TooltipOf(card.offer)[1], "Offer")
    assertTrue(#W.TooltipOf(card.announce) >= 1)
    assertEqual(#W.TooltipOf(card.cells.item.hit), 0, "the item shows the game's own tooltip instead")
end)

test("compact mine: every tooltip opens at the card's top right, just outside the window", function()
    local NS, drawn, m = shownCompact()
    local win = NS.Window.Frame()
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 580 end
    win.GetTop = function() return 800 end
    m.UIParent.GetWidth = function() return 1920 end
    m.GameTooltip.GetWidth = function() return 320 end
    local card = cardFor(drawn, 1)
    card.GetTop = function() return 600 end
    for i, f in ipairs({ card.cells.trade.hit, card.cells.forYou.hit, card.cells.candidates.hit, card.offer, card.announce }) do
        m.GameTooltip.__points = {}
        f:__fire("OnEnter")
        local point, rel, relPoint, _, y = m.GameTooltip:GetPoint(1)
        assertEqual(tostring(point) .. ">" .. tostring(relPoint), "BOTTOMLEFT>TOPRIGHT", "piece " .. i)
        assertTrue(rel == win, "piece " .. i)
        assertEqual(y, -200, "piece " .. i .. ": level with the card's top")
    end
end)

test("compact mine: the strip is shortened in the compact layout and put back in the full one", function()
    local NS, drawn = shownCompact()
    local K, CM = NS.Constants.WINDOW, NS.CompactMine
    local strip = drawn.pane.summary
    assertEqual(textOf(strip.info.text), "2 tradeable · next 0:08:41")
    assertEqual(textOf(strip.post.label), "Post"); assertEqual(strip.post:GetWidth(), CM.POST_W)
    assertEqual(NS.Window.TooltipOf(strip.post)[1], "Post my tradeables", "the tooltip is unchanged")
    NS.SetWindowMode("full")
    drawn = NS.WindowMine.Drawn()
    assertTrue(drawn.compact == nil and #drawn.rows == 3, "the table again")
    assertEqual(textOf(strip.info.text), "2 tradeable · next expiry 0:08:41")
    assertEqual(textOf(strip.post.label), "Post my tradeables"); assertEqual(strip.post:GetWidth(), K.POST_W)
end)

test("compact mine: cards are pooled and follow the Font size row", function()
    local NS, drawn = shownCompact()
    local pool = drawn.pane.compactView.cardPool
    NS.Window.Refresh()
    NS.Window.Refresh()
    local free, active = NS.Pool.Counts(pool)
    assertEqual(free + active, 3, "three cards ever built")
    NS.addon.db.profile.window.fontSize = 14
    NS.Window.Refresh()
    local card = cardFor(NS.WindowMine.Drawn(), 1)
    assertEqual(card:GetHeight(), 62)
    assertEqual(select(2, card.cells.trade.text:GetFont()), 14, "the countdown keeps the size after its face changes")
    assertEqual(select(2, card.cells.forYou.glyph:GetFont()), 14)
end)

test("compact mine: a header click collapses its group; the empty line still shows", function()
    local NS, drawn = shownCompact()
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowMine.Drawn()
    assertEqual(#drawn.rows, 0); assertEqual(#drawn.headers, 1)
    assertEqual(drawn.summary.text, "2 tradeable · next expiry 0:08:41", "the summary still counts them")
    NS.WindowFilterBar.Set("mine", "search", "nothing like it")
    drawn = NS.WindowMine.Drawn()
    assertEqual(#drawn.headers, 0)
    assertTrue(drawn.pane.placeholder:IsShown())
end)

-- ── the Offer panel beside the compact window ───────────────────────────────────────────────

local function placed(NS, m, left, right, height)
    local win = NS.Window.Frame()
    win.GetLeft = function() return left end
    win.GetRight = function() return right end
    win.GetHeight = function() return height end
    m.UIParent.GetWidth = function() return 1920 end
    return win
end

test("compact mine: Offer opens the panel docked beside the compact window, its width unchanged", function()
    local NS, drawn, m = shownCompact()
    local K = NS.Constants.WINDOW
    local win = placed(NS, m, 200, 580, 460)
    cardFor(drawn, 1).offer:__fire("OnClick")
    local p = NS.OfferPanel.Drawn().panel
    assertTrue(NS.OfferPanel.IsShown()); assertEqual(NS.OfferPanel.DropId(), 1)
    assertEqual(p.dock, "right"); assertEqual(p:GetWidth(), K.OFFER_W)
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPLEFT>TOPRIGHT"); assertTrue(rel == win); assertEqual(x, K.DOCK_GAP)
    assertEqual(p:GetHeight(), 460, "as tall as the window")
    assertEqual(#NS.OfferPanel.Drawn().rows, 3)
end)

test("compact mine: the panel goes on the side with room, and floats centered when neither has", function()
    local NS, drawn, m = shownCompact()
    local K = NS.Constants.WINDOW
    local win = placed(NS, m, 1500, 1880, 220)
    cardFor(drawn, 1).offer:__fire("OnClick")
    local p = NS.OfferPanel.Drawn().panel
    assertEqual(p.dock, "left")
    local point, rel, relPoint, x = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOPRIGHT>TOPLEFT"); assertTrue(rel == win); assertEqual(x, -K.DOCK_GAP)
    assertEqual(p:GetHeight(), K.OFFER_MIN_H, "never shorter than its least height")
    m.UIParent.GetWidth = function() return 800 end
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 580 end
    NS.Window.Refresh()
    assertEqual(p.dock, "float")
    point, rel, relPoint = p:GetPoint(1)
    assertEqual(point .. ">" .. relPoint, "TOP>TOP"); assertTrue(rel == win)
    NS.SetWindowMode("full")
    win.GetLeft = function() return 200 end
    win.GetRight = function() return 1200 end
    m.UIParent.GetWidth = function() return 1920 end
    NS.Window.Refresh()
    assertEqual(p.dock, "right")
    assertEqual(select(2, p:GetPoint(2)), win, "the full layout docks top and bottom again")
end)

-- ── test mode ───────────────────────────────────────────────────────────────────────────────

test("compact mine: test mode fills a card for every sample of yours, no piece blank", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    NS.Window.SelectTab("mine")
    NS.WindowFilterBar.Set("mine", "view", "all")
    local drawn = NS.WindowMine.Drawn()
    assertTrue(drawn.compact == true)
    assertTrue(#drawn.rows >= 1, "the samples of yours, as cards: " .. #drawn.rows)
    for _, card in ipairs(drawn.rows) do
        local c = card.cells
        for _, key in ipairs({ "item", "ilvl", "forYouLabel", "trade", "candidates" }) do
            local t = textOf(c[key].text)
            assertTrue(t ~= nil and t ~= "", "card " .. tostring(card.dropId) .. ": " .. key)
        end
        assertTrue(card.offer:IsShown() or card.dash:IsShown(), "Offer or its dash")
        assertTrue(card.announce:IsShown() or card.dash:IsShown(), "Announce, or the dash of a dead drop")
    end
end)
