local _, NS = ...
-- modules/WindowGroup.lua — the Group drops table (design spec §11.1-§11.2, boards 01, 03 and 06):
-- every drop the group receives, one row each, under a collapsible header per encounter or key run.
--
-- THE COLUMNS. Item (a real item button and the name), Ilvl, Slot, Type (Cloth … Plate, Jewelry,
-- Trinkets, Cloak or Weapons; feedback-4 spec §3), Looter (in class color), My eq
-- (what you wear in that slot, from your gear snapshot), Their eq (what the looter wears there, from
-- their inspect read, the read's age in its tooltip; feedback spec §3, FB-6 and FB-7), Me, Them (the
-- verdicts: ▲ ≈ ▽ before the signed item-level change, green, yellow or red in both; feedback-4
-- spec §0), Trade
-- (Yes, Likely, Unknown or No) and Actions (the Ask button; no drop is ever dismissed, feedback-4
-- spec §2).
-- `profile.window.columns[key] = false` hides a column (Item never hides); a row too narrow for them
-- all sheds columns by their `shed` order (WG.Fit) rather than clip Actions. What every
-- cell says, and its reason tooltip, is modules/WindowCells.lua's (pure); this file is the frame
-- edge that paints it. Nothing is ever blank.
--
-- THE ROWS. Pooled through LibKa0s-Pool-1.0 (NS.Pool), one pool for the drop rows and one for the
-- headers, released and re-acquired in order on every repaint (Pool v3 hands them back in their
-- order). Each row builds every column's cell once; a repaint shows, places and paints the ones
-- the column set keeps. A drop row's height, its item button and its cells' text size are the
-- Window page's Layout rows (`window.rowHeight`, `window.fontSize`), read through
-- modules/WindowRows.lua at each repaint (18 pixels and the template's own size by default, like
-- Ka0s Loot History's table; feedback-2 spec §8, FB2-9); the headers, the column labels and the
-- buttons keep their own.
--
-- THE ORDER. NS.WindowCells.Entries (pure): the feed's groups newest first (oldest first under Sort: Oldest),
-- each group's drops that pass the tab's filter (Window.TabContext: the filter bar's predicate,
-- and your own drops only with `feed.showOwn` on)
-- ordered by the tab's Sort. A group with none keeps its header (`n drops ·
-- 0 shown`) while the View filter hid them, and is left out when Search or Content did or it has
-- nothing for the tab (WC.KeepsHeader); its header counts your own drops left to My drops (`· 1 yours
-- on My drops`, feedback-3 spec §0). A group the
-- player never toggled is open when it is the first one shown and collapsed otherwise (board 01);
-- toggles are session-only (NS.State.windowGroup).
--
-- THE DETAIL CARD (design spec §11.3, board 02). A click on a row (anywhere but a button) expands
-- it inline: modules/DetailCard.lua's card is placed under it and the rows below move down by the
-- card's height. Only one row is expanded at a time (NS.State.windowGroup.expanded); a second click
-- on it, or on another row, collapses or moves the card. A row filtered out or collapsed under its
-- header takes its card with it.
--
-- THE EXPAND INDICATOR (feedback-5 spec §0). Every drop row draws the header's chevron at its left
-- edge, before the Item column: chevron-down while collapsed, chevron-up while its card is open,
-- muted white (C.CHEVRON_ROW) and the same on hover. The rows read as their header's children: each
-- row (stripe, chevron, every cell) and its detail card is indented K.ROW_INDENT from the header's
-- left edge, and the column labels move with them (WG.LEAD, the indent and the chevron's lead, is
-- what the columns lose of the pane's width). A header's own chevron is gold, as its text, on every
-- tab and in both layouts (they all build it here, WG.NewHeader).
-- THE COMPACT LAYOUT (WG.IsCompact) draws the same entries as cards: modules/CompactGroup.lua.
--
-- THE UI LISTENS. Window.lua repaints it on the bus; it reads the feed (NS.LootFeed.Groups, Get),
-- the looter's inspect entry (NS.Inspect.Get) and the ask's state (NS.Asks.StateOf), all read-only.
-- The Ask button goes through the host handler NS.PressAsk (core/DropWatcher.lua). An item button
-- shows the game's tooltip, shift-click links it (Compat.InsertChatLink) and ctrl-click tries it
-- on (Compat.DressUpItem).

NS.WindowGroup = NS.WindowGroup or {}
local WG    = NS.WindowGroup
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local WC    = NS.WindowCells

local max = math.max

-- Where a drop row's Item column starts, from the header's left edge (feedback-5 spec §0): the
-- row's indent, then its chevron (CHEVRON_X in, ROW_CHEVRON wide) and the gap after it. The chevron
-- is not a column: no label, no toggle, never shed.
WG.CHEVRON_LEAD = K.CHEVRON_X + K.ROW_CHEVRON + K.CHEVRON_GAP
WG.LEAD = K.ROW_INDENT + WG.CHEVRON_LEAD

-- The default columns, left to right (design spec §11.1). `flex` takes the width the others leave.
-- `shed` is the order a too-narrow window lets columns go (1 first; WG.Layout): what they say is
-- also on the row's detail card. Item and Actions never go.
WG.COLUMNS = {
    { key = "item", label = L["Item"], flex = true,
      tip = L["The drop. Hover its icon for the game's tooltip; shift-click links it in chat, ctrl-click tries it on."] },
    { key = "ilvl", label = L["Ilvl"], width = 40, shed = 5, tip = L["The drop's item level."] },
    { key = "slot", label = L["Slot"], width = 72, shed = 1, tip = L["Where the drop is worn."] },
    { key = "armorType", label = L["Type"], width = 64, shed = 0,
      tip = L["What kind of item it is: Cloth, Leather, Mail or Plate armor, Jewelry, Trinkets, a Cloak or Weapons."] },
    { key = "looter", label = L["Looter"], width = 104, shed = 2, tip = L["Who looted it, in their class color."] },
    { key = "myEq", label = L["My eq"], width = 84, shed = 3,
      tip = L["What you wear in that slot (two items for rings, trinkets and one-hand weapons) and its item level. Hover an icon for the item."] },
    { key = "theirEq", label = L["Their eq"], width = 84, shed = 4,
      tip = L["What the looter wears in that slot (two items for rings, trinkets and weapons) and its item level. Hover for how old the read is."] },
    { key = "me", label = L["Me"], width = 70, shed = 8,
      tip = L["The drop judged for you: ▲ upgrade (green), ≈ sidegrade (yellow) or ▽ downgrade (red), then the item-level change."] },
    { key = "them", label = L["Them"], width = 70, shed = 6,
      tip = L["The drop judged for its looter, in the same colors: ▲ upgrade green, ≈ sidegrade yellow, ▽ downgrade red."] },
    { key = "trade", label = L["Trade"], width = 70, shed = 7, tip = L["Whether the looter can trade it: Yes, Likely, Unknown or No."] },
    { key = "actions", label = L["Actions"], width = K.ASK_W,
      tip = L["Ask the looter for it, once."] },
}
local GLYPH_COLS = { me = true, them = true }
local WHITE = { r = 1, g = 1, b = 1 }   -- an untoned button's label (GameFontHighlightSmall)

local NO_MATCH = L["No drop matches the filters. View: All shows everything."]
local TEST_LOADING = L["Gathering real items for test mode."]
local TEST_NONE = L["Test mode found no items to show."]

-- ── the view state (session-only) ───────────────────────────────────────────────────────────

local function view()
    local v = State.windowGroup
    if not v then
        v = { collapsed = {} }
        State.windowGroup = v
    end
    return v
end

local function profileWindow()
    local p = NS.db and NS.db.profile
    local w = p and p.window
    return type(w) == "table" and w or nil
end

--- Whether the window is in its compact layout (modules/WindowCompact.lua): cards, not the table.
--- @return boolean
function WG.IsCompact()
    return NS.WindowCompact.Mode() == "compact"
end

local function repaint()
    if NS.Window.IsShown() then NS.Window.Refresh() end
end

--- Collapse or expand one group; `shown` is how it is drawn now.
--- @param key string the group's key
--- @param collapsedNow boolean
function WG.ToggleGroup(key, collapsedNow)
    view().collapsed[key] = not collapsedNow
    NS.Debug("UI", "group %s %s", tostring(key), collapsedNow and "expanded" or "collapsed")
    repaint()
end

--- Expand one row's detail card, or collapse it when it is the one expanded (design spec §11.3):
--- one row at a time.
--- @param id number the drop's id
function WG.ToggleExpand(id)
    if id == nil then return end
    local v = view()
    if v.expanded == id then v.expanded = nil else v.expanded = id end
    NS.Debug("UI", "drop %s %s", tostring(id), v.expanded and "expanded" or "collapsed")
    repaint()
end

--- The drop whose detail card is open, or nil.
--- @return number|nil
function WG.Expanded() return view().expanded end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

--- The columns shown: the default ones less each one the profile turns off (`columns[key] =
--- false`); Item always stays.
--- @param hidden table|nil `profile.window.columns`
--- @return table the column definitions, left to right
function WG.Columns(hidden)
    local out = {}
    hidden = type(hidden) == "table" and hidden or {}
    for _, col in ipairs(WG.COLUMNS) do
        if col.key == "item" or hidden[col.key] ~= false then out[#out + 1] = col end
    end
    return out
end

local function fixedWidth(cols)
    local fixed = 0
    for _, col in ipairs(cols) do fixed = fixed + (col.width or 0) + K.CELL_GAP end
    return fixed
end

-- The index of the column to let go first: the lowest `shed`, or nil when none may go.
local function nextToShed(cols)
    local at, best
    for i, col in ipairs(cols) do
        if col.shed and (not best or col.shed < best) then at, best = i, col.shed end
    end
    return at
end

--- The columns that fit a row `total` pixels wide: while the fixed columns and the Item column's
--- least width (K.ITEM_MIN) pass it, the column with the lowest `shed` goes.
--- @param cols table
--- @param total number
--- @return table the kept columns, left to right
function WG.Fit(cols, total)
    local kept = {}
    for i, col in ipairs(cols) do kept[i] = col end
    total = tonumber(total) or 0
    while fixedWidth(kept) + K.ITEM_MIN > total do
        local i = nextToShed(kept)
        if not i then break end
        table.remove(kept, i)
    end
    return kept
end

--- Each kept column's x and width for a row `total` pixels wide: the columns that do not fit are
--- shed first (WG.Fit), then the fixed columns take their width and the flex column (Item) the
--- rest, never less than K.ITEM_MIN. A shed column has no entry, so its cells and label hide.
--- @param cols table WG.Columns' answer
--- @param total number
--- @return table { [key] = { x, w } }, table the kept columns
function WG.Layout(cols, total)
    local kept = WG.Fit(cols, total)
    local flex = max(K.ITEM_MIN, (tonumber(total) or 0) - fixedWidth(kept))
    local out, x = {}, 0
    for _, col in ipairs(kept) do
        local w = col.flex and flex or col.width
        out[col.key] = { x = x, w = w }
        x = x + w + K.CELL_GAP
    end
    return out, kept
end

-- ── painting helpers ────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function tipOf(frame)
    return unpack(frame.tipLines or {})
end

local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end

-- A click on a cell is a click on its row (the cells take the mouse for their tooltips).
local function cellClick(self, button)
    if button == "LeftButton" and self.row then WG.ToggleExpand(self.row.dropId) end
end

local function textCell(row, key)
    local f = CreateFrame("Frame", nil, row)
    f.key, f.row = key, row
    f:SetScript("OnMouseUp", cellClick)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    NS.Window.AttachTooltip(f, function() return tipOf(f) end, "row")
    return f
end

-- The verdict cells: the glyph in the monospace face first, then the signed change in the row's
-- face (feedback-4 spec §0); a word with no glyph starts at the cell's left edge.
local function glyphCell(row, key)
    local f = textCell(row, key)
    f.glyph = f:CreateFontString(nil, "OVERLAY")
    f.glyph:SetFont(C.FONT_MONO, 12, "")
    f.glyph:SetPoint("LEFT", f, "LEFT", 0, 0)
    return f
end

--- Put a verdict cell's text after its glyph, or at the cell's left edge when it has none: the
--- arrow comes before the number in every full table (feedback-4 spec §0).
--- @param f table the cell (`f.text`, `f.glyph`)
--- @param glyph string|nil
function WG.PlaceGlyph(f, glyph)
    f.text:ClearAllPoints()
    if glyph and glyph ~= "" then
        f.text:SetPoint("LEFT", f.glyph, "RIGHT", 3, 0)
    else
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    end
end

--- Color an action button's label and mark by whose move it is (feedback-4 spec §1): red your
--- move, yellow waiting on someone else, green done (WindowCells.ActionTone); white for a state that
--- is none of them. Every Ask, Offer and Announce button goes through here, in both layouts.
--- @param b table a Window.TextButton (`b.label`, `b.art`)
--- @param state string|nil the button's state (WindowCells.ActionTone's key)
function WG.ToneButton(b, state)
    local tone = NS.WindowCells.ActionTone(state)
    local c = tone and C.TONE[tone] or WHITE
    b.label:SetTextColor(c.r, c.g, c.b)
    if b.art then b.art:SetVertexColor(c.r, c.g, c.b) end
    b.tone = tone
end

-- ── the item button ─────────────────────────────────────────────────────────────────────────

-- THE REAL GAME TOOLTIP (ui spec §0, BUG-2). Every item button shows the client's own tooltip,
-- never one assembled from facts: your own drop matched to its bag item shows that bag item (so the
-- client's "You may trade this item..." line appears), an item you wear shows your inventory slot,
-- anything else its link. Each place is checked against the link at hover time, so a moved item
-- falls back to its link. The addon's own line goes after the game's.

local function sameItemAs(link, other)
    return other ~= nil and NS.Item.ItemIDFromLink(other) == NS.Item.ItemIDFromLink(link)
end

-- Your own drop's bag slot: the trade timer's match, while the slot still holds the item.
local function bagSlotOf(dropId, link)
    local TT = NS.TradeTimer
    local e = dropId and TT and TT.ForDrop(dropId)
    if not (e and e.bag and e.slot) then return nil end
    if not sameItemAs(link, NS.Compat.BagItemLink(e.bag, e.slot)) then return nil end
    return e.bag, e.slot
end

local function showWorn(tip, b)
    local w = b.worn
    if not (w and sameItemAs(b.link, NS.Compat.InventoryItemLink(w.unit, w.slot))) then return false end
    return NS.Compat.TooltipInventoryItem(tip, w.unit, w.slot)
end

--- Show an item button's item on `tip` the client's own way: its bag slot (`b.ownDropId`, your own
--- drop matched to its bag item), else its inventory slot (`b.worn` = { unit, slot }), else its
--- link. Answers which: `bag`, `inventory` or `link`.
--- @param tip table a GameTooltip
--- @param b table the item button
--- @return string
function WG.SetItemTooltip(tip, b)
    local bag, slot = bagSlotOf(b.ownDropId, b.link)
    if bag and NS.Compat.TooltipBagItem(tip, bag, slot) then return "bag" end
    if showWorn(tip, b) then return "inventory" end
    NS.Compat.TooltipHyperlink(tip, b.link)
    return "link"
end

-- AT THE ROW'S TOP RIGHT (feedback-3 spec §2, DW-B2). An item tooltip never covers the table: it
-- rises from the hovered row's top-right corner, just outside the window (else its top left),
-- through the one row-tooltip placement every row cell shares (modules/RowTooltip.lua).

-- `owner` is the hovered frame: the button, or a name beside it (WG.ItemHover).
local function itemEnter(self, owner)
    if not (self.link and GameTooltip) then return end
    owner = owner or self
    GameTooltip:SetOwner(owner, "ANCHOR_NONE")
    WG.SetItemTooltip(GameTooltip, self)
    GameTooltip:AddLine(L["Shift-click to link it in chat; ctrl-click to try it on."], C.IDLE.r, C.IDLE.g, C.IDLE.b)
    GameTooltip:Show()
    NS.RowTooltip.PlaceOrFallback(GameTooltip, owner)
end

--- An item button's click: shift links the item in chat, ctrl tries it on (design spec §11.1); a
--- plain click on a row's own item button expands the row, as a click on the row does.
--- @param self table the button (`self.link`, and `self.dropId` on a row's item button)
function WG.OnItemClick(self)
    local link = self.link
    if type(link) ~= "string" then return end
    if IsShiftKeyDown() then
        NS.Compat.InsertChatLink(link)
    elseif IsControlKeyDown() then
        NS.Compat.DressUpItem(link)
    elseif self.dropId ~= nil then
        WG.ToggleExpand(self.dropId)
    end
end

local function itemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.art = b:CreateTexture(nil, "ARTWORK")
    b.art:SetAllPoints(b)
    b:SetScript("OnEnter", function(self) itemEnter(self) end)
    b:SetScript("OnLeave", hideTooltip)
    b:SetScript("OnClick", WG.OnItemClick)
    return b
end

-- `where` says where the item is, for its tooltip: { dropId } for your own drop, { unit, slot }
-- for an item worn; nil for anything else (its link).
local function setItem(b, link, where)
    b.link = link
    b.ownDropId = where and where.dropId or nil
    b.worn = where and where.unit and where or nil
    local icon = link and NS.Compat.ItemIcon(link)
    b.art:SetTexture(icon or NS.Icon("help"))
    b:SetShown(link ~= nil)
end

--- A real item button (the game's tooltip on hover, shift-click links, ctrl-click tries on), for
--- the detail card too. `WG.SetItem(b, link, where)` shows an item on it, or hides it for nil;
--- `where` is WG.Where(drop) for a drop, { unit, slot } for an item worn, nil for a link only.
--- @param parent table
--- @param size number
--- @return table
function WG.ItemButton(parent, size) return itemButton(parent, size) end

WG.SetItem = setItem

--- Where a drop's item is, for its tooltip: your own live drop's bag item (once the trade timer
--- matched it), else nil (its link).
--- @param drop table
--- @return table|nil
function WG.Where(drop)
    if type(drop) ~= "table" or not drop.isMine or drop.test then return nil end
    return { dropId = drop.id }
end

--- A name beside an item button shows the button's real tooltip on hover while `frame.showItem` is
--- true (its own text tooltip then has no lines).
--- @param frame table
--- @param button table the item button
function WG.ItemHover(frame, button)
    frame.itemButton = button
    frame:HookScript("OnEnter", function(self)
        if self.showItem then itemEnter(self.itemButton, self) end
    end)
    frame:HookScript("OnLeave", hideTooltip)
end

-- ── building a row ──────────────────────────────────────────────────────────────────────────

local function itemCell(row)
    local f = textCell(row, "item")
    f.button = itemButton(f, K.ROW_ICON)
    WG.ItemHover(f, f.button)
    f.button:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.button, "RIGHT", 5, 0)
    return f
end

local function eqCell(row, key)
    local f = textCell(row, key)
    f.icons = { itemButton(f, K.EQ_ICON), itemButton(f, K.EQ_ICON) }
    f.icons[1]:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.icons[2]:SetPoint("LEFT", f.icons[1], "RIGHT", 2, 0)
    return f
end

local function actionsCell(row)
    local f = CreateFrame("Frame", nil, row)
    f.key = "actions"
    f.ask = NS.Window.TextButton(f, K.ASK_W, nil, L["Ask"], function(b) NS.PressAsk(b.dropId) end)
    f.ask:SetPoint("LEFT", f, "LEFT", 0, 0)
    NS.Window.AttachTooltip(f.ask, function() return tipOf(f.ask) end, "row")
    f.dash = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.dash:SetPoint("CENTER", f.ask, "CENTER", 0, 0)
    f.dashTip = CreateFrame("Frame", nil, f)
    f.dashTip:SetAllPoints(f.ask)
    NS.Window.AttachTooltip(f.dashTip, function() return tipOf(f.dashTip) end, "row")
    return f
end

local BUILDERS = { item = itemCell, myEq = eqCell, theirEq = eqCell, actions = actionsCell }

--- A drop row's (or compact card's) expand indicator: the header's chevron texture, ROW_CHEVRON
--- square, muted white (C.CHEVRON_ROW); the caller anchors it. WG.PaintChevron sets its state.
--- @param parent table the row or card
--- @return table the texture
function WG.RowChevron(parent)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetSize(K.ROW_CHEVRON, K.ROW_CHEVRON)
    local c = C.CHEVRON_ROW
    t:SetVertexColor(c.r, c.g, c.b, c.a)
    t:SetTexture(NS.Icon("chevron-down"))
    return t
end

--- Point a row's chevron down while it is collapsed and up while its detail card is open.
--- @param t table WG.RowChevron's texture
--- @param open boolean
function WG.PaintChevron(t, open)
    t:SetTexture(NS.Icon(open and "chevron-up" or "chevron-down"))
end

local function newRow(content)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(NS.WindowRows.ROW_H)
    row.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetColorTexture(1, 1, 1, 0.03)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints(row)
    row.selected:SetColorTexture(C.GOLD.r, C.GOLD.g, C.GOLD.b, 0.08)
    row.chevron = WG.RowChevron(row)
    row.chevron:SetPoint("LEFT", row, "LEFT", K.CHEVRON_X, 0)
    row.cells = {}
    for _, col in ipairs(WG.COLUMNS) do
        local make = BUILDERS[col.key] or (GLYPH_COLS[col.key] and glyphCell) or textCell
        row.cells[col.key] = make(row, col.key)
    end
    row:SetScript("OnClick", function(self) WG.ToggleExpand(self.dropId) end)
    return row
end

local function newHeader(content)
    local h = CreateFrame("Button", nil, content)
    h:SetHeight(K.GROUP_H)
    h.tipRow = true
    h.fill = h:CreateTexture(nil, "BACKGROUND")
    h.fill:SetAllPoints(h)
    h.fill:SetColorTexture(1, 1, 1, 0.06)
    h.chevron = h:CreateTexture(nil, "ARTWORK")
    h.chevron:SetSize(10, 10)
    h.chevron:SetPoint("LEFT", h, "LEFT", K.CHEVRON_X, 0)
    h.chevron:SetVertexColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)   -- gold, as its text (feedback-5 spec §0)
    h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    h.text:SetPoint("LEFT", h.chevron, "RIGHT", 6, 0)
    h.text:SetTextColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)
    h:SetScript("OnClick", function(self) WG.ToggleGroup(self.groupKey, self.collapsed) end)
    NS.Window.AttachTooltip(h, function() return tipOf(h) end, "row")
    return h
end
WG.NewHeader = newHeader   -- the compact cards' headers are the same button (modules/CompactGroup.lua)

-- ── painting a row ──────────────────────────────────────────────────────────────────────────

local function paintText(f, c)
    f.text:SetText(c.text)
    setTone(f.text, c.tone)
    f.tipLines = c.tip
    if f.glyph then
        f.glyph:SetText(c.glyph or "")
        setTone(f.glyph, c.tone)
        WG.PlaceGlyph(f, c.glyph)
    end
end

local function qualityTone(fs, drop)
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then fs:SetTextColor(qc.r, qc.g, qc.b) end
end

local function classTone(fs, classFile)
    local r, g, b = NS.Compat.ClassColor(classFile)
    if r then fs:SetTextColor(r, g, b) end
end

local function paintItem(f, drop)
    setItem(f.button, drop.link, WG.Where(drop))
    f.showItem = true
    paintText(f, WC.Item(drop))
    f.tipLines = nil   -- the real item tooltip instead (WG.ItemHover)
    qualityTone(f.text, drop)
end

-- The looter's worn gear: their inspect entry's (a test mode placeholder's own).
local function inspectGear(drop)
    local e = NS.TestMode.InspectOf(drop)
    return e and e.gear
end

-- Your worn gear: the gear snapshot's (NS.Gear), so it is always the current one.
local function myGear()
    local snap = NS.Gear.Snapshot()
    return snap and snap.equipped
end

-- An equipment cell: its worn items' icons, their item levels beside them. `unit` names whose
-- inventory an icon's tooltip reads (yours: the client's own tooltip for your slot), else the link.
local function paintEq(f, c, unit)
    paintText(f, c)
    for i, b in ipairs(f.icons) do
        local it = c.items[i]
        setItem(b, it and it.link or nil, it and unit and { unit = unit, slot = it.slot } or nil)
    end
    f.text:ClearAllPoints()
    local last = #c.items > 0 and f.icons[math.min(#c.items, 2)] or nil
    if last then f.text:SetPoint("LEFT", last, "RIGHT", 4, 0) else f.text:SetPoint("LEFT", f, "LEFT", 0, 0) end
end

--- The ask's state and reason; `traded` once the history settled the drop received (History.lua).
function WG.AskState(drop)
    local target = NS.AskTargetOf(drop)
    if not target then return NS.History.AskState(drop, "ready") end
    return NS.History.AskState(drop, NS.TestMode.AskState(drop, NS.Asks.StateOf("ask", target, drop.id)))
end

local function paintActions(f, drop)
    local state, reason = WG.AskState(drop)
    local a = WC.Ask(drop, state, reason, NS.Setting("messages.transmogAsk") == true)
    f.ask.dropId = drop.id
    f.ask:SetShown(a.offered)
    f.dashTip:SetShown(not a.offered)
    f.dash:SetShown(not a.offered)
    f.dash:SetText(a.text)
    f.ask.label:SetText(a.text)
    f.ask.art:SetTexture(a.icon and NS.Icon(a.icon) or nil)
    f.ask.art:SetShown(a.icon ~= nil)
    f.ask.label:ClearAllPoints()
    f.ask.label:SetPoint("CENTER", f.ask, "CENTER", a.icon and 7 or 0, 0)
    f.ask:SetEnabled(a.enabled)
    f.ask:SetAlpha(a.enabled and 1 or 0.6)
    f.ask.tipLines, f.dashTip.tipLines = a.tip, a.tip
    f.ask.state = a.state
    WG.ToneButton(f.ask, a.state)
end

-- What a cell's text may take of its width, so a long name is cut short rather than spilling into
-- the next column: the item button, the verdict glyph and the worn items take their share.
local EQ_INSET = 2 * (K.EQ_ICON + 2) + 4
local TEXT_INSET = { item = K.ROW_ICON + 5, me = 16, them = 16, myEq = EQ_INSET, theirEq = EQ_INSET }

local function placeCells(row, layout, height)
    for key, f in pairs(row.cells) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", WG.CHEVRON_LEAD + at.x, 0)
            f:SetSize(at.w, height)
            if f.text then f.text:SetWidth(max(at.w - (TEXT_INSET[key] or 0), 10)) end
        end
    end
end

local SIMPLE = { ilvl = WC.Ilvl, slot = WC.Slot, armorType = WC.ArmorType, me = WC.Me, trade = WC.Trade }

local function paintRow(row, drop, layout, now, metrics)
    row.dropId = drop.id
    local open = view().expanded == drop.id
    row.selected:SetShown(open)
    WG.PaintChevron(row.chevron, open)
    row:SetHeight(metrics.height)
    placeCells(row, layout, metrics.height)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize)
    NS.WindowRows.ApplyRowIcon(row, metrics.icon)
    local cells = row.cells
    paintItem(cells.item, drop)
    cells.item.button.dropId = drop.id
    for key, fn in pairs(SIMPLE) do paintText(cells[key], fn(drop)) end
    local lc = WC.Looter(drop)
    paintText(cells.looter, lc)
    classTone(cells.looter.text, lc.classFile)
    paintText(cells.them, WC.Them(drop, now))
    paintEq(cells.myEq, WC.MyEq(drop, myGear()), "player")
    paintEq(cells.theirEq, WC.TheirEq(drop, inspectGear(drop), now))
    paintActions(cells.actions, drop)
end

local function paintHeader(h, e, now)
    local g = e.group
    local sit = NS.WindowFooter.SITUATION_LABEL[g.situation]
    local hd = WC.Header(g, e.count, now, sit, e.collapsed, e.hidden, e.filter, e.yours)
    h.groupKey, h.collapsed = g.key, e.collapsed
    h.text:SetText(hd.text)
    h.tipLines = hd.tip
    h.chevron:SetTexture(NS.Icon(e.collapsed and "chevron-right" or "chevron-down"))
end

-- ── the empty state (board 06 D) ────────────────────────────────────────────────────────────

local function previewTip()
    return L["Preview with test data"], L["Turns test mode on: sample drops of real items in every state, so the window can be checked anywhere. Nothing is whispered, and combat ends it."]
end

local function scanTip()
    return L["Scan group"], L["Inspects every other member of your group, one at a time and out of combat, so each drop can be judged for its looter."]
end

-- No drop at all yet: what the table will hold, and the two ways to fill it now.
local function buildEmpty(pane)
    local e = CreateFrame("Frame", nil, pane)
    e:SetSize(K.EMPTY_W, K.EMPTY_H)
    e:SetPoint("CENTER", pane, "CENTER", 0, 0)
    e.title = e:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    e.title:SetPoint("TOP", e, "TOP", 0, 0)
    e.title:SetText(L["No drops yet"])
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    e.text:SetPoint("TOP", e.title, "BOTTOM", 0, -8)
    e.text:SetText(L["Loot your group receives appears here, grouped by boss."])
    local W = NS.Window
    e.preview = W.TextButton(e, 160, "eye", L["Preview with test data"], function() NS.SetTestMode(true) end)
    e.preview:SetPoint("TOPRIGHT", e.text, "BOTTOM", -4, -12)
    W.AttachTooltip(e.preview, previewTip)
    e.scan = W.TextButton(e, 110, "people", L["Scan group"], function() NS.ScanGroup() end)
    e.scan:SetPoint("TOPLEFT", e.text, "BOTTOM", 4, -12)
    W.AttachTooltip(e.scan, scanTip)
    e:Hide()
    return e
end

-- ── the pane ────────────────────────────────────────────────────────────────────────────────

local function buildHeads(pane)
    local head = CreateFrame("Frame", nil, pane)
    head:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -K.SCROLL_W, 0)
    head:SetHeight(K.COLHEAD_H)
    head.labels = {}
    for _, col in ipairs(WG.COLUMNS) do
        local f = CreateFrame("Frame", nil, head)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.text:SetTextColor(C.GOLD.r, C.GOLD.g, C.GOLD.b)   -- gold, as Loot History's (feedback-4 spec §4)
        NS.Window.AttachTooltip(f, function() return f.label, col.tip end)
        head.labels[col.key] = f
    end
    pane.colHead = head
end

local function build(pane)
    buildHeads(pane)
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane.colHead, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    pane.scroll, pane.content = scroll, content
    pane.rowPool, pane.headPool = NS.Pool.New(), NS.Pool.New()
    pane.card = NS.DetailCard.Build(content)
    pane.emptyState = buildEmpty(pane)
    pane.entries = {}
end

local function paintHeads(pane, cols, layout)
    for key, f in pairs(pane.colHead.labels) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", pane.colHead, "LEFT", WG.LEAD + at.x, 0)   -- over their cells
            f:SetSize(at.w, K.COLHEAD_H)
        end
    end
    for _, col in ipairs(cols) do
        local f = pane.colHead.labels[col.key]
        f.label = col.label
        f.text:SetText(f.label)
    end
end

-- The rows' width: the pane's, less the scroll bar's gutter; the window's before the first layout.
local function rowWidth(pane)
    local w = pane:GetWidth()
    if not w or w <= 0 then
        local f = NS.Window.Frame()
        w = (f and f:GetWidth() or K.WIDTH) - 2 * K.INSET
    end
    return w - K.SCROLL_W
end

-- `x` indents a drop row and its detail card (K.ROW_INDENT); a header takes the full width.
local function place(frame, content, y, width, x)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, -y)
    frame:SetWidth(width - (x or 0))
end

-- The open row's detail card under it, indented with its row; answers the height it takes.
local function drawCard(pane, drop, y, width, now)
    place(pane.card, pane.content, y, width, K.ROW_INDENT)
    NS.DetailCard.Paint(pane.card, drop, width - K.ROW_INDENT, now)
    pane.card:Show()
    pane.cardDropId = drop.id
    return K.CARD_H
end

local function drawEntries(pane, entries, layout, width)
    local now, y, metrics = GetTime(), 0, NS.WindowRows.Metrics()
    local Pool = NS.Pool
    local expanded = view().expanded
    pane.card:Hide()
    pane.cardDropId = nil
    for i, e in ipairs(entries) do
        if e.kind == "header" then
            local h = Pool.Acquire(pane.headPool, function() return newHeader(pane.content) end)
            place(h, pane.content, y, width)
            paintHeader(h, e, now)
            y = y + K.GROUP_H
        else
            local r = Pool.Acquire(pane.rowPool, function() return newRow(pane.content) end)
            place(r, pane.content, y, width, K.ROW_INDENT)
            r.stripe:SetShown(i % 2 == 0)
            paintRow(r, e.drop, layout, now, metrics)
            y = y + metrics.height
            if e.drop.id == expanded then y = y + drawCard(pane, e.drop, y, width, now) end
        end
    end
    pane.content:SetSize(width, max(y, 1))
end

-- Nothing drawn: the empty state when the feed holds no drop at all, else the line saying the
-- filters hide them. The window is never a blank table.
-- In test mode an empty test feed is still gathering its items, or found none (ui spec §4).
local function paintEmpty(pane, entries, ctx, compact)
    local none = #entries == 0
    local nothing = none and #NS.LootFeed.Drops(ctx.feed) == 0
    local test = nothing and ctx.feed == "test"
    pane.emptyState:SetShown(nothing and not test)
    pane.placeholder:SetShown(none and (test or not nothing))
    pane.placeholder:SetText(not test and NO_MATCH or NS.TestMode.IsLoading() and TEST_LOADING or TEST_NONE)
    pane.colHead:SetShown(not (none or compact))
end

local function drawTable(pane, entries)
    local w = profileWindow()
    local cols = WG.Columns(w and w.columns)
    local width = rowWidth(pane)
    local layout, kept = WG.Layout(cols, width - WG.LEAD)   -- the columns start after the indent and chevron
    paintHeads(pane, cols, layout)
    drawEntries(pane, entries, layout, width)
    pane.columns = kept
end

-- The table, or (compact) the cards over the same entries; the other one is released and hidden.
local function refresh(pane, ctx)
    local LF = NS.LootFeed
    local entries = WC.Entries(LF.Groups(ctx.feed), LF.Get, ctx, view())
    local compact = WG.IsCompact()
    NS.Pool.ReleaseAll(pane.rowPool)
    NS.Pool.ReleaseAll(pane.headPool)
    pane.scroll:SetShown(not compact)
    if not compact then drawTable(pane, entries) end
    NS.CompactGroup.Refresh(pane, entries, compact)
    pane.entries = entries
    paintEmpty(pane, entries, ctx, compact)
end

--- The drawn pane's rows and headers, in order, for the suites: { headers, rows, entries, columns,
--- pane, card, cardDropId, empty } (`cardDropId` nil while no card is open on screen; `empty` the
--- empty state's frame).
--- @return table|nil
function WG.Drawn()
    local f = NS.Window.Frame()
    local pane = f and f.panes.group
    if not (pane and pane.rowPool) then return nil end
    if WG.IsCompact() then return NS.CompactGroup.Drawn(pane) end
    return { rows = pane.rowPool.active, headers = pane.headPool.active, entries = pane.entries,
        columns = pane.columns, pane = pane, card = pane.card, cardDropId = pane.cardDropId,
        empty = pane.emptyState }
end

NS.Window.RegisterTab("group", { build = build, refresh = refresh })
