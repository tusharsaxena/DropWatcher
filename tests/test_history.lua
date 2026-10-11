-- tests/test_history.lua — the history (design spec §10): the pure core (the shape, the snapshot,
-- the caps, the outcomes moving forward only, declined by hand, the trade-completion match), the
-- edge on the bus (DropAdded records a live drop, DropUpdated refreshes it, AskStateChanged moves
-- its outcome), the trade window's events (a completed trade marks a drop received or traded away;
-- an unfinished one marks nothing), the cap row, Clear history behind its confirmation, and the
-- History tab built headless: kept groups under their headers, the outcome column, the row menu,
-- the filter and the empty line.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function link(id) return ("|cffa335ee|Hitem:%d::|h[Item %d]|h|r"):format(id, id) end

local function H() return T.newAddon().History end

local function rec(over)
    local r = {
        id = 1, link = link(500), itemID = 500, at = 10, isMine = false, situation = "dungeon",
        looter = { name = "Brakk-Testrealm", guid = "Player-1-0000000A", classFile = "WARRIOR" },
        facts = { ilvl = 610, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 10, baseline = { link = link(9) }, reasons = { { key = "x" } } },
        them = { verdict = "downgrade", ilvlDelta = -6, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", basis = "rule", args = { 610, 616 } },
        groupKey = "enc:2900:5", group = { key = "enc:2900:5", label = "Boss A", kind = "encounter" },
    }
    for k, v in pairs(over or {}) do r[k] = v end
    return r
end

local function entry(over)
    local e = { itemLink = link(500), itemID = 500, looter = "Brakk-Testrealm", outcome = "seen", at = 1 }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("history: Normalize gives the shape in place and keeps the cap", function()
    local Hi = H()
    local hist = { maxGroups = 35 }
    assertTrue(Hi.Normalize(hist) == hist)
    assertEqual(hist.v, 1); assertEqual(#hist.groups, 0); assertEqual(hist.maxGroups, 35)
    hist.groups = "broken"
    Hi.Normalize(hist)
    assertEqual(type(hist.groups), "table", "a broken list is replaced, not the table")
end)

test("history: Snapshot keeps the drop small: link, looter, verdicts, trade, `seen`", function()
    local Hi = H()
    local e = Hi.Snapshot(rec({ trade = { state = "no", reasonKey = "x", args = { 1, {}, 3 } } }), 1234)
    assertEqual(e.itemLink, link(500)); assertEqual(e.itemID, 500)
    assertEqual(e.looter, "Brakk-Testrealm"); assertEqual(e.class, "WARRIOR")
    assertEqual(e.ilvl, 610); assertEqual(e.equipLoc, "INVTYPE_FINGER"); assertEqual(e.quality, 4)
    assertEqual(e.me.verdict, "upgrade"); assertEqual(e.me.ilvlDelta, 10)
    assertNil(e.me.reasons, "no reasons or baseline tables kept"); assertNil(e.me.baseline)
    assertEqual(e.them.verdict, "downgrade")
    assertEqual(#e.trade.args, 1, "the args stop at the first table")
    assertEqual(e.outcome, "seen"); assertEqual(e.at, 1234); assertNil(e.isMine)
    local mine = Hi.Snapshot(rec({ isMine = true, them = false, itemID = false }), 1)
    assertTrue(mine.isMine); assertNil(mine.them); assertEqual(mine.itemID, 500, "read from the link")
end)

test("history: Record groups by key, newest last; the caps drop the oldest first", function()
    local Hi = H()
    local hist = Hi.Normalize({})
    local a = Hi.Record(hist, { key = "a", label = "A" }, entry(), 2)
    Hi.Record(hist, { key = "a", label = "A" }, entry(), 2)
    Hi.Record(hist, { key = "b", label = "B" }, entry(), 2)
    assertEqual(#hist.groups, 2); assertEqual(#hist.groups[1].drops, 2)
    Hi.Record(hist, { key = "c", label = "C" }, entry(), 2)
    assertEqual(#hist.groups, 2); assertEqual(hist.groups[1].key, "b", "the oldest group went")
    assertTrue(a.gone, "a dropped entry is marked gone")
    for _ = 1, Hi.MAX_DROPS + 3 do Hi.Record(hist, { key = "c" }, entry(), 2) end
    assertEqual(#hist.groups[2].drops, Hi.MAX_DROPS, "50 drops per group")
    assertEqual(Hi.Trim(hist, 1), 1)
    assertEqual(#hist.groups, 1); assertEqual(hist.groups[1].key, "c")
end)

test("history: an automatic outcome only moves forward", function()
    local Hi = H()
    local e = entry()
    assertTrue(Hi.Advance(e, "asked")); assertEqual(e.outcome, "asked")
    assertFalse(Hi.Advance(e, "offered"), "the same rank")
    assertTrue(Hi.Advance(e, "expired"))
    assertFalse(Hi.Advance(e, "asked"), "asked never undoes expired")
    assertFalse(Hi.Advance(e, "nonsense"))
    assertTrue(Hi.Advance(e, "received"))
    assertFalse(Hi.Advance(e, "expired"))
end)

test("history: Refresh takes the latest verdicts, and an expired trade makes it `expired`", function()
    local Hi = H()
    local e = Hi.Snapshot(rec(), 1)
    assertFalse(Hi.Refresh(e, rec({ me = { verdict = "sidegrade", ilvlDelta = 2 } })))
    assertEqual(e.me.verdict, "sidegrade")
    assertTrue(Hi.Refresh(e, rec({ trade = { state = "no", reasonKey = "expired", args = { 7300, 7200 } } })))
    assertEqual(e.outcome, "expired")
end)

test("history: Refresh's second answer says whether anything it stores changed", function()
    local Hi = H()
    local e = Hi.Snapshot(rec(), 1)
    local _, moved = Hi.Refresh(e, rec())
    assertFalse(moved, "the same verdicts and trade")
    _, moved = Hi.Refresh(e, rec({ them = { verdict = "upgrade", ilvlDelta = 4 } }))
    assertTrue(moved, "their verdict moved")
    _, moved = Hi.Refresh(e, rec({ them = { verdict = "upgrade", ilvlDelta = 4 },
        trade = { state = "likely", reasonKey = "notUpgrade", basis = "rule", args = { 610, 617 } } }))
    assertTrue(moved, "a trade arg moved")
    _, moved = Hi.Refresh(e, rec({ them = { verdict = "upgrade", ilvlDelta = 4 },
        trade = { state = "likely", reasonKey = "notUpgrade", basis = "rule", args = { 610, 617 } } }))
    assertFalse(moved)
end)

test("history: declined is set by hand, and clearing it puts back what it replaced", function()
    local Hi = H()
    local e = entry({ outcome = "asked" })
    assertTrue(Hi.SetDeclined(e, true)); assertEqual(e.outcome, "declined")
    assertFalse(Hi.SetDeclined(e, true), "already declined")
    assertFalse(Hi.Advance(e, "expired"), "an automatic move never undoes the player's")
    assertTrue(Hi.SetDeclined(e, false)); assertEqual(e.outcome, "asked")
    assertFalse(Hi.SetDeclined(e, false))
    local got = entry({ outcome = "received" })
    assertFalse(Hi.SetDeclined(got, true), "a received drop keeps that")
end)

test("history: a completed trade matches the partner's drop first, then any, one entry per item", function()
    local Hi = H()
    local hist = Hi.Normalize({})
    local lyra = Hi.Record(hist, { key = "a" }, entry({ looter = "Lyra-Area52" }), 20)
    local brakk = Hi.Record(hist, { key = "a" }, entry({ looter = "Brakk" }), 20)
    local other = Hi.Record(hist, { key = "b" }, entry({ looter = "Seta", itemID = 501, itemLink = link(501) }), 20)
    local m = Hi.MatchTrade(hist, { partner = "Lyra-Area52", received = { link(500) }, given = {} })
    assertEqual(#m, 1); assertTrue(m[1].entry == lyra, "the partner's own drop, though older")
    assertEqual(m[1].outcome, "received")
    m = Hi.MatchTrade(hist, { partner = "Stranger", received = { link(500), link(500), link(500) } })
    assertEqual(#m, 2, "two drops of that item, so two matches")
    assertTrue(m[1].entry == brakk, "the newest first")
    m = Hi.MatchTrade(hist, { partner = "Seta", received = { link(999) } })
    assertEqual(#m, 0, "no drop of that item")
    other.outcome = "received"
    assertEqual(#Hi.MatchTrade(hist, { received = { link(501) } }), 0, "already received")
end)

test("history: an item you gave marks your own drop traded away, never someone else's", function()
    local Hi = H()
    local hist = Hi.Normalize({})
    Hi.Record(hist, { key = "a" }, entry({ itemID = 600, itemLink = link(600) }), 20)
    assertEqual(#Hi.MatchTrade(hist, { given = { link(600) } }), 0)
    local mine = Hi.Record(hist, { key = "a" }, entry({ itemID = 600, itemLink = link(600), isMine = true }), 20)
    local m = Hi.MatchTrade(hist, { given = { link(600) }, received = { link(600) } })
    assertEqual(#m, 2)
    assertTrue(m[2].entry == mine); assertEqual(m[2].outcome, "tradedAway")
    assertFalse(m[1].entry == mine, "your own drop is never one you received")
end)

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- An enabled instance whose feed answers `drops` by id.
local function enabled(drops)
    local NS, _, m = T.enableAddon()
    local byId = {}
    for _, d in ipairs(drops or {}) do byId[d.id] = d end
    NS.LootFeed.Get = function(id) return byId[id] end
    local seen = { changed = 0 }
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.HISTORY_CHANGED, function() seen.changed = seen.changed + 1 end)
    return NS, m, seen, byId
end

local function added(NS, id) NS.addon:SendMessage(NS.MSG.DROP_ADDED, id) end

test("history edge: DropAdded records a live drop in DB.global, never a test drop, and keeps the cap", function()
    local NS, _, seen = enabled({ rec(), rec({ id = 2, test = true }) })
    assertTrue(NS.SchemaRuntime.Set("global.history.maxGroups", 35))
    added(NS, 1); added(NS, 2); added(NS, 1)
    local g = NS.addon.db.global.history
    assertEqual(g.maxGroups, 35, "the cap row's value is still in the table")
    assertEqual(g.v, 1); assertEqual(#g.groups, 1); assertEqual(#g.groups[1].drops, 1)
    assertEqual(g.groups[1].label, "Boss A"); assertEqual(g.groups[1].situation, "dungeon")
    assertTrue(g.groups[1].key:find("^enc:2900:5@") ~= nil, "keyed by the feed group and the session")
    assertEqual(seen.changed, 1)
    assertEqual(NS.History.OutcomeOf(1), "seen"); assertNil(NS.History.OutcomeOf(2))
end)

test("history edge: DropUpdated refreshes the entry; an expired trade makes it `expired`", function()
    local NS, _, _, byId = enabled({ rec() })
    added(NS, 1)
    byId[1] = rec({ trade = { state = "no", reasonKey = "expired", args = { 7300, 7200 } } })
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "trade")
    assertEqual(NS.History.OutcomeOf(1), "expired")
    assertEqual(NS.History.EntryOf(1).trade.state, "no")
end)

test("history edge: a DropUpdated that changes nothing kept sends no HistoryChanged", function()
    local NS, _, seen, byId = enabled({ rec() })
    added(NS, 1)
    assertEqual(seen.changed, 1)
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "score")
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertEqual(seen.changed, 1, "nothing the history keeps moved")
    byId[1] = rec({ them = { verdict = "upgrade", ilvlDelta = 3 } })
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    assertEqual(seen.changed, 2)
end)

test("history edge: a sent ask is `asked`, a sent offer or announce `offered`; other states nothing", function()
    local NS = enabled({ rec(), rec({ id = 2, isMine = true }) })
    added(NS, 1); added(NS, 2)
    local M = NS.MSG.ASK_STATE_CHANGED
    NS.addon:SendMessage(M, 1, "queued", "ask", "Brakk-Testrealm")
    assertEqual(NS.History.OutcomeOf(1), "seen")
    NS.addon:SendMessage(M, 1, "sent", "ask", "Brakk-Testrealm")
    assertEqual(NS.History.OutcomeOf(1), "asked")
    NS.addon:SendMessage(M, 2, "sent", "announce", "group")
    assertEqual(NS.History.OutcomeOf(2), "offered")
    NS.addon:SendMessage(M, "post:1:1", "sent", "announce", "group")
end)

local function complete(m)
    m.__fire("UI_INFO_MESSAGE", m.LE_GAME_ERR_TRADE_COMPLETE, m.ERR_TRADE_COMPLETE)
end

-- A trade with Brakk (party1's name) in which you get `got` and give `gave`. Brakk accepts, then
-- your accept completes it with no both-accepted update; the window empties and closes (twice),
-- then "Trade complete." arrives, unless `finish` is false (a cancel) or "before" (it comes first).
local function trade(m, got, gave, finish)
    m.units.NPC = { name = "Brakk" }
    m.__fire("TRADE_SHOW")
    m.tradeItems.target = got or {}
    m.tradeItems.player = gave or {}
    m.__fire("TRADE_TARGET_ITEM_CHANGED", 1)
    m.__fire("TRADE_ACCEPT_UPDATE", 0, 1)
    if finish == "before" then complete(m) end
    m.tradeItems.target, m.tradeItems.player = {}, {}
    m.__fire("TRADE_TARGET_ITEM_CHANGED", 1)
    m.__fire("TRADE_CLOSED")
    m.__fire("TRADE_CLOSED")
    if finish == nil then complete(m) end
end

test("history trade: a completed trade marks the drop you got `received`, and the Ask button `Traded`", function()
    local NS, m, seen = enabled({ rec() })
    added(NS, 1)
    local before = seen.changed
    trade(m, { link(500) })
    assertEqual(NS.History.OutcomeOf(1), "received")
    assertEqual(seen.changed, before + 1)
    local drop = rec()
    assertEqual(NS.History.AskState(drop, "sent"), "traded")
    local a = NS.WindowCells.Ask(drop, "traded")
    assertEqual(a.text, "Traded"); assertFalse(a.enabled); assertEqual(a.icon, "confirm")
    assertNil(NS.History.OpenTrade(), "nothing is left open")
end)

test("history trade: \"Trade complete.\" before the close completes it too", function()
    local NS, m = enabled({ rec() })
    added(NS, 1)
    trade(m, { link(500) }, nil, "before")
    assertEqual(NS.History.OutcomeOf(1), "received")
end)

test("history trade: a close after both accepted with no \"Trade complete.\" completes nothing", function()
    local NS, m = enabled({ rec() })
    added(NS, 1)
    m.units.NPC = { name = "Brakk" }
    m.__fire("TRADE_SHOW")
    m.tradeItems.target = { link(500) }
    m.__fire("TRADE_ACCEPT_UPDATE", 1, 1)
    m.__fire("TRADE_CLOSED")
    m.__fire("UI_INFO_MESSAGE", 1, "Some other message.")
    assertEqual(NS.History.OutcomeOf(1), "seen", "a failed trade (a full bag, out of range)")
    m.advance(NS.History.CLOSED_GRACE + 1)
    complete(m)
    assertEqual(NS.History.OutcomeOf(1), "seen", "a late message belongs to no trade")
end)

test("history trade: an item you gave marks your drop `tradedAway`", function()
    local NS, m = enabled({ rec({ isMine = true }) })
    added(NS, 1)
    trade(m, {}, { link(500) })
    assertEqual(NS.History.OutcomeOf(1), "tradedAway")
end)

test("history trade: a canceled trade completes nothing; the offer is the last one accepted", function()
    local NS, m = enabled({ rec(), rec({ id = 2, itemID = 501, link = link(501) }) })
    added(NS, 1); added(NS, 2)
    trade(m, { link(500) }, nil, false)
    assertEqual(NS.History.OutcomeOf(1), "seen", "canceled: no \"Trade complete.\"")
    m.units.NPC = { name = "Brakk" }
    m.__fire("TRADE_SHOW")
    m.tradeItems.target = { link(500) }
    m.__fire("TRADE_ACCEPT_UPDATE", 1, 0)
    m.tradeItems.target = { link(501) }
    m.__fire("TRADE_TARGET_ITEM_CHANGED", 1)
    m.__fire("TRADE_ACCEPT_UPDATE", 0, 0)
    m.__fire("TRADE_ACCEPT_UPDATE", 0, 1)
    m.tradeItems.target = {}
    m.__fire("TRADE_CLOSED")
    complete(m)
    assertEqual(NS.History.OutcomeOf(1), "seen", "swapped out before the final accept")
    assertEqual(NS.History.OutcomeOf(2), "received")
end)

test("history: lowering the cap row trims the stored log at once", function()
    local NS = enabled({ rec(), rec({ id = 2, groupKey = "enc:2:1" }), rec({ id = 3, groupKey = "enc:3:1" }) })
    added(NS, 1); added(NS, 2); added(NS, 3)
    assertEqual(#NS.History.Groups(), 3)
    assertTrue(NS.SchemaRuntime.Set("global.history.maxGroups", 1))
    assertEqual(#NS.History.Groups(), 1)
    assertNil(NS.History.OutcomeOf(1), "a dropped entry leaves the session index")
    assertEqual(NS.History.OutcomeOf(3), "seen")
end)

test("history: Clear history asks first, and empties the log only on Yes; the cap stays", function()
    local NS, m = enabled({ rec() })
    added(NS, 1)
    NS.WindowHistory.AskClear()
    assertEqual(m.popupsShown[#m.popupsShown][1], NS.WindowHistory.CLEAR_POPUP)
    assertEqual(#NS.History.Groups(), 1, "nothing cleared before the answer")
    local popup = m.StaticPopupDialogs[NS.WindowHistory.CLEAR_POPUP]
    -- red under: a popup without preferredIndex (DW-62 review F-006): slot 3, clear of Blizzard's own
    assertEqual(popup.preferredIndex, 3)
    popup.OnAccept()
    assertEqual(#NS.History.Groups(), 0)
    assertEqual(NS.addon.db.global.history.maxGroups, 20)
    assertNil(NS.History.OutcomeOf(1))
end)

test("history: the diagnostics' feed section reports the history and the trade", function()
    local NS = enabled({ rec() })
    added(NS, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("feed: history groups=1/20 drops=1 session=1 trade=none", 1, true) ~= nil, text)
end)

-- ── the History tab ─────────────────────────────────────────────────────────────────────────

local DAY = 86400

-- Two groups kept from earlier sessions, then the tab shown.
local function shownTab(mutate)
    local NS, _, m = T.enableAddon()
    local now = m.time()
    local hist = NS.History.Store()
    hist.groups = {
        { key = "old", label = "Boss Old", kind = "encounter", situation = "raid", at = now - 3 * DAY, drops = {
            entry({ at = now - 3 * DAY, outcome = "received", class = "WARRIOR", ilvl = 600, equipLoc = "INVTYPE_FINGER",
                me = { verdict = "upgrade", ilvlDelta = 8 }, trade = { state = "likely", reasonKey = "notUpgrade", args = {} } }),
        } },
        { key = "new", label = "Boss New", kind = "encounter", situation = "dungeon", at = now - 120, drops = {
            entry({ at = now - 120, itemLink = link(501), outcome = "asked", ilvl = 610 }),
            entry({ at = now - 100, itemLink = link(502), outcome = "expired", isMine = true, ilvl = 612 }),
        } },
    }
    if mutate then mutate(NS, hist) end
    NS.ShowWindow()
    NS.Window.SelectTab("history")
    return NS, NS.WindowHistory.Drawn(), m
end

local function textOf(region) return region and region:GetText() end

test("history tab: kept groups newest first, the first open, each row's outcome painted", function()
    local NS, drawn = shownTab()
    assertEqual(#drawn.headers, 2); assertEqual(#drawn.rows, 2, "the older group is collapsed")
    assertEqual(drawn.entries[1].group.key, "new")
    assertTrue(textOf(drawn.headers[1].text):find("^Boss New · Dungeon · 2m ago · 2 drops") ~= nil, textOf(drawn.headers[1].text))
    assertTrue(textOf(drawn.headers[2].text):find("3 days ago", 1, true) ~= nil)
    local outcomes = {}
    for _, r in ipairs(drawn.rows) do outcomes[#outcomes + 1] = textOf(r.cells.outcome.text) end
    table.sort(outcomes)
    assertEqual(table.concat(outcomes, ","), "Asked,Expired")
    assertEqual(NS.WindowFilterBar.State("history").content, "all", "the tab opens on Content: All")
    assertEqual(NS.WindowFilterBar.State("history").view, "all", "and View: All")
    assertEqual(textOf(drawn.strip.info), "2 of 20 groups kept, 3 drops")
    for _, r in ipairs(drawn.rows) do
        for key, c in pairs(r.cells) do
            local itemTip = c.showItem and c.itemButton.link ~= nil   -- the real item tooltip (DW-80)
            if c:IsShown() then assertTrue(itemTip or #NS.Window.TooltipOf(c) >= 2, key .. " has a reason") end
        end
    end
end)

test("history tab: a header click opens a collapsed group; the filter's Content cuts earlier sessions", function()
    local NS = shownTab()
    NS.WindowHistory.ToggleGroup("old", true)
    local drawn = NS.WindowHistory.Drawn()
    assertEqual(#drawn.rows, 3)
    NS.WindowFilterBar.Set("history", "content", "session")
    drawn = NS.WindowHistory.Drawn()
    assertEqual(#drawn.entries, 0, "every kept drop is from before this session")
    assertEqual(textOf(drawn.pane.placeholder), "No kept drop matches the filters. View: All and Content: All show everything.")
end)

test("history tab: a right-click marks a row declined, through the menu when the client has one", function()
    local _, drawn, m = shownTab()
    local row = drawn.rows[1]
    local e = row.entry
    row:GetScript("OnMouseUp")(row, "RightButton")
    assertEqual(e.outcome, "declined", "no MenuUtil: it acts at once")
    local made = {}
    m.MenuUtil = { CreateContextMenu = function(o, gen)
        gen(o, { CreateButton = function(_, text, fn) made[#made + 1] = { text = text, fn = fn } end })
    end }
    row.cells.slot:GetScript("OnMouseUp")(row.cells.slot, "RightButton")
    assertEqual(made[1].text, "Clear declined")
    made[1].fn()
    assertTrue(e.outcome ~= "declined")
end)

test("history tab: with nothing kept it says what it will hold, and Clear history is off", function()
    local _, drawn = shownTab(function(_, hist) hist.groups = {} end)
    assertEqual(#drawn.entries, 0)
    assertTrue(drawn.pane.placeholder:IsShown())
    assertEqual(textOf(drawn.pane.placeholder), "Drops from earlier encounters appear here.")
    assertFalse(drawn.strip.clear:IsEnabled())
end)

test("history tab: HistoryChanged repaints the shown window on the next frame", function()
    local NS, _, m = shownTab()
    local hist = NS.History.Store()
    hist.groups[2].drops[3] = entry({ at = m.time(), itemLink = link(503) })
    NS.addon:SendMessage(NS.MSG.HISTORY_CHANGED)
    assertEqual(#NS.WindowHistory.Drawn().rows, 2, "not yet")
    m.advance(0)
    assertEqual(#NS.WindowHistory.Drawn().rows, 3)
end)

test("history tab: a DropUpdated that changes the history still repaints the window once", function()
    local NS, _, m = shownTab()
    local byId = { [1] = rec() }
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    m.advance(0)
    local passes, real = 0, NS.Window.Refresh
    NS.Window.Refresh = function(...) passes = passes + 1; return real(...) end
    byId[1] = rec({ them = { verdict = "upgrade", ilvlDelta = 3 } })
    NS.addon:SendMessage(NS.MSG.DROP_UPDATED, 1, "inspect")
    m.advance(0)
    NS.Window.Refresh = real
    assertEqual(passes, 1, "DropUpdated and HistoryChanged share one pass")
end)

test("history tab: the pure Ago reads seconds, hours, then days", function()
    local WH = T.newAddon().WindowHistory
    assertEqual(WH.Ago(40), "40s ago")
    assertEqual(WH.Ago(7140), "1h 59m ago")
    assertEqual(WH.Ago(86400), "1 day ago")
    assertEqual(WH.Ago(3 * 86400 + 5), "3 days ago")
end)
