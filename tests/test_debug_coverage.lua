-- tests/test_debug_coverage.lua — what the debug log and the diagnostics report carry
-- (debug-logging-§8, §9, §14). A drop's line names its item level and where it came from, and its
-- trade estimate with the reason; a re-judged drop says what it reads now. The encounter and the
-- keystone run edges are logged, and so is each hold and its release: auto-ask's waiting asks over
-- an encounter, the inspect queue and the toast queue over combat. Two repeating paths stay quiet
-- in steady state: the trade timer's bag scan logs on change only, and the search box logs once
-- when it loses focus, never per keystroke. The report's drop lines carry the looter, both
-- verdicts and the trade estimate; the waiting toasts and auto-asks are listed.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

local BRAKK = "Player-1-0000000A"

local function link(id, name)
    return ("|cffa335ee|Hitem:%d::::::::90:::::|h[%s]|h|r"):format(id, name or ("Item " .. id))
end

local function def(equipLoc, ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
end

-- The lines logged under `tag` (every tag when nil) since logging was turned on.
local function logged(NS, tag)
    local out = {}
    for _, l in ipairs(NS.DebugLog.buffer) do
        if not tag or l:find("[" .. tag .. "]", 1, true) then out[#out + 1] = l end
    end
    return out
end

local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do
        if l:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function joined(lines) return table.concat(lines, "\n") end

-- An enabled instance in a Mythic+ dungeon with Brakk, logging on.
local function dungeon(seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "party"
        m.instance = { name = "The Rookery", difficultyID = 8 }
        if seed then seed(m) end
    end })
    m.addItem(link(100), def("INVTYPE_FINGER", 600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(100)
    m.setGroup({ { guid = BRAKK, name = "Brakk", realm = "Thrall", class = "WARRIOR", classFile = "WARRIOR" } })
    NS.Roster.Refresh("test")
    NS.State.debug = true
    NS.DebugLog:Clear()
    return NS, m
end

local function loot(m, text)
    return m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

test("debug: a drop added names its item level and source, and its trade estimate with the reason", function()
    local NS, m = dungeon()
    m.addItem(link(200, "Band of Brakk"), def("INVTYPE_FINGER", 610))
    loot(m, "Brakk-Thrall receives loot: " .. link(200, "Band of Brakk") .. ".")
    m.advance(0)
    local feed = logged(NS, "FEED")
    local line
    for _, l in ipairs(feed) do
        if l:find("[Band of Brakk]", 1, true) and l:find("me=", 1, true) then line = l end
    end
    assertTrue(line ~= nil, joined(feed))
    assertTrue(line:find("ilvl 610 (", 1, true) ~= nil, line)
    assertTrue(line:find("trade=%a+/%a+") ~= nil or line:find("trade=%a+$") ~= nil, line)
end)

test("debug: the encounter and the keystone run edges each write one FEED line", function()
    local NS, m = dungeon(function(m) m.challengeMaps[505] = "The Rookery+" end)
    m.__fire("CHALLENGE_MODE_START", 505)
    m.__fire("ENCOUNTER_START", 2902, "Kyrioss", 8, 5)
    m.__fire("ENCOUNTER_END", 2902, "Kyrioss", 8, 5, 0)
    m.__fire("ENCOUNTER_START", 2902, "Kyrioss", 8, 5)
    m.__fire("ENCOUNTER_END", 2902, "Kyrioss", 8, 5, 1)
    m.__fire("CHALLENGE_MODE_COMPLETED")
    local feed = logged(NS, "FEED")
    assertEqual(count(feed, "keystone run started: The Rookery+"), 1, joined(feed))
    assertEqual(count(feed, "encounter 2902 started"), 2, joined(feed))
    assertEqual(count(feed, "encounter 2902 ended: wipe"), 1, joined(feed))
    assertEqual(count(feed, "encounter 2902 ended: kill"), 1, joined(feed))
    assertEqual(count(feed, "keystone run completed: The Rookery+"), 1, joined(feed))
end)

test("debug: a drop re-judged on new facts says what it reads now", function()
    local NS, m = dungeon()
    local l = link(201, "Wraps")
    m.addItem(l, def("INVTYPE_WRIST", 298))
    loot(m, "Brakk-Thrall receives loot: " .. l .. ".")
    m.advance(0)
    local rec = NS.LootFeed.Drops()[1]
    NS.LootFeed.Refresh(rec, "source")
    m.advance(0)
    local eval = logged(NS, "EVAL")
    assertEqual(count(eval, "drop " .. tostring(rec.id) .. " re-judged (source): ilvl 298 ("), 1, joined(eval))
end)

test("debug: the inspect queue logs its park and resume over combat, only with jobs waiting", function()
    local NS, m = dungeon()
    m.__fire("PLAYER_REGEN_DISABLED")
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(count(logged(NS, "INSPECT"), "queue "), 0, "an empty queue writes nothing")
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.Inspect.Scan("test")
    m.__fire("PLAYER_REGEN_ENABLED")
    local lines = logged(NS, "INSPECT")
    assertEqual(count(lines, "queue resumed after combat: 1 waiting"), 1, joined(lines))
end)

-- An auto-ask party (test_auto_ask's shape): Brakk's drop is an upgrade for you, likely tradeable.
local function party()
    local NS, m = dungeon()
    local byId = {}
    NS.LootFeed.Get = function(id) return byId[id] end
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    byId[1] = { id = 1, link = link(500), itemID = 500, isMine = false, at = m.GetTime(),
        looter = { name = "Brakk", guid = BRAKK, classFile = "WARRIOR" },
        facts = { ilvl = 311, equipLoc = "INVTYPE_HEAD", quality = 4 },
        me = { verdict = "upgrade", ilvlDelta = 12 },
        trade = { state = "likely", reasonKey = "notUpgrade", args = {} } }
    return NS, m
end

test("debug: auto-ask's waiting asks are held for an encounter and released at its end, each one line", function()
    local NS, m = party()
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    m.__fire("ENCOUNTER_START", 2902, "Kyrioss", 8, 5)
    m.__fire("ENCOUNTER_END", 2902, "Kyrioss", 8, 5, 1)
    local msg = logged(NS, "MSG")
    assertEqual(count(msg, "auto-ask: 1 waiting held for the encounter"), 1, joined(msg))
    assertEqual(count(msg, "auto-ask: the encounter is over, 1 waiting are due"), 1, joined(msg))
end)

test("diagnostics: an auto-ask waiting is listed with its looter and when it is due", function()
    local NS = party()
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = joined(NS.DebugLog.buffer)
    assertTrue(text:find("auto-ask: waiting drop 1 to Brakk", 1, true) ~= nil, text)
    assertTrue(text:find("due=10s offSpec=false", 1, true) ~= nil, text)
end)

test("debug: the toast queue held over combat says so when combat ends", function()
    local NS, m = party()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    local ui = logged(NS, "UI")
    assertEqual(count(ui, "toast: combat over, 1 waiting"), 1, joined(ui))
    assertEqual(count(ui, "toast shown: drop 1"), 1, joined(ui))
end)

test("diagnostics: the toast queue is listed while toasts wait", function()
    local NS, m = party()
    assertTrue(NS.SchemaRuntime.Set("toast.enabled", true))
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    NS.addon:SendMessage(NS.MSG.DROP_ADDED, 1)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = joined(NS.DebugLog.buffer)
    assertTrue(text:find("toast: queue 1", 1, true) ~= nil, text)
end)

test("diagnostics: each drop line names its looter, both verdicts and the trade estimate", function()
    local NS, m = dungeon()
    m.addItem(link(202, "Cord"), def("INVTYPE_FINGER", 610))
    loot(m, "Brakk-Thrall receives loot: " .. link(202, "Cord") .. ".")
    m.advance(0)
    local rec = NS.LootFeed.Drops()[1]
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = joined(NS.DebugLog.buffer)
    local want = ("drops: %s looter=Brakk-Thrall me=%s"):format(tostring(rec.id), tostring(rec.me.verdict))
    assertTrue(text:find(want, 1, true) ~= nil, text)
    assertTrue(text:find(("trade=%s (%s)"):format(tostring(rec.trade.state), tostring(rec.trade.reasonKey or "none")),
        1, true) ~= nil, text)
end)

test("debug: the trade timer's bag scan logs on change only, not on every scan", function()
    local NS, m = dungeon()
    m.bags[0] = { size = 4 }
    local l = link(300)
    m.addItem(l, def("INVTYPE_FINGER", 590))
    NS.LootFeed.Add(l)
    m.advance(0)
    for _ = 1, 5 do NS.TradeTimer.Scan("BAG_UPDATE_DELAYED") end
    local trade = logged(NS, "TRADE")
    assertEqual(count(trade, "scan: 1 own drops"), 1, joined(trade))
end)

test("debug: the search box logs its text once, when it loses focus, never per keystroke", function()
    local NS = dungeon()
    NS.ShowWindow()
    local eb = NS.WindowFilterBar.Controls().search
    for _, text in ipairs({ "b", "br", "bra" }) do
        eb:SetText(text)
        eb:GetScript("OnTextChanged")(eb)
    end
    assertEqual(count(logged(NS, "UI"), ".search"), 0, "no line per keystroke")
    eb:GetScript("OnEditFocusLost")(eb)
    eb:GetScript("OnEditFocusLost")(eb)
    local ui = logged(NS, "UI")
    assertEqual(count(ui, 'filter group.search = "bra"'), 1, joined(ui))
    assertFalse(NS.WindowFilterBar.State("group").search ~= "bra")
end)
