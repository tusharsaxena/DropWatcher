-- tests/test_gear.lua — modules/Gear.lua (design spec §4, §5.3, §6.2): the player's gear snapshot
-- (each worn slot at its current level, the best owned item per slot with the bags included), the
-- candidate table the verdict kernel takes for you, the per-slot qualities the quality gate reads,
-- the throttled rebuild on the gear events, GearChanged, items still loading, and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local SLOT = { HEAD = 1, NECK = 2, CHEST = 5, FINGER1 = 11, FINGER2 = 12, MAINHAND = 16, OFFHAND = 17 }

-- A link for item `id`, and its definition in the mock's item cache.
local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function def(equipLoc, ilvl, classID, subClassID, extra)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = classID,
        subClassID = subClassID, bindType = 1, stats = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

local function leather(equipLoc, ilvl, extra) return def(equipLoc, ilvl, 4, 2, extra) end
local function plate(equipLoc, ilvl) return def(equipLoc, ilvl, 4, 4) end
local function ring(ilvl, extra) return def("INVTYPE_FINGER", ilvl, 4, 0, extra) end
local function dagger(ilvl) return def("INVTYPE_WEAPON", ilvl, 2, 15) end

-- An Outlaw rogue (a dual wielder in leather) unless the seed says otherwise.
local function enabled(seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.class, m.__context.classToken = "Rogue", "ROGUE"
        m.specID = 260
        if seed then seed(m) end
    end })
    return NS, m, NS.Gear
end

local function wear(m, slot, id, d)
    m.addItem(link(id), d)
    m.inventory.player[slot] = link(id)
end

local function carry(m, bag, slot, id, d)
    m.addItem(link(id), d)
    m.bags[bag] = m.bags[bag] or { size = 16 }
    m.bags[bag][slot] = link(id)
end

-- Counts GearChanged on a receiver of its own.
local function listen(NS)
    local seen = { n = 0 }
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.GEAR_CHANGED, function() seen.n = seen.n + 1 end)
    return seen
end

-- ---------------------------------------------------------------------------------------------
-- The snapshot
-- ---------------------------------------------------------------------------------------------

test("gear: each worn slot is a copy of its facts at the current level; an empty slot is false", function()
    local NS, _, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600, { effectiveIlvl = 610 }))
        wear(m, SLOT.CHEST, 3002, leather("INVTYPE_CHEST", 620))
        m.tooltips.inventory["player:" .. SLOT.CHEST] = { lines = { { type = 41, leftText = "Item Level 590" } } }
    end)
    G.Refresh("test")
    local s = G.Snapshot()
    assertEqual(s.equipped[SLOT.HEAD].ilvl, 610, "the link's effective level with no tooltip line")
    assertEqual(s.equipped[SLOT.HEAD].slot, SLOT.HEAD)
    assertEqual(s.equipped[SLOT.CHEST].ilvl, 590, "the tooltip's current level wins")
    assertEqual(NS.ItemFacts.Get(link(3002)).ilvl, 620, "the cached facts are not written")
    assertEqual(s.equipped[SLOT.NECK], false, "an empty slot")
    assertEqual(s.equipped[SLOT.CHEST].link, link(3002))
    assertEqual(s.loading, 0)
    assertTrue(G.IsComplete())
end)

test("gear: the candidate carries the class, the spec and the hand flags from ClassData", function()
    local _, m, G = enabled()
    local c = G.Candidate()
    assertEqual(c.classFile, "ROGUE"); assertEqual(c.specID, 260)
    assertTrue(c.dualWield); assertFalse(c.titanGrip)
    assertTrue(c.isPlayer)
    assertTrue(c.gear == G.Snapshot().equipped); assertTrue(c.owned == G.Snapshot().owned)
    assertNil(c.prefs, "the feed adds the preferences")
    m.__context.class, m.__context.classToken = "Warrior", "WARRIOR"
    m.specID = 72
    G.Refresh("test")
    c = G.Candidate()
    assertTrue(c.dualWield); assertTrue(c.titanGrip, "Fury")
    m.GetSpecialization = function() return nil end
    m.__context.classToken = "ROGUE"
    G.Refresh("test")
    c = G.Candidate()
    assertNil(c.specID, "no spec yet")
    assertTrue(c.dualWield, "every rogue spec dual wields, so the class answers")
end)

test("gear: a spec the class flags disagree on leaves the hand flag unknown", function()
    local _, _, G = enabled(function(m)
        m.__context.classToken = "WARRIOR"
        m.GetSpecialization = function() return nil end
    end)
    assertNil(G.Candidate().titanGrip, "Fury alone has it: unknown without the spec")
end)

test("gear: the qualities are per worn slot, false for an empty one", function()
    local NS, _, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600, { quality = 3 }))
        wear(m, SLOT.CHEST, 3002, leather("INVTYPE_CHEST", 600, { quality = 4 }))
        wear(m, SLOT.FINGER1, 3003, ring(600, { quality = 4 }))
    end)
    local q = G.Qualities()
    assertEqual(q[SLOT.HEAD], 3); assertEqual(q[SLOT.CHEST], 4); assertEqual(q[SLOT.NECK], false)
    assertEqual(NS.QualityGate.CharacterQuality(q), 4, "the gate reads the snapshot's qualities")
end)

-- ---------------------------------------------------------------------------------------------
-- The best owned per slot
-- ---------------------------------------------------------------------------------------------

test("gear: a better bag item you can wear is owned for its slot; one you cannot is not", function()
    local _, _, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600))
        carry(m, 0, 1, 3010, leather("INVTYPE_HEAD", 630))
        carry(m, 0, 2, 3011, plate("INVTYPE_CHEST", 700))
        carry(m, 1, 4, 3012, def("INVTYPE_HEAD", 700, 15, 0, { equipLoc = "" }))
    end)
    local s = G.Snapshot()
    assertEqual(s.owned[SLOT.HEAD].ilvl, 630)
    assertEqual(s.owned[SLOT.HEAD].bag, 0); assertEqual(s.owned[SLOT.HEAD].bagSlot, 1)
    assertNil(s.owned[SLOT.CHEST], "plate is not a rogue's")
end)

test("gear: a worn item better than any bag item is its own slot's owned best", function()
    local _, _, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 640))
        carry(m, 0, 1, 3010, leather("INVTYPE_HEAD", 630))
    end)
    local s = G.Snapshot()
    assertTrue(s.owned[SLOT.HEAD] == s.equipped[SLOT.HEAD])
end)

test("gear: a pair gets your best two rings, one ring never fills both", function()
    local _, _, G = enabled(function(m)
        wear(m, SLOT.FINGER1, 3001, ring(610))
        wear(m, SLOT.FINGER2, 3002, ring(600))
        carry(m, 0, 1, 3010, ring(620))
    end)
    local s = G.Snapshot()
    assertEqual(s.owned[SLOT.FINGER1].ilvl, 620)
    assertEqual(s.owned[SLOT.FINGER2].ilvl, 610, "the worn 610 moves to the second finger")
end)

test("gear: a dual wielder's one-handers fill both hands, each once", function()
    local _, _, G = enabled(function(m)
        wear(m, SLOT.MAINHAND, 3001, dagger(600))
        wear(m, SLOT.OFFHAND, 3002, dagger(590))
        carry(m, 0, 1, 3010, dagger(630))
    end)
    local s = G.Snapshot()
    assertEqual(s.owned[SLOT.MAINHAND].ilvl, 630)
    assertEqual(s.owned[SLOT.OFFHAND].ilvl, 600)
end)

test("gear: a one-hander fills the main hand only for a spec that does not dual wield", function()
    local _, _, G = enabled(function(m)
        m.__context.classToken = "PRIEST"
        m.specID = 257
        carry(m, 0, 1, 3010, dagger(630))
        carry(m, 0, 2, 3011, def("INVTYPE_HOLDABLE", 610, 4, 0))
    end)
    local s = G.Snapshot()
    assertEqual(s.owned[SLOT.MAINHAND].ilvl, 630)
    assertEqual(s.owned[SLOT.OFFHAND].ilvl, 610, "the held off hand")
end)

test("gear: with Titan's Grip a two-hander can fill the off hand too", function()
    local _, _, G = enabled(function(m)
        m.__context.classToken = "WARRIOR"
        m.specID = 72
        carry(m, 0, 1, 3010, def("INVTYPE_2HWEAPON", 640, 2, 8))
        carry(m, 0, 2, 3011, def("INVTYPE_2HWEAPON", 630, 2, 1))
    end)
    local s = G.Snapshot()
    assertEqual(s.owned[SLOT.MAINHAND].ilvl, 640)
    assertEqual(s.owned[SLOT.OFFHAND].ilvl, 630)
end)

test("gear: a tier token and a secret bag link are not owned gear", function()
    local NS, m, G = enabled(function(m)
        carry(m, 0, 1, 3010, def("", 700, 15, 0))
        m.tooltips.hyperlink[link(3010)] = { lines = { { type = 21, leftText = "Classes: Rogue" } } }
        m.bags[0][2] = T.secret(link(3011))
        m.addItem(link(3011), leather("INVTYPE_HEAD", 700))
    end)
    m.issecretvalue = function(v) return T.isSecret(v) end
    assertTrue(NS.ItemFacts.Get(link(3010)).isTierToken)
    G.Refresh("test")
    local s = G.Snapshot()
    assertEqual(next(s.owned), nil, "nothing owned")
    assertEqual(s.loading, 0)
end)

-- ---------------------------------------------------------------------------------------------
-- The candidate feeds the verdict kernel
-- ---------------------------------------------------------------------------------------------

test("gear: the candidate judges a drop against the worn item, and against the bags with compareOwned", function()
    local NS, _, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600))
        carry(m, 0, 1, 3010, leather("INVTYPE_HEAD", 640))
        m.addItem(link(3020), leather("INVTYPE_HEAD", 620))
    end)
    local drop = NS.ItemFacts.Get(link(3020))
    local r = NS.Evaluate.Evaluate(drop, G.Candidate(), {})
    assertEqual(r.verdict, "upgrade"); assertEqual(r.ilvlDelta, 20)
    r = NS.Evaluate.Evaluate(drop, G.Candidate(), { compareOwned = true })
    assertEqual(r.verdict, "downgrade", "the 640 in the bags is the baseline"); assertEqual(r.ilvlDelta, -20)
end)

-- ---------------------------------------------------------------------------------------------
-- The events, the throttle and GearChanged
-- ---------------------------------------------------------------------------------------------

test("gear: the gear events share one throttled rebuild, which announces a change once", function()
    local NS, m, G = enabled()
    G.Snapshot()
    local seen = listen(NS)
    wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600))
    m.__fire("PLAYER_EQUIPMENT_CHANGED", SLOT.HEAD, true)
    m.__fire("BAG_UPDATE_DELAYED")
    m.__fire("PLAYER_EQUIPMENT_CHANGED", SLOT.HEAD, false)
    assertTrue(G.IsScheduled())
    assertEqual(seen.n, 0, "nothing before the timer")
    assertEqual(G.Snapshot().equipped[SLOT.HEAD], false, "the stored snapshot until then")
    -- two timers: the one rebuild, and modules/TradeTimer.lua's scan on BAG_UPDATE_DELAYED
    assertEqual(m.__fireTimers(), 2, "one rebuild")
    assertFalse(G.IsScheduled())
    assertEqual(seen.n, 1)
    assertEqual(G.Snapshot().equipped[SLOT.HEAD].ilvl, 600)
    m.__fire("BAG_UPDATE_DELAYED")
    m.__fireTimers()
    assertEqual(seen.n, 1, "a rebuild that changed nothing is silent")
end)

test("gear: the player's spec change rebuilds; another unit's does not", function()
    local NS, m, G = enabled()
    G.Snapshot()
    local seen = listen(NS)
    m.__fire("PLAYER_SPECIALIZATION_CHANGED", "party1")
    assertFalse(G.IsScheduled())
    m.specID = 261
    m.__fire("PLAYER_SPECIALIZATION_CHANGED", "player")
    m.__fireTimers()
    assertEqual(seen.n, 1)
    assertEqual(G.Candidate().specID, 261)
end)

test("gear: the first lazy read announces nothing", function()
    local NS, _, G = enabled()
    NS.State.gear = nil
    local seen = listen(NS)
    G.Snapshot()
    assertEqual(seen.n, 0)
end)

test("gear: an item still loading leaves its slot unknown, and its arrival rebuilds", function()
    local NS, m, G = enabled(function(m)
        wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600, { loadsNeeded = 1 }))
        carry(m, 0, 1, 3010, ring(620, { loadsNeeded = 1 }))
    end)
    NS.State.gear = nil
    local s = G.Snapshot()
    assertNil(s.equipped[SLOT.HEAD], "unknown, not empty")
    assertEqual(s.loading, 2); assertFalse(G.IsComplete())
    assertNil(G.Qualities()[SLOT.HEAD])
    local seen = listen(NS)
    m.__fireTimers()   -- the loads answer, and arm the rebuild
    assertTrue(G.IsScheduled())
    m.__fireTimers()
    assertEqual(seen.n, 1)
    s = G.Snapshot()
    assertEqual(s.equipped[SLOT.HEAD].ilvl, 600); assertEqual(s.owned[SLOT.FINGER1].ilvl, 620)
    assertTrue(G.IsComplete())
end)

-- ---------------------------------------------------------------------------------------------
-- The lifecycle
-- ---------------------------------------------------------------------------------------------

test("gear: the stand-down cancels the rebuild and drops the snapshot; the stand-up rebuilds", function()
    local NS, m, G = enabled(function(m) wear(m, SLOT.HEAD, 3001, leather("INVTYPE_HEAD", 600)) end)
    G.Snapshot()
    m.__fire("BAG_UPDATE_DELAYED")
    assertTrue(G.IsScheduled())
    NS.addon:OnSlashCommand("disable")
    assertFalse(G.IsScheduled())
    assertNil(NS.State.gear)
    assertEqual(m.__fireTimers(), 0, "the canceled rebuild never runs")
    G.Schedule("late")
    assertFalse(G.IsScheduled(), "nothing arms while stood down")
    local seen = listen(NS)
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.State.gear ~= nil, "rebuilt at the stand-up")
    assertEqual(NS.State.gear.equipped[SLOT.HEAD].ilvl, 600)
    assertEqual(seen.n, 1)
end)
