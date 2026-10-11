-- tests/test_inspect.lua — modules/Inspect.lua (design spec §8): the inspect broker's state machine
-- on the mock's clock (`m.advance`): one inspect in flight, the spacing, the priority order, the
-- ready timeout and its retry, the range and identity waits, the incomplete-link retries, the read
-- (links, tooltip levels, spec), the fast path, the foreign-inspect hook, opportunistic reads, the
-- combat park, the inspect window, the cache's TTL and invalidation, the warm-up and the scan, the
-- candidate, InspectDone, the secret guards and the stand-down.

local T = _G.DW_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local A, B, C = "Player-1-0000000A", "Player-2-0000000B", "Player-3-0000000C"
local STRANGER = "Player-9-00000009"

local function row(guid, name, classFile, connected)
    return { guid = guid, name = name, class = classFile, classFile = classFile, connected = connected }
end

-- An enabled instance in a party: the player, then Brakk (party1), Lyra (party2) and Vex (party3).
-- The roster is read directly, so no warm-up is armed.
local function party(seed)
    local NS, _, m = T.enableAddon({ mock = seed })
    m.setGroup({ row(A, "Brakk", "WARRIOR"), row(B, "Lyra", "PRIEST"), row(C, "Vex", "ROGUE") })
    NS.Roster.Refresh("test")
    return NS, m, NS.Inspect
end

local UNIT = { [A] = "party1", [B] = "party2", [C] = "party3" }

local function link(id) return ("|cnIQ4:|Hitem:%d::::::::90:::::|h[Item %d]|h|r"):format(id, id) end

local function plate(equipLoc, ilvl, extra)
    local d = { name = "Item", quality = 4, ilvl = ilvl, equipLoc = equipLoc, classID = 4,
        subClassID = 4, bindType = 1, stats = {} }
    for k, v in pairs(extra or {}) do d[k] = v end
    return d
end

-- What the client holds for a member once its inspect data has arrived: a helm in slot 1 and a
-- chest in slot 5, and the spec.
local function arrive(m, guid, specID)
    local unit = UNIT[guid]
    m.inventory[unit] = {}
    m.addItem(link(4001), plate("INVTYPE_HEAD", 600))
    m.addItem(link(4005), plate("INVTYPE_CHEST", 610))
    m.inventory[unit][1] = link(4001)
    m.inventory[unit][5] = link(4005)
    m.inspect.specs[unit] = specID or 71
end

-- As arrive, plus the slots only inspect data shows (neck, rings, trinkets): what the fast path
-- needs before it trusts a read made without an inspect.
local HIDDEN = { [2] = "INVTYPE_NECK", [11] = "INVTYPE_FINGER", [12] = "INVTYPE_FINGER",
    [13] = "INVTYPE_TRINKET", [14] = "INVTYPE_TRINKET" }
local function arriveFull(m, guid, specID)
    arrive(m, guid, specID)
    for slot, equipLoc in pairs(HIDDEN) do
        m.addItem(link(4000 + slot), plate(equipLoc, 600, { classID = 4, subClassID = 0 }))
        m.inventory[UNIT[guid]][slot] = link(4000 + slot)
    end
end

local function ready(m, guid)
    m.__fire("INSPECT_READY", guid)
end

local function notifiedUnits(m)
    local out = {}
    for i, n in ipairs(m.inspect.notified) do out[i] = n.unit end
    return table.concat(out, ",")
end

-- Every InspectDone, in order, on a receiver of its own.
local function listen(NS)
    local seen = {}
    local target = NS.Bus:NewTarget()
    target:RegisterMessage(NS.MSG.INSPECT_DONE, function(_, guid) seen[#seen + 1] = guid end)
    return seen
end

-- Sends `guid`'s inspect, delivers its data and lets the read run.
local function inspectNow(m, guid, specID)
    m.advance(0)
    arrive(m, guid, specID)
    ready(m, guid)
    m.advance(0.15)
end

local function installSecrets(m)
    m.issecretvalue = function(v) return T.isSecret(v) end
end

-- ---------------------------------------------------------------------------------------------
-- One inspect, read
-- ---------------------------------------------------------------------------------------------

test("inspect: a request sends one NotifyInspect, and the ready read stores gear and spec", function()
    local NS, m, I = party()
    local done = listen(NS)
    assertEqual(I.Request(A, I.PRIORITY.looter), "pending")
    assertEqual(#m.inspect.notified, 0, "the pump runs on the next timer pass")
    m.advance(0)
    assertEqual(notifiedUnits(m), "party1")
    assertEqual(I.QueueState().inFlight, A)
    arrive(m, A, 71)
    ready(m, A)
    m.advance(0.1)
    assertEqual(I.Get(A).status, "pending", "the read waits READ_DELAY after INSPECT_READY")
    m.advance(0.05)
    local e = I.Get(A)
    assertEqual(e.status, "fresh")
    assertEqual(e.gear[1].link, link(4001)); assertEqual(e.gear[5].link, link(4005))
    assertEqual(e.gear[2], false, "an empty slot")
    assertEqual(e.specID, 71); assertEqual(e.gen, 1); assertNil(e.reason)
    assertEqual(NS.Roster.Get(A).specID, 71, "the roster learns the spec")
    assertEqual(m.inspect.cleared, 1, "this broker's inspect is cleared after the read")
    assertNil(I.QueueState().inFlight)
    assertEqual(table.concat(done, ","), A, "InspectDone, once")
end)

test("inspect: a slot's level comes from its tooltip, else from the link", function()
    local NS, m, I = party()
    I.Request(A)
    m.advance(0)
    arrive(m, A)
    m.tooltips.inventory["party1:1"] = { lines = { { type = 41, leftText = "Item Level 645" } } }
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).gear[1].ilvl, 645)
    assertNil(I.Get(A).gear[5].ilvl, "no tooltip line: the candidate falls back to the link's level")
    local c = I.Candidate(A)
    assertEqual(c.gear[1].ilvl, 645); assertEqual(c.gear[5].ilvl, 610)
    assertEqual(c.gear[1].slot, 1)
    assertEqual(NS.ItemFacts.Get(link(4001)).ilvl, 600, "the cached facts are not written")
end)

-- ---------------------------------------------------------------------------------------------
-- The queue: spacing and priority
-- ---------------------------------------------------------------------------------------------

test("inspect: one in flight at a time, spaced SPACING seconds apart", function()
    local _, m, I = party()
    I.Request(A); I.Request(B)
    m.advance(0)
    assertEqual(notifiedUnits(m), "party1", "B waits while A is in flight")
    arrive(m, A); ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh")
    m.advance(1.8)
    assertEqual(#m.inspect.notified, 1, "1.95s after A's send: still spaced")
    m.advance(0.05)
    assertEqual(notifiedUnits(m), "party1,party2")
    assertTrue(math.abs(m.inspect.notified[2].at - 2.0) < 1e-6, "exactly SPACING after the last send")
end)

test("inspect: looters first, then offer candidates, then warm-up; a later ask can raise a job", function()
    local _, m, I = party()
    I.Request(B, I.PRIORITY.offer)
    I.Request(C, I.PRIORITY.warmup)
    I.Request(A, I.PRIORITY.warmup)
    I.Request(A, I.PRIORITY.looter)
    I.Request(C, I.PRIORITY.offer)
    for _, guid in ipairs({ A, B, C }) do
        inspectNow(m, guid)
        m.advance(I.SPACING)
    end
    assertEqual(notifiedUnits(m), "party1,party2,party3", "A raised to looter; C raised to offer, after B by arrival")
end)

-- ---------------------------------------------------------------------------------------------
-- Timeouts and retries
-- ---------------------------------------------------------------------------------------------

test("inspect: no INSPECT_READY in 2.5s retries once, then the job fails with a timeout", function()
    local NS, m, I = party()
    local done = listen(NS)
    I.Request(A)
    m.advance(0)
    m.advance(2.4)
    assertEqual(#m.inspect.notified, 1)
    m.advance(0.1)
    assertEqual(#m.inspect.notified, 2, "re-queued and sent again (the spacing has run)")
    assertEqual(m.inspect.cleared, 1, "the timed-out inspect was this broker's: cleared")
    assertEqual(I.Get(A).status, "pending")
    m.advance(2.5)
    assertEqual(#m.inspect.notified, 2, "READY_ATTEMPTS sends in all")
    assertEqual(I.Get(A).status, "failed"); assertEqual(I.Get(A).reason, "timeout")
    assertEqual(table.concat(done, ","), A)
    assertEqual(I.QueueState().queued, 0)
end)

test("inspect: out of range waits without using an attempt, then sends once in range", function()
    local _, m, I = party(function(m) m.inspect.far.party1 = true end)
    I.Request(A)
    m.advance(10)
    assertEqual(#m.inspect.notified, 0)
    assertEqual(I.Get(A).status, "pending")
    m.inspect.far.party1 = nil
    m.advance(1)
    assertEqual(notifiedUnits(m), "party1", "the next recheck sends it")
    m.advance(2.5); m.advance(2.5)
    assertEqual(#m.inspect.notified, 2, "both attempts were still there to use")
end)

test("inspect: 25s out of range ends the job as outOfRange; CanInspect false waits the same way", function()
    local NS, m, I = party(function(m)
        m.inspect.far.party1 = true
        m.inspect.cannot.party2 = true
    end)
    local done = listen(NS)
    I.Request(A); I.Request(B)
    m.advance(24.5)
    assertEqual(I.Get(A).status, "pending")
    m.advance(1)
    assertEqual(I.Get(A).status, "outOfRange"); assertEqual(I.Get(A).reason, "range")
    assertEqual(I.Get(B).status, "outOfRange")
    assertEqual(#m.inspect.notified, 0)
    assertEqual(#done, 2)
end)

test("inspect: a GUID with no unit fails after 10s; an offline member waits the same way", function()
    local NS, m, I = party()
    m.units.party3.connected = false
    NS.Roster.Refresh("test")
    I.Request(STRANGER); I.Request(C)
    m.advance(9.5)
    assertEqual(I.Get(STRANGER).status, "pending")
    m.advance(1)
    assertEqual(I.Get(STRANGER).status, "failed"); assertEqual(I.Get(STRANGER).reason, "identity")
    assertEqual(I.Get(C).status, "failed", "offline: no unit to inspect")
    assertEqual(#m.inspect.notified, 0)
end)

test("inspect: an incomplete link is read again, 0.3s apart, and completes when it arrives", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    arrive(m, A)
    m.inventory.party1[5] = nil
    m.inventoryIDs.party1 = { [5] = 4005 }
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "pending", "slot 5 has an id but no link yet")
    m.advance(0.3)
    assertEqual(I.Get(A).status, "pending", "first retry: still missing")
    m.inventory.party1[5] = link(4005)
    m.advance(0.3)
    assertEqual(I.Get(A).status, "fresh")
    assertEqual(I.Get(A).gear[5].link, link(4005)); assertNil(I.Get(A).reason)
end)

test("inspect: still incomplete after three retries, the read is kept and says so", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    arrive(m, A)
    m.inventory.party1[1] = "|cnIQ4:|Hitem:4001::::::::90:::::|h[]|h|r"
    ready(m, A)
    m.advance(0.15 + 0.3 * 2)
    assertEqual(I.Get(A).status, "pending")
    m.advance(0.3)
    local e = I.Get(A)
    assertEqual(e.status, "fresh"); assertEqual(e.reason, "incomplete")
    assertNil(e.gear[1], "a nameless link is not kept"); assertEqual(e.gear[5].link, link(4005))
end)

-- ---------------------------------------------------------------------------------------------
-- The fast path, the hook and opportunistic reads
-- ---------------------------------------------------------------------------------------------

test("inspect: every link already readable completes at once, cached, with no inspect", function()
    local NS, m, I = party(function(m) arriveFull(m, A, 72) end)
    local done = listen(NS)
    I.Request(A); I.Request(B)
    m.advance(0)
    assertEqual(I.Get(A).status, "cached"); assertEqual(I.Get(A).specID, 72)
    assertEqual(notifiedUnits(m), "party2", "the next job goes at once: no inspect was spent")
    assertEqual(m.inspect.cleared, 0, "nothing to clear")
    assertEqual(done[1], A)
end)

test("inspect: a foreign inspect re-queues the job in flight, free, and resets the spacing", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    m.advance(1)
    m.NotifyInspect("target")          -- another addon, or the player
    assertNil(I.QueueState().inFlight)
    assertEqual(I.QueueState().queued, 1)
    m.advance(1.9)
    assertEqual(notifiedUnits(m), "party1,target")
    m.advance(0.1)
    assertEqual(notifiedUnits(m), "party1,target,party1", "SPACING after the foreign call")
    assertEqual(m.inspect.cleared, 0, "the taken-over inspect is not cleared")
    m.advance(2.5)
    assertEqual(#m.inspect.notified, 4, "the foreign call cost no attempt: a second send of A follows")
end)

test("inspect: a foreign inspect after the data arrived lets the read finish, and clears nothing", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    arrive(m, A); ready(m, A)
    m.advance(0.05)
    m.NotifyInspect("target")
    m.advance(0.1)
    assertEqual(I.Get(A).status, "fresh")
    assertEqual(m.inspect.cleared, 0)
end)

test("inspect: anyone's INSPECT_READY for a group member is read, completing its queued job", function()
    local NS, m, I = party(function(m) m.inspect.far.party2 = true end)
    local done = listen(NS)
    arrive(m, A, 73)
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh"); assertEqual(I.Get(A).specID, 73)
    I.Request(B)
    arrive(m, B, 256)
    ready(m, B)
    m.advance(0.15)
    assertEqual(I.Get(B).status, "fresh")
    assertEqual(I.QueueState().queued, 0, "the queued job is done")
    assertEqual(#m.inspect.notified, 0); assertEqual(m.inspect.cleared, 0)
    assertEqual(table.concat(done, ","), A .. "," .. B)
    ready(m, STRANGER)
    m.advance(1)
    assertNil(I.Get(STRANGER), "not a group member: ignored")
end)

test("inspect: the fast path needs neck, rings and trinkets; visible slots alone send the inspect", function()
    local _, m, I = party(function(m) arrive(m, A, 72) end)
    I.Request(A)
    m.advance(0)
    -- red under: a fast path that takes any complete read with one worn item
    assertEqual(I.Get(A).status, "pending", "the hidden slots read empty: not trusted")
    assertEqual(notifiedUnits(m), "party1")
    arriveFull(m, A, 72)
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh")
    assertEqual(I.Get(A).gear[11].link, link(4011))
end)

-- ---------------------------------------------------------------------------------------------
-- A read with no data
-- ---------------------------------------------------------------------------------------------

test("inspect: an INSPECT_READY whose data is gone by the read is never stored as fresh", function()
    local NS, m, I = party()
    local done = listen(NS)
    I.Request(A)
    m.advance(0)
    m.inventory.party1 = {}            -- cleared (ClearInspectPlayer) before the read
    ready(m, A)
    m.advance(0.15 + 0.3 * 3)
    -- red under: a read with no item at all completing as `fresh`
    assertEqual(I.Get(A).status, "pending", "re-queued like a timeout")
    assertNil(I.Get(A).gear)
    assertEqual(#done, 0)
    m.advance(I.SPACING)
    assertEqual(notifiedUnits(m), "party1,party1", "the second send")
    ready(m, A)
    m.advance(0.15 + 0.3 * 3)
    assertEqual(I.Get(A).status, "failed"); assertEqual(I.Get(A).reason, "empty")
    assertEqual(table.concat(done, ","), A, "InspectDone, once, when the job ends")
end)

test("inspect: the data arriving within the retries is read; a moved unit token is no data", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    m.inventory.party1 = {}
    ready(m, A)
    m.advance(0.15 + 0.3)
    arrive(m, A)
    m.advance(0.3)
    assertEqual(I.Get(A).status, "fresh", "a later retry found the data")
    m.advance(I.TTL + 1)
    I.Request(A)
    m.inventory.party1 = {}
    m.advance(0)
    arrive(m, A)
    m.units.party1 = nil               -- the token no longer names Brakk
    ready(m, A)
    m.advance(0.15 + 0.3 * 3)
    assertEqual(I.Get(A).gen, 1, "nothing read off the wrong unit")
    assertEqual(I.Get(A).status, "pending")
end)

test("inspect: an empty read nobody asked for is dropped, and the entry kept as it was", function()
    local _, m, I = party()
    I.Request(B)
    inspectNow(m, B)
    local before = I.Get(B)
    assertEqual(before.status, "fresh"); assertEqual(before.gen, 1)
    m.advance(I.INVALIDATE_GRACE + 1)
    m.inventory.party2 = {}            -- another addon's inspect of Lyra, cleared before our read
    ready(m, B)
    m.advance(0.15 + 0.3 * 3)
    assertEqual(I.Get(B).status, "fresh"); assertEqual(I.Get(B).gen, 1)
    assertEqual(I.Get(B).gear[1].link, link(4001), "the good read stays")
    ready(m, C)                        -- and one for a member never read
    m.advance(0.15 + 0.3 * 3)
    assertNil(I.Get(C), "no entry is made from no data")
end)

-- ---------------------------------------------------------------------------------------------
-- Combat and the inspect window
-- ---------------------------------------------------------------------------------------------

test("inspect: combat parks the queue, the job in flight still finishes, and its end resumes", function()
    local _, m, I = party()
    I.Request(A); I.Request(B)
    m.advance(0)
    m.inCombat = true
    m.__fire("PLAYER_REGEN_DISABLED")
    assertEqual(I.Get(B).status, "combatParked")
    assertTrue(I.QueueState().parked)
    arrive(m, A); ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh", "the job in flight finishes")
    m.advance(30)
    assertEqual(#m.inspect.notified, 1, "nothing sent while parked")
    assertEqual(I.Get(B).status, "combatParked", "and no wait runs out while parked")
    assertEqual(I.Request(C), "combatParked", "a request in combat is parked")
    m.inCombat = false
    m.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(I.Get(B).status, "pending")
    m.advance(0)
    assertEqual(notifiedUnits(m), "party1,party2")
end)

test("inspect: the queue waits while the inspect window is open", function()
    local _, m, I = party()
    m.InspectFrame = m.__stubFrame():Show()
    I.Request(A)
    m.advance(5)
    assertEqual(#m.inspect.notified, 0)
    m.InspectFrame:Hide()
    m.advance(1)
    assertEqual(notifiedUnits(m), "party1")
end)

-- ---------------------------------------------------------------------------------------------
-- The cache
-- ---------------------------------------------------------------------------------------------

test("inspect: with the old data still held, a request completes on the fast path", function()
    local _, m, I = party()
    I.Request(A)
    m.advance(0)
    arriveFull(m, A)
    ready(m, A)
    m.advance(0.15)
    m.advance(I.TTL)
    assertEqual(I.Request(A), "pending")
    m.advance(0)
    assertEqual(I.Get(A).status, "cached"); assertEqual(#m.inspect.notified, 1)
end)

test("inspect: a read is good for 600s; after that a request inspects again", function()
    local _, m, I = party()
    I.Request(A)
    inspectNow(m, A)
    m.advance(10)
    assertEqual(I.Request(A), "fresh", "good: nothing queued")
    assertTrue(I.IsGood(A))
    m.advance(I.TTL)
    assertFalse(I.IsGood(A))
    m.inventory.party1 = {}            -- the client no longer holds the old inspect
    assertEqual(I.Request(A), "pending")
    m.advance(0)
    assertEqual(#m.inspect.notified, 2)
end)

test("inspect: UNIT_INVENTORY_CHANGED marks a group member stale and re-queues it", function()
    local NS, m, I = party()
    I.Request(A)
    inspectNow(m, A)
    m.__fire("UNIT_INVENTORY_CHANGED", "party1")
    assertFalse(I.Get(A).stale == true, "the inspect's own echo is ignored")
    m.advance(I.INVALIDATE_GRACE + 0.1)
    m.__fire("UNIT_INVENTORY_CHANGED", "player")
    m.__fire("UNIT_INVENTORY_CHANGED", "target")
    assertEqual(I.QueueState().queued, 0, "your own unit and a stranger's are ignored")
    m.__fire("UNIT_INVENTORY_CHANGED", "party1")
    assertTrue(I.Get(A).stale); assertEqual(I.Get(A).status, "pending")
    assertEqual(I.Candidate(A).gear[1].link, link(4001), "the old read stays readable meanwhile")
    m.inventory.party1 = {}
    m.advance(0)
    assertEqual(#m.inspect.notified, 2)
    arrive(m, A); ready(m, A)
    m.advance(0.15)
    assertNil(I.Get(A).stale); assertEqual(I.Get(A).gen, 2)
    assertTrue(NS.Inspect.IsGood(A))
end)

test("inspect: the roster event drops the entries of members who left", function()
    local NS, m, I = party()
    I.Request(A)
    inspectNow(m, A)
    m.setGroup({ row(B, "Lyra", "PRIEST") })
    m.__fire("GROUP_ROSTER_UPDATE")
    assertNil(I.Get(A))
    assertEqual(NS.Roster.Count(), 2)
end)

-- ---------------------------------------------------------------------------------------------
-- Warm-up and scan
-- ---------------------------------------------------------------------------------------------

local function inDungeon(m)
    m.__context.inInstance, m.__context.instanceType = true, "party"
    m.instance.difficultyID = 1
end

test("inspect: 2s after a roster update in a tracked situation, the idle queue warms up", function()
    local _, m, I = party(inDungeon)
    m.__fire("GROUP_ROSTER_UPDATE")
    m.advance(1.9)
    assertEqual(I.QueueState().queued, 0)
    m.advance(0.1)
    assertEqual(I.QueueState().inFlight, A, "the first member is sent at once")
    assertEqual(I.QueueState().queued, 2)
    assertEqual(I.Get(B).status, "pending")
end)

test("inspect: entering an instance warms up too; untracked or busy, nothing is queued", function()
    local _, m = party(inDungeon)
    m.__fire("PLAYER_ENTERING_WORLD")
    m.advance(2)
    assertEqual(#m.inspect.notified, 1)
    local _, m2, I2 = party()
    m2.__fire("GROUP_ROSTER_UPDATE")
    m2.advance(5)
    assertEqual(#m2.inspect.notified, 0, "the open world is not tracked by default")
    assertNil(I2.Get(B))
    local _, m3, I3 = party(inDungeon)
    I3.Request(C, I3.PRIORITY.looter)
    m3.advance(0)
    m3.__fire("GROUP_ROSTER_UPDATE")
    m3.advance(2)
    assertNil(I3.Get(A), "the queue was not idle")
end)

test("inspect: Scan queues every other member that has no good read", function()
    local NS, m, I = party(function(m) arriveFull(m, B) end)
    I.Request(B)
    m.advance(0)
    assertEqual(I.Get(B).status, "cached")
    assertEqual(I.Scan("test"), 2, "Brakk and Vex; Lyra is good; you are never queued")
    assertNil(I.Request(NS.Roster.Player().guid), "your own gear is the gear snapshot's")
    assertNil(I.Get(NS.Roster.Player().guid))
end)

-- ---------------------------------------------------------------------------------------------
-- The candidate and InspectDone
-- ---------------------------------------------------------------------------------------------

test("inspect: the candidate carries the roster's class, the read spec and the hand flags", function()
    local NS, m, I = party()
    assertNil(I.Candidate(A), "nothing read yet")
    I.Request(A)
    inspectNow(m, A, 72)
    local c = I.Candidate(A)
    assertEqual(c.classFile, "WARRIOR"); assertEqual(c.specID, 72)
    assertTrue(c.dualWield); assertTrue(c.titanGrip, "Fury")
    assertFalse(c.isPlayer); assertNil(c.owned)
    assertEqual(c.gear[1].equipLoc, "INVTYPE_HEAD"); assertEqual(c.gear[2], false)
    local drop = NS.ItemFacts.Get(m.addItem(link(4100), plate("INVTYPE_HEAD", 630)))
    assertEqual(NS.Evaluate.Evaluate(drop, c, {}).verdict, "upgrade", "the kernel takes it as it is")
end)

test("inspect: InspectDone waits for the read's items to load", function()
    local NS, m, I = party()
    local done = listen(NS)
    I.Request(A)
    m.advance(0)
    arrive(m, A)
    m.items[link(4005)].loadsNeeded = 2
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh")
    assertEqual(#done, 0, "the chest is still loading")
    assertNil(I.Candidate(A).gear[5], "a slot still loading is absent")
    m.advance(0.4)
    assertEqual(#done, 0, "one load answered; the second is asked for")
    m.advance(0.4)
    assertEqual(table.concat(done, ","), A)
    assertEqual(I.Candidate(A).gear[5].ilvl, 610)
end)

test("inspect: one debug line per job", function()
    local NS, m, I = party()
    local lines = {}
    local real = NS.Debug
    NS.Debug = function(tag, fmt, ...)
        if tag == "INSPECT" then lines[#lines + 1] = fmt:format(...) end
        return real(tag, fmt, ...)
    end
    I.Request(A)
    m.advance(0); m.advance(1)
    arrive(m, A); ready(m, A)
    m.advance(0.15)
    NS.Debug = real
    assertEqual(#lines, 1, table.concat(lines, " | "))
    assertTrue(lines[1]:find("Brakk%-Testrealm: fresh") ~= nil, lines[1])
end)

-- ---------------------------------------------------------------------------------------------
-- Secrets and the stand-down
-- ---------------------------------------------------------------------------------------------

test("inspect: secret GUIDs, units and specs are never used", function()
    local _, m, I = party()
    installSecrets(m)
    assertNil(I.Request(T.secret(A)))
    ready(m, T.secret(A))
    m.__fire("UNIT_INVENTORY_CHANGED", T.secret("party1"))
    m.advance(1)
    assertEqual(I.QueueState().queued, 0)
    I.Request(A)
    m.advance(0)
    arrive(m, A)
    m.inspect.specs.party1 = T.secret(71)
    ready(m, A)
    m.advance(0.15)
    assertEqual(I.Get(A).status, "fresh"); assertNil(I.Get(A).specID)
end)

test("inspect: the stand-down clears this broker's inspect, every timer and the state", function()
    local NS, m, I = party(inDungeon)
    I.Request(A); I.Request(B)
    m.advance(0)
    m.__fire("GROUP_ROSTER_UPDATE")
    NS.addon:OnSlashCommand("disable")
    assertEqual(m.inspect.cleared, 1, "the inspect in flight was this broker's")
    assertEqual(#m.__timers(), 0, "no live timer")
    assertNil(NS.State.inspect)
    assertNil(I.Request(A), "stood down: nothing is queued")
    m.NotifyInspect("target")
    assertNil(NS.State.inspect, "the hook does nothing while stood down")
    NS.addon:OnSlashCommand("enable")
    assertEqual(I.Request(A), "pending")
    m.advance(0)
    assertEqual(m.inspect.notified[#m.inspect.notified].unit, "party1")
end)
