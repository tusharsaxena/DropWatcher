-- tests/test_window_pending.lua — the Drops tab's Rolling now section (modules/WindowPending.lua,
-- Forever port design §5.3, plan DW-FP15) built headless: shown only while a pending item exists
-- and `rolls.show` is on, above the boss groups, each row your verdict, the roll summary and the
-- time left with no action for a roll, a click expanding the roll table inline; the compact
-- layout's card for a pending item; the resolved drop's Rolls box on its detail card; the row
-- tooltip's summary line; and the detail card naming the scale each score used (DW-FP07's
-- ScoreFor, carried from M2). Rolls are a both-clients feature, so every case runs on both kit
-- profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local LINK = "|cffa335ee|Hitem:212::|h[Crown of Roaring Storms]|h|r"
local ROLL_LINK = "|cffa335ee|Hitem:300::|h[Band of Embers]|h|r"
local OLD = "|cffa335ee|Hitem:301::|h[Old Band]|h|r"

local function plain(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function textOf(region) return region and region:GetText() end
-- The roll count line as the player reads it (RX-06): each icon as its texture's name, colors out.
local function line(s) return plain(T.marks(s)) end
local COUNTS = "[UI-GroupLoot-Dice-Up] 1  [UI-GroupLoot-Coin-Up] 1  [clock] 2"
local function yOf(frame) return select(5, frame:GetPoint(1)) end

local function player(name, state, roll, isWinner, classFile)
    return { name = name, guid = "Player-1-" .. name, classFile = classFile or "WARRIOR", state = state,
        roll = roll, isWinner = isWinner == true }
end

-- An open roll: Brakk at Need 87, Lyra at Greed, two waiting; 60 s from 100 on the history's clock.
local function openRoll()
    return { link = ROLL_LINK, startTime = 100, duration = 60, allPassed = false, isTied = false,
        leader = { name = "Brakk", classFile = "WARRIOR", roll = 87 },
        rolls = { player("Brakk", 0, 87), player("Lyra", 3, nil, false, "PRIEST"), player("Seta", 4), player("Dorn", 4) } }
end

local function wonRoll()
    local r = openRoll()
    r.winner = { name = "Brakk", guid = "Player-1-Brakk", classFile = "WARRIOR", roll = 87 }
    r.rolls[1].isWinner = true
    return r
end

-- A pending roll item as NS.Pending holds it: an upgrade for you.
local function item(over)
    local it = { id = 1, kind = "roll", key = "2900:1", link = ROLL_LINK, itemID = 300, at = 100, state = "open",
        facts = { ilvl = 620, equipLoc = "INVTYPE_FINGER", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 20, reasons = {}, baseline = { link = OLD, ilvl = 600 } },
        roll = openRoll() }
    for k, v in pairs(over or {}) do it[k] = v end
    return it
end

-- A judged feed drop (test_window_group's shape).
local function drop(over)
    local d = {
        id = 1, at = 100, link = LINK, isMine = false, sources = { history = 1 },
        looter = { name = "Brakk-Realm", guid = "Player-1-Brakk", classFile = "WARRIOR" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 19, reasons = {}, baseline = { link = OLD, ilvl = 292 } },
        them = { verdict = "downgrade", ilvlDelta = -13, reasons = {} },
        trade = { state = "likely", reasonKey = "notUpgrade", args = { 311, 324 }, basis = "inspect", age = 40 },
        inspect = { status = "fresh", at = 60 },
    }
    for k, v in pairs(over or {}) do d[k] = v end
    return d
end

local GROUP = { key = "enc:3", label = "Boss 3", kind = "encounter", situation = "dungeon", at = 90, drops = { 1 } }

-- Stand `list` in for the store: All answers it and Count its length (WindowPending's empty check
-- reads Count, so a repaint with nothing pending builds no list).
local function stubPending(NS, list)
    NS.Pending.All = function() return list end
    NS.Pending.Count = function() return #list end
end

local function seed(NS, drops, pending)
    local byId = {}
    for _, d in ipairs(drops) do byId[d.id] = d end
    NS.LootFeed.Groups = function() return #drops > 0 and { GROUP } or {} end
    NS.LootFeed.Get = function(id) return byId[id] end
    NS.LootFeed.Drops = function() return drops end
    local byPending = {}
    for _, it in ipairs(pending) do byPending[it.id] = it end
    stubPending(NS, pending)
    NS.Pending.Get = function(id) return byPending[id] end
end

-- The window shown with `drops` in the feed and `pending` in the store (the full layout unless
-- `compact`), on the history's clock at 110.
local function shown(drops, pending, compact)
    local NS, _, m = T.enableAddon{ skin = "ka0s" }
    m.__now = 100
    m.lootHistoryTime = 110
    seed(NS, drops, pending)
    NS.WindowFilterBar.Set("group", "view", "all")
    if compact then NS.SetWindowMode("compact") end
    NS.ShowWindow()
    local drawn = NS.WindowGroup.Drawn()
    return NS, drawn, NS.WindowPending.Drawn(drawn.pane), m
end

local function refresh(NS)
    NS.Window.Refresh()
    local drawn = NS.WindowGroup.Drawn()
    return drawn, NS.WindowPending.Drawn(drawn.pane)
end

-- ── the full layout ─────────────────────────────────────────────────────────────────────────

test("window pending: the section shows only while an item exists and hides with rolls.show off", function()
    local NS, drawn, wp = shown({ drop() }, {})
    assertFalse(wp.header ~= nil and wp.header:IsShown(), "no pending item: no section")
    assertEqual(#wp.rows, 0)
    assertEqual(yOf(drawn.headers[1]), 0, "the boss group starts at the top")
    -- One open roll: the section above the boss group, its header `Rolling now (1)`.
    local pending = { item() }
    stubPending(NS, pending)
    drawn, wp = refresh(NS)
    assertTrue(wp.header:IsShown())
    assertEqual(textOf(wp.header.text), "Rolling now (1)")
    assertEqual(#wp.rows, 1)
    assertTrue(yOf(drawn.headers[1]) < 0, "the boss group moved down under it")
    -- A click on its header collapses it, like a boss group's.
    wp.header:__fire("OnClick")
    wp = select(2, refresh(NS))
    assertEqual(#wp.rows, 0, "collapsed: the header alone")
    assertTrue(wp.header:IsShown())
    wp.header:__fire("OnClick")
    wp = select(2, refresh(NS))
    assertEqual(#wp.rows, 1)
    -- rolls.show off: the section goes, the store is untouched.
    NS.SchemaRuntime.Set("rolls.show", false)
    drawn, wp = refresh(NS)
    assertFalse(wp.header:IsShown()); assertEqual(#wp.rows, 0)
    assertEqual(yOf(drawn.headers[1]), 0)
    assertEqual(#NS.Pending.All(), 1, "tracking still runs")
    -- With no drop in the feed, an open roll keeps the empty state away.
    NS.SchemaRuntime.Set("rolls.show", true)
    NS.LootFeed.Drops = function() return {} end
    NS.LootFeed.Groups = function() return {} end
    drawn = refresh(NS)
    assertFalse(drawn.empty:IsShown(), "not the empty state over Rolling now")
    stubPending(NS, {})
    drawn = refresh(NS)
    assertTrue(drawn.empty:IsShown(), "and back once nothing is pending")
end)

-- tests/perf.lua's refresh pair: a repaint with nothing pending builds no list (Pending.Count, not
-- All) and no feed view table (Window.FeedName, not FeedView).
test("window pending: a repaint with nothing pending never builds the item list", function()
    local NS = shown({ drop() }, {})
    local built, viewed = 0, 0
    local all, feedView = NS.Pending.All, NS.Window.FeedView
    NS.Pending.All = function(...) built = built + 1 return all(...) end
    NS.Window.FeedView = function(...) viewed = viewed + 1 return feedView(...) end
    NS.Pending.Count = function() return 0 end
    refresh(NS)
    NS.SetWindowMode("compact")
    NS.Window.Refresh()
    assertEqual(built, 0, "no list in either layout")
    assertEqual(viewed, 0, "no feed view table")
    assertTrue(NS.WindowPending.None())
    NS.SchemaRuntime.Set("rolls.show", false)
    NS.Pending.Count = function() return 1 end
    assertTrue(NS.WindowPending.None(), "rolls.show off: nothing to show, whatever is pending")
    NS.SchemaRuntime.Set("rolls.show", true)
    assertFalse(NS.WindowPending.None())
    assertEqual(NS.Window.FeedName(), "live")
    NS.State.testMode = true
    assertEqual(NS.Window.FeedName(), "test", "test mode reads the test store")
    NS.State.testMode = false
end)

test("window pending: a pending row has your verdict and no Ask button for a roll", function()
    local NS, _, wp = shown({ drop() }, { item() })
    local row = wp.rows[1]
    local c = row.cells
    assertEqual(textOf(c.item.text), "Band of Embers")
    assertEqual(textOf(c.me.glyph), "▲"); assertEqual(textOf(c.me.text), "+20")
    assertEqual(line(textOf(c.summary.text)), COUNTS, "the roll count line (RX-06)")
    assertEqual(textOf(c.timer.text), "0:50", "the time left on the history's clock")
    assertNil(row.cells.actions, "no action cell"); assertNil(row.ask, "no Ask button for a roll")
    assertTrue(T.tipPlainJoined(c.me.tipLines):find("For you", 1, true) ~= nil, "the verdict's own tooltip")
    assertTrue(NS.WindowPending.Live(NS.WindowGroup.Drawn().pane), "an open roll keeps the countdown ticker alive")
    -- A click expands the roll table under it: the players, the winner and their numbers.
    row:__fire("OnClick")
    local _, wp2 = refresh(NS)
    assertTrue(wp2.box:IsShown(), "the roll table inline")
    assertEqual(textOf(wp2.box.lines[1].name), "Brakk"); assertEqual(textOf(wp2.box.lines[1].roll), "87")
    assertEqual(textOf(wp2.box.lines[2].word), "Greed")
    assertEqual(textOf(wp2.box.lines[4].word), "waiting")
    wp2.rows[1]:__fire("OnClick")
    local _, wp3 = refresh(NS)
    assertFalse(wp3.box:IsShown(), "a second click folds it")
end)

test("window pending: a won or ended roll says so, and the timer ticks on the history's clock", function()
    local NS, _, wp, m = shown({ drop() }, { item() })
    assertEqual(textOf(wp.rows[1].cells.timer.text), "0:50")
    m.lootHistoryTime = 128
    NS.WindowGroup.TickCountdowns()
    assertEqual(textOf(wp.rows[1].cells.timer.text), "0:32", "the tick moved it")
    local ended = { item({ state = "expired" }) }
    stubPending(NS, ended)
    NS.Pending.Get = function() return ended[1] end
    local _, wp2 = refresh(NS)
    assertEqual(textOf(wp2.rows[1].cells.summary.text), "Roll ended")
    assertFalse(NS.WindowPending.Live(NS.WindowGroup.Drawn().pane), "nothing open: no roll keeps the ticker")
    local passed = { item({ state = "allPassed", roll = { allPassed = true, rolls = { player("Brakk", 5) } } }) }
    stubPending(NS, passed)
    _, wp2 = refresh(NS)
    assertEqual(textOf(wp2.rows[1].cells.summary.text), "Everyone passed")
end)

test("window pending: a master-loot item names its master looter, never a roll that ended", function()
    local mlItem = item({ kind = "ml", key = "Creature-0-1-2-3-2900-0000AAAA:300", state = "awaiting", roll = nil,
        ml = { unit = "raid3", name = "Doom Dock", slot = 1, quality = 4, threshold = 4 } })
    mlItem.roll = nil   -- an ml item has no roll table
    local NS, _, wp = shown({ drop() }, { mlItem })
    local c = wp.rows[1].cells
    assertEqual(textOf(c.timer.text), "awaiting master looter")
    assertEqual(plain(textOf(c.summary.text)), "Master looter: Doom Dock", "the master looter, whole (Review Focus 4)")
    assertFalse(NS.WindowPending.Live(NS.WindowGroup.Drawn().pane), "no roll clock to tick")
    NS.WindowGroup.TickCountdowns()
    assertEqual(plain(textOf(c.summary.text)), "Master looter: Doom Dock", "a tick keeps it")
    wp.rows[1]:__fire("OnClick")
    local _, wp2 = refresh(NS)
    assertEqual(textOf(wp2.box.summary), "awaiting master looter", "the inline box never says Roll ended")
    local unnamed = { item({ kind = "ml", state = "awaiting", ml = { slot = 1 } }) }
    unnamed[1].roll = nil
    stubPending(NS, unnamed)
    local _, wp3 = refresh(NS)
    assertEqual(textOf(wp3.rows[1].cells.summary.text), "Master loot", "no name read: the method alone")
end)

test("window pending: a master-loot item has the Ask master looter button, in its ask's state", function()
    local mlItem = item({ kind = "ml", key = "Creature-0-1-2-3-2900-0000AAAA:300", state = "awaiting",
        ml = { unit = "raid3", name = "Doom Dock", slot = 1, quality = 4, threshold = 4 } })
    mlItem.roll = nil
    local NS, _, wp = shown({ drop() }, { mlItem })
    local pressed = {}
    NS.PressAskML = function(id) pressed[#pressed + 1] = id end
    local b = wp.rows[1].ask
    assertTrue(b ~= nil and b:IsShown(), "the row's Ask")
    assertEqual(textOf(b.label), "Ask"); assertEqual(b.state, "ready")
    local tip = T.tipPlainJoined(b.tipLines)
    assertTrue(tip:find("Ask master looter", 1, true) ~= nil, tip)
    assertTrue(tip:find("Doom Dock", 1, true) ~= nil, "it names the master looter whole: " .. tip)
    b:__fire("OnClick")
    assertEqual(#pressed, 1); assertEqual(pressed[1], mlItem.id, "the press names the pending item")
    -- Sent: Asked, and no longer clickable.
    NS.Asks.StateOf = function(kind) return kind == "askML" and "sent" or "ready" end
    local _, wp2 = refresh(NS)
    assertEqual(textOf(wp2.rows[1].ask.label), "Asked"); assertFalse(wp2.rows[1].ask:IsEnabled())
    -- No upgrade for you: the gray No action.
    local worse = item({ kind = "ml", state = "awaiting", ml = { name = "Doom Dock" },
        me = { verdict = "downgrade", ilvlDelta = -10, reasons = {} } })
    worse.roll = nil
    stubPending(NS, { worse })
    _, wp2 = refresh(NS)
    assertEqual(textOf(wp2.rows[1].ask.label), "No action"); assertEqual(wp2.rows[1].ask.state, "none")
    -- A roll's row hides it.
    stubPending(NS, { item() })
    _, wp2 = refresh(NS)
    assertFalse(wp2.rows[1].ask ~= nil and wp2.rows[1].ask:IsShown(), "no Ask on a roll")
end)

-- ── the compact layout ──────────────────────────────────────────────────────────────────────

test("compact: a pending item is a card", function()
    local NS, drawn, wp = shown({ drop() }, { item() }, true)
    assertTrue(drawn.compact)
    assertTrue(wp.compactHeader:IsShown()); assertEqual(textOf(wp.compactHeader.text), "Rolling now (1)")
    assertEqual(#wp.cards, 1)
    local card = wp.cards[1]
    assertEqual(textOf(card.cells.item.text), "Band of Embers")
    assertEqual(textOf(card.cells.youLabel.text), "You")
    assertEqual(textOf(card.cells.me.text), "+20")
    assertEqual(line(textOf(card.cells.summary.text)), COUNTS, "the roll count line (RX-06)")
    assertEqual(textOf(card.cells.timer.text), "0:50")
    assertNil(card.ask, "no action button on a roll's card")
    assertTrue(yOf(drawn.headers[1]) < 0, "the boss group's header under the section")
    -- A master-loot item's card has the Ask master looter button.
    local mlItem = item({ id = 2, kind = "ml", state = "awaiting", ml = { name = "Doom Dock" } })
    mlItem.roll = nil
    stubPending(NS, { mlItem })
    local _, wpm = refresh(NS)
    assertTrue(wpm.cards[1].ask ~= nil and wpm.cards[1].ask:IsShown(), "the card's Ask")
    assertEqual(textOf(wpm.cards[1].ask.label), "Ask")
    stubPending(NS, { item() })
    _, wpm = refresh(NS)
    assertFalse(wpm.cards[1].ask:IsShown(), "hidden again on a roll's card")
    card = wpm.cards[1]
    -- A click expands its roll table under the card.
    card:__fire("OnClick")
    local _, wp2 = refresh(NS)
    assertTrue(wp2.compactBox:IsShown())
    assertEqual(textOf(wp2.compactBox.lines[1].name), "Brakk")
    NS.SchemaRuntime.Set("rolls.show", false)
    _, wp2 = refresh(NS)
    assertEqual(#wp2.cards, 0); assertFalse(wp2.compactHeader:IsShown())
end)

test("window pending: Rolling now's count line has every roll in its tooltip, in both layouts", function()
    -- RX-06 (rolls UX design §3.2, ruling 2): the row's and the card's summary hover the all-rolls
    -- tooltip: the item's name, the players by choice, those still to roll, your verdict at the foot.
    -- red under: the summary's old tooltip (leader and players count)
    local function check(tipLines, where)
        local tip = line(T.tipPlainJoined(tipLines, "\n"))
        assertTrue(tip:find("^Band of Embers") ~= nil, where .. ": the item's name first: " .. tip)
        assertTrue(tip:find("• [UI-GroupLoot-Dice-Up] Need (1): Brakk 87\n", 1, true) ~= nil, where .. ": " .. tip)
        assertTrue(tip:find("• [clock] Waiting (2): Dorn, Seta", 1, true) ~= nil, where .. ": " .. tip)
        assertTrue(tip:find("• You: %+20$") ~= nil, where .. ": the verdict at the foot: " .. tip)
    end
    local NS, _, wp = shown({ drop() }, { item() })
    check(wp.rows[1].cells.summary.tipLines, "row")
    -- The inline Rolls box: its summary is the count line, the tooltip the same.
    wp.rows[1]:__fire("OnClick")
    local _, wp2 = refresh(NS)
    assertEqual(line(textOf(wp2.box.summary)), COUNTS)
    check(wp2.box.summaryHit.tipLines, "box")
    assertFalse(wp2.box.counts:IsShown(), "an open roll's summary is the count line: not drawn twice")
    local _, _, wp3 = shown({ drop() }, { item() }, true)
    local card = wp3.cards[1]
    check((card.cells.summary.hit or card.cells.summary).tipLines, "card")
end)

-- ── the resolved drop: its Rolls box and the row tooltip ────────────────────────────────────

test("detail card: a resolved drop with rec.roll has a Rolls box", function()
    local NS = shown({ drop({ roll = wonRoll() }) }, {})
    local K = NS.Constants.WINDOW
    NS.WindowGroup.ToggleExpand(1)
    local card = NS.WindowGroup.Drawn().card
    assertTrue(card.rolls:IsShown(), "the Rolls box")
    assertEqual(plain(textOf(card.rolls.summary)), "Won by Brakk (Need 87)")
    -- RX-06 (ruling 2): the resolved drop's Rolls box draws the same count line beside its result.
    assertTrue(card.rolls.counts:IsShown(), "the count line")
    assertEqual(line(textOf(card.rolls.counts)), "[UI-GroupLoot-Dice-Up] 1  [UI-GroupLoot-Coin-Up] 1  [clock] 2")
    local bt = line(T.tipPlainJoined(card.rolls.countsHit.tipLines, "\n"))
    assertTrue(bt:find("Brakk 87 (won it)", 1, true) ~= nil and bt:find("^Band of Embers") ~= nil, bt)
    assertEqual(textOf(card.rolls.lines[1].name), "Brakk"); assertEqual(textOf(card.rolls.lines[1].mark), "Won")
    assertTrue(card:GetHeight() > K.CARD_H, "the card is the box taller")
    -- The pure half: none without a table, none with rolls.show off.
    local DC = NS.DetailCells
    assertNil(DC.RollsBox(drop(), true)); assertNil(DC.RollsBox(drop({ roll = wonRoll() }), false))
    assertEqual(#DC.RollsBox(drop({ roll = wonRoll() }), true).rows, 4)
    -- A drop with no roll keeps the card as it was.
    NS.SchemaRuntime.Set("rolls.show", false)
    NS.Window.Refresh()
    card = NS.WindowGroup.Drawn().card
    assertFalse(card.rolls:IsShown())
    assertEqual(card:GetHeight(), K.CARD_H)
end)

test("row tooltip: a rolled drop's item tooltip has the roll summary line", function()
    local NS = shown({ drop({ roll = wonRoll() }) }, {})
    local tip = { lines = {} }
    function tip.AddLine(_, text) tip.lines[#tip.lines + 1] = text end
    assertEqual(NS.RowTooltip.AddRollRow(tip, { dropId = 1 }), 1)
    assertTrue(plain(tip.lines[1]):find("Won by Brakk (Need 87)", 1, true) ~= nil)
    assertEqual(NS.RowTooltip.AddRollRow(tip, { pendingId = 9 }), 0, "no such pending item")
    NS.Pending.Get = function() return item() end
    assertEqual(NS.RowTooltip.AddRollRow(tip, { pendingId = 1 }), 1)
    assertTrue(line(tip.lines[2]):find(COUNTS, 1, true) ~= nil, "the live summary: the count line")
    NS.SchemaRuntime.Set("rolls.show", false)
    assertEqual(NS.RowTooltip.AddRollRow(tip, { dropId = 1 }), 0, "rolls.show off")
end)

-- ── the scale each score used (DW-FP07 ScoreFor, carried from M2) ───────────────────────────

test("detail card: the score row names a best-of-class scale, and the looter's spec row names theirs", function()
    local NS = T.newAddon()
    local DC = NS.DetailCells
    local d = drop({ me = { verdict = "upgrade", ilvlDelta = 19, scoreDelta = 4.5, reasons = {},
        baseline = { link = OLD, ilvl = 292 } } })
    local function scoreTip(how)
        for _, r in ipairs(DC.ForYou(d, "pawn", "WARRIOR", nil, how).rows) do
            if r.key == "score" then return T.tipPlainJoined(r.tip) end
        end
    end
    assertTrue(scoreTip("bestOfClass"):find("the best of your class's", 1, true) ~= nil)
    assertTrue(scoreTip("tree"):find("your own spec's", 1, true) ~= nil)
    assertTrue(scoreTip("none"):find("Scale", 1, true) == nil, "no score source, no Scale row")
    local function specTip(how)
        for _, r in ipairs(DC.ForLooter(d, { at = 60 }, "Arms", 100, nil, nil, how).rows) do
            if r.key == "spec" then return T.tipPlainJoined(r.tip) end
        end
    end
    assertTrue(specTip("bestOfClass"):find("the best of their class's", 1, true) ~= nil)
    assertTrue(specTip(nil):find("Scale", 1, true) == nil)
    -- A score-led upgrade at a lower item level says so (DW-FP08's scoreFirst).
    local led = drop({ me = { verdict = "upgrade", ilvlDelta = -6, scoreDelta = 3, led = "score", reasons = {},
        baseline = { link = OLD, ilvl = 317 } } })
    for _, r in ipairs(DC.ForYou(led, "pawn", "WARRIOR").rows) do
        if r.key == "score" then
            local tip = T.tipPlainJoined(r.tip)
            assertTrue(tip:find("the score (item level breaks a tie)", 1, true) ~= nil)
            assertTrue(tip:find("though its item level is lower", 1, true) ~= nil)
        end
    end
end)

test("detail card: the shipped card asks ScoreFor for both scores", function()
    local NS = shown({ drop() }, {})
    local asked = {}
    NS.Scoring.ScoreFor = function(_, who)
        asked[#asked + 1] = who.isPlayer and "you" or ("them:" .. tostring(who.classFile))
        return 10, who.isPlayer and "bestOfClass" or "tree"
    end
    NS.Scoring.InUse = function() return "pawn" end
    NS.WindowGroup.ToggleExpand(1)
    assertEqual(table.concat(asked, ","), "you,them:WARRIOR")
    assertTrue(NS.WindowGroup.Drawn().card:IsShown())
end)
