local _, NS = ...
-- modules/CompactMine.lua — the My drops tab in the compact layout (compact spec §3, DW-C3): the
-- same rows as the full table, each of your drops a three-line card under a one-line header.
--
-- ONE PANE, TWO LAYOUTS. modules/WindowMine.lua computes the tab's rows (WM.Rows: your drops that
-- pass its filters and were not hidden, under their run's or encounter's header) once per repaint
-- and hands them here in the compact layout; this file draws them into its own scroll view over the
-- same pane (NS.CompactGroup's shared kit: pooled cards and headers, the layout switch and the scroll
-- carry-over). Nothing here filters, judges or sends: Offer and Announce are the full table's
-- handlers (NS.OfferPanel.Open, NS.PressAnnounce).
--
-- THE CARD. What each piece says, its tone and its tooltip are NS.CompactCards.Mine's:
--
--   line 1  item (quality color, the game's tooltip) · ilvl · [Offer] (or a dash and why)
--   line 2  For you ▲ +49 (keep?)             1:44:46 ████████░░░░   (or Not tradeable)
--   line 3  Seta +14 · Butterz +6 (class colors)          [Announce] (or [Hide])
--
-- The countdown's bar is the full table's (MineCells.TradeWindow's fraction, amber once it warns),
-- drawn after its text on line 2. Every tooltip rises from the card's top right (`tipRow`,
-- NS.RowTooltip).
--
-- THE STRIP. The summary strip stays under the cards, shortened: `n tradeable · next 0:08:41` and
-- a narrower Post button (the same tooltip and handler); the full layout puts both back.

NS.CompactMine = NS.CompactMine or {}
local CM = NS.CompactMine
local K  = NS.Constants.WINDOW
local C  = NS.Constants
local L  = NS.L

local max, floor = math.max, math.floor

CM.BAR_W  = 56     -- the countdown's bar on line 2
CM.POST_W = 64     -- the strip's shortened Post button

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

local function hex(v) return floor(max(0, math.min(1, v or 1)) * 255 + 0.5) end

--- Line 3's candidates as one string: each named upgrade in its class color (`colorOf` answers r,
--- g, b or nil), joined by a dot, then `+n more`; the cell's own text when nobody is named (its
--- tone is the cell's then).
--- @param c table CompactCards.Mine's `candidates`
--- @param colorOf function classFile -> r, g, b | nil
--- @return string text, boolean colored
function CM.CandidatesText(c, colorOf)
    if type(c.parts) ~= "table" or #c.parts == 0 then return c.text, false end
    local words = {}
    for i, p in ipairs(c.parts) do
        local r, g, b = colorOf(p.classFile)
        words[i] = r and ("|cff%02x%02x%02x%s|r"):format(hex(r), hex(g), hex(b), p.text) or p.text
    end
    words[#words + 1] = c.more
    return table.concat(words, " · "), true
end

--- The strip's short summary (MineCells.Summary's, shortened): `2 tradeable · next 0:08:41`.
--- @param s table MineCells.Summary's answer
--- @return string
function CM.SummaryText(s)
    local text = s.count == 1 and L["1 tradeable"] or L["%d tradeable"]:format(s.count or 0)
    if s.next then text = text .. " · " .. L["next %s"]:format(NS.MineCells.Clock(s.next)) end
    return text
end

-- ── building a card ─────────────────────────────────────────────────────────────────────────

local function tipOf(f) return unpack(f.tipLines or {}) end

local function attach(f) NS.Window.AttachTooltip(f, function() return tipOf(f) end, "row") end

local function buildLineOne(card)
    local CG, WG, W = NS.CompactGroup, NS.WindowGroup, NS.Window
    card.icon = WG.ItemButton(card, K.ROW_ICON)
    card.icon:SetPoint("LEFT", card, "LEFT", CG.PAD + CG.QUALITY_W, 0)
    local item = CG.Piece(card, "item")
    item.hit.showItem = true   -- the game's own tooltip (WindowGroup.ItemHover)
    WG.ItemHover(item.hit, card.icon)
    CG.Piece(card, "ilvl")
    card.offer = W.TextButton(card, K.OFFER_BTN_W, nil, L["Offer"], function(b) NS.OfferPanel.Open(b.dropId) end)
    attach(card.offer)
    card.dash = CG.FontString(card, "GameFontDisableSmall")
    card.dash:SetPoint("CENTER", card.offer, "CENTER", 0, 0)
    card.dashTip = CreateFrame("Frame", nil, card)
    card.dashTip:SetAllPoints(card.offer)
    attach(card.dashTip)
end

-- Line 2: For you (label, then the verdict's glyph and change, then `(keep?)`), the countdown.
local function buildLineTwo(card)
    local CG = NS.CompactGroup
    local label = { text = CG.FontString(card) }
    local fy = { glyph = CG.MonoString(card), text = CG.FontString(card), sub = CG.FontString(card, "GameFontDisableSmall") }
    fy.glyph:SetPoint("LEFT", label.text, "RIGHT", 3, 0)
    fy.text:SetPoint("LEFT", fy.glyph, "RIGHT", 2, 0)
    fy.sub:SetPoint("LEFT", fy.text, "RIGHT", 4, 0)
    card.cells.forYouLabel, card.cells.forYou = label, fy
    local hit = CreateFrame("Frame", nil, card)
    hit:SetPoint("TOPLEFT", label.text, "TOPLEFT", 0, 0)
    hit:SetPoint("BOTTOMRIGHT", fy.sub, "BOTTOMRIGHT", 0, 0)
    attach(hit)
    fy.hit = hit
    card.barBg = card:CreateTexture(nil, "BACKGROUND")
    card.barBg:SetColorTexture(1, 1, 1, 0.12)
    card.barBg:SetSize(CM.BAR_W, K.BAR_H + 1)
    card.bar = card:CreateTexture(nil, "ARTWORK")
    card.bar:SetHeight(K.BAR_H + 1)
    card.bar:SetPoint("LEFT", card.barBg, "LEFT", 0, 0)
    local trade = CG.Piece(card, "trade")
    trade.text:SetJustifyH("RIGHT")
end

local function buildLineThree(card)
    local CG, W = NS.CompactGroup, NS.Window
    CG.Piece(card, "candidates")
    card.announce = W.TextButton(card, K.ANNOUNCE_W, nil, L["Announce"], function(b) NS.PressAnnounce(b.dropId) end)
    attach(card.announce)
end

local function newCard(content)
    local card = CreateFrame("Frame", nil, content)
    card.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    card.cells = {}
    NS.CompactGroup.Background(card)
    card.selected:Hide()
    buildLineOne(card)
    buildLineTwo(card)
    buildLineThree(card)
    return card
end

-- The pieces placed against the card's lines, once per text size.
local function layout(card, m)
    if card.dwLine == m.line then return end
    card.dwLine = m.line
    local CG = NS.CompactGroup
    local at, x, P, c = CG.At, CG.TextLeft(m), CG.PAD, card.cells
    local y1, y2, y3 = CG.LineY(m, 1), CG.LineY(m, 2), CG.LineY(m, 3)
    card.icon:SetSize(m.icon, m.icon)
    at(card.offer, "RIGHT", card, "TOPRIGHT", -P, y1)
    card.offer:SetHeight(m.line + 2)
    at(c.ilvl.text, "RIGHT", card.offer, "LEFT", -6, 0)
    at(c.item.text, "LEFT", card, "TOPLEFT", x, y1)
    c.item.text:SetPoint("RIGHT", c.ilvl.text, "LEFT", -6, 0)
    at(c.forYouLabel.text, "LEFT", card, "TOPLEFT", x, y2)
    at(card.barBg, "RIGHT", card, "TOPRIGHT", -P, y2)
    at(c.trade.text, "RIGHT", card.barBg, "LEFT", -6, 0)
    at(card.announce, "RIGHT", card, "TOPRIGHT", -P, y3)
    card.announce:SetHeight(m.line + 2)
    at(c.candidates.text, "LEFT", card, "TOPLEFT", x, y3)
    c.candidates.text:SetPoint("RIGHT", card.announce, "LEFT", -6, 0)
end

-- ── painting a card ─────────────────────────────────────────────────────────────────────────

local function paintLineOne(card, drop, cc)
    local CG, WG, c = NS.CompactGroup, NS.WindowGroup, card.cells
    WG.SetItem(card.icon, drop.link, WG.Where(drop))
    card.quality:SetColorTexture(CG.QualityColor(drop))
    c.item.text:SetText(cc.item.text)
    c.item.text:SetTextColor(CG.QualityColor(drop))
    c.item.hit.tipLines = nil   -- the real item tooltip instead
    CG.PaintText(c.ilvl, cc.ilvl)
    local o = cc.offer
    card.offer.dropId = drop.id
    card.offer:SetShown(not o.dash)
    card.dash:SetShown(o.dash == true)
    card.dashTip:SetShown(o.dash == true)
    card.dash:SetText(o.text)
    card.offer.tipLines, card.dashTip.tipLines, card.offer.primary = o.tip, o.tip, o.primary
    NS.WindowGroup.ToneButton(card.offer, cc.offerTone)   -- feedback-4 spec §1
end

local function paintForYou(card, fy)
    local CG, c = NS.CompactGroup, card.cells
    c.forYouLabel.text:SetText(fy.label)
    CG.SetTone(c.forYouLabel.text, "muted")
    local v = c.forYou
    v.glyph:SetText(fy.verdict.glyph or "")
    CG.SetTone(v.glyph, fy.verdict.tone)
    v.text:SetText(fy.verdict.text)
    CG.SetTone(v.text, fy.verdict.tone)
    v.sub:SetText(fy.sub or "")
    v.hit.tipLines = fy.verdict.tip
end

-- The countdown's face follows its urgency (as the full table's); SetFontObject puts the template's
-- size back, so the Font size row's size goes on again after it.
local function paintTrade(card, t, m)
    local CG, f = NS.CompactGroup, card.cells.trade
    f.text:SetFontObject(t.bold and "GameFontNormalSmall" or "GameFontHighlightSmall")
    if m.fontSize then NS.WindowRows.SetFontSize(f.text, m.fontSize) end
    CG.PaintText(f, t)
    card.fraction = t.fraction or 0
    card.bar:SetWidth(max(CM.BAR_W * card.fraction, 0.01))
    card.bar:SetShown(card.fraction > 0)
    local tone = C.TONE[t.soon and "warn" or "good"]
    card.bar:SetColorTexture(tone.r, tone.g, tone.b, 0.9)
end

local function paintLineThree(card, drop, cc)
    local CG, c = NS.CompactGroup, card.cells
    local text, colored = CM.CandidatesText(cc.candidates, NS.Compat.ClassColor)
    CG.PaintText(c.candidates, cc.candidates)
    c.candidates.text:SetText(text)
    if colored then CG.SetTone(c.candidates.text, "plain") end
    local a = cc.action
    card.announce.dropId = drop.id
    card.announce:SetShown(a ~= nil)
    if a then
        a.toneState = cc.announceTone
        NS.WindowMine.SetButtonLook(card.announce, a)
    end
end

local function cardCtx(drop, st)
    local state, reason = NS.Asks.StateOf("announce", nil, drop.id)
    return { now = st.now, warnAt = st.warnAt, revealed = NS.WindowMine.IsRevealed(drop.id),
        announceState = state, announceReason = reason }
end

local function paintCard(card, drop, _, m, st)
    card.dropId = drop.id
    card:SetHeight(m.height)
    layout(card, m)
    NS.WindowRows.ApplyRowFont(card, m.fontSize)
    local cc = NS.CompactCards.Mine(drop, cardCtx(drop, st))
    card.model = cc
    cc.offerTone, cc.announceTone = NS.WindowMine.ToneStates(drop)   -- once per card (feedback-4 spec §1)
    paintLineOne(card, drop, cc)
    paintForYou(card, cc.forYou)
    paintTrade(card, cc.trade, m)
    paintLineThree(card, drop, cc)
end

local function mineHeader(e, st)
    local g = e.group
    return NS.CompactCards.Header(g, e.count, st.now, NS.WindowFooter.SITUATION_LABEL[g.situation], e.collapsed,
        e.hidden, e.filter)
end

local function toggle(h) NS.WindowMine.ToggleGroup(h.groupKey, h.collapsed) end

local SPEC = { newCard = newCard, paint = paintCard, header = mineHeader, toggle = toggle }

-- ── the strip ───────────────────────────────────────────────────────────────────────────────

-- The Post button's look in each layout (the tooltip and the handler stay the full table's).
local POST_LOOK = { [true] = { w = CM.POST_W, label = L["Post"] }, [false] = { w = K.POST_W, label = L["Post my tradeables"] } }
local INFO_W = 320   -- the summary's width in the full layout (WindowMine's strip)

local function infoWidth(pane, postW)
    local w = pane:GetWidth()
    if not w or w <= 0 then w = K.COMPACT_WIDTH end
    return max(w - postW - 8, 40)
end

-- The summary strip, shortened in the compact layout and put back in the full one.
local function paintStrip(pane, compact)
    local strip = pane.summary
    if not strip then return end
    local look = POST_LOOK[compact == true]
    strip.post:SetWidth(look.w)
    strip.post.label:SetText(look.label)
    strip.info:SetWidth(compact and infoWidth(pane, look.w) or INFO_W)
    if compact and pane.summaryData then strip.info.text:SetText(CM.SummaryText(pane.summaryData)) end
end

-- The pane's own scroll view, above its strip.
local function buildView(pane) return NS.CompactGroup.BuildView(pane, K.MINE_FOOT_H) end

--- Draw the compact layout's cards for the tab's rows (WindowMine's refresh, every repaint, after
--- its summary), or, in the full layout, hide them and put the strip back.
--- @param pane table the My drops pane
--- @param items table NS.WindowMine.Rows' answer
--- @param compact boolean
function CM.Refresh(pane, items, compact)
    local CG = NS.CompactGroup
    paintStrip(pane, compact)
    local cv = CG.Swap(pane, compact, buildView)
    if not cv then return end
    local st = { now = GetTime(), warnAt = NS.TradeTimer.WarnAt() }
    CG.Draw(cv, items, CG.CardWidth(pane), SPEC, st)
    CG.Settle(pane, cv)
end

--- The drawn compact pane, for the suites (WindowMine.Drawn's shape in the compact layout).
--- @param pane table
--- @return table|nil
function CM.Drawn(pane)
    local cv = pane.compactView
    if not cv then return nil end
    return { compact = true, rows = cv.cardPool.active, headers = cv.headPool.active, entries = pane.entries,
        items = pane.items, pane = pane, summary = pane.summaryData, scroll = cv.scroll }
end
