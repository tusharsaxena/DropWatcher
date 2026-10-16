-- tests/test_diagnostics.lua — the addon's own sections of the diagnostics report
-- (debug-logging-§14). The contract around them (both forms, append, the run turning logging on,
-- the markers, no alias) is the kit's test_diagnostics_contract.lua, run against this dispatcher.

local T = _G.DW_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function report(NS)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    return table.concat(NS.DebugLog.buffer, "\n")
end

test("diagnostics: the sections are the addon's, in report order", function()
    local NS = T.newAddon()
    local names = {}
    for i, s in ipairs(NS.Diagnostics.Sections()) do names[i] = s[1] end
    assertEqual(table.concat(names, ","), "identity,state,settings,window,situation,restrictions,roster,inspect,gear,feed,drops,trade,scoring,messaging,sim,registration,integrations")
end)

test("diagnostics: the report names the schema, the profile, the holds and the window decision", function()
    local NS = T.enableAddon()
    NS.ShowWindow()
    local text = report(NS)
    assertTrue(text:find(("schema stored=%d code=%d"):format(NS.SCHEMA_VERSION, NS.SCHEMA_VERSION), 1, true) ~= nil, "identity")
    assertTrue(text:find("profile=", 1, true) ~= nil)
    assertTrue(text:find("window: built=true shown=true shouldShow=true", 1, true) ~= nil, "window")
    assertTrue(text:find("window: tab=group minimized=false new=0", 1, true) ~= nil, "window tab")
    assertTrue(text:find("PLAYER_REGEN_DISABLED", 1, true) ~= nil, "registration")
end)

test("diagnostics: the situation section names the key, its settings and the inputs", function()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    local text = report(NS)
    assertTrue(text:find("situation: dungeon (last announced dungeon) track=true autoOpen=true quality=global", 1, true) ~= nil, text)
    assertTrue(text:find("situation inputs: inInstance=true type=party difficulty=2 challengeMode=false", 1, true) ~= nil)
end)

test("diagnostics: it runs while stood down and says so, without acting", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    local text = report(NS)
    assertTrue(text:find("stoodDown=true", 1, true) ~= nil)
    assertTrue(text:find("holds disabled", 1, true) ~= nil, text)
    assertTrue(NS.IsStoodDown(), "the report changed nothing")
end)

test("diagnostics: a non-default setting is listed, and `enabled` always is", function()
    local NS = T.enableAddon()
    NS.SchemaRuntime.Set("scale", 1.5)
    local text = report(NS)
    assertTrue(text:find("scale", 1, true) ~= nil and text:find("1.5", 1, true) ~= nil)
    assertTrue(text:find("enabled", 1, true) ~= nil)
end)

test("diagnostics: the restrictions section names the answers, the reasons and the last announced", function()
    local NS, _, m = T.enableAddon()
    local RT, RS = m.Enum.AddOnRestrictionType, m.Enum.AddOnRestrictionState
    m.restrictionStates[RT.Map] = RS.Active
    m.__fire("ADDON_RESTRICTION_STATE_CHANGED", RT.Encounter, RS.Active)
    local text = report(NS)
    assertTrue(text:find("restrictions: reason=encounter canSendChat=false canInspect=true canTrade=true", 1, true) ~= nil, text)
    assertTrue(text:find("restrictions: active", 1, true) ~= nil)
    assertTrue(text:find("encounter, map", 1, true) ~= nil or text:find("encounter,map", 1, true) ~= nil, text)
    assertTrue(text:find("restrictions: last announced encounter/false/true/true", 1, true) ~= nil, text)
end)

test("diagnostics: the roster section lists the stored members without reading the client", function()
    local NS, _, m = T.enableAddon()
    NS.State.roster = nil
    assertTrue(report(NS):find("roster: not read yet", 1, true) ~= nil)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", classFile = "WARRIOR", connected = false } })
    m.__fire("GROUP_ROSTER_UPDATE")
    local text = report(NS)
    assertTrue(text:find("roster: 2 members", 1, true) ~= nil, text)
    assertTrue(text:find("roster: Brakk-Testrealm unit=party1 class=WARRIOR online=false spec=unknown player=false", 1, true) ~= nil, text)
end)

test("diagnostics: the gear section lists the stored slots without reading the client", function()
    local NS, _, m = T.enableAddon()
    NS.State.gear = nil
    assertTrue(report(NS):find("gear: not read yet", 1, true) ~= nil)
    local HEAD = "|cnIQ4:|Hitem:3001::::::::90:::::|h[Hood]|h|r"
    local RING = "|cnIQ4:|Hitem:3002::::::::90:::::|h[Band]|h|r"
    m.addItem(HEAD, { name = "Hood", quality = 4, ilvl = 610, equipLoc = "INVTYPE_HEAD", classID = 4,
        subClassID = 1, stats = {} })
    m.addItem(RING, { name = "Band", quality = 3, ilvl = 620, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, stats = {} })
    m.inventory.player[1] = HEAD
    m.bags[0] = { size = 1, [1] = RING }
    NS.Gear.Refresh("test")
    local text = report(NS)
    assertTrue(text:find("gear: class=MAGE spec=250 dualWield=false", 1, true) ~= nil, text)
    assertTrue(text:find("gear: HEAD ilvl=610 quality=4", 1, true) ~= nil, text)
    assertTrue(text:find("gear: NECK empty", 1, true) ~= nil, text)
    assertTrue(text:find("gear: FINGER1 empty owned=620", 1, true) ~= nil, text)
end)

test("diagnostics: the feed section counts the parser's lines and names the last loot", function()
    local NS, _, m = T.enableAddon()
    assertTrue(report(NS):find("feed: parser has read no loot line yet", 1, true) ~= nil)
    m.__now = 50
    m.__fire("CHAT_MSG_LOOT", "You receive bonus loot: |cnIQ4:|Hitem:3001::::::::90:::::|h[Hood]|h|r.")
    m.__fire("CHAT_MSG_LOOT", "Changed |Hitem:1|h[a]|h to |Hitem:2|h[b]|h.")
    m.__fire("CHAT_MSG_LOOT", "Someone has selected Need for: |Hitem:1|h[a]|h")
    m.__now = 62
    local text = report(NS)
    assertTrue(text:find("feed: parser hits=1 ignored=1 rejected=1 secret=0", 1, true) ~= nil, text)
    assertTrue(text:find("feed: last loot 12s ago (chat, bonus) by Testchar-Testrealm", 1, true) ~= nil, text)
end)

test("diagnostics: the feed section counts the drops, the hidden ones and the context", function()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 2 }
    end })
    assertTrue(report(NS):find("feed: no drop received yet", 1, true) ~= nil)
    local band = m.addItem("|cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r", { name = "Band", quality = 4,
        ilvl = 600, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, bindType = 1, stats = {} })
    local potion = m.addItem("|cnIQ1:|Hitem:2002::::::::90:::::|h[Potion]|h|r", { name = "Potion",
        quality = 1, ilvl = 1, equipLoc = "", classID = 0, subClassID = 0, stats = {} })
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    NS.LootFeed.Add(band)
    NS.LootFeed.Add(band, "Nobody")
    NS.LootFeed.Add(potion)
    local text = report(NS)
    assertTrue(text:find("feed: drops group=1 mine=1 test=0 groups=1 merged=0 loading=0", 1, true) ~= nil, text)
    assertTrue(text:find("feed: hidden notGear=1", 1, true) ~= nil, text)
    assertTrue(text:find("feed: encounter=Speaker Brokk run=none", 1, true) ~= nil, text)
    assertTrue(text:find("feed: quality mode=fixed threshold=3 (fixed)", 1, true) ~= nil, text)
    NS.addon.db.profile.feed = { quality = { mode = "dynamicSlot" } }
    text = report(NS)
    assertTrue(text:find("feed: quality mode=dynamicSlot thresholds HEAD=2", 1, true) ~= nil, text)
end)

test("diagnostics: the trade section shows the timers, the ticker and each entry", function()
    local NS, _, m = T.enableAddon()
    assertTrue(report(NS):find("trade: no scan yet", 1, true) ~= nil)
    local band = m.addItem("|cnIQ4:|Hitem:2001::::::::90:::::|h[Band]|h|r", { name = "Band", quality = 4,
        ilvl = 1, equipLoc = "INVTYPE_FINGER", classID = 4, subClassID = 0, bindType = 1, stats = {} })
    local id = NS.LootFeed.Add(band)
    m.bags[0] = { size = 1, band }
    m.bagGUIDs["0:1"] = "Item-1-0001"
    m.tooltips.bag["0:1"] = { lines = { { type = 36, leftText = m.BIND_TRADE_TIME_REMAINING:format("1 hour") } } }
    m.advance(0)
    local text = report(NS)
    assertTrue(text:find("trade: timers live=1 expired=0 boe=0 scans=1 ticker=60s", 1, true) ~= nil, text)
    assertTrue(text:find("trade: drop " .. id .. " ", 1, true) ~= nil, text)
    assertTrue(text:find("left=3600s expired=false boe=false warned=false guid=Item-1-0001", 1, true) ~= nil, text)
end)

test("diagnostics: the inspect section shows the queue and each member's entry", function()
    local NS, _, m = T.enableAddon()
    assertTrue(report(NS):find("inspect: nothing asked yet", 1, true) ~= nil)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    NS.Inspect.Request("Player-1-0000000A")
    m.advance(0)
    m.advance(3)
    local text = report(NS)
    assertTrue(text:find("inspect: queued=0 inFlight=Player-1-0000000A parked=false", 1, true) ~= nil, text)
    assertTrue(text:find("inspect: Brakk-Testrealm status=pending reason=none spec=unknown slots=0", 1, true) ~= nil, text)
end)

test("diagnostics: the messaging section counts the registry, the sends and lists each queued ask", function()
    local NS, _, m = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("messaging: asks=0 queued=0 sent=0 failed=0 ready=0", 1, true) ~= nil, text)
    assertTrue(text:find("messaging: template lengths ask=", 1, true) ~= nil, text)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    m.chatLockdown = true
    NS.Asks.Request("ask", "Brakk", 7)
    text = report(NS)
    assertTrue(text:find("messaging: asks=1 queued=1", 1, true) ~= nil, text)
    assertTrue(text:find("messaging: queued ask to Brakk-Testrealm, drop 7", 1, true) ~= nil, text)
end)

test("diagnostics: the state section is one read of enabled, situation, test mode, restriction and queue", function()
    local NS, _, m = T.enableAddon()
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.instance.difficultyID = 2
    m.__fire("PLAYER_ENTERING_WORLD")
    local text = report(NS)
    assertTrue(text:find("state: enabled=true situation=dungeon testMode=false restriction=none queuedSends=0", 1, true) ~= nil, text)
    m.setGroup({ { guid = "Player-1-0000000A", name = "Brakk", class = "Warrior", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    m.chatLockdown = true
    NS.Asks.Request("ask", "Brakk", 7)
    NS.addon:OnSlashCommand("disable")
    text = report(NS)
    assertTrue(text:find("state: enabled=false situation=", 1, true) ~= nil, text)
    assertTrue(text:find("queuedSends=", 1, true) ~= nil, text)
end)

test("diagnostics: the scoring section names the scorer, the one in use, Pawn and the pending retries", function()
    local NS, _, m = T.enableAddon()
    local text = report(NS)
    assertTrue(text:find("scoring: scorer=auto inUse=none", 1, true) ~= nil, text)
    assertTrue(text:find("scoring: pawn ready=false scale=none", 1, true) ~= nil, text)
    assertTrue(text:find("scoring: retries pending=0 spent=0 timer=off", 1, true) ~= nil, text)
    m.PawnIsInitialized = true
    m.PawnFindScaleForSpec = function(classID, specID) return "Scale" .. classID .. ":" .. specID end
    NS.Gear.Refresh("test")
    text = report(NS)
    assertTrue(text:find("scoring: scorer=auto inUse=pawn", 1, true) ~= nil, text)
    assertTrue(text:find("scoring: pawn ready=true scale=Scale8:250", 1, true) ~= nil, text)
    -- Configured Pawn without Pawn: the scorer in use is none, not the one configured.
    m.PawnIsInitialized, m.PawnFindScaleForSpec = nil, nil
    NS.SchemaRuntime.Set("comparison.scorer", "pawn")
    text = report(NS)
    assertTrue(text:find("scoring: scorer=pawn inUse=none", 1, true) ~= nil, text)
    NS.SchemaRuntime.Set("comparison.scorer", "weights")
    NS.SchemaRuntime.Set("comparison.weights", { [250] = { ITEM_MOD_INTELLECT_SHORT = 1 } })
    text = report(NS)
    assertTrue(text:find("scoring: scorer=weights inUse=weights", 1, true) ~= nil, text)
end)
