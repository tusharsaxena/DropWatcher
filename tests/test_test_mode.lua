-- tests/test_test_mode.lua — test mode (design spec §11.6, boards 03, 04 and 06; ui spec §4): the
-- sample data covers every verdict, trade, inspect and ask state over real pool items
-- (modules/TestData.lua, pure), the test feed fills from the item pool and clears with test mode
-- (modules/TestMode.lua, NS.LootFeed.AddTest), the History tab shows session-only sample groups that
-- never reach the account's history, the window built headless draws every state with a reason and
-- never a blank cell or an unknown item, no button label ends in an ellipsis, and a send is printed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function textOf(region) return region and region:GetText() end

local function hasAll(seen, want, what)
    for _, k in ipairs(want) do assertTrue(seen[k] == true, what .. ": " .. tostring(k)) end
end

local YOU = { name = "Tester", guid = "Player-1-00000001", classFile = "MAGE", isSelf = true }

local SLOTS = { "INVTYPE_HEAD", "INVTYPE_NECK", "INVTYPE_SHOULDER", "INVTYPE_CLOAK", "INVTYPE_CHEST",
    "INVTYPE_WRIST", "INVTYPE_HAND", "INVTYPE_WAIST", "INVTYPE_LEGS", "INVTYPE_FEET", "INVTYPE_FINGER",
    "INVTYPE_TRINKET", "INVTYPE_WEAPON" }

local function poolLink(id, ilvl)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[Real %d]|h|r"):format(id, ilvl, id)
end

-- A pool of real-looking items: two drops per slot at 300, and worn items at 290 and 320.
local function fakePool(slots)
    local drops, gear, ids = {}, {}, {}
    for i, loc in ipairs(slots or SLOTS) do
        for copy = 1, 2 do
            local id = 8000 + i * 10 + copy
            local e = { link = poolLink(id, 300), itemID = id, equipLoc = loc, ilvl = 300 }
            drops[#drops + 1], gear[#gear + 1], ids[id] = e, e, true
        end
        for k, lvl in ipairs({ 290, 320 }) do
            local id = 9000 + i * 10 + k
            gear[#gear + 1], ids[id] = { link = poolLink(id, lvl), itemID = id, equipLoc = loc, ilvl = lvl }, true
        end
    end
    return drops, gear, ids
end

local function source(NS, slots)
    local drops, gear, ids = fakePool(slots)
    local function factsOf(e) return { ilvl = e.ilvl, equipLoc = e.equipLoc, quality = 4 } end
    return NS.TestData.Source(drops, gear, factsOf), ids, gear
end

local function placeholders()
    local NS = T.newAddon()
    local src, ids, gear = source(NS)
    return NS, NS.TestMode.Placeholders(1000, YOU, src), ids, gear
end

local function others(specs)
    local out = {}
    for _, s in ipairs(specs) do if not s.looter.isSelf then out[#out + 1] = s end end
    return out
end

local function yours(specs)
    local out = {}
    for _, s in ipairs(specs) do if s.looter.isSelf then out[#out + 1] = s end end
    return out
end

local function idOf(link) return tonumber(link:match("item:(%d+)")) end

-- ── the data (pure) ─────────────────────────────────────────────────────────────────────────

test("test mode data: the other members' drops cover every Me and Them verdict (board 03)", function()
    local _, specs = placeholders()
    local me, them = {}, {}
    for _, s in ipairs(others(specs)) do
        me[s.me.verdict] = true
        them[s.them and s.them.verdict or "none"] = true
    end
    hasAll(me, { "upgrade", "sidegrade", "downgrade", "cantUse", "doesntWant", "unknown" }, "Me")
    hasAll(them, { "upgrade", "sidegrade", "downgrade", "cantUse", "none" }, "Them")
end)

test("test mode data: every trade estimate, inspect state and ask state is there", function()
    local _, specs = placeholders()
    local trade, insp, ask = {}, {}, {}
    for _, s in ipairs(others(specs)) do
        trade[s.trade.state] = true
        insp[s.testInspect.status] = true
        assertEqual(s.inspect.status, s.testInspect.status, "the drop's inspect matches its entry")
        ask[s.testAsk and s.testAsk.state or "ready"] = true
    end
    hasAll(trade, { "yes", "likely", "unknown", "no" }, "trade")
    hasAll(insp, { "fresh", "cached", "pending", "outOfRange", "combatParked", "failed", "unavailable" }, "inspect")
    hasAll(ask, { "ready", "queued", "sent", "failed", "traded" }, "ask")
end)

test("test mode data: your own drops cover every countdown and every candidate pill (board 04)", function()
    local NS, specs = placeholders()
    local MC = NS.MineCells
    local pills, kinds = {}, {}
    for _, s in ipairs(yours(specs)) do
        local drop = { at = 1000 - s.ago, trade = s.trade, candidates = s.candidates, facts = s.facts, me = s.me }
        local cd = MC.Countdown(drop, 1000)
        if s.trade.state == "no" then kinds.expired = true
        elseif s.trade.reasonKey == "boe" then kinds.boe = true
        elseif cd.exact and cd.left <= 600 then kinds.soon = true
        elseif cd.exact then kinds.exact = true
        else kinds.estimated = true end
        for _, c in ipairs(MC.Candidates(drop)) do pills[c.pill.text:gsub("^%+%d+ ", "")] = true end
    end
    hasAll(kinds, { "exact", "soon", "estimated", "boe", "expired" }, "countdown")
    hasAll(pills, { "UPGRADE", "EQUAL", "NO UPGRADE", "CAN'T USE", "CHECKING", "UNAVAILABLE" }, "pill")
end)

test("test mode data: two groups, a boss and a key run, every item a pool item that keeps its slot", function()
    local NS, specs, ids = placeholders()
    local groups, slots = {}, {}
    for _, s in ipairs(specs) do
        groups[s.group.kind] = true
        assertTrue(ids[idOf(s.link)] == true, "a pool item, never an invented one: " .. s.link)
        assertEqual(s.facts.ilvl, 300, "the item level is the real link's")
        slots[s.facts.equipLoc] = true
        assertTrue(s.situation ~= nil)
    end
    hasAll(groups, { "encounter", "run" }, "group")
    hasAll(slots, { "INVTYPE_HEAD", "INVTYPE_FINGER", "INVTYPE_TRINKET", "INVTYPE_CLOAK", "INVTYPE_WEAPON" }, "slot")
    assertEqual(#specs, 16)
    assertTrue(NS.TestData.MEMBERS.seta.name == "Seta", "the names are invented")
end)

test("test mode data: worn items are other pool items of the slot, nearest the level the change implies", function()
    local _, specs, ids = placeholders()
    local checked = 0
    for _, s in ipairs(specs) do
        for _, eval in ipairs({ s.me, s.them or false }) do
            local base = eval and eval.baseline
            if base then
                checked = checked + 1
                assertTrue(ids[idOf(base.link)] == true, "a pool item")
                assertTrue(base.link ~= s.link, "not the drop itself")
                local want = s.facts.ilvl - eval.ilvlDelta
                for _, lvl in ipairs({ 290, 300, 320 }) do
                    assertTrue(math.abs(base.ilvl - want) <= math.abs(lvl - want), "the nearest level")
                end
            end
        end
        if s.testInspect then
            for _, worn in pairs(s.testInspect.gear) do assertTrue(ids[idOf(worn.link)] == true) end
        end
    end
    assertTrue(checked >= 15, tostring(checked))
end)

test("test mode data: the trade reason's two levels are the drop's and the looter's worn item's", function()
    local _, specs = placeholders()
    local n = 0
    for _, s in ipairs(others(specs)) do
        if s.trade.reasonKey == "notUpgrade" and s.them and s.them.baseline then
            assertEqual(s.trade.args[1], s.facts.ilvl)
            assertEqual(s.trade.args[2], s.them.baseline.ilvl)
            n = n + 1
        end
    end
    assertTrue(n >= 2)
end)

test("test mode data: an empty pool gives no sample, and a pool short of a slot borrows a real item", function()
    local NS = T.newAddon()
    local TD = NS.TestData
    assertEqual(#TD.Placeholders(1000, YOU, TD.Source({}, {}, nil)), 0)
    assertEqual(#TD.History(1000, YOU, TD.Source({}, {}, nil)).groups, 0)
    local src, ids = source(NS, { "INVTYPE_FINGER" })
    local specs = TD.Placeholders(1000, YOU, src)
    assertEqual(#specs, 16, "every state still shows")
    for _, s in ipairs(specs) do assertTrue(ids[idOf(s.link)] == true) end
end)

test("test mode data: the History sample has two groups and every outcome, oldest first", function()
    local NS = T.newAddon()
    local src, ids = source(NS)
    local log = NS.TestData.History(100000, YOU, src)
    assertEqual(#log.groups, 2)
    assertTrue(log.groups[1].at < log.groups[2].at, "oldest first")
    local outcomes, mine = {}, 0
    for _, g in ipairs(log.groups) do
        for _, e in ipairs(g.drops) do
            outcomes[e.outcome] = true
            assertTrue(ids[e.itemID] == true, "a pool item")
            assertTrue(e.test == true)
            if e.isMine then mine = mine + 1 end
        end
    end
    hasAll(outcomes, NS.History.OUTCOMES, "outcome")
    assertTrue(mine >= 3, "your own drops show offered, traded away and expired")
end)

-- ── the feed ────────────────────────────────────────────────────────────────────────────────

test("feed: AddTest puts a sample in the test feed as given, never in the live one", function()
    local NS = T.enableAddon()
    local LF = NS.LootFeed
    local spec = NS.TestMode.Placeholders(1000, YOU, (source(NS)))[1]
    local id, status = LF.AddTest(spec)
    assertEqual(status, "added")
    local rec = LF.Get(id)
    assertTrue(rec.test); assertEqual(rec.feed, "test")
    assertTrue(rec.me == spec.me, "the verdict is the spec's, not judged")
    assertTrue(rec.trade == spec.trade)
    assertEqual(#LF.Drops("test"), 1); assertEqual(#LF.Drops("live"), 0)
    assertEqual(LF.Groups("test")[1].label, spec.group.label)
end)

test("feed: AddTest refuses a spec with no item, no looter or no group, and while stood down", function()
    local NS = T.enableAddon()
    local LF = NS.LootFeed
    local good = NS.TestMode.Placeholders(1000, YOU, (source(NS)))[1]
    assertEqual(select(2, LF.AddTest({ link = "nope", looter = good.looter, group = good.group })), "notItem")
    assertEqual(select(2, LF.AddTest({ link = good.link, group = good.group })), "notItem")
    assertEqual(select(2, LF.AddTest({ link = good.link, looter = good.looter })), "notItem")
    assertEqual(select(2, LF.AddTest(nil)), "notItem")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(select(2, LF.AddTest(good)), "stoodDown")
end)

-- The journal's item ids (tests/wow_mock.lua seedGearJournal).
local function journalIds(m)
    local ids = {}
    for _, byDifficulty in pairs(m.journal.loot) do
        for _, list in pairs(byDifficulty) do
            for _, e in ipairs(list) do ids[e.itemID] = true end
        end
    end
    return ids
end

-- Every seeded journal entry left to load once more.
local function unloaded(m)
    for _, list in pairs(m.journal.loot[901]) do
        for _, e in ipairs(list) do e.loadsNeeded = 1 end
    end
end

test("test mode: on fills the test feed from the item pool, off empties it; the live feed is never touched", function()
    local NS, _, m = T.enableAddon()
    local LF = NS.LootFeed
    m.seedGearJournal()
    NS.SetTestMode(true)
    assertEqual(#LF.Drops("test"), 16)
    assertEqual(#LF.Drops("live"), 0)
    local ids = journalIds(m)
    for _, rec in ipairs(LF.Drops("test")) do
        assertTrue(ids[rec.itemID] == true, "a journal item, never an unknown id: " .. tostring(rec.link))
        assertTrue(rec.link:find("[Vault ", 1, true) ~= nil, rec.link)
        assertEqual(rec.facts.ilvl, 300, "the Mythic Keystone drop's own level")
        assertTrue(NS.Compat.ItemIcon(rec.link) ~= 134400, "a real icon, not the question mark")
    end
    NS.SetTestMode(false)
    assertEqual(#LF.Drops("test"), 0)
    NS.SetTestMode(true)
    assertEqual(#LF.Drops("test"), 16, "turned on again: filled again, not doubled")
end)

test("test mode: while the pool loads the tab says so and holds no drop; the drops fill in when it is ready", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    unloaded(m)
    NS.SetTestMode(true)
    NS.Window.Refresh()
    assertEqual(#NS.LootFeed.Drops("test"), 0, "no invented item meanwhile")
    assertTrue(NS.TestMode.IsLoading())
    local drawn = NS.WindowGroup.Drawn()
    assertFalse(drawn.empty:IsShown(), "not the live empty state")
    assertEqual(textOf(drawn.pane.placeholder), "Gathering real items for test mode.")
    m.loadJournal()
    m.advance(1)
    assertFalse(NS.TestMode.IsLoading())
    assertEqual(#NS.LootFeed.Drops("test"), 16)
end)

test("test mode: turned off while the pool loads, nothing arrives later", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    unloaded(m)
    NS.SetTestMode(true)
    NS.SetTestMode(false)
    m.loadJournal()
    m.advance(10)
    assertEqual(#NS.LootFeed.Drops("test"), 0)
    assertTrue(NS.State.testPool == nil)
end)

test("test mode: with no journal and no gear of your own there is no sample, and it says so", function()
    local NS, _, m = T.enableAddon()
    NS.SetTestMode(true)
    NS.Window.Refresh()
    assertEqual(#NS.LootFeed.Drops("test"), 0)
    local said = 0
    for _, line in ipairs(m.prints) do
        if line:find("Test mode found no items to show.", 1, true) then said = said + 1 end
    end
    assertEqual(said, 1)
    assertEqual(textOf(NS.WindowGroup.Drawn().pane.placeholder), "Test mode found no items to show.")
end)

test("test mode: combat and the stand-down both empty the test feed", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(#NS.LootFeed.Drops("test"), 0)
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    NS.SetTestMode(true)
    NS.SchemaRuntime.Set("enabled", false)
    assertFalse(NS.State.testMode)
    assertEqual(#NS.LootFeed.Drops("test"), 0)
end)

test("test mode: the Group drops tab shows View: All while on, and the player's View comes back", function()
    local NS = T.enableAddon()
    local FB = NS.WindowFilterBar
    assertEqual(FB.State("group").view, "interesting")
    NS.SetTestMode(true)
    assertEqual(FB.State("group").view, "all")
    NS.SetTestMode(false)
    assertEqual(FB.State("group").view, "interesting")
end)

-- ── the History tab (FB-10) ─────────────────────────────────────────────────────────────────

test("history: test mode shows its sample groups, every outcome, and never writes the account's history", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    local H = NS.History
    NS.SetTestMode(true)
    local groups, outcomes = H.Groups(), {}
    assertEqual(#groups, 2)
    for _, g in ipairs(groups) do
        for _, e in ipairs(g.drops) do outcomes[e.outcome] = true end
    end
    hasAll(outcomes, H.OUTCOMES, "outcome")
    assertEqual(#H.Store().groups, 0, "nothing in global.history")
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    local drawn = NS.WindowHistory.Drawn()
    assertEqual(#drawn.headers, 2)
    assertTrue(#drawn.rows >= 1)
    H.Clear()
    assertEqual(#H.Groups(), 0, "Clear history clears the samples")
    assertEqual(#H.Store().groups, 0)
    NS.SetTestMode(false)
    assertTrue(NS.State.testHistory == nil, "the samples leave with test mode")
end)

test("history: the account's kept groups come back when test mode ends", function()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    local H = NS.History
    local kept = { key = "k@1", label = "Old boss", kind = "encounter", at = 1, drops = {
        { itemLink = "|cnIQ4:|Hitem:1::::::::90:::::|h[Old]|h|r", outcome = "seen", at = 1 } } }
    H.Store().groups = { kept }
    NS.SetTestMode(true)
    assertEqual(#H.Groups(), 2)
    assertEqual(H.Groups()[1].label, "Placeholder key run")
    NS.SetTestMode(false)
    assertEqual(#H.Groups(), 1)
    assertTrue(H.Groups()[1] == kept)
end)

-- ── the window ──────────────────────────────────────────────────────────────────────────────

-- Test mode on over the seeded journal, the window shown, and every group expanded.
local function shownTest()
    local NS, _, m = T.enableAddon()
    m.seedGearJournal()
    NS.SetTestMode(true)
    for _, g in ipairs(NS.LootFeed.Groups("test")) do NS.State.windowGroup.collapsed[g.key] = false end
    NS.Window.Refresh()
    return NS, NS.WindowGroup.Drawn(), m
end

test("window: test mode draws every sample, under the boss and the key run, with real icons", function()
    local NS, drawn = shownTest()
    local f = NS.Window.Frame()
    assertTrue(f.banner:IsShown()); assertTrue(f.testText:IsShown())
    assertEqual(textOf(f.testText.text), "TEST MODE")
    assertTrue(textOf(f.banner.text):find("Nothing is whispered") ~= nil)
    assertTrue(textOf(f.banner.text):find("real items", 1, true) ~= nil)
    assertEqual(NS.Window.TooltipOf(f.banner)[1], "Test mode")
    assertEqual(#drawn.headers, 2)
    local notMine = 0
    for _, d in ipairs(NS.LootFeed.Drops("test")) do
        if not d.isMine then notMine = notMine + 1 end
    end
    assertEqual(#drawn.rows, notMine, "your own samples go to My drops (feed.showOwn off)")
    for _, r in ipairs(drawn.rows) do
        local tex = r.cells.item.button.art:GetTexture()
        assertTrue(tex ~= 134400 and tex ~= NS.Icon("help"), "a real icon: " .. tostring(tex))
    end
    assertFalse(drawn.empty:IsShown())
    NS.addon.db.profile.feed = { showOwn = true }
    NS.Window.Refresh()
    assertEqual(#NS.WindowGroup.Drawn().rows, #NS.LootFeed.Drops("test"), "showOwn on: every sample")
end)

test("window: every cell of every sample row says something and has a reason", function()
    local _, drawn = shownTest()
    for _, r in ipairs(drawn.rows) do
        for key, cell in pairs(r.cells) do
            if cell.text and cell:IsShown() then
                local text = textOf(cell.text)
                assertTrue(type(text) == "string" and text ~= "", ("row %s %s is blank"):format(r.dropId, key))
                local itemTip = cell.showItem and cell.itemButton.link ~= nil   -- the real item tooltip (DW-80)
                assertTrue(itemTip or (type(cell.tipLines) == "table" and #cell.tipLines >= 2),
                    ("row %s %s has no reason"):format(r.dropId, key))
            end
        end
    end
end)

-- The worn item a sample's looter was inspected wearing, or nil.
local function wornOf(NS, dropId)
    local insp = NS.TestMode.InspectOf(NS.LootFeed.Get(dropId))
    if not (insp and insp.gear) then return nil end
    local _, worn = next(insp.gear)
    return worn
end

test("window: the rows show every ask state, every Their eq state and every trade chip", function()
    local NS, drawn = shownTest()
    local ask, eq, trade, levels = {}, {}, {}, 0
    for _, r in ipairs(drawn.rows) do
        local a = r.cells.actions
        ask[a.ask:IsShown() and textOf(a.ask.label) or textOf(a.dash)] = true
        local text = textOf(r.cells.theirEq.text)
        eq[text] = true
        local worn = wornOf(NS, r.dropId)
        if worn then
            assertEqual(text, tostring(worn.ilvl), "the worn item's real level")
            levels = levels + 1
        end
        trade[textOf(r.cells.trade.text)] = true
    end
    hasAll(ask, { "Ask", "Queued", "Asked", "Retry", "–" }, "ask")
    hasAll(eq, { "…", "range", "combat", "!", "–" }, "their eq: the reason word")
    assertTrue(levels >= 5, "the inspected looters' worn levels")
    hasAll(trade, { "Yes", "Likely", "Unknown", "No" }, "trade")
end)

test("window: a sample's Their eq shows its own worn item, and its detail card its own inspect", function()
    local NS, drawn = shownTest()
    local crown
    for _, r in ipairs(drawn.rows) do
        local d = NS.LootFeed.Get(r.dropId)
        if d.looter.name == "Seta" and d.facts.equipLoc == "INVTYPE_HEAD" then crown = r end
    end
    assertTrue(crown.cells.theirEq.icons[1]:IsShown(), "the worn item's button")
    NS.WindowGroup.ToggleExpand(crown.dropId)
    local spec = NS.TestMode.InspectOf(NS.LootFeed.Get(crown.dropId))
    assertEqual(spec.status, "fresh")
    assertEqual(NS.WindowGroup.Drawn().cardDropId, crown.dropId)
end)

test("window: the My drops tab counts your tradeable samples and draws them all", function()
    local NS = shownTest()
    NS.Window.SelectTab("mine")
    local f = NS.Window.Frame()
    assertEqual(textOf(f.tabs.mine.label), "My drops · 4")
    local drawn = NS.WindowMine.Drawn()
    assertEqual(#drawn.rows, 5)
end)

test("window: the empty state comes back once test mode ends with nothing in the live feed", function()
    local NS = shownTest()
    NS.ShowWindow()
    NS.SetTestMode(false)
    local drawn = NS.WindowGroup.Drawn()
    assertTrue(drawn.empty:IsShown())
    assertEqual(#drawn.rows, 0)
end)

-- ── no trailing ellipsis (FB-11) ────────────────────────────────────────────────────────────

test("labels: My drops says Offer, and no cell of its rows ends in an ellipsis", function()
    local NS = shownTest()
    NS.Window.SelectTab("mine")
    local offers = 0
    for _, r in ipairs(NS.WindowMine.Drawn().rows) do
        local a = r.cells.actions
        if a.offer:IsShown() then
            assertEqual(textOf(a.offer.label), "Offer")
            offers = offers + 1
        end
        for key, cell in pairs(r.cells) do
            local text = type(cell) == "table" and cell.text and textOf(cell.text)
            if type(text) == "string" then
                assertFalse(text:find("…$") ~= nil, ("%s ends in an ellipsis: %s"):format(key, text))
            end
        end
    end
    assertTrue(offers >= 1)
end)

test("labels: no button the addon builds is labeled with a trailing ellipsis", function()
    local files = { "modules/WindowTitleBar.lua", "modules/WindowGroup.lua", "modules/WindowMine.lua",
        "modules/OfferPanel.lua", "modules/WindowHistory.lua", "modules/DetailCard.lua", "modules/Toast.lua" }
    local buttons = 0
    for _, path in ipairs(files) do
        local fh = assert(io.open(path, "rb"))
        local src = fh:read("*a")
        fh:close()
        for call in src:gmatch("TextButton(%b())") do
            buttons = buttons + 1
            assertFalse(call:find('…"%]') ~= nil, path .. ": " .. call)
        end
    end
    assertTrue(buttons >= 10)
end)

-- ── nothing is sent ─────────────────────────────────────────────────────────────────────────

test("sends: Ask on a sample prints the text and sends nothing; its state is the edge's from then on", function()
    local NS, drawn, m = shownTest()
    local ready
    for _, r in ipairs(drawn.rows) do
        local a = r.cells.actions
        if a.ask:IsShown() and textOf(a.ask.label) == "Ask" then ready = r end
    end
    local before = #m.prints
    ready.cells.actions.ask:__fire("OnClick")
    assertEqual(#(m.chatSent or {}), 0, "never sent")
    local said = false
    for i = before + 1, #m.prints do
        if m.prints[i]:find("Test mode, not sent:", 1, true) then said = true end
    end
    assertTrue(said, "printed instead")
    local rec = NS.LootFeed.Get(ready.dropId)
    assertEqual((NS.TestMode.AskState(rec, NS.Asks.StateOf("ask", NS.AskTargetOf(rec), rec.id))), "sent")
end)

test("sends: Post my tradeables in test mode prints its lines and sends nothing", function()
    local NS, _, m = shownTest()
    assertTrue(NS.PostTradeables() >= 1)
    assertEqual(#(m.chatSent or {}), 0)
    assertTrue(m.prints[#m.prints]:find("Test mode, not sent:", 1, true) ~= nil)
end)

test("hooks: AskState shows a sample's own state only while the edge holds none", function()
    local NS = T.newAddon()
    local TM = NS.TestMode
    local d = { test = true, testAsk = { state = "queued" } }
    assertEqual((TM.AskState(d, "ready")), "queued")
    assertEqual((TM.AskState(d, "sent")), "sent", "the edge's state wins")
    assertEqual((TM.AskState({ testAsk = { state = "queued" } }, "ready")), "ready", "a live drop's is ignored")
    assertTrue(TM.InspectOf({ isMine = true, test = true, testInspect = {} }) == nil, "your own drop has none")
end)
