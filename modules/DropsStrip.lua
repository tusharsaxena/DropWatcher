local _, NS = ...
-- modules/DropsStrip.lua — the Drops tab's summary on the window's footer (feedback-5 spec §3,
-- DW-E3; RX-24): how many of your drops the tab lists you can still trade, the next of their trade
-- windows to run out, and the footer's Drops controls, Post my tradeables, Scan group and Expand all /
-- Collapse all.
--
-- WHEN IT SAYS WHAT. In both layouts: with nothing tradeable its summary is empty and Post hidden.
-- It counts your drops the tab lists (DS.Own: yours and passing the tab's filters, through
-- Window.TabContext's `matches`), collapsed under their header or not. What it says is
-- NS.MineCells.Summary's (pure): `2 tradeable · next expiry 0:08:41`.
--
-- ON THE FOOTER (RX-24; WowAddonStandards v2.110.0 standalone-windows' *The footer*). No strip and no
-- frame of its own: the summary is the start of the footer's own left line, the status after it
-- (NS.WindowFooter.PaintTab, LineText), and the controls are the footer's marks (NS.FooterRow),
-- right to left from the grip's corner: `Expand all`, `Scan group`, `Post my tradeables`, each a
-- catalog mark with a tooltip naming it, the same in both layouts. Post, the leftmost, shows only
-- while one of your drops the tab lists can be traded and another player is in your group to read it
-- (DS.Postable, DW-07; test mode always). Until RX-24 this was a strip of 150 px labeled buttons laid
-- over the footer (feedback-15 spec §2), with the tab's Sort at its right edge (now on the filter
-- bar).
--
-- THE COMPACT LAYOUT shortens the summary: `2 tradeable · next 0:08:41` (DS.SummaryText).
--
-- NEW TO YOUR COLLECTION (issue #13, categories design spec §6.1). The summary ends with `n new`:
-- the drops the tab lists (anyone's) whose verdict for you is new to your collection (DS.NewCount),
-- `2 tradeable · next expiry 0:08:41 · 1 new`, or `1 new` alone (DS.Text). It is no trade count, so
-- it never shows Post my tradeables.
--
-- THE FRAME EDGE. modules/WindowGroup.lua builds the pane's model with it (DS.Build) and repaints it
-- on every refresh (DS.Paint, after the table or the cards are drawn: it keeps the scroll frames'
-- bottom edge over the footer) and on each countdown tick (DS.Tick: the words alone). Post my
-- tradeables goes through the host handler NS.PostTradeables (core/DropWatcher.lua), which posts
-- every drop of yours you can still trade; Scan group through NS.ScanGroup, as the empty state's did.
--
-- THE EMPTY STATE (board 06 D) is built here too (DS.BuildEmpty, peeled out of
-- modules/WindowGroup.lua, which shows it while the feed holds no drop at all): `No drops yet` and a
-- line on what the table will hold. Its Preview with test data and Scan group buttons (feedback-7
-- spec §4) left it in feedback-16: Scan group is on the footer and the title bar, test mode `/dw test`.

NS.DropsStrip = NS.DropsStrip or {}
local DS = NS.DropsStrip
local K  = NS.Constants.WINDOW
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

--- The drops the tab lists whose verdict for you is new to your collection (pure): anyone's.
--- @param drops table|nil the feed's drops
--- @param matches function drop -> boolean (Window.TabContext's)
--- @return number
function DS.NewCount(drops, matches)
    local n = 0
    for _, d in ipairs(drops or {}) do
        if type(d) == "table" and type(d.me) == "table" and d.me.verdict == "newCollect" and matches(d) == true then
            n = n + 1
        end
    end
    return n
end

--- The summary's text and tooltip (pure): the tradeable part (MineCells.Summary's, the compact
--- layout's DS.SummaryText) when anything is tradeable, then `n new` when anything is new to your
--- collection, joined by ` · `; "" and nil when neither.
--- @param s table MineCells.Summary's answer
--- @param newCount number DS.NewCount's
--- @param compact boolean
--- @return string text, table|nil tip
function DS.Text(s, newCount, compact)
    local parts, tip = {}, nil
    if s.count > 0 then
        parts[1] = compact and DS.SummaryText(s) or s.text
        tip = { unpack(s.tip) }
    end
    if (newCount or 0) > 0 then
        parts[#parts + 1] = L["%d new"]:format(newCount)
        tip = tip or { L["New to your collection"] }
        tip[#tip + 1] = NS.TipMarks.Row(L["New to your collection"], newCount, "good")
    end
    return table.concat(parts, " · "), tip
end

--- The compact layout's short summary (MineCells.Summary's, shortened): `2 tradeable · next 0:08:41`.
--- @param s table MineCells.Summary's answer
--- @return string
function DS.SummaryText(s)
    local text = s.count == 1 and L["1 tradeable"] or L["%d tradeable"]:format(s.count or 0)
    if s.next then text = text .. " · " .. L["next %s"]:format(NS.MineCells.Clock(s.next)) end
    return text
end

--- Post my tradeables has someone to reach (DW-07, Addendum 08): another player is in your group
--- (NS.WindowOwn.Alone), or test mode is on, where NS.PostTradeables prints instead of sending. Solo,
--- with only followers or a delve companion, the strip leaves Post hidden.
--- @return boolean
function DS.Postable()
    if NS.State and NS.State.testMode == true then return true end
    local WO = NS.WindowOwn
    return not (WO and WO.Alone and WO.Alone())
end

-- ── the model ───────────────────────────────────────────────────────────────────────────────

local function postTip()
    local TM = NS.TipMarks
    return L["Post my tradeables"], TM.Row(L["Posts to"], L["the group"]),
        TM.Row(L["Lists"], L["every drop you can still trade"]), TM.Row(L["Too long"], L["cut into several lines"])
end

local function scanTip() return NS.WindowTitleBar.ScanTip() end

--- Build the Drops pane's footer model (RX-24): its words and its controls, right to left, with Post
--- my tradeables and without it, both built once so a repaint builds no table.
--- @param pane table the Drops pane
function DS.Build(pane)
    local FR = NS.FooterRow
    local fold = FR.FoldControl(function(collapse) NS.WindowGroup.FoldAll(pane.entries, collapse) end)
    local scan = FR.Control("scan", "people", scanTip, function() NS.ScanGroup() end)
    local post = FR.Control("post", "speech-bubble", postTip, function() NS.PostTradeables() end)
    pane.foot = { info = "", tip = nil, fold = fold,
        withPost = { fold, scan, post }, withoutPost = { fold, scan } }
    pane.foot.controls = pane.foot.withoutPost
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
    NS.Skin.Text(e.title, "heading")   -- gold, in the skin's title face
    e.text = e:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    e.text:SetPoint("TOP", e.title, "BOTTOM", 0, -8)
    NS.Skin.Text(e.text, "text.highlight")
    e.text:SetText(L["Loot your group receives appears here, grouped by boss."])
    e:Hide()
    return e
end

-- A scroll frame's bottom edge: `bottom` pixels over the pane's (the footer's room, or none).
local function setBottom(scroll, pane, top, topY, bottom)
    if not scroll or scroll.dwBottom == bottom then return end
    scroll.dwBottom = bottom
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", top, top == pane and "TOPLEFT" or "BOTTOMLEFT", 0, topY)
    scroll:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", -K.SCROLL_W, bottom)
end

-- The summary's words in the layout in force (DS.Text), handed to the footer; nothing to say
-- (nothing tradeable, nothing new) leaves them empty, with no tooltip.
local function paintText(pane, s, compact)
    local foot = pane.foot
    foot.info, foot.tip = DS.Text(s, pane.newCount, compact)
    NS.WindowFooter.PaintTab(pane)
end

--- Repaint the summary for the tab's view (every refresh, after the table or the cards are drawn):
--- its words and, in both layouts, its controls on the footer (Post my tradeables only while one of
--- your drops the tab lists can be traded), the toggle painted from the tab's entries, the scroll
--- frames over the footer.
--- @param pane table the Drops pane
--- @param ctx table Window.TabContext's
--- @param compact boolean the compact layout is in force
function DS.Paint(pane, ctx, compact)
    local foot = pane.foot
    if not foot then return end
    local drops = NS.LootFeed.Drops(ctx.feed)
    pane.ownDrops = DS.Own(drops, ctx.matches)
    pane.newCount = DS.NewCount(drops, ctx.matches)
    local s = NS.MineCells.Summary(pane.ownDrops, GetTime())
    local tradeable = s.count > 0
    pane.summaryData = tradeable and s or nil
    foot.controls = (tradeable and DS.Postable()) and foot.withPost or foot.withoutPost
    NS.FooterRow.PaintFold(foot.fold, pane.entries)
    paintText(pane, s, compact)
    local bottom = NS.FooterMetric("HEIGHT")
    setBottom(pane.scroll, pane, pane.colHead, -2, bottom)
    local cv = pane.compactView
    setBottom(cv and cv.scroll, pane, pane, 0, bottom)
end

--- Move the summary's next expiry on to the clock (WindowGroup.TickCountdowns): the words alone, over
--- the drops the last repaint counted, while it shows a summary.
--- @param pane table the Drops pane
--- @param compact boolean
function DS.Tick(pane, compact)
    if not (pane.foot and pane.summaryData and pane.ownDrops) then return end
    local s = NS.MineCells.Summary(pane.ownDrops, GetTime())
    pane.summaryData = s.count > 0 and s or nil
    paintText(pane, s, compact)
end
