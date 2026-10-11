-- tests/test_test_mode.lua — test mode's placeholder drops (design spec §11.6, boards 03, 04 and
-- 06): the data covers every verdict, trade, inspect and ask state (modules/TestMode.lua's pure
-- half), the test feed fills and clears with test mode (NS.LootFeed.AddTest), the window built
-- headless draws every state with a reason and never a blank cell, and a send is printed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local function textOf(region) return region and region:GetText() end

local function hasAll(seen, want, what)
    for _, k in ipairs(want) do assertTrue(seen[k] == true, what .. ": " .. tostring(k)) end
end

local YOU = { name = "Tester", guid = "Player-1-00000001", classFile = "MAGE", isSelf = true }

local function placeholders()
    local NS = T.newAddon()
    return NS, NS.TestMode.Placeholders(1000, YOU)
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
    hasAll(pills, { "UPGRADE", "EQUAL", "NO UPGRADE", "CAN'T USE", "CHECKING…", "UNAVAILABLE" }, "pill")
end)

test("test mode data: two groups, a boss and a key run, and every item is a placeholder", function()
    local _, specs = placeholders()
    local groups = {}
    for _, s in ipairs(specs) do
        groups[s.group.kind] = true
        assertTrue(s.link:find("|h%[Placeholder ") ~= nil, s.link)
        assertTrue(s.situation ~= nil)
    end
    hasAll(groups, { "encounter", "run" }, "group")
end)

-- ── the feed ────────────────────────────────────────────────────────────────────────────────

test("feed: AddTest puts a placeholder in the test feed as given, never in the live one", function()
    local NS = T.enableAddon()
    local LF = NS.LootFeed
    local spec = NS.TestMode.Placeholders(1000, YOU)[1]
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
    local good = NS.TestMode.Placeholders(1000, YOU)[1]
    assertEqual(select(2, LF.AddTest({ link = "nope", looter = good.looter, group = good.group })), "notItem")
    assertEqual(select(2, LF.AddTest({ link = good.link, group = good.group })), "notItem")
    assertEqual(select(2, LF.AddTest({ link = good.link, looter = good.looter })), "notItem")
    assertEqual(select(2, LF.AddTest(nil)), "notItem")
    NS.SchemaRuntime.Set("enabled", false)
    assertEqual(select(2, LF.AddTest(good)), "stoodDown")
end)

test("test mode: on fills the test feed, off empties it; the live feed is never touched", function()
    local NS = T.enableAddon()
    local LF = NS.LootFeed
    local n = #NS.TestMode.Placeholders(1000, YOU)
    NS.SetTestMode(true)
    assertEqual(#LF.Drops("test"), n)
    assertEqual(#LF.Drops("live"), 0)
    NS.SetTestMode(false)
    assertEqual(#LF.Drops("test"), 0)
    NS.SetTestMode(true)
    assertEqual(#LF.Drops("test"), n, "turned on again: filled again, not doubled")
end)

test("test mode: combat and the stand-down both empty the test feed", function()
    local NS, _, m = T.enableAddon()
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

-- ── the window ──────────────────────────────────────────────────────────────────────────────

-- Test mode on, the window shown, and every group expanded.
local function shownTest()
    local NS, _, m = T.enableAddon()
    NS.SetTestMode(true)
    for _, g in ipairs(NS.LootFeed.Groups("test")) do NS.State.windowGroup.collapsed[g.key] = false end
    NS.Window.Refresh()
    return NS, NS.WindowGroup.Drawn(), m
end

test("window: test mode draws every placeholder, under the boss and the key run", function()
    local NS, drawn = shownTest()
    local f = NS.Window.Frame()
    assertTrue(f.banner:IsShown()); assertTrue(f.testChip:IsShown())
    assertEqual(textOf(f.testChip.text), "TEST MODE")
    assertTrue(textOf(f.banner.text):find("Nothing is whispered") ~= nil)
    assertEqual(NS.Window.TooltipOf(f.banner)[1], "Test mode")
    assertEqual(#drawn.headers, 2)
    local notMine = 0
    for _, d in ipairs(NS.LootFeed.Drops("test")) do
        if not d.isMine then notMine = notMine + 1 end
    end
    assertEqual(#drawn.rows, notMine, "your own placeholders go to My drops (feed.showOwn off)")
    assertFalse(drawn.empty:IsShown())
    NS.addon.db.profile.feed = { showOwn = true }
    NS.Window.Refresh()
    assertEqual(#NS.WindowGroup.Drawn().rows, #NS.LootFeed.Drops("test"), "showOwn on: every placeholder")
end)

test("window: every cell of every placeholder row says something and has a reason", function()
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

test("window: the rows show every ask state, every Their eq state and every trade chip", function()
    local _, drawn = shownTest()
    local ask, eq, trade = {}, {}, {}
    for _, r in ipairs(drawn.rows) do
        local a = r.cells.actions
        ask[a.ask:IsShown() and textOf(a.ask.label) or textOf(a.dash)] = true
        eq[textOf(r.cells.theirEq.text)] = true
        trade[textOf(r.cells.trade.text)] = true
    end
    hasAll(ask, { "Ask", "Queued", "Asked", "Retry", "–" }, "ask")
    hasAll(eq, { "40s", "6m", "…", "range", "combat", "!", "–" }, "their eq")
    hasAll(trade, { "Yes", "Likely", "Unknown", "No" }, "trade")
end)

test("window: a placeholder's Their eq shows its own worn item, and its detail card its own inspect", function()
    local NS, drawn = shownTest()
    local crown
    for _, r in ipairs(drawn.rows) do
        if textOf(r.cells.item.text) == "Placeholder Crown" then crown = r end
    end
    assertTrue(crown.cells.theirEq.icons[1]:IsShown(), "the worn item's button")
    NS.WindowGroup.ToggleExpand(crown.dropId)
    local spec = NS.TestMode.InspectOf(NS.LootFeed.Get(crown.dropId))
    assertEqual(spec.status, "fresh")
    assertEqual(NS.WindowGroup.Drawn().cardDropId, crown.dropId)
end)

test("window: the My drops tab counts your tradeable placeholders and draws them all", function()
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

-- ── nothing is sent ─────────────────────────────────────────────────────────────────────────

test("sends: Ask on a placeholder prints the text and sends nothing; its state is the edge's from then on", function()
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

test("hooks: AskState shows a placeholder's own state only while the edge holds none", function()
    local NS = T.newAddon()
    local TM = NS.TestMode
    local d = { test = true, testAsk = { state = "queued" } }
    assertEqual((TM.AskState(d, "ready")), "queued")
    assertEqual((TM.AskState(d, "sent")), "sent", "the edge's state wins")
    assertEqual((TM.AskState({ testAsk = { state = "queued" } }, "ready")), "ready", "a live drop's is ignored")
    assertTrue(TM.InspectOf({ isMine = true, test = true, testInspect = {} }) == nil, "your own drop has none")
end)
