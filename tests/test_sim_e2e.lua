-- tests/test_sim_e2e.lua — a sim run fills the window (sim feedback spec §0, DW-90): the owner's
-- first `/dw sim run` left Group drops empty. Every read the simulator answers goes through the
-- seam (no module names one of those globals itself); and every scenario, run in the real solo,
-- out-of-instance world the mock answers by default, puts drops in the feed with both verdicts,
-- rows in Group drops and My drops under the window's DEFAULT filters (View Interesting, Content
-- This instance, Quality Rare+), and a footer and chat that report the run. It runs once with a
-- player at the content's level and once with a player who outgears it, the owner's case.
-- Also the M7 review's low findings on the same reads: the combat flags and the LOOT_ITEM*
-- strings through Compat, raid1 aliased to you, you online in a raid, LFR's instance chat.
-- Every scenario runs once in each layout (compact spec §5, DW-C5): the full table, with Open in
-- compact view during a run off so the run's auto-open keeps it, and the compact cards, every piece
-- of every card saying something.

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

-- Item levels per difficulty in the journal the cases seed.
local LEVEL = { [1] = 580, [2] = 590, [23] = 600, [8] = 610, [17] = 590, [14] = 600, [15] = 610, [16] = 620 }

-- Two dungeons of the newest tier, each dropping two rings at every dungeon difficulty, and a raid
-- dropping two rings at every raid difficulty.
local function seedJournal(m)
    local j = m.journal
    j.tiers = { { dungeons = { { id = 101, name = "Ashen Vault" }, { id = 102, name = "Tidewell" } },
        raids = { { id = 201, name = "The Spire" } } } }
    local function add(inst, d, n)
        local id = inst * 1000 + d * 10 + n
        local l = link(id, LEVEL[d])
        m.addItem(l, ring(LEVEL[d]))
        return { itemID = id, link = l, encounterID = 2000 + n }
    end
    for _, inst in ipairs({ 101, 102 }) do
        j.loot[inst] = {}
        for _, d in ipairs({ 1, 2, 23, 8 }) do j.loot[inst][d] = { add(inst, d, 1), add(inst, d, 2) } end
    end
    j.loot[201] = {}
    for _, d in ipairs({ 17, 14, 15, 16 }) do j.loot[201][d] = { add(201, d, 1), add(201, d, 2) } end
end

-- An enabled addon in the mock's own world: solo, out of an instance, no difficulty, out of
-- combat. The player (a mage) wears two rings at `ilvl`; the journal is seeded.
local function addon(ilvl)
    local NS, _, m = T.enableAddon()
    m.addItem(link(100, ilvl), ring(ilvl))
    m.addItem(link(101, ilvl), ring(ilvl))
    m.inventory.player[11], m.inventory.player[12] = link(100, ilvl), link(101, ilvl)
    m.INVTYPE_FINGER = "Finger"
    seedJournal(m)
    return NS, m
end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function dropEntries(drawn)
    local n = 0
    for _, e in ipairs(drawn and drawn.entries or {}) do
        if e.kind == "drop" then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------------------------
-- Every read the simulator answers goes through the seam
-- ---------------------------------------------------------------------------------------------

-- The client reads a simulation must answer (spec §0 step 2): the situation inputs, the group and
-- its units, the instance and its difficulty, and combat; and, in the engine's modules, the
-- GlobalStrings (`_G`: the settings panel's frames are read there too, never a simulated answer).
local WORLD_READS = { "IsInInstance", "GetInstanceInfo", "GetDifficultyInfo", "C_ChallengeMode", "IsInGroup",
    "IsInRaid", "GetNumGroupMembers", "LE_PARTY_CATEGORY_%u+", "UnitName", "UnitGUID", "UnitClass",
    "UnitIsConnected", "InCombatLockdown", "UnitAffectingCombat" }

-- The seam's own files, and the two that read GlobalStrings once at load, before any simulation.
local SKIPPED = { ["core/Compat.lua"] = true, ["core/CompatWorld.lua"] = true, ["core/CompatItem.lua"] = true,
    ["core/Constants.lua"] = true, ["core/ItemSetup.lua"] = true }

-- A file's code with its comments and strings blanked, so a member key or a GlobalString's name
-- never reads as a call.
local function code(rel)
    local fh = assert(io.open(T.root .. "/" .. rel, "rb"))
    local src = fh:read("*a"); fh:close()
    src = src:gsub("%-%-%[%[.-%]%]", ""):gsub("%-%-[^\r\n]*", "")
    return (src:gsub('"[^"\r\n]*"', '""'):gsub("'[^'\r\n]*'", "''"))
end

local function scanned(rel)
    if SKIPPED[rel] then return false end
    return rel:find("^modules/") ~= nil or rel:find("^settings/") ~= nil or rel:find("^core/") ~= nil
end

test("sim e2e: no module reads the world the simulator answers except through NS.Compat", function()
    for _, rel in ipairs(T.loadAddon.tocFiles) do
        if scanned(rel) then
            local src = code(rel)
            for _, api in ipairs(WORLD_READS) do
                -- red under: the M7 SimEvents, which read InCombatLockdown itself
                assertNil(src:find("[^%w_.:]" .. api .. "%f[^%w_]"), rel .. " reads " .. api .. " outside NS.Compat")
            end
            if rel:find("^modules/") then
                -- red under: the M7 SimEvents, which wrote its loot lines from _G's LOOT_ITEM*
                assertNil(src:find("[^%w_.:]_G%f[^%w_]"), rel .. " reads _G outside NS.Compat")
            end
        end
    end
end)

test("sim e2e: the seam wraps every world read, the combat flags and the GlobalStrings", function()
    local NS = T.newAddon()
    local wrapped = {}
    for _, key in ipairs(NS.Sim.SeamKeys()) do wrapped[key] = true end
    for _, key in ipairs({ "GroupSize", "InRaid", "InGroup", "UnitGUID", "UnitName", "UnitClass", "UnitIsConnected",
        "InstanceState", "InstanceInfo", "DifficultyKnown", "ChallengeModeActive", "InCombatLockdown", "PlayerInCombat",
        "GlobalString" }) do
        assertTrue(wrapped[key], key .. " is answered through the seam")
    end
end)

-- ---------------------------------------------------------------------------------------------
-- Every scenario fills the window under the default filters
-- ---------------------------------------------------------------------------------------------

local SCENARIOS = {
    { name = "key",     situation = "Mythic+",          members = 4 },
    { name = "dungeon", situation = "Dungeon",          members = 4 },
    { name = "raid",    situation = "Raid",             members = 12, size = 12 },
    { name = "lfr",     situation = "Raid Finder",      members = 10, size = 10 },
    { name = "delve",   situation = "Delve",            members = 4 },
    { name = "world",   situation = "Open world group", members = 4 },
}

-- The mock answers the real solo world (spec §0 step 1), as the client did for the owner.
local function assertSoloWorld(NS)
    local Compat = NS.Compat
    assertFalse(Compat.InGroup()); assertFalse(Compat.InRaid()); assertEqual(Compat.GroupSize(), 0)
    assertFalse((Compat.InstanceState()))
    local _, _, difficulty = Compat.InstanceInfo()
    assertEqual(difficulty, 0)
    assertNil(Compat.UnitGUID("party1"))
    assertEqual(NS.Situations.Current(), "solo")
end

-- The window's filters are the defaults: View All, Character Current, Content This instance,
-- Quality Rare+.
local function assertDefaultFilters(NS)
    local FB = NS.WindowFilterBar
    for _, tab in ipairs({ "group", "mine", "history" }) do
        local st = FB.State(tab)
        assertEqual(next(st.view), nil, "View: All"); assertEqual(st.content, "instance")
        assertEqual(st.search, "")
        assertTrue(st.char["Testchar-Testrealm"] == true and next(st.char, next(st.char)) == nil,
            "Character: Current (feedback-2 spec §4)")
    end
    local mode, threshold = FB.QualityReadout()
    assertEqual(mode, "fixed"); assertEqual(threshold, 3)
end

local function assertDrops(NS, label)
    local st = NS.LootFeed.Stats()
    assertTrue(st.group > 0, label .. ": the group's drops are in the feed")
    assertTrue(st.mine > 0, label .. ": your drops are in the feed")
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        assertTrue(rec.sim, label .. ": every drop is the simulation's")
        assertTrue(rec.me ~= nil and rec.me.verdict ~= nil, label .. ": your verdict on drop " .. rec.id)
        if not rec.isMine then
            assertTrue(rec.them ~= nil and rec.them.verdict ~= nil, label .. ": the looter's verdict on drop " .. rec.id)
        end
    end
end

local function assertFooter(NS, sc, label)
    local seg = NS.WindowFooter.Compose(NS.WindowFooter.Read())
    assertEqual(seg.situation.text, ("Simulating: %s · %d members"):format(sc.situation, sc.members), label)
    assertEqual(seg.inspect.text, ("Inspect %d/%d fresh"):format(sc.members, sc.members), label)
end

-- The pieces every compact card fills, per tab (modules/CompactGroup.lua, CompactMine.lua).
local CARD_PIECES = {
    group = { "item", "ilvl", "looter", "slot", "trade", "fresh", "you", "them" },
    mine  = { "item", "ilvl", "forYouLabel", "forYou", "trade", "candidates" },
}

-- Each drawn row is a card in the compact layout, a table row in the full one; a card leaves no
-- piece blank.
local function assertLayout(drawn, tab, mode, label)
    assertTrue((drawn.compact == true) == (mode == "compact"), label .. ": " .. tab .. " is drawn " .. mode)
    if mode ~= "compact" then return end
    assertTrue(#drawn.rows > 0, label .. ": " .. tab .. " shows cards")
    for _, card in ipairs(drawn.rows) do
        for _, key in ipairs(CARD_PIECES[tab]) do
            local t = card.cells[key].text:GetText()
            assertTrue(t ~= nil and t ~= "", ("%s: %s card %s %s"):format(label, tab, tostring(card.dropId), key))
        end
    end
end

local function assertWindow(NS, mode, label)
    local W = NS.Window
    assertTrue(W.IsShown(), label .. ": the window opened")
    assertEqual(NS.WindowCompact.Mode(), mode, label .. ": the layout")
    W.SelectTab("group")
    W.Refresh()
    -- red under: the M7 roster, which dressed the group around you, so content you outgear left
    -- the members naked and nothing Interesting (the owner's empty window)
    local group = NS.WindowGroup.Drawn()
    assertTrue(dropEntries(group) > 0, label .. ": Group drops shows rows")
    assertLayout(group, "group", mode, label)
    W.SelectTab("mine")
    W.Refresh()
    local mine = NS.WindowMine.Drawn()
    assertTrue(mine ~= nil and #mine.entries > 0, label .. ": My drops shows your drops")
    assertLayout(mine, "mine", mode, label)
end

-- Every group the run made names the whole simulated group, you first, and its History group (the
-- simulation's own log) keeps the same roster (feedback-2 spec §3).
local function assertRosters(NS, label)
    local n = NS.Roster.Count()
    assertTrue(n > 1, label .. ": the simulated group is drawn")
    for _, g in ipairs(NS.LootFeed.Groups("live")) do
        assertEqual(#(g.roster or {}), n, label .. ": group " .. g.key .. " names the whole group")
        assertTrue(g.roster[1].me == true, label .. ": you first in " .. g.key)
    end
    local kept = NS.History.Log().groups
    assertTrue(#kept > 0, label .. ": the run is in the simulation's history")
    for _, g in ipairs(kept) do
        assertEqual(#(g.roster or {}), n, label .. ": history group " .. g.key .. " keeps the roster")
    end
end

-- Every simulated drop, and its entry in the simulation's history, is seen by you, the real player
-- (the simulator never answers for "player"), so Character: Current shows the run on every tab
-- (feedback-2 spec §4).
local function assertRecorder(NS, label)
    local me = "Testchar-Testrealm"
    for _, rec in ipairs(NS.LootFeed.Drops("live")) do
        assertEqual(rec.seenBy, me, label .. ": drop " .. rec.id .. " says who saw it")
    end
    for _, g in ipairs(NS.History.Log().groups) do
        for _, e in ipairs(g.drops) do assertEqual(e.seenBy, me, label .. ": its history entry too") end
    end
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    assertTrue(#NS.WindowHistory.Drawn().headers > 0, label .. ": History shows the run under Current")
end

-- The History footer says how long the run is kept (feedback-2 spec §5), and a shorter window
-- deletes nothing of a run that has just happened, so it asks nothing.
local function assertRetention(NS, m, label)
    NS.Window.SelectTab("history")
    NS.Window.Refresh()
    local text = NS.WindowHistory.Drawn().strip.info:GetText()
    assertTrue(text:find("^%d+ groups, %d+ drops · kept for 30 days$") ~= nil, label .. ": " .. text)
    local groups, asked = #NS.History.Log().groups, #m.popupsShown
    assertTrue(NS.SchemaRuntime.Set("global.history.retentionDays", 7), label)
    assertEqual(#m.popupsShown, asked, label .. ": nothing to delete, nothing asked")
    assertEqual(#NS.History.Log().groups, groups, label .. ": the run is kept")
    assertTrue(NS.SchemaRuntime.Set("global.history.retentionDays", 30), label)
end

-- The layout a run is drawn in: compact as stored, or full with the run override off (else the
-- run's auto-open would open it compact, compact spec §1).
local function setLayout(NS, mode)
    if mode == "full" then assertTrue(NS.SchemaRuntime.Set("window.compactInRuns", false)) end
    NS.SetWindowMode(mode)
end

local function runScenario(sc, ilvl, seed, mode)
    local label = ("%s at %d, seed %d, %s"):format(sc.name, ilvl, seed, mode)
    local NS, m = addon(ilvl)
    setLayout(NS, mode)
    assertSoloWorld(NS)
    assertTrue(NS.SimScenario.Start(sc.name, sc.size, { seed = seed }), label)
    assertDefaultFilters(NS)
    assertTrue(NS.SimScenario.Run(), label)
    local st = NS.SimScenario.Status()
    m.advance(NS.SimScenario.STEP_DELAY * st.steps + 30)
    st = NS.SimScenario.Status()
    assertEqual(st.pos, st.steps, label .. ": the timeline played")
    for i = 1, st.steps do
        assertEqual(printed(m, ("Simulation step %d of %d: "):format(i, st.steps)), 1, label .. ": step " .. i .. "'s line")
    end
    assertDrops(NS, label)
    assertFooter(NS, sc, label)
    assertWindow(NS, mode, label)
    assertRosters(NS, label)
    assertRecorder(NS, label)
    assertRetention(NS, m, label)
    NS.Sim.Stop("stop")
    assertEqual(NS.Situations.Current(), "solo", label .. ": the real world again")
end

for _, mode in ipairs({ "full", "compact" }) do
    for _, sc in ipairs(SCENARIOS) do
        test(("sim e2e %s, %s: a run fills Group drops and My drops under the default filters"):format(sc.name, mode),
            function()
                for _, ilvl in ipairs({ 600, 660 }) do
                    for seed = 1, 3 do runScenario(sc, ilvl, seed, mode) end
                end
            end)
    end
end

-- With the defaults (the full layout stored, Open in compact view during a run on): the simulation
-- opens the window itself when its group forms, a player's open, so in the stored layout; closed,
-- a simulated key's drop auto-opens it compact, or full with the option off; and stopping the
-- simulation lets the override go once the window is hidden (compact spec §1 and §5).
local function closeWindow(NS)
    NS.HideWindow()
    local f = NS.Window.Frame()
    f:GetScript("OnHide")(f)
end

test("sim e2e: a simulated key's auto-open is compact by default, full with the option off, then the stored layout", function()
    for _, case in ipairs({ { "key", "compact", true }, { "key", "full", false } }) do
        local NS, m = addon(600)
        assertTrue(NS.SchemaRuntime.Set("window.compactInRuns", case[3]) or case[3], "the option")
        assertTrue(NS.SimScenario.Start(case[1], nil, { seed = 1 }), case[1])
        assertTrue(NS.Window.IsShown(), case[1] .. ": the simulation opened the window")
        assertEqual(NS.WindowCompact.Mode(), "full", case[1] .. ": its own open is the stored layout")
        closeWindow(NS)
        assertTrue(NS.SimScenario.Run(), case[1])
        m.advance(NS.SimScenario.STEP_DELAY * NS.SimScenario.Status().steps + 30)
        assertTrue(NS.Window.IsShown(), case[1] .. ": a drop opened it again")
        assertEqual(NS.WindowCompact.Mode(), case[2], case[1] .. ": the auto-open's layout")
        assertEqual(NS.WindowGroup.Drawn().compact == true, case[2] == "compact", case[1] .. ": cards or the table")
        NS.Sim.Stop("stop")
        closeWindow(NS)
        assertTrue(not NS.WindowCompact.InRun(), case[1] .. ": the override let go")
        NS.ShowWindow()
        assertEqual(NS.WindowCompact.Mode(), "full", case[1] .. ": the stored layout again")
        assertEqual(NS.Setting("window.mode"), "full", case[1] .. ": never written")
    end
end)

-- ---------------------------------------------------------------------------------------------
-- The M7 review's low findings on the same reads
-- ---------------------------------------------------------------------------------------------

test("sim e2e: the combat flags answer the simulated fight, and the client's again after it", function()
    local NS, m = addon(600)
    NS.SimScenario.Start("dungeon", nil, { seed = 1 })
    local Compat = NS.Compat
    assertFalse(Compat.InCombatLockdown()); assertFalse(Compat.PlayerInCombat())
    NS.SimEvents.Pull()
    assertTrue(Compat.InCombatLockdown(), "the simulated pull is a fight")
    assertTrue(Compat.PlayerInCombat())
    assertFalse(NS.Sim.Live(Compat.InCombatLockdown), "the real world is not fighting")
    NS.SimEvents.Kill()
    assertFalse(Compat.InCombatLockdown())
    m.inCombat = true
    assertTrue(Compat.InCombatLockdown(), "real combat is never hidden")
    m.inCombat = false
    NS.SimEvents.Pull()
    NS.Sim.Stop("stop")
    assertFalse(Compat.InCombatLockdown(), "the stop ends the simulated fight")
end)

test("sim e2e: the loot lines are written from the GlobalStrings Compat reads", function()
    local NS, m = addon(600)
    m.LOOT_ITEM = "%s grabs: %s."
    NS.SimScenario.Start("dungeon", nil, { seed = 1 })
    local member = NS.SimRoster.Get()[1]
    local hits = NS.LootParser.Stats().hits
    assertEqual(NS.SimEvents.Loot(1, member.name), 1)
    assertTrue(NS.LootParser.Stats().hits > hits, "the parser read the line the client's string wrote")
    local got = NS.LootFeed.Drops("live")
    assertEqual(#got, 1)
    assertEqual(got[1].looter.guid, member.guid)
end)

test("sim e2e: in a raid, raid1 is you, online, for every unit read", function()
    local NS = addon(600)
    NS.SimScenario.Start("raid", 10, { seed = 1 })
    local Compat = NS.Compat
    local guid = NS.Sim.Live(Compat.UnitGUID, "player")
    assertEqual(Compat.UnitGUID("raid1"), guid)
    assertEqual(Compat.UnitName("raid1"), NS.Sim.Live(Compat.UnitName, "player"))
    -- red under: the M7 provider, which asked the client about raid1 and read you offline
    assertTrue(Compat.UnitIsConnected("raid1") == true, "you are online")
    local me = NS.Roster.Player()
    assertTrue(me ~= nil and me.online ~= false, "the roster has you online")
    assertEqual(Compat.InventoryItemLink("raid1", 11), Compat.InventoryItemLink("player", 11))
end)

test("sim e2e: Raid Finder is an instance group, so asks announce in instance chat", function()
    local NS = addon(600)
    NS.SimScenario.Start("lfr", 10, { seed = 1 })
    local Compat = NS.Compat
    assertTrue(Compat.InGroup()); assertTrue(Compat.InGroup(Compat.InstanceGroupCategory()))
    assertFalse(Compat.InGroup(1), "not a home group")
    -- red under: the M7 provider, which answered every matchmade group as a home group
    assertEqual(NS.Asks.AnnounceChannel(), "INSTANCE_CHAT")
    NS.Sim.Stop("stop")
    NS.SimScenario.Start("raid", 10, { seed = 1 })
    assertFalse(Compat.InGroup(Compat.InstanceGroupCategory()))
    assertEqual(NS.Asks.AnnounceChannel(), "RAID")
    NS.Sim.Stop("stop")
    NS.SimScenario.Start("key", nil, { seed = 1 })
    assertEqual(NS.Asks.AnnounceChannel(), "PARTY")
end)
