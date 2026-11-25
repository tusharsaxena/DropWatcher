local _, NS = ...
-- modules/ItemSearchGrid.lua — the Item Search window's blocks and tables, the frame edge over the
-- pure rows of modules/ItemSearchCells.lua and the columns of modules/ItemSearchTabs.lua (Item Search
-- feedback spec §5.2, §5.4 to §5.6; mockups V2Window and V2Tabs). modules/ItemSearchWindow.lua builds
-- the window and lays these out.
--
-- THE SECTION HEADER (spec §5.5, Skill Master's block header the model): a band in the skin's
-- `list.header.bg` (Ka0s Default black .35, the band Drop Watcher's encounter headers and Skill
-- Master's blocks draw), the title in `list.header.text` (Ka0s Default gold), the count after it and
-- the sort in force at the right, dim; then its marks, right-aligned, left to right Filter · Sort ·
-- Reset, each with a tooltip. A mark rests in `icon.tint` and lights `text.link` under the pointer
-- (the title bar's marks, NS.WindowTitleBar). The filter mark while a filter narrows the rows wears
-- Skill Master's filled badge (its R8-2): a square in the accent, `text.accent`, the funnel on it in
-- the window's own fill, `win.bg`. Skill Master's header is Skill Master's own code (modules/Blocks.lua,
-- NS.Chrome.HeaderMark and SetBadge), not a LibKa0s widget, so the look is redrawn here from the
-- same tokens rather than shared (own call). Crafting's header carries one chip besides: My
-- professions / All professions (spec §4).
--
-- THE TABLE (spec §5.4): the column labels on the skin's sort-header band (NS.Skin.SortHeaderBar,
-- as the main window's), each a button that sorts (a second click flips; the arrow shows which),
-- then a scroll frame of pooled rows. A sortable label lights `text.link` under the pointer (the
-- marks' ISG.MARK_HOT), and while it is not the sort in force shows, faint (ISG.ARROW_HINT_ALPHA),
-- the triangle its click would give (round 3 spec §4.1, item 5). The triangles are LibKa0s's
-- open-iconic `sort-up` (ascending) and `sort-down`, LootHistory's, at the label's line height and
-- tinted `list.header.arrow` (item 11). A label with no sort gets no hover. Every row is Drop Watcher's table row: the stripe on every
-- other row (`list.stripe`), the skin's hover wash (NS.WindowRows' `tipRow` rows), the main
-- window's table font and row height (NS.WindowRows.Metrics: Window > Layout's rows, the skin's face
-- and its scale), and a tooltip under the Ka0s rules (spec §5.6: the title, label and value rows,
-- dim hint lines last; NS.Window.AttachTooltip places it beside the window). A container's row and a
-- recipe's Makes cell show the item's own game tooltip instead, and a shift-click links that item in
-- chat (NS.ItemSearchGrid.LinkItem). The pin column's button, a dim map pin lit on its row's hover,
-- sets the waypoint (TomTom's or Drop Watcher's arrow, modules/ItemSearchWaypoint.lua).
--
-- THE MATCH ROW (spec §5.2): the icon, the name in its quality color and the id dim at the right;
-- the stripe, the hover wash, and the selected look on the item the right pane shows: a wash and a
-- left edge in the selection color (NS.SelectedColor: Ka0s Default's gold in every skin, the
-- 2026-11-24 ruling, W5). Hovering it shows the item's game tooltip; a shift-click links the item.

NS.ItemSearchGrid = NS.ItemSearchGrid or {}
local ISG  = NS.ItemSearchGrid
local TABS = NS.ItemSearchTabs
local C    = NS.Constants
local L    = NS.L

local Compat = NS.Compat
local K = C.WINDOW

ISG.HEADER_H = 22
ISG.MARK = 18
ISG.CELLS = 8          -- a row's most text cells (Quests has eight columns)
ISG.SEL_ALPHA = 0.26   -- the selected row's wash over the selection color (Ka0s Default's list.sel)
ISG.SEL_EDGE = 2       -- the selected row's left edge, in pixels
ISG.MARK_REST, ISG.MARK_HOT = "icon.tint", "text.link"
ISG.HEADER_BG, ISG.HEADER_TEXT = "list.header.bg", "list.header.text"
ISG.ARROW_HINT_ALPHA = 0.5   -- the next-sort triangle's alpha on a hovered label that is not the sort
ISG.ARROW_SIZE = 10          -- the triangle's size when the label's line height is not measured yet

local function TM() return NS.TipMarks end

-- ── the item behind a row: its tooltip and its link ─────────────────────────────────────────

local function itemLink(id)
    local it = Compat.ItemInfoByID(id)
    return it and it.link or nil
end

--- The item's own game tooltip on `owner`, placed beside the window (a body element).
--- @param owner table
--- @param id number|nil
function ISG.ItemTip(owner, id)
    if not (GameTooltip and id) then return end
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    Compat.TooltipHyperlink(GameTooltip, itemLink(id) or ("item:" .. id))
    GameTooltip:Show()
    NS.RowTooltip.PlaceOrFallback(GameTooltip, owner)
end

function ISG.HideTip()
    if GameTooltip then GameTooltip:Hide() end
end

--- Put `id`'s link in the chat box (the client's shift-click): answers whether it went. An item the
--- client has not cached yet is asked for, and the chat line says to try again.
--- @param id number|nil
--- @return boolean
function ISG.LinkItem(id)
    if not id then return false end
    local link = itemLink(id)
    if not link then
        Compat.RequestItem(id)
        NS.Print(L["That item is still loading: try again in a moment."])
        return false
    end
    return Compat.LinkInChat(link) == true
end

-- ── text ────────────────────────────────────────────────────────────────────────────────────

local function cellText(parent)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    NS.Skin.Font(fs)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function toneRGB(tone)
    local t = C.TONE[tone or "plain"] or C.TONE.plain
    return t.r, t.g, t.b
end

local function partsText(parts)
    local out = {}
    for _, p in ipairs(parts) do out[#out + 1] = NS.GroupRoster.Colored(p.text, toneRGB(p.tone)) end
    return table.concat(out, " ")
end

-- ── a header mark ───────────────────────────────────────────────────────────────────────────

local function paintMark(b)
    local badge = b.dwBadge == true
    if badge then
        b.badge:SetColorTexture(NS.SkinColor(b.dwHot and ISG.MARK_HOT or "text.accent"))
        b.art:SetVertexColor(NS.SkinColor("win.bg"))
    else
        b.art:SetVertexColor(NS.SkinColor(b.dwHot and ISG.MARK_HOT or ISG.MARK_REST))
    end
    b.badge:SetShown(badge)
    b.glyph:SetTextColor(NS.SkinColor(b.dwHot and ISG.MARK_HOT or ISG.MARK_REST))
end

--- A header mark: the catalog's `icon` (its `glyph` without the media library), ISG.MARK square,
--- resting in `icon.tint` and lit `text.link` under the pointer, with a tooltip (`tip()`, chrome).
--- @return table
function ISG.Mark(parent, icon, glyph, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(ISG.MARK, ISG.MARK)
    b.badge = b:CreateTexture(nil, "BACKGROUND")
    b.badge:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.badge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.art:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    local path = NS.Icon(icon)
    b.art:SetTexture(path)
    b.art:SetShown(path ~= nil)
    b.glyph = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.glyph:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.glyph:SetText(glyph or "")
    b.glyph:SetShown(path == nil)
    NS.SkinPaint(b, paintMark)
    b:HookScript("OnEnter", function(self) self.dwHot = true; paintMark(self) end)
    b:HookScript("OnLeave", function(self) self.dwHot = false; paintMark(self) end)
    b:SetScript("OnClick", onClick)
    if tip then NS.Window.AttachTooltip(b, tip, "chrome") end
    return b
end

--- The filled badge on a mark (a filter that narrows), or none.
--- @param b table ISG.Mark's
--- @param on boolean
function ISG.SetBadge(b, on)
    b.dwBadge = on == true
    paintMark(b)
end

-- ── the section header ──────────────────────────────────────────────────────────────────────

--- A section header: `h.title`, `h.count`, `h.note`, `h.chip` and `h.marks[key]` for each of
--- `marks` (`{ { key, icon, glyph, onClick, tip } }`, laid right to left from the header's right
--- edge in reverse, so the list reads left to right). ISG.PaintHeader fills it.
--- @param parent table
--- @param marks table
--- @return table
function ISG.Header(parent, marks)
    local h = CreateFrame("Frame", nil, parent)
    h:SetHeight(ISG.HEADER_H)
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints(h)
    NS.SkinPaint(h.bg, function(t) t:SetColorTexture(NS.SkinColor(ISG.HEADER_BG)) end)
    h.title = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.title:SetPoint("LEFT", h, "LEFT", 8, 0)
    NS.Skin.Text(h.title, ISG.HEADER_TEXT)
    h.count = cellText(h)
    h.count:SetPoint("LEFT", h.title, "RIGHT", 4, 0)
    NS.Skin.Text(h.count, "text.muted")
    h.marks, h.order = {}, {}
    local anchor, point, x = h, "RIGHT", -4
    for i = #marks, 1, -1 do
        local m = marks[i]
        local b = ISG.Mark(h, m.icon, m.glyph, m.onClick, m.tip)
        b:SetPoint("RIGHT", anchor, point, x, 0)
        anchor, point, x = b, "LEFT", -2
        h.marks[m.key] = b
        table.insert(h.order, 1, b)
    end
    h.note = cellText(h)
    h.note:SetPoint("RIGHT", anchor, anchor == h and "RIGHT" or "LEFT", -6, 0)
    h.note:SetJustifyH("RIGHT")
    NS.Skin.Text(h.note, "text.muted")
    h.chip = NS.Window.TextButton(h, 110, nil, "", function() if h.onChip then h.onChip() end end)
    NS.Window.SetButtonMark(h.chip, "", nil)
    h.chip:SetHeight(ISG.HEADER_H - 4)
    h.chip:SetPoint("LEFT", h.count, "RIGHT", 8, 0)
    h.chip:Hide()
    NS.Window.AttachTooltip(h.chip, function() if h.chipTip then return h.chipTip() end end, "chrome")
    return h
end

--- Fill a section header: `spec` `{ title, count, note, marks = { [key] = { shown, badge } },
--- chip = { text, tip, onClick } | nil }`.
--- @param h table ISG.Header's
--- @param spec table
function ISG.PaintHeader(h, spec)
    h.title:SetText(spec.title or "")
    h.count:SetText(spec.count and ("· " .. spec.count) or "")
    h.note:SetText(spec.note or "")
    for key, b in pairs(h.marks) do
        local m = spec.marks and spec.marks[key]
        b:SetShown(m ~= nil and m.shown ~= false)
        ISG.SetBadge(b, m ~= nil and m.badge == true)
    end
    -- The marks shown, packed to the right (a hidden Reset leaves no hole).
    local anchor, point, x = h, "RIGHT", -4
    for i = #h.order, 1, -1 do
        local b = h.order[i]
        if b:IsShown() then
            b:ClearAllPoints()
            b:SetPoint("RIGHT", anchor, point, x, 0)
            anchor, point, x = b, "LEFT", -2
        end
    end
    h.note:ClearAllPoints()
    h.note:SetPoint("RIGHT", anchor, anchor == h and "RIGHT" or "LEFT", -6, 0)
    local chip = spec.chip
    h.chip:SetShown(chip ~= nil)
    if chip then
        NS.Window.SetButtonMark(h.chip, chip.text, nil)
        h.onChip, h.chipTip = chip.onClick, chip.tip
    end
end

-- ── a table row ─────────────────────────────────────────────────────────────────────────────

local function rowTip(row)
    local tip = row.dwTip
    if type(tip) ~= "table" or tip.item then return end
    local out = { tip.title or "" }
    for _, r in ipairs(tip.rows or {}) do out[#out + 1] = TM().Row(r[1], r[2]) end
    for _, h in ipairs(tip.hints or {}) do out[#out + 1] = TM().Hint(h) end
    return unpack(out)
end

local function onRowEnter(row)
    local tip = row.dwTip
    if type(tip) == "table" and tip.item then ISG.ItemTip(row, tip.item) end
end

local function onRowClick(row)
    local id = row.dwItem
    if not id then return end
    if Compat.ShiftDown() then ISG.LinkItem(id) elseif row.dwOpen then row.dwOpen(id) end
end

-- THE PIN (Item Search feedback spec §6, W11): a map-pin icon (Phosphor `map-pin`), dim at rest
-- (ISG.PIN_ALPHA of `icon.tint`) and lit `text.link` while the pointer is on its row or on it. Its
-- tooltip: Set a waypoint, the place, the arrow that will point the way, the click hint.
ISG.PIN_ICON, ISG.PIN_ALPHA = "ph:map-pin", 0.5

local function paintPinArt(pin)
    local r, g, b = NS.SkinColor(pin.dwHot and ISG.MARK_HOT or ISG.MARK_REST)
    pin.art:SetVertexColor(r, g, b, pin.dwHot and 1 or ISG.PIN_ALPHA)
end

--- Light or dim a row's pin (its row's, or its own, hover).
--- @param row table
--- @param hot boolean
function ISG.PinHot(row, hot)
    local pin = row and row.pin
    if not pin then return end
    pin.dwHot = hot == true
    paintPinArt(pin)
end

local function newPin(row)
    local pin = CreateFrame("Button", nil, row)
    pin:SetSize(C.ITEM_SEARCH.WINDOW.PIN, C.ITEM_SEARCH.WINDOW.PIN)
    pin.art = pin:CreateTexture(nil, "ARTWORK")
    pin.art:SetAllPoints(pin)
    pin.art:SetTexture(NS.Icon(ISG.PIN_ICON))
    NS.SkinPaint(pin.art, function() paintPinArt(pin) end)
    pin:SetScript("OnClick", function(self) if row.dwPin then row.dwPin(self.spot, self.title) end end)
    NS.Window.AttachTooltip(pin, function()
        return L["Set a waypoint"], TM().Row(L["At"], pin.where or ""),
            TM().Row(L["Arrow"], NS.ItemSearchWaypoint.MethodLabel(pin.how)), TM().Hint(L["Click: set a waypoint"])
    end)
    pin:HookScript("OnEnter", function() ISG.PinHot(row, true) end)
    pin:HookScript("OnLeave", function() ISG.PinHot(row, false) end)
    return pin
end

-- The overlay over a cell that stands for an item (a recipe's Makes): its game tooltip and its link.
local function newLink(row)
    local b = CreateFrame("Button", nil, row)
    b:SetScript("OnEnter", function(self) ISG.ItemTip(self, self.itemID) end)
    b:SetScript("OnLeave", ISG.HideTip)
    b:SetScript("OnClick", function(self)
        if Compat.ShiftDown() then ISG.LinkItem(self.itemID) elseif row.dwOpen then row.dwOpen(self.itemID) end
    end)
    b:Hide()
    return b
end

--- One pooled table row: ISG.CELLS text cells (`row.cells[i].text`), a chance bar, a pin and an item
--- overlay, the stripe, the hover wash and the tooltip.
--- @param parent table
--- @return table
function ISG.NewRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row.tipRow = true
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    NS.SkinPaint(row.stripe, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    row.cells = {}
    for i = 1, ISG.CELLS do row.cells[i] = { text = cellText(row) } end
    row.barBack = row:CreateTexture(nil, "ARTWORK")
    row.barFill = row:CreateTexture(nil, "OVERLAY")
    NS.SkinPaint(row.barBack, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    row.pin = newPin(row)
    row.link = newLink(row)
    NS.Window.AttachTooltip(row, function() return rowTip(row) end)
    row:HookScript("OnEnter", onRowEnter)
    row:HookScript("OnEnter", function(self) ISG.PinHot(self, true) end)
    row:HookScript("OnLeave", function(self) ISG.PinHot(self, false) end)
    row:HookScript("OnLeave", function(self) if type(self.dwTip) == "table" and self.dwTip.item then ISG.HideTip() end end)
    row:SetScript("OnClick", onRowClick)
    return row
end

local function place(fs, row, at, h, justify)
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", row, "LEFT", at.x, 0)
    fs:SetSize(math.max(1, at.w), h)
    fs:SetJustifyH(justify or "LEFT")
    fs:Show()
end

local function paintText(fs, cell)
    fs:SetText(cell.text or "")
    local r, g, b
    if cell.quality ~= nil then r, g, b = NS.QualityColor(cell.quality) end
    if r then fs:SetTextColor(r, g, b) else NS.WindowRows.SetTone(fs, cell.tone or "plain") end
end

local function paintBar(row, fs, at, h, cell, opts)
    local pctW = math.min(48, at.w)
    local barW = math.max(1, at.w - pctW - 4)
    local barH = math.max(4, h - 10)
    row.barBack:ClearAllPoints()
    row.barBack:SetPoint("LEFT", row, "LEFT", at.x, 0)
    row.barBack:SetSize(barW, barH)
    row.barBack:SetShown(cell.known == true)
    local w = (cell.fraction or 0) > 0 and math.max(1, math.floor(barW * cell.fraction + 0.5)) or 0
    row.barFill:ClearAllPoints()
    row.barFill:SetPoint("LEFT", row, "LEFT", at.x, 0)
    row.barFill:SetSize(math.max(w, 1), barH)
    row.barFill:SetColorTexture(opts.barColor())
    row.barFill:SetShown(w > 0)
    place(fs, row, { x = at.x + barW + 4, w = pctW }, h, "RIGHT")
    fs:SetText(cell.pct or "")
    NS.WindowRows.SetTone(fs, cell.known and "plain" or "muted")
end

local function paintPin(row, at, r, opts)
    local pin = row.pin
    local spot = r.spot
    local how = spot and opts.canPin(spot) or nil
    pin.spot, pin.title, pin.how = spot, r.tip and r.tip.title or nil, how
    pin.where = spot and ("%s %.1f, %.1f"):format(Compat.MapName(spot.map) or L["Map %d"]:format(spot.map),
        spot.x * 100, spot.y * 100) or nil
    pin:ClearAllPoints()
    pin:SetPoint("LEFT", row, "LEFT", at.x + math.floor((at.w - C.ITEM_SEARCH.WINDOW.PIN) / 2), 0)
    pin:SetShown(how ~= nil)
end

-- One cell of a row, by its column's kind.
local function paintCell(row, fs, c, at, h, r, opts)
    local cell = r.cells[c.key]
    if c.kind == "pin" then return paintPin(row, at, r, opts) end
    if cell == nil then return end
    if c.kind == "bar" then return paintBar(row, fs, at, h, cell, opts) end
    place(fs, row, at, h, c.justify)
    if c.kind == "glyph" then
        fs:SetText(NS.ItemSearchTip.CraftMark(cell.craft))
    elseif c.kind == "mark" then
        fs:SetText(opts.questMark(cell.mark))
    elseif cell.parts then
        fs:SetText(partsText(cell.parts))
    else
        paintText(fs, cell)
    end
end

local function blank(row)
    for _, f in ipairs(row.cells) do f.text:Hide() end
    row.barBack:Hide()
    row.barFill:Hide()
    row.pin:Hide()
    row.link:Hide()
end

local function placeLink(row, layout, r, h)
    local at = r.makesID and layout.makes or nil
    row.link.itemID = r.makesID
    if not at then return row.link:Hide() end
    row.link:ClearAllPoints()
    row.link:SetPoint("LEFT", row, "LEFT", at.x, 0)
    row.link:SetSize(math.max(1, at.w), h)
    row.link:Show()
end

--- Paint one table row: `r` (an ISC row) across `cols` laid out as `layout`, `i` its place (the
--- stripe on every other one). `opts`: { barColor() -> r, g, b, canPin(spot), questMark(status),
--- onPin(spot, title), onOpen(itemID) }.
function ISG.PaintRow(row, cols, layout, r, i, h, opts)
    blank(row)
    row.stripe:SetShown(i % 2 == 0)
    row.dwTip, row.dwItem = r.tip, r.itemID
    row.dwPin, row.dwOpen = opts.onPin, opts.onOpen
    local n = 0
    for _, c in ipairs(cols) do
        local at = layout[c.key]
        if at and c.kind ~= "pin" then n = n + 1 end
        if at then paintCell(row, row.cells[math.max(1, n)].text, c, at, h, r, opts) end
    end
    placeLink(row, layout, r, h)
end

-- ── the table ───────────────────────────────────────────────────────────────────────────────

local function scrollArea(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end
    return scroll, content
end
ISG.ScrollArea = scrollArea

local function columnTip(t, key)
    local c = TABS.Column(t.tab, key)
    if not c then return end
    local hint = t.sort and t.sort.col == key and L["Click again: reverse the order"]
        or L["Click: sort by %s; click again to reverse"]:format(c.title)
    return c.title, TM().Row(L["Shows"], c.tip or c.title), TM().Hint(hint)
end

--- The triangle for a sort direction: `sort-down` for high to low, `sort-up` for low to high.
--- @param desc boolean
--- @return string
function ISG.ArrowIcon(desc) return desc and "sort-down" or "sort-up" end

-- The label's line height, rounded (the triangle's size); ISG.ARROW_SIZE before the client measures.
local function arrowSize(b)
    local h = b.text.GetStringHeight and b.text:GetStringHeight() or 0
    h = type(h) == "number" and math.floor(h + 0.5) or 0
    return h > 0 and h or ISG.ARROW_SIZE
end

-- One column label's look: its tone (hot under the pointer while it sorts) and its triangle (the sort
-- in force, else the next sort faint while hovered, else none).
local function paintLabel(b)
    local hot = b.dwHot == true and b.key ~= nil
    b.text:SetTextColor(NS.SkinColor(hot and ISG.MARK_HOT or ISG.HEADER_TEXT))
    b.arrow:SetVertexColor(NS.SkinColor("list.header.arrow"))
    local t, sort = b.dwTable, b.dwTable and b.dwTable.sort
    local on = b.key ~= nil and sort ~= nil and sort.col == b.key
    local desc = sort and sort.desc
    if not on and hot and sort then desc = TABS.NextSort(t.tab, sort, b.key).desc end
    local size = arrowSize(b)
    b.arrow:SetSize(size, size)
    b.arrow:SetTexture(NS.Icon(ISG.ArrowIcon(desc == true)))
    b.arrow:SetAlpha(on and 1 or ISG.ARROW_HINT_ALPHA)
    b.arrow:SetShown(on or hot)
end
ISG.PaintLabel = paintLabel

local function newColumnLabel(t)
    local b = CreateFrame("Button", nil, t.head)
    b.dwTable = t
    b:SetHeight(K.COLHEAD_H)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("LEFT", b, "LEFT", 0, 0)
    NS.Skin.Text(b.text, ISG.HEADER_TEXT)
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetSize(ISG.ARROW_SIZE, ISG.ARROW_SIZE)
    b.arrow:SetPoint("LEFT", b.text, "RIGHT", 3, 0)
    b.arrow:Hide()
    NS.SkinPaint(b, paintLabel)
    b:HookScript("OnEnter", function(self) self.dwHot = true; paintLabel(self) end)
    b:HookScript("OnLeave", function(self) self.dwHot = false; paintLabel(self) end)
    b:SetScript("OnClick", function(self) if t.onSort and self.key then t.onSort(self.key) end end)
    NS.Window.AttachTooltip(b, function() return columnTip(t, b.key) end)
    return b
end

--- A table: its column labels (`t.head`, `t.labels[i]`), its scroll frame and pooled rows. Anchor
--- `t.frame` and paint it with ISG.PaintTable.
--- @param parent table
--- @return table
function ISG.Table(parent)
    local t = { frame = CreateFrame("Frame", nil, parent), labels = {}, pool = NS.Pool.New() }
    t.head = CreateFrame("Frame", nil, t.frame)
    t.head:SetPoint("TOPLEFT", t.frame, "TOPLEFT", 0, 0)
    t.head:SetPoint("TOPRIGHT", t.frame, "TOPRIGHT", -K.SCROLL_W, 0)
    t.head:SetHeight(K.COLHEAD_H)
    NS.Skin.SortHeaderBar(t.head)
    for i = 1, ISG.CELLS do t.labels[i] = newColumnLabel(t) end
    t.scroll, t.content = scrollArea(t.frame)
    t.scroll:SetPoint("TOPLEFT", t.head, "BOTTOMLEFT", 0, -2)
    t.scroll:SetPoint("BOTTOMRIGHT", t.frame, "BOTTOMRIGHT", -K.SCROLL_W, 0)
    t.empty = cellText(t.frame)
    t.empty:SetPoint("TOP", t.head, "BOTTOM", 0, -16)
    NS.Skin.Text(t.empty, "text.muted")
    return t
end

local function paintLabels(t, cols, layout)
    for _, b in ipairs(t.labels) do b:Hide() end
    local i = 0
    for _, c in ipairs(cols) do
        local at = layout[c.key]
        if at and c.title then
            i = i + 1
            local b = t.labels[i]
            b.key = c.sort and c.key or nil
            b:ClearAllPoints()
            b:SetPoint("LEFT", t.head, "LEFT", at.x, 0)
            b:SetWidth(math.max(1, at.w))
            b.text:SetText(c.title)
            if b.EnableMouse then b:EnableMouse(b.key ~= nil) end
            paintLabel(b)
            b:Show()
        end
    end
end

--- Paint table `t` with tab `tab`'s `rows` (already filtered and sorted) at `width`. `opts` is
--- ISG.PaintRow's, plus { metrics (NS.WindowRows.Metrics'), sort, onSort(key), empty (text) }.
function ISG.PaintTable(t, tab, rows, width, opts)
    local cols = TABS.DEF[tab].columns
    local layout = TABS.Layout(cols, width)
    t.tab, t.sort, t.onSort = tab, opts.sort, opts.onSort
    paintLabels(t, cols, layout)
    NS.Pool.ReleaseAll(t.pool)
    local m = opts.metrics
    local h = m.height
    for i, r in ipairs(rows) do
        local row = NS.Pool.Acquire(t.pool, function() return ISG.NewRow(t.content) end)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", t.content, "TOPLEFT", 0, -(i - 1) * h)
        row:SetSize(width, h)
        NS.WindowRows.ApplyRowFont(row, m.fontSize, m.font)
        ISG.PaintRow(row, cols, layout, r, i, h, opts)
    end
    t.content:SetSize(width, math.max(1, #rows * h))
    t.empty:SetText(opts.empty or "")
    t.empty:SetShown(#rows == 0 and opts.empty ~= nil)
    t.layout = layout
end

--- The rows table `t` draws now, in order (for the tests and the tooltip checks).
--- @return table
function ISG.Rows(t)
    local out = {}
    for i, row in ipairs(t.pool.active) do out[i] = row end
    return out
end

-- ── a match row ─────────────────────────────────────────────────────────────────────────────

local function paintSelected(row)
    local r, g, b = NS.SelectedColor()
    if r then
        row.selected:SetColorTexture(r, g, b, ISG.SEL_ALPHA)
        row.edge:SetColorTexture(r, g, b)
    end
end

--- One pooled match row (the left pane's list): icon, name, id, the stripe, the selected look, the
--- item's game tooltip on hover and a shift-click that links it. `open(id)` is the plain click's.
--- @param parent table
--- @param open function
--- @return table
function ISG.MatchRow(parent, open)
    local row = CreateFrame("Button", nil, parent)
    row.tipRow = true
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    NS.SkinPaint(row.stripe, function(t) t:SetColorTexture(NS.SkinColor("list.stripe")) end)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints(row)
    row.edge = row:CreateTexture(nil, "ARTWORK")
    row.edge:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.edge:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.edge:SetWidth(ISG.SEL_EDGE)
    NS.SkinPaint(row, paintSelected)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.cells = { name = { text = cellText(row) }, id = { text = cellText(row) } }
    row.cells.id.text:SetJustifyH("RIGHT")
    row:SetScript("OnEnter", function(self) ISG.ItemTip(self, self.itemID) end)
    row:SetScript("OnLeave", ISG.HideTip)
    NS.WindowRows.HoverWash(row)   -- hooked after the scripts are set, so it is kept
    row:SetScript("OnClick", function(self)
        if Compat.ShiftDown() then ISG.LinkItem(self.itemID) else open(self.itemID) end
    end)
    return row
end

--- Paint a match row: `r` `{ id, name, quality, icon }`, `i` its place, `selected` whether the right
--- pane shows it.
function ISG.PaintMatch(row, r, i, width, h, selected, m)
    row.itemID = r.id
    row.stripe:SetShown(i % 2 == 0)
    row.selected:SetShown(selected)
    row.edge:SetShown(selected)
    row.isSelected = selected
    NS.WindowRows.ApplyRowFont(row, m.fontSize, m.font)
    local iconSize = math.max(8, h - 4)
    row.icon:SetSize(iconSize, iconSize)
    row.icon:SetTexture(r.icon or Compat.ItemIcon(r.id) or NS.Icon("help"))
    local idW = 56
    local name, id = row.cells.name.text, row.cells.id.text
    name:ClearAllPoints()
    name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    name:SetSize(math.max(1, width - iconSize - idW - 18), h)
    name:SetText(r.name or L["Item %d"]:format(r.id))
    local qr, qg, qb = NS.QualityColor(r.quality)
    if qr then name:SetTextColor(qr, qg, qb) else NS.WindowRows.SetTone(name, "plain") end
    id:ClearAllPoints()
    id:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    id:SetSize(idW, h)
    id:SetText(tostring(r.id))
    NS.WindowRows.SetTone(id, "muted")
end
