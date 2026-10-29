local _, NS = ...
-- modules/WindowHistory.lua — the History tab (design spec §10, §11.1): the drops kept across
-- sessions (modules/History.lua), under a collapsible header per encounter or run, in the Drops
-- table's row style, read-only (Clear history lives in Settings, feedback-15 spec §3).
--
-- THE COLUMNS. Item (a real item button and the name), Ilvl, Slot, Looter (in class color; ` [YOU]`
-- in gold after your own name, feedback-7 spec §2), Me,
-- Them, Trade (each as it was last judged while the drop was in the feed) and Outcome (seen, asked,
-- offered, received, traded away, expired or declined). A narrow row sheds Slot, Looter, Them, Ilvl,
-- Trade and Me, in that order (NS.WindowGroup.Fit); Item and Outcome stay. The cells are
-- modules/WindowCells.lua's composers over each entry turned into a drop-shaped record (AsDrop);
-- this file adds the Outcome cell and a header that reads days for an old group. Nothing is blank.
-- Me and Them read as the Drops table's (NS.SideCells, feedback-6 spec §1: the glyph and the
-- unsigned difference, `▲6`, or a word), but a kept entry holds no worn items, so they are the
-- verdict alone, never the gear the Drops table shows before it.
-- Them's column tooltip draws the verdict marks as NS.TipMarks' inline textures (feedback-6 spec §3).
-- A row's height, item button and text size are the Drops rows' (modules/WindowRows.lua, the
-- Window page's Layout rows; feedback-2 spec §8, FB2-9).
--
-- READ-ONLY. No row asks or offers. A right-click on a row opens its menu (core/Compat.lua's
-- ContextMenu): Mark as declined, or Clear declined; a client without the menu toggles it at once.
--
-- THE DETAIL CARD (feedback-15 spec §4, DW-Q4). A row draws the Drops rows' chevron and is indented
-- as they are (K.ROW_INDENT, the columns after WindowGroup.LEAD); a click on it (a cell, or a plain
-- click on its item button) expands NS.HistoryCard's card under it, the rows below moving down by
-- its height, the chevron up while it is open. One row at a time: the view's own `expanded`, the
-- entry itself (a kept entry's list place moves as the log grows), session-only. A row filtered out
-- or collapsed under its header takes its card with it. The compact cards expand the same way
-- (modules/CompactHistory.lua); both layouts read the one `expanded`.
--
-- THE FILTER. The tab honors View, Character, Content, the search box and Sort
-- (modules/WindowFilterBar.lua). History is account-wide, so Character (All by default since
-- feedback-13 spec §0) filters it by who saw each drop; an entry kept before that was recorded shows
-- only under All.
-- An entry's `at` is time(), so This instance and This session are the window's GetTime() marks
-- turned into time() (ctx: instanceSince, sessionSince = NS.History.SessionStart()). The tab opens
-- on View: All, Content: All and Character: All (WindowFilterBar.TAB_FIXED, feedback-13 spec §0):
-- it is a record of earlier sessions and every character, not a feed to act on.
--
-- THE COMPACT LAYOUT draws the same entries as cards: modules/CompactHistory.lua (DW-C3).
--
-- THE STRIP (feedback-15 spec §2, NS.FooterRow): the kept-history line on the left, one line, cut
-- with an ellipsis where the row starts; right to left, the tab's Sort (full layout only) and Expand
-- all / Collapse all (WH.FoldAll), each button the one footer width with the same label in both
-- layouts. Clear history left the strip for Settings › Window › Layout (feedback-15 spec §3, DW-Q3;
-- its confirmation is NS.History.AskClear).
--
-- THE UI LISTENS. HistoryChanged repaints the shown window on the next frame, the Drops rows
-- included (their Ask button reads `Traded` once a trade settles the drop). Collapsed groups are
-- session-only (NS.State.windowHistory).

NS.WindowHistory = NS.WindowHistory or {}
local WH    = NS.WindowHistory
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local WC    = NS.WindowCells
local SC    = NS.SideCells
local TM    = NS.TipMarks

local max, floor = math.max, math.floor

WH.COLUMNS = {
    { key = "item", label = L["Item"], flex = true,
      tip = { TM.Row(L["Shows"], L["the drop"]),
          TM.Hint(L["Hover its icon for the game's tooltip; shift-click links it, ctrl-click tries it on."]) } },
    { key = "ilvl", label = L["Ilvl"], width = 40, shed = 4, tip = { TM.Row(L["Shows"], L["the drop's item level"]) } },
    { key = "slot", label = L["Slot"], width = 72, shed = 1, tip = { TM.Row(L["Shows"], L["where the drop is worn"]) } },
    { key = "armorType", label = L["Type"], width = 64, shed = 0,
      tip = { TM.Row(L["Shows"], L["what kind of item it is"]),
          TM.Row(L["Values"], L["Cloth, Leather, Mail, Plate, Jewelry, Trinkets, Cloak, Weapons"]) } },
    { key = "looter", label = L["Looter"], width = 104, shed = 2, tip = { TM.Row(L["Shows"], L["who looted it, in their class color"]) } },
    { key = "me", label = L["Me"], width = 70, shed = 6,
      tip = { TM.Row(L["Shows"], L["the drop judged for you"]), TM.Row(L["As of"], L["its last judgment in the feed"]) } },
    { key = "them", label = L["Them"], width = 70, shed = 3,
      tip = { TM.Row(L["Shows"], L["the drop judged for its looter"]), TM.Row(L["As of"], L["its last judgment in the feed"]),
          TM.Row(L["Colors"], L["%s upgrade, %s sidegrade, %s downgrade"]:format(TM.Mark("upgrade"), TM.Mark("sidegrade"),
              TM.Mark("downgrade"))) } },
    { key = "trade", label = L["Trade"], width = 112, shed = 5,
      tip = { TM.Row(L["Shows"], L["the last trade estimate"]), TM.Row(L["Values"], L["Yes, No or ?, then why in a few words"]) } },
    { key = "outcome", label = L["Outcome"], width = 92,
      tip = { TM.Row(L["Shows"], L["what became of it"]),
          TM.Row(L["Values"], L["seen, asked, offered, received, traded away, expired, declined"]),
          TM.Hint(L["Right-click a row to mark it declined."]) } },
}
local GLYPH_COLS = { me = true, them = true }

-- Each outcome's word, tone and line. The tones follow the action buttons' (feedback-12 spec §0,
-- WindowCells.ActionTone): yellow while it waited on someone else (Asked, Offered), green once done
-- (Received, Traded away), gray where nothing came of it (Seen, Declined, as No action), and red where
-- it fell through (Expired, as Retry).
local OUTCOME = {
    seen       = { L["Seen"], "bad", L["shown in the feed, nothing more"] },
    asked      = { L["Asked"], "yellow", L["you asked its looter for it"] },
    offered    = { L["Offered"], "yellow", L["you offered or announced your drop"] },
    received   = { L["Received"], "good", L["a completed trade gave it to you"] },
    tradedAway = { L["Traded away"], "good", L["a completed trade passed it on"] },
    expired    = { L["Expired"], "red", L["its trade window passed"] },
    declined   = { L["Declined"], "bad", L["you marked it declined"] },
}

local NO_HISTORY = L["Drops from earlier encounters appear here."]
local NO_MATCH = L["No kept drop matches the filters. View: All, Character: All and Content: All show everything."]

-- ── the view state (session-only) ───────────────────────────────────────────────────────────

local function view()
    local v = State.windowHistory
    if not v then
        v = { collapsed = {} }
        State.windowHistory = v
    end
    return v
end

local function repaint()
    if NS.Window.IsShown() then NS.Window.Refresh() end
end

--- Expand one kept entry's detail card, or collapse it when it is the one open (feedback-15 spec
--- §4): one at a time.
--- @param e table|nil the entry
function WH.ToggleExpand(e)
    if type(e) ~= "table" then return end
    local v = view()
    if v.expanded == e then v.expanded = nil else v.expanded = e end
    repaint()
end

--- The entry whose detail card is open, or nil.
--- @return table|nil
function WH.Expanded() return view().expanded end

--- The card's context for a drawn entry (HistoryCard.Model's): the clock, your class, the kept
--- group's situation in words and the live drop it is, if any.
--- @param drop table WH.AsDrop's
--- @return table
function WH.CardContext(drop)
    local snap = NS.Gear.Snapshot()
    local g = type(drop.group) == "table" and drop.group or {}
    return { nowEpoch = time(), dateFn = date, classFile = type(snap) == "table" and snap.classFile or nil,
        situationLabel = NS.WindowFooter.SITUATION_LABEL[g.situation], liveId = NS.History.DropOf(drop.entry) }
end

--- Collapse, or open, every header the tab shows (Expand all / Collapse all, feedback-15 spec §2).
--- @param entries table|nil the drawn entries (WH.Entries')
--- @param collapse boolean
function WH.FoldAll(entries, collapse)
    NS.FooterRow.FoldAll(entries, view().collapsed, collapse)
    repaint()
end

--- Collapse or expand one kept group.
--- @param key string
--- @param collapsedNow boolean
function WH.ToggleGroup(key, collapsedNow)
    view().collapsed[key] = not collapsedNow
    repaint()
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

--- An entry as the drop record the cell composers read: { id, link, at, isMine, looter, facts,
--- me, them, trade, outcome, entry, group }.
--- @param e table a history entry
--- @param id number its place in the list (Sort's tiebreak)
--- @param group table|nil the kept group it is in (the detail card's When and where)
--- @return table
function WH.AsDrop(e, id, group)
    return {
        id = id, link = e.itemLink, at = e.at, isMine = e.isMine == true, outcome = e.outcome, entry = e, group = group,
        looter = { name = e.looter, classFile = e.class }, seenBy = e.seenBy, seenByClass = e.seenByClass,
        facts = { ilvl = e.ilvl, equipLoc = e.equipLoc, quality = e.quality },
        me = e.me, them = e.them, trade = e.trade,
    }
end

--- The Outcome cell, with its explanation and the row menu's hint.
--- @param drop table WH.AsDrop's
--- @return table cell
function WH.Outcome(drop)
    local o = OUTCOME[drop.outcome] or OUTCOME.seen
    local hint = drop.outcome == "declined" and L["Right-click to clear declined."]
        or L["Right-click to mark it declined."]
    return { text = o[1], tone = o[2], tip = { L["Outcome: %s"]:format(o[1]), TM.Row(L["Means"], o[3]), TM.Hint(hint) } }
end

--- The Them verdict alone (WH.ThemCell is the merged cell the table and the card draw): as the
--- Drops table says it, except that a looter whose gear was never read says so plainly (the inspect
--- is long over).
--- @param drop table
--- @return table cell
function WH.ThemVerdict(drop)
    if drop.isMine or type(drop.them) == "table" then return WC.Them(drop) end
    local who = WC.ShortName(drop.looter.name)
    return { text = "?", tone = "muted", verdict = "unknown",
        tip = { L["For %s: Unknown"]:format(who), TM.Row(L["Their gear"], L["not read while it was in the feed"]) } }
end

--- How long ago, in words: `40s`, `1h 59m`, then `1 day`, `3 days`.
--- @param seconds number
--- @return string
function WH.Ago(seconds)
    local s = max(0, tonumber(seconds) or 0)
    if s < 86400 then return L["%s ago"]:format(WC.Duration(s)) end
    local days = floor(s / 86400)
    return days == 1 and L["1 day ago"] or L["%d days ago"]:format(days)
end

--- A kept group's header: `Instance · Boss · Difficulty · 2 days ago · 4 drops · Recorder` (the
--- place and the character that saw it, class-colored, feedback-3 spec §4; a group kept before them
--- reads `Label · Situation`; `... · 4 drops · 3 shown` while the filter hides some, feedback-2 spec
--- §0), and its tooltip its facts as rows (NS.WindowCells.HeaderFacts) and each hidden drop.
--- @param group table { label, kind, situation, at, instance, difficulty, seenBy, seenByClass, roster }
--- @param shown number
--- @param now number time()
--- @param situationLabel string|nil
--- @param collapsed boolean
--- @param hidden table|nil { { drop, why }, ... }
--- @param filter table|nil the tab's filter state
--- @return table { text, tip }
function WH.Header(group, shown, now, situationLabel, collapsed, hidden, filter)
    local parts, who = WC.Place(group, situationLabel)
    local when = (type(group.at) == "number" and type(now) == "number") and WH.Ago(now - group.at) or nil
    parts[#parts + 1] = when
    parts[#parts + 1] = WC.DropCount(shown, hidden)
    parts[#parts + 1] = who
    local text = table.concat(parts, " · ")
    if collapsed then text = text .. " " .. L["(collapsed)"] end
    local rows = WC.HeaderFacts(group, situationLabel, when, shown, hidden)
    return { text = text, tip = WC.HeaderTip(tostring(group.label or "?"), rows,
        L["the history, kept across sessions"], hidden, filter, collapsed) }
end

local function visibleDrops(group, ctx, base)
    local shown, hidden = {}, {}
    for i, e in ipairs(group.drops or {}) do
        local d = WH.AsDrop(e, base + i, group)
        if ctx.matches(d) then
            shown[#shown + 1] = d
        else
            hidden[#hidden + 1] = { drop = d, why = ctx.hiddenBy and ctx.hiddenBy(d) or "filter" }
        end
    end
    table.sort(shown, ctx.compare)
    return shown, hidden
end

-- One group's header, then its shown drops unless it is collapsed.
local function appendGroup(out, g, drops, hidden, filter, c)
    out[#out + 1] = { kind = "header", group = g, count = #drops, total = #drops + #hidden,
        hidden = hidden, filter = filter, collapsed = c }
    if c then return end
    for _, d in ipairs(drops) do out[#out + 1] = { kind = "drop", drop = d } end
end

--- The tab's entries, top to bottom: { kind = "header", group, count, total, hidden, filter,
--- collapsed } (as NS.WindowCells.Entries') and
--- { kind = "drop", drop }. Groups newest first (oldest first under Sort: Oldest); a group with no
--- entry passing the filter keeps an open header with count 0 while the View filter hid them; it is
--- left out when Search, Content or the Character filter did (WC.KeepsHeader; entries with no
--- recorder too, feedback-12 spec §1). A group never toggled is open
--- when it is the first shown.
--- @param groups table NS.History.Groups(), oldest first
--- @param ctx table { matches = fn(drop), compare = fn(a, b), filter = { sort } }
--- @param state table|nil { collapsed }
--- @return table
function WH.Entries(groups, ctx, state)
    local collapsed = (state or {}).collapsed or {}
    local oldest = type(ctx.filter) == "table" and ctx.filter.sort == "oldest"
    local from, to, step = #groups, 1, -1
    if oldest then from, to, step = 1, #groups, 1 end
    local out, first, base = {}, true, 0
    for i = from, to, step do
        local g = groups[i]
        local drops, hidden = visibleDrops(g, ctx, base)
        base = base + #(g.drops or {})
        if #drops > 0 then
            local c = collapsed[g.key]
            if c == nil then c = not first end
            first = false
            appendGroup(out, g, drops, hidden, ctx.filter, c)
        elseif WC.KeepsHeader(0, hidden) then
            appendGroup(out, g, drops, hidden, ctx.filter, false)
        end
    end
    return out
end

--- The tab's filter context: the filter bar's state for `history`, with This instance and This
--- session as time() marks.
--- @param tc table Window.TabContext("history")
--- @param nowEpoch number time()
--- @param nowClock number GetTime()
--- @param sessionSince number|nil
--- @return table { filter, matches, hiddenBy, compare }
function WH.Context(tc, nowEpoch, nowClock, sessionSince)
    local FB = NS.WindowFilterBar
    local since = tc.ctx and tc.ctx.instanceSince
    local ctx = { sessionSince = sessionSince, current = tc.ctx and tc.ctx.current,
        instanceSince = type(since) == "number" and nowEpoch - (nowClock - since) or nil }
    return {
        filter = tc.filter,
        matches = function(d) return FB.Matches(d, tc.filter, ctx, tc.honors) end,
        hiddenBy = function(d) return FB.HiddenBy(d, tc.filter, ctx, tc.honors) end,
        compare = FB.Comparator(tc.filter.sort),
    }
end

-- ── painting ────────────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function tipOf(frame) return unpack(frame.tipLines or {}) end

--- A row's menu: Mark as declined, or Clear declined. Without the client's menu it acts at once.
--- @param e table the history entry
--- @param owner table|nil
function WH.OpenMenu(e, owner)
    if type(e) ~= "table" then return end
    local on = e.outcome ~= "declined"
    local text = on and L["Mark as declined"] or L["Clear declined"]
    local act = function() NS.History.SetEntryDeclined(e, on) end
    if not NS.Compat.ContextMenu(owner, { { text = text, fn = act } }) then act() end
end

-- The row's own mouse-up opens the menu (its left click is OnClick); a cell's is its row's click.
local function onMouseUp(self, button)
    local row = self.row or self
    if button == "RightButton" then WH.OpenMenu(row.entry, row) end
end

local function cellMouseUp(self, button)
    if button == "LeftButton" then return WH.ToggleExpand(self.row.entry) end
    onMouseUp(self, button)
end

--- A kept entry's item button: shift-click links and ctrl-click tries on (WindowGroup.OnItemClick);
--- a plain click expands the entry's card (`self.entry`), as a row click does.
--- @param self table the item button
function WH.OnItemClick(self)
    if IsShiftKeyDown() or IsControlKeyDown() then return NS.WindowGroup.OnItemClick(self) end
    WH.ToggleExpand(self.entry)
end

local function textCell(row, key)
    local f = CreateFrame("Frame", nil, row)
    f.key, f.row = key, row
    f:SetScript("OnMouseUp", cellMouseUp)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    NS.Skin.Font(f.text)   -- the skin's face; the color is the cell's tone, set at paint time
    NS.Window.AttachTooltip(f, function() return tipOf(f) end, "row")
    return f
end

local function glyphCell(row, key)
    local f = textCell(row, key)
    f.glyph = f:CreateFontString(nil, "OVERLAY")
    NS.SkinMono(f.glyph, 12)
    f.glyph:SetPoint("LEFT", f, "LEFT", 0, 0)   -- the arrow before the number (feedback-4 spec §0)
    return f
end

local function itemCell(row)
    local f = textCell(row, "item")
    f.button = NS.WindowGroup.ItemButton(f, K.ROW_ICON)
    f.button:SetScript("OnClick", WH.OnItemClick)
    NS.WindowGroup.ItemHover(f, f.button)
    f.showItem = true   -- the real item tooltip on the name too (DW-80)
    f.button:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.button, "RIGHT", 5, 0)
    return f
end

local function newRow(content)
    local row = CreateFrame("Button", nil, content)
    row:SetHeight(NS.WindowRows.ROW_H)
    row.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.selected = row:CreateTexture(nil, "BACKGROUND")
    row.selected:SetAllPoints(row)
    NS.WindowGroup.PaintRowWashes(row)   -- the Drops rows' stripe and expanded wash, from the skin
    row.chevron = NS.WindowGroup.RowChevron(row)   -- the Drops rows' expand indicator (feedback-15 spec §4)
    row.chevron:SetPoint("LEFT", row, "LEFT", K.CHEVRON_X, 0)
    row.cells = {}
    for _, col in ipairs(WH.COLUMNS) do
        local make = (col.key == "item" and itemCell) or (GLYPH_COLS[col.key] and glyphCell) or textCell
        row.cells[col.key] = make(row, col.key)
    end
    NS.WindowRows.MarkedCell(row.cells.looter)   -- ` [YOU]` after your own name (feedback-7 spec §2)
    row:SetScript("OnMouseUp", onMouseUp)
    row:SetScript("OnClick", function(self) WH.ToggleExpand(self.entry) end)
    return row
end

-- A kept group's header: the Drops tab's own button (WindowGroup.NewHeader), toggling this tab's.
local function newHeader(content)
    local h = NS.WindowGroup.NewHeader(content)
    h:SetScript("OnClick", function(self) WH.ToggleGroup(self.groupKey, self.collapsed) end)
    return h
end

local function paintText(f, c)
    f.text:SetText(c.text)
    setTone(f.text, c.tone)
    f.tipLines = c.tip
    if f.glyph then
        f.glyph:SetText(c.glyph or "")
        setTone(f.glyph, c.tone)
        NS.WindowGroup.PlaceGlyph(f, c.glyph)
    end
end

local TEXT_INSET = { item = K.ROW_ICON + 5, me = 16, them = 16 }

local function placeCells(row, layout, height)
    for key, f in pairs(row.cells) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", NS.WindowGroup.CHEVRON_LEAD + at.x, 0)   -- after the chevron
            f:SetSize(at.w, height)
            f.text:SetWidth(max(at.w - (TEXT_INSET[key] or 0), 10))
        end
    end
end

local function tone(fs, r, g, b)
    if r then fs:SetTextColor(r, g, b) end
end

local function qualityColor(q)
    return NS.QualityColor(q)   -- the skin's q.* token, else the client's color (E4)
end

--- The Me cell: the verdict alone, as the Drops table words it (NS.SideCells.Merge with no gear);
--- the tooltip grid's `You` in your class color (the gear snapshot's, NS.Gear), as on Drops.
--- @param drop table
--- @return table cell
function WH.MeCell(drop)
    local snap = NS.Gear.Snapshot()
    return SC.Merge(WC.Me(drop, type(snap) == "table" and snap.classFile or nil))
end

--- The Them cell: WH.ThemVerdict's verdict alone, as the Drops table words it.
--- @param drop table
--- @return table cell
function WH.ThemCell(drop) return SC.Merge(WH.ThemVerdict(drop)) end

local function tradeCell(drop) return WC.TradeDrawn(WC.Trade(drop)) end   -- `No Bonus roll` (feedback-22)

local SIMPLE = { ilvl = WC.Ilvl, slot = WC.Slot, armorType = WC.ArmorType, me = WH.MeCell, trade = tradeCell,
    them = WH.ThemCell, outcome = WH.Outcome }

local function paintRow(row, drop, layout, metrics)
    row.entry = drop.entry
    local open = view().expanded == drop.entry
    row.selected:SetShown(open)
    NS.WindowGroup.PaintChevron(row.chevron, open)
    row:SetHeight(metrics.height)
    placeCells(row, layout, metrics.height)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize)
    NS.WindowRows.ApplyRowIcon(row, metrics.icon)
    local cells = row.cells
    paintText(cells.item, WC.Item(drop))
    tone(cells.item.text, qualityColor(drop.facts.quality))
    NS.WindowGroup.SetItem(cells.item.button, drop.link)
    cells.item.button.entry = drop.entry
    cells.item.tipLines = nil
    for key, fn in pairs(SIMPLE) do paintText(cells[key], fn(drop)) end
    local lc = WC.Looter(drop)
    paintText(cells.looter, lc)
    tone(cells.looter.text, NS.Compat.ClassColor(lc.classFile))
    NS.WindowRows.PaintMark(cells.looter, lc.you, layout.looter)
end

local function paintHeader(h, e, now)
    local g = e.group
    local hd = WH.Header(g, e.count, now, NS.WindowFooter.SITUATION_LABEL[g.situation], e.collapsed, e.hidden,
        e.filter)
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
    for _, col in ipairs(WH.COLUMNS) do
        local f = CreateFrame("Frame", nil, head)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        NS.Skin.Text(f.text, "list.header.text")   -- gold, as Loot History's (feedback-4 spec §4)
        f.text:SetText(col.label)
        NS.Window.AttachTooltip(f, function() return col.label, unpack(col.tip) end)
        head.labels[col.key] = f
    end
    pane.colHead = head
end

local function buildStrip(pane)
    local strip = CreateFrame("Frame", nil, pane)
    strip:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(K.STRIP_H)
    strip.line = strip:CreateTexture(nil, "ARTWORK")
    NS.SkinPaint(strip.line, function(t) t:SetColorTexture(NS.SkinColor("dw.rule")) end)
    strip.line:SetHeight(1)
    strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
    strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
    strip.info = strip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    NS.Skin.Text(strip.info, "disabled")
    strip.info:SetJustifyH("LEFT")
    strip.info:SetWordWrap(false)   -- one line: the game cuts it with an ellipsis when narrow
    local FR = NS.FooterRow
    strip.fold = FR.BuildFold(strip, function(collapse) WH.FoldAll(pane.entries, collapse) end)
    pane.strip = strip
    pane.sortHost = strip   -- the full layout's Sort sits at its right edge (feedback-10 spec §3)
end

local function build(pane)
    buildHeads(pane)
    buildStrip(pane)
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane.colHead, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, K.STRIP_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    pane.scroll, pane.content = scroll, content
    local bar = rawget(scroll, "ScrollBar")
    if bar then NS.Skin.ScrollBar(bar) end   -- the skin's corridor and knob (D2)
    pane.rowPool, pane.headPool = NS.Pool.New(), NS.Pool.New()
    pane.card = NS.HistoryCard.Build(content)
    pane.entries = {}
end

local function paintHeads(pane, layout)
    for key, f in pairs(pane.colHead.labels) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", pane.colHead, "LEFT", NS.WindowGroup.LEAD + at.x, 0)   -- over their cells
            f:SetSize(at.w, K.COLHEAD_H)
        end
    end
end

local function rowWidth(pane)
    local w = pane:GetWidth()
    if not w or w <= 0 then
        local f = NS.Window.Frame()
        w = (f and f:GetWidth() or K.WIDTH) - 2 * K.INSET
    end
    return w - K.SCROLL_W
end

-- `x` indents a row and its card (K.ROW_INDENT, as on Drops); a header takes the full width.
local function place(frame, content, y, width, x)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", x or 0, -y)
    frame:SetWidth(width - (x or 0))
end

-- The open entry's card under its row, indented with it; answers the height it takes.
local function drawCard(pane, drop, y, width)
    place(pane.card, pane.content, y, width, K.ROW_INDENT)
    local h = NS.HistoryCard.Paint(pane.card, drop, width - K.ROW_INDENT, WH.CardContext(drop))
    pane.card:Show()
    pane.cardEntry = drop.entry
    return h
end

local function drawEntries(pane, entries, layout, width, now)
    local y, metrics = 0, NS.WindowRows.Metrics()
    local expanded = view().expanded
    for i, e in ipairs(entries) do
        local pool, make, h = pane.rowPool, newRow, metrics.height
        if e.kind == "header" then pool, make, h = pane.headPool, newHeader, K.GROUP_H end
        local f = NS.Pool.Acquire(pool, function() return make(pane.content) end)
        if e.kind == "header" then
            place(f, pane.content, y, width)
            paintHeader(f, e, now)
        else
            place(f, pane.content, y, width, K.ROW_INDENT)
            f.stripe:SetShown(i % 2 == 0)
            paintRow(f, e.drop, layout, metrics)
        end
        y = y + h
        if e.kind ~= "header" and e.drop.entry == expanded then y = y + drawCard(pane, e.drop, y, width) end
    end
    pane.content:SetSize(width, max(y, 1))
end

-- The strip's row, right to left (feedback-15 spec §2, §3): full `Sort · Expand/Collapse`, compact
-- `Expand/Collapse` as its mark alone (feedback-16); the tab's Sort is anchored in its slot by
-- NS.WindowFooter.AnchorSort. Placed again only when the layout changes, so a repaint builds no
-- table and re-anchors nothing.
local function placeStrip(strip, compact)
    if strip.dwPlacedCompact == compact then return end
    strip.dwPlacedCompact = compact
    local FR, WF = NS.FooterRow, NS.WindowFooter
    local w = FR.Width(compact)
    FR.SetCompact(strip.fold, compact)
    local row = { { key = "fold", w = w } }
    if not compact then table.insert(row, 1, { key = "sort", w = WF.SORT_W }) end
    local slots = FR.Slots(row, FR.GAP, compact and 0 or WF.SORT_INSET)
    FR.Place(strip, strip.fold, slots.fold)
    FR.PlaceInfo(strip, strip.info, slots.left)
end

local function paintStrip(pane, groups, entries, compact)
    local st = NS.History.Stats()
    local strip = pane.strip
    strip.info:SetText(NS.HistoryRetention.FooterText(#groups, st.drops, st.days))
    placeStrip(strip, compact)
    NS.FooterRow.PaintFold(strip.fold, entries)
end

local function paintEmpty(pane, entries, groups, compact)
    local none = #entries == 0
    pane.placeholder:SetShown(none)
    if none then pane.placeholder:SetText(#groups == 0 and NO_HISTORY or NO_MATCH) end
    pane.colHead:SetShown(not (none or compact))
end

local function drawTable(pane, entries)
    local width = rowWidth(pane)
    local layout, kept = NS.WindowGroup.Layout(WH.COLUMNS, width - NS.WindowGroup.LEAD)   -- after the indent and chevron
    paintHeads(pane, layout)
    drawEntries(pane, entries, layout, width, time())
    pane.columns = kept
end

-- The table, or (compact) the cards over the same entries (modules/CompactHistory.lua, DW-C3).
local function refresh(pane, tc)
    local groups = NS.History.Groups()
    local ctx = WH.Context(tc, time(), GetTime(), NS.History.SessionStart())
    local entries = WH.Entries(groups, ctx, view())
    local compact = NS.WindowGroup.IsCompact()
    NS.Pool.ReleaseAll(pane.rowPool)
    NS.Pool.ReleaseAll(pane.headPool)
    pane.card:Hide()
    pane.cardEntry = nil
    pane.scroll:SetShown(not compact)
    if not compact then drawTable(pane, entries) end
    pane.entries = entries
    paintStrip(pane, groups, entries, compact)
    NS.CompactHistory.Refresh(pane, entries, compact)
    paintEmpty(pane, entries, groups, compact)
end

--- The drawn pane, for the suites: { rows, headers, entries, columns, pane, strip, card, cardEntry }
--- or nil (`cardEntry` nil while no card is open on screen).
--- @return table|nil
function WH.Drawn()
    local f = NS.Window.Frame()
    local pane = f and f.panes.history
    if not (pane and pane.rowPool) then return nil end
    if NS.WindowGroup.IsCompact() then return NS.CompactHistory.Drawn(pane) end
    return { rows = pane.rowPool.active, headers = pane.headPool.active, entries = pane.entries,
        columns = pane.columns, pane = pane, strip = pane.strip, card = pane.card, cardEntry = pane.cardEntry }
end

NS.Window.RegisterTab("history", { build = build, refresh = refresh })

-- ── the bus ─────────────────────────────────────────────────────────────────────────────────

-- HistoryChanged repaints the shown window once on the next frame, however many arrive, through
-- the window's own coalesced repaint: a DropUpdated that also changed the history costs one pass.
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.HISTORY_CHANGED, function()
        NS.WindowFilterBar.InvalidateChars()
        NS.Window.ScheduleRepaint()
    end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
