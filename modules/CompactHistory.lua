local _, NS = ...
-- modules/CompactHistory.lua — the History tab in the compact layout (compact spec §3, DW-C3): the
-- same kept entries as the full table, each a three-line card under a one-line header.
--
-- ONE PANE, TWO LAYOUTS. modules/WindowHistory.lua computes the tab's entries (WH.Entries over the
-- kept groups and its filters) once per repaint and hands them here in the compact layout; this
-- file draws them into its own scroll view over the same pane through NS.CompactGroup's shared kit.
-- Read-only, as the table is: a right-click on a card opens the row menu (Mark as declined, or
-- Clear declined: NS.WindowHistory.OpenMenu).
--
-- THE CARD. What each piece says, its tone and its tooltip are NS.CompactCards.History's:
--
--   line 1  ilvl item (the item level before the name, feedback-10 spec §2)   outcome (in its tone)
--   line 2  looter (class color, ⊕ from another realm) · slot · type · trade       17:02 (dimmed)
--   line 3  You ▼4   Them ≈0
--           (the full table's Me and Them: a kept entry holds no worn items, so the verdict alone;
--           the labels gold, Them a fixed gap after You, as on Drops' cards)
--
-- THE HEADERS are the full table's header button, painted with the short form
-- (NS.CompactCards.HistoryHeader: `2d` once a day old); a click collapses the group as before.
--
-- THE STRIP is the full layout's (NS.WindowHistory places it for both): the kept-history line,
-- Expand all / Collapse all and Clear history at the one footer width (feedback-15 spec §2).

NS.CompactHistory = NS.CompactHistory or {}
local CH = NS.CompactHistory
local K  = NS.Constants.WINDOW

-- ── building a card ─────────────────────────────────────────────────────────────────────────

-- A right-click on the card, or on any piece of it, opens the row menu.
local function onPiece(card, button)
    if button == "RightButton" then NS.WindowHistory.OpenMenu(card.entry, card) end
end

local function onMouseUp(self, button) onPiece(self, button) end

local function newCard(content)
    local CG, WG = NS.CompactGroup, NS.WindowGroup
    local card = CreateFrame("Button", nil, content)
    card.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    card.cells = {}
    card.onPiece = onPiece
    CG.Background(card)
    card.selected:Hide()
    card.icon = WG.ItemButton(card, K.ROW_ICON)
    card.icon:SetPoint("LEFT", card, "LEFT", CG.PAD + CG.QUALITY_W, 0)
    local item = CG.Piece(card, "item")
    item.hit.showItem = true   -- the game's own tooltip (WindowGroup.ItemHover)
    WG.ItemHover(item.hit, card.icon)
    CG.Piece(card, "ilvl")
    CG.Piece(card, "outcome")
    CG.BuildLineTwo(card, "time")
    CG.BuildHalf(card, "you")
    CG.BuildHalf(card, "them")
    card:SetScript("OnMouseUp", onMouseUp)
    return card
end

-- The pieces placed against the card's lines, once per text size.
local function layout(card, m)
    if card.dwLine == m.line then return end
    card.dwLine = m.line
    local CG = NS.CompactGroup
    local at, x, P, c = CG.At, CG.TextLeft(m), CG.PAD, card.cells
    local y1 = CG.LineY(m, 1)
    card.icon:SetSize(m.icon, m.icon)
    at(c.outcome.text, "RIGHT", card, "TOPRIGHT", -P, y1)
    CG.PlaceLineOne(card, x, y1, c.outcome.text)
    at(c.looter.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 2))
    at(c.time.text, "RIGHT", card, "TOPRIGHT", -P, CG.LineY(m, 2))
    at(c.youLabel.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 3))
    CG.PlaceThem(card)
end

-- ── painting a card ─────────────────────────────────────────────────────────────────────────

local function paintCard(card, drop, _, m, st)
    local CG, WG, c = NS.CompactGroup, NS.WindowGroup, card.cells
    card.dropId, card.entry = drop.id, drop.entry
    card:SetHeight(m.height)
    layout(card, m)
    NS.WindowRows.ApplyRowFont(card, m.fontSize)
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
    CG.PaintHalf(card, "you", cc.you)
    CG.PaintHalf(card, "them", cc.them)
end

local function historyHeader(e, st)
    local g = e.group
    return NS.CompactCards.HistoryHeader(g, e.count, st.nowEpoch, NS.WindowFooter.SITUATION_LABEL[g.situation],
        e.collapsed, e.hidden, e.filter)
end

local function toggle(h) NS.WindowHistory.ToggleGroup(h.groupKey, h.collapsed) end

local SPEC = { newCard = newCard, paint = paintCard, header = historyHeader, toggle = toggle }

-- The pane's own scroll view, above its strip.
local function buildView(pane) return NS.CompactGroup.BuildView(pane, K.STRIP_H) end

--- Draw the compact layout's cards for the tab's entries (WindowHistory's refresh, every repaint),
--- or, in the full layout, hide them.
--- @param pane table the History pane
--- @param entries table NS.WindowHistory.Entries' answer
--- @param compact boolean
function CH.Refresh(pane, entries, compact)
    local CG = NS.CompactGroup
    local cv = CG.Swap(pane, compact, buildView)
    if not cv then return end
    local st = { nowEpoch = time(), dateFn = date, ownRealm = NS.Compat.NormalizedRealm() }
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
        pane = pane, strip = pane.strip, scroll = cv.scroll }
end
