-- tests/test_group_roster.lua — group headers name the party (feedback-2 spec §3, FB2-5): the
-- roster snapshot's pure core (modules/GroupRoster.lua: Entry, Merge, Names, TipLines); a feed
-- group taking the members when its first drop makes it and growing when someone joins mid-run,
-- between drops or with the next one; the History group keeping the roster across the log; the
-- headers on Group drops and History naming everyone class-colored, you first, a raid's cut to
-- `+n`, and an older History group with no roster naming none. Test mode's sample rosters are
-- test_test_mode's; a simulated run's, test_sim_e2e's.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BUNIAN, KEGHUNT, TIAMAT = "Player-3209-0000000A", "Player-11-0000000B", "Player-11-0000000C"

local function uncolored(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function names(list)
    local out = {}
    for i, e in ipairs(list or {}) do out[i] = e.realm and (e.name .. "-" .. e.realm) or e.name end
    return table.concat(out, ",")
end

local function gr() return T.newAddon().GroupRoster end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("roster entry: the short name, the realm only when it is not yours, the class, you marked", function()
    local GR = gr()
    local e = GR.Entry({ name = "Bùnian", realm = "Azralon", classFile = "PALADIN" }, "Testrealm")
    assertEqual(e.name, "Bùnian"); assertEqual(e.realm, "Azralon"); assertEqual(e.class, "PALADIN")
    assertNil(e.me)
    local own = GR.Entry({ name = "Tiamât", realm = "testrealm", classFile = "MAGE", isPlayer = true }, "Testrealm")
    assertNil(own.realm, "your realm, in any case, is left out"); assertTrue(own.me)
    assertTrue(GR.Entry({ name = "Seta", isSelf = true }).me, "a test looter's isSelf marks you too")
    assertEqual(GR.Entry({ name = "Keghunt-Thrall" }).name, "Keghunt", "a full name is cut to the short name")
    assertNil(GR.Entry({ name = "" })); assertNil(GR.Entry({ classFile = "MAGE" })); assertNil(GR.Entry(nil))
end)

test("roster merge: the snapshot only grows, you first, the same character never twice", function()
    local GR = gr()
    local list = {}
    assertTrue(GR.Merge(list, { { name = "Keghunt", realm = "Thrall", class = "WARRIOR" },
        { name = "Tiamât", class = "MAGE", me = true } }))
    assertEqual(names(list), "Tiamât,Keghunt-Thrall", "you first, whatever the order")
    assertFalse(GR.Merge(list, { { name = "keghunt", realm = "THRALL", class = "WARRIOR" } }), "matched without case")
    assertFalse(GR.Merge(list, {}), "a member leaving takes no one out")
    assertTrue(GR.Merge(list, { { name = "Bùnian", realm = "Azralon" } }))
    assertEqual(names(list), "Tiamât,Keghunt-Thrall,Bùnian-Azralon", "a newcomer goes last")
    assertTrue(GR.Merge(list, { { name = "Bùnian", realm = "Azralon", class = "PALADIN" } }), "a missing class is filled")
    assertEqual(list[3].class, "PALADIN")
    assertTrue(GR.Merge(list, { { name = "Keghunt" } }), "the same name on your realm is another character")
    assertFalse(GR.Merge(list, { "junk", { realm = "X" } }), "malformed entries are skipped")
end)

test("roster merge and copy: the entries are copied, never shared", function()
    local GR = gr()
    local src = { { name = "Seta", class = "PRIEST" } }
    local list = {}
    GR.Merge(list, src)
    src[1].name = "Changed"
    assertEqual(list[1].name, "Seta")
    local c = GR.Copy(list)
    assertTrue(c ~= list and c[1] ~= list[1]); assertEqual(c[1].name, "Seta")
    assertNil(GR.Copy(nil))
end)

test("roster names: the first few, class-colored, then +n; none for no roster", function()
    local GR = gr()
    local function colorOf(class) if class == "MAGE" then return 0.25, 0.78, 0.92 end end
    local list = {}
    for i = 1, 8 do list[i] = { name = "M" .. i, class = i == 1 and "MAGE" or "ROGUE" } end
    list[1].me = true
    local text = GR.Names(list, 5, colorOf)
    assertEqual(uncolored(text), "M1, M2, M3, M4, M5, +3")
    assertTrue(text:find("|cff40c7ebM1|r", 1, true) ~= nil, text)
    assertTrue(text:find("M2", 1, true) == text:find(", M2", 1, true) + 2, "an unknown color is plain")
    assertEqual(GR.Names({ list[1], list[2] }, 5, colorOf):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), "M1, M2")
    assertEqual(uncolored(GR.Names(list, nil, nil)), "M1, M2, M3, M4, M5, +3", "the default is HEADER_NAMES")
    assertEqual(GR.HEADER_NAMES, 5, "a party of five shows everyone")
    assertNil(GR.Names({})); assertNil(GR.Names(nil))
end)

test("roster tooltip: everyone, with the realm when it is not yours, class-colored", function()
    local GR = gr()
    local lines = GR.TipLines({ { name = "Tiamât", class = "MAGE", me = true },
        { name = "Bùnian", realm = "Azralon", class = "PALADIN" } }, function(c) if c == "MAGE" then return 1, 0, 0 end end)
    assertEqual(lines[1], "In the group (2):")
    assertEqual(lines[2], "|cffff0000Tiamât|r"); assertEqual(lines[3], "Bùnian-Azralon")
    assertEqual(#GR.TipLines(nil), 0)
    assertEqual(GR.Colored("x", nil), "x")
end)

-- ── the feed group's snapshot ───────────────────────────────────────────────────────────────

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
end

local function link(id) return ("|cffa335ee|Hitem:%d::::::::90:::::|h[Ring %d]|h|r"):format(id, id) end

local BUNIAN_ROW = { guid = BUNIAN, name = "Bùnian", realm = "Azralon", class = "PALADIN", classFile = "PALADIN" }
local KEGHUNT_ROW = { guid = KEGHUNT, name = "Keghunt", realm = "Thrall", class = "WARRIOR", classFile = "WARRIOR" }
local TIAMAT_ROW = { guid = TIAMAT, name = "Tiamât", class = "MAGE", classFile = "MAGE" }

-- The owner's group in a Mythic+ dungeon, two rings known.
local function party()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "Den of Nalorakk", difficultyID = 8 }
    end })
    m.addItem(link(501), ring(600)); m.addItem(link(502), ring(600))
    m.setGroup({ BUNIAN_ROW, KEGHUNT_ROW })
    NS.Roster.Refresh("test")
    return NS, m
end

local function onlyGroup(NS)
    local groups = NS.LootFeed.Groups()
    assertEqual(#groups, 1)
    return groups[1]
end

test("feed roster: the group takes everyone in it when its first drop makes it, you first", function()
    local NS = party()
    NS.LootFeed.Add(link(501), "Keghunt-Thrall")
    local g = onlyGroup(NS)
    assertEqual(names(g.roster), "Testchar,Bùnian-Azralon,Keghunt-Thrall")
    assertTrue(g.roster[1].me); assertEqual(g.roster[2].class, "PALADIN")
end)

test("feed roster: someone who joins mid-run is added on the roster event, and to the History group", function()
    local NS, m = party()
    NS.LootFeed.Add(link(501), "Keghunt-Thrall")
    local kept = NS.History.Log().groups
    assertEqual(#kept, 1); assertEqual(names(kept[1].roster), "Testchar,Bùnian-Azralon,Keghunt-Thrall")
    local heard = 0
    NS.addon:RegisterMessage(NS.MSG.HISTORY_CHANGED, function() heard = heard + 1 end)
    m.setGroup({ BUNIAN_ROW, KEGHUNT_ROW, TIAMAT_ROW })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(names(onlyGroup(NS).roster), "Testchar,Bùnian-Azralon,Keghunt-Thrall,Tiamât")
    assertEqual(names(NS.History.Log().groups[1].roster), "Testchar,Bùnian-Azralon,Keghunt-Thrall,Tiamât")
    assertTrue(heard > 0, "the History tab hears it")
    m.setGroup({ KEGHUNT_ROW })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(#onlyGroup(NS).roster, 4, "someone leaving stays named")
end)

test("feed roster: a joiner is also taken by the next drop, with no roster event between", function()
    local NS, m = party()
    NS.LootFeed.Add(link(501), "Keghunt-Thrall")
    m.setGroup({ BUNIAN_ROW, KEGHUNT_ROW, TIAMAT_ROW })
    NS.Roster.Refresh("test")
    NS.LootFeed.Add(link(502), "Bùnian-Azralon")
    assertEqual(#onlyGroup(NS).roster, 4)
    assertEqual(#NS.History.Log().groups[1].roster, 4, "the History group merges it with the drop")
end)

test("feed roster: a roster event with no group open yet changes nothing and raises nothing", function()
    local NS, m = party()
    m.setGroup({ BUNIAN_ROW, KEGHUNT_ROW, TIAMAT_ROW })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(#NS.LootFeed.Groups(), 0)
    assertFalse(NS.GroupRoster.Grow())
end)

-- ── the History log (pure) ──────────────────────────────────────────────────────────────────

test("history roster: Record copies the group's roster in and merges it with each entry", function()
    local NS = T.newAddon()
    local H = NS.History
    local hist = H.Normalize({})
    local roster = { { name = "You", class = "MAGE", me = true }, { name = "Seta", class = "PRIEST" } }
    H.Record(hist, { key = "k", label = "Boss", kind = "encounter", roster = roster }, { at = 1 }, 20)
    local g = hist.groups[1]
    assertEqual(names(g.roster), "You,Seta"); assertTrue(g.roster[1] ~= roster[1], "a copy, never the feed's")
    H.Record(hist, { key = "k", roster = { { name = "Kaelith", class = "PALADIN" } } }, { at = 2 }, 20)
    assertEqual(names(g.roster), "You,Seta,Kaelith")
    H.Record(hist, { key = "old" }, { at = 3 }, 20)
    assertNil(hist.groups[2].roster, "no roster given, none kept")
end)

-- ── the headers ─────────────────────────────────────────────────────────────────────────────

local function raid(n)
    local list = { { name = "You", class = "MAGE", me = true } }
    for i = 2, n do list[i] = { name = "R" .. i, class = "ROGUE" } end
    return list
end

test("group header: the party's names after the count, class-colored; the tooltip lists everyone", function()
    local NS = T.newAddon()
    local hd = NS.WindowCells.Header({ label = "Den of Nalorakk", kind = "run", roster = raid(5) }, 2, nil,
        "Mythic+", false)
    assertEqual(uncolored(hd.text), "Den of Nalorakk · Mythic+ · 2 drops · You, R2, R3, R4, R5")
    assertTrue(hd.text:find("|cff40c7ebYou|r", 1, true) ~= nil, "you in your class color")
    local tip = table.concat(hd.tip, "\n")
    assertTrue(tip:find("In the group (5):", 1, true) ~= nil, tip)
    assertTrue(tip:find("Click to collapse this group.", 1, true) ~= nil, "the click hint stays last")
end)

test("group header: a raid's header names the first five and +n; its tooltip names all", function()
    local NS = T.newAddon()
    local hd = NS.WindowCells.Header({ label = "The Spire", kind = "encounter", roster = raid(20) }, 3, nil, nil, false)
    assertEqual(uncolored(hd.text), "The Spire · 3 drops · You, R2, R3, R4, R5, +15")
    local tip = uncolored(table.concat(hd.tip, "\n"))
    assertTrue(tip:find("In the group (20):", 1, true) ~= nil); assertTrue(tip:find("\nR20\n", 1, true) ~= nil, tip)
end)

test("history header: a kept roster is named; an older group with none names nobody", function()
    local NS = T.newAddon()
    local WH = NS.WindowHistory
    local hd = WH.Header({ label = "Boss", kind = "encounter", roster = raid(3) }, 1, nil, nil, false)
    assertEqual(uncolored(hd.text), "Boss · 1 drop · You, R2, R3")
    assertTrue(table.concat(hd.tip, "\n"):find("In the group (3):", 1, true) ~= nil)
    local old = WH.Header({ label = "Boss", kind = "encounter" }, 1, nil, nil, false)
    assertEqual(old.text, "Boss · 1 drop")
    assertFalse(table.concat(old.tip, "\n"):find("In the group", 1, true) ~= nil)
end)
