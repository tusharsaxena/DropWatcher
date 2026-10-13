local _, NS = ...
-- modules/WindowHistory.lua — the History tab (design spec §10, §11.1): the drops kept across
-- sessions (modules/History.lua), under a collapsible header per encounter or run, in the Group
-- drops table's row style, read-only, with Clear history behind a confirmation.
--
-- THE COLUMNS. Item (a real item button and the name), Ilvl, Slot, Looter (in class color), Me,
-- Them, Trade (each as it was last judged while the drop was in the feed) and Outcome (seen, asked,
-- offered, received, traded away, expired or declined). A narrow row sheds Slot, Looter, Them, Ilvl,
-- Trade and Me, in that order (NS.WindowGroup.Fit); Item and Outcome stay. The cells are
-- modules/WindowCells.lua's composers over each entry turned into a drop-shaped record (AsDrop);
-- this file adds the Outcome cell and a header that reads days for an old group. Nothing is blank.
-- A row's height, item button and text size are the Group drops rows' (modules/WindowRows.lua, the
-- Window page's Layout rows; feedback-2 spec §8, FB2-9).
--
-- READ-ONLY. No row asks, offers or expands. A right-click on a row opens its menu (core/Compat.lua's
-- ContextMenu): Mark as declined, or Clear declined; a client without the menu toggles it at once.
--
-- THE FILTER. The tab honors View, Character, Content, the search box and Sort
-- (modules/WindowFilterBar.lua). History is account-wide, so Character (Current by default, feedback-2
-- spec §4) filters it by who saw each drop; an entry kept before that was recorded shows only under All.
-- An entry's `at` is time(), so This instance and This session are the window's GetTime() marks
-- turned into time() (ctx: instanceSince, sessionSince = NS.History.SessionStart()). The tab opens
-- on View: All and Content: All the first time it is shown in a session: it is a record of earlier
-- sessions, not a feed to act on.
--
-- THE COMPACT LAYOUT draws the same entries as cards: modules/CompactHistory.lua (DW-C3).
--
-- THE UI LISTENS. HistoryChanged repaints the shown window on the next frame, the Group drops rows
-- included (their Ask button reads `Traded` once a trade settles the drop). Collapsed groups are
-- session-only (NS.State.windowHistory).

NS.WindowHistory = NS.WindowHistory or {}
local WH    = NS.WindowHistory
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local WC    = NS.WindowCells

local max, floor = math.max, math.floor

WH.COLUMNS = {
    { key = "item", label = L["Item"], flex = true,
      tip = L["The drop. Hover its icon for the game's tooltip; shift-click links it in chat, ctrl-click tries it on."] },
    { key = "ilvl", label = L["Ilvl"], width = 40, shed = 4, tip = L["The drop's item level."] },
    { key = "slot", label = L["Slot"], width = 72, shed = 1, tip = L["Where the drop is worn."] },
    { key = "looter", label = L["Looter"], width = 104, shed = 2, tip = L["Who looted it, in their class color."] },
    { key = "me", label = L["Me"], width = 70, shed = 6,
      tip = L["The drop judged for you, as it was last judged while it was in the feed."] },
    { key = "them", label = L["Them"], width = 70, shed = 3,
      tip = L["The drop judged for its looter, as it was last judged. In the same colors as Me: ▲ green, ≈ yellow, ▽ red."] },
    { key = "trade", label = L["Trade"], width = 70, shed = 5, tip = L["The last trade estimate: Yes, Likely, Unknown or No."] },
    { key = "outcome", label = L["Outcome"], width = 92,
      tip = L["What became of it: seen, asked, offered, received, traded away, expired or declined. Right-click a row to mark it declined."] },
}
local GLYPH_COLS = { me = true, them = true }

local OUTCOME = {
    seen       = { L["Seen"], "muted", L["Shown in the feed; nothing more happened."] },
    asked      = { L["Asked"], "plain", L["You asked its looter for it."] },
    offered    = { L["Offered"], "plain", L["You offered or announced your drop."] },
    received   = { L["Received"], "good", L["A completed trade gave you this item."] },
    tradedAway = { L["Traded away"], "good", L["A completed trade passed your drop on."] },
    expired    = { L["Expired"], "bad", L["Its trade window passed."] },
    declined   = { L["Declined"], "muted", L["Marked declined by you."] },
}

local NO_HISTORY = L["Drops from earlier encounters appear here."]
local NO_MATCH = L["No kept drop matches the filters. View: All, Character: All and Content: All show everything."]
local CLEAR_POPUP = "DROPWATCHER_CLEAR_HISTORY"

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

--- Collapse or expand one kept group.
--- @param key string
--- @param collapsedNow boolean
function WH.ToggleGroup(key, collapsedNow)
    view().collapsed[key] = not collapsedNow
    repaint()
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

--- An entry as the drop record the cell composers read: { id, link, at, isMine, looter, facts,
--- me, them, trade, outcome, entry }.
--- @param e table a history entry
--- @param id number its place in the list (Sort's tiebreak)
--- @return table
function WH.AsDrop(e, id)
    return {
        id = id, link = e.itemLink, at = e.at, isMine = e.isMine == true, outcome = e.outcome, entry = e,
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
    return { text = o[1], tone = o[2], tip = { L["Outcome: %s"]:format(o[1]), o[3], hint } }
end

--- The Them column: as the Group drops table says it, except that a looter whose gear was never
--- read says so plainly (the inspect is long over).
--- @param drop table
--- @return table cell
function WH.Them(drop)
    if drop.isMine or type(drop.them) == "table" then return WC.Them(drop) end
    local who = WC.ShortName(drop.looter.name)
    return { text = "?", tone = "muted", verdict = "unknown",
        tip = { L["For %s: Unknown"]:format(who), L["Their gear was not read while the drop was in the feed."] } }
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
--- §0), and its tooltip naming the kept party on one line and each hidden drop.
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
    if type(group.at) == "number" and type(now) == "number" then parts[#parts + 1] = WH.Ago(now - group.at) end
    parts[#parts + 1] = WC.DropCount(shown, hidden)
    parts[#parts + 1] = who
    local text = table.concat(parts, " · ")
    if collapsed then text = text .. " " .. L["(collapsed)"] end
    return { text = text, tip = WC.HeaderTip(tostring(group.label or "?"), L["Kept in the history across sessions."],
        hidden, filter, collapsed, group.roster) }
end

local function visibleDrops(group, ctx, base)
    local shown, hidden = {}, {}
    for i, e in ipairs(group.drops or {}) do
        local d = WH.AsDrop(e, base + i)
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
--- entry passing the filter keeps an open header with count 0 while the View filter hid them, or
--- Character hid entries with no recorder (kept before the Character dropdown); it is left out
--- when Search, Content or a Character choice did (WC.KeepsHeader). A group never toggled is open
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

local function onMouseUp(self, button)
    local row = self.row or self
    if button == "RightButton" then WH.OpenMenu(row.entry, row) end
end

local function textCell(row, key)
    local f = CreateFrame("Frame", nil, row)
    f.key, f.row = key, row
    f:SetScript("OnMouseUp", onMouseUp)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    NS.Window.AttachTooltip(f, function() return tipOf(f) end, "row")
    return f
end

local function glyphCell(row, key)
    local f = textCell(row, key)
    f.glyph = f:CreateFontString(nil, "OVERLAY")
    f.glyph:SetFont(C.FONT_MONO, 12, "")
    f.glyph:SetPoint("LEFT", f, "LEFT", 0, 0)   -- the arrow before the number (feedback-4 spec §0)
    return f
end

local function itemCell(row)
    local f = textCell(row, "item")
    f.button = NS.WindowGroup.ItemButton(f, K.ROW_ICON)
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
    row.stripe:SetColorTexture(1, 1, 1, 0.03)
    row.cells = {}
    for _, col in ipairs(WH.COLUMNS) do
        local make = (col.key == "item" and itemCell) or (GLYPH_COLS[col.key] and glyphCell) or textCell
        row.cells[col.key] = make(row, col.key)
    end
    row:SetScript("OnMouseUp", onMouseUp)
    return row
end

-- A kept group's header: the Group drops tab's own button (WindowGroup.NewHeader), toggling this tab's.
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
            f:SetPoint("LEFT", row, "LEFT", at.x, 0)
            f:SetSize(at.w, height)
            f.text:SetWidth(max(at.w - (TEXT_INSET[key] or 0), 10))
        end
    end
end

local function tone(fs, r, g, b)
    if r then fs:SetTextColor(r, g, b) end
end

local function qualityColor(q)
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then return qc.r, qc.g, qc.b end
end

local SIMPLE = { ilvl = WC.Ilvl, slot = WC.Slot, me = WC.Me, trade = WC.Trade, them = WH.Them, outcome = WH.Outcome }

local function paintRow(row, drop, layout, metrics)
    row.entry = drop.entry
    row:SetHeight(metrics.height)
    placeCells(row, layout, metrics.height)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize)
    NS.WindowRows.ApplyRowIcon(row, metrics.icon)
    local cells = row.cells
    paintText(cells.item, WC.Item(drop))
    tone(cells.item.text, qualityColor(drop.facts.quality))
    NS.WindowGroup.SetItem(cells.item.button, drop.link)
    cells.item.tipLines = nil
    for key, fn in pairs(SIMPLE) do paintText(cells[key], fn(drop)) end
    local lc = WC.Looter(drop)
    paintText(cells.looter, lc)
    tone(cells.looter.text, NS.Compat.ClassColor(lc.classFile))
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

-- ── Clear history ───────────────────────────────────────────────────────────────────────────

local function ensurePopup()
    if StaticPopupDialogs[CLEAR_POPUP] then return end
    StaticPopupDialogs[CLEAR_POPUP] = {
        text = L["Clear the drop history on every character? This cannot be undone."],
        button1 = YES or "Yes", button2 = NO or "No",
        timeout = 0, whileDead = true, hideOnEscape = true,
        preferredIndex = 3,   -- clear of the slots Blizzard's own popups take first
        OnAccept = function() NS.History.Clear() end,
    }
end

--- Clear history's button: asks first (a StaticPopup); the history is emptied only on Yes.
function WH.AskClear()
    ensurePopup()
    StaticPopup_Show(CLEAR_POPUP)
end

WH.CLEAR_POPUP = CLEAR_POPUP

local function clearTip()
    return L["Clear history"], L["Empty the drop history on every character, after a confirmation."]
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
        f.text:SetTextColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
        f.text:SetText(col.label)
        NS.Window.AttachTooltip(f, function() return col.label, col.tip end)
        head.labels[col.key] = f
    end
    pane.colHead = head
end

local function buildStrip(pane)
    local strip = CreateFrame("Frame", nil, pane)
    strip:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(K.MINE_FOOT_H)
    strip.line = strip:CreateTexture(nil, "ARTWORK")
    strip.line:SetColorTexture(1, 1, 1, 0.1)
    strip.line:SetHeight(1)
    strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
    strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
    strip.info = strip:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    strip.info:SetPoint("LEFT", strip, "LEFT", 2, 0)
    strip.clear = NS.Window.TextButton(strip, K.CLEAR_W, "clear", L["Clear history"], WH.AskClear)
    strip.clear:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
    NS.Window.AttachTooltip(strip.clear, clearTip)
    pane.strip = strip
end

local function build(pane)
    buildHeads(pane)
    buildStrip(pane)
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane.colHead, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, K.MINE_FOOT_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    pane.scroll, pane.content = scroll, content
    pane.rowPool, pane.headPool = NS.Pool.New(), NS.Pool.New()
    pane.entries = {}
    -- Opened for the first time this session: View: All and Content: All, since the tab is a
    -- record of earlier sessions, not a feed to act on.
    local v = view()
    if not v.seeded then
        v.seeded = true
        local st = NS.WindowFilterBar.State("history")
        st.view, st.content = {}, "all"
    end
end

local function paintHeads(pane, layout)
    for key, f in pairs(pane.colHead.labels) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", pane.colHead, "LEFT", at.x, 0)
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

local function drawEntries(pane, entries, layout, width, now)
    local y, metrics = 0, NS.WindowRows.Metrics()
    for i, e in ipairs(entries) do
        local pool, make, h = pane.rowPool, newRow, metrics.height
        if e.kind == "header" then pool, make, h = pane.headPool, newHeader, K.GROUP_H end
        local f = NS.Pool.Acquire(pool, function() return make(pane.content) end)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", pane.content, "TOPLEFT", 0, -y)
        f:SetWidth(width)
        if e.kind == "header" then
            paintHeader(f, e, now)
        else
            f.stripe:SetShown(i % 2 == 0)
            paintRow(f, e.drop, layout, metrics)
        end
        y = y + h
    end
    pane.content:SetSize(width, max(y, 1))
end

local function paintStrip(pane, groups)
    local st = NS.History.Stats()
    pane.strip.info:SetText(NS.HistoryRetention.FooterText(#groups, st.drops, st.days))
    pane.strip.clear:SetEnabled(#groups > 0)
    pane.strip.clear:SetAlpha(#groups > 0 and 1 or 0.5)
end

local function paintEmpty(pane, entries, groups, compact)
    local none = #entries == 0
    pane.placeholder:SetShown(none)
    if none then pane.placeholder:SetText(#groups == 0 and NO_HISTORY or NO_MATCH) end
    pane.colHead:SetShown(not (none or compact))
end

local function drawTable(pane, entries)
    local width = rowWidth(pane)
    local layout, kept = NS.WindowGroup.Layout(WH.COLUMNS, width)
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
    pane.scroll:SetShown(not compact)
    if not compact then drawTable(pane, entries) end
    pane.entries = entries
    paintStrip(pane, groups)
    NS.CompactHistory.Refresh(pane, entries, compact)
    paintEmpty(pane, entries, groups, compact)
end

--- The drawn pane, for the suites: { rows, headers, entries, columns, pane, strip } or nil.
--- @return table|nil
function WH.Drawn()
    local f = NS.Window.Frame()
    local pane = f and f.panes.history
    if not (pane and pane.rowPool) then return nil end
    if NS.WindowGroup.IsCompact() then return NS.CompactHistory.Drawn(pane) end
    return { rows = pane.rowPool.active, headers = pane.headPool.active, entries = pane.entries,
        columns = pane.columns, pane = pane, strip = pane.strip }
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
