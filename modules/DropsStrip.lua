local _, NS = ...
-- modules/DropsStrip.lua — the Drops tab's summary strip (feedback-5 spec §3, DW-E3): how many of
-- your drops the tab lists you can still trade, the next of their trade windows to run out, Post my
-- tradeables, Expand all / Collapse all and Scan group, under the table (or the compact cards) and
-- above the footer.
--
-- WHEN IT SHOWS. Always, in both layouts (feedback-7 spec §4 for the full one; feedback-15 spec §2
-- for compact, where the toggle lives there now): with nothing tradeable its summary is empty and
-- Post hidden. It counts your drops the tab lists (DS.Own: yours and passing the tab's filters, through
-- Window.TabContext's `matches`), collapsed under their header or not. What it says is
-- NS.MineCells.Summary's (pure): `2 tradeable · next expiry 0:08:41`.
--
-- THE ROW (feedback-15 spec §2, NS.FooterRow), right-aligned. Full, every button the one footer
-- width (K.FOOTER_BUTTON_W) with its label: `[Post my tradeables] [Scan group] [Expand all] [Sort]`,
-- the tab's Sort (NS.WindowFooter's control, anchored here through `pane.sortHost`) at the strip's
-- right edge (NS.WindowFooter.SORT_INSET). Compact, the same buttons as their marks alone
-- (K.FOOTER_ICON_W, FooterRow.SetCompact; feedback-16), their tooltips naming them: `[Post] [Scan
-- group] [Expand all]` (Sort is in the Filters panel; Scan group is the title bar's icon too). Post,
-- the leftmost, shows only while one of your drops the tab lists can be traded; the summary ends
-- where the row starts, one line, cut with an ellipsis when the row is narrow.
--
-- THE COMPACT LAYOUT shortens the summary: `2 tradeable · next 0:08:41` (DS.SummaryText).
--
-- THE FRAME EDGE. modules/WindowGroup.lua builds it with the pane (DS.Build) and repaints it on every
-- refresh (DS.Paint, after the table or the cards are drawn: it moves the scroll frames' bottom edge
-- up over it, or back down) and on each countdown tick (DS.Tick: the text alone). Post my tradeables
-- goes through the host handler NS.PostTradeables (core/DropWatcher.lua), which posts every drop of
-- yours you can still trade; Scan group through NS.ScanGroup, as the title bar's and the empty
-- state's do.
--
-- THE EMPTY STATE (board 06 D) is built here too (DS.BuildEmpty, peeled out of
-- modules/WindowGroup.lua, which shows it while the feed holds no drop at all): `No drops yet` and a
-- line on what the table will hold. Its Preview with test data and Scan group buttons (feedback-7
-- spec §4) left it in feedback-16: Scan group is on the strip and the title bar, test mode `/dw test`.

NS.DropsStrip = NS.DropsStrip or {}
local DS = NS.DropsStrip
local K  = NS.Constants.WINDOW
local C  = NS.Constants
local L  = NS.L

-- ── pure ────────────────────────────────────────────────────────────────────────────────────

--- Your drops the tab lists (pure): yours, and passing the tab's own filters, in the feed's order.
--- @param drops table|nil the feed's drops (NS.LootFeed.Drops)
--- @param matches function drop -> boolean (Window.TabContext's)
--- @return table drops
function DS.Own(drops, matches)
    local out = {}
    for _, d in ipairs(drops or {}) do
        if type(d) == "table" and d.isMine == true and matches(d) == true then out[#out + 1] = d end
    end
    return out
end

--- The compact layout's short summary (MineCells.Summary's, shortened): `2 tradeable · next 0:08:41`.
--- @param s table MineCells.Summary's answer
--- @return string
function DS.SummaryText(s)
    local text = s.count == 1 and L["1 tradeable"] or L["%d tradeable"]:format(s.count or 0)
    if s.next then text = text .. " · " .. L["next %s"]:format(NS.MineCells.Clock(s.next)) end
    return text
end

--- The strip's row, right to left, for NS.FooterRow.Slots (pure): full `Sort · Expand/Collapse ·
--- Scan group · Post my tradeables`, compact `Expand/Collapse · Scan group · Post` as icons, Post
--- shown only while something of yours is tradeable (feedback-15 spec §2, feedback-16).
--- @param tradeable boolean
--- @param compact boolean
--- @return table
function DS.Row(tradeable, compact)
    local w = NS.FooterRow.Width(compact)
    local row = {}
    if not compact then row[#row + 1] = { key = "sort", w = NS.WindowFooter.SORT_W } end
    row[#row + 1] = { key = "fold", w = w }
    row[#row + 1] = { key = "scan", w = w }
    row[#row + 1] = { key = "post", w = w, shown = tradeable }
    return row
end

-- ── the frame ───────────────────────────────────────────────────────────────────────────────

local function postTip()
    return L["Post my tradeables"], L["Post one line to the group listing every drop you can still trade, cut into several lines when it is longer than chat allows."]
end

local function tipOf(f) return unpack(f.tipLines or {}) end

--- Build the strip at the bottom of the Drops pane, hidden until it has something to say.
--- @param pane table the Drops pane
function DS.Build(pane)
    local W = NS.Window
    local strip = CreateFrame("Frame", nil, pane)
    strip:SetPoint("BOTTOMLEFT", pane, "BOTTOMLEFT", 0, 0)
    strip:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)
    strip:SetHeight(K.STRIP_H)
    strip.line = strip:CreateTexture(nil, "ARTWORK")
    strip.line:SetColorTexture(1, 1, 1, 0.1)
    strip.line:SetHeight(1)
    strip.line:SetPoint("TOPLEFT", strip, "TOPLEFT", 0, 0)
    strip.line:SetPoint("TOPRIGHT", strip, "TOPRIGHT", 0, 0)
    local info = CreateFrame("Frame", nil, strip)
    info.text = info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info.text:SetPoint("LEFT", info, "LEFT", 0, 0)
    info.text:SetPoint("RIGHT", info, "RIGHT", 0, 0)
    info.text:SetJustifyH("LEFT")
    info.text:SetWordWrap(false)   -- one line: the game cuts it with an ellipsis when narrow
    info:SetHeight(K.STRIP_H)
    W.AttachTooltip(info, function() return tipOf(info) end, "row")
    strip.info = info
    local FR = NS.FooterRow
    strip.post = FR.Button(strip, "speech-bubble", L["Post my tradeables"], function() NS.PostTradeables() end)
    W.AttachTooltip(strip.post, postTip)
    strip.scan = FR.Button(strip, "people", L["Scan group"], function() NS.ScanGroup() end)
    W.AttachTooltip(strip.scan, NS.WindowTitleBar.ScanTip)
    strip.fold = FR.BuildFold(strip, function(collapse) NS.WindowGroup.FoldAll(pane.entries, collapse) end)
    strip:Hide()
    pane.summary = strip
    pane.sortHost = strip   -- the full layout's Sort sits at its right edge (feedback-10 spec §3)
end

-- ── the empty state (board 06 D) ────────────────────────────────────────────────────────────

-- No drop at all yet: what the table will hold, in both layouts (no button: feedback-16).
--- Build the Drops pane's empty state (board 06 D), hidden; WindowGroup shows it while the feed
--- holds no drop at all.
--- @param pane table the Drops pane
--- @return table frame { title, text }
function DS.BuildEmpty(pane)
    local e = CreateFrame("Frame", nil, pane)
    e:SetSize(K.EMPTY_W, K.EMPTY_H)
    e:SetPoint("CENTER", pane, "CENTER", 0, 0)
    e.title = e:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    e.title:SetPoint("TOP", e, "TOP", 0, 0)
    e.title:SetText(L["No drops yet"])
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    e.text:SetPoint("TOP", e.title, "BOTTOM", 0, -8)
    e.text:SetText(L["Loot your group receives appears here, grouped by boss."])
    e:Hide()
    return e
end

-- A scroll frame's bottom edge: `bottom` pixels over the pane's (the strip's room, or none).
local function setBottom(scroll, pane, top, topY, bottom)
    if not scroll or scroll.dwBottom == bottom then return end
    scroll.dwBottom = bottom
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", top, top == pane and "TOPLEFT" or "BOTTOMLEFT", 0, topY)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, bottom)
end

-- The row in the layout in force (DS.Row through NS.FooterRow.Slots; the tab's Sort is anchored
-- by NS.WindowFooter.AnchorSort in its slot), and the summary ending where it starts. The placement
-- depends on the layout and on whether Post shows, nothing else, so a repaint that changes neither
-- builds no table and re-anchors nothing (the refresh's allocation ceiling, docs/performance.md).
local function placeButtons(strip, tradeable, compact)
    if strip.dwPlacedCompact == compact and strip.dwPlacedPost == tradeable then return end
    strip.dwPlacedCompact, strip.dwPlacedPost = compact, tradeable
    local FR = NS.FooterRow
    local slots = FR.Slots(DS.Row(tradeable, compact), FR.GAP, compact and 0 or NS.WindowFooter.SORT_INSET)
    FR.SetCompact(strip.fold, compact)
    FR.SetCompact(strip.scan, compact)
    FR.SetCompact(strip.post, compact)
    FR.Place(strip, strip.fold, slots.fold)
    FR.Place(strip, strip.scan, slots.scan)
    FR.Place(strip, strip.post, slots.post)
    FR.PlaceInfo(strip, strip.info, slots.left)
end

-- The summary's text in the layout in force; nothing to say (nothing tradeable) leaves it empty,
-- with no tooltip.
local function paintText(pane, s, compact)
    local strip = pane.summary
    local info = strip.info
    local tradeable = s.count > 0
    info.text:SetText(not tradeable and "" or compact and DS.SummaryText(s) or s.text)
    local tone = C.TONE.muted
    info.text:SetTextColor(tone.r, tone.g, tone.b)
    info.tipLines = tradeable and s.tip or nil
end

--- Repaint the strip for the tab's view (every refresh, after the table or the cards are drawn):
--- shown always, in both layouts (Post my tradeables only while one of your drops the tab lists can
--- be traded), the toggle painted from the tab's entries, the scroll frames above it.
--- @param pane table the Drops pane
--- @param ctx table Window.TabContext's
--- @param compact boolean the compact layout is in force
function DS.Paint(pane, ctx, compact)
    local strip = pane.summary
    if not strip then return end
    pane.ownDrops = DS.Own(NS.LootFeed.Drops(ctx.feed), ctx.matches)
    local s = NS.MineCells.Summary(pane.ownDrops, GetTime())
    local tradeable = s.count > 0
    strip:Show()
    pane.summaryData = tradeable and s or nil
    paintText(pane, s, compact)
    placeButtons(strip, tradeable, compact)
    NS.FooterRow.PaintFold(strip.fold, pane.entries)
    local bottom = K.STRIP_H
    setBottom(pane.scroll, pane, pane.colHead, -2, bottom)
    local cv = pane.compactView
    setBottom(cv and cv.scroll, pane, pane, 0, bottom)
end

--- Move the strip's next expiry on to the clock (WindowGroup.TickCountdowns): the text alone, over
--- the drops the last repaint counted, while it shows a summary.
--- @param pane table the Drops pane
--- @param compact boolean
function DS.Tick(pane, compact)
    local strip = pane.summary
    if not (strip and strip:IsShown() and pane.summaryData and pane.ownDrops) then return end
    local s = NS.MineCells.Summary(pane.ownDrops, GetTime())
    pane.summaryData = s.count > 0 and s or nil
    paintText(pane, s, compact)
end
