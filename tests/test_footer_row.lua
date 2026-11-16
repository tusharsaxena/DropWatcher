-- tests/test_footer_row.lua — the window's footer on the library's lines and marks (RX-24,
-- WowAddonStandards v2.110.0 standalone-windows' *The footer*, anti-pattern #118): the words are
-- W.Footer's own left line (the active tab's info, then the status line, one line the library cuts
-- with an ellipsis), the controls are its `marks` slot, catalog icon buttons with tooltips, right to
-- left from the grip's corner: Drops the toggle, Scan group and Post my tradeables (only while one
-- of your listed drops can be traded), History the toggle, Insights Reset filters; the same marks
-- in both layouts. Nothing of the host's is laid over the footer but the line's tooltip host. The
-- toggle reads `Expand all` while a header the filters show is collapsed and `Collapse all` once
-- every one is open, sets every shown header of the active tab, and is off with none. Built
-- headless under the mock (modules/FooterRow.lua, modules/WindowFooter.lua).

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
-- tradeable drop of yours in the newest. `opts.record` collects every frame built from here on.
local function shownDrops(mode, mine, record)
    local NS, _, m = T.enableAddon()
    T.withPlayer(m)   -- someone to post to (DW-07)
    NS.addon.db.char = { session = { start = m.time() - DAY } }   -- logged in a day ago (feedback-15 spec §1)
    m.__now = NOW
    if record then
        local real = m.CreateFrame
        m.CreateFrame = function(...)
            local f = real(...)
            record[#record + 1] = f
            return f
        end
    end
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

-- The footer's shown marks' control keys, right to left from the corner.
local function markKeys(NS) return table.concat(NS.FooterRow.Shown(), ",") end

local function collapsedHeaders(drawn)
    local n = 0
    for _, e in ipairs(drawn.entries) do
        if e.kind == "header" and e.collapsed then n = n + 1 end
    end
    return n
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

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

test("footer row: the line, pure: the tab's info, then the status; the status alone with no info (RX-24)", function()
    local WF = T.enableAddon().WindowFooter
    -- red under: no WF.LineText (the status rode a host font string after the strip's own words)
    assertEqual(WF.LineText("2 tradeable", "Inspect 3/4"), "2 tradeable · Inspect 3/4")
    assertEqual(WF.LineText("", "Inspect 3/4"), "Inspect 3/4")
    assertEqual(WF.LineText(nil, "Inspect 3/4"), "Inspect 3/4")
end)

test("footer row: the line's tooltip, pure: the info's lines, then every status row and hint (RX-24)", function()
    local NS = T.enableAddon()
    local WF = NS.WindowFooter
    local read = { members = 0, situation = "solo", tracking = true, pawn = "off" }
    local status = WF.StatusTip(read)
    local plain = WF.LineTip(nil, read)
    assertEqual(plain[1], "Status", "no info: the status tooltip")
    assertEqual(#plain, #status)
    local tip = WF.LineTip({ "Your tradeable drops", NS.TipMarks.Row("Tradeable", 2) }, read)
    assertEqual(tip[1], "Your tradeable drops", "the info's title first")
    assertEqual(T.tipPlain(tip[2]), "• Tradeable: 2")
    assertEqual(#tip, 2 + #status - 1, "then every status line but its title")
    assertEqual(T.tipPlain(tip[3]), "• Inspect: no group")
end)

-- ── the footer is the library's ─────────────────────────────────────────────────────────────

test("footer row: the footer is W.Footer; nothing of the host's is laid over it but the line's tooltip host (RX-24)", function()
    local record = {}
    local NS = shownDrops(nil, true, record)
    local f = NS.Window.Frame()
    local foot = f.footerHost
    local line = NS.WindowFooter.Parts()
    assertTrue(foot.line ~= nil and foot.left ~= nil and foot.right ~= nil and foot.SetLeft ~= nil, "built by W.Footer")
    assertEqual(foot:GetHeight(), NS.FooterMetric("HEIGHT"))
    assertEqual(#foot.marks, NS.FooterRow.SLOTS, "the control slot is the library's marks")
    -- red under: the tab strips' 150 px labeled buttons and font strings over the footer
    local mark = {}
    for _, b in ipairs(foot.marks) do mark[b] = true end
    local over = 0
    for _, fr in ipairs(record) do
        local p = fr:GetParent()
        if p == foot and not mark[fr] and fr ~= f.resizeGrip and fr ~= line then over = over + 1 end
    end
    assertEqual(over, 0, "no host frame on the footer")
    assertEqual(#line.__regions, 0, "the tooltip host draws nothing")
    assertTrue(line.text == foot.left, "the words are the footer's own left line")
    for _, pane in pairs(f.panes) do
        assertTrue(pane.summary == nil and pane.strip == nil, "no tab strip under the footer")
    end
    assertTrue(NS.Constants.WINDOW.FOOTER_BUTTON_W == nil, "no labeled footer button width")
end)

test("footer row: the footer's words, both layouts: the tab's info then the status, through foot:SetLeft (RX-24)", function()
    local NS = shownDrops(nil, true)
    local WF = NS.WindowFooter
    local foot = NS.Window.Frame().footerHost
    local text = textOf(foot.left)
    -- red under: the status a font string of the host's after the strip's info
    assertEqual(text, "1 tradeable · next expiry 0:10:00 · " .. WF.StatusText(WF.Read(), nil, false))
    assertTrue(text:find("Pawn: off$") ~= nil, text)
    assertEqual(textOf(foot.right), "", "the right line unused on the window")
    NS.SetWindowMode("compact")
    assertEqual(textOf(foot.left), "1 tradeable · next 0:10:00 · " .. NS.CompactChrome.FooterLine(WF.Read()), "compact's short words")
end)

test("footer row: nothing tradeable, the status starts the line; it follows the active tab (RX-24)", function()
    local NS = shownDrops(nil, false)
    local WF = NS.WindowFooter
    local foot = NS.Window.Frame().footerHost
    local status = WF.StatusText(WF.Read(), nil, false)
    assertEqual(textOf(foot.left), status)
    NS.Window.SelectTab("history")
    local hist = textOf(foot.left)
    assertTrue(hist:sub(-#status) == status and #hist > #status, "History's kept-history line, then the status")
    NS.Window.SelectTab("insights")
    assertTrue(textOf(foot.left):find(" · " .. status, 1, true) ~= nil, "Insights' period, then the status")
    NS.Window.SelectTab("group")
    assertEqual(textOf(foot.left), status, "back on Drops")
end)

test("footer row: the line keeps its tooltip: the info's rows, then every segment's words and reasons (RX-24)", function()
    local NS = T.enableAddon()
    NS.db.profile.situations.solo.track = false   -- Solo is tracked by default (DW-06); this reads an untracked one
    NS.ShowWindow()
    local line = NS.WindowFooter.Parts()
    local tip = NS.Window.TooltipOf(line)
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
    assertEqual(NS.Window.TooltipOf(line)[1], "Status", "the same tooltip in compact")
end)

-- ── the marks ───────────────────────────────────────────────────────────────────────────────

test("footer row: Drops' marks, right to left: the toggle, Scan group, Post my tradeables, each a tooltip (RX-24)", function()
    local NS = shownDrops(nil, true)
    local FR = NS.FooterRow
    -- red under: no marks (the strip's labeled buttons)
    assertEqual(markKeys(NS), "fold,scan,post")
    local foot = NS.Window.Frame().footerHost
    assertTrue(FR.Mark("fold") == foot.marks[1], "the toggle in the corner")
    assertTrue(FR.Mark("scan") == foot.marks[2] and FR.Mark("post") == foot.marks[3])
    assertEqual(FR.Mark("scan").icon:GetTexture(), NS.Icon("people"))
    assertEqual(FR.Mark("post").icon:GetTexture(), NS.Icon("speech-bubble"))
    assertEqual(FR.Mark("scan"):GetWidth(), foot.marks[1]:GetWidth(), "one size")
    assertEqual(NS.Window.TooltipOf(FR.Mark("scan"))[1], "Scan group")
    assertEqual(NS.Window.TooltipOf(FR.Mark("post"))[1], "Post my tradeables")
    assertTrue(#NS.Window.TooltipOf(FR.Mark("post")) >= 2, "with a reason")
    assertEqual(NS.Window.TooltipOf(FR.Mark("fold"))[1], "Expand all")
end)

test("footer row: Post my tradeables shows only while something of yours is tradeable; compact the same marks (RX-24)", function()
    local NS = shownDrops(nil, false)
    local FR = NS.FooterRow
    assertEqual(markKeys(NS), "fold,scan")
    assertFalse(NS.Window.Frame().footerHost.marks[3]:IsShown(), "the spare mark hidden")
    assertTrue(FR.Mark("post") == nil)
    NS.SetWindowMode("compact")
    assertEqual(markKeys(NS), "fold,scan", "compact: the same marks")
    NS = shownDrops("compact", true)
    assertEqual(markKeys(NS), "fold,scan,post")
end)

test("footer row: each mark does what its button did: Scan group, Post my tradeables (RX-24)", function()
    local NS = shownDrops(nil, true)
    local FR = NS.FooterRow
    local scanned, posted = 0, 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    NS.PostTradeables = function() posted = posted + 1 end
    FR.Mark("scan"):__fire("OnClick", "LeftButton")
    FR.Mark("post"):__fire("OnClick", "LeftButton")
    assertEqual(scanned, 1); assertEqual(posted, 1)
end)

test("footer row: History's mark is the toggle; Insights' is Reset filters, which resets them (RX-24)", function()
    local NS = shownHistory()
    assertEqual(markKeys(NS), "fold")
    NS.Window.SelectTab("insights")
    local FR = NS.FooterRow
    assertEqual(markKeys(NS), "reset")
    assertEqual(FR.Mark("reset").icon:GetTexture(), NS.Icon("reset"))
    assertEqual(NS.Window.TooltipOf(FR.Mark("reset"))[1], "Reset filters")
    local reset = 0
    NS.WindowInsights.ResetFilters = function() reset = reset + 1 end
    FR.Mark("reset"):__fire("OnClick", "LeftButton")
    assertEqual(reset, 1)
    NS.Window.SelectTab("group")
    assertEqual(markKeys(NS), "fold,scan")
end)

-- ── Expand all / Collapse all ───────────────────────────────────────────────────────────────

test("footer row: the Drops toggle opens every shown header, then closes them, in both layouts", function()
    for _, mode in ipairs({ "full", "compact" }) do
        local NS, drawn = shownDrops(mode)
        local fold = NS.FooterRow.Mark("fold")
        assertEqual(collapsedHeaders(drawn), 2, mode .. ": the older two collapsed by default")
        assertEqual(NS.Window.TooltipOf(fold)[1], "Expand all", mode)
        -- red under: the expand-down / collapse-up marks (feedback-16 picks the chevrons)
        assertEqual(fold.icon:GetTexture(), NS.Icon("chevron-down"), mode)
        assertTrue(fold:IsEnabled())
        fold:__fire("OnClick", "LeftButton")
        drawn = NS.WindowGroup.Drawn()
        assertEqual(collapsedHeaders(drawn), 0, mode .. ": every one open")
        assertEqual(#drawn.rows, 3, mode)
        assertEqual(NS.Window.TooltipOf(fold)[1], "Collapse all", mode)
        assertEqual(fold.icon:GetTexture(), NS.Icon("chevron-up"), mode)
        fold:__fire("OnClick", "LeftButton")
        drawn = NS.WindowGroup.Drawn()
        assertEqual(collapsedHeaders(drawn), 3, mode .. ": every one closed")
        assertEqual(#drawn.rows, 0, mode)
        assertEqual(NS.Window.TooltipOf(fold)[1], "Expand all", mode)
        drawn.headers[1]:__fire("OnClick")   -- one opened by hand: still one closed
        assertEqual(NS.Window.TooltipOf(fold)[1], "Expand all", mode)
    end
end)

-- red under: the mark's tooltip read once on enter, so a press under the pointer left it stale (RX-28)
test("footer row: a press on the toggle under the pointer turns its open tooltip to the new state", function()
    local NS, _, m = shownDrops()
    local fold = NS.FooterRow.Mark("fold")
    fold:__fire("OnEnter")
    assertEqual(m.GameTooltip.__lines[1].text, "Expand all")
    fold:__fire("OnClick", "LeftButton")
    assertEqual(m.GameTooltip.__lines[1].text, "Collapse all", "the shown tooltip follows the press")
    fold:__fire("OnLeave")
end)

test("footer row: the toggle is off when the tab shows no header", function()
    local NS = shownDrops()
    NS.WindowFilterBar.Set("group", "search", "nothing like it")
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.headers, 0)
    local fold = NS.FooterRow.Mark("fold")
    assertFalse(fold:IsEnabled())
    local collapsed = collapsedHeaders(drawn)
    fold:__fire("OnClick", "LeftButton")
    assertEqual(collapsedHeaders(NS.WindowGroup.Drawn()), collapsed, "an off toggle does nothing")
    NS = shownHistory(nil, true)
    assertFalse(NS.FooterRow.Mark("fold"):IsEnabled())
end)

test("footer row: the History toggle in both layouts, and each tab keeps its own collapsed state", function()
    for _, mode in ipairs({ "full", "compact" }) do
        local NS, drawn = shownHistory(mode)
        local fold = NS.FooterRow.Mark("fold")
        assertEqual(collapsedHeaders(drawn), 1, mode)
        assertEqual(NS.Window.TooltipOf(fold)[1], "Expand all", mode)
        fold:__fire("OnClick", "LeftButton")
        drawn = NS.WindowHistory.Drawn()
        assertEqual(collapsedHeaders(drawn), 0, mode)
        assertEqual(#drawn.rows, 3, mode)
        assertEqual(NS.Window.TooltipOf(fold)[1], "Collapse all", mode)
        fold:__fire("OnClick", "LeftButton")
        assertEqual(collapsedHeaders(NS.WindowHistory.Drawn()), 2, mode)
        assertTrue(NS.State.windowGroup == nil or next(NS.State.windowGroup.collapsed or {}) == nil,
            mode .. ": Drops' state untouched")
    end
end)

-- ── the grip's corner ───────────────────────────────────────────────────────────────────────

test("footer row: the panes reach the footer, whose corner holds the grip; locked still hides it (RX-24)", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local f = NS.Window.Frame()
    for key, pane in pairs(f.panes) do
        local rel, y = pane.__points[2][2], pane.__points[2][5]
        assertTrue(rel == f.body); assertEqual(y, 0, key .. " reaches the body's foot")
    end
    local H = NS.FooterMetric("HEIGHT")
    assertEqual(H, 24)
    assertEqual(f.footerHost:GetHeight(), H, "the library's footer, FOOTER.HEIGHT")
    assertTrue(f.footerHost.bg == nil, "no fill band")
    local grip = f.resizeGrip
    assertTrue(grip:GetParent() == f.footerHost, "the grip is the footer's")
    local p, rel = grip:GetPoint(1)
    assertEqual(p, "BOTTOMRIGHT"); assertTrue(rel == f.footerHost, "in its bottom-right corner")
    local mp, mrel, _, mx = f.footerHost.marks[1]:GetPoint(1)
    assertEqual(mp, "RIGHT"); assertTrue(mrel == f.footerHost)
    assertEqual(mx, -NS.FooterMetric("GRIP"), "the first mark clears the grip")
    NS.SetLocked(true)
    assertFalse(grip:IsShown(), "locked: no grip (RX-08)")
    assertEqual(select(4, f.footerHost.marks[1]:GetPoint(1)), -NS.FooterMetric("PAD"), "the marks take the corner back")
    NS.SetLocked(false)
    assertTrue(grip:IsShown())
end)
