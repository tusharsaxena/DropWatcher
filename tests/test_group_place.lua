-- tests/test_group_place.lua — where a group dropped and who saw it (feedback-3 spec §4, DW-B4):
-- modules/GroupPlace.lua's pure core (the difficulty's name, the header's place parts, the
-- recorder), the two compat reads behind it (GetDifficultyInfo's name, the keystone's level), the
-- owner's real Timewalking drop through the real feed (`Gate of the Setting Sun · Commander Ri'mok ·
-- Timewalking · ... · Testchar`) kept on its History group, a key run's `Mythic+ <level>` read after
-- the run completes, the open world's fallback to the situation word, and realistic names in test
-- mode and the simulator.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertNil

local function uncolored(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function joined(parts) return table.concat(parts, " · ") end

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

test("group place: a keystone's difficulty reads Mythic+ and its level; any other is the client's name", function()
    local GP = T.newAddon().GroupPlace
    assertEqual(GP.DifficultyName(8, "Mythic Keystone", 12), "Mythic+ 12")
    assertEqual(GP.DifficultyName(8, "Mythic Keystone", nil), "Mythic+", "no level read: Mythic+ alone")
    assertEqual(GP.DifficultyName(8, nil, 0), "Mythic+")
    assertEqual(GP.DifficultyName(24, "Timewalking", 12), "Timewalking", "a level means nothing elsewhere")
    assertNil(GP.DifficultyName(24, nil)); assertNil(GP.DifficultyName(24, ""))
end)

test("group place: an encounter names its instance, its boss, then its difficulty", function()
    local GP = T.newAddon().GroupPlace
    local g = { kind = "encounter", label = "Commander Ri'mok", instance = "Gate of the Setting Sun",
        difficulty = "Timewalking" }
    assertEqual(joined(GP.Parts(g, "Dungeon")), "Gate of the Setting Sun · Commander Ri'mok · Timewalking",
        "the difficulty's name, never the generic situation word")
end)

test("group place: a key run's and an area's label is the instance, named once", function()
    local GP = T.newAddon().GroupPlace
    assertEqual(joined(GP.Parts({ kind = "run", label = "Ara-Kara", instance = "Ara-Kara", difficulty = "Mythic+ 9" },
        "Mythic+")), "Ara-Kara · Mythic+ 9")
    assertEqual(joined(GP.Parts({ kind = "run", label = "Ara-Kara", instance = "Ara-Kara, City of Echoes",
        difficulty = "Mythic+ 9" })), "Ara-Kara · Mythic+ 9", "a run's map name stands for the instance")
    assertEqual(joined(GP.Parts({ kind = "area", label = "The Spire", instance = "the spire", difficulty = "Heroic" })),
        "The Spire · Heroic", "the same name twice is said once, whatever its case")
end)

test("group place: with no difficulty name the situation word stands in; an older group keeps its label", function()
    local GP = T.newAddon().GroupPlace
    assertEqual(joined(GP.Parts({ kind = "area", label = "Open world" }, "Solo")), "Open world · Solo")
    assertEqual(joined(GP.Parts({ kind = "encounter", label = "Boss" }, "Raid")), "Boss · Raid",
        "a History group kept before DW-B4 reads as it did")
    assertEqual(joined(GP.Parts({ kind = "encounter", label = "Boss", instance = "The Spire" }, nil)),
        "The Spire · Boss")
    assertEqual(joined(GP.Parts({}, nil)), "?")
end)

test("group place: Looking For Raid reads LFR, a stored name too, and Parts names each part's role", function()
    local GP = T.newAddon().GroupPlace
    local g = { kind = "encounter", label = "Vashnik the Malignant", instance = "The Venomous Abyss",
        difficulty = "Looking For Raid" }
    -- red under: a header that spells out the client's Looking For Raid
    local parts, roles = GP.Parts(g, "Raid", GP.ShortNames())
    assertEqual(joined(parts), "The Venomous Abyss · Vashnik the Malignant · LFR")
    assertEqual(table.concat(roles, ","), "instance,label,difficulty")
    assertEqual(joined(GP.Parts({ kind = "area", label = "Open world" }, "Solo", GP.ShortNames())), "Open world · Solo")
    assertEqual(table.concat(select(2, GP.Parts({ kind = "area", label = "Open world" }, "Solo")), ","),
        "label,situation", "the situation word stands in for the difficulty")
    assertEqual(joined(GP.Parts(g, "Raid")), "The Venomous Abyss · Vashnik the Malignant · Looking For Raid",
        "with no short names the client's name stands")
    assertEqual(GP.Who({ seenBy = "Sacrilègeous-Realm" }, nil, 10), "Sacrilège…", "the recorder cut to a limit")
end)

test("group place: Who names the recorder alone, its short name class-colored; History falls back to an entry", function()
    local GP = T.newAddon().GroupPlace
    local function colorOf(c) if c == "MAGE" then return 1, 0, 0 end end
    assertEqual(GP.Who({ seenBy = "Euthanàsia-Azralon", seenByClass = "MAGE" }, colorOf), "|cffff0000Euthanàsia|r")
    assertEqual(GP.Who({ seenBy = "Alt-Other", seenByClass = "ROGUE" }, colorOf), "Alt", "an unknown color is plain")
    assertEqual(GP.Who({ drops = { { seenBy = nil }, { seenBy = "Old-Realm", seenByClass = "MAGE" } } }, colorOf),
        "|cffff0000Old|r", "a group kept before DW-B4: its first entry with a recorder")
    assertNil(GP.Who({ drops = { 1, 2 } }), "a feed group's drops are ids")
    assertNil(GP.Who({}))
end)

-- ── the compat reads ────────────────────────────────────────────────────────────────────────

test("compat: DifficultyName answers the client's name, nil for an unknown id or no API", function()
    local NS, _, m = T.newAddon()
    assertEqual(NS.Compat.DifficultyName(24), "Timewalking")
    assertEqual(NS.Compat.DifficultyName(208), "Delves")
    m.unknownDifficulties[24] = true
    assertNil(NS.Compat.DifficultyName(24)); assertNil(NS.Compat.DifficultyName(0))
    assertNil(NS.Compat.DifficultyName("8"))
    m.GetDifficultyInfo = nil
    assertNil(NS.Compat.DifficultyName(1))
end)

test("compat: KeystoneLevel answers the active key, else the completed run's, else nil", function()
    local NS, _, m = T.newAddon()
    assertNil(NS.Compat.KeystoneLevel(), "no key")
    m.keystoneLevel = 9
    assertEqual(NS.Compat.KeystoneLevel(), 9)
    m.keystoneLevel, m.completionLevel = 0, 15
    assertEqual(NS.Compat.KeystoneLevel(), 15, "the run completed: its end chest is still the run's")
    m.C_ChallengeMode.GetChallengeCompletionInfo = nil
    assertNil(NS.Compat.KeystoneLevel())
    m.C_ChallengeMode = nil
    assertNil(NS.Compat.KeystoneLevel())
end)

-- ── through the real feed ───────────────────────────────────────────────────────────────────

local LEGGINGS = "|cff0070dd|Hitem:143982::::::::90:::::|h[Leggings of the Frenzy]|h|r"

local function inInstance(name, difficultyID, seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = name, difficultyID = difficultyID }
        if seed then seed(m) end
    end })
    m.addItem(LEGGINGS, { name = "Leggings of the Frenzy", quality = 3, ilvl = 183, equipLoc = "INVTYPE_LEGS",
        classID = 4, subClassID = 1, bindType = 1, stats = {} })
    return NS, m
end

local function loot(m, text)
    return m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

test("feed: the owner's Timewalking drop names the instance, the boss, Timewalking and you (07)", function()
    local NS, m = inInstance("Gate of the Setting Sun", 24)
    m.__fire("ENCOUNTER_START", 1425, "Commander Ri'mok", 24, 5)
    m.__fire("ENCOUNTER_END", 1425, "Commander Ri'mok", 24, 5, 1)
    loot(m, "You receive loot: " .. LEGGINGS .. ".")
    m.advance(0)
    local g = NS.LootFeed.Groups("live")[1]
    assertTrue(g ~= nil, "the drop made a group")
    assertEqual(g.instance, "Gate of the Setting Sun"); assertEqual(g.difficulty, "Timewalking")
    assertEqual(g.seenBy, "Testchar-Testrealm")
    local sit = NS.WindowFooter.SITUATION_LABEL[g.situation]
    local hd = NS.WindowCells.Header(g, 1, nil, sit, false)
    assertEqual(uncolored(hd.text), "Gate of the Setting Sun · Commander Ri'mok · Timewalking · 1 drop · Testchar")
    -- History keeps all four with the group, and its header reads the same.
    local kept = NS.History.Log().groups[1]
    assertTrue(kept ~= nil, "recorded")
    assertEqual(kept.instance, "Gate of the Setting Sun"); assertEqual(kept.difficulty, "Timewalking")
    assertEqual(kept.seenBy, "Testchar-Testrealm"); assertTrue(kept.seenByClass ~= nil)
    local wh = NS.WindowHistory.Header(kept, 1, nil, sit, false)
    assertEqual(uncolored(wh.text), "Gate of the Setting Sun · Commander Ri'mok · Timewalking · 1 drop · Testchar")
end)

test("feed: GetInstanceInfo's own difficulty name wins over GetDifficultyInfo's; an empty one falls back", function()
    local NS, m = inInstance("Gate of the Setting Sun", 24, function(m)
        m.instance.difficultyName = "Instance Says This"
    end)
    loot(m, "You receive loot: " .. LEGGINGS .. ".")
    m.advance(0)
    assertEqual(NS.LootFeed.Groups("live")[1].difficulty, "Instance Says This")
    assertEqual(NS.GroupPlace.Read().difficulty, "Instance Says This")
    m.instance.difficultyName = ""
    assertEqual(NS.GroupPlace.Read().difficulty, "Timewalking", "GetDifficultyInfo's name when the instance gives none")
    m.instance.difficultyName = nil
    assertEqual(NS.GroupPlace.Read().difficulty, "Timewalking")
end)

test("feed: a group keeps the place it opened in", function()
    local NS, m = inInstance("Gate of the Setting Sun", 24)
    m.__fire("ENCOUNTER_START", 1425, "Commander Ri'mok", 24, 5)
    m.__fire("ENCOUNTER_END", 1425, "Commander Ri'mok", 24, 5, 1)
    loot(m, "You receive loot: " .. LEGGINGS .. ".")
    m.instance = { name = "Somewhere Else", difficultyID = 2 }
    loot(m, "You receive loot: " .. LEGGINGS .. ".")
    m.advance(0)
    local groups = NS.LootFeed.Groups("live")
    assertEqual(#groups, 1, "the same encounter's group")
    assertEqual(groups[1].instance, "Gate of the Setting Sun"); assertEqual(groups[1].difficulty, "Timewalking")
end)

test("feed: a key run's end chest reads Mythic+ and the completed run's level", function()
    local NS, m = inInstance("Ara-Kara, City of Echoes", 8, function(m)
        m.challengeMaps[503] = "Ara-Kara, City of Echoes"
    end)
    m.challengeModeActive, m.keystoneLevel = true, 14
    m.__fire("CHALLENGE_MODE_START", 503)
    m.challengeModeActive, m.keystoneLevel, m.completionLevel = false, 0, 14
    m.__fire("CHALLENGE_MODE_COMPLETED")
    loot(m, "You receive loot: " .. LEGGINGS .. ".")
    m.advance(0)
    local g = NS.LootFeed.Groups("live")[1]
    assertEqual(g.kind, "run")
    local hd = NS.WindowCells.Header(g, 1, nil, "Mythic+", false)
    assertEqual(uncolored(hd.text), "Ara-Kara, City of Echoes · Mythic+ 14 · 1 drop · Testchar")
end)

test("feed: in the open world no place is read and the situation word stands in", function()
    local NS, m = T.enableAddon()
    m.addItem(LEGGINGS, { name = "Leggings of the Frenzy", quality = 4, ilvl = 183, equipLoc = "INVTYPE_LEGS",
        classID = 4, subClassID = 1, bindType = 1, stats = {} })
    local spec = NS.GroupPlace.Stamp({ key = "area:Open world", label = "Open world", kind = "area" })
    assertNil(spec.instance); assertNil(spec.difficulty)
    assertEqual(joined(NS.GroupPlace.Parts(spec, "Solo")), "Open world · Solo")
end)

-- ── test mode and the simulator ─────────────────────────────────────────────────────────────

test("test mode: the sample groups carry real instance names and realistic difficulties", function()
    local NS = T.newAddon()
    local TD = NS.TestData
    local entry = function(id, slot, inst)
        return { link = ("|cffa335ee|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id), itemID = id,
            equipLoc = slot, ilvl = 600, instance = inst }
    end
    local drops = { entry(1, "INVTYPE_HEAD", "Ara-Kara, City of Echoes"), entry(2, "INVTYPE_CLOAK", "The Rookery") }
    local src = TD.Source(drops, drops, function(e)
        return { link = e.link, itemID = e.itemID, ilvl = e.ilvl, equipLoc = e.equipLoc, quality = 4 }
    end)
    local you = { name = "Tester", guid = "P1", classFile = "MAGE", isSelf = true, seenBy = "Tester-Realm" }
    local seen = {}
    for _, s in ipairs(TD.Placeholders(1000, you, src)) do seen[s.group.kind] = s.group end
    assertEqual(seen.run.label, "Ara-Kara, City of Echoes", "the key run is a real dungeon")
    assertEqual(seen.run.difficulty, "Mythic+ 10")
    assertEqual(seen.encounter.instance, "The Rookery"); assertEqual(seen.encounter.difficulty, "Heroic")
    for _, g in ipairs(TD.History(5000, you, src).groups) do
        assertTrue(g.instance ~= nil and g.difficulty ~= nil, g.key .. ": a sample History group names its place")
        assertTrue(g.seenBy ~= nil, g.key .. ": and its recorder")
    end
end)

-- Two dungeons dropping rings at the dungeon difficulties (tests/test_sim_e2e.lua's journal, cut down).
local function seedJournal(m)
    local j = m.journal
    j.tiers = { { dungeons = { { id = 101, name = "Ashen Vault" } }, raids = {} } }
    j.loot[101] = {}
    for _, d in ipairs({ 1, 2, 23, 8 }) do
        local id = 101000 + d
        local l = ("|cnIQ4:|Hitem:%d::::::::90:::::600|h[Item %d]|h|r"):format(id, id)
        m.addItem(l, { name = "Ring", quality = 4, ilvl = 600, equipLoc = "INVTYPE_FINGER", classID = 4,
            subClassID = 0, bindType = 1, stats = {} })
        j.loot[101][d] = { { itemID = id, link = l, encounterID = 2001 } }
    end
end

test("sim: a dungeon boss and a key run name the pool's instance and the client's difficulty", function()
    local NS, _, m = T.enableAddon()
    seedJournal(m)
    NS.SimScenario.Start("dungeon", nil, { seed = 1 })
    NS.SimEvents.Pull(); NS.SimEvents.Kill()
    NS.SimEvents.Loot(1, "me")
    local g = NS.LootFeed.Groups("live")[1]
    assertTrue(g ~= nil, "the simulated drop made a group")
    assertEqual(g.instance, "Ashen Vault"); assertEqual(g.difficulty, "Mythic")
    assertEqual(joined(NS.GroupPlace.Parts(g, "Dungeon")), "Ashen Vault · " .. g.label .. " · Mythic")
    NS.Sim.Stop("stop")
    NS.SimScenario.Start("key", nil, { seed = 1 })
    NS.SimEvents.RunStart(); NS.SimEvents.RunEnd()
    NS.SimEvents.Loot(1, "me")
    local run
    for _, x in ipairs(NS.LootFeed.Groups("live")) do if x.kind == "run" then run = x end end
    assertTrue(run ~= nil, "the key's chest made a run group")
    assertEqual(joined(NS.GroupPlace.Parts(run, "Mythic+")), "Ashen Vault · Mythic+ " .. NS.SimEvents.KEY_LEVEL)
end)
