-- tests/test_sim_pool.lua — the simulator's item pool and its group (simulator spec §2, §3): the
-- Encounter Journal shims (core/Compat.lua), the pool read from the journal with the player's
-- selection saved and restored, never while its frame is shown, the wait for
-- EJ_LOOT_DATA_RECIEVED and its timeout, the class filter and the own-items fallback reported once
-- (modules/SimPool.lua); and the invented roster and its gear drawn from the pool inside a band
-- around your item level (modules/SimRoster.lua).

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function link(id, ilvl)
    return ("|cnIQ4:|Hitem:%d::::::::90:::::%d|h[Item %d]|h|r"):format(id, ilvl or 0, id)
end

local function ring(ilvl)
    return { name = "Ring", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function armor(ilvl, equipLoc, subClassID)
    return { name = "Armor", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = 4,
        subClassID = subClassID, bindType = 1, stats = {} }
end

-- Item levels per difficulty in the journal the cases seed (the client's link carries the level).
local LEVEL = { [1] = 580, [2] = 590, [23] = 600, [8] = 610, [17] = 590, [14] = 600, [15] = 610, [16] = 620 }

-- One journal entry for `id` at `difficulty`, its item seeded in the item cache.
local function entry(m, id, difficulty, def, extra)
    local l = link(id, LEVEL[difficulty])
    def.ilvl = LEVEL[difficulty]
    m.addItem(l, def)
    local e = { itemID = id, link = l, encounterID = 2000 + id % 10 }
    for k, v in pairs(extra or {}) do e[k] = v end
    return e
end

-- Two dungeons (101, 102) and a raid (201) in the newest of two tiers; each dungeon drops a ring
-- and a cloth helm at every dungeon difficulty, the raid a plate chest at every raid difficulty.
local function seedJournal(m, extra)
    local j = m.journal
    j.tiers = { { dungeons = { { id = 1, name = "Old Keep" } }, raids = {} },
        { dungeons = { { id = 101, name = "Ashen Vault" }, { id = 102, name = "Tidewell" } },
          raids = { { id = 201, name = "The Spire" } } } }
    for _, inst in ipairs({ 101, 102 }) do
        j.loot[inst] = {}
        for _, d in ipairs({ 1, 2, 23, 8 }) do
            j.loot[inst][d] = {
                entry(m, inst * 1000 + d * 10 + 1, d, ring(0), extra),
                entry(m, inst * 1000 + d * 10 + 2, d, armor(0, "INVTYPE_HEAD", 1), extra),
            }
        end
    end
    j.loot[201] = {}
    for _, d in ipairs({ 17, 14, 15, 16 }) do
        j.loot[201][d] = { entry(m, 201000 + d * 10 + 1, d, armor(0, "INVTYPE_CHEST", 4), extra) }
    end
    j.loot[1] = { [23] = { entry(m, 1231, 23, ring(0), extra) } }
end

-- An enabled instance, solo; the player (a mage) wears two 600 rings.
local function solo()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, 600), ring(600))
    m.addItem(link(101, 600), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100, 600), link(101, 600)
    return NS, m
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function count(list, pred)
    local n = 0
    for _, v in ipairs(list) do
        if pred(v) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- The journal shims
-- ---------------------------------------------------------------------------------------------

test("compat journal: the selection is read whole, the frame's part only once it loads", function()
    local NS, _, m = T.newAddon()
    local j = m.journal
    j.tier, j.difficulty, j.classID, j.specID, j.slot = 1, 23, 8, 62, 4
    local sel = NS.Compat.JournalSelection()
    assertEqual(sel.tiers, 1); assertEqual(sel.tier, 1); assertEqual(sel.difficulty, 23)
    assertEqual(sel.classID, 8); assertEqual(sel.specID, 62); assertEqual(sel.slot, 4)
    assertFalse(sel.shown); assertNil(sel.instanceID)
    m.EncounterJournal = { instanceID = 77, encounterID = 5, IsShown = function() return true end }
    sel = NS.Compat.JournalSelection()
    assertTrue(sel.shown); assertEqual(sel.instanceID, 77); assertEqual(sel.encounterID, 5)
    m.EJ_GetLootFilter = nil
    assertNil(NS.Compat.JournalSelection(), "no EJ_* API: nil")
end)

test("compat journal: Select applies the selection in the journal's order and resets the filters", function()
    local NS, _, m = T.newAddon()
    local j = m.journal
    assertTrue(NS.Compat.JournalSelect({ tier = 1, instanceID = 9, encounterID = 3, difficulty = 2,
        classID = 8, specID = 62, slot = 4 }))
    assertEqual(j.tier, 1); assertEqual(j.instanceID, 9); assertEqual(j.encounterID, 3)
    assertEqual(j.difficulty, 2); assertEqual(j.classID, 8); assertEqual(j.specID, 62); assertEqual(j.slot, 4)
    NS.Compat.JournalSelect({})
    assertEqual(j.classID, 0, "no class: every class"); assertEqual(j.slot, 15, "no slot: every slot")
    m.EJ_SetLootFilter = nil
    assertFalse(NS.Compat.JournalSelect({ tier = 1 }), "no API: false")
end)

test("compat journal: Instances lists the tier's dungeons or raids; Loot answers the loaded and the pending", function()
    local NS, _, m = T.newAddon()
    seedJournal(m)
    NS.Compat.JournalSelect({ tier = 2 })
    assertEqual(#NS.Compat.JournalInstances(false), 2)
    assertEqual(NS.Compat.JournalInstances(true)[1].name, "The Spire")
    m.journal.loot[101][23][2].loadsNeeded = 1
    NS.Compat.JournalSelect({ instanceID = 101, difficulty = 23 })
    local loot, pending = NS.Compat.JournalLoot()
    assertEqual(#loot, 1); assertEqual(pending, 1)
    assertEqual(loot[1].itemID, 101231); assertEqual(loot[1].link, link(101231, 600))
    m.EJ_GetNumLoot, m.EJ_GetInstanceByIndex = nil, nil
    local none, p = NS.Compat.JournalLoot()
    assertEqual(#none, 0); assertEqual(p, 0)
    assertEqual(#NS.Compat.JournalInstances(false), 0)
end)

-- ---------------------------------------------------------------------------------------------
-- The pool's pure parts
-- ---------------------------------------------------------------------------------------------

test("sim pool: each situation reads its side and difficulty; the class filter is yours or none", function()
    local NS = T.newAddon()
    local P, D = NS.SimPool, NS.Constants.DIFFICULTY
    assertEqual(P.Source("mythicPlus").difficulty, D.MYTHIC_KEYSTONE)
    assertFalse(P.Source("dungeon").raid)
    assertTrue(P.Source("raidLFR").raid); assertEqual(P.Source("raidLFR").difficulty, D.LFR)
    assertEqual(P.Source("nonsense"), P.Source("dungeon"), "anything else reads the dungeons")
    local mine = P.Filter("mine", "MAGE", 62)
    assertEqual(mine.classID, 8); assertEqual(mine.specID, 62)
    assertEqual(P.Filter("any", "MAGE", 62).classID, 0)
    assertEqual(P.Filter("mine", nil, nil).classID, 0, "an unknown class reads every class")
    local pool = { difficulty = 8, entries = { { difficulty = 8 }, { difficulty = 23 } } }
    assertEqual(#P.Drops(pool), 1)
    assertEqual(#P.Drops({ entries = { {}, {} } }), 2, "a fallback pool drops anything")
    assertEqual(#P.Drops(nil), 0)
end)

-- ---------------------------------------------------------------------------------------------
-- Reading the journal
-- ---------------------------------------------------------------------------------------------

test("sim pool: a read takes every instance of the newest tier at every difficulty and restores the selection", function()
    local NS, m = solo()
    seedJournal(m)
    local j = m.journal
    j.tier, j.difficulty, j.classID, j.specID, j.slot = 1, 2, 5, 256, 3
    m.EncounterJournal = { instanceID = 1, encounterID = 44, IsShown = function() return false end }
    local entries, pending = NS.SimPool.ReadJournal(NS.SimPool.Source("mythicPlus"), { classID = 0, specID = 0 })
    assertEqual(#entries, 16, "two dungeons, two items, four difficulties")
    assertEqual(pending, 0)
    assertEqual(count(entries, function(e) return e.instance == "Old Keep" end), 0, "the newest tier only")
    -- red under: a ReadJournal that leaves the journal on the last instance it read
    assertEqual(j.tier, 1); assertEqual(j.instanceID, 1); assertEqual(j.encounterID, 44)
    assertEqual(j.difficulty, 2); assertEqual(j.classID, 5); assertEqual(j.specID, 256); assertEqual(j.slot, 3)
end)

test("sim pool: the selection is restored even when a read raises", function()
    local NS, m = solo()
    seedJournal(m)
    local j = m.journal
    j.tier, j.difficulty = 1, 2
    m.C_EncounterJournal.GetLootInfoByIndex = function() error("journal broke") end
    local entries, _, why = NS.SimPool.ReadJournal(NS.SimPool.Source("raid"), { classID = 0, specID = 0 })
    assertNil(entries); assertEqual(why, "error")
    assertEqual(j.tier, 1); assertEqual(j.difficulty, 2)
end)

test("sim pool: the journal is not read while its frame is shown", function()
    local NS, m = solo()
    seedJournal(m)
    local shown = true
    m.EncounterJournal = { IsShown = function() return shown end }
    NS.Sim.Start({ scenario = "test" })
    local got
    NS.SimPool.Build({ situation = "dungeon" }, function(pool) got = pool end)
    -- red under: a build that reads with the frame open
    assertEqual(m.journal.selects, 0)
    assertTrue(NS.SimPool.Status().building)
    assertEqual(NS.SimPool.Status().waiting, "shown")
    shown = false
    m.advance(NS.SimPool.RETRY)
    assertTrue(got ~= nil, "read once the frame is closed")
    assertEqual(got.source, "journal")
    assertEqual(#NS.SimPool.Drops(got), 4, "Mythic: two dungeons, two items each")
    NS.Sim.Stop()
end)

test("sim pool: a frame shown the whole time ends in the fallback at the timeout", function()
    local NS, m = solo()
    seedJournal(m)
    m.EncounterJournal = { IsShown = function() return true end }
    NS.Sim.Start({ scenario = "test" })
    local got
    NS.SimPool.Build({ situation = "dungeon" }, function(pool) got = pool end)
    m.advance(NS.SimPool.TIMEOUT)
    assertEqual(m.journal.selects, 0)
    assertEqual(got.source, "fallback")
    NS.Sim.Stop()
end)

test("sim pool: entries still loading are awaited through EJ_LOOT_DATA_RECIEVED", function()
    local NS, m = solo()
    seedJournal(m, { loadsNeeded = 1 })
    NS.Sim.Start({ scenario = "test" })
    local calls, got = 0, nil
    NS.SimPool.Build({ situation = "mythicPlus" }, function(pool) calls, got = calls + 1, pool end)
    assertEqual(calls, 0, "nothing loaded yet: it waits")
    assertEqual(NS.SimPool.Status().waiting, "loot")
    m.loadJournal()
    assertEqual(calls, 0, "the burst settles first")
    m.advance(NS.SimPool.SETTLE)
    assertEqual(calls, 1)
    assertEqual(got.source, "journal"); assertEqual(got.pending, 0); assertEqual(#got.entries, 16)
    assertEqual(NS.SimPool.Get(), got)
    m.advance(NS.SimPool.TIMEOUT)
    assertEqual(calls, 1, "the timeout does not finish it twice")
    NS.Sim.Stop()
end)

test("sim pool: at the timeout the build keeps what has loaded", function()
    local NS, m = solo()
    seedJournal(m)
    m.journal.loot[101][8][1].loadsNeeded = 1
    NS.Sim.Start({ scenario = "test" })
    local got
    NS.SimPool.Build({ situation = "mythicPlus", timeout = 3 }, function(pool) got = pool end)
    assertNil(got)
    m.advance(3)
    assertEqual(got.source, "journal")
    assertEqual(got.pending, 1)
    assertEqual(#got.entries, 15)
    assertEqual(#NS.SimPool.Drops(got), 3)
    NS.Sim.Stop()
end)

test("sim pool: loot for me sets the journal's class filter to yours; any lists every class", function()
    local NS, m = solo()
    seedJournal(m)
    -- The helms are for warriors only (class 1); the rings for anyone.
    for _, inst in ipairs({ 101, 102 }) do
        for _, list in pairs(m.journal.loot[inst]) do list[2].classes = { [1] = true } end
    end
    NS.Sim.Start({ scenario = "test" })
    NS.SimPool.Build({ situation = "dungeon", classFilter = "mine" })
    assertEqual(#NS.SimPool.Get().entries, 8, "a mage sees the rings only")
    NS.SimPool.Build({ situation = "dungeon", classFilter = "any" })
    assertEqual(#NS.SimPool.Get().entries, 16)
    assertEqual(m.journal.classID, 0, "the player's own filter is put back")
    NS.Sim.Stop()
end)

test("sim pool: an empty journal falls back to your own gear, reported once", function()
    local NS, m = solo()
    m.bags[0] = { size = 2, [1] = link(102, 590) }
    m.addItem(link(102, 590), armor(590, "INVTYPE_HEAD", 1))
    m.bags[0][2] = "|cffffffff|Hitem:6948::::::::|h[Hearthstone]|h|r"
    m.addItem(m.bags[0][2], { name = "Hearthstone", quality = 1, ilvl = 1, equipLoc = "", classID = 15 })
    NS.Sim.Start({ scenario = "test" })
    NS.SimPool.Build({ situation = "raid" })
    local pool = NS.SimPool.Get()
    assertEqual(pool.source, "fallback")
    assertEqual(#pool.entries, 3, "two rings and the helm; the hearthstone is not gear")
    assertEqual(#NS.SimPool.Drops(pool), 3)
    local line = "The Encounter Journal gave no items"
    assertEqual(printed(m, line), 1)
    NS.Sim.Stop()
    NS.Sim.Start({ scenario = "test" })
    NS.SimPool.Build({ situation = "raid" })
    -- red under: a fallback that prints on every build
    assertEqual(printed(m, line), 1, "reported once")
    assertEqual(NS.SimPool.Status().source, "fallback")
    NS.Sim.Stop()
end)

test("sim pool: without the journal API the fallback answers at once", function()
    local NS, m = solo()
    m.EJ_GetNumTiers = nil
    NS.Sim.Start({ scenario = "test" })
    local got
    NS.SimPool.Build({ situation = "dungeon" }, function(pool) got = pool end)
    assertEqual(got.source, "fallback")
    NS.Sim.Stop()
end)

test("sim pool: the stop ends a waiting build, and a late event does nothing", function()
    local NS, m = solo()
    seedJournal(m, { loadsNeeded = 1 })
    NS.Sim.Start({ scenario = "test" })
    local calls = 0
    NS.SimPool.Build({ situation = "dungeon" }, function() calls = calls + 1 end)
    NS.Sim.Stop()
    m.loadJournal()
    m.advance(NS.SimPool.TIMEOUT)
    assertEqual(calls, 0)
    assertNil(NS.SimPool.Get())
    assertFalse(NS.SimPool.Status().building)
    assertFalse(NS.SimPool.Build({}), "no simulation: no build")
end)

-- ---------------------------------------------------------------------------------------------
-- The roster and its gear
-- ---------------------------------------------------------------------------------------------

test("sim roster: the random source replays a seed and stays in range", function()
    local NS = T.newAddon()
    local a, b = NS.SimRoster.Random(42), NS.SimRoster.Random(42)
    for _ = 1, 50 do
        local x = a(3, 7)
        assertEqual(x, b(3, 7))
        assertTrue(x >= 3 and x <= 7)
    end
    local r = NS.SimRoster.Random(0)
    for _ = 1, 50 do
        local u = r()
        assertTrue(u >= 0 and u < 1)
        local n = r(4)
        assertTrue(n >= 1 and n <= 4)
    end
end)

test("sim roster: a party has four members, a raid nine to nineteen, each distinct and whole", function()
    local NS = T.newAddon()
    local R, CD = NS.SimRoster, NS.ClassData
    local party = R.Members({ kind = "party", ownRealm = "Testrealm" }, R.Random(7))
    assertEqual(#party, 4)
    assertEqual(party[1].unit, "party1"); assertEqual(party[4].unit, "party4")
    for seed = 1, 20 do
        local raid = R.Members({ kind = "raid", ownRealm = "Testrealm" }, R.Random(seed))
        assertTrue(#raid >= 9 and #raid <= 19, "raid size " .. #raid)
        assertEqual(raid[1].unit, "raid2", "you are raid1")
        local names, guids = {}, {}
        for _, mem in ipairs(raid) do
            assertTrue(mem.sim)
            assertNil(names[mem.name], "distinct names"); names[mem.name] = true
            assertNil(guids[mem.guid], "distinct GUIDs"); guids[mem.guid] = true
            assertTrue(mem.guid:find("^Player%-%d+%-%x+$") ~= nil, "a client-shaped GUID")
            assertEqual(CD.ClassOf(mem.specID), mem.classFile, "the spec is the class's")
            assertEqual(mem.classID, CD.CLASS_ID[mem.classFile])
            assertEqual(mem.fullName, mem.name .. "-" .. mem.realm)
        end
    end
    assertEqual(#R.Members({ kind = "raid", size = 40 }, R.Random(1)), 19, "clamped")
    assertEqual(#R.Members({ kind = "raid", size = 2 }, R.Random(1)), 9, "clamped")
    local own, other = 0, 0
    for _, mem in ipairs(R.Members({ kind = "raid", size = 19, ownRealm = "Testrealm" }, R.Random(3))) do
        if mem.realm == "Testrealm" then own = own + 1 else other = other + 1 end
    end
    assertTrue(own > other, "most share your realm")
    assertTrue(other > 0, "some come from another realm")
end)

test("sim roster: gear is drawn inside the band, from what the class can wear; the rest stays empty", function()
    local NS = T.newAddon()
    local R, S = NS.SimRoster, NS.Constants.SLOT
    local W = NS.Constants.WEAPON_SUBCLASS
    local entries = {
        { link = "plate600", equipLoc = "INVTYPE_HEAD", ilvl = 600, classID = 4, subClassID = 4 },
        { link = "cloth600", equipLoc = "INVTYPE_HEAD", ilvl = 600, classID = 4, subClassID = 1 },
        { link = "plate650", equipLoc = "INVTYPE_CHEST", ilvl = 650, classID = 4, subClassID = 4 },
        { link = "ringA", equipLoc = "INVTYPE_FINGER", ilvl = 598, classID = 4, subClassID = 0 },
        { link = "ringB", equipLoc = "INVTYPE_FINGER", ilvl = 602, classID = 4, subClassID = 0 },
        { link = "sword2h", equipLoc = "INVTYPE_2HWEAPON", ilvl = 600, classID = 2, subClassID = W.SWORD_2H },
        { link = "shield", equipLoc = "INVTYPE_SHIELD", ilvl = 600, classID = 4, subClassID = 6 },
    }
    -- A Retribution paladin (70): plate, a two-hander, no Titan's Grip.
    local ret = { classFile = "PALADIN", specID = 70 }
    local gear = R.Gear(ret, entries, { low = 590, high = 605 }, R.Random(5))
    assertEqual(gear[S.HEAD], "plate600", "plate, never cloth")
    assertNil(gear[S.CHEST], "650 is outside the band: the slot stays empty")
    assertTrue((gear[S.FINGER1] == "ringA" and gear[S.FINGER2] == "ringB")
        or (gear[S.FINGER1] == "ringB" and gear[S.FINGER2] == "ringA"), "two different rings")
    assertEqual(gear[S.MAINHAND], "sword2h")
    -- red under: a generator that fills the off hand behind a two-hander
    assertNil(gear[S.OFFHAND], "a two-hander leaves the off hand empty")
    assertNil(gear[S.WAIST], "nothing in the pool for the waist")
    -- A mage cannot wear plate nor a shield, and has no two-hander sword.
    local mage = R.Gear({ classFile = "MAGE", specID = 62 }, entries, { low = 590, high = 605 }, R.Random(5))
    assertEqual(mage[S.HEAD], "cloth600")
    assertNil(mage[S.MAINHAND]); assertNil(mage[S.OFFHAND])
    local band = R.BandAround(600)
    assertEqual(band.low, 590); assertEqual(band.high, 605)
    assertEqual(R.BandAround(600, { low = -20, high = 0 }).low, 580)
end)

test("sim roster: Create draws the group from the session's pool and the stop forgets it", function()
    local NS, m = solo()
    seedJournal(m)
    assertNil(NS.SimRoster.Create({}), "no simulation: nothing")
    NS.Sim.Start({ scenario = "test" })
    NS.SimPool.Build({ situation = "dungeon" })
    local members = NS.SimRoster.Create({ kind = "raid", size = 12, seed = 9 })
    assertEqual(#members, 12)
    assertEqual(NS.SimRoster.Get(), members)
    local rings = 0
    for _, mem in ipairs(members) do
        assertTrue(NS.Sim.IsSimGUID(mem.guid), "marked as the simulation's")
        for _, l in pairs(mem.gear) do
            assertTrue(m.items[l] ~= nil, "a pool item")
            local ilvl = m.items[l].ilvl
            assertTrue(ilvl >= 590 and ilvl <= 605, "inside the default band around 600")
            if m.items[l].equipLoc == "INVTYPE_FINGER" then rings = rings + 1 end
        end
    end
    assertTrue(rings > 0, "rings are drawn")
    assertEqual(NS.Sim.Status().members, 12)
    local guid = members[1].guid
    NS.Sim.Stop()
    assertEqual(#NS.SimRoster.Get(), 0)
    assertFalse(NS.Sim.IsSimGUID(guid))
end)
