-- tests/test_drops_strip.lua — one tab for every drop, with the strip (feedback-5 spec §3, DW-E3):
-- the tab strip is Drops and History (the retired `mine` opens Drops); under the Drops table (or
-- its compact cards), above the footer, the summary strip (modules/DropsStrip.lua) counts your
-- drops the tab lists that you can still trade and names the next expiry, its next expiry moving
-- each second; Post my tradeables posts them. Both layouts always show it (feedback-15 spec §2):
-- full `[Post my tradeables] [Scan group] [Expand all] [Sort]`, compact `[Post my tradeables]
-- [Expand all]`, every button the one footer width with the same label; compact shortens the
-- summary. tests/test_footer_row.lua has the row and the toggle. Built headless under the mock.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRACERS = "|cffa335ee|Hitem:401::|h[Bracers of the Tide]|h|r"
local RING = "|cffa335ee|Hitem:402::|h[Band of Embers]|h|r"
local TRINKET = "|cffa335ee|Hitem:403::|h[Idol of Storms]|h|r"
local BOOTS = "|cffa335ee|Hitem:404::|h[Treads of Dawn]|h|r"

local NONE = {}
local NOW = 1000

local function cand(name, classFile, status, eval)
    return { guid = "Player-1-" .. name, name = name .. "-Realm", classFile = classFile, status = status, eval = eval }
end

-- Board 04's first row: your bracers, a downgrade for you, 1:47:12 left on the item's own timer,
-- an upgrade for Seta (+14) and Butterz (+6), equal for Littlewolf, unusable for Uniquerogue and
-- one member still being checked.
local function candidates()
    local list = {
        cand("Seta", "PRIEST", "ready", { verdict = "upgrade", ilvlDelta = 14, baseline = { ilvl = 291 }, reasons = {} }),
        cand("Butterz", "MAGE", "ready", { verdict = "upgrade", ilvlDelta = 6, baseline = { ilvl = 299 }, reasons = {} }),
        cand("Littlewolf", "ROGUE", "ready", { verdict = "sidegrade", ilvlDelta = 0, baseline = { ilvl = 305 }, reasons = {} }),
        cand("Uniquerogue", "ROGUE", "ready", { verdict = "cantUse", reasons = { { key = "armorType" } } }),
        cand("Fifth", "DRUID", "checking"),
    }
    local out = {}
    for _, c in ipairs(list) do out[c.guid] = c end
    return out
end

local function drop(over)
    local d = {
        id = 1, at = NOW - 700, link = BRACERS, isMine = true, sources = { chat = 1 },
        looter = { name = "Me-Realm", guid = "Player-1-ME", classFile = "PALADIN", isSelf = true },
        facts = { ilvl = 305, equipLoc = "INVTYPE_WRIST", quality = 4 },
        me = { verdict = "downgrade", ilvlDelta = -5, reasons = {} },
        trade = { state = "yes", reasonKey = "timer", basis = "timer", args = { 6432 }, expiresAt = NOW + 6432 },
        candidates = candidates(),
    }
    for k, v in pairs(over or {}) do
        if v == NONE then d[k] = nil else d[k] = v end
    end
    return d
end

local function groupOf(key, at, ids, roster)
    return { key = key, label = key, kind = "encounter", at = at, drops = ids, roster = roster,
        instance = "Zul'Aman", difficulty = "Heroic", seenBy = "Me-Realm", seenByClass = "PALADIN" }
end

local ROSTER = { { name = "Me", class = "PALADIN", me = true }, { name = "Seta", class = "PRIEST" } }

local function seed(NS, drops, groups)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    NS.LootFeed.Groups = function() return groups or {} end
end

-- Board 04's four rows.
local function boardDrops()
    return {
        drop(),
        drop({ id = 2, at = NOW - 1800, link = RING, facts = { ilvl = 298, equipLoc = "INVTYPE_FINGER", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 3, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 5405 } }),
        drop({ id = 3, at = NOW - 2000, link = TRINKET, facts = { ilvl = 305, equipLoc = "INVTYPE_TRINKET", quality = 4 },
            me = { verdict = "downgrade", ilvlDelta = -11, reasons = {} },
            trade = { state = "yes", reasonKey = "timer", basis = "timer", expiresAt = NOW + 521 },
            candidates = { x = cand("Littlewolf", "ROGUE", "ready", { verdict = "upgrade", ilvlDelta = 9, baseline = { ilvl = 296 }, reasons = {} }) } }),
        drop({ id = 4, at = NOW - 100, link = BOOTS, facts = { ilvl = 311, equipLoc = "INVTYPE_FEET", quality = 4 },
            me = { verdict = "upgrade", ilvlDelta = 6, reasons = {} },
            trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }),
    }
end

-- Your four drops on Drops (board 04's rows), every View value shown.
local function shownMine(compact)
    local NS, _, m = T.enableAddon()
    NS.addon.db.char = { session = { start = m.time() - 86400 } }   -- logged in a day ago: these drops are this session's (feedback-15 spec §1)
    m.__now = NOW
    seed(NS, boardDrops(), { groupOf("Den of Nalorakk", NOW - 3000, { 1, 2, 3, 4 }, ROSTER) })
    NS.Asks.StateOf = function() return "ready" end
    NS.WindowFilterBar.Set("group", "view", "all")
    if compact then NS.SetWindowMode("compact") end
    NS.ShowWindow()
    NS.Window.SelectTab("group")
    return NS, NS.WindowGroup.Drawn(), m
end

local function textOf(region) return region and region:GetText() end

local OTHER = { id = 9, at = NOW - 60, link = "|cffa335ee|Hitem:409::|h[Seta's Hood]|h|r", isMine = false,
    sources = { chat = 1 }, looter = { name = "Seta-Realm", guid = "Player-1-0000000A", classFile = "PRIEST" },
    facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
    me = { verdict = "upgrade", ilvlDelta = 19, reasons = {} }, them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
    trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 } }

-- The scroll frame's bottom edge over the pane's: its BOTTOMRIGHT anchor's y.
local function bottomOf(scroll)
    for i = 1, 4 do
        local point, _, _, _, y = scroll:GetPoint(i)
        if point == "BOTTOMRIGHT" then return y end
    end
end

-- ── the tabs ────────────────────────────────────────────────────────────────────────────────

test("drops tab: the tabs are Drops and History, and the retired `mine` opens Drops", function()
    local NS = shownMine()
    local W = NS.Window
    assertEqual(table.concat(W.TABS, ","), "group,history")
    local f = W.Frame()
    assertTrue(f.tabs.mine == nil and f.panes.mine == nil, "no third tab")
    assertEqual(textOf(f.tabs.group.label), "Drops", "no count on the label")
    assertEqual(textOf(f.tabs.history.label), "History")
    local tip = W.TooltipOf(f.tabs.group)
    assertEqual(tip[1], "Drops"); assertTrue(tip[2]:find("your own included", 1, true) ~= nil, tip[2])
    W.SelectTab("history")
    assertEqual(W.ActiveTab(), "history")
    assertTrue(W.SelectTab("mine"), "a stored `mine` still opens a tab")
    assertEqual(W.ActiveTab(), "group")
    assertFalse(W.SelectTab("nonsense"))
    assertEqual(NS.CompactChrome.TabText("group", true), "Drops")
    assertEqual(NS.CompactChrome.TabText("group", false), "Drops")
    assertTrue(NS.WindowMine == nil and NS.CompactMine == nil, "the tab's modules are gone")
    assertTrue(NS.WindowFilterBar.HONORS.mine == nil)
end)

-- ── the strip, full layout ──────────────────────────────────────────────────────────────────

test("drops strip: under the table, it counts your tradeable drops and the next expiry, Post beside it", function()
    local NS, drawn = shownMine()
    local K = NS.Constants.WINDOW
    local strip = drawn.pane.summary
    assertTrue(strip:IsShown())
    assertEqual(drawn.summary.count, 3, "the bonus roll is listed but not tradeable")
    assertEqual(textOf(strip.info.text), "3 tradeable · next expiry 0:08:41")
    assertEqual(textOf(strip.post.label), "Post my tradeables")
    assertTrue(#NS.Window.TooltipOf(strip.info) >= 2); assertTrue(#NS.Window.TooltipOf(strip.post) >= 2)
    local point, rel = strip:GetPoint(1)
    assertEqual(point, "BOTTOMLEFT"); assertTrue(rel == drawn.pane, "at the pane's foot, above the footer")
    assertEqual(bottomOf(drawn.pane.scroll), K.STRIP_H, "the table ends over it")
    assertEqual(#drawn.rows, 4, "the rows are the table's own")
end)

-- A button's one anchor: its point, the frame it hangs from and its x.
local function anchorOf(b)
    local point, rel, _, x = b:GetPoint(1)
    return point, rel, x
end

test("drops strip: one row, right-aligned: [Post my tradeables] [Scan group] [Expand all] [Sort] (feedback-15 spec §2)", function()
    local NS, drawn = shownMine()
    local K, WF, FR = NS.Constants.WINDOW, NS.WindowFooter, NS.FooterRow
    local strip = drawn.pane.summary
    local step = K.FOOTER_BUTTON_W + FR.GAP
    assertEqual(strip.post:GetWidth(), WF.SORT_W); assertEqual(strip.post:GetHeight(), K.CONTROL_H)
    local _, sort = WF.Parts()
    assertEqual(sort:GetWidth(), WF.SORT_W, "the same width as Post")
    assertTrue(sort:GetParent() == strip, "Sort on the strip, not the footer")
    local sp, srel, _, sx = sort:GetPoint(1)
    assertEqual(sp, "RIGHT"); assertTrue(srel == strip); assertEqual(sx, -WF.SORT_INSET, "at the strip's right edge")
    assertTrue(strip.scan:IsShown()); assertEqual(textOf(strip.scan.label), "Scan group")
    assertEqual(strip.scan:GetHeight(), K.CONTROL_H, "the same height")
    local p, rel, x = anchorOf(strip.scan)
    assertEqual(p, "RIGHT"); assertTrue(rel == strip)
    assertEqual(x, -(WF.SORT_INSET + 2 * step), "left of the toggle, which is left of Sort")
    assertEqual(select(3, anchorOf(strip.fold)), -(WF.SORT_INSET + step))
    p, rel, x = anchorOf(strip.post)
    assertEqual(p, "RIGHT"); assertTrue(rel == strip)
    assertEqual(x, -(WF.SORT_INSET + 3 * step), "immediately left of Scan group")
    assertEqual(NS.Window.TooltipOf(strip.scan)[1], "Scan group")
end)

test("drops strip: Sort follows the active tab to History's strip, after the toggle and Clear history, and back", function()
    local NS, drawn = shownMine()
    local WF, FR, K = NS.WindowFooter, NS.FooterRow, NS.Constants.WINDOW
    local _, sort = WF.Parts()
    NS.Window.SelectTab("history")
    local hstrip = NS.WindowHistory.Drawn().strip
    assertTrue(sort:GetParent() == hstrip, "on History's strip")
    local _, rel, _, x = sort:GetPoint(1)
    assertTrue(rel == hstrip); assertEqual(x, -WF.SORT_INSET)
    local _, crel, _, cx = hstrip.clear:GetPoint(1)
    assertTrue(crel == hstrip)
    assertEqual(cx, -(WF.SORT_INSET + 2 * (K.FOOTER_BUTTON_W + FR.GAP)), "Clear history left of the toggle, left of Sort")
    NS.Window.SelectTab("group")
    assertTrue(sort:GetParent() == drawn.pane.summary, "back on Drops' strip")
end)

test("drops strip: Scan group goes through the shared handler", function()
    local NS, drawn = shownMine()
    local scanned = 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    drawn.pane.summary.scan:__fire("OnClick")
    assertEqual(scanned, 1)
end)

test("drops strip: the row, pure: full Sort, the toggle, Scan group, Post; compact the toggle and Post", function()
    local NS = T.enableAddon()
    local DS = NS.DropsStrip
    local function keys(row)
        local out = {}
        for _, c in ipairs(row) do out[#out + 1] = c.key .. (c.shown == false and "-" or "") end
        return table.concat(out, ",")
    end
    assertEqual(keys(DS.Row(true, false)), "sort,fold,scan,post")
    assertEqual(keys(DS.Row(false, false)), "sort,fold,scan,post-", "Post hidden, the rest keep their places")
    assertEqual(keys(DS.Row(true, true)), "fold,post")
    assertEqual(keys(DS.Row(false, true)), "fold,post-")
end)

test("drops strip: full layout, nothing tradeable: shown with Scan group beside Sort, no summary", function()
    local NS, _, m = T.enableAddon()
    NS.addon.db.char = { session = { start = m.time() - 86400 } }   -- logged in a day ago: these drops are this session's (feedback-15 spec §1)
    m.__now = NOW
    local WF = NS.WindowFooter
    local dead = drop({ id = 4, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } })
    seed(NS, { dead, OTHER }, { groupOf("Boss", NOW - 3000, { 4, 9 }, ROSTER) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    local strip = drawn.pane.summary
    assertEqual(#drawn.rows, 2)
    assertTrue(strip:IsShown(), "Scan group lives here"); assertTrue(drawn.summary == nil)
    assertEqual(textOf(strip.info.text), ""); assertEqual(#NS.Window.TooltipOf(strip.info), 0)
    assertFalse(strip.post:IsShown())
    assertTrue(strip.scan:IsShown())
    local _, _, x = anchorOf(strip.scan)
    local step = NS.Constants.WINDOW.FOOTER_BUTTON_W + NS.FooterRow.GAP
    assertEqual(x, -(WF.SORT_INSET + 2 * step), "Scan group stays beside the toggle")
    assertEqual(bottomOf(drawn.pane.scroll), NS.Constants.WINDOW.STRIP_H)
    seed(NS, { drop(), OTHER }, { groupOf("Boss", NOW - 3000, { 1, 9 }, ROSTER) })
    NS.Window.Refresh()
    assertTrue(strip.post:IsShown())
    _, _, x = anchorOf(strip.scan)
    assertEqual(x, -(WF.SORT_INSET + 2 * step), "still in its place, Post beside it")
end)

test("drops strip: compact, shown while none of your listed drops can be traded: no summary, no Post (feedback-15 spec §2)", function()
    local NS, _, m = T.enableAddon()
    NS.addon.db.char = { session = { start = m.time() - 86400 } }   -- logged in a day ago: these drops are this session's (feedback-15 spec §1)
    m.__now = NOW
    local dead = drop({ id = 4, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } })
    seed(NS, { dead, OTHER }, { groupOf("Boss", NOW - 3000, { 4, 9 }, ROSTER) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.SetWindowMode("compact")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact)
    assertTrue(drawn.pane.summary:IsShown(), "the toggle lives there"); assertTrue(drawn.summary == nil)
    assertFalse(drawn.pane.summary.post:IsShown())
    assertEqual(bottomOf(drawn.scroll), NS.Constants.WINDOW.STRIP_H, "the cards end over it")
    NS.SetWindowMode("full")
    seed(NS, { drop(), OTHER }, { groupOf("Boss", NOW - 3000, { 1, 9 }, ROSTER) })
    NS.Window.Refresh()
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.pane.summary:IsShown())
    assertEqual(textOf(drawn.pane.summary.info.text), "1 tradeable · next expiry 1:47:12", "another player's drop is not counted")
    assertEqual(bottomOf(drawn.pane.scroll), NS.Constants.WINDOW.STRIP_H)
end)

test("drops strip: it counts the drops the tab lists, its filters applied, collapsed or not", function()
    local NS, drawn = shownMine()
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 0, "collapsed")
    assertEqual(drawn.summary.text, "3 tradeable · next expiry 0:08:41", "the strip still counts them")
    NS.WindowFilterBar.Set("group", "search", "Bracers")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(drawn.summary.text, "1 tradeable · next expiry 1:47:12")
    NS.WindowFilterBar.Set("group", "search", "nothing like it")
    drawn = NS.WindowGroup.Drawn()
    assertFalse(drawn.pane.summary.post:IsShown(), "none listed: no Post")
    assertTrue(drawn.summary == nil)
    assertTrue(drawn.pane.placeholder:IsShown())
end)

test("drops strip: its next expiry moves each second with the countdowns", function()
    local NS, drawn, m = shownMine()
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(textOf(drawn.pane.summary.info.text), "3 tradeable · next expiry 0:08:29")
    m.advance(1)   -- the countdown ticker, a second on
    assertEqual(textOf(drawn.pane.summary.info.text), "3 tradeable · next expiry 0:08:28")
end)

test("drops strip: its next expiry keeps the each-second ticker running with no row's countdown drawn", function()
    local NS, drawn, m = shownMine()
    local function tickers()
        local n = 0
        for _, t in ipairs(m.__timers) do
            if t.ticker and not t.stopped and t.delay == NS.Constants.WINDOW.COUNTDOWN_TICK then n = n + 1 end
        end
        return n
    end
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 0, "collapsed: no row draws a countdown")
    assertTrue(NS.WindowGroup.LiveCountdown(), "the strip still shows one"); assertEqual(tickers(), 1)
    NS.SchemaRuntime.Set("window.columns.tradeWindow", false)
    NS.Window.Refresh()
    assertTrue(NS.WindowGroup.LiveCountdown(), "with the column off too"); assertEqual(tickers(), 1)
    m.advance(1)
    assertEqual(textOf(drawn.pane.summary.info.text), "3 tradeable · next expiry 0:08:40")
end)

test("drops strip: Post my tradeables goes through the shared handler", function()
    local NS, drawn = shownMine()
    local sent = {}
    NS.Asks.Request = function(kind, _, id, opts) sent[#sent + 1] = { kind = kind, id = id, text = opts.text }; return "sent" end
    drawn.pane.summary.post:__fire("OnClick")
    assertEqual(#sent, 1); assertEqual(sent[1].kind, "announce")
    assertEqual(sent[1].text, "Up for trade, whisper me: " .. BRACERS .. " " .. RING .. " " .. TRINKET)
end)

-- ── the strip, compact layout ───────────────────────────────────────────────────────────────

test("drops strip: under the compact cards, the summary shortened, Post my tradeables as in the full layout", function()
    local NS, drawn = shownMine(true)
    local K, FR = NS.Constants.WINDOW, NS.FooterRow
    assertTrue(drawn.compact)
    local strip = drawn.pane.summary
    assertTrue(strip:IsShown())
    assertEqual(textOf(strip.info.text), "3 tradeable · next 0:08:41")
    assertEqual(textOf(strip.post.label), "Post my tradeables"); assertEqual(strip.post:GetWidth(), K.FOOTER_BUTTON_W)
    assertEqual(select(3, anchorOf(strip.post)), -(K.FOOTER_BUTTON_W + FR.GAP), "left of the toggle")
    assertFalse(strip.scan:IsShown(), "compact's Scan group is the title bar's icon")
    assertEqual(NS.Window.TooltipOf(strip.post)[1], "Post my tradeables", "the tooltip is unchanged")
    assertEqual(drawn.summary.count, 3)
    assertEqual(bottomOf(drawn.scroll), K.STRIP_H, "the cards end over it")
    NS.SetWindowMode("full")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == nil and #drawn.rows == 4, "the table again")
    assertEqual(textOf(strip.info.text), "3 tradeable · next expiry 0:08:41")
    assertEqual(textOf(strip.post.label), "Post my tradeables"); assertEqual(strip.post:GetWidth(), NS.WindowFooter.SORT_W)
    assertTrue(strip.scan:IsShown())
end)

test("drops strip: the compact countdown tick moves its next expiry too", function()
    local NS, drawn, m = shownMine(true)
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(textOf(drawn.pane.summary.info.text), "3 tradeable · next 0:08:29")
end)
