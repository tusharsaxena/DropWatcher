-- tests/test_feed_restore.lua — the session is the login, and the Drops tab survives a reload
-- (feedback-15 spec §0, DW-Q0): the per-character session start (modules/Session.lua) set by an
-- initial login, kept by a reload, moved by nothing else; the feed rebuilt from this session's
-- History entries after a reload (modules/FeedRestore.lua, LootFeed.Restore, History.Adopt); the
-- false Expired a live timer read undoes; and This instance kept across a reload.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK = "Player-1-0000000A"
local ME_KEY = "Testchar-Testrealm"
local T0 = 1800000000

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, extra)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- An enabled instance in a Heroic dungeon (instance map 1234), in a party with Brakk, wearing two
-- 600 rings; the epoch clock is m.__epoch (time()) and the kit's AceDB fake, which has no `char`
-- section, gets one: `char` (a table another instance kept, for a reload) or a fresh one.
local function world(char, epoch)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2, instanceID = 1234 }
    end })
    m.__epoch = epoch or T0
    m.time = function() return m.__epoch end
    NS.addon.db.char = char or {}
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ { guid = BRAKK, name = "Brakk", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    for id = 300, 310 do m.addItem(link(id), ring(620)) end
    return NS, m
end

local function login(m) m.__fire("PLAYER_ENTERING_WORLD", true, false) end
local function reload(m) m.__fire("PLAYER_ENTERING_WORLD", false, true) end

local function chat(m, text) m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil) end
local function brakkLoots(m, id) chat(m, "Brakk receives loot: " .. link(id) .. ".") end
local function youLoot(m, id) chat(m, "You receive loot: " .. link(id) .. ".") end

-- A second load of the same account and character after `secs` seconds: the History log and the
-- `char` section carried over, as SavedVariables would.
local function nextLoad(NS, secs)
    local NS2, m2 = world(NS.addon.db.char, T0 + secs)
    NS2.addon.db.global.history = NS.addon.db.global.history
    return NS2, m2
end

local function entry(over)
    local e = { itemLink = link(300), itemID = 300, looter = "Brakk-Testrealm", class = "WARRIOR",
        outcome = "seen", at = T0, seenBy = ME_KEY, seenByClass = "MAGE" }
    for k, v in pairs(over or {}) do e[k] = v end
    return e
end

local function group(key, drops, over)
    local g = { key = key, label = "Boss A", kind = "encounter", situation = "dungeon", at = T0,
        instance = "The Rookery", difficulty = "Heroic", seenBy = ME_KEY, seenByClass = "MAGE",
        roster = { { name = "Testchar", class = "MAGE", me = true }, { name = "Brakk", class = "WARRIOR" } },
        drops = drops }
    for k, v in pairs(over or {}) do g[k] = v end
    return g
end

-- A load with this history stored and the session started at T0, `secs` seconds later.
local function seeded(groups, secs)
    local NS, m = world({ session = { start = T0 } }, T0 + (secs or 60))
    NS.History.Store().groups = groups
    return NS, m
end

local function links(LF)
    local out = {}
    for _, rec in ipairs(LF.Drops()) do out[#out + 1] = rec.itemID end
    return table.concat(out, ",")
end

-- ── the session is the login ────────────────────────────────────────────────────────────────

test("session: an initial login starts it now; a zone change moves nothing; a reload keeps it", function()
    local NS, m = world()
    login(m)
    assertEqual(NS.History.SessionStart(), T0)
    assertEqual(NS.addon.db.char.session.start, T0, "stored per character")
    m.__epoch = T0 + 500
    m.__fire("PLAYER_ENTERING_WORLD", false, false)
    assertEqual(NS.History.SessionStart(), T0, "a zone change")
    -- red under: a lazy session start (the first recording's time()), so a reload starts anew
    local NS2, m2 = world(NS.addon.db.char, T0 + 900)
    assertEqual(NS2.History.SessionStart(), T0, "before the event, the stored value")
    reload(m2)
    assertEqual(NS2.History.SessionStart(), T0, "a reload keeps it")
    local NS3, m3 = world(NS.addon.db.char, T0 + 2000)
    login(m3)
    assertEqual(NS3.History.SessionStart(), T0 + 2000, "a new login starts a new session")
end)

test("session: with no stored value (a first run, a corrupt row) it is now, and it holds", function()
    local NS, m = world({ session = { start = "broken" } })
    assertEqual(NS.History.SessionStart(), T0)
    m.__epoch = T0 + 10
    assertEqual(NS.History.SessionStart(), T0, "never nil, and never moving on its own")
    reload(m)
    assertEqual(NS.History.SessionStart(), T0)
end)

-- ── the feed rebuilt after a reload ─────────────────────────────────────────────────────────

test("restore: after a reload this session's drops come back under their headers, linked to their entries", function()
    local NS, m = world()
    login(m)
    brakkLoots(m, 300)
    youLoot(m, 301)
    local before = NS.LootFeed.Drops()
    assertEqual(#before, 2)
    local hist = NS.History.Store()
    assertEqual(#hist.groups[1].drops, 2)
    local NS2, m2 = nextLoad(NS, 600)
    -- red under: no FeedRestore (an empty Drops tab after the reload)
    reload(m2)
    local LF = NS2.LootFeed
    assertEqual(links(LF), "300,301", "oldest first")
    local a, b = LF.Drops()[1], LF.Drops()[2]
    assertEqual(T.tipPlain(NS2.WindowCells.Looter(a).tip[3]), "• Reported by: the History, after a reload")
    assertEqual(a.source, "restore"); assertEqual(a.groupKey, before[1].groupKey, "the feed key, its suffix gone")
    assertEqual(LF.Groups()[1].label, NS.LootFeed.Groups()[1].label)
    assertEqual(#LF.Groups(), 1)
    assertEqual(a.looter.name, "Brakk-Testrealm"); assertEqual(a.looter.guid, BRAKK, "read from the roster")
    assertFalse(a.isMine); assertTrue(b.isMine)
    assertEqual(a.at, m2.GetTime() - 600, "its epoch turned into the client clock")
    assertEqual(a.situation, "dungeon")
    assertEqual(a.me.verdict, "upgrade", "judged anew")
    assertTrue(NS2.History.EntryOf(a.id) == hist.groups[1].drops[1], "linked to its entry")
    assertEqual(#hist.groups, 1); assertEqual(#hist.groups[1].drops, 2, "nothing recorded twice")
    a.trade = { state = "no", reasonKey = "expired", basis = "rule", args = { 0, 7200 } }
    NS2.addon:SendMessage(NS2.MSG.DROP_UPDATED, a.id, "trade")
    assertEqual(hist.groups[1].drops[1].outcome, "expired", "DropUpdated refreshes that entry")
end)

test("restore: an initial login starts an empty feed", function()
    local NS, m = seeded({ group("enc:2900:5@" .. T0, { entry() }) })
    login(m)
    assertEqual(#NS.LootFeed.Drops(), 0)
end)

test("restore: this session's and this character's entries only, gone ones skipped, the newest MAX_DROPS", function()
    local NS, m = seeded({
        group("enc:1:5@" .. (T0 - 86400), { entry({ itemID = 309, itemLink = link(309) }) }),
        group("enc:2:5@" .. T0, {
            entry({ itemID = 301, itemLink = link(301), at = T0 + 1 }),
            entry({ itemID = 302, itemLink = link(302), seenBy = "Other-Testrealm" }),
            entry({ itemID = 303, itemLink = link(303), gone = true }),
            entry({ itemID = 304, itemLink = link(304), at = T0 + 4 }),
        }),
        group("area:The Rookery:7@" .. T0, { entry({ itemID = 305, itemLink = link(305), at = T0 + 5 }) },
            { kind = "area", label = "The Rookery" }),
    })
    NS.LootFeed.MAX_DROPS = 2
    reload(m)
    assertEqual(links(NS.LootFeed), "304,305")
    local g = NS.LootFeed.Groups()
    assertEqual(g[#g].key, "area:The Rookery:7", "an area group keeps its key")
    assertEqual(g[#g].kind, "area"); assertEqual(g[1].instance, "The Rookery")
    assertEqual(g[1].difficulty, "Heroic"); assertEqual(#g[1].roster, 2, "the History group's roster")
end)

test("restore: restored drops never merge; a live line for the same drop merges into one", function()
    local NS, m = seeded({ group("enc:2:5@" .. T0, { entry(), entry() }) }, 30)
    reload(m)
    assertEqual(links(NS.LootFeed), "300,300")
    brakkLoots(m, 300)
    local drops = NS.LootFeed.Drops()
    assertEqual(#drops, 2, "the chat line merged")
    assertTrue((drops[1].sources.chat or 0) + (drops[2].sources.chat or 0) == 1)
    assertEqual(#NS.History.Store().groups[1].drops, 2)
end)

test("restore: the quality gate still runs; the situation gate and the feed filters do not", function()
    local NS, m = seeded({ group("enc:2:5@" .. T0, {
        entry({ itemID = 306, itemLink = link(306) }),
        entry({ itemID = 307, itemLink = link(307) }),
    }) })
    m.addItem(link(306), ring(590, { quality = 2 }))
    m.addItem(link(307), ring(620, { classID = 15, subClassID = 0, equipLoc = "" }))
    m.__context.inInstance, m.__context.instanceType = false, "none"
    NS.Situations.Refresh("test")
    reload(m)
    assertEqual(links(NS.LootFeed), "307", "Uncommon is under Rare; gear only and the solo row are not asked")
end)

test("restore: a restored drop opens no window, queues no toast and asks nothing", function()
    local NS, m = seeded({ group("enc:2:5@" .. T0, { entry() }) })
    NS.Toast.Qualifies = function() return true end
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    m.advance(100)   -- the restored drop dates after auto-ask was turned on, as a stored setting is
    reload(m)
    assertEqual(#NS.LootFeed.Drops(), 1)
    -- red under: the restored drop's DropAdded taken as a new drop by the window, the toast and auto-ask
    assertTrue(NS.State.windowOpen ~= true, "no auto-open")
    local toast = NS.Toast.Stats()
    assertFalse(toast.shown, "no toast"); assertEqual(toast.waiting, 0)
    assertEqual(NS.AutoAsk.Stats().scheduled, 0, "no automatic ask")
    brakkLoots(m, 308)
    assertTrue(NS.State.windowOpen == true, "a live drop still opens it")
    assertTrue(NS.Toast.Stats().shown, "and is toasted")
    assertEqual(NS.AutoAsk.Stats().scheduled, 1, "and asked for")
end)

test("restore: an area group made after the reload never takes a key from before it", function()
    -- Before the reload, drops hidden by the filters used ids 1-2 and a trash drop made
    -- `area:The Rookery:3`; after it the restored drops take ids 1-2 and the next live one id 3.
    local NS, m = seeded({
        group("area:The Rookery:3@" .. T0, { entry({ itemID = 301, itemLink = link(301), at = T0 + 1 }) },
            { kind = "area", label = "The Rookery" }),
        group("enc:2:5@" .. T0, { entry({ itemID = 302, itemLink = link(302), at = T0 + 2 }) }),
    })
    reload(m)
    assertEqual(links(NS.LootFeed), "301,302")
    brakkLoots(m, 303)
    local g = NS.LootFeed.Groups()
    -- red under: the area key suffixed by the drop's id alone (s.seq restarts at 1 every load)
    assertEqual(#g, 3, "a new area group")
    assertTrue(g[3].key ~= g[1].key, "its own key")
    assertEqual(#g[1].drops, 1, "the restored group untouched")
    local hist = NS.History.Store().groups
    assertEqual(#hist, 3, "a History group of its own")
    assertEqual(#hist[1].drops, 1, "nothing filed into the group from before the reload")
end)

test("restore: restored drops are not counted new on a window minimized before the reload", function()
    local NS, m = seeded({ group("enc:2:5@" .. T0, { entry(), entry({ itemID = 301, itemLink = link(301) }) }) })
    NS.addon.db.profile.window.minimized = true
    assertTrue(NS.Window.IsMinimized())
    reload(m)
    assertEqual(#NS.LootFeed.Drops(), 2)
    -- red under: onDropAdded counting every drop added while minimized, a restored one too
    assertEqual(NS.Window.NewCount(), 0, "seen before the reload")
    brakkLoots(m, 308)
    assertEqual(NS.Window.NewCount(), 1, "a live drop still counts")
end)

test("restore: a drop asked for before the reload reads Asked, not Ask, after it", function()
    local NS, m = seeded({ group("enc:2:5@" .. T0, {
        entry({ itemID = 301, itemLink = link(301), at = T0 + 1, outcome = "asked" }),
        entry({ itemID = 302, itemLink = link(302), at = T0 + 2, outcome = "expired", beforeExpired = "asked" }),
        entry({ itemID = 303, itemLink = link(303), at = T0 + 3, outcome = "declined", before = "asked" }),
        entry({ itemID = 304, itemLink = link(304), at = T0 + 4 }),
    }) })
    reload(m)
    local drops, WG = NS.LootFeed.Drops(), NS.WindowGroup
    assertEqual(#drops, 4)
    -- red under: the Asks book is this load's alone, so a restored asked drop read `ready` (Ask)
    assertEqual((WG.AskState(drops[1])), "sent", "asked")
    assertFalse(WG.Action(drops[1]).enabled, "so it cannot be sent twice")
    assertEqual((WG.AskState(drops[2])), "sent", "asked, then expired")
    assertEqual((WG.AskState(drops[3])), "sent", "asked, then declined")
    assertEqual((WG.AskState(drops[4])), "ready", "never asked")
end)

test("restore: drops cleared from the Drops tab before the reload stay cleared", function()
    local NS, m = world()
    login(m)
    brakkLoots(m, 300)
    m.__epoch = T0 + 10
    NS.LootFeed.Clear("live")   -- `/dw clear`, and Clear this session's drops on boss kill
    brakkLoots(m, 301)
    assertEqual(links(NS.LootFeed), "301")
    local NS2, m2 = nextLoad(NS, 600)
    reload(m2)
    -- red under: FeedRestore.Pick skipping only `gone` entries (300 back after the reload)
    assertEqual(links(NS2.LootFeed), "301", "only the drops after the clear")
    local NS3, m3 = nextLoad(NS2, 900)
    login(m3)
    brakkLoots(m3, 302)
    local NS4, m4 = nextLoad(NS3, 950)
    reload(m4)
    assertEqual(links(NS4.LootFeed), "302", "a new login's session is not held by the old clear")
end)

-- ── the false Expired undone ────────────────────────────────────────────────────────────────

test("history: a live timer read undoes Expired; a rule estimate, declined and received do not", function()
    local H = T.newAddon().History
    local function rec(trade) return { link = link(300), trade = trade } end
    local timerYes = { state = "yes", reasonKey = "timer", basis = "timer", args = { 3000 } }
    local ruleYes = { state = "yes", reasonKey = "x", basis = "rule" }
    local e = entry({ outcome = "asked" })
    assertTrue(H.Advance(e, "expired"))
    assertEqual(e.beforeExpired, "asked", "Advance keeps what it replaced")
    H.Refresh(e, rec(ruleYes))
    assertEqual(e.outcome, "expired", "a rule estimate never undoes it")
    -- red under: an automatic outcome that only moves forward
    local moved, changed = H.Refresh(e, rec(timerYes))
    assertEqual(e.outcome, "asked"); assertNil(e.beforeExpired)
    assertTrue(moved); assertTrue(changed)
    local old = entry({ outcome = "expired" })
    H.Refresh(old, rec(timerYes))
    assertEqual(old.outcome, "seen", "expired before the field existed")
    local d = entry({ outcome = "declined", before = "expired" })
    H.Refresh(d, rec(timerYes))
    assertEqual(d.outcome, "declined")
    local got = entry({ outcome = "received" })
    H.Refresh(got, rec(timerYes))
    assertEqual(got.outcome, "received")
end)

-- ── This instance across a reload ───────────────────────────────────────────────────────────

test("session: This instance survives a reload in the same instance, and only then", function()
    local NS, m = world()
    m.advance(100)
    login(m)
    assertEqual(NS.Window.TabContext("group").ctx.instanceSince, 100)
    local mark = NS.addon.db.char.session.instance
    assertEqual(mark.at, T0); assertEqual(mark.situation, "dungeon"); assertEqual(mark.instance, 1234)
    -- red under: instanceSince reset by the reload's first situation announcement
    local NS2, m2 = world(NS.addon.db.char, T0 + 300)
    m2.advance(1000)
    reload(m2)
    assertEqual(NS2.Window.TabContext("group").ctx.instanceSince, 700, "restored from the stored epoch")
    local NS3, m3 = world(NS.addon.db.char, T0 + 400)
    m3.instance.instanceID = 999
    m3.advance(1000)
    reload(m3)
    assertEqual(NS3.Window.TabContext("group").ctx.instanceSince, 1000, "another instance starts now")
    local NS4, m4 = world({ session = { start = T0, instance = { at = T0, situation = "dungeon", instance = 1234 } } },
        T0 + 400)
    m4.advance(1000)
    login(m4)
    assertEqual(NS4.Window.TabContext("group").ctx.instanceSince, 1000, "a login starts now")
end)
