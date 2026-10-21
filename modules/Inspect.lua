local _, NS = ...
-- modules/Inspect.lua — the inspect broker (design spec §8): another group member's worn gear and
-- spec, read through the client's inspect, one member at a time, politely.
--
--   entry = { status, at, gear = { [slot] = { link, ilvl } | false }, specID, reason, gen, stale,
--             loading }
--
-- STATUS. `pending` (queued or in flight), `fresh` (read after an INSPECT_READY, ours or anyone's),
-- `cached` (read at once without an inspect: the client already held every link, the fast path),
-- `outOfRange` (the range wait ran out), `combatParked` (queued while the queue is parked for
-- combat) and `failed` (`reason`: `identity` when the GUID found no unit in time, `timeout` when
-- INSPECT_READY never came, `empty` when every read found no data). `fresh` and `cached` are good
-- for TTL seconds; `gen` counts the reads.
-- `gear` holds each slot's link and the level its tooltip showed (an inspected link carries the
-- unscaled level; the link's own is the fallback), false for an empty slot, absent for a slot the
-- client never completed. Candidate(guid) turns it into the verdict kernel's candidate.
--
-- THE QUEUE. Request(guid, priority) queues a member, unless its entry is still good: looters of
-- drops awaiting a verdict first, then Offer-panel candidates, then warm-up jobs, each in arrival
-- order. One NotifyInspect is in flight at a time, at least SPACING seconds after the last one
-- (anyone's). Before a job is sent its gates are asked: the GUID must name an online member's unit
-- (IDENTITY_WAIT seconds, then `failed`), and the client must allow the inspect and the unit be in
-- range (RANGE_WAIT seconds, then `outOfRange`; waiting for range costs no attempt). The whole queue
-- waits while Blizzard's inspect window is open, and parks in combat: the job in flight finishes or
-- times out, and the PLAYER_REGEN_ENABLED edge resumes the rest. A job no gate lets through is
-- asked again every RECHECK seconds.
--
-- READING. On the job's INSPECT_READY the slots 1-17 are read READ_DELAY seconds later; a slot whose
-- item id is known but whose link is not (or is nameless) is incomplete, and the read is retried up
-- to LINK_TRIES times, LINK_RETRY seconds apart, then kept as it is (`reason` = `incomplete`).
-- A read that finds no item at all, or a unit that no longer names the GUID, is NO DATA (the
-- client's inspect was cleared before the read, by Blizzard's inspect window or another addon): it
-- is retried the same way, then never stored. The job in flight is then re-queued like a timeout
-- (`failed`, `empty` once its sends are used up); a read nobody asked for is dropped and the entry
-- kept as it was.
-- No INSPECT_READY within READY_TIMEOUT seconds re-queues the job, READY_ATTEMPTS sends in all.
-- ClearInspectPlayer is called only for an inspect this broker started and nobody took over. If
-- every link reads before any inspect, the job completes at once as `cached`: only when the
-- slots an uninspected unit does not show (neck, rings, trinkets: HIDDEN_SLOTS) each hold an item,
-- so the client's answer can only come from inspect data it still holds.
--
-- COURTESY. NotifyInspect is hooked (core/Compat.lua): a foreign inspect resets the spacing and
-- re-queues the job in flight unless its data has already arrived, at no cost in attempts. An
-- INSPECT_READY for any other group member, from anyone's inspect, is read the same way.
--
-- THE CACHE. Memory only, TTL seconds. UNIT_INVENTORY_CHANGED for a group unit marks its entry stale
-- and re-queues it as a warm-up job; an echo within INVALIDATE_GRACE seconds of the read is ignored,
-- because the inspect's own arrival can raise it. Entries of members who left are dropped on the
-- next roster event.
--
-- WARM-UP. WARMUP_DELAY seconds after GROUP_ROSTER_UPDATE, or after entering an instance, every
-- other member is queued as a warm-up job, when the current situation is tracked and the queue is
-- idle. Scan() does the same on demand (`/dw scan` and the Scan group button, M3 and M4).
--
-- InspectDone(guid) is sent when a job ends: after a read, once every link's item facts have
-- loaded (or been given up on), and at once for `outOfRange` and `failed`. One debug line per job.
-- Stood down, every timer is canceled, an inspect this broker started is cleared, and the state
-- dropped; the hook stays installed (it cannot be removed) and does nothing.

NS.Inspect = NS.Inspect or {}
local I = NS.Inspect
local CD = NS.ClassData
local State = NS.State
local Perf = NS.Perf

local TAG = "INSPECT"

I.SPACING = 2.0
I.READY_TIMEOUT = 2.5
I.READY_ATTEMPTS = 2
I.READ_DELAY = 0.15
I.LINK_TRIES = 3
I.LINK_RETRY = 0.3
I.RANGE_WAIT = 25
I.IDENTITY_WAIT = 10
I.RECHECK = 1.0
I.TTL = 600
I.INVALIDATE_GRACE = 5
I.WARMUP_DELAY = 2

--- Queue priorities, lower first.
I.PRIORITY = { looter = 1, offer = 2, warmup = 3 }

local FIRST_SLOT, LAST_SLOT = 1, 17

--- The slots the client knows only from inspect data (neck, rings, trinkets): the fast path needs
--- an item in each before it trusts a read made without an inspect.
I.HIDDEN_SLOTS = { 2, 11, 12, 13, 14 }

-- The broker's timers: the pump, the ready timeout, the warm-up, and one read per GUID.
local timers = { reads = {} }

-- True while this broker is calling NotifyInspect itself, so the hook can tell it from a foreign one.
local notifying = false

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function store()
    local s = State.inspect
    if not s then
        s = { entries = {}, queue = {}, seq = 0, inFlight = nil, lastNotifyAt = nil, parked = false }
        State.inspect = s
    end
    return s
end

local function after(delay, fn)
    return C_Timer.NewTimer(delay, fn)
end

local function cancel(t)
    if t then t:Cancel() end
end

local function now()
    return GetTime()
end

-- ── entries and the queue ───────────────────────────────────────────────────────────────────

local function entryOf(guid)
    local s = store()
    local e = s.entries[guid]
    if not e then
        e = { status = "pending", gen = 0 }
        s.entries[guid] = e
    end
    return e
end

-- Whether an entry holds a read still good: fresh or cached, not stale, inside the TTL.
local function isGood(e)
    if not e or e.stale then return false end
    if e.status ~= "fresh" and e.status ~= "cached" then return false end
    return now() - e.at < I.TTL
end

local function findJob(guid)
    for i, job in ipairs(store().queue) do
        if job.guid == guid then return job, i end
    end
    return nil
end

local function removeJob(guid)
    local _, i = findJob(guid)
    if i then table.remove(store().queue, i) end
end

local function byPriority(a, b)
    if a.priority ~= b.priority then return a.priority < b.priority end
    return a.seq < b.seq
end

local function isParked()
    return store().parked or not NS.Restrictions.CanInspect()
end

local function waitingStatus()
    return isParked() and "combatParked" or "pending"
end

local function push(job)
    local q = store().queue
    q[#q + 1] = job
    table.sort(q, byPriority)
    entryOf(job.guid).status = waitingStatus()
end

local function logJob(guid, e, extra)
    local m = NS.Roster.Get(guid)
    NS.Debug(TAG, "inspect %s: %s%s spec=%s slots=%s%s", tostring(m and m.fullName or guid),
        tostring(e.status), e.reason and (" (" .. tostring(e.reason) .. ")") or "",
        tostring(e.specID), tostring(e.worn or 0), extra or "")
end

local schedulePump

-- A job that ends without a read: outOfRange or failed.
local function finish(guid, status, reason)
    removeJob(guid)
    local e = entryOf(guid)
    e.status, e.reason, e.at = status, reason, now()
    logJob(guid, e)
    NS.addon:SendMessage(NS.MSG.INSPECT_DONE, guid)
end

-- ── the flight ──────────────────────────────────────────────────────────────────────────────

-- The flight is over: its timeout canceled, and the client's inspect target released when it is
-- still this broker's.
local function endFlight(f)
    local s = store()
    if s.inFlight == f then s.inFlight = nil end
    cancel(timers.ready)
    timers.ready = nil
    if f.ours then NS.Compat.ClearInspectPlayer() end
end

-- The flight ends without a read: re-queued while sends are left, else `failed` with `reason`.
local function retryOrFail(f, reason)
    endFlight(f)
    if f.job.attempts < I.READY_ATTEMPTS then
        push(f.job)
    else
        finish(f.guid, "failed", reason)
    end
    schedulePump(0)
end

local function onReadyTimeout()
    timers.ready = nil
    local f = store().inFlight
    if not f then return end
    retryOrFail(f, "timeout")
end

-- ── reading ─────────────────────────────────────────────────────────────────────────────────

-- One slot: its { link, ilvl }, false when empty, or nil and true when the client knows an item
-- there but not its full link.
local function readSlot(unit, slot)
    local Compat = NS.Compat
    local link = Compat.InventoryItemLink(unit, slot)
    if not link then
        if Compat.InventoryItemID(unit, slot) then return nil, true end
        return false
    end
    if link:find("[]", 1, true) then return nil, true end
    return { link = link, ilvl = Compat.InventoryItemLevel(unit, slot) }
end

-- Slots 1-17 of `unit`: { items, missing (incomplete slots), worn (slots with an item) }.
local function readSlots(unit)
    local t0 = Perf.on and debugprofilestop()
    local snap = { items = {}, missing = 0, worn = 0 }
    for slot = FIRST_SLOT, LAST_SLOT do
        local item, incomplete = readSlot(unit, slot)
        if incomplete then
            snap.missing = snap.missing + 1
        else
            snap.items[slot] = item
            if item then snap.worn = snap.worn + 1 end
        end
    end
    if t0 then Perf.Note("inspect.read", debugprofilestop() - t0) end
    return snap
end

-- Load every read link's facts; InspectDone once all have answered (at once when none waits).
local function loadFacts(guid, e)
    local gen = e.gen
    local function done()
        if e.gen ~= gen or stoodDown() then return end
        e.loading = e.loading - 1
        if e.loading == 0 then NS.addon:SendMessage(NS.MSG.INSPECT_DONE, guid) end
    end
    e.loading = 1
    for _, item in pairs(e.gear) do
        if item then
            local _, status = NS.ItemFacts.Request(item.link, done)
            if status == "loading" then e.loading = e.loading + 1 end
        end
    end
    done()
end

-- A read is in: store it, end the job and its flight, and move the queue on.
local function complete(guid, unit, snap, status)
    local s = store()
    if s.inFlight and s.inFlight.guid == guid then endFlight(s.inFlight) end
    removeJob(guid)
    local e = entryOf(guid)
    local m = NS.Roster.Get(guid)
    e.status, e.at, e.gear, e.gen, e.stale = status, now(), snap.items, e.gen + 1, nil
    e.reason = snap.missing > 0 and "incomplete" or nil
    e.worn = snap.worn
    e.specID = NS.Compat.InspectSpecID(unit) or e.specID or (m and m.specID)
    if e.specID then NS.Roster.SetSpec(guid, e.specID) end
    logJob(guid, e)
    loadFacts(guid, e)
    schedulePump(0)
end

local scheduleRead

-- Whether `unit` still names `guid` (the client may have moved the token since the event).
local function unitNames(unit, guid)
    local live = NS.Compat.UnitGUID(unit)
    return NS.Compat.IsSafeKey(live) and live == guid
end

-- A read with nothing in it: the inspect data was gone. The job in flight is retried like a
-- timeout; a read nobody asked for leaves the entry as it was.
local function noData(guid)
    local f = store().inFlight
    if f and f.guid == guid then return retryOrFail(f, "empty") end
    NS.Debug(TAG, "inspect %s: no data in the read, dropped", tostring(guid))
end

local function readAfterReady(guid, unit, tries)
    local snap = unitNames(unit, guid) and readSlots(unit) or nil
    local empty = snap == nil or (snap.worn == 0 and snap.missing == 0)
    if (empty or snap.missing > 0) and tries < I.LINK_TRIES then
        return scheduleRead(guid, unit, tries + 1)
    end
    if empty then return noData(guid) end
    complete(guid, unit, snap, "fresh")
end

scheduleRead = function(guid, unit, tries)
    cancel(timers.reads[guid])
    local delay = tries == 0 and I.READ_DELAY or I.LINK_RETRY
    timers.reads[guid] = after(delay, function()
        timers.reads[guid] = nil
        readAfterReady(guid, unit, tries)
    end)
end

-- ── the pump ────────────────────────────────────────────────────────────────────────────────

-- The unit an online member with this GUID has now, or nil.
local function unitOf(guid)
    local m = NS.Roster.Get(guid)
    if not (m and m.online and m.unit) then return nil end
    local live = NS.Compat.UnitGUID(m.unit)
    if not NS.Compat.IsSafeKey(live) or live ~= guid then return nil end
    return m.unit
end

-- Starts (or keeps) the job's wait in `field`; ends the job once it has waited `limit` seconds.
local function waitFor(job, field, limit, status, reason)
    job[field] = job[field] or now()
    if now() - job[field] >= limit then finish(job.guid, status, reason) end
    return nil
end

-- The job's unit when every gate lets it through now; nil while it waits (or once it has ended).
local function gate(job)
    local unit = unitOf(job.guid)
    if not unit then return waitFor(job, "identitySince", I.IDENTITY_WAIT, "failed", "identity") end
    job.identitySince = nil
    local Compat = NS.Compat
    if not (Compat.CanInspectUnit(unit) and Compat.InInspectRange(unit)) then
        return waitFor(job, "rangeSince", I.RANGE_WAIT, "outOfRange", "range")
    end
    job.rangeSince = nil
    return unit
end

-- The first job, in priority order, whose gates let it through, with its unit.
local function pick()
    local q = store().queue
    local jobs = {}
    for i, job in ipairs(q) do jobs[i] = job end
    for _, job in ipairs(jobs) do
        local unit = gate(job)
        if unit then return job, unit end
    end
    return nil
end

local function send(job, unit)
    local s = store()
    job.attempts = job.attempts + 1
    s.inFlight = { job = job, guid = job.guid, unit = unit, ours = true }
    s.lastNotifyAt = now()
    entryOf(job.guid).status = "pending"
    notifying = true
    NS.Compat.NotifyInspect(unit)
    notifying = false
    timers.ready = after(I.READY_TIMEOUT, onReadyTimeout)
end

-- Whether a read made without an inspect can be trusted: complete, and an item in every slot the
-- client knows only from inspect data (an empty answer there may just be data it never had).
local function trustedWithoutInspect(snap)
    if snap.missing > 0 then return false end
    for _, slot in ipairs(I.HIDDEN_SLOTS) do
        if not snap.items[slot] then return false end
    end
    return true
end

-- The fast path, else the inspect.
local function dispatch(job, unit)
    removeJob(job.guid)
    local snap = readSlots(unit)
    if trustedWithoutInspect(snap) then return complete(job.guid, unit, snap, "cached") end
    send(job, unit)
end

local function spacingLeft()
    local last = store().lastNotifyAt
    if not last then return 0 end
    return last + I.SPACING - now()
end

--- Move the queue on: send the next job whose gates pass, when nothing is in flight, the queue is
--- not parked and the spacing has run. Re-arms itself while jobs wait.
function I.Pump()
    local s = store()
    if stoodDown() or s.inFlight or #s.queue == 0 or isParked() then return end
    local wait = spacingLeft()
    if wait > 0 then return schedulePump(wait) end
    if NS.Compat.IsInspectFrameShown() then return schedulePump(I.RECHECK) end
    local job, unit = pick()
    if job then return dispatch(job, unit) end
    if #s.queue > 0 then schedulePump(I.RECHECK) end
end

schedulePump = function(delay)
    if timers.pump or stoodDown() then return end
    timers.pump = after(delay, function()
        timers.pump = nil
        I.Pump()
    end)
end

-- ── the public surface ──────────────────────────────────────────────────────────────────────

local function isPlayer(guid)
    local me = NS.Roster.Player()
    return me ~= nil and me.guid == guid
end

-- Queue `guid`, or raise the priority of its job already queued or in flight.
local function enqueue(guid, priority)
    local s = store()
    if s.inFlight and s.inFlight.guid == guid then
        s.inFlight.job.priority = math.min(s.inFlight.job.priority, priority)
        return
    end
    local job = findJob(guid)
    if job then
        job.priority = math.min(job.priority, priority)
        table.sort(s.queue, byPriority)
        return
    end
    s.seq = s.seq + 1
    push({ guid = guid, priority = priority, seq = s.seq, attempts = 0 })
end

--- Ask for a member's gear and spec. Answers the entry's status: "fresh" or "cached" when its read
--- is still good (nothing is queued), else "pending" (or "combatParked"). Nil for your own GUID
--- (the gear snapshot is yours), a GUID that cannot key an entry, or while stood down.
--- @param guid string
--- @param priority number|nil one of I.PRIORITY (warm-up when nil)
--- @return string|nil status
function I.Request(guid, priority)
    if stoodDown() or not NS.Compat.IsSafeKey(guid) or type(guid) ~= "string" then return nil end
    if isPlayer(guid) then return nil end
    local e = store().entries[guid]
    if isGood(e) then return e.status end
    enqueue(guid, priority or I.PRIORITY.warmup)
    schedulePump(0)
    return entryOf(guid).status
end

--- Queue every other member of the group as a warm-up job (`/dw scan`, the Scan group button).
--- @param cause string|nil for the debug line
--- @return number queued how many members were queued (members with a good read are skipped)
function I.Scan(cause)
    local n = 0
    for _, m in ipairs(NS.Roster.Members()) do
        if not m.isPlayer then
            local status = I.Request(m.guid, I.PRIORITY.warmup)
            if status == "pending" or status == "combatParked" then n = n + 1 end
        end
    end
    NS.Debug(TAG, "scan: %s queued (%s)", tostring(n), tostring(cause))
    return n
end

--- A member's entry, or nil. The table is the broker's own: read it, never write it.
--- @param guid string
--- @return table|nil
function I.Get(guid)
    if not NS.Compat.IsSafeKey(guid) then return nil end
    return store().entries[guid]
end

--- Whether a member's read is still good (fresh or cached, not stale, inside the TTL).
--- @param guid string
--- @return boolean
function I.IsGood(guid)
    return isGood(I.Get(guid))
end

local function copy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

-- A read's slots as the kernel's gear: each item's cached facts copied, at the level read. A slot
-- whose facts have not loaded is absent (not read yet), as in the gear snapshot.
local function gearOf(e)
    local out = {}
    for slot, item in pairs(e.gear) do
        if item == false then
            out[slot] = false
        else
            local facts = NS.ItemFacts.Get(item.link)
            if facts then
                local c = copy(facts)
                c.ilvl, c.slot = item.ilvl or facts.ilvl, slot
                out[slot] = c
            end
        end
    end
    return out
end

--- Spec §5.1's candidate for a member, for NS.Evaluate.Evaluate, or nil before any read. Its
--- class is the roster's, its spec the inspect's (else the roster's); `owned` is unknown for
--- another player and left nil, as are the `prefs`. `offSpecGear(specID)` (feedback-19 spec §0)
--- is the worn gear alone, since an inspect cannot see bags: each worn item that spec could wear,
--- false where it could not (NS.OffSpec.WornGear).
--- @param guid string
--- @return table|nil
function I.Candidate(guid)
    local e = I.Get(guid)
    if not (e and e.gear) then return nil end
    local m = NS.Roster.Get(guid)
    local classFile = m and m.classFile
    local specID = e.specID or (m and m.specID)
    local gear = gearOf(e)
    return {
        classFile = classFile, specID = specID, isPlayer = false, gear = gear,
        dualWield = CD.DualWieldFor(classFile, specID), titanGrip = CD.TitanGripFor(classFile, specID),
        offSpecGear = function(x) return NS.OffSpec.WornGear(gear, NS.OffSpec.Who(classFile, x)) end,
    }
end

--- The queue as the diagnostics report shows it: its length, the GUID in flight (or nil), whether
--- it is parked, and the seconds until the spacing allows the next send.
--- @return table { queued, inFlight, parked, spacingLeft }
function I.QueueState()
    local s = store()
    return {
        queued = #s.queue, inFlight = s.inFlight and s.inFlight.guid or nil, parked = isParked(),
        spacingLeft = math.max(0, spacingLeft()),
    }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

--- INSPECT_READY(guid): the job in flight is read after READ_DELAY; any other group member's
--- inspect, anyone's, is read the same way.
--- @param guid any
function I.OnInspectReady(guid)
    if stoodDown() or not NS.Compat.IsSafeKey(guid) then return end
    local f = store().inFlight
    if f and f.guid == guid then
        cancel(timers.ready)
        timers.ready, f.ready = nil, true
        return scheduleRead(guid, f.unit, 0)
    end
    local m = NS.Roster.Get(guid)
    if m and not m.isPlayer and m.unit then scheduleRead(guid, m.unit, 0) end
end

--- NotifyInspect was called (the hook). A foreign call resets the spacing and takes over the
--- flight: the job in flight is re-queued, at no cost in attempts, unless its data has arrived.
function I.OnNotifyInspect()
    if notifying or stoodDown() then return end
    local s = store()
    s.lastNotifyAt = now()
    local f = s.inFlight
    if not f then return end
    f.ours = false
    if f.ready then return end
    endFlight(f)
    f.job.attempts = f.job.attempts - 1
    push(f.job)
    schedulePump(I.SPACING)
end

--- A PLAYER_REGEN edge: `fighting` parks the queue; its end resumes it.
--- @param fighting boolean
function I.OnCombatEdge(fighting)
    local s = store()
    s.parked = fighting and true or false
    if fighting then
        cancel(timers.pump)
        timers.pump = nil
    end
    for _, job in ipairs(s.queue) do entryOf(job.guid).status = waitingStatus() end
    if #s.queue > 0 then
        NS.Debug(TAG, "queue %s: %d waiting", fighting and "parked for combat" or "resumed after combat", #s.queue)
    end
    if not fighting then schedulePump(0) end
end

--- UNIT_INVENTORY_CHANGED(unit): a group member's read goes stale and is re-queued as a warm-up.
--- @param unit any
function I.OnInventoryChanged(unit)
    if NS.Compat.IsSecret(unit) or type(unit) ~= "string" or unit == "player" then return end
    local guid = NS.Compat.UnitGUID(unit)
    if not NS.Compat.IsSafeKey(guid) or not NS.Roster.Get(guid) then return end
    local e = store().entries[guid]
    if not isGood(e) or now() - e.at < I.INVALIDATE_GRACE then return end
    e.stale = true
    I.Request(guid, I.PRIORITY.warmup)
end

local function warmup(cause)
    local s = store()
    if s.inFlight or #s.queue > 0 then return end
    if not NS.Situations.IsTracking() then return end
    I.Scan(cause)
end

--- Arm the warm-up WARMUP_DELAY seconds from now (a second call restarts the wait).
--- @param cause string|nil
function I.ScheduleWarmup(cause)
    if stoodDown() then return end
    cancel(timers.warmup)
    timers.warmup = after(I.WARMUP_DELAY, function()
        timers.warmup = nil
        warmup(cause)
    end)
end

--- Forget a member entirely: its entry, its queued job, its pending read, and its flight (the
--- simulator's stop, for the members it invented). Answers whether anything was held.
--- @param guid string
--- @return boolean
function I.Forget(guid)
    local s = State.inspect
    if not s or guid == nil then return false end
    local held = s.entries[guid] ~= nil or findJob(guid) ~= nil
    removeJob(guid)
    if s.inFlight and s.inFlight.guid == guid then endFlight(s.inFlight); held = true; schedulePump(0) end
    cancel(timers.reads[guid])
    timers.reads[guid] = nil
    s.entries[guid] = nil
    return held
end

-- Drop the entries of members who left (nothing queued or in flight for them).
local function prune()
    local s = store()
    for guid in pairs(s.entries) do
        local busy = findJob(guid) or (s.inFlight and s.inFlight.guid == guid)
        if not busy and not NS.Roster.Get(guid) then s.entries[guid] = nil end
    end
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- GROUP_ROSTER_UPDATE and PLAYER_ENTERING_WORLD are shared (core/DropWatcher.lua's dispatcher);
-- this module's rows come after the roster's, so the roster is fresh when they run. So are both
-- PLAYER_REGEN edges, after core/DropWatcher.lua's, which hands the edge to the restriction
-- tracker first.
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "INSPECT_READY", "OnInspectReadyEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "UNIT_INVENTORY_CHANGED", "OnInspectInventoryEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "GROUP_ROSTER_UPDATE", "OnInspectRosterEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_ENTERING_WORLD", "OnInspectWorldEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_DISABLED", "OnInspectCombatEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_REGEN_ENABLED", "OnInspectCombatEvent" }

function NS.addon.OnInspectReadyEvent(_, _, guid)
    I.OnInspectReady(guid)
end

function NS.addon.OnInspectInventoryEvent(_, _, unit)
    I.OnInventoryChanged(unit)
end

function NS.addon.OnInspectRosterEvent(_, event)
    prune()
    I.ScheduleWarmup(event)
end

function NS.addon.OnInspectWorldEvent(_, event)
    if NS.Compat.InstanceState() then I.ScheduleWarmup(event) end
end

function NS.addon.OnInspectCombatEvent(_, event)
    I.OnCombatEdge(event == "PLAYER_REGEN_DISABLED")
end

-- Installed once, at load: a hook cannot be removed, so it checks the latch itself.
NS.Compat.HookNotifyInspect(function() I.OnNotifyInspect() end)

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    local s = State.inspect
    if s and s.inFlight then endFlight(s.inFlight) end
    cancel(timers.pump); cancel(timers.ready); cancel(timers.warmup)
    for _, t in pairs(timers.reads) do cancel(t) end
    timers = { reads = {} }
    State.inspect = nil
end
