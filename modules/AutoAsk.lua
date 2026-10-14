local _, NS = ...
-- modules/AutoAsk.lua — auto-ask (design spec §9.4): an opt-in ask sent on your behalf, a few
-- seconds after the boss kill or the drop, for a likely tradeable upgrade someone else looted.
--
-- OFF BY DEFAULT (`messages.autoAsk.enabled`). A drop qualifies by the toast's own test
-- (NS.Toast.Qualifies, pure): someone else's drop, `upgrade` for you by at least
-- `messages.autoAsk.minGain` item levels (default 5), with a trade estimate of `likely` or `yes`.
-- Each drop is considered on DropAdded and on each DropUpdated (an inspect can turn its trade
-- `likely` later) and is scheduled at most once a session. Only drops the feed recorded after
-- auto-ask was turned on are considered, so turning it on never asks for the drops already there;
-- a profile switch, copy or reset that turns it on counts the same (OnProfileReloaded).
--
-- THE TIMING (DueAt, pure). The ask is due `messages.autoAsk.delay` seconds (3 to 30, default 10)
-- after the later of the drop and the last ENCOUNTER_END. While an encounter is in progress
-- (between ENCOUNTER_START and ENCOUNTER_END) nothing is due: the waiting asks are held, and the
-- encounter's end schedules them again from that moment. A player who leaves mid-fight (a hearth,
-- a release, a teleport) may never hear that ENCOUNTER_END, so a loading screen or a new zone
-- (PLAYER_ENTERING_WORLD, ZONE_CHANGED_NEW_AREA) ends the hold too, unless the restriction tracker
-- still reports the Encounter restriction (a zone line crossed inside the fight); then the
-- restriction's lifting (RESTRICTION_CHANGED) ends it, since the client may report that after the
-- loading screen. A drop that qualifies after its time has
-- passed is asked at once. A test drop is timed from when it is considered, since its age is made up.
--
-- THE SEND. When it is due the drop is checked again (still on, still in the feed, still
-- qualifying, never asked, not received, its looter still in the group) and the ask goes through
-- the messaging edge's Request (modules/Asks.lua), which guards, queues under a restriction, sends
-- and confirms it in chat like a click would; the edit-first box is never opened for it. It fills
-- the plain `ask` template (an upgrade never takes the transmog one). In test mode nothing is
-- sent: the messaging edge prints the text instead.
--
-- CANCELED (spec §9.4) when you ask yourself (any AskStateChanged for the drop's ask), when the
-- looter leaves the group (GROUP_ROSTER_UPDATE), when the item is received (HistoryChanged and
-- the history's `received`), when auto-ask is turned off, and on the stand-down. A canceled drop is
-- never scheduled again this session.
--
-- THE NOTICE. The first time auto-ask is turned on (its row's reaction, OnEnabledChanged), one chat
-- notice says what it does; `global.notices.autoAsk` remembers it was said, for every character.
--
-- PURE: DueAt and Config's clamp take plain values; test_auto_ask drives them. The edge below reads
-- the feed, the settings, the asks, the roster and the history, and keeps one C_Timer per waiting ask.

NS.AutoAsk = NS.AutoAsk or {}
local AA = NS.AutoAsk
local L = NS.L

local TAG = "MSG"

AA.MIN_DELAY, AA.MAX_DELAY = 3, 30

-- ── the pure core ───────────────────────────────────────────────────────────────────────────

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- When an ask is due: `delay` seconds after the later of the drop (`droppedAt`) and the last
--- encounter's end (`endedAt`, nil when none). Every time is GetTime()'s.
--- @param droppedAt number
--- @param endedAt number|nil
--- @param delay number
--- @return number
function AA.DueAt(droppedAt, endedAt, delay)
    local base = num(droppedAt) or 0
    local ended = num(endedAt)
    if ended and ended > base then base = ended end
    return base + (num(delay) or 0)
end

--- The delay in force, clamped to MIN_DELAY..MAX_DELAY; a value that is not a number is the
--- default's 10.
--- @param v any
--- @return number
function AA.ClampDelay(v)
    local d = num(v) or 10
    return math.min(math.max(d, AA.MIN_DELAY), AA.MAX_DELAY)
end

--- The `messages.autoAsk.*` settings, through the schema seam: { enabled, delay, minGain }.
--- @return table
function AA.Config()
    return {
        enabled = NS.Setting("messages.autoAsk.enabled") == true,
        delay = AA.ClampDelay(NS.Setting("messages.autoAsk.delay")),
        minGain = num(NS.Setting("messages.autoAsk.minGain")) or 5,
    }
end

-- ── the edge's state ────────────────────────────────────────────────────────────────────────

local pending = {}       -- [drop id] = { target, at, timer, dueAt }: the asks waiting
local considered = {}    -- [drop id] = true: scheduled, sent or canceled once; never again
local enabledAt = 0      -- GetTime() when auto-ask was last turned on (0: at load)
local wasOn              -- the last `enabled` seen (nil until first read)
local inEncounter = false
local movedWhileHeld = false -- a world event came while the Encounter restriction still held
local endedAt            -- GetTime() of the last ENCOUNTER_END
local counts = { scheduled = 0, sent = 0, canceled = 0 }

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function now() return GetTime() end

-- ── scheduling ──────────────────────────────────────────────────────────────────────────────

local function stopTimer(p)
    if p.timer then p.timer:Cancel() end
    p.timer, p.dueAt = nil, nil
end

-- Arm one waiting ask's timer, unless an encounter is in progress (its end arms it).
local function arm(id)
    local p = pending[id]
    stopTimer(p)
    if inEncounter then return end
    p.dueAt = AA.DueAt(p.at, endedAt, AA.Config().delay)
    p.timer = C_Timer.NewTimer(math.max(p.dueAt - now(), 0), function()
        p.timer = nil
        AA.Fire(id)
    end)
end

local function received(id)
    return NS.History ~= nil and NS.History.OutcomeOf(id) == "received"
end

local function asked(target, id)
    return NS.Asks.StateOf("ask", target, id) ~= "ready"
end

-- Why a drop is not (or no longer) to be asked for, or nil when it is.
local function blocker(rec, cfg)
    if not rec then return "gone" end
    if not NS.Toast.Qualifies(rec, cfg.minGain) then return "notQualifying" end
    local target = NS.AskTargetOf(rec)
    if not target then return "noTarget" end
    if asked(target, rec.id) then return "asked" end
    if received(rec.id) then return "received" end
    return nil
end

local function fresh(rec)
    return rec.test == true or (num(rec.at) or 0) >= enabledAt
end

--- Consider a drop for an automatic ask (DropAdded, DropUpdated): scheduled once when it qualifies.
--- @param id any the drop's id
--- @return boolean scheduled
function AA.Consider(id)
    if considered[id] or stoodDown() then return false end
    local cfg = AA.Config()
    if wasOn == nil then wasOn = cfg.enabled end
    if not cfg.enabled then return false end
    local rec = NS.LootFeed.Get(id)
    if blocker(rec, cfg) or not fresh(rec) then return false end
    considered[id] = true
    pending[id] = { target = NS.AskTargetOf(rec), at = rec.test and now() or rec.at, test = rec.test == true }
    counts.scheduled = counts.scheduled + 1
    arm(id)
    NS.Debug(TAG, "auto-ask scheduled: drop %s to %s%s", tostring(id), pending[id].target,
        inEncounter and ", after the encounter" or "")
    return true
end

--- Cancel a drop's automatic ask, waiting or not: it is never scheduled again this session.
--- @param id any
--- @param why string|nil the reason, for the debug log
--- @return boolean canceled whether one was waiting
function AA.Cancel(id, why)
    considered[id] = true
    local p = pending[id]
    if not p then return false end
    stopTimer(p)
    pending[id] = nil
    counts.canceled = counts.canceled + 1
    NS.Debug(TAG, "auto-ask canceled: drop %s (%s)", tostring(id), tostring(why))
    return true
end

local function cancelAll(why)
    local ids = {}
    for id in pairs(pending) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do AA.Cancel(id, why) end
    return #ids
end

local function looterGone(p)
    return not p.test and NS.Roster.Resolve(p.target) == nil
end

--- A waiting ask is due: checked once more, then requested through the messaging edge.
--- @param id any
--- @return string|nil state NS.Asks.Request's answer, nil when it was not sent
function AA.Fire(id)
    local p = pending[id]
    if not p then return nil end
    stopTimer(p)
    pending[id] = nil
    local cfg = AA.Config()
    local why = (stoodDown() or not cfg.enabled) and "off" or blocker(NS.LootFeed.Get(id), cfg)
    if not why and looterGone(p) then why = "left" end
    if why then
        counts.canceled = counts.canceled + 1
        NS.Debug(TAG, "auto-ask dropped when due: drop %s (%s)", tostring(id), why)
        return nil
    end
    local state, reason = NS.Asks.Request("ask", p.target, id)
    if state == "sent" or state == "queued" then counts.sent = counts.sent + 1 end
    NS.Debug(TAG, "auto-ask: drop %s to %s -> %s%s", tostring(id), p.target, tostring(state),
        reason and (" (" .. tostring(reason) .. ")") or "")
    return state
end

-- ── the notice ──────────────────────────────────────────────────────────────────────────────

local function notices()
    local g = NS.addon and NS.addon.db and NS.addon.db.global
    if not g then return nil end
    if type(g.notices) ~= "table" then g.notices = {} end
    return g.notices
end

--- Print the one-time notice, unless it was said before on this account. Answers true when printed.
--- @return boolean
function AA.Notice()
    local n = notices()
    if not n or n.autoAsk == true then return false end
    n.autoAsk = true
    local cfg = AA.Config()
    NS.Print(L["Auto-ask is on: when someone else loots a likely tradeable upgrade of %d or more item levels for you, your ask template is whispered to them %d seconds after the boss kill or the drop."]
        :format(cfg.minGain, cfg.delay))
    NS.Print(L["It holds off when you ask yourself, they leave or you get the item. Turn it off in Settings > Messages > Auto-ask."])
    return true
end

--- The `messages.autoAsk.enabled` row's reaction: turned on, only drops from now on count and the
--- notice is said once; turned off, every waiting ask is canceled.
--- @param on boolean
function AA.OnEnabledChanged(on)
    wasOn = on == true
    if on == true then
        enabledAt = now()
        AA.Notice()
    else
        cancelAll("off")
    end
end

--- A profile switch, copy or reset (core/DropWatcher.lua's reloadProfile): no row reaction runs,
--- so the incoming `enabled` is read here. Turned on by it, only drops from now on count; off,
--- every waiting ask is canceled. The one-time notice stays the row's alone.
function AA.OnProfileReloaded()
    local on = AA.Config().enabled
    if on and wasOn ~= true then
        enabledAt = now()
    elseif not on then
        cancelAll("off")
    end
    wasOn = on
end

-- ── edges ───────────────────────────────────────────────────────────────────────────────────

--- ENCOUNTER_START: the waiting asks are held until the encounter ends.
function AA.OnEncounterStart()
    inEncounter, movedWhileHeld = true, false
    for _, p in pairs(pending) do stopTimer(p) end
end

--- ENCOUNTER_END: every waiting ask is due its delay after now.
function AA.OnEncounterEnd()
    inEncounter, movedWhileHeld, endedAt = false, false, now()
    for id in pairs(pending) do arm(id) end
end

local function encounterRestricted()
    return NS.Restrictions.ActiveSet().encounter == true
end

local function leaveEncounter()
    NS.Debug(TAG, "auto-ask: left the encounter without its end; the waiting asks are due")
    AA.OnEncounterEnd()
end

--- PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA: an encounter held with no Encounter
--- restriction left in force is over for this player, so it ends as ENCOUNTER_END would. While the
--- restriction still holds (a zone line crossed inside the fight, or its lifting not yet heard) the
--- move is remembered, and the restriction's lifting ends the hold then (OnRestrictionChanged).
function AA.OnWorldChanged()
    if not inEncounter then return end
    if encounterRestricted() then
        movedWhileHeld = true
        return
    end
    leaveEncounter()
end

--- RESTRICTION_CHANGED: after a world event that came while the Encounter restriction held, its
--- lifting ends the hold (the client may report it after the loading screen).
function AA.OnRestrictionChanged()
    if not (inEncounter and movedWhileHeld) or encounterRestricted() then return end
    leaveEncounter()
end

--- GROUP_ROSTER_UPDATE: a waiting ask to a looter who left is canceled.
function AA.OnRosterChanged()
    for id, p in pairs(pending) do
        if looterGone(p) then AA.Cancel(id, "left") end
    end
end

--- HistoryChanged: a waiting ask for a drop now received is canceled.
function AA.OnHistoryChanged()
    for id in pairs(pending) do
        if received(id) then AA.Cancel(id, "received") end
    end
end

--- The diagnostics' and the suites' read: { enabled, delay, minGain, waiting, scheduled, sent,
--- canceled, inEncounter, nextDue (seconds, or nil) }.
--- @return table
function AA.Stats()
    local cfg = AA.Config()
    local waiting, nextDue = 0, nil
    for _, p in pairs(pending) do
        waiting = waiting + 1
        if p.dueAt and (not nextDue or p.dueAt < nextDue) then nextDue = p.dueAt end
    end
    return { enabled = cfg.enabled, delay = cfg.delay, minGain = cfg.minGain, waiting = waiting,
        scheduled = counts.scheduled, sent = counts.sent, canceled = counts.canceled,
        inEncounter = inEncounter, nextDue = nextDue and math.max(nextDue - now(), 0) or nil }
end

-- ENCOUNTER_START, ENCOUNTER_END, GROUP_ROSTER_UPDATE, PLAYER_ENTERING_WORLD and
-- ZONE_CHANGED_NEW_AREA are shared (core/DropWatcher.lua fans each out in declaration order, so the
-- roster is fresh here).
local EVENTS = {
    { "ENCOUNTER_START", "OnAutoAskEncounterStart", AA.OnEncounterStart },
    { "ENCOUNTER_END", "OnAutoAskEncounterEnd", AA.OnEncounterEnd },
    { "GROUP_ROSTER_UPDATE", "OnAutoAskRosterEvent", AA.OnRosterChanged },
    { "PLAYER_ENTERING_WORLD", "OnAutoAskWorldEvent", AA.OnWorldChanged },
    { "ZONE_CHANGED_NEW_AREA", "OnAutoAskWorldEvent", AA.OnWorldChanged },
}
for _, row in ipairs(EVENTS) do
    local fn = row[3]
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { row[1], row[2] }
    NS.addon[row[2]] = function() fn() end
end

-- Tracked, so the stand-down takes them down and the stand-up replays them. Without the bus
-- library it is a bare target, unregistered here instead (NS.Bus.tracked says which).
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    local M = NS.MSG
    target:RegisterMessage(M.DROP_ADDED, function(_, id) AA.Consider(id) end)
    target:RegisterMessage(M.DROP_UPDATED, function(_, id) AA.Consider(id) end)
    target:RegisterMessage(M.ASK_STATE_CHANGED, function(_, id, _, kind)
        if kind == "ask" and pending[id] then AA.Cancel(id, "asked") end
    end)
    target:RegisterMessage(M.HISTORY_CHANGED, function() AA.OnHistoryChanged() end)
    target:RegisterMessage(M.RESTRICTION_CHANGED, function() AA.OnRestrictionChanged() end)
end
listen()

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    cancelAll("disabled")
    inEncounter, movedWhileHeld = false, false
    if target and not NS.Bus.tracked then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not NS.Bus.tracked then listen() end
end
