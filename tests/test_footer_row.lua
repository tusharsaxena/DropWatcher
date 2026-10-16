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
    local irel, ix = rightOf(strip.info)
    assertTrue(irel == strip, "the info ends where the buttons start")
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
    assertEqual(select(3, anchorOf(strip.fold)), 0)
    assertEqual(select(3, anchorOf(strip.scan)), -step, "Scan group beside the toggle, as in full")
    assertEqual(NS.Window.TooltipOf(strip.scan)[1], "Scan group", "the tooltip names it")
    assertFalse(strip.post:IsShown())
    assertEqual(select(2, rightOf(strip.info)), -(2 * step))
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
    assertEqual(select(3, anchorOf(strip.post)), -(2 * step))
    assertEqual(select(2, rightOf(strip.info)), -(3 * step))
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
    assertTrue((rightOf(strip.info)) == strip)
    assertEqual(select(2, rightOf(strip.info)), -(WF.SORT_INSET + step + K.FOOTER_BUTTON_W + FR.GAP))
    NS.SetWindowMode("compact")
    assertTrue(NS.WindowHistory.Drawn().compact == true)
    assertEqual(select(3, anchorOf(strip.fold)), 0)
    assertEqual(strip.fold:GetWidth(), K.FOOTER_ICON_W, "icon only in compact")
    assertFalse(strip.fold.label:IsShown())
    assertEqual(select(2, rightOf(strip.info)), -(K.FOOTER_ICON_W + FR.GAP))
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
