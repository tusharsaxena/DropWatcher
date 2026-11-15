-- tests/test_drops_strip.lua — one tab for every drop, with its summary (feedback-5 spec §3, DW-E3):
-- the tab strip is Drops, History and Insights (the retired `mine` opens Drops); the Drops tab's words
-- on the window's footer (modules/DropsStrip.lua; RX-24, the footer's own left line) count your drops
-- the tab lists that you can still trade and name the next expiry, its next expiry moving each
-- second; the footer's Post my tradeables mark posts them. Both layouts lay the same marks, right to
-- left the toggle, Scan group and Post (only while something is tradeable); compact shortens the
-- summary. tests/test_footer_row.lua has the footer, its marks and the toggle. Built headless under
-- the mock.

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
    T.withPlayer(m)   -- someone to offer to (DW-07)
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

test("drops tab: the tabs are Drops, History and Insights, and the retired `mine` opens Drops", function()
    local NS = shownMine()
    local W = NS.Window
    assertEqual(table.concat(W.TABS, ","), "group,history,insights")
    local f = W.Frame()
    assertTrue(f.tabs.mine == nil and f.panes.mine == nil, "no My drops tab")
    assertEqual(textOf(f.tabs.group.label), "Drops", "no count on the label")
    assertEqual(textOf(f.tabs.history.label), "History")
    local tip = W.TooltipOf(f.tabs.group)
    assertEqual(tip[1], "Drops"); assertEqual(T.tipPlain(tip[2]), "• Holds: every drop your group receives, yours included")
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

-- ── the summary on the footer, full layout ──────────────────────────────────────────────────

-- The window footer's left line, and the tab's own words on it.
local function lineOf(NS) return textOf(NS.Window.Frame().footerHost.left) end
local function infoOf(drawn) return drawn.pane.foot.info end

test("drops strip: the footer counts your tradeable drops and the next expiry, Post beside it (RX-24)", function()
    local NS, drawn = shownMine()
    assertEqual(drawn.summary.count, 3, "the bonus roll is listed but not tradeable")
    assertEqual(infoOf(drawn), "3 tradeable · next expiry 0:08:41")
    assertTrue(lineOf(NS):find("^3 tradeable · next expiry 0:08:41 · ") ~= nil, "the footer's own line, first")
    local post = NS.FooterRow.Mark("post")
    assertTrue(post ~= nil and post:IsShown())
    assertTrue(#NS.Window.TooltipOf(NS.WindowFooter.Parts()) >= 2); assertTrue(#NS.Window.TooltipOf(post) >= 2)
    assertEqual(NS.Window.TooltipOf(NS.WindowFooter.Parts())[1], "Your tradeable drops", "the count's tooltip first")
    assertEqual(bottomOf(drawn.pane.scroll), NS.FooterMetric("HEIGHT"), "the table ends over the footer")
    assertEqual(#drawn.rows, 4, "the rows are the table's own")
end)

test("drops strip: Scan group goes through the shared handler", function()
    local NS = shownMine()
    local scanned = 0
    NS.ScanGroup = function() scanned = scanned + 1 end
    NS.FooterRow.Mark("scan"):__fire("OnClick", "LeftButton")
    assertEqual(scanned, 1)
end)

test("drops strip: full layout, nothing tradeable: Scan group and the toggle, no count, no Post", function()
    local NS, _, m = T.enableAddon()
    T.withPlayer(m)   -- someone to post to (DW-07)
    NS.addon.db.char = { session = { start = m.time() - 86400 } }   -- logged in a day ago: these drops are this session's (feedback-15 spec §1)
    m.__now = NOW
    local dead = drop({ id = 4, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } })
    seed(NS, { dead, OTHER }, { groupOf("Boss", NOW - 3000, { 4, 9 }, ROSTER) })
    NS.WindowFilterBar.Set("group", "view", "all")
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 2)
    assertTrue(drawn.summary == nil)
    assertEqual(infoOf(drawn), ""); assertTrue(drawn.pane.foot.tip == nil)
    assertEqual(table.concat(NS.FooterRow.Shown(), ","), "fold,scan")
    assertEqual(bottomOf(drawn.pane.scroll), NS.FooterMetric("HEIGHT"))
    seed(NS, { drop(), OTHER }, { groupOf("Boss", NOW - 3000, { 1, 9 }, ROSTER) })
    NS.Window.Refresh()
    assertEqual(table.concat(NS.FooterRow.Shown(), ","), "fold,scan,post", "Post beside Scan group")
end)

test("drops strip: a repaint that changes nothing re-binds no mark; Post coming or going does", function()
    local NS = shownMine(false)
    local foot = NS.Window.Frame().footerHost
    local sets = 0
    for _, b in ipairs(foot.marks) do
        local real = b.icon.SetTexture
        b.icon.SetTexture = function(self, ...) sets = sets + 1; return real(self, ...) end
    end
    -- red under: every repaint re-binding the three marks' art
    NS.Window.Refresh(); NS.Window.Refresh()
    assertEqual(sets, 0, "the refresh's allocation ceiling (docs/performance.md)")
    seed(NS, { drop({ id = 4, trade = { state = "no", reasonKey = "bonusRoll", basis = "bind" } }) },
        { groupOf("Boss", NOW - 3000, { 4 }, ROSTER) })
    NS.Window.Refresh()
    assertFalse(foot.marks[3]:IsShown(), "nothing tradeable any more: Post gone")
end)

test("drops strip: compact, none of your listed drops can be traded: no count, no Post (feedback-15 spec §2)", function()
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
    assertTrue(drawn.summary == nil)
    assertTrue(NS.FooterRow.Mark("post") == nil)
    assertEqual(bottomOf(drawn.scroll), NS.FooterMetric("HEIGHT"), "the cards end over the footer")
    NS.SetWindowMode("full")
    seed(NS, { drop(), OTHER }, { groupOf("Boss", NOW - 3000, { 1, 9 }, ROSTER) })
    NS.Window.Refresh()
    drawn = NS.WindowGroup.Drawn()
    assertEqual(infoOf(drawn), "1 tradeable · next expiry 1:47:12", "another player's drop is not counted")
    assertEqual(bottomOf(drawn.pane.scroll), NS.FooterMetric("HEIGHT"))
end)

test("drops strip: it counts the drops the tab lists, its filters applied, collapsed or not", function()
    local NS, drawn = shownMine()
    drawn.headers[1]:__fire("OnClick")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(#drawn.rows, 0, "collapsed")
    assertEqual(drawn.summary.text, "3 tradeable · next expiry 0:08:41", "the footer still counts them")
    NS.WindowFilterBar.Set("group", "search", "Bracers")
    drawn = NS.WindowGroup.Drawn()
    assertEqual(drawn.summary.text, "1 tradeable · next expiry 1:47:12")
    NS.WindowFilterBar.Set("group", "search", "nothing like it")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(NS.FooterRow.Mark("post") == nil, "none listed: no Post")
    assertTrue(drawn.summary == nil)
    assertTrue(drawn.pane.placeholder:IsShown())
end)

test("drops strip: its next expiry moves each second with the countdowns, on the footer's line", function()
    local NS, drawn, m = shownMine()
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(infoOf(drawn), "3 tradeable · next expiry 0:08:29")
    m.advance(1)   -- the countdown ticker, a second on
    assertEqual(infoOf(drawn), "3 tradeable · next expiry 0:08:28")
    assertTrue(lineOf(NS):find("^3 tradeable · next expiry 0:08:28 · ") ~= nil, lineOf(NS))
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
    assertTrue(NS.WindowGroup.LiveCountdown(), "the footer still shows one"); assertEqual(tickers(), 1)
    NS.SchemaRuntime.Set("window.columns.tradeWindow", false)
    NS.Window.Refresh()
    assertTrue(NS.WindowGroup.LiveCountdown(), "with the column off too"); assertEqual(tickers(), 1)
    m.advance(1)
    assertEqual(infoOf(drawn), "3 tradeable · next expiry 0:08:40")
end)

test("drops strip: Post my tradeables goes through the shared handler", function()
    local NS = shownMine()
    local sent = {}
    NS.Asks.Request = function(kind, _, id, opts) sent[#sent + 1] = { kind = kind, id = id, text = opts.text }; return "sent" end
    NS.FooterRow.Mark("post"):__fire("OnClick", "LeftButton")
    assertEqual(#sent, 1); assertEqual(sent[1].kind, "announce")
    assertEqual(sent[1].text, "Up for trade, whisper me: " .. BRACERS .. " " .. RING .. " " .. TRINKET)
end)

-- ── the summary, compact layout ─────────────────────────────────────────────────────────────

test("drops strip: under the compact cards, the summary shortened, the same marks", function()
    local NS, drawn = shownMine(true)
    assertTrue(drawn.compact)
    assertEqual(infoOf(drawn), "3 tradeable · next 0:08:41")
    assertEqual(table.concat(NS.FooterRow.Shown(), ","), "fold,scan,post", "Scan group and Post, as in full (feedback-16)")
    assertEqual(NS.Window.TooltipOf(NS.FooterRow.Mark("post"))[1], "Post my tradeables", "the tooltip is unchanged")
    assertEqual(drawn.summary.count, 3)
    assertEqual(bottomOf(drawn.scroll), NS.FooterMetric("HEIGHT"), "the cards end over the footer")
    NS.SetWindowMode("full")
    drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.compact == nil and #drawn.rows == 4, "the table again")
    assertEqual(infoOf(drawn), "3 tradeable · next expiry 0:08:41")
end)

test("drops strip: the compact countdown tick moves its next expiry too", function()
    local NS, drawn, m = shownMine(true)
    m.__now = NOW + 12
    NS.addon:SendMessage(NS.MSG.TRADE_TIMER_TICK)
    assertEqual(infoOf(drawn), "3 tradeable · next 0:08:29")
    assertTrue(lineOf(NS):find("^3 tradeable · next 0:08:29 · ") ~= nil)
end)
