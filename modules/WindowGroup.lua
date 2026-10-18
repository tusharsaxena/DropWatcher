local _, NS = ...
-- modules/WindowGroup.lua — the Drops table (design spec §11.1-§11.2, boards 01, 03 and 06):
-- every drop the group receives, one row each, under a collapsible header per encounter or key run.
--
-- THE COLUMNS. Item (a real item button and the name), Ilvl, Slot, Type (Cloth … Plate, Jewelry,
-- Trinkets, Cloak or Weapons; feedback-4 spec §3), Looter (in class color), Me and Them (what you,
-- or the looter, wear in that slot and the drop judged for you, or them, in one cell: the worn item's
-- icon or two, its item level, then ▲ ≈ ▼ and the item-level difference in the verdict's green,
-- yellow or red, `292 ▲19`, and on two worn items both read a mark each, `321 ▼10 / 308 ▲3`
-- (feedback-21 H7); your gear from its snapshot, theirs from their inspect read, the
-- read's age in the tooltip; NS.SideCells, feedback-6 spec §1, which merged My eq and Their eq into
-- them), Trade (Yes, Likely, Unknown or No), Trade window (every drop's countdown over its bar, an estimate from
-- when it dropped for another player's, `No limit (BoE)`, or the short reason it cannot be traded;
-- NS.MineCells.TradeWindow, feedback-5 spec §1) and Actions (the Ask button; no drop is ever
-- dismissed, feedback-4 spec §2). YOUR OWN DROPS are listed too (feedback-5 spec §2;
-- modules/WindowOwn.lua): Looter reads `Name [YOU]`, Them reads `Upgrade for N` (feedback-7
-- spec §2) with each upgrade in the tooltip (`Hidden` while it is an upgrade for you that you
-- have not offered), and Actions is Offer, which opens the Offer panel (no Announce in the table).
-- `profile.window.columns[key] = false` hides a column (Item never hides); a row too narrow for them
-- all sheds columns by their `shed` order (WG.Fit) rather than clip Actions. What every
-- cell says, and its reason tooltip, is modules/WindowCells.lua's and modules/SideCells.lua's
-- (pure); this file is the frame edge that paints it. Nothing is ever blank. A column tooltip draws
-- the verdict marks as NS.TipMarks' inline textures (the tooltip's face has no ▲ ≈ ▼).
--
-- THE ROWS. Pooled through LibKa0s-Pool-1.0 (NS.Pool), one pool for the drop rows and one for the
-- headers, released and re-acquired in order on every repaint (Pool v3 hands them back in their
-- order). Each row builds every column's cell once; a repaint shows, places and paints the ones
-- the column set keeps. A drop row's height, its item button and its cells' text size are the
-- Window page's Layout rows (`window.rowHeight`, `window.fontSize`), read through
-- modules/WindowRows.lua at each repaint (18 pixels and the template's own size by default, like
-- Ka0s Loot History's table; feedback-2 spec §8, FB2-9); the headers, the column labels and the
-- buttons keep their own. While the Trade window column is shown a row is the room its countdown
-- bar needs taller (WindowRows' countdownHeight), so the text and the bar never overlap.
--
-- THE STRIP (feedback-5 spec §3, feedback-7 spec §4). Under the table (or the compact cards), above
-- the footer: `n tradeable · next expiry 0:08:41`, Post my tradeables (while one of your drops the
-- tab lists can be traded), Expand all / Collapse all (WG.FoldAll, feedback-15 spec §2) and, in the
-- full layout, Scan group; always shown, in both layouts (modules/DropsStrip.lua, built with the
-- pane and repainted with it).
--
-- THE COUNTDOWNS MOVE each second while a shown row or the strip has one (feedback-5 spec §1;
-- the strip counts your drops under a collapsed header too): Window.lua's
-- countdown ticker, its footer ticker and TradeTimerTick call WG.TickCountdowns, which repaints the
-- Trade window cells alone (the compact cards show none, feedback-10 spec §2) and the strip's next expiry, never
-- the whole table;
-- WG.LiveCountdown tells Window.lua whether the ticker is still wanted.
--
-- THE ORDER. NS.WindowCells.Entries (pure): the feed's groups newest first (oldest first under Sort: Oldest),
-- each group's drops that pass the tab's filter (Window.TabContext: the filter bar's predicate;
-- your own drops with the others) ordered by the tab's Sort. A group with none keeps its header
-- (`n drops · 0 shown`) while the View filter hid them, and is left out when Search, Content or
-- Character did or it has nothing for the tab (WC.KeepsHeader). A group the
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
-- The Ask button goes through the host handler NS.PressAsk (core/DropWatcher.lua), the Offer button
-- to the Offer panel (NS.WindowOwn.PressAction). An item button
-- shows the game's tooltip, shift-click links it (Compat.InsertChatLink) and ctrl-click tries it
-- on (Compat.DressUpItem).

NS.WindowGroup = NS.WindowGroup or {}
local WG    = NS.WindowGroup
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local WC    = NS.WindowCells
local SC    = NS.SideCells
local TM    = NS.TipMarks

local max = math.max

-- Where a drop row's Item column starts, from the header's left edge (feedback-5 spec §0): the
-- row's indent, then its chevron (CHEVRON_X in, ROW_CHEVRON wide) and the gap after it. The chevron
-- is not a column: no label, no toggle, never shed.
WG.CHEVRON_LEAD = K.CHEVRON_X + K.ROW_CHEVRON + K.CHEVRON_GAP
WG.LEAD = K.ROW_INDENT + WG.CHEVRON_LEAD
-- The Trade window cell's own padding: its bar stops this far short of the cell's right edge, and
-- the column is its widest answer (`No limit (BoE)`) plus this (feedback-6 spec §0; measured over
-- every MineCells.TradeWindow answer by tests/test_drops_layout.lua).
WG.TRADE_WINDOW_PAD = 6
-- A Me or Them cell's pieces, left to right (feedback-6 spec §1): the worn items' icons (EQ_ICON
-- each, ICON_GAP apart), LEVEL_GAP, the item level, VERDICT_GAP, the glyph (the monospace face),
-- GLYPH_GAP, the difference or the word. A piece that is not there takes no room and no gap. A dual
-- mark (NS.SideCells' `parts`, feedback-21 H7) puts the first worn item's level, glyph and difference
-- before them, then PART_GAP, a muted `/` and PART_GAP: `321 ▼10 / 324 ▼23`. The columns are their
-- widest cell (tests/test_side_cells.lua measures every kind, the dual mark at two-digit differences).
WG.SIDE = { ICON_GAP = 2, LEVEL_GAP = 4, VERDICT_GAP = 4, GLYPH_GAP = 3, PART_GAP = 4 }
-- Between a dual mark's two parts (feedback-21 H7): a punctuation mark, as WindowCells.Levels' `/`.
WG.PART_SEP = "/"

-- The default columns, left to right (design spec §11.1). `flex` takes the width the others leave.
-- `tip` is the header's tooltip rows (feedback-21); `desc` the prose the settings panel's Columns
-- checkbox shows for it (settings/SchemaRows.lua), which stays prose.
-- `shed` is the order a too-narrow window lets columns go (1 first; WG.Layout): what they say is
-- also on the row's detail card. Item and Actions never go.
WG.COLUMNS = {
    { key = "item", label = L["Item"], flex = true,
      tip = { TM.Row(L["Shows"], L["the drop"]),
          TM.Hint(L["Hover its icon for the game's tooltip; shift-click links it, ctrl-click tries it on."]) } },
    { key = "ilvl", label = L["Ilvl"], width = 40, shed = 4, tip = { TM.Row(L["Shows"], L["the drop's item level"]) },
      desc = L["The drop's item level."] },
    { key = "slot", label = L["Slot"], width = 72, shed = 1, tip = { TM.Row(L["Shows"], L["where the drop is worn"]) },
      desc = L["Where the drop is worn."] },
    { key = "armorType", label = L["Type"], width = 64, shed = 0,
      tip = { TM.Row(L["Shows"], L["what kind of item it is"]),
          TM.Row(L["Values"], L["Cloth, Leather, Mail, Plate, Jewelry, Trinkets, Cloak, Weapons"]) },
      desc = L["What kind of item it is: Cloth, Leather, Mail or Plate armor, Jewelry, Trinkets, a Cloak or Weapons."] },
    { key = "looter", label = L["Looter"], width = 104, shed = 2, tip = { TM.Row(L["Shows"], L["who looted it, in their class color"]) },
      desc = L["Who looted it, in their class color."] },
    { key = "me", label = L["Me"], width = 127, shed = 7,
      desc = L["What you wear in that slot (two items for rings, trinkets and one-hand weapons) and its item level, then the drop judged for you: %s upgrade (green), %s sidegrade (yellow) or %s downgrade (red) and the item-level difference. Hover an icon for the item."]:format(
          TM.Mark("upgrade"), TM.Mark("sidegrade"), TM.Mark("downgrade"))
          .. " " .. L["Cyan: an upgrade for another of your specs (off-spec); your current spec can't use it."],
      tip = { TM.Row(L["Shows"], L["what you wear there (two for rings, trinkets, one-hand weapons), its item level"]),
          TM.Row(L["Then"], L["the drop judged for you, and the item-level difference"]),
          TM.Row(L["Two worn"], L["a mark each, the drop against each"]),
          TM.Row(L["Colors"], L["%s upgrade, %s sidegrade, %s downgrade"]:format(TM.Mark("upgrade"), TM.Mark("sidegrade"),
              TM.Mark("downgrade"))),
          NS.OffSpecCells.Legend(), TM.Hint(L["Hover an icon for the item."]) } },
    { key = "them", label = L["Them"], width = 127, shed = 5,
      desc = L["What the looter wears in that slot and its item level, then the drop judged for them in the same colors. Hover for how old their read is. On your own drop, Upgrade for N lists who it would help."],
      tip = { TM.Row(L["Shows"], L["what the looter wears there, its item level"]),
          TM.Row(L["Then"], L["the drop judged for them, in the same colors"]),
          TM.Row(L["Two worn"], L["a mark each, the drop against each"]),
          TM.Row(L["Your own drop"], L["Upgrade for N, who it would help"]), TM.Hint(L["Hover for how old their read is."]) } },
    { key = "trade", label = L["Trade"], width = 70, shed = 6,
      tip = { TM.Row(L["Shows"], L["whether the looter can trade it"]), TM.Row(L["Values"], L["Yes, Likely, Unknown or No"]) },
      desc = L["Whether the looter can trade it: Yes, Likely, Unknown or No."] },
    { key = "tradeWindow", label = L["Trade window"], width = 76, shed = 3,
      desc = L["The time left to trade it, over its bar: exact for your own item once it is in your bags, else estimated from when it dropped. Amber and bold when it is ending soon."],
      tip = { TM.Row(L["Shows"], L["the time left to trade it, over its bar"]),
          TM.Row(L["Exact"], L["your own item, once it is in your bags"]), TM.Row(L["Estimated"], L["from when it dropped"]),
          TM.Row(L["Amber and bold"], L["ending soon"]) } },
    { key = "actions", label = L["Actions"], width = K.ASK_W,
      desc = L["Ask the looter for it, once. On your own drop, Offer shows who it would help."],
      tip = { TM.Row(L["Shows"], L["Ask the looter for it, once"]), TM.Row(L["Your own drop"], L["Offer, who it would help"]) } },
}
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

--- Collapse, or open, every header the tab shows (Expand all / Collapse all, feedback-15 spec §2).
--- @param entries table|nil the drawn entries (WC.Entries')
--- @param collapse boolean
function WG.FoldAll(entries, collapse)
    NS.FooterRow.FoldAll(entries, view().collapsed, collapse)
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

--- Open a live drop's header and expand its card (the History card's Show in Drops, feedback-15
--- spec §4); false when the feed no longer holds it.
--- @param id number
--- @return boolean
function WG.Reveal(id)
    local rec = NS.LootFeed.Get(id)
    if not rec then return false end
    local v = view()
    if rec.groupKey ~= nil then v.collapsed[rec.groupKey] = false end
    v.expanded = id
    return true
end

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

--- Put a verdict cell's text after its glyph, or at the cell's left edge when it has none: the
--- arrow comes before the number in every full table (feedback-4 spec §0). History's verdict cells.
--- @param f table the cell (`f.text`, `f.glyph`)
--- @param glyph string|nil
function WG.PlaceGlyph(f, glyph)
    f.text:ClearAllPoints()
    if glyph and glyph ~= "" then
        f.text:SetPoint("LEFT", f.glyph, "RIGHT", WG.SIDE.GLYPH_GAP, 0)
    else
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    end
end

--- Place a Me or Them cell's pieces left to right (WG.SIDE): the shown icons, the item level, the
--- glyph, the difference or word; each after the last piece shown, the first at the cell's edge.
--- The difference or word ends at the cell's right edge, so a long word (or a larger Font size) is
--- cut short there rather than spilling into the next column.
--- A dual mark (`dual`, feedback-21 H7) places the first part's pieces (`leadLevel`, `leadGlyph`,
--- `leadText`) and the muted `sep` before the second part's, which are the single pieces.
--- @param f table the cell (`icons`, `level`, `glyph`, `text`; `leadLevel`, `leadGlyph`, `leadText`, `sep`)
--- @param nIcons number the icons shown (0..2)
--- @param hasLevel boolean
--- @param hasGlyph boolean
--- @param dual boolean|nil
function WG.PlaceSide(f, nIcons, hasLevel, hasGlyph, dual)
    local S = WG.SIDE
    local last, gap = nil, 0
    if nIcons > 0 then last, gap = f.icons[math.min(nIcons, 2)], S.LEVEL_GAP end
    local function after(fs, wanted)
        fs:ClearAllPoints()
        if last then fs:SetPoint("LEFT", last, "RIGHT", gap, 0) else fs:SetPoint("LEFT", f, "LEFT", 0, 0) end
        if wanted then last = fs end
    end
    if dual then
        after(f.leadLevel, true)
        gap = S.VERDICT_GAP
        after(f.leadGlyph, true)
        gap = S.GLYPH_GAP
        after(f.leadText, true)
        gap = S.PART_GAP
        after(f.sep, true)
    end
    after(f.level, hasLevel)
    if hasLevel then gap = S.VERDICT_GAP end
    after(f.glyph, hasGlyph)
    if hasGlyph then gap = S.GLYPH_GAP end
    after(f.text, true)
    f.text:SetPoint("RIGHT", f, "RIGHT", 0, 0)
end

--- Color an action button's label and mark by whose move it is (feedback-4 spec §1): red your
--- move (cyan for an Offer, feedback-6 spec §2), yellow waiting on someone else, green done
--- (WindowCells.ActionTone); white for a state that is none of them. Every Ask, Offer and Announce
--- button goes through here, in both layouts.
--- @param b table a Window.TextButton (`b.label`, `b.art`)
--- @param state string|nil the button's state (WindowCells.ActionTone's key)
--- @param kind string|nil `offer` for a button that reads Offer
function WG.ToneButton(b, state, kind)
    local tone = NS.WindowCells.ActionTone(state, kind)
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
    NS.IconStyle.Apply(b, nil)   -- Window › Icons' look (modules/IconStyle.lua), from the start
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
    NS.IconStyle.Apply(b, link)  -- the border's quality color follows the item
    b:SetShown(link ~= nil)
end

--- A real item button (the game's tooltip on hover, shift-click links, ctrl-click tries on), for
--- the detail card too. `WG.SetItem(b, link, where)` shows an item on it, or hides it for nil;
--- `where` is WG.Where(drop) for a drop, { unit, slot } for an item worn, nil for a link only.
--- Every one wears Window › Icons' zoom and border (NS.IconStyle, feedback-21 G11).
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

--- A dual mark's first part and its separator (feedback-21 H7) on a Me or Them cell, built once:
--- `leadLevel` (plain), `leadGlyph` (the monospace face), `leadText` and the muted `sep`; hidden
--- until a dual cell is painted (WG.PaintLead).
--- @param f table the cell
function WG.BuildLead(f)
    f.leadLevel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.leadGlyph = f:CreateFontString(nil, "OVERLAY")
    f.leadGlyph:SetFont(C.FONT_MONO, 12, "")
    f.leadText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sep = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    for _, fs in ipairs({ f.leadLevel, f.leadGlyph, f.leadText, f.sep }) do
        fs:SetWordWrap(false)
        fs:Hide()
    end
end

--- Paint a dual mark's first part and its separator on `f` (WG.BuildLead's pieces; a compact half's
--- and the toast's segments are the same four): the level plain, the glyph and the difference in the
--- part's tone, the `/` muted. Hides them with no `parts`. Answers the second part, which the
--- caller paints in its single pieces, or nil.
--- @param f table { leadLevel, leadGlyph, leadText, sep }
--- @param parts table|nil NS.SideCells' `parts`
--- @return table|nil
function WG.PaintLead(f, parts)
    local first = type(parts) == "table" and parts[1] or nil
    f.leadLevel:SetShown(first ~= nil); f.leadGlyph:SetShown(first ~= nil)
    f.leadText:SetShown(first ~= nil); f.sep:SetShown(first ~= nil)
    if not first then return nil end
    f.leadLevel:SetText(first.level or "")
    setTone(f.leadLevel, "plain")
    f.leadGlyph:SetText(first.glyph or "")
    setTone(f.leadGlyph, first.tone)
    f.leadText:SetText(first.text or "")
    setTone(f.leadText, first.tone)
    f.sep:SetText(WG.PART_SEP)
    setTone(f.sep, "muted")
    return parts[2]
end

-- A Me or Them cell: the worn items' buttons, the item level, the glyph (the monospace face) and
-- the difference or word (`f.text`); WG.PlaceSide places them. WG.SideCell: the Offer panel's
-- Their eq cell is built the same (feedback-7 spec §0).
local function sideCell(row, key)
    local f = textCell(row, key)
    f.icons = { itemButton(f, K.EQ_ICON), itemButton(f, K.EQ_ICON) }
    f.icons[1]:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.icons[2]:SetPoint("LEFT", f.icons[1], "RIGHT", WG.SIDE.ICON_GAP, 0)
    f.level = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.level:SetWordWrap(false)
    f.glyph = f:CreateFontString(nil, "OVERLAY")
    f.glyph:SetFont(C.FONT_MONO, 12, "")
    WG.BuildLead(f)
    return f
end
WG.SideCell = sideCell

local function actionsCell(row)
    local f = CreateFrame("Frame", nil, row)
    f.key = "actions"
    f.ask = NS.Window.TextButton(f, K.ASK_W, "chat", L["Ask"], function(b) NS.WindowOwn.PressAction(b) end)
    f.ask:SetPoint("LEFT", f, "LEFT", 0, 0)
    NS.Window.AttachTooltip(f.ask, function() return tipOf(f.ask) end, "row")
    return f
end

-- The Trade window cell: the countdown at the top, its K.BAR_H bar at the bottom (the row is the
-- bar's room taller while the column shows).
local function tradeWindowCell(row)
    local f = textCell(row, "tradeWindow")
    f.text:ClearAllPoints()
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
    f.barBg = f:CreateTexture(nil, "BACKGROUND")
    f.barBg:SetColorTexture(1, 1, 1, 0.12)
    f.barBg:SetHeight(K.BAR_H)
    f.barBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 5)
    f.barBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -WG.TRADE_WINDOW_PAD, 5)
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetHeight(K.BAR_H)
    f.bar:SetPoint("BOTTOMLEFT", f.barBg, "BOTTOMLEFT", 0, 0)
    return f
end

local BUILDERS = { item = itemCell, me = sideCell, them = sideCell, actions = actionsCell, tradeWindow = tradeWindowCell,
    looter = function(row, key) return NS.WindowRows.MarkedCell(textCell(row, key)) end }

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
        local make = BUILDERS[col.key] or textCell
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
    h.text:SetJustifyH("LEFT")   -- the compact headers size the text to the line; it reads from the left
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
end

local function qualityTone(fs, drop)
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then fs:SetTextColor(qc.r, qc.g, qc.b) end
end

local function classTone(fs, classFile, fallback)
    local r, g, b = NS.Compat.ClassColor(classFile)
    if not r and fallback then
        local t = C.TONE[fallback] or C.TONE.plain
        r, g, b = t.r, t.g, t.b
    end
    if r then fs:SetTextColor(r, g, b) end
end

--- Put a name in its class color (NS.Compat.ClassColor), else in the `fallback` tone (a C.TONE key),
--- else leave the text's color as it is. The Offer panel's member and the detail card share it.
--- @param fs table a FontString
--- @param classFile string|nil
--- @param fallback string|nil
WG.ClassTone = classTone

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

-- Your worn gear and class: the gear snapshot's (NS.Gear), so it is always the current one.
local function myGear()
    local snap = NS.Gear.Snapshot()
    return snap and snap.equipped, snap and snap.classFile
end

-- A Me or Them cell (NS.SideCells): the worn items' icons, their item level (plain, or a muted
-- word), then the glyph and the difference or word in the verdict's tone. `unit` names whose
-- inventory an icon's tooltip reads (yours: the client's own tooltip for your slot), else the link;
-- an item with no slot (an off-spec bag item, feedback-19 spec §1) always reads its link.
-- The item level, glyph and difference or word: a dual mark's second part (its first in the lead
-- pieces), else the cell's one mark. Answers the second part, or nil.
local function paintMarks(f, c, parts)
    local second = WG.PaintLead(f, parts)
    local p = second or c
    f.level:SetText(p.level or "")
    setTone(f.level, second and "plain" or c.levelTone)
    f.glyph:SetText(p.glyph or "")
    setTone(f.glyph, p.tone)
    f.text:SetText(p.text)
    setTone(f.text, p.tone)
    return second
end

-- A piece's width on one line (unbounded: the last piece is cut at the cell's edge), or nil while
-- its font is not loaded.
local function pieceWidth(fs)
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    return fn(fs)
end

-- A dual mark's pieces in WG.PlaceSide's order (WG.DualFits adds the gaps between them).
local DUAL_PIECES = { "leadLevel", "leadGlyph", "leadText", "sep", "level", "glyph", "text" }

--- Whether a painted dual mark (feedback-21 H7) fits its cell: its pieces at WG.PlaceSide's gaps
--- after `nIcons` icons, within the cell's width. The columns keep the width the Default size
--- measures, so at a larger Font size a dual mark can run past the cell into the next column; it
--- then gives way to the one mark (feedback-21 R5). True while a piece cannot be measured (a font not
--- yet loaded) or the cell has no width yet.
--- @param f table a Me or Them cell, its dual mark painted
--- @param nIcons number the icons shown (0..2)
--- @return boolean
function WG.DualFits(f, nIcons)
    local S, room = WG.SIDE, f:GetWidth() or 0
    if room <= 0 then return true end
    local w = 2 * (S.VERDICT_GAP + S.GLYPH_GAP + S.PART_GAP)
    if nIcons > 0 then w = w + nIcons * K.EQ_ICON + (nIcons - 1) * S.ICON_GAP + S.LEVEL_GAP end
    for _, key in ipairs(DUAL_PIECES) do
        local pw = pieceWidth(f[key])
        if not pw then return true end
        w = w + pw
    end
    return w <= room
end

local function paintSide(f, c, unit)
    paintText(f, c)
    for i, b in ipairs(f.icons) do
        local it = c.items[i]
        setItem(b, it and it.link or nil, it and unit and it.slot and { unit = unit, slot = it.slot } or nil)
    end
    local nIcons = math.min(#c.items, 2)
    local second = paintMarks(f, c, c.parts)
    if second and not WG.DualFits(f, nIcons) then second = paintMarks(f, c, nil) end
    local p = second or c
    WG.PlaceSide(f, #c.items, p.level ~= nil, p.glyph ~= nil, second ~= nil)
end
WG.PaintSide = paintSide   -- the Offer panel's Their eq cell too (feedback-7 spec §0)

--- The ask's state and reason; `traded` once the history settled the drop received (History.lua).
function WG.AskState(drop)
    local target = NS.AskTargetOf(drop)
    if not target then return NS.History.AskState(drop, "ready") end
    return NS.History.AskState(drop, NS.TestMode.AskState(drop, NS.Asks.StateOf("ask", target, drop.id)))
end

--- A row's action (both layouts): your own drop's Offer (NS.WindowOwn.Offer), else the Ask
--- (WindowCells.Ask's look in the ask's state).
--- @param drop table
--- @return table WindowCells.Ask's shape (`offer` true for an Offer)
function WG.Action(drop)
    if drop.isMine then return NS.WindowOwn.Offer(drop) end
    local state, reason = WG.AskState(drop)
    return WC.Ask(drop, state, reason, NS.Setting("messages.transmogAsk") == true)
end

local function paintActions(f, drop)
    local a = WG.Action(drop)
    f.ask.dropId, f.ask.offer = drop.id, a.offer == true
    NS.Window.SetButtonMark(f.ask, a.text, a.icon)   -- No action where there is none (feedback-11 spec §1)
    f.ask:SetEnabled(a.enabled)
    f.ask:SetAlpha(a.enabled and 1 or 0.6)
    f.ask.tipLines = a.tip
    f.ask.state = a.state
    WG.ToneButton(f.ask, a.state, a.kind)
end

-- What a cell's text may take of its width, so a long name is cut short rather than spilling into
-- the next column: the item button takes its share. A Me or Them cell's pieces are placed one after
-- the other, and the column is their widest (WG.SIDE); the last ends at the cell's right edge
-- (WG.PlaceSide), which cuts it short instead.
local TEXT_INSET = { item = K.ROW_ICON + 5 }
local SIDE_COLS = { me = true, them = true }

local function placeCells(row, layout, height)
    for key, f in pairs(row.cells) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", WG.CHEVRON_LEAD + at.x, 0)
            f:SetSize(at.w, height)
            if f.text and not SIDE_COLS[key] then f.text:SetWidth(max(at.w - (TEXT_INSET[key] or 0), 10)) end
        end
    end
end

-- The countdown's face follows its urgency (bold while ending soon); SetFontObject puts the
-- template's size back, so the Font size row's size goes on again after it. The bar fills by the
-- window left, amber while ending soon.
local function paintTradeWindow(f, drop, now, warnAt, size)
    local c = NS.MineCells.TradeWindow(drop, now, warnAt)
    paintText(f, c)
    f.text:SetFontObject(c.bold and "GameFontNormalSmall" or "GameFontHighlightSmall")
    if size then NS.WindowRows.SetFontSize(f.text, size) end
    setTone(f.text, c.tone)
    local w = max((f:GetWidth() or 0) - WG.TRADE_WINDOW_PAD, 0)
    f.fraction = c.fraction or 0
    f.bar:SetWidth(max(w * f.fraction, 0.01))
    f.bar:SetShown(f.fraction > 0)
    local tone = C.TONE[c.soon and "warn" or "good"]
    f.bar:SetColorTexture(tone.r, tone.g, tone.b, 0.9)
    f.bold = c.bold == true
end

local SIMPLE = { ilvl = WC.Ilvl, slot = WC.Slot, armorType = WC.ArmorType }

--- The Them cell for any drop (NS.SideCells.Them): what the looter wears and their verdict, or on
--- your own drop `Upgrade for N` (or `Hidden`, by the session's reveal state: NS.WindowOwn).
--- @param drop table
--- @param gear table|nil the looter's inspect gear
--- @param now number|nil
--- @return table cell (with `items`)
function WG.ThemCell(drop, gear, now)
    return SC.Them(drop, gear, now, drop.isMine and NS.WindowOwn.IsRevealed(drop.id) or nil)
end

-- `metrics.rowH` is this repaint's row height (drawTable: taller while Trade window shows).
local function paintRow(row, drop, layout, now, metrics)
    row.dropId, row.drop = drop.id, drop
    local open = view().expanded == drop.id
    row.selected:SetShown(open)
    WG.PaintChevron(row.chevron, open)
    row:SetHeight(metrics.rowH)
    placeCells(row, layout, metrics.rowH)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize)
    NS.WindowRows.ApplyRowIcon(row, metrics.icon)
    local cells = row.cells
    paintItem(cells.item, drop)
    cells.item.button.dropId = drop.id
    NS.Glow.Apply(cells.item.button, drop)   -- after ApplyRowIcon: the glow is sized from the button
    for key, fn in pairs(SIMPLE) do paintText(cells[key], fn(drop)) end
    local lc = WC.Looter(drop)
    paintText(cells.looter, lc)
    classTone(cells.looter.text, lc.classFile)
    NS.WindowRows.PaintMark(cells.looter, lc.you, layout.looter)   -- ` [YOU]` (feedback-7 spec §2)
    paintText(cells.trade, NS.WindowOwn.Trade(drop))
    local equipped, classFile = myGear()
    -- A sample's Me shows its own worn items, their tooltips the links (feedback-18).
    paintSide(cells.me, SC.Me(drop, NS.TestMode.GearOf(drop, equipped), classFile), not drop.test and "player" or nil)
    paintSide(cells.them, WG.ThemCell(drop, inspectGear(drop), now))
    if layout.tradeWindow then paintTradeWindow(cells.tradeWindow, drop, now, metrics.warnAt, metrics.fontSize) end
    paintActions(cells.actions, drop)
end

local function paintHeader(h, e, now)
    local g = e.group
    local sit = NS.WindowFooter.SITUATION_LABEL[g.situation]
    local hd = WC.Header(g, e.count, now, sit, e.collapsed, e.hidden, e.filter)
    h.groupKey, h.collapsed = g.key, e.collapsed
    h.text:SetText(hd.text)
    h.tipLines = hd.tip
    h.chevron:SetTexture(NS.Icon(e.collapsed and "chevron-right" or "chevron-down"))
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
        NS.Window.AttachTooltip(f, function() return f.label, unpack(col.tip) end)
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
    pane.emptyState = NS.DropsStrip.BuildEmpty(pane)   -- the empty state (board 06 D)
    pane.entries = {}
    NS.DropsStrip.Build(pane)
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
    metrics.rowH = layout.tradeWindow and metrics.countdownHeight or metrics.height
    metrics.warnAt = NS.TradeTimer.WarnAt()
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
            y = y + metrics.rowH
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
    pane.columns, pane.layout = kept, layout
end

local function rowIcon(row) return row.cells.item.button end

-- The table, or (compact) the cards over the same entries; the other one is released and hidden.
local function refresh(pane, ctx)
    local LF = NS.LootFeed
    local entries = WC.Entries(LF.Groups(ctx.feed), LF.Get, ctx, view())
    local compact = WG.IsCompact()
    NS.Pool.ReleaseAll(pane.rowPool)
    NS.Pool.ReleaseAll(pane.headPool)
    pane.scroll:SetShown(not compact)
    if not compact then drawTable(pane, entries) end
    NS.Glow.StopFree(pane.rowPool, rowIcon)   -- the rows this repaint left unused (all, in compact)
    NS.CompactGroup.Refresh(pane, entries, compact)
    pane.entries = entries
    NS.DropsStrip.Paint(pane, ctx, compact)
    paintEmpty(pane, entries, ctx, compact)
end

-- ── the countdowns (feedback-5 spec §1) ─────────────────────────────────────────────────────

local function shownPane()
    local f = NS.Window.Frame()
    local pane = f and f.panes.group
    return pane and pane.rowPool and pane or nil
end

-- Whether a drawn row shows a countdown still running: the Trade window column is kept and a drawn
-- drop has time left. The compact cards show none (feedback-10 spec §2).
local function rowsLive(pane)
    if not pane.entries or WG.IsCompact() then return false end
    if not (pane.layout and pane.layout.tradeWindow) then return false end
    local now, MC = GetTime(), NS.MineCells
    for _, e in ipairs(pane.entries) do
        local cd = e.kind ~= "header" and MC.Countdown(e.drop, now)
        if cd and cd.left > 0 then return true end
    end
    return false
end

--- Whether anything on screen shows a countdown still running: a drawn row's Trade window, or the strip's next expiry, which also counts your drops under a collapsed header
--- and shows whether the column is kept or not. Window.lua runs its each-second countdown ticker
--- while this holds.
--- @return boolean
function WG.LiveCountdown()
    local pane = shownPane()
    if not pane then return false end
    local s = pane.summaryData
    if s and s.next and s.next > 0 then return true end
    return rowsLive(pane)
end

--- Move every shown countdown on to the clock: the Trade window cells of the drawn rows and the
--- strip's next expiry; nothing else is repainted (the compact cards show no countdown).
function WG.TickCountdowns()
    local pane = shownPane()
    if not pane then return end
    local compact = WG.IsCompact()
    NS.DropsStrip.Tick(pane, compact)
    if compact then return end
    if not (pane.layout and pane.layout.tradeWindow) then return end
    local now, warnAt, size = GetTime(), NS.TradeTimer.WarnAt(), NS.WindowRows.FontSize(NS.Setting("window.fontSize"))
    for _, row in ipairs(pane.rowPool.active) do
        if row.drop then paintTradeWindow(row.cells.tradeWindow, row.drop, now, warnAt, size) end
    end
end

--- The drawn pane's rows and headers, in order, for the suites: { headers, rows, entries, columns,
--- pane, card, cardDropId, empty, summary } (`cardDropId` nil while no card is open on screen;
--- `empty` the empty state's frame; `summary` the strip's MineCells.Summary, nil while nothing is tradeable).
--- @return table|nil
function WG.Drawn()
    local f = NS.Window.Frame()
    local pane = f and f.panes.group
    if not (pane and pane.rowPool) then return nil end
    if WG.IsCompact() then return NS.CompactGroup.Drawn(pane) end
    return { rows = pane.rowPool.active, headers = pane.headPool.active, entries = pane.entries,
        columns = pane.columns, pane = pane, card = pane.card, cardDropId = pane.cardDropId,
        empty = pane.emptyState, summary = pane.summaryData }
end

NS.Window.RegisterTab("group", { build = build, refresh = refresh })
