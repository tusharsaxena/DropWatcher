-- tests/test_collect_feed.lua — a collectible through the feed (issue #13, categories design spec
-- §3.2, §4.3-§4.6, §6.2): judged by its collection verdict, never the gear kernel; no looter inspect
-- and no Them; your own one judged for nobody (none inspected, also through the trade re-estimate);
-- the trade estimate's `collectible` answer; someone else's kept out of the trade sweep and your own
-- kept in; `newCollect` through the quality gate's override; the collection events coalesced into
-- one re-read that re-judges only the drops whose verdict moved, the regen pass for the unknown ones
-- alone, and the stand-down canceling the timer; and the feed-only refusals at the edges (Asks,
-- the Offer panel and `/dw offer`, auto-ask); and an Always watch drop of no kind keeping the list's
-- answer from its admission through a later re-judge.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK, LYRA = "Player-1-0000000A", "Player-2-0000000B"
local MISC, MOUNT_SUB, ARMOR, COSMETIC_SUB = 15, 5, 4, 5

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = ARMOR, subClassID = 0,
        bindType = 1, stats = {} }
end

-- A mount item (the Miscellaneous > Mount class rung); `quality` 4 unless given.
local function mount(quality)
    return { name = "Reins", quality = quality or 4, ilvl = 1, equipLoc = "", classID = MISC, subClassID = MOUNT_SUB,
        bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled instance in a Heroic dungeon: two 600 rings worn; Brakk and Lyra in the group.
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    NS.Roster.Refresh("test")
    return NS, m, NS.LootFeed
end

-- Mount item `id` as mount `mountID`, collected (true), not (false) or with no answer (nil).
local function addMount(m, id, mountID, known, quality)
    m.addItem(link(id), mount(quality))
    m.mounts.byItem[id] = mountID
    m.mounts.collected[mountID] = known
end

local function chat(m, text)
    return m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

local function brakkLoots(m, id) chat(m, "Brakk receives loot: " .. link(id) .. ".") end
local function iLoot(m, id) chat(m, "You receive loot: " .. link(id) .. ".") end

local function updates(NS)
    local seen = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.DROP_UPDATED, function(_, id, cause)
        seen[#seen + 1] = id .. ":" .. tostring(cause)
    end)
    return seen
end

local function count(list, value)
    local n = 0
    for _, v in ipairs(list) do if v == value then n = n + 1 end end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- The judge path
-- ---------------------------------------------------------------------------------------------

test("collect feed: someone else's mount reads its collection verdict, asks no inspect and has no Them", function()
    local NS, m, LF = party()
    addMount(m, 300, 77, false)
    brakkLoots(m, 300)
    local rec = LF.Drops()[1]
    -- red under: judgeMe without the collectible hook (the gear kernel's `unknown notGear`)
    assertEqual(rec.me.verdict, "newCollect"); assertTrue(rec.me.collect); assertEqual(rec.me.category, "mount")
    assertNil(rec.them)
    -- red under: judgeLooter requesting the looter's inspect for a collectible
    assertEqual(NS.Inspect.QueueState().queued, 0, "no looter inspect")
    assertNil(rec.inspect)
    assertEqual(rec.trade.state, "unknown"); assertEqual(rec.trade.reasonKey, "collectible")
    assertEqual(rec.trade.basis, "rule")
end)

test("collect feed: your own mount is judged for nobody, none inspected, also when its trade leaves no", function()
    local NS, m, LF = party()
    addMount(m, 300, 77, true)
    iLoot(m, 300)
    local rec = LF.Drops()[1]
    assertEqual(rec.me.verdict, "collected")
    -- red under: judgeCandidates without its guard (every member judged and inspected)
    assertNil(next(rec.candidates), "no candidates")
    assertEqual(NS.Inspect.QueueState().queued, 0)
    rec.trade = { state = "no", reasonKey = "expired", basis = "rule", args = {} }
    assertEqual(LF.SweepTrade(true), 1, "your own collectible moved off no")
    -- red under: the guard only in judgeLooter, so reestimate's own judgeCandidates asked again
    assertNil(next(rec.candidates)); assertEqual(NS.Inspect.QueueState().queued, 0)
end)

test("collect feed: the trade sweep drops someone else's collectible and keeps your own", function()
    local _, m, LF = party()
    addMount(m, 300, 77, false)
    addMount(m, 301, 78, false)
    brakkLoots(m, 300)
    iLoot(m, 301)
    local theirs, mine = LF.Drops()[1], LF.Drops()[2]
    theirs.trade = { state = "likely", reasonKey = "notUpgrade", basis = "inspect", args = {} }
    mine.trade = { state = "likely", reasonKey = "notUpgrade", basis = "inspect", args = {} }
    -- red under: mayChange keeping someone else's `unknown` collectible in the sweep
    assertEqual(LF.SweepTrade(), 1, "your own only")
    assertEqual(mine.trade.reasonKey, "collectible")
    assertEqual(theirs.trade.reasonKey, "notUpgrade", "someone else's is not re-estimated")
end)

test("collect feed: a mount new to your collection passes the quality gate's override; a collected one does not", function()
    local _, m, LF = party()
    addMount(m, 300, 77, false, 1)
    addMount(m, 301, 78, true, 1)
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    -- red under: QualityGate's override for `upgrade` alone
    assertEqual(#LF.Drops(), 1, "the common new mount shows")
    assertEqual(LF.Drops()[1].quality.reason, "upgradeOverride")
    assertEqual(LF.Stats().hidden.quality, 1, "the common collected one is hidden")
end)

-- ---------------------------------------------------------------------------------------------
-- Reading the collections again
-- ---------------------------------------------------------------------------------------------

-- Spy on ItemFacts.RereadCollections: answers the call counter.
local function spyReread(NS)
    local calls, real = { n = 0 }, NS.ItemFacts.RereadCollections
    NS.ItemFacts.RereadCollections = function(...)
        calls.n = calls.n + 1
        return real(...)
    end
    return calls
end

test("collect feed: a burst of collection events reads once, and re-judges only the drop that moved", function()
    local NS, m, LF = party()
    addMount(m, 300, 77, false)
    addMount(m, 301, 78, false)
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    local seen, calls = updates(NS), spyReread(NS)
    local learned, other = LF.Drops()[1], LF.Drops()[2]
    m.mounts.collected[77] = true
    m.__fire("NEW_MOUNT_ADDED", 77)
    m.__fire("NEW_MOUNT_ADDED", 77)
    m.__fire("SKILL_LINES_CHANGED")
    assertEqual(calls.n, 0, "nothing read before the delay")
    m.advance(NS.Collectibles.REREAD_DELAY)
    -- red under: one re-read per event, not one per burst
    assertEqual(calls.n, 1, "one re-read")
    assertEqual(learned.me.verdict, "collected")
    assertEqual(count(seen, learned.id .. ":collection"), 1)
    -- red under: every live collectible re-judged, moved or not
    assertEqual(count(seen, other.id .. ":collection"), 0, "the unmoved drop is left alone")
    assertEqual(other.me.verdict, "newCollect")
end)

test("collect feed: combat's end reads again only the drops still at collectUnknown", function()
    local NS, m, LF = party()
    addMount(m, 300, 77, nil)
    addMount(m, 301, 78, false)
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    local seen = updates(NS)
    local unread, fresh = LF.Drops()[1], LF.Drops()[2]
    assertEqual(unread.me.verdict, "collectUnknown")
    m.mounts.collected[77], m.mounts.collected[78] = true, true
    m.__fire("PLAYER_REGEN_ENABLED")
    m.advance(NS.Collectibles.REREAD_DELAY)
    assertEqual(unread.me.verdict, "collected")
    assertEqual(count(seen, unread.id .. ":collection"), 1)
    -- red under: the regen pass widened to every collectible
    assertEqual(fresh.me.verdict, "newCollect", "a drop already answered waits for a collection event")
    assertEqual(count(seen, fresh.id .. ":collection"), 0)
end)

test("collect feed: combat's end with no unknown collectible arms nothing", function()
    local NS, m = party()
    addMount(m, 300, 77, false)
    brakkLoots(m, 300)
    local calls = spyReread(NS)
    m.__fire("PLAYER_REGEN_ENABLED")
    m.advance(NS.Collectibles.REREAD_DELAY * 2)
    assertEqual(calls.n, 0)
end)

test("collect feed: a learned appearance re-judges a live cosmetic through the same re-read", function()
    local NS, m, LF = party()
    assertTrue(NS.SchemaRuntime.Set("feed.categories.cosmetic", true))
    m.addItem(link(300), { name = "Hat", quality = 4, ilvl = 600, equipLoc = "INVTYPE_HEAD", classID = ARMOR,
        subClassID = COSMETIC_SUB, bindType = 1, stats = {}, transmog = false })
    brakkLoots(m, 300)
    local seen, rec = updates(NS), LF.Drops()[1]
    assertEqual(rec.me.verdict, "newCollect")
    m.items[link(300)].transmog = true
    m.__fire("TRANSMOG_COLLECTION_UPDATED")
    m.advance(NS.Collectibles.REREAD_DELAY)
    -- red under: ItemFacts' transmog handler not calling Collectibles.Changed
    assertEqual(rec.me.verdict, "collected")
    assertEqual(count(seen, rec.id .. ":collection"), 1)
end)

test("collect feed: the stand-down cancels a waiting re-read", function()
    local NS, m = party()
    addMount(m, 300, 77, false)
    brakkLoots(m, 300)
    local calls = spyReread(NS)
    m.__fire("NEW_MOUNT_ADDED", 77)
    NS.addon:OnSlashCommand("disable")
    m.advance(NS.Collectibles.REREAD_DELAY * 2)
    -- red under: a stand-down that leaves the timer armed
    assertEqual(calls.n, 0)
end)

test("collect feed: RereadCollections is the cache's one writer and reads the collectibles alone", function()
    local NS, m = party()
    addMount(m, 300, 77, false)
    local f = NS.ItemFacts.Get(link(300))
    local gear = NS.ItemFacts.Get(link(100))
    m.mounts.collected[77] = true
    assertEqual(NS.ItemFacts.RereadCollections(), 1, "the mount; never the worn ring")
    assertTrue(NS.ItemFacts.Get(link(300)) == f, "the same cached table")
    assertTrue(f.collect.known)
    assertNil(gear.collect)
end)

-- ---------------------------------------------------------------------------------------------
-- The refusals at the edges
-- ---------------------------------------------------------------------------------------------

test("collect feed: Asks refuses an ask, an offer and an announce for a collectible", function()
    local NS, m, LF = party()
    addMount(m, 300, 77, false)
    addMount(m, 301, 78, false)
    brakkLoots(m, 300)
    iLoot(m, 301)
    local theirs, mine = LF.Drops()[1], LF.Drops()[2]
    -- red under: Asks.Request without the collectible refusal
    assertEqual(select(2, NS.Asks.Request("ask", "Brakk", theirs.id)), "collectible")
    assertEqual(select(2, NS.Asks.Press("ask", "Brakk", theirs.id)), "collectible", "the button's path too")
    assertEqual(select(2, NS.Asks.Request("offer", "Brakk", mine.id)), "collectible")
    assertEqual(select(2, NS.Asks.Request("announce", nil, mine.id)), "collectible")
    assertEqual(NS.Asks.StateOf("ask", "Brakk", theirs.id), "ready", "nothing filed")
end)

test("collect feed: the Offer panel never opens for your collectible, and /dw offer says why", function()
    local NS, m, LF = party()
    addMount(m, 301, 78, false)
    iLoot(m, 301)
    local rec = LF.Drops()[1]
    NS.ShowWindow()
    assertTrue(NS.Window.Frame() ~= nil, "the window is built, so only the refusal can say no")
    -- red under: OP.Open without the feed-only refusal
    assertNil(NS.OfferPanel.Open(rec.id))
    local printed = {}
    local print0 = NS.Print
    NS.Print = function(text) printed[#printed + 1] = text end
    local ok = NS.SlashVerbs.Offer(link(301))
    NS.Print = print0
    assertFalse(ok)
    assertEqual(printed[#printed], NS.L["Collectibles are watched, not offered."])
end)

test("collect feed: /dw offer refuses a bag collectible the feed never saw, and adds no drop", function()
    local NS, m, LF = party()
    addMount(m, 302, 79, false)
    m.bags[0] = { size = 1, link(302) }
    local printed = {}
    local print0 = NS.Print
    NS.Print = function(text) printed[#printed + 1] = text end
    local ok = NS.SlashVerbs.Offer(link(302))
    NS.Print = print0
    assertFalse(ok)
    assertEqual(printed[#printed], NS.L["Collectibles are watched, not offered."])
    -- red under: the refusal after adopt (the bag mount added to the feed as one of your drops)
    assertEqual(#LF.Drops(), 0, "no drop added")
end)

-- A trade good: no watched kind (category nil), so only the Always watch list lets it in.
local function tradeGood()
    return { name = "Ore", quality = 1, ilvl = 1, equipLoc = "", classID = 7, subClassID = 0, bindType = 0, stats = {} }
end

test("collect feed: an Always watch drop of no kind stays feed-only after the list changes", function()
    local NS, m, LF = party()
    m.addItem(link(303), tradeGood())
    assertTrue(NS.ItemLists.Add("whitelist", 303))
    brakkLoots(m, 303)
    local rec = LF.Drops()[1]
    assertTrue(NS.Collectibles.IsFeedOnly(rec)); assertNil(rec.inspect); assertNil(rec.them)
    assertTrue(NS.ItemLists.Remove("whitelist", 303))
    assertTrue(NS.ItemLists.Add("blacklist", 303))
    LF.OnGearChanged()
    -- red under: judgeMe reading the list from cfg (the gear kernel's `unknown notGear`, Them `?`)
    assertTrue(NS.Collectibles.IsFeedOnly(rec), "still feed-only: list changes apply to new drops")
    assertNil(rec.inspect); assertNil(rec.them)
    assertEqual(NS.Inspect.QueueState().queued, 0, "no looter inspect")
end)

test("collect feed: auto-ask never schedules a collectible", function()
    local NS, m, LF = party()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    addMount(m, 300, 77, false)
    brakkLoots(m, 300)
    local rec = LF.Drops()[1]
    -- red under: Toast.Qualifies without its collectible check
    assertFalse(NS.AutoAsk.Consider(rec.id))
    assertEqual(select(2, NS.Toast.Qualifies(rec, 0)), "collectible")
end)
