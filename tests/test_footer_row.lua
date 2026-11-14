-- tests/test_footer_row.lua — one footer button kind, and Expand all / Collapse all (feedback-15
-- spec §2, DW-Q2): every footer button is C.WINDOW.FOOTER_BUTTON_W wide with the same icon and label
-- in both layouts (no short `Post` or `Clear`); right to left the full Drops row is Sort, the toggle,
-- Scan group and Post my tradeables, compact Drops the toggle and Post, full History Sort and the
-- toggle, compact History the toggle (Clear history lives in Settings, feedback-15 spec §3); the
-- info text on the left ends where the buttons start; the compact Drops strip is always shown. The
-- toggle reads `Expand all` while a header the filters show is collapsed and `Collapse all` once
-- every one is open, sets every shown header of the active tab, and is off with none. Built headless
-- under the mock (modules/FooterRow.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local NOW = 1000
local DAY = 86400

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function drop(id, mine, at)
    return { id = id, at = at, link = link(400 + id), isMine = mine, sources = { chat = 1 },
        looter = mine and { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true }
            or { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = mine and { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 600 }
            or { state = "no", reasonKey = "bonusRoll", basis = "bind" } }
end

local function groupOf(key, at, ids)
    return { key = key, label = key, kind = "encounter", at = at, drops = ids,
        instance = "Zul'Aman", difficulty = "Heroic", seenBy = "Me-Realm", seenByClass = "PALADIN" }
end

-- Three groups on Drops (the newest open, the older two collapsed by default); `mine` puts a
-- tradeable drop of yours in the newest.
local function shownDrops(mode, mine)
    local NS, _, m = T.enableAddon()
    T.withPlayer(m)   -- someone to post to (DW-07)
    NS.addon.db.char = { session = { start = m.time() - DAY } }   -- logged in a day ago (feedback-15 spec §1)
    m.__now = NOW
    local drops = { drop(1, false, NOW - 900), drop(2, false, NOW - 600), drop(3, mine == true, NOW - 300) }
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.LootFeed.Groups = function()
        return { groupOf("A", NOW - 900, { 1 }), groupOf("B", NOW - 600, { 2 }), groupOf("C", NOW - 300, { 3 }) }
    end
    NS.Asks.StateOf = function() return "ready" end
    NS.WindowFilterBar.Set("group", "view", "all")
    if mode then NS.SetWindowMode(mode) end
    NS.ShowWindow()
    NS.Window.SelectTab("group")
    return NS, NS.WindowGroup.Drawn(), m
end

local function entry(at, id)
    return { itemLink = link(id), itemID = id, looter = "Brakk-Otherrealm", class = "WARRIOR", outcome = "seen",
        at = at, seenBy = "Testchar-Testrealm", ilvl = 610, equipLoc = "INVTYPE_NECK", quality = 4,
        me = { verdict = "downgrade", ilvlDelta = -4 }, them = { verdict = "sidegrade", ilvlDelta = 0 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} } }
end

-- Two kept groups on History (the newest open, the older collapsed by default).
local function shownHistory(mode, empty)
    local NS, _, m = T.enableAddon()
    local now = m.time()
    local hist = NS.History.Store()
    hist.groups = empty and {} or {
        { key = "old", label = "Boss Old", kind = "encounter", situation = "raid", at = now - 3 * DAY,
          drops = { entry(now - 3 * DAY, 500) } },
        { key = "new", label = "Boss New", kind = "encounter", situation = "dungeon", at = now - 120,
          drops = { entry(now - 120, 501), entry(now - 100, 502) } },
    }
    if mode then NS.SetWindowMode(mode) end
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    return NS, NS.WindowHistory.Drawn(), m
end

local function textOf(region) return region and region:GetText() end

-- A control's one anchor: its point, the frame it hangs from and its x.
local function anchorOf(b)
    local point, rel, _, x = b:GetPoint(1)
    return point, rel, x
end

-- The info's right edge: its RIGHT anchor's frame and x.
local function rightOf(region)
    for _, pt in ipairs(region.__points or {}) do
        if pt[1] == "RIGHT" then return pt[2], pt[4] end
    end
end

local function collapsedHeaders(drawn)
    local n = 0
    for _, e in ipairs(drawn.entries) do
        if e.kind == "header" and e.collapsed then n = n + 1 end
    end
    return n
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

test("footer row: the slots, pure: right to left, a gap between, a hidden control takes no room", function()
    local NS = T.enableAddon()
    local FR = NS.FooterRow
    -- red under: no modules/FooterRow.lua (DropsStrip.Slots placed Post, Scan group and Sort alone)
    assertTrue(FR ~= nil, "NS.FooterRow")
    local s = FR.Slots({ { key = "sort", w = 150 }, { key = "fold", w = 150 }, { key = "scan", w = 150 },
        { key = "post", w = 150 } }, 8)
    assertEqual(s.sort, 0); assertEqual(s.fold, 158); assertEqual(s.scan, 316); assertEqual(s.post, 474)
    assertEqual(s.left, 624, "the leftmost control's left edge")
    s = FR.Slots({ { key = "fold", w = 150 }, { key = "post", w = 150, shown = false } }, 8)
    assertEqual(s.fold, 0); assertTrue(s.post == nil, "hidden"); assertEqual(s.left, 150)
end)

test("footer row: the toggle's state, pure: Expand all while a shown header is collapsed, none without one", function()
    local NS = T.enableAddon()
    local FR = NS.FooterRow
    local function h(key, count, c) return { kind = "header", group = { key = key }, count = count, collapsed = c } end
    assertEqual(FR.FoldState({ h("a", 1, false), { kind = "drop" }, h("b", 2, true) }), "expand")
    assertEqual(FR.FoldState({ h("a", 1, false), { kind = "drop" }, h("b", 2, false) }), "collapse")
    assertTrue(FR.FoldState({}) == nil, "no header: off")
    assertTrue(FR.FoldState({ h("a", 0, false) }) == nil, "a header with no drop shown has nothing to fold")
    local collapsed = { gone = true }
    FR.FoldAll({ h("a", 1, false), h("b", 2, true), h("z", 0, false) }, collapsed, false)
    assertTrue(collapsed.a == false and collapsed.b == false and collapsed.z == nil)
    assertTrue(collapsed.gone == true, "a group the filters do not show keeps its state")
    FR.FoldAll({ h("a", 1, false), h("b", 2, false) }, collapsed, true)
    assertTrue(collapsed.a == true and collapsed.b == true)
end)

-- ── one button kind ─────────────────────────────────────────────────────────────────────────

test("footer row: full Drops, right to left: Sort, the toggle, Scan group, Post my tradeables, one width", function()
    local NS, drawn = shownDrops(nil, true)
    local K, WF, FR = NS.Constants.WINDOW, NS.WindowFooter, NS.FooterRow
    local strip = drawn.pane.summary
    -- red under: Scan group SCAN_W (110) wide, no toggle on the strip
    assertEqual(K.FOOTER_BUTTON_W, 150)
    assertTrue(strip.fold ~= nil, "the toggle")
    local _, sort = WF.Parts()
    assertEqual(sort:GetWidth(), K.FOOTER_BUTTON_W, "Sort the same width")
    for _, b in ipairs({ strip.fold, strip.scan, strip.post }) do
        assertTrue(b:IsShown()); assertEqual(b:GetWidth(), K.FOOTER_BUTTON_W); assertEqual(b:GetHeight(), K.CONTROL_H)
    end
    local step = K.FOOTER_BUTTON_W + FR.GAP
    local p, rel, x = anchorOf(strip.fold)
    assertEqual(p, "RIGHT"); assertTrue(rel == strip); assertEqual(x, -(WF.SORT_INSET + step))
    assertEqual(select(3, anchorOf(strip.scan)), -(WF.SORT_INSET + 2 * step))
    assertEqual(select(3, anchorOf(strip.post)), -(WF.SORT_INSET + 3 * step))
    local status = WF.Parts()
    local irel, ix = rightOf(status)
    assertTrue(irel == strip, "the line ends where the buttons start")
    assertEqual(ix, -(WF.SORT_INSET + 3 * step + K.FOOTER_BUTTON_W + FR.GAP))
    assertTrue((rightOf(strip.info.text)) == strip.info, "its text bounded too: one line, an ellipsis when narrow")
end)

test("footer row: compact Drops is always shown: the toggle at the right, Post my tradeables left of it", function()
    local NS, drawn = shownDrops("compact", false)
    local K, FR = NS.Constants.WINDOW, NS.FooterRow
    local strip = drawn.pane.summary
    -- red under: compact hid the strip while nothing of yours was tradeable
    assertTrue(strip:IsShown(), "nothing tradeable, the toggle still there")
    local step = K.FOOTER_ICON_W + FR.GAP
    -- red under: compact's buttons 150 wide with their labels, and no Scan group on its strip (feedback-16)
    for _, b in ipairs({ strip.fold, strip.scan }) do
        assertTrue(b:IsShown()); assertEqual(b:GetWidth(), K.FOOTER_ICON_W, "icon only")
        assertFalse(b.label:IsShown(), "no label"); assertTrue(b.art:IsShown(), "its mark")
        assertEqual(b.art.__points[1][1], "CENTER", "the mark centered")
    end
    local status = NS.WindowFooter.Parts()
    assertEqual(select(3, anchorOf(strip.fold)), -FR.START, "clear of the grip in the corner (RX-09)")
    assertEqual(select(3, anchorOf(strip.scan)), -(FR.START + step), "Scan group beside the toggle, as in full")
    assertEqual(NS.Window.TooltipOf(strip.scan)[1], "Scan group", "the tooltip names it")
    assertFalse(strip.post:IsShown())
    assertEqual(select(2, rightOf(status)), -(FR.START + 2 * step))
    assertEqual(textOf(strip.info.text), "")
    NS.SetWindowMode("full")
    NS.LootFeed.Drops()[3].isMine = true
    NS.LootFeed.Drops()[3].looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true }
    NS.LootFeed.Drops()[3].trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 600 }
    NS.SetWindowMode("compact")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(strip.post:IsShown())
    assertEqual(strip.post:GetWidth(), K.FOOTER_ICON_W); assertFalse(strip.post.label:IsShown())
    assertEqual(NS.Window.TooltipOf(strip.post)[1], "Post my tradeables", "the tooltip names it")
    assertEqual(select(3, anchorOf(strip.post)), -(FR.START + 2 * step))
    assertEqual(select(2, rightOf(status)), -(FR.START + 3 * step))
    assertTrue(drawn.summary ~= nil)
    NS.SetWindowMode("full")
    for _, b in ipairs({ strip.fold, strip.scan, strip.post }) do
        assertEqual(b:GetWidth(), K.FOOTER_BUTTON_W, "full takes the width back")
        assertTrue(b.label:IsShown()); assertEqual(b.art.__points[1][1], "LEFT")
    end
    assertEqual(textOf(strip.post.label), "Post my tradeables")
end)

test("footer row: History, full Sort then the toggle, compact the toggle; no Clear history", function()
    local NS, drawn = shownHistory()
    local K, WF, FR = NS.Constants.WINDOW, NS.WindowFooter, NS.FooterRow
    local strip = drawn.strip
    local step = K.FOOTER_BUTTON_W + FR.GAP
    -- red under: no toggle on History's strip
    assertTrue(strip.fold ~= nil and strip.fold:IsShown())
    assertEqual(strip.fold:GetWidth(), K.FOOTER_BUTTON_W)
    assertEqual(select(3, anchorOf(strip.fold)), -(WF.SORT_INSET + step))
    -- red under: Clear history beside the toggle (DW-Q3 moves it to Settings, feedback-15 spec §3)
    assertTrue(strip.clear == nil, "Clear history left the strip")
    local status = WF.Parts()
    assertTrue((rightOf(status)) == strip)
    assertEqual(select(2, rightOf(status)), -(WF.SORT_INSET + step + K.FOOTER_BUTTON_W + FR.GAP))
    NS.SetWindowMode("compact")
    assertTrue(NS.WindowHistory.Drawn().compact == true)
    assertEqual(select(3, anchorOf(strip.fold)), -FR.START)
    assertEqual(strip.fold:GetWidth(), K.FOOTER_ICON_W, "icon only in compact")
    assertFalse(strip.fold.label:IsShown())
    assertEqual(select(2, rightOf(status)), -(FR.START + K.FOOTER_ICON_W + FR.GAP))
end)

-- ── Expand all / Collapse all ───────────────────────────────────────────────────────────────

test("footer row: the Drops toggle opens every shown header, then closes them, in both layouts", function()
    for _, mode in ipairs({ "full", "compact" }) do
        local NS, drawn = shownDrops(mode)
        local fold = drawn.pane.summary.fold
        assertEqual(collapsedHeaders(drawn), 2, mode .. ": the older two collapsed by default")
        assertEqual(textOf(fold.label), "Expand all", mode)
        -- red under: the expand-down / collapse-up marks (feedback-16 picks the chevrons)
        assertEqual(fold.art:GetTexture(), NS.Icon("chevron-down"), mode)
        assertTrue(fold:IsEnabled())
        assertEqual(NS.Window.TooltipOf(fold)[1], "Expand all")
        fold:__fire("OnClick")
        drawn = NS.WindowGroup.Drawn()
        assertEqual(collapsedHeaders(drawn), 0, mode .. ": every one open")
        assertEqual(#drawn.rows, 3, mode)
        assertEqual(textOf(fold.label), "Collapse all", mode)
        assertEqual(fold.art:GetTexture(), NS.Icon("chevron-up"), mode)
        assertEqual(NS.Window.TooltipOf(fold)[1], "Collapse all")
        fold:__fire("OnClick")
        drawn = NS.WindowGroup.Drawn()
        assertEqual(collapsedHeaders(drawn), 3, mode .. ": every one closed")
        assertEqual(#drawn.rows, 0, mode)
        assertEqual(textOf(fold.label), "Expand all", mode)
        drawn.headers[1]:__fire("OnClick")   -- one opened by hand: still one closed
        assertEqual(textOf(fold.label), "Expand all", mode)
    end
end)

test("footer row: the toggle is off when the tab shows no header", function()
    local NS = shownDrops()
    NS.WindowFilterBar.Set("group", "search", "nothing like it")
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.headers, 0)
    assertFalse(drawn.pane.summary.fold:IsEnabled())
    local _, hdrawn = shownHistory(nil, true)
    assertFalse(hdrawn.strip.fold:IsEnabled())
end)

test("footer row: the History toggle in both layouts, and each tab keeps its own collapsed state", function()
    for _, mode in ipairs({ "full", "compact" }) do
        local NS, drawn = shownHistory(mode)
        local fold = drawn.strip.fold
        assertEqual(collapsedHeaders(drawn), 1, mode)
        assertEqual(textOf(fold.label), "Expand all", mode)
        fold:__fire("OnClick")
        drawn = NS.WindowHistory.Drawn()
        assertEqual(collapsedHeaders(drawn), 0, mode)
        assertEqual(#drawn.rows, 3, mode)
        assertEqual(textOf(fold.label), "Collapse all", mode)
        fold:__fire("OnClick")
        assertEqual(collapsedHeaders(NS.WindowHistory.Drawn()), 2, mode)
        assertTrue(NS.State.windowGroup == nil or next(NS.State.windowGroup.collapsed or {}) == nil,
            mode .. ": Drops' state untouched")
    end
end)

-- ── one footer line: the status after the count (RX-09, rolls-UX spec §3.7) ─────────────────

-- A region's anchor of `point`: the frame it hangs from, its x and that frame's point.
local function pointOf(region, point)
    for _, pt in ipairs(region.__points or {}) do
        if pt[1] == point then return pt[2], pt[4], pt[3] end
    end
end

-- What a measured line draws, in characters (a UTF-8 character one), as the mock's textCharWidth counts.
local function chars(text) return #((text or ""):gsub("[\128-\191]", "")) end

test("footer row: the count's width and the status's room, pure (RX-09)", function()
    local FR = T.newAddon().FooterRow
    assertEqual(FR.InfoWidth("", 0, 300), 0, "nothing to say takes no room")
    assertEqual(FR.InfoWidth("", nil, 300), 0)
    assertEqual(FR.InfoWidth("2 tradeable", 55, 300), 55, "as wide as its words")
    assertEqual(FR.InfoWidth("2 tradeable", 55, 40), 40, "never past the row: cut with an ellipsis")
    assertEqual(FR.InfoWidth("2 tradeable", 55, 0), 55, "no width known yet: its words")
    assertEqual(FR.InfoWidth("2 tradeable", nil, 300), 300, "not measured: the whole room, as before")
    assertEqual(FR.InfoWidth("2 tradeable", nil, -5), 0, "not measured and no room known: none")
end)

test("footer row: the status is one line on Drops' strip, after the count, ending where the buttons start (RX-09)", function()
    local NS, drawn = shownDrops(nil, true)
    local K, WF, FR = NS.Constants.WINDOW, NS.WindowFooter, NS.FooterRow
    local strip = drawn.pane.summary
    local status = WF.Parts()
    -- red under: the status bar, four segments on the window's footer under the strip
    assertTrue(status ~= nil and status.text ~= nil, "one status line")
    assertTrue(status:GetParent() == strip, "on the strip, not a bar of its own")
    local text = textOf(status.text)
    assertEqual(text, WF.StatusText(WF.Read(), nil, false), "every segment's words, one line")
    assertTrue(text:find("^Inspect") and text:find(" · No loot seen yet · ", 1, true) and text:find("Pawn: off$"), text)
    assertFalse(status.text:GetWordWrap(), "one line")
    assertTrue(pointOf(status.text, "RIGHT") == status, "its words bounded: the game cuts them with an ellipsis")
    local rel, x, relPoint = pointOf(status, "LEFT")
    assertTrue(rel == strip.info and relPoint == "RIGHT", "after the tradeable count")
    assertEqual(x, FR.STATUS_GAP)
    local step = K.FOOTER_BUTTON_W + FR.GAP
    local rrel, rx = pointOf(status, "RIGHT")
    assertTrue(rrel == strip)
    assertEqual(rx, -(WF.SORT_INSET + 3 * step + K.FOOTER_BUTTON_W + FR.GAP), "it ends where Post starts")
    assertTrue(pointOf(strip.info, "RIGHT") == nil, "the count ends at its own words")
end)

test("footer row: the count keeps its words' width and the status the rest; narrow, the count is cut (RX-09)", function()
    local NS, drawn, m = shownDrops(nil, true)
    local FR = NS.FooterRow
    local strip = drawn.pane.summary
    local status = NS.WindowFooter.Parts()
    m.textCharWidth = 5
    strip:SetWidth(1200)
    NS.Window.Refresh()
    local words = chars(textOf(strip.info.text))
    assertTrue(words > 0)
    assertEqual(strip.info:GetWidth(), words * 5, "as wide as the count's words")
    assertEqual(select(2, pointOf(status, "LEFT")), FR.STATUS_GAP)
    local rowEnd = -select(2, pointOf(status, "RIGHT"))
    strip:SetWidth(rowEnd + 2 + 40)   -- 40 px of room: less than the count
    NS.Window.Refresh()
    assertEqual(strip.info:GetWidth(), 40, "the count cut at the row; the status has no room")
    m.textCharWidth = nil
end)

test("footer row: nothing tradeable, the status starts the line; compact, it is the short line (RX-09)", function()
    local NS, drawn = shownDrops("compact", false)
    local strip = drawn.pane.summary
    local status = NS.WindowFooter.Parts()
    assertTrue(status:GetParent() == strip)
    assertEqual(textOf(strip.info.text), "")
    assertEqual(strip.info:GetWidth(), 0)
    assertEqual(select(2, pointOf(status, "LEFT")), 0, "no gap before it")
    local WF = NS.WindowFooter
    assertEqual(textOf(status.text), NS.CompactChrome.FooterLine(WF.Read()), "compact's one line")
    NS.SetWindowMode("full")
    assertEqual(textOf(status.text), WF.StatusText(WF.Read(), nil, false))
end)

test("footer row: the status follows the active tab, and the strip it leaves takes its row back (RX-09)", function()
    local NS, hdrawn = shownHistory()
    local K, WF, FR = NS.Constants.WINDOW, NS.WindowFooter, NS.FooterRow
    local status = WF.Parts()
    local hstrip = hdrawn.strip
    assertTrue(status:GetParent() == hstrip, "on History's strip")
    assertTrue(pointOf(status, "LEFT") == hstrip.info)
    NS.Window.SelectTab("insights")
    local istrip = NS.WindowInsights.Drawn().strip
    assertTrue(status:GetParent() == istrip, "on Insights' strip")
    assertEqual(select(2, pointOf(status, "RIGHT")), -(FR.START + K.FOOTER_BUTTON_W + FR.GAP), "left of Reset filters")
    local rel, x = pointOf(hstrip.info, "RIGHT")
    assertTrue(rel == hstrip, "History's info spans its row again")
    assertEqual(x, -(WF.SORT_INSET + 2 * (K.FOOTER_BUTTON_W + FR.GAP)))
    NS.Window.SelectTab("group")
    assertTrue(status:GetParent() == NS.WindowGroup.Drawn().pane.summary, "back on Drops'")
end)

test("footer row: the status keeps its tooltip, every segment's words and reasons, rows then hints (RX-09)", function()
    local NS = T.enableAddon()
    NS.db.profile.situations.solo.track = false   -- Solo is tracked by default (DW-06); this reads an untracked one
    NS.ShowWindow()
    local status = NS.WindowFooter.Parts()
    local tip = NS.Window.TooltipOf(status)
    assertEqual(tip[1], "Status")
    local plain = {}
    for i = 2, #tip do plain[#plain + 1] = T.tipPlain(tip[i]) end
    local joined = table.concat(plain, "\n")
    for _, want in ipairs({ "• Inspect: no group", "• Group: none, so no one to inspect", "• No loot seen yet",
        "• Loot lines read: none this session", "• Not tracking in Solo · change in settings",
        "• Turned on in: Settings > Drops > Situations", "• Pawn: off", "• Verdicts: do not use it" }) do
        assertTrue(joined:find(want, 1, true) ~= nil, want)
    end
    assertEqual(plain[#plain], "If loot dropped and this stays, see /dw diagnostics.", "the hints close it")
    NS.SetWindowMode("compact")
    assertEqual(NS.Window.TooltipOf(status)[1], "Status", "the same tooltip in compact")
    assertTrue(#NS.Window.TooltipOf(status) == #tip)
end)

test("footer row: no status bar: the panes reach the footer band, whose corner holds the grip (RX-09)", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f, K, FR = NS.Window.Frame(), NS.Constants.WINDOW, NS.FooterRow
    -- red under: the panes ending K.FOOTER_H over the body's foot, over the status bar
    assertTrue(K.FOOTER_H == nil, "no status bar height")
    for key, pane in pairs(f.panes) do
        local rel, y = pane.__points[2][2], pane.__points[2][5]
        assertTrue(rel == f.body); assertEqual(y, 0, key .. " reaches the body's foot")
    end
    assertEqual(f.footerHost:GetHeight(), K.STRIP_H, "the band is the footer row's height")
    local grip = f.resizeGrip
    assertTrue(grip:GetParent() == f.footerHost, "the grip is the footer's")
    local p, rel = grip:GetPoint(1)
    assertEqual(p, "BOTTOMRIGHT"); assertTrue(rel == f.footerHost, "in its bottom-right corner")
    assertTrue(FR.START >= 17, "the row's first control clears the grip and its edge")
    assertEqual(NS.WindowFooter.SORT_INSET, FR.START)
    NS.SetLocked(true)
    assertFalse(grip:IsShown(), "locked: no grip (RX-08)")
    NS.SetLocked(false)
    assertTrue(grip:IsShown())
end)
