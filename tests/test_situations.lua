-- tests/test_situations.lua — modules/Situations.lua (design spec §6.1): the classifier's truth
-- table for every key, the per-situation settings with their spec defaults, and the edge: the six
-- re-evaluation events, SITUATION_CHANGED, the difficulty check and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local cached
local function load()
    if not cached then
        local NS = T.newAddon()
        cached = { Sit = NS.Situations, C = NS.Constants }
    end
    return cached.Sit, cached.C
end

local _, C0 = load()
local D = C0.DIFFICULTY

-- ---------------------------------------------------------------------------------------------
-- the classifier (pure)
-- ---------------------------------------------------------------------------------------------

-- Instance inputs: in an instance of `instanceType` at `difficultyID`, with `over` merged in.
local function inst(instanceType, difficultyID, over)
    local i = { inInstance = true, instanceType = instanceType, difficultyID = difficultyID, inGroup = true }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end

local function world(over)
    local i = { inInstance = false, instanceType = "none" }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end

-- { label, inputs, key }. Every C.SITUATIONS key appears at least once (checked below).
local TRUTH = {
    { "M+ active",                     inst("party", D.MYTHIC_KEYSTONE, { isChallengeModeActive = true }), "mythicPlus" },
    { "M+ difficulty, flag not yet up", inst("party", D.MYTHIC_KEYSTONE), "mythicPlus" },
    { "M+ flag over a Mythic 0 id",    inst("party", D.MYTHIC_DUNGEON, { isChallengeModeActive = true }), "mythicPlus" },
    { "Normal dungeon",                inst("party", D.NORMAL_DUNGEON), "dungeon" },
    { "Heroic dungeon",                inst("party", D.HEROIC_DUNGEON), "dungeon" },
    { "Mythic 0",                      inst("party", D.MYTHIC_DUNGEON), "dungeon" },
    { "Timewalking dungeon",           inst("party", D.TIMEWALKING_DUNGEON), "dungeon" },
    { "party, unknown difficulty",     inst("party", nil), "dungeon" },
    { "party, solo",                   inst("party", D.NORMAL_DUNGEON, { inGroup = false }), "dungeon" },
    { "follower dungeon by id",        inst("party", D.FOLLOWER_DUNGEON), "followerDungeon" },
    { "follower dungeon by flag",      inst("party", nil, { isFollowerDungeon = true }), "followerDungeon" },
    { "LFR",                           inst("raid", D.LFR), "raidLFR" },
    { "legacy LFR",                    inst("raid", D.LFR_LEGACY), "raidLFR" },
    { "Timewalking LFR",               inst("raid", D.LFR_TIMEWALKING), "raidLFR" },
    { "Normal raid",                   inst("raid", D.NORMAL_RAID), "raid" },
    { "Heroic raid",                   inst("raid", D.HEROIC_RAID), "raid" },
    { "Mythic raid",                   inst("raid", D.MYTHIC_RAID), "raid" },
    { "Timewalking raid",              inst("raid", D.TIMEWALKING_RAID), "raid" },
    { "legacy 10-player",              inst("raid", D.RAID_10_NORMAL), "raid" },
    { "raid, unknown difficulty",      inst("raid", nil), "raid" },
    { "delve by id",                   inst("scenario", D.DELVE), "delve" },
    { "delve by flag",                 inst("scenario", nil, { isDelve = true }), "delve" },
    { "scenario",                      inst("scenario", nil), "scenario" },
    { "battleground",                  inst("pvp", nil), "pvp" },
    { "arena",                         inst("arena", nil), "pvp" },
    { "PvP flag",                      inst("none", nil, { isPvP = true }), "pvp" },
    { "open world, in a party",        world({ inGroup = true }), "openWorldGroup" },
    { "open world, in a raid",         world({ inGroup = true, inRaid = true }), "openWorldGroup" },
    { "open world, alone",             world(), "solo" },
    { "unnamed instance type, alone",  inst("neighborhood", nil, { inGroup = false }), "solo" },
    { "unnamed instance type, grouped", inst("interior", nil), "openWorldGroup" },
    { "a dungeon id outside an instance", world({ difficultyID = D.HEROIC_DUNGEON }), "solo" },
}

test("situations: the classifier truth table", function()
    local Sit = load()
    for _, row in ipairs(TRUTH) do assertEqual(Sit.Classify(row[2]), row[3], row[1]) end
end)

test("situations: the truth table reaches every situation key", function()
    local _, C = load()
    local seen = {}
    for _, row in ipairs(TRUTH) do seen[row[3]] = true end
    for _, s in ipairs(C.SITUATIONS) do assertTrue(seen[s.key], s.key .. " is never reached") end
end)

test("situations: garbage inputs classify as solo and never throw", function()
    local Sit = load()
    for _, v in ipairs({ "x", 1, true, {}, { difficultyID = "8" }, { difficultyID = 0 / 0 } }) do
        assertEqual(Sit.Classify(v), "solo", tostring(v))
    end
    assertEqual(Sit.Classify(nil), "solo")
end)

-- ---------------------------------------------------------------------------------------------
-- the per-situation settings (pure)
-- ---------------------------------------------------------------------------------------------

test("situations: with nothing stored, every key takes the spec's track and auto-open", function()
    local Sit, C = load()
    local SPEC = {   -- design spec §6.1 with the owner's DW-06 defaults, pinned as literals
        mythicPlus = { true, true }, dungeon = { true, true }, followerDungeon = { true, true },
        raidLFR = { true, false }, raid = { true, true }, delve = { true, true },
        scenario = { true, true }, pvp = { false, false }, openWorldGroup = { false, false },
        solo = { true, true },
    }
    local n = 0
    for _, s in ipairs(C.SITUATIONS) do
        local r = Sit.Resolve(s.key, nil)
        assertEqual(r.track, SPEC[s.key][1], s.key .. " track")
        assertEqual(r.autoOpen, SPEC[s.key][2], s.key .. " autoOpen")
        assertNil(r.quality, s.key .. " quality")
        n = n + 1
    end
    assertEqual(n, 10)
end)

test("situations: a stored row overrides, and a malformed field falls back to the default", function()
    local Sit = load()
    local r = Sit.Resolve("solo", { track = true, autoOpen = true, quality = "dynamicSlot" })
    assertTrue(r.track); assertTrue(r.autoOpen); assertEqual(r.quality, "dynamicSlot")
    r = Sit.Resolve("dungeon", { track = false })
    assertFalse(r.track); assertTrue(r.autoOpen, "the absent field keeps its default")
    r = Sit.Resolve("dungeon", { track = "no", autoOpen = 0 })
    assertTrue(r.track); assertTrue(r.autoOpen)
    for _, q in ipairs({ "global", "bogus", 3 }) do
        assertNil(Sit.Resolve("raid", { quality = q }).quality, tostring(q))
    end
    for _, mode in ipairs({ "fixed", "dynamicSlot", "dynamicCharacter" }) do
        assertEqual(Sit.Resolve("raid", { quality = mode }).quality, mode)
    end
    r = Sit.Resolve("raid", "garbage")
    assertTrue(r.track)
end)

test("situations: an unknown key tracks nothing", function()
    local Sit = load()
    local r = Sit.Resolve("nowhere", nil)
    assertFalse(r.track); assertFalse(r.autoOpen); assertNil(r.quality)
    assertFalse(Sit.Resolve(nil, nil).track)
end)

-- ---------------------------------------------------------------------------------------------
-- the edge
-- ---------------------------------------------------------------------------------------------

-- Put the mocked player somewhere: `p` = { inInstance, instanceType, difficultyID, cm, inGroup,
-- inRaid }.
local function place(m, p)
    m.__context.inInstance = p.inInstance or false
    m.__context.instanceType = p.instanceType or "none"
    m.__context.inGroup = p.inGroup or false
    m.__context.inRaid = p.inRaid or false
    m.instance.difficultyID = p.difficultyID or 0
    m.challengeModeActive = p.cm or false
end

local KEYSTONE = { inInstance = true, instanceType = "party", difficultyID = 8, cm = true, inGroup = true }
local HEROIC = { inInstance = true, instanceType = "party", difficultyID = 2, inGroup = true }

-- An enabled instance with a receiver recording every SITUATION_CHANGED as { key, prev }.
local function live()
    local NS, _, m = T.enableAddon()
    local heard = {}
    local rx = NS.Bus:NewTarget()
    rx:RegisterMessage(NS.MSG.SITUATION_CHANGED, function(_, key, prev)
        heard[#heard + 1] = { key, prev }
    end)
    return NS, m, heard
end

test("situations: each re-evaluation event classifies and announces a change once", function()
    local NS, m, heard = live()
    local EVENTS = {
        { "PLAYER_ENTERING_WORLD", HEROIC, "dungeon" },
        { "CHALLENGE_MODE_START", KEYSTONE, "mythicPlus" },
        { "CHALLENGE_MODE_COMPLETED", HEROIC, "dungeon" },
        { "ZONE_CHANGED_NEW_AREA", { inGroup = true }, "openWorldGroup" },
        { "GROUP_ROSTER_UPDATE", {}, "solo" },
        { "PLAYER_DIFFICULTY_CHANGED", { inInstance = true, instanceType = "raid", difficultyID = 17 }, "raidLFR" },
    }
    local prev
    for i, e in ipairs(EVENTS) do
        place(m, e[2])
        assertTrue(m.__fire(e[1]) > 0, e[1] .. " is registered")
        assertEqual(NS.Situations.Current(), e[3], e[1])
        assertEqual(#heard, i, e[1] .. " announced")
        assertEqual(heard[i][1], e[3])
        assertEqual(heard[i][2], prev, e[1] .. " carries the previous key")
        prev = e[3]
    end
end)

test("situations: an event that changes nothing sends nothing", function()
    local NS, m, heard = live()
    place(m, HEROIC)
    m.__fire("PLAYER_ENTERING_WORLD")
    m.__fire("GROUP_ROSTER_UPDATE")
    m.__fire("ZONE_CHANGED_NEW_AREA")
    assertEqual(#heard, 1)
    assertEqual(NS.Situations.Current(), "dungeon")
end)

test("situations: the edge's inputs are what the client says", function()
    local NS, m = live()
    place(m, KEYSTONE)
    local i = NS.Situations.ReadInputs()
    assertTrue(i.inInstance); assertEqual(i.instanceType, "party"); assertEqual(i.difficultyID, 8)
    assertTrue(i.isChallengeModeActive); assertTrue(i.inGroup); assertFalse(i.inRaid)
    assertFalse(i.isDelve); assertFalse(i.isFollowerDungeon); assertFalse(i.isPvP)
    place(m, { inInstance = true, instanceType = "scenario", difficultyID = 208 })
    i = NS.Situations.ReadInputs()
    assertTrue(i.isDelve)
    place(m, { inInstance = true, instanceType = "arena" })
    assertTrue(NS.Situations.ReadInputs().isPvP)
    m.__fire("PLAYER_ENTERING_WORLD")
    assertEqual(NS.Situations.LastInputs().instanceType, "arena")
end)

test("situations: a difficulty the client does not know falls back to the instance type", function()
    local NS, m = live()
    place(m, { inInstance = true, instanceType = "party", difficultyID = 205, inGroup = true })
    assertEqual(NS.Situations.Current(), "followerDungeon")
    m.unknownDifficulties[205] = true
    assertNil(NS.Situations.ReadInputs().difficultyID)
    assertEqual(NS.Situations.Current(), "dungeon")
end)

test("situations: a client with no C_ChallengeMode still classifies", function()
    local NS, m = live()
    m.C_ChallengeMode = nil
    place(m, HEROIC)
    assertFalse(NS.Situations.ReadInputs().isChallengeModeActive)
    assertEqual(NS.Situations.Current(), "dungeon")
end)

test("situations: Current classifies live before the first event, without a message", function()
    local NS, m, heard = live()
    place(m, KEYSTONE)
    assertNil(NS.State.situation)
    assertEqual(NS.Situations.Current(), "mythicPlus")
    assertEqual(#heard, 0)
end)

test("situations: IsTracking, ShouldAutoOpen and QualityOverride read the profile, then the spec", function()
    local NS, m = live()
    local Sit = NS.Situations
    place(m, HEROIC)
    m.__fire("PLAYER_ENTERING_WORLD")
    assertTrue(Sit.IsTracking()); assertTrue(Sit.ShouldAutoOpen()); assertNil(Sit.QualityOverride())
    assertFalse(Sit.IsTracking("pvp")); assertFalse(Sit.ShouldAutoOpen("raidLFR"))
    NS.db.profile.situations = { dungeon = { track = false, autoOpen = false, quality = "dynamicCharacter" } }
    assertFalse(Sit.IsTracking()); assertFalse(Sit.ShouldAutoOpen())
    assertEqual(Sit.QualityOverride(), "dynamicCharacter")
    assertEqual(NS.QualityGate.ResolveMode("fixed", Sit.QualityOverride()), "dynamicCharacter")
    assertTrue(Sit.IsTracking("raid"), "another key keeps its default")
end)

test("situations: stood down, the events are gone; the stand-up announces where the player is", function()
    local NS, m, heard = live()
    place(m, HEROIC)
    m.__fire("PLAYER_ENTERING_WORLD")
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.situation, "the stand-down drops the stale key")
    place(m, KEYSTONE)
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "CHALLENGE_MODE_START", "GROUP_ROSTER_UPDATE" }) do
        assertEqual(m.__fire(e), 0, e)
    end
    NS.addon:OnSlashCommand("enable")
    assertEqual(NS.State.situation, "mythicPlus")
    local last = heard[#heard]
    assertEqual(last[1], "mythicPlus", "the replayed receiver heard the stand-up")
end)
