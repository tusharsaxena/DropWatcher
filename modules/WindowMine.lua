local _, NS = ...
-- modules/WindowMine.lua — the My drops tab (design spec §11.4, board 04): your own drops, one row
-- each, with the time left to trade them and who each would help.
--
-- THE COLUMNS. Item (a real item button and the name), Ilvl, For me (the verdict, with `keep?`
-- under an upgrade), Trade window (the countdown over its bar, why it is not tradeable, or `No limit`
-- for a bind-on-equip drop), Best candidates (the top three upgrades, or why there are none) and
-- Actions (Offer and Announce while it may be traded; a dash and Hide when it cannot). Under the
-- rows, a summary strip: how many are tradeable, the next expiry and Post my tradeables. What every
-- cell says, and its reason tooltip, is modules/MineCells.lua's (pure); this file is the frame edge
-- that paints it. Nothing is ever blank.
--
-- THE ROWS. Pooled through LibKa0s-Pool-1.0 (NS.Pool), released and re-acquired in order on every
-- repaint. The entries (pure): your own drops in the tab's feed that pass the tab's filter
-- (Window.TabContext: Content, search and Sort) and were not hidden, in the tab's order. They sit
-- under the same collapsible header per run or encounter as the other two tabs (M10 review,
-- FB2-10; WC.Header: the place, the age, `n drops · m shown`, the party in class color), through
-- NS.WindowCells.Entries with only your drops counted: newest group first, every group open until
-- the player collapses it (an older run's drops are the ones whose trade windows end first), and a
-- drop in no group listed last, so none is lost. The summary counts every entry, collapsed or not.
-- A row is the Window page's row height plus the room its countdown bar needs, in the Group drops
-- rows' text size (modules/WindowRows.lua; FB2-9). The compact layout draws the same rows as cards
-- (modules/CompactMine.lua, DW-C3).
--
-- THE UI LISTENS. Window.lua repaints it on the bus (TradeTimerTick moves the countdowns each second
-- while a timer is live) and on its footer ticker while the tab is shown. It reads the feed
-- (NS.LootFeed.Drops), the ask states (NS.Asks.StateOf) and the warning threshold
-- (NS.TradeTimer.WarnAt), all read-only. Offer opens the Offer panel (modules/OfferPanel.lua);
-- Announce and Post my tradeables go through the host handlers NS.PressAnnounce and
-- NS.PostTradeables (core/DropWatcher.lua); Hide is the tab's own, session-only.

NS.WindowMine = NS.WindowMine or {}
local WM    = NS.WindowMine
local K     = NS.Constants.WINDOW
local C     = NS.Constants
local L     = NS.L
local State = NS.State
local MC    = NS.MineCells

local max = math.max

WM.COLUMNS = {
    { key = "item", label = L["Item"], flex = true,
      tip = L["Your drop. Hover its icon for the game's tooltip; shift-click links it in chat, ctrl-click tries it on."] },
    { key = "ilvl", label = L["Ilvl"], width = 40, shed = 2, tip = L["The drop's item level."] },
    { key = "forMe", label = L["For me"], width = 64, shed = 3,
      tip = L["The drop judged for you. An upgrade asks whether to keep it, and nobody is offered it by default."] },
    { key = "trade", label = L["Trade window"], width = 124, shed = 4,
      tip = L["The time left to trade it: exact once read from the item, estimated before. At 10 minutes it warns."] },
    { key = "best", label = L["Best candidates"], width = 190, shed = 1,
      tip = L["The group members it would help most, by their item-level gain."] },
    { key = "actions", label = L["Actions"], width = K.OFFER_BTN_W + K.ANNOUNCE_W + 6,
      tip = L["Offer opens who could use it. Announce posts your template to the group."] },
}

-- A narrow row sheds Best candidates, Ilvl, For me, then Trade window (`shed`, NS.WindowGroup.Fit);
-- the Offer panel's header and list still say what they would.
local NO_DROPS = L["Your tradeable drops appear here, with who each would help."]
local NO_MATCH = L["None of your drops matches the filters."]

-- ── the view state (session-only) ───────────────────────────────────────────────────────────

local function view()
    local v = State.windowMine
    if not v then
        v = { dismissed = {}, revealed = {} }
        State.windowMine = v
    end
    v.collapsed = v.collapsed or {}
    return v
end

local function repaint()
    if NS.Window.IsShown() then NS.Window.Refresh() end
end

--- Hide one of your drops from the tab for the session (its row's Hide).
--- @param id number
function WM.Dismiss(id)
    view().dismissed[id] = true
    NS.Debug("UI", "my drop %s hidden", tostring(id))
    repaint()
end

--- Collapse or expand one group's rows for the session (its header's click).
--- @param key string the group's key
--- @param collapsedNow boolean
function WM.ToggleGroup(key, collapsedNow)
    view().collapsed[key] = not collapsedNow
    NS.Debug("UI", "my drops group %s %s", tostring(key), collapsedNow and "expanded" or "collapsed")
    repaint()
end

--- Show the Best candidates of an upgrade for you: the player chose to offer it.
--- @param id number
function WM.Reveal(id)
    if id ~= nil then view().revealed[id] = true end
end

--- Whether the Best candidates of drop `id` were revealed.
--- @param id number
--- @return boolean
function WM.IsRevealed(id) return view().revealed[id] == true end

-- ── the pure half ───────────────────────────────────────────────────────────────────────────

--- The tab's rows, top to bottom: your own drops that pass the tab's filter and were not hidden,
--- in the tab's order.
--- @param drops table the feed's drops (NS.LootFeed.Drops)
--- @param ctx table { matches = fn(drop), compare = fn(a, b) }
--- @param state table|nil { dismissed } (NS.State.windowMine)
--- @return table drops
function WM.Entries(drops, ctx, state)
    local out = {}
    for _, d in ipairs(drops or {}) do
        if WM.Lists(d, ctx, state) then out[#out + 1] = d end
    end
    table.sort(out, ctx.compare)
    return out
end

--- Whether the tab lists drop `d`: yours, not hidden with its row's Hide and passing the tab's own
--- filters. The tab's label and the Group drops headers' `· n yours on My drops` count with it, so
--- they agree with what the tab lists (feedback-3 spec §5, DW-B5).
--- @param d table
--- @param ctx table { matches = fn(drop) }
--- @param state table|nil { dismissed }
--- @return boolean
function WM.Lists(d, ctx, state)
    local dismissed = state and state.dismissed or {}
    return type(d) == "table" and d.isMine == true and not dismissed[d.id] and ctx.matches(d) == true
end

-- Why the tab leaves one of your drops out: `dismissed` (its row's Hide), else the filter's key.
local function excludedWhy(d, ctx, state)
    if state and state.dismissed and state.dismissed[d.id] then return "dismissed" end
    return ctx.hiddenBy and ctx.hiddenBy(d) or "filter"
end

--- Your drops in `drops`, tallied the way the tab lists them (pure): `listed` (WM.Lists), how many
--- of those you can still trade, and the ones left out ({ drop, why }, why `dismissed` or the
--- filter's key) for the tab's tooltip (feedback-3 spec §5).
--- @param drops table|nil
--- @param ctx table { matches = fn(drop), hiddenBy = fn(drop) }
--- @param state table|nil { dismissed }
--- @return table { listed, tradeable, excluded }
function WM.Tally(drops, ctx, state)
    local FB, t = NS.WindowFilterBar, { listed = 0, tradeable = 0, excluded = {} }
    for _, d in ipairs(drops or {}) do
        if WM.Lists(d, ctx, state) then
            t.listed = t.listed + 1
            if FB.IsTradeableMine(d) then t.tradeable = t.tradeable + 1 end
        elseif type(d) == "table" and d.isMine then
            t.excluded[#t.excluded + 1] = { drop = d, why = excludedWhy(d, ctx, state) }
        end
    end
    return t
end

--- The words for why the tab leaves a drop of yours out (pure): `you hid it`, or the filter
--- (FB.ReasonLabel).
--- @param why string `dismissed` or a filter key (excludedWhy's)
--- @param filter table|nil the tab's filter state
--- @return string
function WM.WhyLabel(why, filter)
    if why == "dismissed" then return L["you hid it"] end
    return NS.WindowFilterBar.ReasonLabel(why, filter)
end

--- The tab tooltip's lines for your drops it leaves out (pure): `Not listed here:`, then each drop
--- and why (`you hid it`, or the filter: FB.ReasonLabel), the first WC.HIDDEN_TIP_LINES of them.
--- @param excluded table|nil WM.Tally's
--- @param filter table|nil the tab's filter state
--- @return table lines (empty when none is left out)
function WM.ExcludedLines(excluded, filter)
    local WC, out = NS.WindowCells, {}
    if type(excluded) ~= "table" or #excluded == 0 then return out end
    out[1] = L["Not listed here:"]
    for i, x in ipairs(excluded) do
        if i > WC.HIDDEN_TIP_LINES then
            out[#out + 1] = L["and %d more"]:format(#excluded - WC.HIDDEN_TIP_LINES)
            break
        end
        out[#out + 1] = L["%s: %s"]:format(WC.ItemName(x.drop.link) or "?", WM.WhyLabel(x.why, filter))
    end
    return out
end

--- The tab's tally over the feed the window shows, through its own filters and Hide (the edge
--- the tab label and its tooltip read).
--- @return table WM.Tally's, plus `filter` (the tab's filter state)
function WM.TabTally()
    local ctx = NS.Window.TabContext("mine")
    local t = WM.Tally(NS.LootFeed.Drops(ctx.feed), ctx, view())
    t.filter = ctx.filter
    return t
end

--- Whether the tab lists drop `d` now (WM.Lists over its own filters and Hide), for the Group drops
--- headers' `· n yours on My drops`. Asked only of your own drops Group drops leaves to My drops, so
--- a repaint with none of them builds no context (the refresh pair's allocation ceiling).
--- @param d table
--- @return boolean
function WM.ListsNow(d)
    return WM.Lists(d, NS.Window.TabContext("mine"), view())
end

--- Why the tab leaves drop `d` of yours out now (its Hide or its own filters, in WM.WhyLabel's
--- words), else nil: the sim report's `not on My drops` (modules/SimReport.lua, feedback-3 spec §5).
--- Asked only of your own drops, so a repaint with none of them builds no context.
--- @param d table
--- @return string|nil
function WM.LeftOutNow(d)
    local ctx, st = NS.Window.TabContext("mine"), view()
    if WM.Lists(d, ctx, st) then return nil end
    return WM.WhyLabel(excludedWhy(d, ctx, st), ctx.filter)
end

--- How many drops the tab lists now (the tab label's `My drops · n`): WM.Tally's `listed`, without
--- its tables, and without the tab's context while the feed on show holds no drop of yours.
--- @return number
function WM.ListedCount()
    local drops = NS.LootFeed.Drops(NS.Window.FeedName())
    local any = false
    for _, d in ipairs(drops) do
        if d.isMine then any = true; break end
    end
    if not any then return 0 end
    local ctx, state, n = NS.Window.TabContext("mine"), view(), 0
    for _, d in ipairs(drops) do
        if WM.Lists(d, ctx, state) then n = n + 1 end
    end
    return n
end

-- The ids the feed's groups hold.
local function groupedIds(groups)
    local out = {}
    for _, g in ipairs(groups) do
        for _, id in ipairs(g.drops or {}) do out[id] = true end
    end
    return out
end

--- The table's entries, top to bottom: { kind = "header", group, count, total, hidden, filter,
--- collapsed } and { kind = "drop", drop }, as NS.WindowCells.Entries' over your own drops only, every
--- group open until toggled; then any entry of WM.Entries that no group holds, with no header.
--- @param groups table the feed's groups, oldest first (NS.LootFeed.Groups)
--- @param drops table the feed's drops (NS.LootFeed.Drops)
--- @param get function id -> drop (NS.LootFeed.Get)
--- @param ctx table Window.TabContext's { matches, compare, filter, belongs, hiddenBy }
--- @param state table|nil { collapsed, dismissed } (NS.State.windowMine)
--- @return table
function WM.Rows(groups, drops, get, ctx, state)
    state, groups = state or {}, groups or {}
    local mine = { matches = ctx.matches, compare = ctx.compare, filter = ctx.filter, hiddenBy = ctx.hiddenBy,
        belongs = function(d) return d.isMine == true and (not ctx.belongs or ctx.belongs(d)) end }
    local out = NS.WindowCells.Entries(groups, get, mine,
        { collapsed = state.collapsed, dismissed = state.dismissed, allOpen = true })
    local grouped = groupedIds(groups)
    for _, d in ipairs(WM.Entries(drops, ctx, state)) do
        if not grouped[d.id] then out[#out + 1] = { kind = "drop", drop = d } end
    end
    return out
end

-- ── painting helpers ────────────────────────────────────────────────────────────────────────

local function setTone(fs, tone)
    local c = C.TONE[tone] or C.TONE.plain
    fs:SetTextColor(c.r, c.g, c.b)
end

local function tipOf(frame) return unpack(frame.tipLines or {}) end

-- Every tooltip attached here is a row's (a cell, a button, a header): the row's top right.
local function attach(frame)
    NS.Window.AttachTooltip(frame, function() return tipOf(frame) end, "row")
end

local function textCell(row, key)
    local f = CreateFrame("Frame", nil, row)
    f.key = key
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
    f.text:SetJustifyH("LEFT")
    f.text:SetWordWrap(false)
    attach(f)
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

local function forMeCell(row)
    local f = textCell(row, "forMe")
    f.glyph = f:CreateFontString(nil, "OVERLAY")
    f.glyph:SetFont(C.FONT_MONO, 12, "")
    f.glyph:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4)   -- the arrow before the number (feedback-4 spec §0)
    f.text:ClearAllPoints()
    f.text:SetPoint("LEFT", f.glyph, "RIGHT", 3, 0)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.sub:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 4)
    return f
end

local function tradeCell(row)
    local f = textCell(row, "trade")
    f.text:ClearAllPoints()
    f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -5)
    f.barBg = f:CreateTexture(nil, "BACKGROUND")
    f.barBg:SetColorTexture(1, 1, 1, 0.12)
    f.barBg:SetHeight(K.BAR_H)
    f.barBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 5)
    f.barBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 5)
    f.bar = f:CreateTexture(nil, "ARTWORK")
    f.bar:SetHeight(K.BAR_H)
    f.bar:SetPoint("BOTTOMLEFT", f.barBg, "BOTTOMLEFT", 0, 0)
    return f
end

-- A flat button whose look follows an ask's state: label, catalog mark and whether it clicks.
local function setButtonLook(b, look)
    b.label:SetText(look.text)
    b.art:SetTexture(look.icon and NS.Icon(look.icon) or nil)
    b.art:SetShown(look.icon ~= nil)
    b.label:ClearAllPoints()
    b.label:SetPoint("CENTER", b, "CENTER", look.icon and 7 or 0, 0)
    b:SetEnabled(look.enabled)
    b:SetAlpha(look.enabled and 1 or 0.6)
    b.tipLines, b.state = look.tip, look.state
end
WM.SetButtonLook = setButtonLook

local function actionsCell(row)
    local f = CreateFrame("Frame", nil, row)
    f.key = "actions"
    local W = NS.Window
    f.offer = W.TextButton(f, K.OFFER_BTN_W, nil, L["Offer"], function(b) NS.OfferPanel.Open(b.dropId) end)
    f.offer:SetPoint("LEFT", f, "LEFT", 0, 0)
    attach(f.offer)
    f.announce = W.TextButton(f, K.ANNOUNCE_W, nil, L["Announce"], function(b) NS.PressAnnounce(b.dropId) end)
    f.announce:SetPoint("LEFT", f.offer, "RIGHT", 6, 0)
    attach(f.announce)
    f.dash = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.dash:SetPoint("CENTER", f.offer, "CENTER", 0, 0)
    f.dash:SetText("–")
    f.dashTip = CreateFrame("Frame", nil, f)
    f.dashTip:SetAllPoints(f.offer)
    attach(f.dashTip)
    f.hide = W.TextButton(f, K.ANNOUNCE_W, nil, L["Hide"], function(b) WM.Dismiss(b.dropId) end)
    f.hide:SetPoint("LEFT", f.offer, "RIGHT", 6, 0)
    attach(f.hide)
    return f
end

local BUILDERS = { item = itemCell, forMe = forMeCell, trade = tradeCell, actions = actionsCell }

-- A group's header: the Group drops tab's own button (WindowGroup.NewHeader), toggling this tab's.
local function newHeader(content)
    local h = NS.WindowGroup.NewHeader(content)
    h:SetScript("OnClick", function(self) WM.ToggleGroup(self.groupKey, self.collapsed) end)
    return h
end

local function paintHeader(h, e, now)
    local g = e.group
    local hd = NS.WindowCells.Header(g, e.count, now, NS.WindowFooter.SITUATION_LABEL[g.situation], e.collapsed,
        e.hidden, e.filter)
    h.groupKey, h.collapsed = g.key, e.collapsed
    h.text:SetText(hd.text)
    h.tipLines = hd.tip
    h.chevron:SetTexture(NS.Icon(e.collapsed and "chevron-right" or "chevron-down"))
end

local function newRow(content)
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(NS.WindowRows.MineRowHeight(NS.WindowRows.ROW_H))
    row.tipRow = true   -- its tooltips rise from its top right (modules/RowTooltip.lua)
    row.stripe = row:CreateTexture(nil, "BACKGROUND")
    row.stripe:SetAllPoints(row)
    row.stripe:SetColorTexture(1, 1, 1, 0.03)
    row.cells = {}
    for _, col in ipairs(WM.COLUMNS) do
        row.cells[col.key] = (BUILDERS[col.key] or textCell)(row, col.key)
    end
    return row
end

-- ── painting a row ──────────────────────────────────────────────────────────────────────────

local function paintText(f, c)
    f.text:SetText(c.text)
    setTone(f.text, c.tone)
    f.tipLines = c.tip
end

local function paintItem(f, drop)
    local c = NS.WindowCells.Item(drop)
    NS.WindowGroup.SetItem(f.button, drop.link, NS.WindowGroup.Where(drop))
    paintText(f, c)
    f.tipLines = nil
    local q = type(drop.facts) == "table" and drop.facts.quality
    local qc = type(ITEM_QUALITY_COLORS) == "table" and ITEM_QUALITY_COLORS[q]
    if qc then f.text:SetTextColor(qc.r, qc.g, qc.b) end
end

local function paintForMe(f, drop)
    local c = MC.ForMe(drop)
    paintText(f, c)
    f.glyph:SetText(c.glyph or "")
    setTone(f.glyph, c.tone)
    f.text:ClearAllPoints()
    if c.glyph then f.text:SetPoint("LEFT", f.glyph, "RIGHT", 3, 0) else f.text:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -4) end
    f.sub:SetText(c.sub or "")
    f.sub:SetShown(c.sub ~= nil)
end

-- The countdown's face follows its urgency; SetFontObject puts the template's size back, so the
-- Font size row's size goes on again after it.
local function paintTrade(f, drop, now, warnAt, size)
    local c = MC.TradeWindow(drop, now, warnAt)
    paintText(f, c)
    f.text:SetFontObject(c.bold and "GameFontNormalSmall" or "GameFontHighlightSmall")
    if size then NS.WindowRows.SetFontSize(f.text, size) end
    setTone(f.text, c.tone)
    local w = max((f:GetWidth() or 0) - 6, 0)
    f.fraction = c.fraction or 0
    f.bar:SetWidth(max(w * f.fraction, 0.01))
    f.bar:SetShown(f.fraction > 0)
    local tone = C.TONE[c.soon and "warn" or "good"]
    f.bar:SetColorTexture(tone.r, tone.g, tone.b, 0.9)
    f.bold = c.bold == true
end

local function annState(drop)
    return NS.Asks.StateOf("announce", nil, drop.id)
end

local function paintActions(f, drop, best)
    local a = MC.Actions(drop, best, MC.AnnounceButton(annState(drop)))
    f.offer.dropId, f.announce.dropId, f.hide.dropId = drop.id, drop.id, drop.id
    f.offer:SetShown(a.tradeable)
    f.announce:SetShown(a.tradeable)
    f.dash:SetShown(not a.tradeable)
    f.dashTip:SetShown(not a.tradeable)
    f.hide:SetShown(not a.tradeable)
    if not a.tradeable then
        f.dashTip.tipLines, f.hide.tipLines = a.dash.tip, a.hide.tip
        return
    end
    f.offer.tipLines, f.offer.primary = a.offer.tip, a.offer.primary
    local tone = a.offer.primary and C.GOLD or C.TONE.plain
    f.offer.label:SetTextColor(tone.r, tone.g, tone.b)
    setButtonLook(f.announce, a.announce)
end

local TEXT_INSET = { item = K.ROW_ICON + 5, forMe = 16 }

local function placeCells(row, layout, height)
    for key, f in pairs(row.cells) do
        local at = layout[key]
        f:SetShown(at ~= nil)
        if at then
            f:ClearAllPoints()
            f:SetPoint("LEFT", row, "LEFT", at.x, 0)
            f:SetSize(at.w, height)
            if f.text then f.text:SetWidth(max(at.w - (TEXT_INSET[key] or 0), 10)) end
        end
    end
end

local function paintRow(row, drop, layout, now, warnAt, metrics)
    row.dropId = drop.id
    row:SetHeight(metrics.mineHeight)
    placeCells(row, layout, metrics.mineHeight)
    NS.WindowRows.ApplyRowFont(row, metrics.fontSize)
    local cells = row.cells
    paintItem(cells.item, drop)
    paintText(cells.ilvl, NS.WindowCells.Ilvl(drop))
    paintForMe(cells.forMe, drop)
    paintTrade(cells.trade, drop, now, warnAt, metrics.fontSize)
    local best = MC.BestCandidates(drop, WM.IsRevealed(drop.id))
    paintText(cells.best, best)
    paintActions(cells.actions, drop, best)
end

-- ── the pane ────────────────────────────────────────────────────────────────────────────────

local function buildHeads(pane)
    local head = CreateFrame("Frame", nil, pane)
    head:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    head:SetPoint("TOPRIGHT", pane, "TOPRIGHT", -K.SCROLL_W, 0)
    head:SetHeight(K.COLHEAD_H)
    head.labels = {}
    for _, col in ipairs(WM.COLUMNS) do
        local f = CreateFrame("Frame", nil, head)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.text:SetPoint("LEFT", f, "LEFT", 0, 0)
        f.text:SetTextColor(C.IDLE.r, C.IDLE.g, C.IDLE.b)
        f.text:SetText(col.label)
        f.label = col.label
        NS.Window.AttachTooltip(f, function() return col.label, col.tip end)
        head.labels[col.key] = f
    end
    pane.colHead = head
end

local function postTip()
    return L["Post my tradeables"], L["Post one line to the group listing every drop you can still trade, cut into several lines when it is longer than chat allows."]
end

local function buildSummary(pane)
    local strip = CreateFrame("Frame", nil, pane)
    strip:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(K.MINE_FOOT_H)
    strip.line = strip:CreateTexture(nil, "ARTWORK")
    strip.line:SetColorTexture(1, 1, 1, 0.1)
    strip.line:SetHeight(1)
    strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
    strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
    strip.info = textCell(strip, "summary")
    strip.info:SetPoint("LEFT", strip, "LEFT", 2, 0)
    strip.info:SetSize(320, K.MINE_FOOT_H)
    strip.post = NS.Window.TextButton(strip, K.POST_W, "speech-bubble", L["Post my tradeables"], function() NS.PostTradeables() end)
    strip.post:SetPoint("RIGHT", strip, "RIGHT", 0, 0)
    NS.Window.AttachTooltip(strip.post, postTip)
    pane.summary = strip
end

local function build(pane)
    buildHeads(pane)
    buildSummary(pane)
    local scroll = CreateFrame("ScrollFrame", nil, pane, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", pane.colHead, "BOTTOMLEFT", 0, -2)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, K.MINE_FOOT_H)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    pane.scroll, pane.content = scroll, content
    pane.rowPool, pane.headPool = NS.Pool.New(), NS.Pool.New()
    pane.entries, pane.items = {}, {}
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

local function place(f, content, y, width)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    f:SetWidth(width)
end

local function drawRows(pane, items, layout, width, now)
    local warnAt, metrics = NS.TradeTimer.WarnAt(), NS.WindowRows.Metrics()
    local y = 0
    for i, e in ipairs(items) do
        if e.kind == "header" then
            local h = NS.Pool.Acquire(pane.headPool, function() return newHeader(pane.content) end)
            place(h, pane.content, y, width)
            paintHeader(h, e, now)
            y = y + K.GROUP_H
        else
            local r = NS.Pool.Acquire(pane.rowPool, function() return newRow(pane.content) end)
            place(r, pane.content, y, width)
            r.stripe:SetShown(i % 2 == 0)
            paintRow(r, e.drop, layout, now, warnAt, metrics)
            y = y + metrics.mineHeight
        end
    end
    pane.content:SetSize(width, max(y, 1))
end

local function paintSummary(pane, entries, now)
    local s = MC.Summary(entries, now)
    local info = pane.summary.info
    info.text:SetText(s.text)
    setTone(info.text, "muted")
    info.tipLines = s.tip
    pane.summary.post:SetEnabled(s.count > 0)
    pane.summary.post:SetAlpha(s.count > 0 and 1 or 0.5)
    pane.summaryData = s
end

local function paintEmpty(pane, entries, ctx, compact)
    local none = #entries == 0
    local ph = pane.placeholder
    ph:SetShown(none)
    if none then
        local anyMine = false
        for _, d in ipairs(NS.LootFeed.Drops(ctx.feed)) do
            if d.isMine then anyMine = true; break end
        end
        ph:SetText(anyMine and NO_MATCH or NO_DROPS)
    end
    pane.colHead:SetShown(not (none or compact))
end

-- The table, or (compact) the cards over the same rows; the other one is released and hidden.
local function refresh(pane, ctx)
    local LF, compact, now = NS.LootFeed, NS.WindowGroup.IsCompact(), GetTime()
    local drops = LF.Drops(ctx.feed)
    local entries = WM.Entries(drops, ctx, view())
    local items = WM.Rows(LF.Groups(ctx.feed), drops, LF.Get, ctx, view())
    NS.Pool.ReleaseAll(pane.rowPool)
    NS.Pool.ReleaseAll(pane.headPool)
    pane.scroll:SetShown(not compact)
    if not compact then
        local width = rowWidth(pane)
        local layout = NS.WindowGroup.Layout(WM.COLUMNS, width)
        paintHeads(pane, layout)
        drawRows(pane, items, layout, width, now)
    end
    pane.entries, pane.items = entries, items
    paintSummary(pane, entries, now)
    NS.CompactMine.Refresh(pane, items, compact)
    paintEmpty(pane, entries, ctx, compact)
end

--- The drawn pane, for the suites: { rows, headers, entries (your drops, flat), items (the
--- headers and rows, in order), pane, summary } or nil before the build.
--- @return table|nil
function WM.Drawn()
    local f = NS.Window.Frame()
    local pane = f and f.panes.mine
    if not (pane and pane.rowPool) then return nil end
    if NS.WindowGroup.IsCompact() then return NS.CompactMine.Drawn(pane) end
    return { rows = pane.rowPool.active, headers = pane.headPool.active, entries = pane.entries,
        items = pane.items, pane = pane, summary = pane.summaryData }
end

NS.Window.RegisterTab("mine", { build = build, refresh = refresh })
