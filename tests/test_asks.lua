-- tests/test_asks.lua — modules/Asks.lua, the messaging edge (design spec §9.2-§9.3): the send
-- through the chat sender in pcall and its confirmation line, the token context from the drop, the
-- one-ask guard and the length limit at the edge, queueing under a restriction, the flush on a
-- restriction lift, ENCOUNTER_END and CHALLENGE_MODE_COMPLETED (one send every 1.5s, first in first
-- out, stopped by a new restriction), cancel by a click and when the looter leaves, a failed send
-- and its retry, the announce channel, test mode routed to print, AskStateChanged, the preview
-- the detail card's Edit message box reads, and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BRAKK, LYRA = "Player-1-0000000A", "Player-2-0000000B"
local EVENT = "ADDON_RESTRICTION_STATE_CHANGED"
local ENCOUNTER, ACTIVE, INACTIVE = 1, 2, 0    -- the mock's Enum.AddOnRestrictionType / State values

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function ring(ilvl)
    return { name = "Item", quality = 4, ilvl = ilvl, equipLoc = "INVTYPE_FINGER", classID = 4,
        subClassID = 0, bindType = 1, stats = {} }
end

local function row(guid, name, realm, classFile)
    return { guid = guid, name = name, realm = realm, class = classFile, classFile = classFile }
end

-- An enabled instance in a party: the player wears two 600 rings; Brakk (party1, on the player's
-- realm) and Lyra (party2, from Area 52) are in the group.
local function party()
    local NS, _, m = T.enableAddon()
    m.addItem(link(100), ring(600))
    m.addItem(link(101), ring(600))
    m.inventory.player[11], m.inventory.player[12] = link(100), link(101)
    m.setGroup({ row(BRAKK, "Brakk", nil, "WARRIOR"), row(LYRA, "Lyra", "Area 52", "PRIEST") })
    m.INVTYPE_FINGER = "Finger"
    NS.Roster.Refresh("test")
    return NS, m, NS.Asks
end

-- A drop of a ring at `ilvl` (item id `id`) looted by `looter`, judged.
local function drop(NS, m, id, looter, ilvl)
    m.addItem(link(id), ring(ilvl or 610))
    local dropID = NS.LootFeed.Add(link(id), looter)
    m.advance(0)
    return dropID
end

local function listen(NS)
    local seen = {}
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.ASK_STATE_CHANGED, function(_, dropID, state, kind, to, reason)
        seen[#seen + 1] = { dropID = dropID, state = state, kind = kind, target = to, reason = reason }
    end)
    return seen
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

-- ---------------------------------------------------------------------------------------------
-- Sending
-- ---------------------------------------------------------------------------------------------

test("send: an ask whispers the looter's Name-Realm with the expanded template, and confirms in chat", function()
    local NS, m, A = party()
    local seen = listen(NS)
    local id = drop(NS, m, 300, "Brakk")
    local state, reason = A.Request("ask", "Brakk", id)
    assertEqual(state, "sent"); assertNil(reason)
    assertEqual(#m.chatSent, 1)
    local sent = m.chatSent[1]
    assertEqual(sent.chatType, "WHISPER")
    assertEqual(sent.target, "Brakk-Testrealm")
    assertNil(sent.languageID)
    assertEqual(sent.text, "Hi Brakk, if you don't need " .. link(300)
        .. ", could I have it? It'd be +10 for me. No worries if not!")
    assertEqual(printed(m, "Whispered Brakk: " .. link(300)), 1, "one confirmation line")
    assertEqual(A.StateOf("ask", "Brakk", id), "sent")
    assertEqual(A.StateOf("ask", BRAKK, id), "sent", "a GUID finds the same ask")
    assertEqual(#seen, 1)
    assertEqual(seen[1].dropID, id); assertEqual(seen[1].state, "sent")
    assertEqual(seen[1].kind, "ask"); assertEqual(seen[1].target, "Brakk-Testrealm")
end)

test("send: every token comes from the drop: item, ilvl, slot, track and both gains", function()
    local NS, m, A = party()
    NS.db.profile.messages = { templates = { ask = "{player}|{item}|{ilvl}|{slot}|{track}|{mygain}" } }
    local id = drop(NS, m, 300, "Brakk", 613)
    A.Request("ask", "Brakk", id)
    assertEqual(m.chatSent[1].text, "Brakk|" .. link(300) .. "|613|Finger|?|13")
end)

test("send: the one-ask guard refuses a repeat; with messages.oneAsk off a sent ask goes again", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, "Brakk")
    A.Request("ask", "Brakk", id)
    local state, reason = A.Request("ask", "Brakk-Testrealm", id)
    assertEqual(state, "refused"); assertEqual(reason, "alreadyAsked")
    assertEqual(#m.chatSent, 1)
    NS.db.profile.messages = { oneAsk = false }
    assertEqual((A.Request("ask", "Brakk", id)), "sent")
    assertEqual(#m.chatSent, 2)
end)

test("send: an edited text over 255 bytes is refused tooLong and nothing is sent", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, "Brakk")
    local state, reason = A.Request("ask", "Brakk", id, { text = string.rep("x", 256) })
    assertEqual(state, "refused"); assertEqual(reason, "tooLong")
    assertEqual(#m.chatSent, 0)
    assertEqual(A.StateOf("ask", "Brakk", id), "ready")
    assertEqual((A.Request("ask", "Brakk", id, { text = "Need it?" })), "sent")
    assertEqual(m.chatSent[1].text, "Need it?")
end)

test("send: a stranger, yourself, an offline member and a missing target are refused", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, "Brakk")
    assertEqual(select(2, A.Request("ask", "Nobody", id)), "notInGroup")
    assertEqual(select(2, A.Request("ask", "player", id)), "notInGroup")
    assertEqual(select(2, A.Request("ask", m.__context.name, id)), "self")
    m.units.party2.connected = false
    NS.Roster.Refresh("test")
    assertEqual(select(2, A.Request("offer", "Lyra", id)), "offline")
    assertEqual(select(2, A.Request("ask", nil, id)), "noTarget")
    assertEqual(select(2, A.Request("ask", T.secret("Brakk"), id)), "noTarget")
    assertEqual(#m.chatSent, 0)
    assertEqual(A.Stats().refusals, 6)
end)

test("preview: the template filled in for the drop, with its length; nothing sent or filed", function()
    local NS, m, A = party()
    NS.db.profile.messages = { templates = { ask = "{player}: {item} at {ilvl}?" } }
    local id = drop(NS, m, 300, "Brakk", 613)
    local p = A.Preview("ask", "Brakk", id)
    assertEqual(p.text, "Brakk: " .. link(300) .. " at 613?")
    assertEqual(p.length, #p.text); assertFalse(p.tooLong)
    assertEqual(#m.chatSent, 0)
    assertEqual(A.StateOf("ask", "Brakk", id), "ready", "a preview files no ask")
    local none, why = A.Preview("ask", "Nobody", id)
    assertNil(none); assertEqual(why, "notInGroup")
    NS.addon:OnSlashCommand("disable")
    assertEqual(select(2, A.Preview("ask", "Brakk", id)), "disabled")
end)

test("send: an offer whispers the candidate, named in {player}", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, nil)    -- your own drop
    A.Request("offer", "Lyra", id)
    assertEqual(m.chatSent[1].target, "Lyra-Area52")
    assertTrue(m.chatSent[1].text:find("^Hi Lyra, " .. link(300):gsub("%p", "%%%0")) ~= nil)
end)

-- ---------------------------------------------------------------------------------------------
-- A failed send
-- ---------------------------------------------------------------------------------------------

test("fail: a raising sender fails with its message, prints nothing, and may be retried", function()
    local NS, m, A = party()
    local seen = listen(NS)
    local id = drop(NS, m, 300, "Brakk")
    local real = m.C_ChatInfo.SendChatMessage
    m.C_ChatInfo.SendChatMessage = function() error("throttled", 0) end
    local state, reason = A.Request("ask", "Brakk", id)
    assertEqual(state, "failed"); assertEqual(reason, "throttled")
    assertEqual(printed(m, "Whispered"), 0)
    assertEqual(seen[1].state, "failed"); assertEqual(seen[1].reason, "throttled")
    assertEqual(A.Stats().failures, 1)
    m.C_ChatInfo.SendChatMessage = real
    assertEqual((A.Request("ask", "Brakk", id)), "sent", "a failed ask may be retried")
    assertEqual(#m.chatSent, 1)
end)

test("fail: a secret or empty error reads as error; no sender at all is noApi", function()
    local NS, m, A = party()
    m.issecretvalue = T.isSecret
    local id = drop(NS, m, 300, "Brakk")
    m.C_ChatInfo.SendChatMessage = function() error(T.secret("why"), 0) end
    assertEqual(select(2, A.Request("ask", "Brakk", id)), "error")
    m.C_ChatInfo.SendChatMessage = nil
    m.SendChatMessage = nil
    assertEqual(select(2, A.Request("ask", "Brakk", id)), "noApi")
end)

test("fail: the deprecated global sender is the fallback", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, "Brakk")
    local calls = {}
    m.C_ChatInfo.SendChatMessage = nil
    m.SendChatMessage = function(text, chatType, _, to) calls[#calls + 1] = { text, chatType, to } end
    assertEqual((A.Request("ask", "Brakk", id)), "sent")
    assertEqual(#calls, 1); assertEqual(calls[1][2], "WHISPER"); assertEqual(calls[1][3], "Brakk-Testrealm")
end)

-- ---------------------------------------------------------------------------------------------
-- Announce
-- ---------------------------------------------------------------------------------------------

test("announce: auto picks INSTANCE_CHAT, then RAID, then PARTY, and never SAY or YELL", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, nil)
    m.RAID = "Raid"
    assertEqual(A.AnnounceChannel(), "PARTY")
    assertEqual((A.Request("announce", nil, id)), "sent")
    assertEqual(m.chatSent[1].chatType, "PARTY"); assertNil(m.chatSent[1].target)
    assertEqual(m.chatSent[1].text, link(300) .. " is up for grabs, whisper me.")
    assertEqual(printed(m, "Announced in PARTY: " .. link(300)), 1)
    m.__context.inRaid = true
    assertEqual(A.AnnounceChannel(), "RAID")
    m.instanceGroup = true
    assertEqual(A.AnnounceChannel(), "INSTANCE_CHAT")
    NS.db.profile.messages = { announceChannel = "PARTY", oneAsk = false }
    assertEqual(A.AnnounceChannel(), "PARTY", "a stored channel wins")
    NS.db.profile.messages.announceChannel = "YELL"
    assertEqual(A.AnnounceChannel(), "INSTANCE_CHAT", "an unknown channel is auto")
    m.instanceGroup = false
    A.Request("announce", nil, id)
    assertEqual(printed(m, "Announced in Raid: " .. link(300)), 1, "the channel's own label")
end)

test("announce: outside a group it fails noChannel", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, nil)
    m.setGroup({})
    local state, reason = A.Request("announce", nil, id)
    assertEqual(state, "failed"); assertEqual(reason, "noChannel")
    assertEqual(#m.chatSent, 0)
end)

-- ---------------------------------------------------------------------------------------------
-- The queue and the flush
-- ---------------------------------------------------------------------------------------------

test("queue: under a restriction the ask is queued, and the lift sends it at once", function()
    local NS, m, A = party()
    local seen = listen(NS)
    local id = drop(NS, m, 300, "Brakk")
    restrict(m)
    assertEqual((A.Request("ask", "Brakk", id)), "queued")
    assertEqual(#m.chatSent, 0)
    assertEqual(A.StateOf("ask", "Brakk", id), "queued")
    assertEqual(seen[1].state, "queued")
    assertEqual(#A.Queued(), 1)
    lift(m)
    assertEqual(#m.chatSent, 1, "sent on the lift")
    assertEqual(A.StateOf("ask", "Brakk", id), "sent")
    assertEqual(seen[2].state, "sent")
    assertEqual(printed(m, "Whispered Brakk"), 1)
    assertFalse(A.IsFlushing(), "nothing left, no timer")
end)

test("flush: one send every 1.5 seconds, first in first out", function()
    local NS, m, A = party()
    local a = drop(NS, m, 300, "Brakk")
    local b = drop(NS, m, 301, "Lyra")
    local c = drop(NS, m, 302, "Brakk")
    restrict(m)
    A.Request("ask", "Brakk", a); A.Request("ask", "Lyra", b); A.Request("ask", "Brakk", c)
    lift(m)
    assertEqual(#m.chatSent, 1)
    assertTrue(A.IsFlushing())
    m.advance(1.4)
    assertEqual(#m.chatSent, 1, "not before the interval")
    m.advance(0.1)
    assertEqual(#m.chatSent, 2)
    m.advance(1.5)
    assertEqual(#m.chatSent, 3)
    assertEqual(m.chatSent[1].target, "Brakk-Testrealm")
    assertEqual(m.chatSent[2].target, "Lyra-Area52")
    assertTrue(m.chatSent[3].text:find("Item 302", 1, true) ~= nil)
    assertFalse(A.IsFlushing())
    assertEqual(A.Stats().flushes, 1)
end)

test("flush: a restriction back mid-flush stops it; the rest wait for the next trigger", function()
    local NS, m, A = party()
    local a = drop(NS, m, 300, "Brakk")
    local b = drop(NS, m, 301, "Lyra")
    restrict(m)
    A.Request("ask", "Brakk", a); A.Request("ask", "Lyra", b)
    lift(m)
    assertEqual(#m.chatSent, 1)
    m.chatLockdown = true    -- a lockdown arrives with no event of its own
    m.advance(1.5)
    assertEqual(#m.chatSent, 1, "held")
    assertEqual(A.StateOf("ask", "Lyra", b), "queued")
    m.chatLockdown = false
    m.__fire("ENCOUNTER_END", 2902, "Boss", 16, 20, 1)
    assertEqual(#m.chatSent, 2, "ENCOUNTER_END flushed it")
end)

test("flush: ENCOUNTER_END and CHALLENGE_MODE_COMPLETED re-read a lockdown that lifted silently", function()
    for _, event in ipairs({ "ENCOUNTER_END", "CHALLENGE_MODE_COMPLETED" }) do
        local NS, m, A = party()
        local id = drop(NS, m, 300, "Brakk")
        m.chatLockdown = true
        assertEqual((A.Request("ask", "Brakk", id)), "queued", event)
        m.chatLockdown = false
        assertEqual(#m.chatSent, 0)
        m.__fire(event)
        assertEqual(#m.chatSent, 1, event)
    end
end)

test("flush: a trigger with nothing queued, or while chat is still restricted, sends nothing", function()
    local NS, m, A = party()
    assertFalse(A.Flush("ENCOUNTER_END"), "nothing queued")
    local id = drop(NS, m, 300, "Brakk")
    restrict(m)
    A.Request("ask", "Brakk", id)
    assertFalse(A.Flush("ENCOUNTER_END"), "still restricted")
    m.__fire("ENCOUNTER_END", 2902, "Boss", 16, 20, 1)
    assertEqual(#m.chatSent, 0)
    assertFalse(A.Flush("someOtherEvent"))
end)

-- ---------------------------------------------------------------------------------------------
-- Cancel
-- ---------------------------------------------------------------------------------------------

test("cancel: pressing a queued ask cancels it; the lift sends nothing and the button is ready", function()
    local NS, m, A = party()
    local seen = listen(NS)
    local id = drop(NS, m, 300, "Brakk")
    restrict(m)
    assertEqual((A.Press("ask", "Brakk", id)), "queued")
    assertEqual((A.Press("ask", "Brakk", id)), "ready", "pressed again: canceled")
    assertEqual(A.StateOf("ask", "Brakk", id), "ready")
    assertEqual(seen[2].state, "ready"); assertEqual(seen[2].reason, "canceled")
    lift(m)
    assertEqual(#m.chatSent, 0)
    assertFalse(A.Cancel("ask", "Brakk", id), "nothing queued to cancel")
    assertEqual((A.Press("ask", "Brakk", id)), "sent", "asked again")
end)

test("cancel: an ask queued to a looter who leaves is dropped; others stay", function()
    local NS, m, A = party()
    local seen = listen(NS)
    local a = drop(NS, m, 300, "Brakk")
    local b = drop(NS, m, 301, "Lyra")
    restrict(m)
    A.Request("ask", "Brakk", a); A.Request("ask", "Lyra", b)
    m.setGroup({ row(LYRA, "Lyra", "Area 52", "PRIEST") })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(A.StateOf("ask", "Brakk-Testrealm", a), "ready")
    assertEqual(A.StateOf("ask", "Lyra", b), "queued")
    local last = seen[#seen]
    assertEqual(last.dropID, a); assertEqual(last.state, "ready"); assertEqual(last.reason, "left")
    lift(m)
    assertEqual(#m.chatSent, 1)
    assertEqual(m.chatSent[1].target, "Lyra-Area52")
end)

test("cancel: a queued announce is dropped once you leave the group", function()
    local NS, m, A = party()
    local id = drop(NS, m, 300, nil)
    restrict(m)
    assertEqual((A.Request("announce", nil, id)), "queued")
    m.__fire("GROUP_ROSTER_UPDATE")
    assertEqual(A.StateOf("announce", nil, id), "queued", "still in a group")
    m.setGroup({})
    assertEqual(A.OnRosterChanged(), 1)
    assertEqual(A.StateOf("announce", nil, id), "ready")
end)

-- ---------------------------------------------------------------------------------------------
-- Test mode
-- ---------------------------------------------------------------------------------------------

test("test mode: nothing is sent; the text is printed and the ask is marked sent, even restricted", function()
    local NS, m, A = party()
    local seen = listen(NS)
    m.addItem(link(300), ring(610))
    local id = NS.LootFeed.Add(link(300), "Seta-Silvermoon", { test = true })
    m.advance(0)
    restrict(m)
    local state = A.Request("ask", "Seta-Silvermoon", id)
    assertEqual(state, "sent")
    assertEqual(#m.chatSent, 0, "never sent")
    assertEqual(printed(m, "Test mode, not sent: Hi Seta,"), 1)
    assertEqual(seen[1].state, "sent")
    -- In test mode a live drop is printed too.
    lift(m)
    NS.SetTestMode(true)
    local live = drop(NS, m, 301, "Brakk")
    assertEqual((A.Request("ask", "Brakk", live)), "sent")
    assertEqual(#m.chatSent, 0)
    assertEqual(printed(m, "Test mode, not sent:"), 2)
end)

-- ---------------------------------------------------------------------------------------------
-- The stand-down
-- ---------------------------------------------------------------------------------------------

test("stand-down: a request is refused, the flush timer is canceled and the queue is dropped", function()
    local NS, m, A = party()
    local a = drop(NS, m, 300, "Brakk")
    local b = drop(NS, m, 301, "Lyra")
    local c = drop(NS, m, 302, "Brakk")
    restrict(m)
    A.Request("ask", "Brakk", a); A.Request("ask", "Lyra", b); A.Request("ask", "Brakk", c)
    lift(m)
    assertTrue(A.IsFlushing())
    NS.addon:OnSlashCommand("disable")
    assertFalse(A.IsFlushing())
    assertEqual(#A.Queued(), 0)
    assertEqual(#m.__timers(), 0)
    assertEqual(select(2, A.Request("ask", "Lyra", b)), "disabled")
    NS.addon:OnSlashCommand("enable")
    m.advance(5)
    assertEqual(#m.chatSent, 1, "nothing dropped was sent")
    assertEqual(A.StateOf("ask", "Lyra", b), "ready")
end)
