local _, NS = ...
-- modules/CompactGroup.lua — the Drops tab in the compact layout (compact spec §2, DW-C2):
-- the same entries as the full table, each drop a four-line card under a one-line header.
--
-- ONE PANE, TWO LAYOUTS. modules/WindowGroup.lua builds the tab and computes its entries (the
-- feed's groups, the filters, the order) once per repaint, then hands them here in
-- the compact layout (WG.IsCompact) and draws its table otherwise. This file adds its own scroll
-- frame to the same pane, built on the first compact repaint, and shows one or the other; the
-- empty state and the filters' line stay WindowGroup's. Nothing here filters, judges or sends.
--
-- THE CARD. Four lines, the item button spanning them (NS.WindowGroup.ItemButton: the game's own
-- tooltip, shift-click links, ctrl-click tries on), a thin bar in the item's quality color at the
-- left edge, and between the two the full table's expand indicator (NS.WindowGroup.RowChevron:
-- chevron-down, chevron-up while the card's detail card is open, muted white) centered on line 1.
-- Like the full table's rows, each card and its detail card are indented K.ROW_INDENT under their
-- header (feedback-5 spec §0; GROUP_SPEC.indent). What each piece says, its tone and its reason tooltip are NS.CompactCards.Group's
-- (pure, built from the full view's cells):
--
--   line 1  ilvl item (fresh) (the item level before the name, the name in quality color with the
--           game's tooltip, then the inspect freshness in brackets, dimmed: `(2m)`, `(cached)`,
--           `(…)`, none at all where there is nothing to say; the name is cut, the freshness not;
--           feedback-10 spec §2)
--   line 2  looter (class color; another realm named in its tooltip) · slot · type      [ Ask ]
--           (the full table's states; Offer on your own drop, which opens the Offer panel:
--           NS.WindowOwn, feedback-5 spec §2; with neither the gray `No action` button, its reason
--           in its tooltip, feedback-11 spec §1). The button is two lines tall, lines 2 and 3,
--           its label centered in it (CG.AskHeight, CG.AskY; feedback-22, feedback-23), so line 1's
--           name runs the card's width)
--   line 3  Trade No Bonus roll
--           (beside the button, cut at its left edge (CG.TradeInset); the full table's Trade cell:
--           Yes, No or ? in its tone, then its short reason in the muted gray,
--           WindowCells.TradeText. Trade sat on line 2 as a bare word, at the end of line 3, then
--           on line 4 (feedback-22) until feedback-25)
--   line 4  You 321 ▼26 / 308 ▼13   Them 298/296 ⊘ Can't use
--           (under the button, to the card's right inset, as line 1's name runs: two rings on both
--           halves fit there on one line (feedback-25; Them wrapped to line 4 before Trade beside
--           the button, feedback-23); dual marks that still do not fit give way to the one mark,
--           CG.PaintHalves) (the full table's Me and Them cells without their icons, feedback-6
--           spec §1; the labels gold, Them a fixed gap after You, feedback-10 spec §2; your own
--           drop: line 2's looter reads `Name [YOU]` and Them `Upgrade for N` (feedback-7 spec §2),
--           every member it upgrades in the tooltip)
--
-- NO TRADE WINDOW on the card (feedback-10 spec §2): the full table's Trade window column, the
-- strip's next expiry and the detail card say it; the card has nothing to tick each second.
--
-- Every piece is a font string with a hit frame over it that carries its tooltip, placed by the
-- row-tooltip helper (NS.RowTooltip, DW-B2) at the card's top right, just outside the window: the
-- card is marked `tipRow`. A click anywhere on the card but a button expands it, as a row click
-- does (NS.WindowGroup.ToggleExpand, one at a time, session-only); a plain click on the item
-- button does too.
--
-- THE SIZE. Text follows `window.fontSize` through NS.WindowRows (Default is the template's own
-- size, as in the full table); a card's line height, height and icon follow from it (Metrics,
-- pure): about 64 pixels at the default size. `window.rowHeight` is the full table's and does not
-- apply.
--
-- THE HEADERS are the full table's header button (NS.WindowGroup.NewHeader, so a click collapses
-- the group the same way), painted with the short form (NS.CompactCards.Header), the full view's
-- tooltip (its facts as rows, the hidden-drop lines) on it.
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
-- THE SHARED KIT. History draws its cards the same way (modules/CompactHistory.lua, DW-C3), so the
-- frame pieces live here once and are exported: the
-- pieces and their hit frames (Piece, FontString, MonoString, Background), line 1's item level
-- and name (PlaceLineOne), line 2 and the halves (BuildLineTwo/PaintLineTwo, BuildHalves/PaintHalf,
-- PlaceThem), the pane's own scroll view (BuildView),
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
CG.ICON_MIN, CG.ICON_MAX = 24, 60
CG.LINES = 4           -- a card's lines (feedback-22: Trade on a line of its own)
CG.QUALITY_W = 2       -- the quality bar at a card's left edge
CG.LEAD = K.ROW_CHEVRON + K.CHEVRON_GAP   -- a Drops card's chevron and the gap before its icon
CG.ILVL_GAP = 4        -- line 1: between the item level and the name (feedback-10 spec §2)
CG.HALVES_GAP = 12     -- You and Them: between one half's last piece and the next label (feedback-10 spec §2)
CG.ASK_GAP = 6         -- lines 2 and 3: between their text and the action button

-- The muted dot between line 2's pieces (an escape, so the piece keeps its own tone): the skin's idle
-- gray `dw.idle` (Ka0s Default 9e9ea3), read at each paint so it follows a skin switch.
local function sep() return (NS.SkinEscape("dw.idle") or "") .. "·|r " end

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- A card's metrics at a `window.fontSize` (nil = Default, the small template's own size):
--- { fontSize, size, line, height, icon }. CG.LINES lines of `size + LINE_EXTRA`, a PAD above and
--- below; the icon spans the lines, within ICON_MIN..ICON_MAX.
--- @param fontSize number|nil NS.WindowRows.FontSize's answer
--- @return table
function CG.Metrics(fontSize)
    local size = fontSize or K.COUNTDOWN_FONT
    local line = size + CG.LINE_EXTRA
    local n = CG.LINES
    return { fontSize = fontSize, size = size, line = line, height = n * line + 2 * CG.PAD,
        icon = min(CG.ICON_MAX, max(CG.ICON_MIN, n * line - 6)) }
end

--- The middle of line `i` (1..CG.LINES), as an offset down from the card's top.
--- @param m table CG.Metrics' answer
--- @param i number
--- @return number
function CG.LineY(m, i) return -(CG.PAD + (i - 0.5) * m.line) end

--- The action button's height: two lines (feedback-22), its label centered in it.
--- @param m table CG.Metrics' answer
--- @return number
function CG.AskHeight(m) return 2 * m.line end

--- The action button's middle: between lines 2 and 3 (feedback-23), as an offset down from the
--- card's top.
--- @param m table
--- @return number
function CG.AskY(m) return -(CG.PAD + 2 * m.line) end

--- Where the text starts: after the quality bar, the chevron's lead (`lead`, CG.LEAD on a Drops
--- card, 0 where a card has no chevron) and the icon.
--- @param m table
--- @param lead number|nil
--- @return number
function CG.TextLeft(m, lead) return CG.PAD + CG.QUALITY_W + (lead or 0) + m.icon + 6 end

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

-- A table row's plain text takes the Tables font block's color (NS.WindowRows.SetTone, DW-01).
local function setTone(fs, tone) NS.WindowRows.SetTone(fs, tone) end
CG.SetTone = setTone

local function tipOf(f) return unpack(f.tipLines or {}) end

local function at(region, ...)
    region:ClearAllPoints()
    region:SetPoint(...)
end
CG.At = at

local function qualityColor(drop)
    local q = type(drop.facts) == "table" and drop.facts.quality or nil
    local r, g, b = NS.QualityColor(q)   -- the skin's q.* token, else the client's color (E4)
    if r then return r, g, b end
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

-- A Drops card's click expands its detail card (a piece's too).
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
    NS.Skin.Font(fs)   -- the skin's face; the color is the piece's tone, set at paint time
    return fs
end
CG.FontString = fontString

local function monoString(card)
    local fs = card:CreateFontString(nil, "OVERLAY")
    NS.SkinMono(fs, 12)
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
    card.selected = card:CreateTexture(nil, "BACKGROUND")
    card.selected:SetAllPoints(card)
    NS.WindowGroup.PaintRowWashes(card)   -- the Drops rows' stripe and expanded wash, from the skin
    card.quality = card:CreateTexture(nil, "ARTWORK")
    card.quality:SetWidth(CG.QUALITY_W)
    card.quality:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    card.quality:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 0, 0)
end
CG.Background = buildBackground

local function buildAsk(card)
    local W = NS.Window
    card.ask = W.TextButton(card, K.ASK_W, "chat", NS.L["Ask"], function(b) NS.WindowOwn.PressAction(b) end)
    W.AttachTooltip(card.ask, function() return tipOf(card.ask) end, "row")
end

--- Line 1's item level then the name (feedback-10 spec §2): the level at `x` on line 1, the name
--- CG.ILVL_GAP after it and cut at the card's right inset (History's outcome moved to line 2,
--- feedback-25), so the name is cut first and the level always shows. A Drops card places its own
--- (the freshness follows the name there).
--- @param card table
--- @param x number the text's left edge
--- @param y number line 1's middle
function CG.PlaceLineOne(card, x, y)
    local c = card.cells
    at(c.ilvl.text, "LEFT", card, "TOPLEFT", x, y)
    at(c.item.text, "LEFT", c.ilvl.text, "RIGHT", CG.ILVL_GAP, 0)
    c.item.text:SetPoint("RIGHT", card, "RIGHT", -CG.PAD, 0)
end

local function buildLineOne(card)
    local WG = NS.WindowGroup
    card.chevron = WG.RowChevron(card)   -- placed on line 1 (layout)
    card.icon = WG.ItemButton(card, K.ROW_ICON)
    card.icon:SetPoint("LEFT", card, "LEFT", CG.PAD + CG.QUALITY_W + CG.LEAD, 0)
    local item = piece(card, "item")
    item.hit.showItem = true   -- the game's own tooltip (WindowGroup.ItemHover)
    WG.ItemHover(item.hit, card.icon)
    piece(card, "ilvl")
    piece(card, "fresh")   -- `(2m)` right after the name (layout)
    buildAsk(card)
end

--- Line 2's pieces: looter (and its gold ` [YOU]` mark on your own drop: feedback-7 spec
--- §2), slot, type (feedback-4 spec §3), then `right` (right-aligned: History's time, which its
--- card places on line 3 since feedback-25; nil on a Drops card, whose action button sits there).
--- @param card table
--- @param right string|nil the right piece's key
function CG.BuildLineTwo(card, right)
    local looter = piece(card, "looter")
    looter.mark = NS.WindowRows.NewMark(card, looter.text)
    local slot = piece(card, "slot")
    slot.text:SetPoint("LEFT", looter.text, "RIGHT", 4, 0)
    local kind = piece(card, "armorType")
    kind.text:SetPoint("LEFT", slot.text, "RIGHT", 4, 0)
    if right then piece(card, right) end
end

-- One half of You and Them's line (feedback-6 spec §1), or Trade: the label (`cells[key .. "Label"]`), then the worn item
-- level, the glyph and the difference or word (`cells[key]`: `level`, `glyph`, `text`), one tooltip
-- over them all; a dual mark's first part and its `/` before them (`leadLevel`, `leadGlyph`,
-- `leadText`, `sep`: feedback-21 H7). CG.PaintHalf places each piece after the last one shown.
function CG.BuildHalf(card, key)
    local label = { text = fontString(card) }
    local half = { level = fontString(card), glyph = monoString(card), text = fontString(card),
        leadLevel = fontString(card), leadGlyph = monoString(card), leadText = fontString(card), sep = fontString(card) }
    half.hit = hitOver(card, label.text, half.text)
    card.cells[key .. "Label"], card.cells[key] = label, half
end

--- The two halves, You and Them, and Trade.
--- @param card table
function CG.BuildHalves(card)
    for _, key in ipairs({ "you", "them", "trade" }) do CG.BuildHalf(card, key) end
end

-- The gaps in a half: between the label, the level and the verdict, and after a glyph.
CG.HALF_GAP, CG.HALF_GLYPH_GAP = 3, 2

--- You under Trade's label, a line down, and Them CG.HALVES_GAP after You's last piece
--- (feedback-10 spec §2: the halves read close together, not at a third of the card's width;
--- feedback-25: Trade on line 3, You and Them on line 4, on both tabs' cards). A half's text is its
--- last piece, shown or empty.
--- @param card table
--- @param m table CG.Metrics' answer (its `line`)
function CG.PlaceThem(card, m)
    local c = card.cells
    at(c.youLabel.text, "LEFT", c.tradeLabel.text, "LEFT", 0, -m.line)
    at(c.themLabel.text, "LEFT", c.you.text, "RIGHT", CG.HALVES_GAP, 0)
end

--- Where a Drops card's Trade is cut, in from the card's right edge: before the action button
--- (feedback-25: Trade on line 3, beside it).
--- @return number
function CG.TradeInset() return CG.PAD + K.ASK_W + CG.ASK_GAP end

local function newCard(content)
    local card = CreateFrame("Button", nil, content)
    card.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    card.cells = {}
    card.onPiece = groupPiece
    buildBackground(card)
    buildLineOne(card)
    CG.BuildLineTwo(card)
    CG.BuildHalves(card)
    card:SetScript("OnClick", function(self) NS.WindowGroup.ToggleExpand(self.dropId) end)
    return card
end

-- The pieces placed against the card's lines, once per text size.
local function layout(card, m)
    if card.dwLine == m.line then return end
    card.dwLine = m.line
    local x, P, c = CG.TextLeft(m, CG.LEAD), CG.PAD, card.cells
    local y1 = CG.LineY(m, 1)
    card.icon:SetSize(m.icon, m.icon)
    at(card.chevron, "LEFT", card, "TOPLEFT", P + CG.QUALITY_W, y1)
    at(c.ilvl.text, "LEFT", card, "TOPLEFT", x, y1)
    at(c.item.text, "LEFT", c.ilvl.text, "RIGHT", CG.ILVL_GAP, 0)
    at(c.fresh.text, "LEFT", c.item.text, "RIGHT", NS.WindowRows.MARK_GAP, 0)
    at(card.ask, "RIGHT", card, "TOPRIGHT", -P, CG.AskY(m))
    card.ask:SetHeight(CG.AskHeight(m))
    card.ask.label:SetJustifyV("MIDDLE")
    at(c.looter.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 2))
    at(c.tradeLabel.text, "LEFT", card, "TOPLEFT", x, CG.LineY(m, 3))
    CG.PlaceThem(card, m)
end

-- ── painting a card ─────────────────────────────────────────────────────────────────────────

local function paintText(cell, c, prefix)
    cell.text:SetText(prefix and (prefix .. c.text) or c.text)
    setTone(cell.text, c.tone)
    cell.hit.tipLines = c.tip
end
CG.PaintText = paintText

-- The Ask button in the full table's states (WindowGroup's paintActions, the same cell), your own
-- drop's Offer, or the gray No action with its reason where neither is offered (feedback-11 spec §1).
local function paintAsk(card, a, id)
    local b = card.ask
    b.dropId, b.offer = id, a.offer == true
    NS.Window.SetButtonMark(b, a.text, a.icon)
    b:SetEnabled(a.enabled)
    b:SetAlpha(a.enabled and 1 or 0.6)
    b.tipLines = a.tip
    b.state = a.state
    NS.WindowGroup.ToneButton(b, a.state, a.kind)   -- whose move it is (feedback-4 spec §1; Offer cyan, feedback-6 §2)
end

-- Line 1's freshness, `(2m)`, right after the name, or nothing (CompactCards.FreshMark); the name
-- takes what is left of the line after the item level and it, to the card's right inset (the action
-- button is lines 2 and 3's since feedback-23: NS.WindowRows.MarkedWidth), so the name is cut and
-- the freshness is not.
local function paintFresh(card, cc, width, m)
    local c = card.cells
    local mark = NS.CompactCards.FreshMark(cc.fresh)
    c.fresh.text:SetText(mark or "")
    setTone(c.fresh.text, "muted")
    c.fresh.text:SetShown(mark ~= nil); c.fresh.hit:SetShown(mark ~= nil)
    c.fresh.hit.tipLines = cc.fresh.tip
    local item = c.item.text
    local room = width - CG.TextLeft(m, CG.LEAD) - CG.PAD - (c.ilvl.text:GetStringWidth() or 0) - CG.ILVL_GAP
    local full = item.GetUnboundedStringWidth and item:GetUnboundedStringWidth() or nil
    item:SetWidth(NS.WindowRows.MarkedWidth(room, full, mark and (c.fresh.text:GetStringWidth() or 0) or nil))
end

local function paintLineOne(card, drop, cc, width, m)
    local WG, c = NS.WindowGroup, card.cells
    WG.SetItem(card.icon, drop.link, WG.Where(drop))
    card.icon.dropId = drop.id
    NS.Glow.Apply(card.icon, drop)   -- the upgrade glow (modules/Glow.lua); sized by layout, above
    card.quality:SetColorTexture(qualityColor(drop))
    c.item.text:SetText(cc.item.text)
    c.item.text:SetTextColor(qualityColor(drop))
    c.item.hit.tipLines = nil   -- the real item tooltip instead
    paintText(c.ilvl, cc.ilvl)
    paintFresh(card, cc, width, m)
    paintAsk(card, cc.ask, drop.id)
end

--- Line 2 painted from a card model: the looter in class color, its ` [YOU]`, slot, type
--- and `right`. Slot (and the looter's tooltip) follows the mark while it shows.
--- @param card table
--- @param cc table a CompactCards card
--- @param right string|nil the right piece's key (History's `time`; nil on a Drops card)
function CG.PaintLineTwo(card, cc, right)
    local c = card.cells
    paintText(c.looter, cc.looter)
    local r, g, b = NS.Compat.ClassColor(cc.looter.classFile)
    if r then c.looter.text:SetTextColor(r, g, b) end
    c.looter.mark:SetText(cc.looter.you or "")
    c.looter.mark:SetShown(cc.looter.you ~= nil)
    local last = cc.looter.you and c.looter.mark or c.looter.text
    at(c.slot.text, "LEFT", last, "RIGHT", 4, 0)
    c.looter.hit:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 0, 0)
    local dot = sep()
    paintText(c.slot, cc.slot, dot)
    paintText(c.armorType, cc.armorType, dot)
    if right then paintText(c[right], cc[right]) end
end

-- A dual mark's first part and its `/` after the label (feedback-21 H7); answers the last piece.
local function placeLead(h, label)
    at(h.leadLevel, "LEFT", label, "RIGHT", CG.HALF_GAP, 0)
    at(h.leadGlyph, "LEFT", h.leadLevel, "RIGHT", CG.HALF_GAP, 0)
    at(h.leadText, "LEFT", h.leadGlyph, "RIGHT", CG.HALF_GLYPH_GAP, 0)
    at(h.sep, "LEFT", h.leadText, "RIGHT", CG.HALF_GAP, 0)
    return h.sep
end

-- A half's level, glyph and text placed after its label (or a dual mark's lead, `second`), each
-- after the last piece shown.
local function placeHalf(h, label, p, second)
    local first = second and placeLead(h, label) or label
    at(h.level, "LEFT", first, "RIGHT", CG.HALF_GAP, 0)
    local last = p.level and h.level or first
    at(h.glyph, "LEFT", last, "RIGHT", CG.HALF_GAP, 0)
    if p.glyph then
        at(h.text, "LEFT", h.glyph, "RIGHT", CG.HALF_GLYPH_GAP, 0)
    else
        at(h.text, "LEFT", last, "RIGHT", CG.HALF_GAP, 0)
    end
end

-- Trade, alone on its line, runs to the button (a Drops card, feedback-25), to History's time, or
-- to the card's right inset, and is cut there (feedback-11 spec §0).
local function boundTrade(card, text)
    if card.dwTradeBefore then
        text:SetPoint("RIGHT", card.dwTradeBefore, "LEFT", -CG.ASK_GAP, 0)
    else
        text:SetPoint("RIGHT", card, "RIGHT", -(card.dwTradeInset or CG.PAD), 0)
    end
end

--- One half (You, Them or Trade) painted (CompactCards.Half's): its label (gold, feedback-10 spec §2), the worn
--- item level (plain, or
--- a muted word), the glyph and the difference or word in the verdict's tone, each placed after the
--- last piece shown. A dual mark (`parts`, feedback-21 H7) draws each worn item's level, glyph and
--- difference, `You 321 ▼10 / 324 ▼23`, the second part in the single pieces; with `single`, the one
--- mark instead (CG.PaintHalves, when the dual marks do not fit: feedback-21 R5). Trade's word is
--- followed by its short reason in the muted gray (WindowCells.TradeText, feedback-22), cut
--- `card.dwTradeInset` in from the card's right edge (CG.TradeInset on a Drops card), or CG.ASK_GAP
--- before `card.dwTradeBefore` (History's time, line 3's right piece), else at its inset.
--- @param card table
--- @param key string `you` or `them`
--- @param half table
--- @param single boolean|nil
function CG.PaintHalf(card, key, half, single)
    local c = card.cells
    local label, h = c[key .. "Label"].text, c[key]
    label:SetText(half.label)
    label:SetTextColor(NS.SkinColor("text.heading"))   -- gold (feedback-10 spec §2)
    local second = h.leadLevel and NS.WindowGroup.PaintLead(h, not single and half.parts or nil) or nil
    local p = second or half
    h.level:SetText(p.level or "")
    setTone(h.level, second and "plain" or half.levelTone)
    h.glyph:SetText(p.glyph or "")
    setTone(h.glyph, p.tone)
    h.text:SetText(key == "trade" and NS.WindowCells.TradeText(p) or p.text)
    setTone(h.text, p.tone)
    h.hit.tipLines = half.tip
    placeHalf(h, label, p, second)
    if key == "trade" then boundTrade(card, h.text) end
end

local HALVES = { "you", "them", "trade" }
local YOU_THEM = { "you", "them" }   -- one line; Trade has its own (feedback-22)

-- A piece's width on one line (unbounded: Trade is cut at the card's inset), or nil while its
-- font is not loaded.
local function pieceWidth(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    return fn(fs)
end

-- A half's pieces in CG.PaintHalf's order, after its label, and the gap before each.
local HALF_PIECES = { "leadLevel", "leadGlyph", "leadText", "sep", "level", "glyph", "text" }
local HALF_GAPS = { CG.HALF_GAP, CG.HALF_GAP, CG.HALF_GLYPH_GAP, CG.HALF_GAP, CG.HALF_GAP, CG.HALF_GAP, CG.HALF_GLYPH_GAP }

-- A painted half's width: its label and each piece shown; nil while one cannot be measured.
local function halfWidth(card, key)
    local h = card.cells[key]
    local w = pieceWidth(card.cells[key .. "Label"].text)
    if not w then return nil end
    for i, k in ipairs(HALF_PIECES) do
        local fs = h[k]
        if fs:IsShown() ~= false and (fs:GetText() or "") ~= "" then
            local pw = pieceWidth(fs)
            if not pw then return nil end
            w = w + HALF_GAPS[i] + pw
        end
    end
    return w
end

--- Whether painted You and Them, CG.HALVES_GAP apart, fit `room`. True while a piece cannot be
--- measured.
--- @param card table
--- @param room number the line's width, from its left edge to the card's right inset
--- @return boolean
function CG.HalvesFit(card, room)
    local w = CG.HALVES_GAP
    for _, key in ipairs(YOU_THEM) do
        local hw = halfWidth(card, key)
        if not hw then return true end
        w = w + hw
    end
    return w <= room
end

--- You, Them and Trade painted (CompactCards' halves). With `room` (You and Them's line, to the
--- card's right inset on a Drops card: feedback-25), dual marks (feedback-21 H7) that do not fit it
--- (a larger Font size) give way to the one mark each (feedback-21 R5).
--- @param card table
--- @param cc table a CompactCards card
--- @param room number|nil
function CG.PaintHalves(card, cc, room)
    for _, key in ipairs(HALVES) do CG.PaintHalf(card, key, cc[key]) end
    if room and (cc.you.parts or cc.them.parts) and not CG.HalvesFit(card, room) then
        CG.PaintHalf(card, "you", cc.you, true)
        CG.PaintHalf(card, "them", cc.them, true)
    end
end

-- What every card of one repaint shares: your gear and class, the transmog ask setting and your realm.
local function sharedCtx(now)
    local snap = NS.Gear.Snapshot()
    return { now = now, equipped = snap and snap.equipped, classFile = snap and snap.classFile, transmogAsk = NS.Setting("messages.transmogAsk") == true,
        ownRealm = NS.Compat.NormalizedRealm() }
end

local function cardCtx(drop, shared)
    local state, reason = NS.WindowGroup.AskState(drop)
    local insp = NS.TestMode.InspectOf(drop)
    local ctx = { now = shared.now, equipped = NS.TestMode.GearOf(drop, shared.equipped), classFile = shared.classFile,
        gear = insp and insp.gear, askState = state,
        askReason = reason, transmogAsk = shared.transmogAsk, ownRealm = shared.ownRealm }
    if drop.isMine then   -- your own drop's Offer and Upgrade for N (feedback-5 spec §2)
        local WO = NS.WindowOwn
        ctx.revealed, ctx.offerTone = WO.IsRevealed(drop.id), (WO.ToneStates(drop))
    end
    return ctx
end

local function paintCard(card, drop, width, m, shared)
    card.dropId, card.drop = drop.id, drop
    card.dwTradeInset = CG.TradeInset()
    card:SetHeight(m.height)
    layout(card, m)
    NS.WindowRows.ApplyRowFont(card, m.fontSize, m.font)
    local open = NS.WindowGroup.Expanded() == drop.id
    card.selected:SetShown(open)
    NS.WindowGroup.PaintChevron(card.chevron, open)
    local cc = NS.CompactCards.Group(drop, cardCtx(drop, shared))
    card.model = cc
    paintLineOne(card, drop, cc, width, m)
    CG.PaintLineTwo(card, cc)
    CG.PaintHalves(card, cc, width - CG.TextLeft(m, CG.LEAD) - CG.PAD)
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
--- @param bottom number|nil the strip under the cards (History's kept-history line; the Drops strip
---   moves the view's bottom edge itself, modules/DropsStrip.lua)
--- @return table cv { scroll, content, cardPool, headPool }
function CG.BuildView(pane, bottom)
    local cv = {}
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, bottom or 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end   -- the skin's corridor and knob (D2)
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

-- `x` indents a card (and its detail card) under its header; the header takes the full width.
local function place(frame, content, y, width, x)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, -y)
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
---   toggle = OnClick for its headers (nil keeps Drops'), after = fn(cv, drop, y, width, st) ->
---   extra height under a card (the detail card), indent = how far a card sits in from its header
---   (nil none) }; `st` is the repaint's shared state. A card's `width` is the view's less its indent.
--- @param cv table
--- @param entries table
--- @param width number
--- @param spec table
--- @param st table|nil
function CG.Draw(cv, entries, width, spec, st)
    local m = CG.Metrics(NS.WindowRows.FontSize(NS.Setting("window.fontSize")))
    m.font = NS.WindowRows.ReadFont()   -- the Tables font block, once per repaint (DW-01)
    local y, Pool = 0, NS.Pool
    local indent = spec.indent or 0
    local cardW = width - indent
    factories(cv, spec)
    for i, e in ipairs(entries) do
        if e.kind == "header" then
            local h = Pool.Acquire(cv.headPool, cv.makeHeader)
            place(h, cv.content, y, width)
            CG.PaintHeader(h, e, spec.header(e, st), width)
            y = y + K.GROUP_H
        else
            local card = Pool.Acquire(cv.cardPool, cv.makeCard)
            place(card, cv.content, y, cardW, indent)
            card.stripe:SetShown(i % 2 == 0)
            spec.paint(card, e.drop, cardW, m, st)
            y = y + m.height + CG.GAP
            if spec.after then y = y + spec.after(cv, e.drop, y, cardW, st) end
        end
    end
    cv.content:SetSize(width, max(y, 1))
end

-- The open card's detail card under it, stacked and indented with it; answers the height it takes
-- (0 for another card). `width` is the card's.
local function drawDetail(cv, drop, y, width, st)
    if drop.id ~= st.expanded then return 0 end
    place(cv.card, cv.content, y, width, K.ROW_INDENT)
    local h = NS.DetailCard.Paint(cv.card, drop, width, st.now)
    cv.card:Show()
    cv.cardDropId = drop.id
    return h + CG.GAP
end

local function groupHeader(e, st)
    local g = e.group
    local sit = NS.WindowFooter.SITUATION_LABEL[g.situation]
    return NS.CompactCards.Header(g, e.count, st.now, sit, e.collapsed, e.hidden, e.filter)
end

local function cardIcon(card) return card.icon end

local GROUP_SPEC = { newCard = newCard, paint = paintCard, header = groupHeader, after = drawDetail,
    indent = K.ROW_INDENT }

--- Draw the compact layout's cards for `entries` (WindowGroup's refresh, every repaint), or, in the
--- full layout, hide them (carrying the scroll offset over to the table on the way out).
--- @param pane table the Drops pane
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
    NS.Glow.StopFree(cv.cardPool, cardIcon)   -- the cards this repaint left unused
    CG.Settle(pane, cv)
end

--- The drawn compact pane, for the suites (WindowGroup.Drawn's shape in the compact layout):
--- { compact = true, rows (the cards), headers, entries, pane, card, cardDropId, empty, scroll, summary }.
--- @param pane table
--- @return table|nil
function CG.Drawn(pane)
    local cv = pane.compactView
    if not cv then return nil end
    return { compact = true, rows = cv.cardPool.active, headers = cv.headPool.active, entries = pane.entries,
        pane = pane, card = cv.card, cardDropId = cv.cardDropId, empty = pane.emptyState, scroll = cv.scroll,
        summary = pane.summaryData }
end
