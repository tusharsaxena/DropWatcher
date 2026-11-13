local _, NS = ...
-- modules/WindowPending.lua — the Drops tab's Rolling now section (Forever port design §5.3, plan
-- DW-FP15): every drop seen but not yet assigned (NS.Pending's items: an open group-loot roll),
-- above the boss groups, in both layouts, and the Rolls box a roll table is drawn in.
--
-- WHERE IT SHOWS. modules/WindowGroup.lua's table calls WP.Draw once per repaint, before its first
-- header, and moves its rows down by the height answered; modules/CompactGroup.lua's cards call
-- WP.DrawCompact the same way. The section is there only while a pending item exists and
-- `rolls.show` is on (off hides the section and the resolved drop's Rolls box, while the store
-- still tracks every roll: design §11.1). Its header is the boss groups' header button
-- (NS.WindowGroup.NewHeader), keyed WP.KEY in the same session-only collapsed map, so a click
-- collapses it the same way; it is open until the player collapses it.
--
-- A ROW (the full layout) shows the item's icon and name, your verdict (Me: the feed's own
-- WindowCells.Me over the item's `me`), the roll summary (NS.RollCells.Summary) and the time left
-- (RollCells.Timer, on the loot history's clock). A roll has no row action: the game's own popup is
-- where you roll (the master-loot ask arrives with its kind, DW-FP19). A click on the row expands
-- its roll table inline under it (one at a time, session-only: NS.State.windowPending), as a drop
-- row's detail card does. The compact layout's card (CompactGroup's PendingCard) says the same in
-- four lines.
--
-- THE ROLLS BOX (WP.BuildRollsBox, WP.PaintRollsBox) is a titled card of NS.RollCells.Rows: each
-- player's glyph, name in class color, choice word and number, the winner marked `Won` and Blizzard's
-- win protection `(protected)`, flowed into as many columns as the width holds (RollCells.Grid) at
-- most MAX_LINES lines tall, a last `and n more` line when they do not all fit. The inline roll
-- table and the resolved drop's detail card (modules/DetailCard.lua) both draw it.
--
-- THE TIMERS MOVE each second while a shown roll is open: Window.lua's countdown ticker asks
-- WG.LiveCountdown, which asks WP.Live, and WG.TickCountdowns calls WP.Tick, which repaints the
-- time left and the summary alone. Window.lua repaints the whole tab on PendingChanged.

NS.WindowPending = NS.WindowPending or {}
local WP = NS.WindowPending
local K  = NS.Constants.WINDOW
local L  = NS.L

local max, min = math.max, math.min

WP.KEY = "pending"   -- the section header's key in NS.State.windowGroup.collapsed
WP.PAD = 8           -- the Rolls box's margin
WP.TITLE_H = 18      -- its title line
WP.LINE_H = 16       -- one player's line
WP.COL_W = 190       -- one column of players
WP.MAX_LINES = 10    -- the most lines a box takes before `and n more`
WP.ME_W, WP.SUMMARY_W, WP.TIMER_W = 96, 280, 56   -- a row's columns after the item (the full layout)
WP.GAP = 8

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

local function view()
    local v = NS.State.windowPending
    if not v then
        v = {}
        NS.State.windowPending = v
    end
    return v
end

--- Whether the Rolling now section and the Rolls box show (`rolls.show`).
--- @return boolean
function WP.Shown() return NS.Setting("rolls.show") ~= false end

--- The pending items the section shows, oldest first, from the store of the feed the window shows
--- (test mode's samples while it is on, NS.Window.FeedView): none while `rolls.show` is off.
--- @return table[]
function WP.Items()
    if not WP.Shown() then return {} end
    return NS.Pending.All(NS.Window.FeedView().feed)
end

--- The pending item whose roll table is expanded, or nil.
function WP.Expanded() return view().expanded end

--- Expand one item's roll table, or collapse it when it is the one expanded.
--- @param id number
function WP.ToggleExpand(id)
    if id == nil then return end
    local v = view()
    if v.expanded == id then v.expanded = nil else v.expanded = id end
    if NS.Window.IsShown() then NS.Window.Refresh() end
end

local function collapsed()
    local g = NS.State.windowGroup
    return g and g.collapsed and g.collapsed[WP.KEY] == true or false
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

local function cellOf(text, tone, tip) return { text = text or "", tone = tone or "plain", tip = tip } end

--- What one pending item's row (or card) says: { item, me, summary, timer, action }. `now` is the
--- loot history's clock; `classFile` your class (the verdict tooltip names you in it). `action` is
--- nil for a roll: nothing to press here.
--- @param item table a NS.Pending item
--- @param now number|nil NS.Compat.LootHistoryNow()
--- @param classFile string|nil
--- @return table
function WP.Model(item, now, classFile)
    local WC, RC = NS.WindowCells, NS.RollCells
    local t = RC.Timer(item.roll, now)
    local timer = t and cellOf(t, "plain", { L["Time left"], NS.TipMarks.Row(L["Rolls end in"], t) })
        or cellOf("", "muted")
    if item.kind == "ml" then
        timer = cellOf(L["awaiting master looter"], "muted", { L["Master loot"], NS.TipMarks.Row(nil, L["awaiting master looter"]) })
    end
    return { item = WC.Item(item), me = WC.Me(item, classFile), summary = RC.Summary(item.roll, now, item.state),
        timer = timer, action = nil }
end

--- The section header's text and tooltip: `Rolling now (n)`.
--- @param n number
--- @param isCollapsed boolean
--- @return table { text, tip }
function WP.Header(n, isCollapsed)
    local tip = { L["Rolling now"], NS.TipMarks.Row(L["Shows"], L["drops still being rolled for"]),
        NS.TipMarks.Hint(isCollapsed and L["Click to expand this group."] or L["Click to collapse this group."]) }
    return { text = L["Rolling now (%d)"]:format(n), tip = tip }
end

--- The x and width of a full-layout row's columns inside `width`: the item takes what the others
--- leave, never under K.ITEM_MIN; the summary gives way first on a narrow window.
--- @param width number the row's width
--- @return table { item, me, summary, timer = { x, w } }
function WP.Columns(width)
    local lead = NS.WindowGroup.CHEVRON_LEAD
    local fixed = WP.ME_W + WP.TIMER_W + 3 * WP.GAP
    local summary = max(80, min(WP.SUMMARY_W, width - lead - fixed - K.ITEM_MIN))
    local itemW = max(K.ITEM_MIN, width - lead - fixed - summary)
    local x = lead
    local out = { item = { x = x, w = itemW } }
    x = x + itemW + WP.GAP
    out.me = { x = x, w = WP.ME_W }
    x = x + WP.ME_W + WP.GAP
    out.summary = { x = x, w = summary }
    x = x + summary + WP.GAP
    out.timer = { x = x, w = WP.TIMER_W }
    return out
end

-- ── the Rolls box ───────────────────────────────────────────────────────────────────────────

local function tipOf(f) return unpack(f.tipLines or {}) end

local function setTone(fs, tone) NS.WindowRows.SetTone(fs, tone) end

local function faced(parent, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    NS.Skin.Font(fs)
    return fs
end

-- One player's line: the glyph, the name, the choice and the number, then the mark.
local function newLine(box)
    local f = CreateFrame("Frame", nil, box)
    f:SetHeight(WP.LINE_H)
    f.glyph = f:CreateTexture(nil, "ARTWORK")
    f.glyph:SetSize(WP.LINE_H - 2, WP.LINE_H - 2)
    f.glyph:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.name = faced(f)
    f.name:SetPoint("LEFT", f, "LEFT", WP.LINE_H + 2, 0)
    f.name:SetWidth(80)
    f.word = faced(f)
    f.word:SetPoint("LEFT", f.name, "RIGHT", 4, 0)
    f.word:SetWidth(52)
    f.roll = faced(f)
    f.roll:SetPoint("LEFT", f.word, "RIGHT", 2, 0)
    f.roll:SetWidth(22)
    f.mark = faced(f)
    f.mark:SetPoint("LEFT", f.roll, "RIGHT", 2, 0)
    NS.Window.AttachTooltip(f, function() return tipOf(f) end)
    return f
end

--- The Rolls box's frame, built once per parent, hidden: a skinned card with a title, the summary
--- beside it and the players' lines (made as they are needed).
--- @param parent table
--- @return table box
function WP.BuildRollsBox(parent)
    local box = NS.DetailCard.Box(parent)
    box.title = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.title:SetPoint("TOPLEFT", box, "TOPLEFT", WP.PAD + 2, -WP.PAD)
    NS.Skin.Text(box.title, "dw.idle")
    box.title:SetText(L["ROLLS"])
    box.summary = faced(box)
    box.summary:SetPoint("LEFT", box.title, "RIGHT", 10, 0)
    box.summaryHit = CreateFrame("Frame", nil, box)
    box.summaryHit:SetAllPoints(box.summary)
    NS.Window.AttachTooltip(box.summaryHit, function() return tipOf(box.summaryHit) end)
    box.lines = {}
    box:Hide()
    return box
end

local function paintLine(f, r)
    if r.glyph then f.glyph:SetTexture(r.glyph) end
    f.glyph:SetShown(r.glyph ~= nil)
    f.name:SetText(r.name)
    NS.WindowGroup.ClassTone(f.name, r.classFile, "plain")
    f.word:SetText(r.word)
    setTone(f.word, r.tone)
    f.roll:SetText(r.roll and tostring(r.roll) or "")
    setTone(f.roll, "plain")
    f.mark:SetText(r.winner and L["Won"] or r.protected and L["(protected)"] or "")
    setTone(f.mark, r.winner and "good" or "muted")
    f.tipLines = NS.RollCells.RowTip(r)
end

local function paintMore(f, n, rows, from)
    f.glyph:Hide()
    f.name:SetText(L["and %d more"]:format(n))
    setTone(f.name, "muted")
    f.word:SetText(""); f.roll:SetText(""); f.mark:SetText("")
    local tip = { L["Rolls"] }
    for i = from, #rows do
        local r = rows[i]
        tip[#tip + 1] = NS.TipMarks.Row(NS.TipMarks.ClassName(r.name, r.classFile),
            r.roll and ("%s %d"):format(r.word, r.roll) or r.word, r.tone)
    end
    f.tipLines = tip
end

--- Paint `roll` into the box at `width`: the summary and every player's line, flowed into columns.
--- Answers the box's height.
--- @param box table WP.BuildRollsBox's
--- @param roll table|nil the plain roll table
--- @param width number
--- @param now number|nil the loot history's clock
--- @param state string|nil the pending item's state
--- @return number height
function WP.PaintRollsBox(box, roll, width, now, state)
    local RC = NS.RollCells
    local s = RC.Summary(roll, now, state)
    box.summary:SetText(s.text)
    setTone(box.summary, s.tone)
    box.summaryHit.tipLines = s.tip
    local rows = RC.Rows(roll)
    local inner = width - 2 * WP.PAD
    local cols, lines, shown = RC.Grid(#rows, inner, WP.COL_W, WP.MAX_LINES)
    local colW = cols > 0 and math.floor(inner / cols) or inner
    local slots = shown < #rows and shown + 1 or shown
    for i = 1, max(slots, #box.lines) do
        local f = box.lines[i]
        if i <= slots then
            if not f then
                f = newLine(box)
                box.lines[i] = f
            end
            local col, line = math.floor((i - 1) / lines), (i - 1) % lines
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", box, "TOPLEFT", WP.PAD + col * colW, -(WP.PAD + WP.TITLE_H + line * WP.LINE_H))
            f:SetWidth(colW - 4)
            if i <= shown then paintLine(f, rows[i]) else paintMore(f, #rows - shown, rows, shown + 1) end
            f:Show()
        elseif f then
            f:Hide()
        end
    end
    local height = 2 * WP.PAD + WP.TITLE_H + lines * WP.LINE_H
    box:SetSize(width, height)
    return height
end

-- ── the full layout ─────────────────────────────────────────────────────────────────────────

local function rowClick(self) WP.ToggleExpand(self.pendingId) end

local function textPiece(row, key)
    local f = CreateFrame("Frame", nil, row)
    f.text = faced(f)
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" then rowClick(row) end
    end)
    NS.Window.AttachTooltip(f, function() return tipOf(f) end, "row")
    row.cells[key] = f
    return f
end

local function newRow(content)
    local WG = NS.WindowGroup
    local row = CreateFrame("Button", nil, content)
    row.tipRow = true
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints(row)
    WG.PaintRowWashes(row)
    NS.WindowRows.HoverWash(row)
    row.chevron = WG.RowChevron(row)
    row.chevron:SetPoint("LEFT", row, "LEFT", K.CHEVRON_X, 0)
    row.cells = {}
    local item = textPiece(row, "item")
    item.button = WG.ItemButton(item, K.ROW_ICON)
    item.button:SetPoint("LEFT", item, "LEFT", 0, 0)
    WG.ItemHover(item, item.button)
    item.showItem = true
    item.text:ClearAllPoints()
    item.text:SetPoint("LEFT", item.button, "RIGHT", 5, 0)
    local me = textPiece(row, "me")
    me.glyph = me:CreateFontString(nil, "OVERLAY")
    NS.SkinMono(me.glyph, 12)
    me.glyph:SetPoint("LEFT", me, "LEFT", 0, 0)
    me.text:ClearAllPoints()
    me.text:SetPoint("LEFT", me.glyph, "RIGHT", 3, 0)
    textPiece(row, "summary")
    textPiece(row, "timer")
    row:SetScript("OnClick", rowClick)
    return row
end

local function place(frame, content, y, width, x)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, -y)
    frame:SetWidth(width - (x or 0))
end

-- A piece's text and tone, and its tooltip on the piece (a row's) or its hit frame (a card's).
local function paintPiece(f, c)
    f.text:SetText(c.text)
    setTone(f.text, c.tone)
    local owner = f.hit or f
    owner.tipLines = c.tip
end
WP.PaintPiece = paintPiece

--- Paint a verdict piece: the glyph (the monospace face) then the text, both in the verdict's tone.
--- @param f table { glyph, text }
--- @param c table a WindowCells verdict cell
function WP.PaintVerdict(f, c)
    f.glyph:SetText(c.glyph or "")
    f.glyph:SetShown(c.glyph ~= nil)
    setTone(f.glyph, c.tone)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.glyph, "RIGHT", c.glyph and 3 or 0, 0)
end

local function paintRow(row, item, model, cols, height, metrics)
    row.pendingId, row.item = item.id, item
    row:SetHeight(height)
    local open = view().expanded == item.id
    row.selected:SetShown(open)
    NS.WindowGroup.PaintChevron(row.chevron, open)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize, metrics.font)
    for key, at in pairs(cols) do
        local f = row.cells[key]
        f:ClearAllPoints()
        f:SetPoint("LEFT", row, "LEFT", at.x, 0)
        f:SetSize(at.w, height)
        f.text:SetWidth(max(at.w - (key == "item" and K.ROW_ICON + 5 or 0), 10))
    end
    local c = row.cells
    NS.WindowGroup.SetItem(c.item.button, item.link)
    c.item.button.pendingId, c.item.button.dropId = item.id, nil
    paintPiece(c.item, model.item)
    c.item.tipLines = nil   -- the game's own tooltip instead
    local r, g, b = NS.QualityColor(type(item.facts) == "table" and item.facts.quality or nil)
    if r then c.item.text:SetTextColor(r, g, b) end
    paintPiece(c.me, model.me)
    WP.PaintVerdict(c.me, model.me)
    paintPiece(c.summary, model.summary)
    paintPiece(c.timer, model.timer)
end

local function section(pane)
    local s = pane.pendingSection
    if s then return s end
    s = { header = NS.WindowGroup.NewHeader(pane.content), rowPool = NS.Pool.New() }
    s.box = WP.BuildRollsBox(pane.content)
    s.header:Hide()
    pane.pendingSection = s
    return s
end

local function paintHeader(h, n, width)
    local isCollapsed = collapsed()
    local hd = WP.Header(n, isCollapsed)
    h.groupKey, h.collapsed = WP.KEY, isCollapsed
    h.text:SetText(hd.text)
    h.tipLines = hd.tip
    h.chevron:SetTexture(NS.Icon(isCollapsed and "chevron-right" or "chevron-down"))
    h:SetWidth(width)
    h:Show()
end

local function classFile()
    local snap = NS.Gear.Snapshot()
    return snap and snap.classFile
end

--- Draw the Rolling now section at the top of the full table's scroll child (WindowGroup's
--- refresh, every repaint): the header, a row per item and the expanded item's roll table. Answers
--- the height it takes (0 with nothing to show: everything hidden).
--- @param pane table the Drops pane
--- @param width number the rows' width
--- @return number height
function WP.Draw(pane, width)
    local s = section(pane)
    NS.Pool.ReleaseAll(s.rowPool)
    s.box:Hide()
    local items = WP.Items()
    pane.pendingShown = #items
    if #items == 0 then
        s.header:Hide()
        return 0
    end
    place(s.header, pane.content, 0, width)
    paintHeader(s.header, #items, width)
    local y = K.GROUP_H
    if collapsed() then return y end
    local metrics = NS.WindowRows.Metrics()
    local now, you = NS.Compat.LootHistoryNow(), classFile()
    local cols = WP.Columns(width - K.ROW_INDENT)
    for i, item in ipairs(items) do
        local row = NS.Pool.Acquire(s.rowPool, function() return newRow(pane.content) end)
        place(row, pane.content, y, width, K.ROW_INDENT)
        row.stripe:SetShown(i % 2 == 0)
        paintRow(row, item, WP.Model(item, now, you), cols, metrics.height, metrics)
        y = y + metrics.height
        if view().expanded == item.id then
            place(s.box, pane.content, y, width, K.ROW_INDENT)
            y = y + WP.PaintRollsBox(s.box, item.roll, width - K.ROW_INDENT, now, item.state) + 2
            s.box:Show()
        end
    end
    return y + 2
end

-- ── the compact layout ──────────────────────────────────────────────────────────────────────

local function compactSection(cv)
    local s = cv.pendingSection
    if s then return s end
    s = { header = NS.WindowGroup.NewHeader(cv.content), cardPool = NS.Pool.New() }
    s.box = WP.BuildRollsBox(cv.content)
    s.header:Hide()
    s.makeCard = function()
        local card = NS.CompactGroup.NewPendingCard(cv.content)
        card:SetScript("OnClick", rowClick)
        card.onPiece = function(c, button) if button == "LeftButton" then rowClick(c) end end
        return card
    end
    cv.pendingSection = s
    return s
end

--- Draw the Rolling now section at the top of the compact view (CompactGroup's draw, every
--- repaint): the header, a four-line card per item and the expanded item's roll table under it.
--- Answers the height it takes.
--- @param cv table the compact view
--- @param width number the view's width
--- @param m table CompactGroup.Metrics' answer
--- @return number height
function WP.DrawCompact(cv, width, m)
    local s = compactSection(cv)
    NS.Pool.ReleaseAll(s.cardPool)
    s.box:Hide()
    local items = WP.Items()
    cv.pendingShown = #items
    if #items == 0 then
        s.header:Hide()
        return 0
    end
    place(s.header, cv.content, 0, width)
    paintHeader(s.header, #items, width)
    s.header.text:SetWidth(max(width - 24, 20))
    local y = K.GROUP_H
    if collapsed() then return y end
    local now, you = NS.Compat.LootHistoryNow(), classFile()
    local cardW = width - K.ROW_INDENT
    for i, item in ipairs(items) do
        local card = NS.Pool.Acquire(s.cardPool, s.makeCard)
        place(card, cv.content, y, cardW + K.ROW_INDENT, K.ROW_INDENT)
        card.stripe:SetShown(i % 2 == 0)
        card.pendingId = item.id
        card.selected:SetShown(view().expanded == item.id)
        NS.CompactGroup.PaintPendingCard(card, item, WP.Model(item, now, you), cardW, m)
        y = y + m.height + NS.CompactGroup.GAP
        if view().expanded == item.id then
            place(s.box, cv.content, y, cardW + K.ROW_INDENT, K.ROW_INDENT)
            y = y + WP.PaintRollsBox(s.box, item.roll, cardW, now, item.state) + NS.CompactGroup.GAP
            s.box:Show()
        end
    end
    return y
end

-- ── the timers ──────────────────────────────────────────────────────────────────────────────

-- The rows or cards the layout in force drew (the other layout's pool keeps its last draw, hidden).
local function drawnPieces(pane)
    if not pane then return {} end
    if NS.WindowGroup.IsCompact() then
        local cs = pane.compactView and pane.compactView.pendingSection
        return cs and cs.cardPool.active or {}
    end
    local s = pane.pendingSection
    return s and s.rowPool.active or {}
end

--- Whether a drawn row or card shows a roll still open (Window.lua's countdown ticker runs while
--- one does).
--- @param pane table|nil the Drops pane
--- @return boolean
function WP.Live(pane)
    for _, row in ipairs(drawnPieces(pane)) do
        if row.item and row.item.state == "open" then return true end
    end
    return false
end

--- Move every drawn row's and card's time left and summary on to the history's clock.
--- @param pane table|nil the Drops pane
function WP.Tick(pane)
    local now = NS.Compat.LootHistoryNow()
    for _, row in ipairs(drawnPieces(pane)) do
        local item = row.item and NS.Pending.Get(row.item.id)
        if item then
            local m = WP.Model(item, now)
            paintPiece(row.cells.timer, m.timer)
            paintPiece(row.cells.summary, m.summary)
        end
    end
end

--- What the section drew, for the suites: { header, rows (full) or cards (compact), box, shown }.
--- @param pane table the Drops pane
--- @return table
function WP.Drawn(pane)
    local s = pane and pane.pendingSection
    local cs = pane and pane.compactView and pane.compactView.pendingSection
    return { header = s and s.header, rows = s and s.rowPool.active or {}, box = s and s.box,
        compactHeader = cs and cs.header, cards = cs and cs.cardPool.active or {}, compactBox = cs and cs.box }
end
