-- tests/test_roster.lua — modules/Roster.lua (design spec §4): the group's members by GUID with
-- their Name-Realm, unit token, classFile and online state; the resolver by GUID, by "Name-Realm"
-- and by bare name, with a same-name tie settled by classFile; the secret guards; the shared
-- GROUP_ROSTER_UPDATE; and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local EVENT = "GROUP_ROSTER_UPDATE"

local function row(guid, name, realm, classFile, connected)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile,
        connected = connected }
end

-- An enabled instance in a party of four: the player, a same-realm warrior, a cross-realm priest
-- and a cross-realm warrior sharing the priest's name.
local function party()
    local NS, _, m = T.enableAddon()
    m.setGroup({
        row("Player-1-0000000A", "Brakk", nil, "WARRIOR"),
        row("Player-2-0000000B", "Lyra", "Area 52", "PRIEST"),
        row("Player-3-0000000C", "Lyra", "Azjol-Nerub", "WARRIOR", false),
    })
    m.__fire(EVENT)
    return NS, m, NS.Roster
end

local function installSecrets(m)
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
end

test("roster: solo, the player alone, read lazily", function()
    local NS = T.enableAddon()
    local Ro = NS.Roster
    assertEqual(Ro.Count(), 1)
    local me = Ro.Player()
    assertEqual(me.fullName, "Testchar-Testrealm", "a same-realm name carries the normalized realm")
    assertEqual(me.unit, "player")
    assertEqual(me.classFile, "MAGE")
    assertTrue(me.online)
    assertTrue(me.isPlayer)
end)

test("roster: a party, in unit order, keyed by GUID, with realm, class and online", function()
    local _, _, Ro = party()
    local list = Ro.Members()
    assertEqual(#list, 4)
    assertEqual(list[1].unit, "player")
    assertEqual(list[2].unit, "party1"); assertEqual(list[4].unit, "party3")
    local b = Ro.Get("Player-1-0000000A")
    assertEqual(b.fullName, "Brakk-Testrealm")
    assertEqual(b.classFile, "WARRIOR")
    assertFalse(b.isPlayer)
    assertEqual(Ro.Get("Player-2-0000000B").fullName, "Lyra-Area52", "the realm is normalized")
    assertEqual(Ro.Get("Player-3-0000000C").realm, "AzjolNerub")
    assertFalse(Ro.Get("Player-3-0000000C").online)
    assertNil(Ro.Get("Player-9-00000009"))
end)

test("roster: a raid reads raid1..N, the player among them", function()
    local NS, _, m = T.enableAddon()
    m.setGroup({ row("Player-1-0000000A", "Brakk", nil, "WARRIOR") }, true)
    m.__fire(EVENT)
    local Ro = NS.Roster
    assertEqual(Ro.Count(), 2)
    assertEqual(Ro.Members()[1].unit, "raid1")
    assertTrue(Ro.Members()[1].isPlayer)
    assertEqual(Ro.Player().unit, "raid1")
    assertEqual(Ro.Resolve("Brakk").unit, "raid2")
end)

test("roster: Resolve by GUID, by Name-Realm and by a bare same-realm name, without case", function()
    local _, _, Ro = party()
    assertEqual(Ro.Resolve("Player-2-0000000B").name, "Lyra")
    assertEqual(Ro.Resolve("Brakk").guid, "Player-1-0000000A")
    assertEqual(Ro.Resolve("brakk-testrealm").guid, "Player-1-0000000A")
    assertEqual(Ro.Resolve("Lyra-Area52").guid, "Player-2-0000000B")
    assertEqual(Ro.Resolve("Lyra-Area 52").guid, "Player-2-0000000B", "the query's realm is normalized too")
    assertEqual(Ro.Resolve("Lyra-Azjol-Nerub").guid, "Player-3-0000000C", "a hyphenated realm")
    assertNil(Ro.Resolve("Brakk-Area52"), "the right name on the wrong realm")
    assertNil(Ro.Resolve("Nobody"))
end)

test("roster: a bare name two members share is settled by classFile, else unresolved", function()
    local _, _, Ro = party()
    assertNil(Ro.Resolve("Lyra"), "two cross-realm Lyras and no class: ambiguous")
    assertEqual(Ro.Resolve("Lyra", "PRIEST").guid, "Player-2-0000000B")
    assertEqual(Ro.Resolve("Lyra", "WARRIOR").guid, "Player-3-0000000C")
    assertNil(Ro.Resolve("Lyra", "MAGE"), "a class neither has leaves both")
end)

test("roster: a bare name prefers the member on the player's own realm", function()
    local NS, _, m = T.enableAddon()
    m.setGroup({
        row("Player-1-0000000A", "Lyra", nil, "PRIEST"),
        row("Player-2-0000000B", "Lyra", "Area52", "PRIEST"),
    })
    m.__fire(EVENT)
    assertEqual(NS.Roster.Resolve("Lyra").guid, "Player-1-0000000A", "chat names a same-realm player bare")
    assertEqual(NS.Roster.Resolve("Lyra", "PRIEST").guid, "Player-1-0000000A")
end)

test("roster: GROUP_ROSTER_UPDATE re-reads the group; the specID survives", function()
    local _, m, Ro = party()
    assertTrue(Ro.SetSpec("Player-1-0000000A", 71))
    m.units.party3 = nil
    m.units.party2.connected = false
    m.__context.groupSize = 3
    m.__fire(EVENT)
    assertEqual(Ro.Count(), 3)
    assertNil(Ro.Get("Player-3-0000000C"), "a member who left is gone")
    assertFalse(Ro.Get("Player-2-0000000B").online)
    assertEqual(Ro.Get("Player-1-0000000A").specID, 71, "the inspect's spec is kept")
    assertFalse(Ro.SetSpec("Player-9-00000009", 71), "no member, nothing recorded")
end)

test("roster: the event fans out to the situation edge and the roster both", function()
    local NS, m = party()
    assertEqual(NS.State.situation, "openWorldGroup", "the situation edge heard it too")
    m.setGroup({})
    assertEqual(m.__fire(EVENT), 1, "one registration, one dispatcher")
    assertEqual(NS.State.situation, "solo")
    assertEqual(NS.Roster.Count(), 1)
end)

test("roster: a miss re-reads the client once, so a name still Unknown at the event resolves", function()
    local _, m, Ro = party()
    m.units.party1.name = "Unknown"
    m.__fire(EVENT)
    assertNil(Ro.Get("Player-1-0000000A").name, "the placeholder is no name")
    assertEqual(Ro.Get("Player-1-0000000A").fullName, nil)
    m.units.party1.name = "Brakk"
    assertEqual(Ro.Resolve("Brakk").guid, "Player-1-0000000A")
end)

test("roster: secret answers never raise; a secret GUID drops the unit, a secret name hides it", function()
    local _, m, Ro = party()
    installSecrets(m)
    m.units.party1.name = T.secret("Brakk")
    m.units.party2.guid = T.secret("Player-2-0000000B")
    m.units.party3.classFile = T.secret("WARRIOR")
    m.units.party3.connected = T.secret(false)
    m.__fire(EVENT)
    assertEqual(Ro.Count(), 3, "the secret GUID cannot key a member")
    assertNil(Ro.Get("Player-1-0000000A").name)
    assertNil(Ro.Resolve("Brakk"))
    assertEqual(Ro.Resolve("Player-1-0000000A").unit, "party1", "still reachable by GUID")
    local c = Ro.Get("Player-3-0000000C")
    assertNil(c.classFile)
    assertTrue(c.online, "a secret online flag reads as online")
    assertNil(Ro.Resolve(T.secret("Brakk")))
    assertNil(Ro.Get(T.secret("Player-1-0000000A")))
    assertEqual(Ro.Resolve("Lyra", T.secret("PRIEST")).guid, "Player-3-0000000C",
        "a secret class is ignored; the one Lyra left answers")
end)

test("roster: garbage queries answer nil", function()
    local _, _, Ro = party()
    assertNil(Ro.Resolve(nil)); assertNil(Ro.Resolve("")); assertNil(Ro.Resolve(42))
    assertNil(Ro.Resolve("-")); assertNil(Ro.Resolve("Lyra-"))
    assertNil(Ro.Get(nil))
end)

test("roster: NormalizeRealm drops spaces and hyphens", function()
    local NS = T.newAddon()
    assertEqual(NS.Roster.NormalizeRealm("Azjol-Nerub"), "AzjolNerub")
    assertEqual(NS.Roster.NormalizeRealm("Area 52"), "Area52")
    assertNil(NS.Roster.NormalizeRealm(""))
    assertNil(NS.Roster.NormalizeRealm(nil))
end)

test("roster: stood down, the roster is dropped and the event is down; the stand-up re-reads", function()
    local NS, m, Ro = party()
    NS.addon:OnSlashCommand("disable")
    assertNil(NS.State.roster, "the stand-down drops the stale roster")
    assertEqual(m.__fire(EVENT), 0, "the event is down")
    m.setGroup({ row("Player-1-0000000A", "Brakk", nil, "WARRIOR") })
    NS.addon:OnSlashCommand("enable")
    assertTrue(NS.State.roster ~= nil, "the stand-up read the group")
    assertEqual(Ro.Count(), 2)
end)
