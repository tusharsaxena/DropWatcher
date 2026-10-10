-- tests/test_feed.lua — modules/LootFeed.lua (design spec §3, §5.3, §6): the three sources
-- (CHAT_MSG_LOOT, ENCOUNTER_LOOT_RECEIVED, C_LootHistory) and their dedupe, the encounter and
-- keystone-run grouping, the gate order (situation, filters, the verdict for you, the quality gate,
-- then the inspect request, the looter's verdict and the trade estimate), your own drops and their
-- candidates, the item load, DropAdded and DropUpdated (inspect, gear, source, score), Add, the
-- test feed, the cap, secrets and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK, LYRA = "Player-1-0000000A", "Player-2-0000000B"
local ME = "Player-1-00000001"

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function def(equipLoc, ilvl, extra)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = 4, subClassID = 0,
        bindType = 1, stats = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

local function ring(ilvl, extra) return def("INVTYPE_FINGER", ilvl, extra) end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- Inside a Heroic dungeon (a tracked situation), unless the seed says otherwise.
local function dungeon(m)
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.instance = { name = "The Rookery", difficultyID = 2 }
end

-- An enabled instance in a party in a dungeon: the player wears two 600 rings; Brakk (party1, a
-- warrior on the player's realm) and Lyra (party2, a priest from Area 52) are in the group.
local function party(seed)
    local NS, _, m = T.enableAddon({ mock = function(m)
        dungeon(m)
        if seed then seed(m) end
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    NS.Roster.Refresh("test")    -- read directly, so no inspect warm-up is armed
    return NS, m, NS.LootFeed
end

-- What Brakk wears, as the client holds it once inspected (the fast path reads it at once: the
-- neck, both rings and both trinkets are held, which only inspect data shows).
local function brakkWears(m, ilvl)
    m.addItem(link(200), ring(ilvl))
    m.addItem(link(201), ring(ilvl))
    m.addItem(link(202), def("INVTYPE_NECK", ilvl))
    m.addItem(link(203), def("INVTYPE_TRINKET", ilvl))
    m.addItem(link(204), def("INVTYPE_TRINKET", ilvl))
    m.inventory.party1 = { [2] = link(202), [11] = link(200), [12] = link(201), [13] = link(203),
        [14] = link(204) }
end

-- Every DropAdded and DropUpdated, in order, on a receiver of its own.
local function listen(NS)
    local seen = { added = {}, updated = {} }
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.DROP_ADDED, function(_, id) seen.added[#seen.added + 1] = id end)
    target:RegisterMessage(NS.MSG.DROP_UPDATED, function(_, id, cause)
        seen.updated[#seen.updated + 1] = id .. ":" .. tostring(cause)
    end)
    return seen
end

local function chat(m, text)
    return m.__fire("CHAT_MSG_LOOT", text, "", "", "", "", "", 0, 0, "", 0, 1, nil)
end

local function brakkLoots(m, id) chat(m, "Brakk receives loot: " .. link(id) .. ".") end

local function encounterLoot(m, encounterID, id, name, classFile)
    m.__fire("ENCOUNTER_LOOT_RECEIVED", encounterID, id, link(id), 1, name, classFile)
end

local function only(LF)
    local drops = LF.Drops()
    assertEqual(#drops, 1, "one drop")
    return drops[1]
end

local function sources(rec)
    local out = {}
    for k in pairs(rec.sources) do out[#out + 1] = k end
    table.sort(out)
    return table.concat(out, ",")
end

local function installSecrets(m)
    m.issecretvalue = T.isSecret
    m.canaccessvalue = function(v) return not T.isSecret(v) end
end

-- ---------------------------------------------------------------------------------------------
-- One group drop, end to end
-- ---------------------------------------------------------------------------------------------

test("feed: a member's loot is added once, judged for you, and asks for the looter's inspect", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    brakkLoots(m, 300)
    local rec = only(LF)
    assertEqual(table.concat(seen.added, ","), tostring(rec.id))
    assertEqual(rec.looter.guid, BRAKK); assertEqual(rec.looter.name, "Brakk-Testrealm")
    assertFalse(rec.isMine); assertEqual(rec.source, "chat"); assertEqual(rec.situation, "dungeon")
    assertEqual(rec.me.verdict, "upgrade", "620 against your 600 ring")
    assertEqual(rec.quality.reason, "atThreshold")
    assertNil(rec.them, "no inspect read yet")
    assertEqual(rec.inspect.status, "pending")
    assertEqual(rec.trade.state, "unknown"); assertEqual(rec.trade.reasonKey, "noInspect")
    assertEqual(NS.Inspect.QueueState().queued, 1, "the looter queued at looter priority")
end)

test("feed: the looter's inspect re-judges the drop: their verdict and the trade estimate", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    brakkLoots(m, 300)
    brakkWears(m, 630)
    m.advance(0)    -- the fast path: every link readable without an inspect
    local rec = only(LF)
    assertEqual(NS.Inspect.Get(BRAKK).status, "cached")
    assertEqual(rec.them.verdict, "downgrade", "620 against Brakk's 630")
    assertEqual(rec.inspect.status, "cached")
    assertEqual(rec.trade.state, "likely"); assertEqual(rec.trade.reasonKey, "notUpgrade")
    assertEqual(table.concat(seen.updated, ","), rec.id .. ":inspect")
end)

test("feed: an upgrade for the looter cannot be traded under the personal rule", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    brakkWears(m, 590)
    brakkLoots(m, 300)
    m.advance(0)
    local rec = only(LF)
    assertEqual(rec.them.verdict, "upgrade")
    assertEqual(rec.trade.state, "no"); assertEqual(rec.trade.reasonKey, "upgradeForLooter")
end)

test("feed: a bonus roll is never tradeable", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    chat(m, "Brakk receives bonus loot: " .. link(300) .. ".")
    local rec = only(LF)
    assertTrue(rec.bonusRoll); assertEqual(rec.kind, "bonus")
    assertEqual(rec.trade.reasonKey, "bonusRoll")
end)

-- ---------------------------------------------------------------------------------------------
-- Dedupe across the three sources
-- ---------------------------------------------------------------------------------------------

test("dedupe: chat, the encounter loot event and the loot history report one drop", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    brakkLoots(m, 300)
    encounterLoot(m, 2900, 300, "Brakk", "WARRIOR")
    m.lootHistory["2900:1"] = { itemHyperlink = link(300), winner = { playerName = "Brakk",
        playerGUID = BRAKK, playerClass = "WARRIOR", isSelf = false } }
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 1)
    local rec = only(LF)
    assertEqual(sources(rec), "chat,encounter,history")
    assertEqual(#seen.added, 1, "DropAdded once")
    assertEqual(table.concat(seen.updated, ","), rec.id .. ":source," .. rec.id .. ":source")
    assertEqual(LF.Stats().merged, 2)
end)

test("dedupe: the encounter event first, chat second, merges the same way", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    encounterLoot(m, 2900, 300, "Brakk", "WARRIOR")
    brakkLoots(m, 300)
    local rec = only(LF)
    assertEqual(rec.source, "encounter"); assertEqual(sources(rec), "chat,encounter")
    assertEqual(rec.encounterID, 2900)
end)

test("dedupe: a looter the roster cannot place is matched by name without the realm", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    chat(m, "Stranger-Otherrealm receives loot: " .. link(300) .. ".")
    encounterLoot(m, 2900, 300, "stranger", "MAGE")
    local rec = only(LF)
    assertEqual(sources(rec), "chat,encounter")
    assertEqual(rec.inspect.status, "unavailable"); assertEqual(rec.inspect.reason, "notInGroup")
end)

test("dedupe: a GUID learned from a second source asks for the looter's inspect", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:4"] = { itemHyperlink = link(300), winner = { playerName = "Stranger",
        playerGUID = "Player-9-00000009", playerClass = "MAGE" } }
    chat(m, "Stranger receives loot: " .. link(300) .. ".")
    local rec = only(LF)
    assertNil(rec.looter.guid)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 4)
    assertEqual(rec.looter.guid, "Player-9-00000009")
    assertEqual(rec.inspect.reason, "notInGroup", "still not in the group: nothing to inspect")
    assertEqual(table.concat(seen.updated, ","), rec.id .. ":source")
    assertEqual(NS.Inspect.QueueState().queued, 0)
end)

test("dedupe: two copies from one source are two drops; another looter's copy is its own", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    brakkLoots(m, 300)
    brakkLoots(m, 300)
    chat(m, "Lyra-Area52 receives loot: " .. link(300) .. ".")
    assertEqual(#LF.Drops(), 3)
end)

test("dedupe: a report after the window is a new drop", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    brakkLoots(m, 300)
    m.advance(LF.DEDUPE_WINDOW + 1)
    encounterLoot(m, 2900, 300, "Brakk", "WARRIOR")
    assertEqual(#LF.Drops(), 2)
end)

-- ---------------------------------------------------------------------------------------------
-- The loot history source
-- ---------------------------------------------------------------------------------------------

test("history: a drop is taken once it has a winner, and only once", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 7)
    assertEqual(#LF.Drops(), 0, "no answer: nothing")
    m.lootHistory["2900:7"] = { itemHyperlink = link(300), winner = {} }
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 7)
    assertEqual(#LF.Drops(), 0, "rolls still open: no winner named")
    m.lootHistory["2900:7"].winner = { playerName = "Lyra-Area52", playerGUID = LYRA, playerClass = "PRIEST" }
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 7)
    m.advance(LF.DEDUPE_WINDOW + 1)
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 7)
    local rec = only(LF)
    assertEqual(rec.looter.guid, LYRA); assertEqual(rec.source, "history"); assertEqual(rec.encounterID, 2900)
end)

test("history: your own won drop is yours", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    m.lootHistory["2900:2"] = { itemHyperlink = link(300), winner = { playerName = "Testchar",
        playerGUID = ME, isSelf = true } }
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 2)
    assertTrue(only(LF).isMine)
end)

-- ---------------------------------------------------------------------------------------------
-- Grouping by encounter and run
-- ---------------------------------------------------------------------------------------------

local function labels(LF)
    local out = {}
    for _, g in ipairs(LF.Groups()) do out[#out + 1] = g.kind .. ":" .. g.label .. "=" .. #g.drops end
    return table.concat(out, ",")
end

test("groups: trash, a boss kill's loot window, then trash again", function()
    local _, m, LF = party()
    for id = 300, 305 do m.addItem(link(id), ring(620)) end
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    brakkLoots(m, 302)
    m.__fire("ENCOUNTER_END", 2900, "Speaker Brokk", 2, 5, 1)
    m.advance(LF.LOOT_GRACE - 1)
    brakkLoots(m, 303)
    m.advance(2)
    brakkLoots(m, 304)
    assertEqual(labels(LF), "area:The Rookery=2,encounter:Speaker Brokk=2,area:The Rookery=1")
    assertEqual(LF.Groups()[2].encounterID, 2900)
    assertEqual(LF.Get(LF.Drops()[3].id).groupKey, LF.Groups()[2].key)
end)

test("groups: a wipe opens no loot window", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    m.__fire("ENCOUNTER_END", 2900, "Speaker Brokk", 2, 5, 0)
    brakkLoots(m, 300)
    assertEqual(labels(LF), "area:The Rookery=1")
end)

test("groups: loot naming an earlier encounter joins that encounter's group", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620)); m.addItem(link(301), ring(620))
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    m.__fire("ENCOUNTER_END", 2900, "Speaker Brokk", 2, 5, 1)
    m.advance(LF.LOOT_GRACE + 1)
    encounterLoot(m, 2900, 300, "Brakk", "WARRIOR")
    encounterLoot(m, 3100, 301, "Lyra", "PRIEST")
    assertEqual(labels(LF), "encounter:Speaker Brokk=1,encounter:Encounter 3100=1")
end)

test("groups: a keystone run gathers every drop, the chest after completion included", function()
    local _, m, LF = party(function(m) m.challengeMaps[505] = "The Rookery+" end)
    for id = 300, 303 do m.addItem(link(id), ring(620)) end
    m.__fire("CHALLENGE_MODE_START", 505)
    brakkLoots(m, 300)
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 8, 5)
    m.__fire("ENCOUNTER_END", 2900, "Speaker Brokk", 8, 5, 1)
    brakkLoots(m, 301)
    m.__fire("CHALLENGE_MODE_COMPLETED")
    m.advance(10)
    encounterLoot(m, 0, 302, "Lyra", "PRIEST")    -- the chest (FEED-6 asks what id it carries)
    m.advance(LF.LOOT_GRACE)
    brakkLoots(m, 303)
    assertEqual(labels(LF), "run:The Rookery+=3,area:The Rookery=1")
    assertEqual(LF.Groups()[1].mapID, 505)
end)

test("groups: outside an instance the area is the open world", function()
    local _, m, LF = party(function(m)
        m.__context.inInstance, m.__context.instanceType = false, "none"
        m.instance = { name = "Khaz Algar", difficultyID = 0 }
    end)
    m.addItem(link(300), ring(620))
    LF.Add(link(300), "Brakk")
    assertEqual(labels(LF), "area:Open world=1")
end)

-- ---------------------------------------------------------------------------------------------
-- The gates, in order
-- ---------------------------------------------------------------------------------------------

test("gates: an untracked situation hides the drop before its item is even loaded", function()
    local NS, m, LF = party(function(m)
        m.__context.inInstance, m.__context.instanceType = false, "none"
    end)
    m.addItem(link(300), ring(620, { loadsNeeded = 1 }))
    brakkLoots(m, 300)
    assertEqual(#LF.Drops(), 0)
    assertEqual(#m.loadRequests, 0, "no item load for a drop the situation hides")
    assertEqual(LF.Stats().hidden.notTracking, 1)
    assertEqual(NS.Inspect.QueueState().queued, 0)
end)

test("gates: below the quality threshold a downgrade for you is hidden, and costs no inspect", function()
    local NS, m, LF = party()
    m.addItem(link(300), ring(590, { quality = 2 }))
    brakkLoots(m, 300)
    m.advance(1)
    assertEqual(#LF.Drops(), 0)
    assertEqual(LF.Stats().hidden.quality, 1)
    assertNil(NS.Inspect.Get(BRAKK), "the quality gate runs before the inspect request")
    assertEqual(#m.inspect.notified, 0)
end)

test("gates: the upgrade override shows an upgrade for you below the threshold", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620, { quality = 2 }))
    brakkLoots(m, 300)
    local rec = only(LF)
    assertEqual(rec.quality.reason, "upgradeOverride"); assertEqual(rec.quality.threshold, 3)
end)

test("gates: the stored quality settings and the situation's override are read", function()
    local NS, m, LF = party()
    m.addItem(link(300), ring(620, { quality = 2 }))
    NS.addon.db.profile.feed = { quality = { upgradeOverride = false } }
    brakkLoots(m, 300)
    assertEqual(#LF.Drops(), 0, "the override off")
    NS.addon.db.profile.feed = { quality = { fixed = 2 } }
    m.advance(LF.DEDUPE_WINDOW + 1)
    brakkLoots(m, 300)
    assertEqual(#LF.Drops(), 1, "Uncommon+ passes")
    NS.addon.db.profile.situations = { dungeon = { quality = "dynamicCharacter" } }
    m.addItem(link(301), ring(590, { quality = 3 }))
    brakkLoots(m, 301)
    assertEqual(#LF.Drops(), 1, "your gear is Epic: a Rare downgrade is hidden")
    assertEqual(LF.Stats().hidden.quality, 2)
end)

test("gates: the filters run after the situation and before the verdict", function()
    local _, m, LF = party()
    m.addItem(link(300), def("", 620, { classID = 0, subClassID = 0 }))    -- a potion
    m.addItem(link(301), ring(620, { quality = 7 }))
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    assertEqual(#LF.Drops(), 0)
    assertEqual(LF.Stats().hidden.notGear, 1); assertEqual(LF.Stats().hidden.heirloom, 1)
end)

test("filter: every rule of spec §6.3 (pure)", function()
    local NS = T.newAddon()
    local F = NS.LootFeed.Filter
    local C = NS.Constants
    local gear = { classID = C.ITEM_CLASS.ARMOR, subClassID = 0, quality = 4, ilvl = 600 }
    local function with(over)
        local out = {}
        for k, v in pairs(gear) do out[k] = v end
        for k, v in pairs(over) do out[k] = v end
        return out
    end
    local function check(facts, cfg, ctx, pass, why)
        local ok, reason = F(facts, cfg, ctx)
        assertEqual(ok, pass); assertEqual(reason, why)
    end
    check(gear, {}, {}, true, nil)
    check(nil, {}, {}, true, nil)
    check(with({ classID = C.ITEM_CLASS.WEAPON }), {}, {}, true, nil)
    check(with({ quality = C.QUALITY.HEIRLOOM }), {}, {}, false, "heirloom")
    check(with({ subClassID = C.ARMOR_SUBCLASS.COSMETIC }), { gearOnly = false }, {}, false, "cosmetic")
    check(with({ classID = 15, isTierToken = true }), {}, {}, true, nil)
    check(with({ classID = 15, isTierToken = true }), { includeTokens = false }, {}, false, "token")
    check(with({ classID = 15 }), {}, {}, false, "notGear")
    check(with({ classID = 15 }), { gearOnly = false }, {}, true, nil)
    check(gear, { minIlvlMode = "absolute", minIlvl = 601 }, {}, false, "minIlvl")
    check(gear, { minIlvlMode = "absolute", minIlvl = 600 }, {}, true, nil)
    check(gear, { minIlvlMode = "relative", relativeIlvl = 10 }, { myIlvl = 611 }, false, "minIlvl")
    check(gear, { minIlvlMode = "relative", relativeIlvl = 10 }, { myIlvl = 610 }, true, nil)
    check(gear, { minIlvlMode = "relative", relativeIlvl = 10 }, {}, true, nil)
    check(with({ ilvl = "x" }), { minIlvlMode = "absolute", minIlvl = 601 }, {}, true, nil)
    check(gear, "junk", "junk", true, nil)
end)

test("gates: the relative minimum item level reads your average equipped level", function()
    local NS, m, LF = party()
    NS.addon.db.profile.feed = { minIlvlMode = "relative", relativeIlvl = 10 }
    m.addItem(link(300), ring(589))
    m.addItem(link(301), ring(590))
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    assertEqual(#LF.Drops(), 1)
    assertEqual(LF.Stats().hidden.minIlvl, 1)
end)

-- ---------------------------------------------------------------------------------------------
-- The item load
-- ---------------------------------------------------------------------------------------------

test("load: an uncached item waits for its facts; a second source merges meanwhile", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620, { loadsNeeded = 1 }))
    local id, status = LF.OnChatLoot({ looterName = "Brakk", looterGUID = BRAKK, link = link(300), qty = 1,
        kind = "loot" })
    assertEqual(status, "loading")
    assertEqual(#LF.Drops(), 0); assertEqual(LF.Stats().loading, 1)
    encounterLoot(m, 2900, 300, "Brakk", "WARRIOR")
    m.advance(0.5)    -- the load answers, and LoadItem calls back 0.4s after asking
    local rec = only(LF)
    assertEqual(rec.id, id); assertEqual(sources(rec), "chat,encounter")
    assertEqual(table.concat(seen.added, ","), tostring(id)); assertEqual(#seen.updated, 0)
    assertEqual(rec.me.verdict, "upgrade")
end)

test("load: an item that never loads is shown, judged unknown", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620, { loadsNeeded = 99 }))
    brakkLoots(m, 300)
    for _ = 1, 10 do m.advance(0.5) end
    local rec = only(LF)
    assertNil(rec.facts); assertEqual(rec.me.verdict, "unknown")
    assertEqual(rec.quality.reason, "qualityUnknown"); assertEqual(rec.trade.reasonKey, "badFacts")
end)

-- ---------------------------------------------------------------------------------------------
-- Your own drops
-- ---------------------------------------------------------------------------------------------

test("own: your drop is judged for you, its trade by your verdict, and every member a candidate", function()
    local NS, m, LF = party()
    m.addItem(link(300), ring(590))
    brakkWears(m, 580)
    chat(m, "You receive loot: " .. link(300) .. ".")
    local rec = only(LF)
    assertTrue(rec.isMine); assertEqual(rec.looter.guid, ME)
    assertNil(rec.them); assertNil(rec.inspect)
    assertEqual(rec.me.verdict, "downgrade")
    assertEqual(rec.trade.state, "likely"); assertEqual(rec.trade.reasonKey, "notUpgrade")
    assertEqual(rec.candidates[BRAKK].status, "checking")
    assertEqual(rec.candidates[LYRA].status, "checking")
    m.advance(0)    -- Brakk on the fast path; Lyra wears nothing readable and waits
    assertEqual(rec.candidates[BRAKK].status, "ready")
    assertEqual(rec.candidates[BRAKK].eval.verdict, "upgrade")
    assertEqual(rec.candidates[BRAKK].name, "Brakk-Testrealm")
    assertEqual(NS.Inspect.Get(LYRA).status, "pending")
end)

test("own: an upgrade for you cannot trade, so no candidate is inspected for it", function()
    local NS, m, LF = party()
    m.addItem(link(300), ring(620))
    chat(m, "You receive loot: " .. link(300) .. ".")
    local rec = only(LF)
    assertEqual(rec.trade.state, "no")
    assertEqual(rec.candidates[BRAKK].status, "unavailable")
    assertEqual(NS.Inspect.QueueState().queued, 0)
end)

test("own: an item pushed to you (a quest reward, a purchase) is not a drop", function()
    local _, m, LF = party()
    m.addItem(link(300), ring(620))
    chat(m, "You receive item: " .. link(300) .. ".")
    assertEqual(#LF.Drops(), 0)
    chat(m, "Brakk receives item: " .. link(300) .. ".")
    assertEqual(#LF.Drops(), 1, "a member's pushed item still counts")
end)

-- ---------------------------------------------------------------------------------------------
-- Updates: your gear, the score retry
-- ---------------------------------------------------------------------------------------------

test("update: GearChanged re-judges you on every drop", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(620))
    brakkLoots(m, 300)
    local rec = only(LF)
    assertEqual(rec.me.verdict, "upgrade")
    m.addItem(link(102), ring(640)); m.addItem(link(103), ring(640))
    m.inventory.player[11], m.inventory.player[12] = link(102), link(103)
    m.__fire("PLAYER_EQUIPMENT_CHANGED")
    m.advance(1)
    assertEqual(rec.me.verdict, "downgrade")
    assertEqual(table.concat(seen.updated, ","), rec.id .. ":gear")
end)

test("update: a pending score is retried on one shared timer, five times at most", function()
    local NS, m, LF = party()
    local seen = listen(NS)
    local answer = "pending"
    NS.Scoring = { Scorer = function() return function() return answer end end }
    m.addItem(link(300), ring(620)); m.addItem(link(301), ring(620))
    brakkLoots(m, 300)
    chat(m, "Lyra-Area52 receives loot: " .. link(301) .. ".")
    local a, b = LF.Drops()[1], LF.Drops()[2]
    assertEqual(a.scoreTries, 0)
    m.advance(1)
    assertEqual(a.scoreTries, 1); assertEqual(b.scoreTries, 1)
    m.advance(LF.SCORE_RETRY * 10)
    assertEqual(a.scoreTries, LF.SCORE_TRIES, "given up after five")
    local n = #seen.updated
    m.advance(5)
    assertEqual(#seen.updated, n, "no more retries")
    answer = 12
    m.addItem(link(302), ring(620))
    brakkLoots(m, 302)
    assertNil(LF.Drops()[3].scoreTries, "a ready score needs no retry")
    NS.Scoring = nil
end)

-- ---------------------------------------------------------------------------------------------
-- Add, the test feed, Clear and the cap
-- ---------------------------------------------------------------------------------------------

test("add: injects a drop past the situation gate; a stranger is judged without an inspect", function()
    local NS, m, LF = party(function(m) m.__context.inInstance, m.__context.instanceType = false, "none" end)
    m.addItem(link(300), ring(620))
    local id, status = LF.Add(link(300), "Nobody")
    assertEqual(status, "added")
    local rec = LF.Get(id)
    assertEqual(rec.source, "manual"); assertEqual(rec.looter.name, "Nobody")
    assertEqual(rec.inspect.reason, "notInGroup"); assertEqual(NS.Inspect.QueueState().queued, 0)
    local mine = LF.Get((LF.Add(link(300))))
    assertTrue(mine.isMine)
    assertEqual(#LF.Drops(), 2, "manual drops never merge")
    assertNil(LF.Add("not a link"))
end)

test("add: the test feed skips every gate and every inspect, and stays apart", function()
    local NS, m, LF = party(function(m) m.__context.inInstance, m.__context.instanceType = false, "none" end)
    local seen = listen(NS)
    m.addItem(link(300), ring(560, { quality = 2 }))
    local id = LF.Add(link(300), "Brakk", { test = true })
    assertEqual(#LF.Drops(), 0); assertEqual(#LF.Drops("test"), 1)
    assertEqual(LF.Get(id).feed, "test")
    assertEqual(NS.Inspect.QueueState().queued, 0)
    assertEqual(table.concat(seen.added, ","), tostring(id))
    m.__fire("PLAYER_EQUIPMENT_CHANGED")
    m.advance(1)
    assertEqual(#seen.updated, 0, "test drops are never updated")
    LF.Clear("test")
    assertEqual(#LF.Drops("test"), 0)
end)

test("cap: the oldest drop goes first, and an emptied group with it", function()
    local _, m, LF = party()
    LF.MAX_DROPS = 2
    for id = 300, 302 do m.addItem(link(id), ring(620)) end
    m.__fire("ENCOUNTER_START", 2900, "Speaker Brokk", 2, 5)
    brakkLoots(m, 300)
    m.__fire("ENCOUNTER_END", 2900, "Speaker Brokk", 2, 5, 0)
    brakkLoots(m, 301)
    brakkLoots(m, 302)
    LF.MAX_DROPS = 200
    assertEqual(#LF.Drops(), 2)
    assertEqual(labels(LF), "area:The Rookery=2")
end)

-- ---------------------------------------------------------------------------------------------
-- Secrets and the stand-down
-- ---------------------------------------------------------------------------------------------

test("secrets: a secret link, name or encounter id is never used", function()
    local _, m, LF = party()
    installSecrets(m)
    m.addItem(link(300), ring(620))
    m.__fire("ENCOUNTER_LOOT_RECEIVED", 2900, 300, T.secret(link(300)), 1, "Brakk", "WARRIOR")
    m.__fire("ENCOUNTER_LOOT_RECEIVED", 2900, 300, link(300), 1, T.secret("Brakk"), "WARRIOR")
    assertEqual(#LF.Drops(), 0)
    m.__fire("ENCOUNTER_START", T.secret(2900), T.secret("Speaker Brokk"), 2, 5)
    m.__fire("ENCOUNTER_LOOT_RECEIVED", T.secret(2900), 300, link(300), 1, "Brakk", T.secret("WARRIOR"))
    local rec = only(LF)
    assertNil(rec.encounterID)
    assertEqual(labels(LF), "encounter:Encounter=1")
    m.lootHistory["2900:9"] = T.secret({})
    m.__fire("LOOT_HISTORY_UPDATE_DROP", 2900, 9)
    assertEqual(#LF.Drops(), 1)
end)

test("stand-down: timers and pending loads are dropped, the drops kept", function()
    local NS, m, LF = party()
    NS.Scoring = { Scorer = function() return function() return "pending" end end }
    m.addItem(link(300), ring(620))
    m.addItem(link(301), ring(620, { loadsNeeded = 1 }))
    brakkLoots(m, 300)
    brakkLoots(m, 301)
    NS.addon:OnSlashCommand("disable")
    m.advance(5)
    assertEqual(#LF.Drops(), 1, "the drop recorded before is kept; the load answering late is ignored")
    assertEqual(LF.Drops()[1].scoreTries, 0, "no retry ran while stood down")
    assertNil(LF.Receive({ link = link(300), source = "chat", looter = { name = "Brakk" } }))
    NS.Scoring = nil
    NS.addon:OnSlashCommand("enable")
    m.advance(1)
    assertEqual(LF.Stats().loading, 0)
end)
