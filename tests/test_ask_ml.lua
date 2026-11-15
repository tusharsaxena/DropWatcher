-- tests/test_ask_ml.lua — the master-loot ask (Forever port design §6, plan DW-FP19): the `askML`
-- message kind, a polite whisper to the master looter for an Epic awaiting them (modules/PendingML.lua's
-- `ml` item). One press whispers the master looter once, and the one-ask guard refuses a second;
-- under a chat restriction it is queued and sent on the lift; it is refused when you are the master
-- looter, when the item is no upgrade for you and when the master looter is offline; on WoW Forever
-- the whisper target is the whole two-word name (Review Focus 4); the received drop's History entry
-- reads `asked`; and auto-ask never sends it. Master loot ships on both clients (design §11.2), so
-- every case runs on both kit profiles.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK, DOOM = "Player-1-0000000A", "Player-1-0000000D"
local BOSS = "Creature-0-1-2-3-2900-0000AAAA"
local EVENT = "ADDON_RESTRICTION_STATE_CHANGED"
local ENCOUNTER, ACTIVE, INACTIVE = 1, 2, 0

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl, quality)
    return { name = "Item", quality = quality or 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- The master looter, Doom Dock (raid3), as the client names them: the whole name on Forever
-- ("Doom Dock"), Name-Realm on Retail ("Doom-Dock"); the greeting's {player} is their name.
local DOOM_TO = T.rosterName("Doom", "Dock")
local DOOM_NAME = T.forever and "Doom Dock" or "Doom"

-- An enabled addon in a raid instance under master loot, Doom Dock (raid3) the master looter, the
-- player wearing two 600 rings.
local function raid()
    local NS, _, m = T.enableAddon({ mock = function(m)
        m.__context.inInstance, m.__context.instanceType = true, "raid"
        m.instance = { name = "Nerub-ar Palace", difficultyID = 14 }
    end })
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.INVTYPE_FINGER = "Finger"
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(DOOM, "Doom", "Dock", "HUNTER") }, true)
    NS.Roster.Refresh("test")
    m.lootMethod = { 2, nil, 3 }
    return NS, m
end

local TOP = 4   -- an Epic, at or above the group's loot threshold (rolls UX RX-03)

-- The boss corpse's loot window holding one ring at `ilvl` (620 by default, an upgrade for you)
-- at the threshold's quality; answers the ml item it opens.
local function awaiting(NS, m, id, ilvl)
    m.addItem(link(id), ring(ilvl or 620, TOP))
    m.lootSlots = { { link = link(id), quality = TOP, locked = true, source = BOSS } }
    m.__fire("LOOT_OPENED", false, false)
    for _, item in ipairs(NS.Pending.All()) do
        if item.kind == "ml" and item.itemID == id then return item end
    end
    error("no ml item for " .. id)
end

local function restrict(m) m.__fire(EVENT, ENCOUNTER, ACTIVE) end
local function lift(m) m.__fire(EVENT, ENCOUNTER, INACTIVE) end

local function printed(m, needle)
    local n = 0
    for _, line in ipairs(m.prints) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function kinds(NS)
    local seen = {}
    NS.Bus:NewTarget():RegisterMessage(NS.MSG.ASK_STATE_CHANGED, function(_, _, state, kind)
        seen[#seen + 1] = kind .. ":" .. state
    end)
    return seen
end

-- ---------------------------------------------------------------------------------------------

test("askML: one press whispers the master looter once; a second press is refused by the one-ask guard", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    local state, reason = NS.PressAskML(item.id)
    assertEqual(state, "sent"); assertNil(reason)
    assertEqual(#m.chatSent, 1)
    local sent = m.chatSent[1]
    assertEqual(sent.chatType, "WHISPER")
    assertEqual(sent.target, DOOM_TO, "the master looter, not a looter")
    assertEqual(sent.text, "Hi " .. DOOM_NAME .. ", if nobody needs " .. link(300) .. ", I'd love it: +20 for me. Thanks!")
    assertEqual(printed(m, "Whispered "), 1, "the confirmation line")
    assertEqual(NS.Asks.StateOf("askML", DOOM_TO, item.id), "sent")
    assertTrue(item.askedML, "the pending item remembers the ask")
    state, reason = NS.PressAskML(item.id)
    assertEqual(state, "refused"); assertEqual(reason, "alreadyAsked")
    assertEqual(#m.chatSent, 1, "one ask per item")
    assertEqual(printed(m, "Not asked: You already asked"), 1)
end)

test("askML: queued while chat is restricted and sent on lift", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    restrict(m)
    assertEqual(NS.PressAskML(item.id), "queued")
    assertEqual(#m.chatSent, 0)
    assertFalse(item.askedML == true, "not asked until it is sent")
    lift(m)
    assertEqual(#m.chatSent, 1, "the lift sent it")
    assertEqual(m.chatSent[1].target, DOOM_TO)
    assertTrue(item.askedML)
    -- A queued ask whose item is assigned first never goes out.
    local other = awaiting(NS, m, 301)
    restrict(m)
    assertEqual(NS.PressAskML(other.id), "queued")
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(301) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    lift(m)
    assertEqual(#m.chatSent, 1, "the assigned item's queued ask was canceled")
    assertEqual(NS.Asks.StateOf("askML", DOOM_TO, other.id), "ready")
end)

test("askML: refused when you are the master looter, when it is no upgrade for you, when the ML is offline", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    m.lootMethod = { 2, nil, 1 }   -- you, with no method event yet
    assertEqual(select(2, NS.PressAskML(item.id)), "isML")
    assertEqual(printed(m, "Not asked: You are the master looter."), 1)
    m.lootMethod = { 2, nil, 3 }
    local worse = awaiting(NS, m, 302, 590)
    assertEqual(worse.me.verdict, "downgrade")
    assertEqual(select(2, NS.PressAskML(worse.id)), "noUpgrade")
    assertEqual(printed(m, "Not asked: It is not an upgrade for you."), 1)
    m.units.raid3.connected = false
    NS.Roster.Refresh("test")
    assertEqual(select(2, NS.PressAskML(item.id)), "offline")
    assertEqual(printed(m, "Not asked: " .. DOOM_TO .. " is offline."), 1)
    assertEqual(select(2, NS.PressAskML(999)), "noDrop", "no such item")
    assertEqual(#m.chatSent, 0)
end)

test("askML: on Forever the whisper target is the whole two-word name", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    assertEqual(item.ml.name, DOOM_NAME)
    assertEqual(NS.PressAskML(item.id), "sent")
    local sent = m.chatSent[1]
    if T.forever then
        assertEqual(sent.target, "Doom Dock", "whispered whole: never Doom-Dock, never Doom")
        assertTrue(sent.text:find("Hi Doom Dock,", 1, true) ~= nil, "the greeting names the whole name")
    else
        assertEqual(sent.target, "Doom-Dock")
    end
end)

test("askML: the received drop's History entry reads asked", function()
    local NS, m = raid()
    -- A feed drop first, so the pending item's id (1) meets a feed id: the ask is never filed on it.
    m.addItem(link(400), ring(580))
    local first = NS.LootFeed.Add(link(400), "Brakk")
    m.advance(0)
    local item = awaiting(NS, m, 300)
    assertEqual(item.id, first, "the two stores' ids meet")
    assertEqual(NS.PressAskML(item.id), "sent")
    assertEqual(NS.History.EntryOf(first).outcome, "seen", "the feed drop with the same id is untouched")
    m.advance(30)
    m.__fire("CHAT_MSG_LOOT", "Brakk receives loot: " .. link(300) .. ".", "", "", "", "", "", 0, 0, "", 0, 1, nil)
    local rec = NS.LootFeed.Drops()[2]
    assertEqual(rec.pendingKey, item.id); assertTrue(rec.askedML)
    local e = NS.History.EntryOf(rec.id)
    assertEqual(e.outcome, "asked")
    assertTrue(e.askedAt ~= nil, "stamped as an ask is")
    assertTrue(NS.History.WasAsked(e))
end)

test("auto-ask: never sends askML", function()
    local NS, m = raid()
    assertTrue(NS.SchemaRuntime.Set("messages.autoAsk.enabled", true))
    local seen = kinds(NS)
    awaiting(NS, m, 300)
    m.advance(60)
    for _, k in ipairs(seen) do assertFalse(k:find("^askML") ~= nil, "no askML: " .. k) end
    for _, s in ipairs(m.chatSent) do assertFalse(s.target == DOOM_TO, "nothing whispered to the master looter") end
end)

test("askML: the Edit message box opens first with editFirst on, and its Send whispers the master looter", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    NS.SchemaRuntime.Set("messages.editFirst", true)
    NS.ShowWindow()
    assertEqual(NS.PressAskML(item.id), "editing")
    assertEqual(#m.chatSent, 0)
    local box = NS.DetailCard.Editor()
    assertTrue(box:IsShown())
    assertEqual(box.kind, "askML"); assertEqual(box.target, DOOM_TO)
    assertTrue(box.box:GetText():find("if nobody needs", 1, true) ~= nil, "the askML template, filled in")
    box.box:SetText("Could I have it?")
    box.send:__fire("OnClick")
    assertEqual(#m.chatSent, 1)
    assertEqual(m.chatSent[1].target, DOOM_TO); assertEqual(m.chatSent[1].text, "Could I have it?")
end)

test("askML: the diagnostics name its template and a queued one", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    restrict(m)
    NS.PressAskML(item.id)
    NS.DebugLog:Clear()
    NS.addon:OnSlashCommand("diagnostics")
    local text = table.concat(NS.DebugLog.buffer, "\n")
    assertTrue(text:find("askML=", 1, true) ~= nil, text)
    assertTrue(text:find("messaging: queued askML to " .. DOOM_TO .. ", pending " .. item.id, 1, true) ~= nil, text)
end)

test("askML: the restriction badge's tooltip names a queued one in words, never the kind's key", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    NS.ShowWindow()
    restrict(m)
    assertEqual(NS.PressAskML(item.id), "queued")
    m.advance(0)
    local f = NS.Window.Frame()
    local tip = NS.Window.TooltipOf(f.badge)
    assertEqual(T.tipPlain(tip[#tip]), "• Queued: Ask the master looter to " .. DOOM_TO)
end)

test("askML: a master looter the roster no longer knows is named, never whispered by GUID", function()
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    assertEqual(item.ml.guid, DOOM)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR") }, true)
    NS.Roster.Refresh("test")
    assertEqual(NS.AskMLTargetOf(item), DOOM_TO, "the name it read, not " .. tostring(item.ml.guid))
    local state, reason = NS.PressAskML(item.id)
    assertEqual(state, "refused"); assertEqual(reason, "notInGroup")
    assertEqual(printed(m, DOOM), 0, "no GUID in chat")
    assertEqual(#m.chatSent, 0)
end)

test("askML: a master looter read by GUID alone and gone from the roster is not known, never named by GUID", function()
    -- red under: NS.AskMLTargetOf answering the item's raw GUID when it read no name
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    item.ml.name, item.ml.realm = nil, nil
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR") }, true)
    NS.Roster.Refresh("test")
    assertNil(NS.AskMLTargetOf(item), "no name to give, and never the GUID")
    local state, reason = NS.PressAskML(item.id)
    assertEqual(state, "refused"); assertEqual(reason, "noTarget")
    assertEqual(printed(m, "Not asked: The master looter is not known."), 1)
    assertEqual(printed(m, DOOM), 0, "no GUID in chat")
    assertEqual(#m.chatSent, 0)
end)

test("askML: a stand-down never reuses a pending id, so a new item never reads an old item's ask", function()
    -- red under: the stand-down dropping the pending store's id sequence while the Asks book keeps
    -- the sent askML filed under the old id
    local NS, m = raid()
    local item = awaiting(NS, m, 300)
    assertEqual((NS.PressAskML(item.id)), "sent")
    NS.addon:OnSlashCommand("disable")
    NS.addon:OnSlashCommand("enable")
    local fresh = awaiting(NS, m, 301)
    assertTrue(fresh.id ~= item.id, "a new id after the stand-down")
    assertTrue(NS.Asks.StateOf("askML", NS.AskMLTargetOf(fresh), fresh.id) ~= "sent", "the new item is not asked")
    assertFalse(fresh.askedML == true)
end)
