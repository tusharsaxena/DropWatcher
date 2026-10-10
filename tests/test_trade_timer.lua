-- tests/test_trade_timer.lua — modules/TradeTimer.lua (design spec §7.4): the exact trade countdown
-- on your own drops. The TradeTimeRemaining line read by its type, the localized duration decoder
-- fallback, the match by link and by item id, the scan throttle and its triggers, the warning at
-- the threshold, the shared ticker's lifecycle (fast while the window is shown, slow otherwise, off
-- with nothing live), an item leaving the bags, test drops, secrets and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"
local LINE_TYPE = 36    -- the mock's Enum.TooltipDataLineType.TradeTimeRemaining
local SENTENCE = "You may trade this item with players that were also eligible to loot this item for the next %s."

local function link(id, extra)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%s|h[Item %d]|h|r"):format(id, extra or "", id)
end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

-- An enabled instance wearing two 600 rings, so a 590 ring is a downgrade you may trade.
local function setup()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.bags[0] = { size = 4 }
    return NS, m, NS.TradeTimer
end

local function tradeLine(duration, lineType)
    return { lines = { { type = 1, leftText = "Item 300" },
        { type = lineType or LINE_TYPE, leftText = SENTENCE:format(duration) } } }
end

-- Put `itemLink` in bag 0, slot `slot`, with its GUID and (when given) its trade-time tooltip.
local function carry(m, slot, itemLink, guid, duration)
    m.bags[0][slot] = itemLink
    m.bagGUIDs["0:" .. slot] = guid
    m.tooltips.bag["0:" .. slot] = duration and tradeLine(duration) or { lines = {} }
end

-- One own drop of `itemLink`, its item in bag slot 1, scanned.
local function ownDrop(NS, m, itemLink, duration)
    m.addItem(itemLink, ring(590))
    local id = NS.LootFeed.Add(itemLink)
    carry(m, 1, itemLink, "Item-1-0001", duration)
    m.advance(0)
    return id
end

local function listen(NS)
    local seen = { ticks = 0, expiring = {} }
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.TRADE_TIMER_TICK, function() seen.ticks = seen.ticks + 1 end)
    target:RegisterMessage(NS.MSG.TRADE_TIMER_EXPIRING, function(_, dropID, guid, left)
        seen.expiring[#seen.expiring + 1] = { dropID = dropID, guid = guid, left = left }
    end)
    return seen
end

-- The live tickers (a C_Timer.NewTicker handle carries `ticker` in the mock).
local function tickers(m)
    local n = 0
    for _, t in ipairs(m.__timers()) do
        if t.ticker then n = n + 1 end
    end
    return n
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- Reading the timer
-- ---------------------------------------------------------------------------------------------

test("read: your drop's TradeTimeRemaining line gives its exact expiry, keyed by item GUID", function()
    local NS, m, TT = setup()
    local id = ownDrop(NS, m, link(300), "1 hour 59 min")
    local e = TT.ForDrop(id)
    assertTrue(e ~= nil, "matched")
    assertEqual(e.guid, "Item-1-0001")
    assertEqual(TT.Get("Item-1-0001"), e)
    assertEqual(e.bag, 0); assertEqual(e.slot, 1)
    assertEqual(TT.Remaining(e), 7140)
    assertFalse(e.expired); assertFalse(e.warned)
    m.advance(40)
    assertEqual(TT.Remaining(e), 7100, "counted down from the stored expiry")
    TT.Scan("test")
    assertEqual(TT.Remaining(e), 7100, "a re-read within a minute keeps the stored expiry")
    m.tooltips.bag["0:1"] = tradeLine("1 hour 30 min")
    TT.Scan("test")
    assertEqual(TT.Remaining(e), 5400, "one further off is taken")
end)

test("read: the sentence on a line of another type is still the timer (the text fallback)", function()
    local NS, m, TT = setup()
    local id = ownDrop(NS, m, link(300), nil)
    m.tooltips.bag["0:1"] = tradeLine("2 hrs", 99)    -- the client tagged it with another type
    TT.Scan("test")
    assertFalse(TT.ForDrop(id).expired)
    assertEqual(TT.Remaining(TT.ForDrop(id)), 7200)
end)

test("decoder: without the line type, the localized sentence is decoded with the client's globals", function()
    local NS, m, TT = setup()
    m.Enum.TooltipDataLineType.TradeTimeRemaining = nil
    m.BIND_TRADE_TIME_REMAINING = "Ihr könnt diesen Gegenstand in den nächsten %s mit anderen Spielern handeln."
    m.INT_SPELL_DURATION_HOURS = "%d |4Stunde:Stunden;"
    m.INT_SPELL_DURATION_MIN = "%d Min."
    local id = ownDrop(NS, m, link(300), nil)
    m.tooltips.bag["0:1"] = { lines = { { type = 0, leftText = "Seelengebunden" }, { type = 0,
        leftText = "Ihr könnt diesen Gegenstand in den nächsten 1 Stunde 5 Min. mit anderen Spielern handeln." } } }
    TT.Scan("test")
    assertEqual(TT.Remaining(TT.ForDrop(id)), 3900)
end)

test("read: no timer line (bound, or the window gone) means no: expired, never live", function()
    local NS, m, TT = setup()
    local id = ownDrop(NS, m, link(300), nil)
    local e = TT.ForDrop(id)
    assertTrue(e.expired); assertNil(e.expiresAt)
    assertEqual(TT.Remaining(e), 0)
    assertEqual(TT.LiveCount(), 0)
    assertNil(TT.TickerPeriod(), "nothing live, no ticker")
end)

-- ---------------------------------------------------------------------------------------------
-- Matching bag items to your drops
-- ---------------------------------------------------------------------------------------------

test("match: by exact link first, then by item id; each drop takes one item", function()
    local NS, m, TT = setup()
    m.addItem(link(300), ring(590))
    local a = NS.LootFeed.Add(link(300))
    local b = NS.LootFeed.Add(link(300))
    carry(m, 1, link(300, "1"), "Item-1-0001", "1 hour")    -- another context: same id, other link
    carry(m, 2, link(300), "Item-1-0002", "2 hrs")
    m.advance(0)
    assertEqual(TT.Get("Item-1-0002").dropID, a, "the exact link takes the first drop")
    assertEqual(TT.Get("Item-1-0001").dropID, b, "the id match takes the other")
    assertEqual(TT.LiveCount(), 2)
end)

test("match: an item that is none of your drops, and another member's drop, are not timed", function()
    local NS, m, TT = setup()
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    m.addItem(link(300), ring(590))
    NS.LootFeed.Add(link(300), "Brakk")
    carry(m, 1, link(300), "Item-1-0001", "1 hour")
    carry(m, 2, link(400), "Item-1-0002", "1 hour")
    m.__fire("BAG_UPDATE_DELAYED")
    m.advance(0)
    assertNil(next(TT.Entries()))
end)

test("match: test drops are never timed", function()
    local NS, m, TT = setup()
    m.addItem(link(300), ring(590))
    NS.LootFeed.Add(link(300), nil, { test = true })
    carry(m, 1, link(300), "Item-1-0001", "1 hour")
    m.__fire("BAG_UPDATE_DELAYED")
    m.advance(0)
    assertNil(next(TT.Entries()))
end)

test("match: an item that left the bags drops its entry; a moved one keeps it", function()
    local NS, m, TT = setup()
    local id = ownDrop(NS, m, link(300), "1 hour")
    local e = TT.ForDrop(id)
    m.bags[0][1], m.bagGUIDs["0:1"] = nil, nil
    carry(m, 3, link(300), "Item-1-0001", "1 hour")
    TT.Scan("test")
    assertEqual(TT.ForDrop(id).slot, 3, "moved, same GUID")
    assertEqual(TT.ForDrop(id), e, "the same entry")
    m.bags[0][3], m.bagGUIDs["0:3"] = nil, nil
    TT.Scan("test")
    assertNil(TT.ForDrop(id), "traded away or sold")
end)

-- ---------------------------------------------------------------------------------------------
-- The scan's triggers and throttle
-- ---------------------------------------------------------------------------------------------

test("scan: BAG_UPDATE_DELAYED, LOOT_CLOSED and your DropAdded ask for it; once per 2 seconds", function()
    local NS, m, TT = setup()
    ownDrop(NS, m, link(300), "1 hour")    -- the DropAdded scan
    local scans = NS.State.tradeTimer.scans
    assertEqual(scans, 1)
    m.__fire("BAG_UPDATE_DELAYED")
    m.__fire("LOOT_CLOSED")
    m.__fire("BAG_UPDATE_DELAYED")
    assertTrue(TT.IsScheduled())
    m.advance(1.9)
    assertEqual(NS.State.tradeTimer.scans, scans, "throttled")
    m.advance(0.1)
    assertEqual(NS.State.tradeTimer.scans, scans + 1, "the three asks share one scan")
    m.advance(5)
    m.__fire("LOOT_CLOSED")
    m.advance(0)
    assertEqual(NS.State.tradeTimer.scans, scans + 2, "past the throttle, at once")
end)

-- ---------------------------------------------------------------------------------------------
-- The ticker
-- ---------------------------------------------------------------------------------------------

test("ticker: slow while the window is hidden, fast while it is shown, off when nothing is live", function()
    local NS, m, TT = setup()
    local seen = listen(NS)
    ownDrop(NS, m, link(300), "1 hour")
    assertEqual(TT.TickerPeriod(), 60)
    seen.ticks = 0
    m.advance(60)
    assertEqual(seen.ticks, 1, "one tick a minute")
    NS.ShowWindow()
    NS.Window.Frame():__fire("OnShow")
    assertEqual(TT.TickerPeriod(), 1)
    seen.ticks = 0
    m.advance(5)
    assertEqual(seen.ticks, 5, "one tick a second")
    NS.Window.Close()
    NS.Window.Frame():__fire("OnHide")
    assertEqual(TT.TickerPeriod(), 60)
    assertEqual(tickers(m), 1, "one shared ticker, never two")
    m.advance(3600)
    assertTrue(TT.Get("Item-1-0001").expired, "run out")
    assertNil(TT.TickerPeriod(), "nothing live: the ticker stopped")
    assertEqual(tickers(m), 0)
end)

test("ticker: a second live item shares the one ticker", function()
    local NS, m, TT = setup()
    m.addItem(link(300), ring(590))
    NS.LootFeed.Add(link(300))
    NS.LootFeed.Add(link(300))
    carry(m, 1, link(300), "Item-1-0001", "1 hour")
    carry(m, 2, link(300), "Item-1-0002", "2 hrs")
    m.advance(0)
    assertEqual(TT.LiveCount(), 2)
    assertEqual(tickers(m), 1)
    m.advance(3600)
    assertEqual(TT.LiveCount(), 1, "the first ran out")
    assertEqual(TT.TickerPeriod(), 60, "the second keeps it going")
end)

-- ---------------------------------------------------------------------------------------------
-- The warning
-- ---------------------------------------------------------------------------------------------

test("warn: once per item at the threshold, with TradeTimerExpiring and one chat line", function()
    local NS, m, TT = setup()
    local seen = listen(NS)
    local id = ownDrop(NS, m, link(300), "11 min 40 sec")    -- 700s
    NS.ShowWindow()
    NS.Window.Frame():__fire("OnShow")
    m.prints = {}
    m.advance(99)
    assertEqual(#seen.expiring, 0, "601s left: not yet")
    m.advance(1)
    assertEqual(#seen.expiring, 1)
    assertEqual(seen.expiring[1].dropID, id)
    assertEqual(seen.expiring[1].guid, "Item-1-0001")
    assertEqual(seen.expiring[1].left, 600)
    assertTrue(TT.ForDrop(id).warned, "the row goes bold")
    assertEqual(printed(m, "10 min left to trade it."), 1)
    m.advance(300)
    TT.Scan("test")
    assertEqual(#seen.expiring, 1, "never twice, a rescan included")
    assertEqual(printed(m, "left to trade it."), 1)
end)

test("warn: an item first read below the threshold warns at once; warnAt 0 turns it off", function()
    local NS, m, TT = setup()
    local seen = listen(NS)
    local id = ownDrop(NS, m, link(300), "5 min")
    assertEqual(#seen.expiring, 1)
    assertEqual(seen.expiring[1].dropID, id)
    local NS2, m2 = setup()
    NS2.db.profile.trade = { warnAt = 0 }
    local seen2 = listen(NS2)
    ownDrop(NS2, m2, link(300), "5 min")
    m2.advance(299)
    assertEqual(#seen2.expiring, 0)
    assertEqual(NS2.TradeTimer.WarnAt(), 0)
    assertEqual(TT.WarnAt(), 600, "the default")
end)

-- ---------------------------------------------------------------------------------------------
-- Secrets and the stand-down
-- ---------------------------------------------------------------------------------------------

test("secrets: a secret bag link, GUID or tooltip text is never used", function()
    local NS, m, TT = setup()
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
    m.addItem(link(300), ring(590))
    local id = NS.LootFeed.Add(link(300))
    carry(m, 1, T.secret(link(300)), "Item-1-0001", "1 hour")
    carry(m, 2, link(300), T.secret("Item-1-0002"), "1 hour")
    m.advance(0)
    assertNil(next(TT.Entries()))
    carry(m, 3, link(300), "Item-1-0003", nil)
    m.tooltips.bag["0:3"] = { lines = { { type = LINE_TYPE, leftText = T.secret(SENTENCE:format("1 hour")) } } }
    TT.Scan("test")
    assertTrue(TT.ForDrop(id).expired, "an unreadable line is no timer")
end)

test("stand-down: the ticker and the scan stop, the entries are kept; the stand-up scans again", function()
    local NS, m, TT = setup()
    local seen = listen(NS)
    local id = ownDrop(NS, m, link(300), "5 min")
    assertTrue(TT.ForDrop(id).warned)
    m.__fire("BAG_UPDATE_DELAYED")
    NS.addon:OnSlashCommand("disable")
    assertEqual(#m.__timers(), 0, "no live timer")
    assertNil(TT.TickerPeriod())
    assertTrue(TT.ForDrop(id) ~= nil, "kept")
    NS.addon:OnSlashCommand("enable")
    m.advance(2)
    assertEqual(TT.TickerPeriod(), 60, "rescanned and ticking")
    assertEqual(#seen.expiring, 1, "the warned flag survived: no second warning")
end)
