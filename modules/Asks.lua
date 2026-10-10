local _, NS = ...
-- modules/Asks.lua — the messaging edge (design spec §9.2-§9.3): asks, offers and announces sent
-- through NS.Compat.ChatSender inside pcall, queued under a restriction, flushed when it lifts,
-- canceled by a click or when the looter leaves, and confirmed in chat.
--
-- THE SPLIT. modules/Messaging.lua is the pure core (templates, tokens, the length check, the
-- one-ask guard, the queue's state machine) and holds no state; this edge holds the one book, reads
-- the restriction tracker, the roster, the feed and the `messages.*` settings, sends, and reports
-- each result back to the core. The UI (DW-33) and auto-ask (DW-54) call Request, Press and Cancel.
--
--   Request(kind, target, dropID, opts) -> state, reason
--     kind    "ask" | "offer" | "announce"
--     target  a member's GUID, "Name-Realm" or bare name (the looter for an ask, the candidate for
--             an offer); ignored for an announce, whose registry target is "group"
--     opts    { text = edited text (the edit-first popup), ctx = token overrides }
--     state   "sent" | "queued" | "failed" | "refused"; reason says why for the last two
--
-- THE PIPELINE (spec §9.2). The recipient is resolved through the roster to its Name-Realm (not in
-- the group, yourself or offline is refused); the token context is built from the drop record; the
-- core guards, expands and checks the length; under a restriction (NS.Restrictions.CanSendChat) the
-- ask is queued, else sent at once: `ChatSender()(text, "WHISPER", nil, NameRealm)` in pcall, or
-- the announce channel for an announce (`messages.announceChannel`: `auto` is INSTANCE_CHAT, then
-- RAID, then PARTY; never SAY or YELL). A raise is a failure with its message as the reason, a
-- client without a sender fails `noApi`, an announce outside a group fails `noChannel`; a failed
-- ask may be retried.
--
-- THE FLUSH. A RestrictionChanged that says chat may be sent, ENCOUNTER_END and
-- CHALLENGE_MODE_COMPLETED (each refreshing the restriction tracker first, since a lockdown can
-- lift with no event of its own) start a flush when something is queued: one ask at once, then one
-- every C.MESSAGE_FLUSH_INTERVAL seconds on a C_Timer, first in first out. A restriction that comes
-- back mid-flush stops it, and the rest wait for the next trigger.
--
-- CANCEL. Press on a queued ask cancels it (its button clicked again); GROUP_ROSTER_UPDATE cancels
-- every ask queued to a member who left, and every queued announce once you are out of a group.
--
-- CONFIRMATION (spec §9.3). One chat line per send through NS.Print ("Whispered Seta: [item]"); a
-- failure is logged under the MSG debug tag with its reason. AskStateChanged(dropID, state, kind,
-- target, reason) is sent on every move: queued, sent, failed, and "ready" after a cancel (reason
-- `canceled` or `left`).
--
-- TEST MODE (spec §11.6). In test mode, and for a test drop, nothing is sent: the text is printed
-- instead, the ask is marked sent, and no restriction queues it. The recipient is not looked up.
--
-- Stood down, a request is refused (`disabled`), the flush timer is canceled and every queued ask
-- is dropped: no trigger reaches it while down. The registry of sent asks is kept for the session.

NS.Asks = NS.Asks or {}
local A = NS.Asks
local M = NS.Messaging
local C = NS.Constants
local L = NS.L
local State = NS.State

local TAG = "MSG"

--- The registry target of an announce: one per drop, whatever the channel.
A.GROUP = "group"

A.FLUSH_INTERVAL = C.MESSAGE_FLUSH_INTERVAL

-- The channels an announce may name; SAY and YELL need a hardware event and are never used.
local CHANNELS = { INSTANCE_CHAT = true, RAID = true, PARTY = true }

local flushTimer

local function stoodDown()
    return NS.IsStoodDown ~= nil and NS.IsStoodDown()
end

local function now() return GetTime() end

local function store()
    local s = State.asks
    if not s then
        s = { book = M.NewBook(), sent = 0, failed = 0, refused = 0, flushes = 0 }
        State.asks = s
    end
    return s
end

local function plainString(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

local function shortName(name)
    return name:match("^([^%-]+)") or name
end

-- ── settings ────────────────────────────────────────────────────────────────────────────────

local function messages()
    local p = NS.db and NS.db.profile
    local m = p and p.messages
    return type(m) == "table" and m or {}
end

--- The `messages.*` settings the edge reads (DW-40 adds the rows; until then the spec defaults):
--- { oneAsk, templates, announceChannel }.
--- @return table
function A.Settings()
    local m = messages()
    return {
        oneAsk = m.oneAsk ~= false,
        templates = type(m.templates) == "table" and m.templates or {},
        announceChannel = CHANNELS[m.announceChannel] and m.announceChannel or "auto",
    }
end

--- The channel an announce goes to now: the stored one when it names a channel, else (auto)
--- INSTANCE_CHAT in an instance group, then RAID, then PARTY. Nil outside a group.
--- @return string|nil
function A.AnnounceChannel()
    local want = A.Settings().announceChannel
    if want ~= "auto" then return want end
    if IsInGroup(LE_PARTY_CATEGORY_INSTANCE or 2) then return "INSTANCE_CHAT" end
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- ── the recipient and the tokens ────────────────────────────────────────────────────────────

local function isTest(rec)
    return State.testMode == true or (rec ~= nil and rec.test == true)
end

local function whisperRecipient(target)
    local m = NS.Roster.Resolve(target)
    if not (m and m.fullName) then return nil, "notInGroup" end
    if m.isPlayer then return nil, "self" end
    if m.online == false then return nil, "offline" end
    return { key = m.fullName, name = m.name, guid = m.guid }
end

-- Who an ask goes to: { key (the registry target), name, guid }, or nil and the refusal reason.
local function recipient(kind, target, test)
    if kind == "announce" then return { key = A.GROUP } end
    local plain = plainString(target)
    if not plain then return nil, "noTarget" end
    if test then return { key = plain, name = shortName(plain) } end
    return whisperRecipient(plain)
end

local function gainOf(eval)
    local d = type(eval) == "table" and eval.ilvlDelta or nil
    if type(d) == "number" and d == d then return d end
    return nil
end

-- The slot's localized name: the client's INVTYPE_* GlobalString, else nil.
local function slotText(equipLoc)
    local key = plainString(equipLoc)
    return key and plainString(_G[key]) or nil
end

-- The verdict whose gain is {gain}: the looter's for an ask, the candidate's for an offer.
local function theirEval(kind, rec, who)
    if kind ~= "offer" then return rec.them end
    local c = who.guid and type(rec.candidates) == "table" and rec.candidates[who.guid] or nil
    return c and c.eval
end

local function dropContext(ctx, kind, rec, who)
    local f = type(rec.facts) == "table" and rec.facts or {}
    ctx.item, ctx.ilvl, ctx.slot = rec.link, f.ilvl, slotText(f.equipLoc)
    ctx.track = type(f.track) == "table" and f.track.name or nil
    ctx.gain, ctx.mygain = gainOf(theirEval(kind, rec, who)), gainOf(rec.me)
end

-- The token values of spec §9.1, from the drop record, with `extra` laid over them.
local function context(kind, rec, who, extra)
    local ctx = { player = who.name }
    if rec then dropContext(ctx, kind, rec, who) end
    if type(extra) == "table" then
        for k, v in pairs(extra) do ctx[k] = v end
    end
    return ctx
end

-- ── sending ─────────────────────────────────────────────────────────────────────────────────

local function changed(a, state, reason)
    NS.addon:SendMessage(NS.MSG.ASK_STATE_CHANGED, a.dropID, state or a.state, a.kind, a.target,
        reason or a.reason)
end

-- A raise's message as a reason; a secret or non-string one reads "error".
local function errorText(err)
    if NS.Compat.IsSecret(err) then return "error" end
    if type(err) == "string" and err ~= "" then return err end
    return "error"
end

-- The chat type and the whisper target of an ask, or nil when an announce has no channel.
local function route(a)
    if a.kind ~= "announce" then return "WHISPER", a.target end
    return A.AnnounceChannel(), nil
end

-- One send through the chat sender, in pcall. Answers ok and the chat type, or false and why.
local function send(a)
    local chatType, to = route(a)
    if not chatType then return false, "noChannel" end
    local sender = NS.Compat.ChatSender()
    if not sender then return false, "noApi" end
    local ok, err = pcall(sender, a.text, chatType, nil, to)
    if not ok then return false, errorText(err) end
    return true, chatType
end

local function itemOf(a)
    local rec = NS.LootFeed.Get(a.dropID)
    return rec and plainString(rec.link) or a.text
end

-- The confirmation line of spec §9.3.
local function confirm(a, chatType)
    if a.test then return NS.Print(L["Test mode, not sent: %s"]:format(a.text)) end
    if chatType == "WHISPER" then
        return NS.Print(L["Whispered %s: %s"]:format(shortName(a.target), itemOf(a)))
    end
    local label = plainString(_G[chatType]) or chatType
    NS.Print(L["Announced in %s: %s"]:format(label, itemOf(a)))
end

local function succeed(a, chatType)
    local s = store()
    M.MarkSent(s.book, a.key, now())
    s.sent = s.sent + 1
    NS.Debug(TAG, "sent %s to %s (%s), drop %s", a.kind, a.target, tostring(chatType), tostring(a.dropID))
    confirm(a, chatType)
end

local function fail(a, reason)
    local s = store()
    M.MarkFailed(s.book, a.key, reason)
    s.failed = s.failed + 1
    NS.Debug(TAG, "send failed: %s to %s, drop %s: %s", a.kind, a.target, tostring(a.dropID), reason)
end

-- Sends one ready ask (a test ask is printed instead), reports the result to the core and on the bus.
local function deliver(a)
    local ok, detail = true, "test"
    if not a.test then ok, detail = send(a) end
    if ok then succeed(a, detail) else fail(a, detail) end
    changed(a)
end

-- ── requests ────────────────────────────────────────────────────────────────────────────────

local function refused(reason, length)
    local s = store()
    s.refused = s.refused + 1
    NS.Debug(TAG, "refused: %s%s", tostring(reason), length and (" (" .. length .. " bytes)") or "")
    return "refused", reason
end

local function coreOpts(test)
    local cfg = A.Settings()
    return { canSend = test or NS.Restrictions.CanSendChat(), oneAsk = cfg.oneAsk,
        templates = cfg.templates, now = now() }
end

-- The core's answer acted on: a queued ask announced, a ready one sent.
local function act(res, test)
    if res.action == "refuse" then return refused(res.reason, res.length) end
    local a = res.ask
    a.test = test
    if res.action == "queue" then
        NS.Debug(TAG, "queued %s to %s, drop %s (%s)", a.kind, a.target, tostring(a.dropID),
            tostring(NS.Restrictions.ActiveReason()))
        changed(a)
        return "queued"
    end
    deliver(a)
    return a.state, a.reason
end

--- Ask, offer or announce (design spec §9.2 steps 1-4). See the header for the arguments.
--- @return string state  "sent" | "queued" | "failed" | "refused"
--- @return string|nil reason
function A.Request(kind, target, dropID, opts)
    if stoodDown() then return refused("disabled") end
    opts = type(opts) == "table" and opts or {}
    local rec = dropID ~= nil and NS.LootFeed.Get(dropID) or nil
    local test = isTest(rec)
    local who, why = recipient(kind, target, test)
    if not who then return refused(why) end
    local req = { kind = kind, target = who.key, dropID = dropID, text = opts.text,
        ctx = context(kind, rec, who, opts.ctx) }
    return act(M.Request(store().book, req, coreOpts(test)), test)
end

-- The registry target a request for `target` was filed under: the target itself when an ask is
-- filed under it, else the member's Name-Realm.
local function filedTarget(kind, target, dropID)
    if kind == "announce" then return A.GROUP end
    local plain = plainString(target)
    if not plain then return nil end
    if store().book.asks[M.Key(kind, plain, dropID)] then return plain end
    local m = NS.Roster.Resolve(plain)
    return m and m.fullName or plain
end

--- The state of one ask ("ready" when never asked, or canceled) and its reason.
--- @return string state
--- @return string|nil reason
function A.StateOf(kind, target, dropID)
    local key = filedTarget(kind, target, dropID)
    if not key then return "ready" end
    return M.StateOf(store().book, kind, key, dropID)
end

--- Cancel a queued ask (spec §9.2 step 6). Answers true when one was queued.
--- @return boolean
function A.Cancel(kind, target, dropID)
    local key = filedTarget(kind, target, dropID)
    local a = key and M.Cancel(store().book, M.Key(kind, key, dropID))
    if not a then return false end
    NS.Debug(TAG, "canceled %s to %s, drop %s", a.kind, a.target, tostring(a.dropID))
    changed(a, "ready", "canceled")
    return true
end

--- The ask button: a queued ask is canceled, anything else requested.
--- @return string state
--- @return string|nil reason
function A.Press(kind, target, dropID, opts)
    if A.StateOf(kind, target, dropID) == "queued" then
        A.Cancel(kind, target, dropID)
        return "ready", "canceled"
    end
    return A.Request(kind, target, dropID, opts)
end

-- ── the flush ───────────────────────────────────────────────────────────────────────────────

local function queuedCount()
    return M.Counts(store().book).queued
end

local flushStep

local function scheduleNext()
    if queuedCount() > 0 then flushTimer = C_Timer.NewTimer(A.FLUSH_INTERVAL, flushStep) end
end

-- One queued ask sent, the next one scheduled; stops while chat is restricted again.
flushStep = function()
    flushTimer = nil
    if stoodDown() or not NS.Restrictions.CanSendChat() then return end
    local a = M.Dequeue(store().book)
    if not a then return end
    deliver(a)
    scheduleNext()
end

--- Start a flush for `trigger` (C.MESSAGE_FLUSH_TRIGGERS) when chat may be sent and something is
--- queued. A flush in progress carries on. Answers true when one started.
--- @param trigger string
--- @return boolean
function A.Flush(trigger)
    if stoodDown() or flushTimer then return false end
    local s = store()
    if not M.ShouldFlush(s.book, trigger, NS.Restrictions.CanSendChat()) then return false end
    s.flushes = s.flushes + 1
    NS.Debug(TAG, "flush (%s): %d queued", tostring(trigger), queuedCount())
    flushStep()
    return true
end

--- Whether a flush is waiting for its next send.
--- @return boolean
function A.IsFlushing()
    return flushTimer ~= nil
end

-- ── the roster ──────────────────────────────────────────────────────────────────────────────

-- The distinct targets with a queued ask, in queue order.
local function queuedTargets(book)
    local out, seen = {}, {}
    for _, key in ipairs(book.queue) do
        local a = book.asks[key]
        if a and a.state == "queued" and not seen[a.target] then
            seen[a.target] = true
            out[#out + 1] = a
        end
    end
    return out
end

local function gone(a)
    if a.test then return false end
    if a.target == A.GROUP then return not IsInGroup() end
    return NS.Roster.Resolve(a.target) == nil
end

--- GROUP_ROSTER_UPDATE: every ask queued to a member who left is canceled (spec §9.2 step 6), and
--- every queued announce once you are out of a group. Answers how many were canceled.
--- @return number
function A.OnRosterChanged()
    local book, n = store().book, 0
    for _, first in ipairs(queuedTargets(book)) do
        if gone(first) then
            for _, a in ipairs(M.CancelTarget(book, first.target)) do
                n = n + 1
                NS.Debug(TAG, "canceled %s to %s, drop %s: left the group", a.kind, a.target, tostring(a.dropID))
                changed(a, "ready", "left")
            end
        end
    end
    return n
end

-- ── diagnostics ─────────────────────────────────────────────────────────────────────────────

--- Diagnostics: the registry by state ({ asks, ready, queued, sent, failed }) plus the edge's
--- counts (sends, failures, refusals, flushes) and whether a flush is in progress.
--- @return table
function A.Stats()
    local s = store()
    local c = M.Counts(s.book)
    c.sends, c.failures, c.refusals, c.flushes = s.sent, s.failed, s.refused, s.flushes
    c.flushing = flushTimer ~= nil
    return c
end

--- Every queued ask, first in first out. Read them, never write them.
--- @return table
function A.Queued()
    local book, out = store().book, {}
    for _, key in ipairs(book.queue) do
        local a = book.asks[key]
        if a and a.state == "queued" then out[#out + 1] = a end
    end
    return out
end

-- ── events, messages and the lifecycle ──────────────────────────────────────────────────────

-- ENCOUNTER_END and CHALLENGE_MODE_COMPLETED are shared with the feed and the situation edge, and
-- GROUP_ROSTER_UPDATE with the roster, whose row comes first so it is fresh here
-- (core/DropWatcher.lua's dispatcher).
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "ENCOUNTER_END", "OnAskFlushEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "CHALLENGE_MODE_COMPLETED", "OnAskFlushEvent" }
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "GROUP_ROSTER_UPDATE", "OnAskRosterEvent" }

function NS.addon.OnAskFlushEvent(_, event)
    NS.Restrictions.Refresh(event)
    A.Flush(event)
end

function NS.addon.OnAskRosterEvent()
    A.OnRosterChanged()
end

-- The RestrictionChanged receiver: tracked, so the stand-down takes it down and the stand-up
-- replays it. Without the bus library it is a bare target, unregistered here instead.
local TRACKED = LibStub and LibStub("LibKa0s-Bus-1.0", true) ~= nil
local target = NS.Bus:NewTarget()

local function listen()
    if not target then return end
    target:RegisterMessage(NS.MSG.RESTRICTION_CHANGED, function(_, _, canSendChat)
        if canSendChat == true then A.Flush("restrictionLifted") end
    end)
end
listen()

-- Every queued ask dropped, quietly: the bus is already down.
local function dropQueued()
    local book = store().book
    local n = 0
    for _, a in ipairs(A.Queued()) do
        if M.Cancel(book, a.key) then n = n + 1 end
    end
    if n > 0 then NS.Debug(TAG, "stand-down: %d queued asks dropped", n) end
end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    if flushTimer then flushTimer:Cancel() end
    flushTimer = nil
    dropQueued()
    if target and not TRACKED then target:UnregisterAllMessages() end
end
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if not TRACKED then listen() end
end
