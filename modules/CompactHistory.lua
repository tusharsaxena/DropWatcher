local _, NS = ...
-- modules/CompactHistory.lua — the History tab in the compact layout (compact spec §3, DW-C3): the
-- same kept entries as the full table, each a four-line card under a one-line header.
--
-- ONE PANE, TWO LAYOUTS. modules/WindowHistory.lua computes the tab's entries (WH.Entries over the
-- kept groups and its filters) once per repaint and hands them here in the compact layout; this
-- file draws them into its own scroll view over the same pane through NS.CompactGroup's shared kit.
-- Read-only, as the table is: a right-click on a card opens the row menu (Mark as declined, or
-- Clear declined: NS.WindowHistory.OpenMenu).
--
-- THE DETAIL CARD (feedback-15 spec §4, DW-Q4). A card draws the Drops cards' chevron before its
-- item button and is indented under its header as they are (K.ROW_INDENT); a click on it, on any
-- piece of it, or a plain click on its item button expands NS.HistoryCard's card, built `stacked`
-- for this view, under it (WindowHistory.ToggleExpand: the table's one open entry), the cards below
-- moving down by its height.
--
-- THE CARD. What each piece says, its tone and its tooltip are NS.CompactCards.History's:
--
--   line 1  ⌄ ilvl item (the chevron, then the item level before the name, feedback-10 spec §2;
--           the name runs to the card's right inset, as on Drops' cards)
--   line 2  looter (class color; another realm in its tooltip) · slot · type     Seen (outcome,
--           in its tone)
--   line 3  Trade Yes Not their upgrade (the full table's Trade, its word and its short reason:
--           feedback-22; above You and Them as on Drops' cards, feedback-25)        17:02 (dimmed;
--           Trade cut before it)
--           (the outcome and the time sit where a Drops card's action button does, lines 2 and 3:
--           feedback-25; they were lines 1 and 2's right pieces before)
--   line 4  You ▼4   Them ≈0
--           (the full table's Me and Them: a kept entry holds no worn items, so the verdict
--           alone; the labels gold, Them a fixed gap after You, as on Drops' cards)
--
-- THE HEADERS are the full table's header button, painted with the short form
-- (NS.CompactCards.HistoryHeader: `2d` once a day old); a click collapses the group as before.
--
-- THE STRIP is the full layout's (NS.WindowHistory places it for both): the kept-history line and
-- Expand all / Collapse all at the one footer width (feedback-15 spec §2); Clear history lives in
-- Settings › Window › Layout (feedback-15 spec §3).

NS.CompactHistory = NS.CompactHistory or {}
local CH = NS.CompactHistory
local K  = NS.Constants.WINDOW

-- ── building a card ─────────────────────────────────────────────────────────────────────────

-- A right-click on the card, or on any piece of it, opens the row menu; a piece's left click is the
-- card's (the card's own left click is its OnClick).
local function onPiece(card, button)
    if button == "RightButton" then return NS.WindowHistory.OpenMenu(card.entry, card) end
    if button == "LeftButton" then NS.WindowHistory.ToggleExpand(card.entry) end
end

local function onMouseUp(self, button)
    if button == "RightButton" then onPiece(self, button) end
end

local function onClick(self) NS.WindowHistory.ToggleExpand(self.entry) end

local function newCard(content)
    local CG, WG = NS.CompactGroup, NS.WindowGroup
    local card = CreateFrame("Button", nil, content)
    card.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    card.cells = {}
    card.onPiece = onPiece
    CG.Background(card)
    card.selected:Hide()
    card.chevron = WG.RowChevron(card)   -- placed on line 1 (layout)
    card.icon = WG.ItemButton(card, K.ROW_ICON)
    card.icon:SetPoint("LEFT", card, "LEFT", CG.PAD + CG.QUALITY_W + CG.LEAD, 0)
    card.icon:SetScript("OnClick", NS.WindowHistory.OnItemClick)
    local item = CG.Piece(card, "item")
    item.hit.showItem = true   -- the game's own tooltip (WindowGroup.ItemHover)
    WG.ItemHover(item.hit, card.icon)
    CG.Piece(card, "ilvl")
    CG.Piece(card, "outcome")
    CG.BuildLineTwo(card, "time")
    CG.BuildHalves(card)
    card:SetScript("OnMouseUp", onMouseUp)
    card:SetScript("OnClick", onClick)
    return card
end

-- The pieces placed against the card's lines, once per text size.
local function layout(card, m)
    if card.dwLine == m.line then return end
    card.dwLine = m.line
    local CG = NS.CompactGroup
    local at, x, P, c = CG.At, CG.TextLeft(m, CG.LEAD), CG.PAD, card.cells
    local y1 = CG.LineY(m, 1)
    card.icon:SetSize(m.icon, m.icon)
    at(card.chevron, "LEFT", card, "TOPLEFT", P + CG.QUALITY_W, y1)
    CG.PlaceLineOne(card, x, y1)
    at(c.looter.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 2))
    at(c.outcome.text, "RIGHT", card, "TOPRIGHT", -P, CG.LineY(m, 2))
    at(c.time.text, "RIGHT", card, "TOPRIGHT", -P, CG.LineY(m, 3))
    card.dwTradeBefore = c.time.text
    at(c.tradeLabel.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 3))
    CG.PlaceThem(card, m)
end

-- ── painting a card ─────────────────────────────────────────────────────────────────────────

local function paintCard(card, drop, _, m, st)
    local CG, WG, c = NS.CompactGroup, NS.WindowGroup, card.cells
    card.dropId, card.entry = drop.id, drop.entry
    card:SetHeight(m.height)
    layout(card, m)
    NS.WindowRows.ApplyRowFont(card, m.fontSize)
    local open = st.expanded == drop.entry
    card.selected:SetShown(open)
    WG.PaintChevron(card.chevron, open)
    card.icon.entry = drop.entry
    local cc = NS.CompactCards.History(drop, st)
    card.model = cc
    WG.SetItem(card.icon, drop.link)
    card.quality:SetColorTexture(CG.QualityColor(drop))
    c.item.text:SetText(cc.item.text)
    c.item.text:SetTextColor(CG.QualityColor(drop))
    c.item.hit.tipLines = nil   -- the real item tooltip instead
    CG.PaintText(c.ilvl, cc.ilvl)
    CG.PaintText(c.outcome, cc.outcome)
    CG.PaintLineTwo(card, cc, "time")
    CG.PaintHalves(card, cc)
end

local function historyHeader(e, st)
    local g = e.group
    return NS.CompactCards.HistoryHeader(g, e.count, st.nowEpoch, NS.WindowFooter.SITUATION_LABEL[g.situation],
        e.collapsed, e.hidden, e.filter)
end

local function toggle(h) NS.WindowHistory.ToggleGroup(h.groupKey, h.collapsed) end

-- The open entry's card under its card, stacked and indented with it; answers the height it takes
-- (0 for another card). `width` is the card's.
local function drawDetail(cv, drop, y, width, st)
    if drop.entry ~= st.expanded then return 0 end
    local card = cv.card
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", cv.content, "TOPLEFT", K.ROW_INDENT, -y)
    local h = NS.HistoryCard.Paint(card, drop, width, NS.WindowHistory.CardContext(drop))
    card:Show()
    cv.cardEntry = drop.entry
    return h + NS.CompactGroup.GAP
end

local SPEC = { newCard = newCard, paint = paintCard, header = historyHeader, toggle = toggle, after = drawDetail,
    indent = K.ROW_INDENT }

-- The pane's own scroll view, above its strip, with its stacked detail card.
local function buildView(pane)
    local cv = NS.CompactGroup.BuildView(pane, K.STRIP_H)
    cv.card = NS.HistoryCard.Build(cv.content, true)
    return cv
end

--- Draw the compact layout's cards for the tab's entries (WindowHistory's refresh, every repaint),
--- or, in the full layout, hide them.
--- @param pane table the History pane
--- @param entries table NS.WindowHistory.Entries' answer
--- @param compact boolean
function CH.Refresh(pane, entries, compact)
    local CG = NS.CompactGroup
    local cv = CG.Swap(pane, compact, buildView)
    if not cv then return end
    local st = { nowEpoch = time(), dateFn = date, ownRealm = NS.Compat.NormalizedRealm(),
        expanded = NS.WindowHistory.Expanded() }
    cv.card:Hide()
    cv.cardEntry = nil
    CG.Draw(cv, entries, CG.CardWidth(pane), SPEC, st)
    CG.Settle(pane, cv)
end

--- The drawn compact pane, for the suites (WindowHistory.Drawn's shape in the compact layout).
--- @param pane table
--- @return table|nil
function CH.Drawn(pane)
    local cv = pane.compactView
    if not cv then return nil end
    return { compact = true, rows = cv.cardPool.active, headers = cv.headPool.active, entries = pane.entries,
        pane = pane, strip = pane.strip, scroll = cv.scroll, card = cv.card, cardEntry = cv.cardEntry }
end
