local _, NS = ...
-- modules/CompactGroup.lua — the Group drops tab in the compact layout (compact spec §2, DW-C2):
-- the same entries as the full table, each drop a three-line card under a one-line header.
--
-- ONE PANE, TWO LAYOUTS. modules/WindowGroup.lua builds the tab and computes its entries (the
-- feed's groups, the filters, the order, the dismissals) once per repaint, then hands them here in
-- the compact layout (WG.IsCompact) and draws its table otherwise. This file adds its own scroll
-- frame to the same pane, built on the first compact repaint, and shows one or the other; the
-- empty state and the filters' line stay WindowGroup's. Nothing here filters, judges or sends.
--
-- THE CARD. Three lines, the item button spanning them (NS.WindowGroup.ItemButton: the game's own
-- tooltip, shift-click links, ctrl-click tries on), a thin bar in the item's quality color at the
-- left edge. What each piece says, its tone and its reason tooltip are NS.CompactCards.Group's
-- (pure, built from the full view's cells):
--
--   line 1  item (quality color, the game's tooltip) · ilvl · Ask (the full table's states) · ×
--   line 2  looter (class color, ⊕ from another realm) · slot · trade        inspect freshness
--   line 3  You ▽ -13 (321/308)                 Them ⊘ Can't use (298/296)
--
-- Every piece is a font string with a hit frame over it that carries its tooltip, placed by the
-- row-tooltip helper (NS.RowTooltip, DW-B2) at the card's top right, just outside the window: the
-- card is marked `tipRow`. A click anywhere on the card but a button expands it, as a row click
-- does (NS.WindowGroup.ToggleExpand, one at a time, session-only); a plain click on the item
-- button does too.
--
-- THE SIZE. Text follows `window.fontSize` through NS.WindowRows (Default is the template's own
-- size, as in the full table); a card's line height, height and icon follow from it (Metrics,
-- pure): about 50 pixels at the default size. `window.rowHeight` is the full table's and does not
-- apply.
--
-- THE HEADERS are the full table's header button (NS.WindowGroup.NewHeader, so a click collapses
-- the group the same way), painted with the short form (NS.CompactCards.Header), the long form and
-- the hidden-drop lines in its tooltip.
--
-- THE DETAIL CARD is NS.DetailCard's, built `stacked` for this pane: under the open card, at the
-- compact width, its two comparisons one under the other; the cards below move down by its height.
--
-- POOLED. One LibKa0s-Pool-1.0 pool for the cards and one for the headers, released and acquired in
-- order on every repaint; a card is built once and repainted.
--
-- SWITCHING keeps the expanded card (NS.State.windowGroup is shared) and carries the scroll offset
-- over as a fraction of the scroll range (CarryScroll), as near as the two layouts allow.
--
-- THE SHARED KIT. My drops and History draw their cards the same way (modules/CompactMine.lua and
-- modules/CompactHistory.lua, DW-C3), so the frame pieces live here once and are exported: the
-- pieces and their hit frames (Piece, FontString, MonoString, Background), line 2 and line 3's
-- halves (BuildLineTwo/PaintLineTwo, BuildHalf/PaintHalf), the pane's own scroll view (BuildView),
-- the layout switch (Swap, Settle) and the draw loop over a tab's entries (Draw, driven by a
-- per-tab `spec` table built once at load: no closure per repaint).

NS.CompactGroup = NS.CompactGroup or {}
local CG = NS.CompactGroup
local K  = NS.Constants.WINDOW
local C  = NS.Constants

local max, min, floor = math.max, math.min, math.floor

CG.PAD = 4             -- a card's margin
CG.GAP = 2             -- between two cards, and around the detail card
CG.LINE_EXTRA = 4      -- a line's height over its text size
CG.ICON_MIN, CG.ICON_MAX = 24, 48
CG.QUALITY_W = 2       -- the quality bar at a card's left edge
CG.DISMISS = 12        -- the × mark

-- The muted dot between line 2's pieces (an escape, so the piece keeps its own tone).
local SEP = "|cff9e9ea3·|r "

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- A card's metrics at a `window.fontSize` (nil = Default, the small template's own size):
--- { fontSize, size, line, height, icon }. Three lines of `size + LINE_EXTRA`, a PAD above and below;
--- the icon spans the three lines, within ICON_MIN..ICON_MAX.
--- @param fontSize number|nil NS.WindowRows.FontSize's answer
--- @return table
function CG.Metrics(fontSize)
    local size = fontSize or K.MINE_FONT
    local line = size + CG.LINE_EXTRA
    return { fontSize = fontSize, size = size, line = line, height = 3 * line + 2 * CG.PAD,
        icon = min(CG.ICON_MAX, max(CG.ICON_MIN, 3 * line - 6)) }
end

--- The middle of line `i` (1..3), as an offset down from the card's top.
--- @param m table CG.Metrics' answer
--- @param i number
--- @return number
function CG.LineY(m, i) return -(CG.PAD + (i - 0.5) * m.line) end

--- Where the text starts: after the quality bar and the icon.
--- @param m table
--- @return number
function CG.TextLeft(m) return CG.PAD + CG.QUALITY_W + m.icon + 6 end

--- Where line 3's second half (Them) starts on a card `width` pixels wide: halfway across the text.
--- @param width number
--- @param m table
--- @return number
function CG.HalfX(width, m)
    local x = CG.TextLeft(m)
    return x + floor(max(0, width - x - CG.PAD) / 2)
end

--- A scroll offset carried from one layout to the other: the same fraction of the scroll range.
--- @param offset number|nil the offset in the layout being left
--- @param fromRange number|nil its scroll range
--- @param toRange number|nil the new layout's scroll range
--- @return number
function CG.CarryScroll(offset, fromRange, toRange)
    offset, fromRange, toRange = tonumber(offset) or 0, tonumber(fromRange) or 0, tonumber(toRange) or 0
    if fromRange <= 0 or toRange <= 0 then return 0 end
    return floor(toRange * min(1, max(0, offset / fromRange)) + 0.5)
end

-- ── painting helpers ────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end
CG.SetTone = setTone

local function tipOf(f) return unpack(f.tipLines or {}) end

local function at(region, ...)
    region:ClearAllPoints()
    region:SetPoint(...)
end
CG.At = at

local function qualityColor(drop)
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then return qc.r, qc.g, qc.b end
    local p = C.TONE.plain
    return p.r, p.g, p.b
end
CG.QualityColor = qualityColor

-- A click on a piece is a click on its card (the pieces take the mouse for their tooltips): the
-- card's own `onPiece(card, button)`, when it has one.
local function pieceClick(self, button)
    local card = self.card
    if card and card.onPiece then card.onPiece(card, button) end
end

-- A Group drops card's click expands its detail card (a piece's too).
local function groupPiece(card, button)
    if button == "LeftButton" then NS.WindowGroup.ToggleExpand(card.dropId) end
end

-- A hit frame over `first`..`last` (font strings on the card) carrying their tooltip.
local function hitOver(card, first, last)
    local hit = CreateFrame("Frame", nil, card)
    hit.card = card
    hit:SetPoint("TOPLEFT", first, "TOPLEFT", 0, 0)
    hit:SetPoint("BOTTOMRIGHT", last or first, "BOTTOMRIGHT", 0, 0)
    hit:SetScript("OnMouseUp", pieceClick)
    NS.Window.AttachTooltip(hit, function() return tipOf(hit) end, "row")
    return hit
end

local function fontString(card, template)
    local fs = card:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end
CG.FontString = fontString

local function monoString(card)
    local fs = card:CreateFontString(nil, "OVERLAY")
    fs:SetFont(C.FONT_MONO, 12, "")
    return fs
end
CG.MonoString = monoString

-- A text piece: `card.cells[key] = { text, hit }` (NS.WindowRows.ApplyRowFont sizes `text`).
local function piece(card, key)
    local cell = { text = fontString(card) }
    cell.hit = hitOver(card, cell.text)
    card.cells[key] = cell
    return cell
end
CG.Piece = piece

-- ── building a card ─────────────────────────────────────────────────────────────────────────

local function buildBackground(card)
    card.stripe = card:CreateTexture(nil, "BACKGROUND")
    card.stripe:SetAllPoints(card)
    card.stripe:SetColorTexture(1, 1, 1, 0.03)
    card.selected = card:CreateTexture(nil, "BACKGROUND")
    card.selected:SetAllPoints(card)
    card.selected:SetColorTexture(C.GOLD.r, C.GOLD.g, C.GOLD.b, 0.08)
    card.quality = card:CreateTexture(nil, "ARTWORK")
    card.quality:SetWidth(CG.QUALITY_W)
    card.quality:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    card.quality:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
end
CG.Background = buildBackground

local function buildAsk(card)
    local W = NS.Window
    card.ask = W.TextButton(card, K.ASK_W, nil, NS.L["Ask"], function(b) NS.PressAsk(b.dropId) end)
    W.AttachTooltip(card.ask, function() return tipOf(card.ask) end, "row")
    card.dash = fontString(card, "GameFontDisableSmall")
    card.dash:SetPoint("CENTER", card.ask, "CENTER", 0, 0)
    card.dashTip = CreateFrame("Frame", nil, card)
    card.dashTip:SetAllPoints(card.ask)
    W.AttachTooltip(card.dashTip, function() return tipOf(card.dashTip) end, "row")
    local d = CreateFrame("Button", nil, card)
    d:SetSize(CG.DISMISS, CG.DISMISS)
    d.art = d:CreateTexture(nil, "ARTWORK")
    d.art:SetAllPoints(d)
    d.art:SetTexture(NS.Icon("close"))
    d.art:SetVertexColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
    d:SetScript("OnClick", function(b) NS.DismissDrop(b.dropId) end)
    W.AttachTooltip(d, function() return tipOf(d) end, "row")
    card.dismiss = d
end

local function buildLineOne(card)
    local WG = NS.WindowGroup
    card.icon = WG.ItemButton(card, K.ROW_ICON)
    card.icon:SetPoint("LEFT", card, "LEFT", CG.PAD + CG.QUALITY_W, 0)
    local item = piece(card, "item")
    item.hit.showItem = true   -- the game's own tooltip (WindowGroup.ItemHover)
    WG.ItemHover(item.hit, card.icon)
    piece(card, "ilvl")
    buildAsk(card)
end

--- Line 2's pieces: looter (and its ⊕), slot, trade, then `right` (right-aligned: Group drops'
--- inspect freshness, History's time).
--- @param card table
--- @param right string the right piece's key
function CG.BuildLineTwo(card, right)
    local looter = piece(card, "looter")
    looter.glyph = monoString(card)
    looter.glyph:SetPoint("LEFT", looter.text, "RIGHT", 2, 0)
    looter.hit:SetPoint("BOTTOMRIGHT", looter.glyph, "BOTTOMRIGHT", 0, 0)
    local slot = piece(card, "slot")
    slot.text:SetPoint("LEFT", looter.glyph, "RIGHT", 4, 0)
    local trade = piece(card, "trade")
    trade.text:SetPoint("LEFT", slot.text, "RIGHT", 4, 0)
    piece(card, right)
end

-- One half of line 3: the label (`cells[key .. "Label"]`), then the verdict's glyph and change
-- (`cells[key]`, one tooltip over the three) and the worn levels (`cells[key .. "Eq"]`).
function CG.BuildHalf(card, key)
    local label = { text = fontString(card) }
    local verdict = { glyph = monoString(card), text = fontString(card) }
    verdict.glyph:SetPoint("LEFT", label.text, "RIGHT", 3, 0)
    verdict.text:SetPoint("LEFT", verdict.glyph, "RIGHT", 2, 0)
    verdict.hit = hitOver(card, label.text, verdict.text)
    card.cells[key .. "Label"], card.cells[key] = label, verdict
    local eq = piece(card, key .. "Eq")
    eq.text:SetPoint("LEFT", verdict.text, "RIGHT", 4, 0)
end

local function newCard(content)
    local card = CreateFrame("Button", nil, content)
    card.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    card.cells = {}
    card.onPiece = groupPiece
    buildBackground(card)
    buildLineOne(card)
    CG.BuildLineTwo(card, "fresh")
    CG.BuildHalf(card, "you")
    CG.BuildHalf(card, "them")
    card:SetScript("OnClick", function(self) NS.WindowGroup.ToggleExpand(self.dropId) end)
    return card
end

-- The pieces placed against the card's lines, once per text size.
local function layout(card, m)
    if card.dwLine == m.line then return end
    card.dwLine = m.line
    local x, P, c = CG.TextLeft(m), CG.PAD, card.cells
    local y1 = CG.LineY(m, 1)
    card.icon:SetSize(m.icon, m.icon)
    at(card.dismiss, "RIGHT", card, "TOPRIGHT", -P, y1)
    at(card.ask, "RIGHT", card.dismiss, "LEFT", -4, 0)
    card.ask:SetHeight(m.line + 2)
    at(c.ilvl.text, "RIGHT", card.ask, "LEFT", -6, 0)
    at(c.item.text, "LEFT", card, "TOPLEFT", x, y1)
    c.item.text:SetPoint("RIGHT", c.ilvl.text, "LEFT", -6, 0)
    at(c.looter.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 2))
    at(c.fresh.text, "RIGHT", card, "TOPRIGHT", -P, CG.LineY(m, 2))
    at(c.youLabel.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 3))
end

-- ── painting a card ─────────────────────────────────────────────────────────────────────────

local function paintText(cell, c, prefix)
    cell.text:SetText(prefix and (prefix .. c.text) or c.text)
    setTone(cell.text, c.tone)
    cell.hit.tipLines = c.tip
end
CG.PaintText = paintText

-- The Ask button in the full table's states (WindowGroup's paintActions, the same cell), or the
-- dash with its reason where no ask is offered.
local function paintAsk(card, a, id)
    local b = card.ask
    b.dropId, card.dismiss.dropId = id, id
    b:SetShown(a.offered)
    card.dash:SetShown(not a.offered)
    card.dashTip:SetShown(not a.offered)
    card.dash:SetText(a.text)
    b.label:SetText(a.text)
    b.art:SetTexture(a.icon and NS.Icon(a.icon) or nil)
    b.art:SetShown(a.icon ~= nil)
    at(b.label, "CENTER", b, "CENTER", a.icon and 7 or 0, 0)
    b:SetEnabled(a.enabled)
    b:SetAlpha(a.enabled and 1 or 0.6)
    b.tipLines, card.dashTip.tipLines = a.tip, a.tip
    b.state = a.state
    NS.WindowGroup.ToneButton(b, a.state)   -- whose move it is (feedback-4 spec §1)
end

local function paintLineOne(card, drop, cc)
    local WG, c = NS.WindowGroup, card.cells
    WG.SetItem(card.icon, drop.link, WG.Where(drop))
    card.icon.dropId = drop.id
    card.quality:SetColorTexture(qualityColor(drop))
    c.item.text:SetText(cc.item.text)
    c.item.text:SetTextColor(qualityColor(drop))
    c.item.hit.tipLines = nil   -- the real item tooltip instead
    paintText(c.ilvl, cc.ilvl)
    paintAsk(card, cc.ask, drop.id)
    card.dismiss.tipLines = cc.dismiss.tip
end

--- Line 2 painted from a card model: the looter in class color, its ⊕, slot, trade and `right`.
--- @param card table
--- @param cc table a CompactCards card
--- @param right string the right piece's key (`fresh` or `time`)
function CG.PaintLineTwo(card, cc, right)
    local c = card.cells
    paintText(c.looter, cc.looter)
    local r, g, b = NS.Compat.ClassColor(cc.looter.classFile)
    if r then c.looter.text:SetTextColor(r, g, b) end
    c.looter.glyph:SetText(cc.looter.mark or "")
    setTone(c.looter.glyph, "muted")
    paintText(c.slot, cc.slot, SEP)
    paintText(c.trade, cc.trade, SEP)
    paintText(c[right], cc[right])
end

--- One half of line 3 painted (CompactCards.Half's): its label, the verdict and the worn levels.
--- @param card table
--- @param key string `you` or `them`
--- @param half table
function CG.PaintHalf(card, key, half)
    local c = card.cells
    local v, eq = c[key], c[key .. "Eq"]
    c[key .. "Label"].text:SetText(half.label)
    setTone(c[key .. "Label"].text, "muted")
    v.glyph:SetText(half.verdict.glyph or "")
    setTone(v.glyph, half.verdict.tone)
    v.text:SetText(half.verdict.text)
    setTone(v.text, half.verdict.tone)
    v.hit.tipLines = half.verdict.tip
    eq.text:SetText(half.eq and half.eq.text or "")
    setTone(eq.text, "muted")
    eq.hit.tipLines = half.eq and half.eq.tip or nil
    eq.hit:SetShown(half.eq ~= nil)
end

-- What every card of one repaint shares: your gear, the transmog ask setting and your realm.
local function sharedCtx(now)
    local snap = NS.Gear.Snapshot()
    return { now = now, equipped = snap and snap.equipped, transmogAsk = NS.Setting("messages.transmogAsk") == true,
        ownRealm = NS.Compat.NormalizedRealm() }
end

local function cardCtx(drop, shared)
    local state, reason = NS.WindowGroup.AskState(drop)
    local insp = NS.TestMode.InspectOf(drop)
    return { now = shared.now, equipped = shared.equipped, gear = insp and insp.gear, askState = state,
        askReason = reason, transmogAsk = shared.transmogAsk, ownRealm = shared.ownRealm }
end

local function paintCard(card, drop, width, m, shared)
    card.dropId = drop.id
    card:SetHeight(m.height)
    layout(card, m)
    NS.WindowRows.ApplyRowFont(card, m.fontSize)
    card.selected:SetShown(NS.WindowGroup.Expanded() == drop.id)
    local cc = NS.CompactCards.Group(drop, cardCtx(drop, shared))
    card.model = cc
    paintLineOne(card, drop, cc)
    CG.PaintLineTwo(card, cc, "fresh")
    CG.PaintHalf(card, "you", cc.you)
    at(card.cells.themLabel.text, "LEFT", card, "TOPLEFT", CG.HalfX(width, m), CG.LineY(m, 3))
    CG.PaintHalf(card, "them", cc.them)
end

--- A one-line header painted with a short form (`hd`, CompactCards.Header's or HistoryHeader's).
--- @param h table a header button (NS.WindowGroup.NewHeader's)
--- @param e table the header entry
--- @param hd table { text, tip }
--- @param width number
function CG.PaintHeader(h, e, hd, width)
    h.groupKey, h.collapsed = e.group.key, e.collapsed
    h.text:SetText(hd.text)
    h.text:SetWidth(max(width - 24, 20))
    h.text:SetWordWrap(false)
    h.tipLines = hd.tip
    h.chevron:SetTexture(NS.Icon(e.collapsed and "chevron-right" or "chevron-down"))
end

-- ── the pane ────────────────────────────────────────────────────────────────────────────────

--- A pane's compact view: its own scroll frame over the pane (above a strip `bottom` pixels tall),
--- hidden until the first compact repaint, and the card and header pools.
--- @param pane table
--- @param bottom number|nil the strip under the cards (My drops' summary, History's Clear history)
--- @return table cv { scroll, content, cardPool, headPool }
function CG.BuildView(pane, bottom)
    local cv = {}
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, bottom or 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll:Hide()
    cv.scroll, cv.content = scroll, content
    cv.cardPool, cv.headPool = NS.Pool.New(), NS.Pool.New()
    pane.compactView = cv
    return cv
end

local function build(pane)
    local cv = CG.BuildView(pane)
    cv.card = NS.DetailCard.Build(cv.content, true)
    return cv
end

--- The cards' width: the pane's, less the scroll bar's gutter; the window's before the first layout.
--- @param pane table
--- @return number
function CG.CardWidth(pane)
    local w = pane:GetWidth()
    if not w or w <= 0 then
        local f = NS.Window.Frame()
        w = (f and f:GetWidth() or K.COMPACT_WIDTH) - 2 * K.INSET
    end
    return w - K.SCROLL_W
end

local function place(frame, content, y, width)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    frame:SetWidth(width)
end

local function num(v) return type(v) == "number" and v or nil end

-- A scroll frame's range: its content's height past its own.
local function rangeOf(scroll)
    local child = scroll.GetScrollChild and scroll:GetScrollChild()
    local ch = child and num(child:GetHeight())
    local sh = num(scroll:GetHeight())
    return (ch and sh) and max(0, ch - sh) or 0
end

local function carry(from, to)
    local offset = num(from:GetVerticalScroll())
    to:SetVerticalScroll(CG.CarryScroll(offset, rangeOf(from), rangeOf(to)))
end

--- The layout switch for a pane: in the full layout, hide the compact view (carrying its scroll
--- offset over to the table's `pane.scroll`) and answer nil; in the compact one, build the view on
--- the first call, release its pools and answer it, ready to draw. CG.Settle follows the draw.
--- @param pane table
--- @param compact boolean
--- @param builder function pane -> cv (CG.BuildView, or a tab's own)
--- @return table|nil cv
function CG.Swap(pane, compact, builder)
    local cv = pane.compactView
    if not compact then
        if cv and cv.scroll:IsShown() then
            cv.scroll:Hide()
            carry(cv.scroll, pane.scroll)
        end
        return nil
    end
    cv = cv or builder(pane)
    cv.entering = not cv.scroll:IsShown()
    NS.Pool.ReleaseAll(cv.cardPool)
    NS.Pool.ReleaseAll(cv.headPool)
    cv.scroll:Show()
    return cv
end

--- After the first compact draw: the table's scroll offset carried over to the cards.
--- @param pane table
--- @param cv table
function CG.Settle(pane, cv)
    if cv.entering then carry(pane.scroll, cv.scroll) end
    cv.entering = nil
end

-- The pools' factories, made once per view (a repaint allocates no closure).
local function factories(cv, spec)
    if cv.makeCard then return end
    cv.makeCard = function() return spec.newCard(cv.content) end
    cv.makeHeader = function()
        local h = NS.WindowGroup.NewHeader(cv.content)
        if spec.toggle then h:SetScript("OnClick", spec.toggle) end
        return h
    end
end

--- Draw a tab's entries as headers and cards (every repaint). `spec` is the tab's, built once:
--- { newCard = fn(content), paint = fn(card, drop, width, m, st), header = fn(e, st) -> { text, tip },
---   toggle = OnClick for its headers (nil keeps Group drops'), after = fn(cv, drop, y, width, st) ->
---   extra height under a card (the detail card) }; `st` is the repaint's shared state.
--- @param cv table
--- @param entries table
--- @param width number
--- @param spec table
--- @param st table|nil
function CG.Draw(cv, entries, width, spec, st)
    local m = CG.Metrics(NS.WindowRows.FontSize(NS.Setting("window.fontSize")))
    local y, Pool = 0, NS.Pool
    factories(cv, spec)
    for i, e in ipairs(entries) do
        if e.kind == "header" then
            local h = Pool.Acquire(cv.headPool, cv.makeHeader)
            place(h, cv.content, y, width)
            CG.PaintHeader(h, e, spec.header(e, st), width)
            y = y + K.GROUP_H
        else
            local card = Pool.Acquire(cv.cardPool, cv.makeCard)
            place(card, cv.content, y, width)
            card.stripe:SetShown(i % 2 == 0)
            spec.paint(card, e.drop, width, m, st)
            y = y + m.height + CG.GAP
            if spec.after then y = y + spec.after(cv, e.drop, y, width, st) end
        end
    end
    cv.content:SetSize(width, max(y, 1))
end

-- The open card's detail card under it, stacked; answers the height it takes (0 for another card).
local function drawDetail(cv, drop, y, width, st)
    if drop.id ~= st.expanded then return 0 end
    place(cv.card, cv.content, y, width)
    local h = NS.DetailCard.Paint(cv.card, drop, width, st.now)
    cv.card:Show()
    cv.cardDropId = drop.id
    return h + CG.GAP
end

local function groupHeader(e, st)
    local g = e.group
    local sit = NS.WindowFooter.SITUATION_LABEL[g.situation]
    return NS.CompactCards.Header(g, e.count, st.now, sit, e.collapsed, e.hidden, e.filter, e.yours)
end

local GROUP_SPEC = { newCard = newCard, paint = paintCard, header = groupHeader, after = drawDetail }

--- Draw the compact layout's cards for `entries` (WindowGroup's refresh, every repaint), or, in the
--- full layout, hide them (carrying the scroll offset over to the table on the way out).
--- @param pane table the Group drops pane
--- @param entries table NS.WindowCells.Entries' answer
--- @param compact boolean whether the compact layout is in force
function CG.Refresh(pane, entries, compact)
    local cv = CG.Swap(pane, compact, build)
    if not cv then return end
    local st = sharedCtx(GetTime())
    st.expanded = NS.WindowGroup.Expanded()
    cv.card:Hide()
    cv.cardDropId = nil
    CG.Draw(cv, entries, CG.CardWidth(pane), GROUP_SPEC, st)
    CG.Settle(pane, cv)
end

--- The drawn compact pane, for the suites (WindowGroup.Drawn's shape in the compact layout):
--- { compact = true, rows (the cards), headers, entries, pane, card, cardDropId, empty }.
--- @param pane table
--- @return table|nil
function CG.Drawn(pane)
    local cv = pane.compactView
    if not cv then return nil end
    return { compact = true, rows = cv.cardPool.active, headers = cv.headPool.active, entries = pane.entries,
        pane = pane, card = cv.card, cardDropId = cv.cardDropId, empty = pane.emptyState, scroll = cv.scroll }
end
