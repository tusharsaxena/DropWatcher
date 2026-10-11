local _, NS = ...
-- core/SimSeam.lua — the simulator's answer seam (simulator spec §2, §5): while a simulation runs,
-- every client answer core/Compat.lua gives is asked of NS.Sim first.
--
-- THE SEAM. At load, right after core/Compat.lua and before anything reads it, each NS.Compat
-- member that answers for the client (every function but the pure ones in PURE) is wrapped once.
-- While NS.Sim.active is true the call goes to NS.Sim.Answer(key, live, ...); otherwise straight to
-- the member, so a session with no simulation costs one boolean test per call. The wrap is the
-- `if NS.Sim.active then return NS.Sim.Answer(...) end` line each member would carry, written once
-- here so core/Compat.lua does not grow. This file names no client API: core/Compat.lua stays the
-- only caller (compat-§1).
--
-- PROVIDERS. The simulator registers `fn(fallback, ...)` per member name (SetProvider) and answers
-- what it invents, handing anything else to `fallback`. Without a provider the fallback answers.
-- For an ordinary member the fallback is the live member, so the client still answers what the
-- simulator does not invent (your own gear, the item cache, the journal). For a GUARDED member the
-- fallback is this file's safe answer, and the live member is never reached while a simulation
-- runs, whatever a provider or a caller does (simulator spec §5):
--   ChatSender            a sender that prints `[sim] <channel> <target>: <text>` and counts it:
--                         nothing is ever whispered or posted
--   NotifyInspect, ClearInspectPlayer   no client call: a real player is never inspected
--   PickupBagItem, DropItemOnUnit, InitiateTrade, ClearCursor   no client call: no real trade
--                         opens and nothing leaves the bags; the hand-over is printed instead
--
-- LIVE READS. Sim.Live(fn, ...) runs `fn` with the ordinary members answering for the client again
-- (the guarded ones stay guarded): the simulator's own safety checks read the real world through it.
--
-- The session itself (start, stop, the refusals, the session-only history log) is
-- modules/Sim.lua's; this file holds only what Compat needs at call time.

NS.Sim = NS.Sim or {}
local Sim = NS.Sim
local Compat = NS.Compat
local L = NS.L

--- True while a simulation runs (modules/Sim.lua sets it). Read on every Compat call.
Sim.active = false

-- True while Sim.Live runs: the ordinary members answer for the client.
Sim.bypass = false

-- What the guarded answers did this session: { sends, handOvers }. Reset by modules/Sim.lua.
Sim.counts = { sends = 0, handOvers = 0 }

-- The members that answer for nobody: the secret guards and the pure text helpers. Never wrapped.
local PURE = {
    IsSecret = true, CanAccess = true, IsSafeKey = true, FormatToPattern = true, DecodeDuration = true,
    ParseTradeTimeRemaining = true, ReadTooltipLine = true, IsRestrictionStateActive = true,
}

local providers = {}

-- ── the guarded answers ─────────────────────────────────────────────────────────────────────

-- One printed line for a send that a simulation kept local.
local function printSend(text, chatType, _, target)
    Sim.counts.sends = Sim.counts.sends + 1
    local channel = tostring(chatType or "?")
    if target ~= nil then
        NS.Print(L["[sim] %s to %s: %s"]:format(channel, tostring(target), tostring(text)))
    else
        NS.Print(L["[sim] %s: %s"]:format(channel, tostring(text)))
    end
end

local function handOver(line, unit)
    Sim.counts.handOvers = Sim.counts.handOvers + 1
    NS.Print(L[line]:format(tostring(unit)))
    return true
end

local function yes() return true end

-- Keyed by the NS.Compat member names, written as fields so test_compat's seam-only scan (which
-- skips a name read off a table) never mistakes a key for a client call.
local GUARDED = {}
GUARDED.ChatSender = function() return printSend end
GUARDED.NotifyInspect = yes
GUARDED.ClearInspectPlayer = yes
GUARDED.PickupBagItem = yes
GUARDED.ClearCursor = yes
GUARDED.DropItemOnUnit = function(unit) return handOver("[sim] Would hand the item to %s.", unit) end
GUARDED.InitiateTrade = function(unit) return handOver("[sim] Would open a trade with %s.", unit) end

-- ── the seam ────────────────────────────────────────────────────────────────────────────────

--- Whether member `key` is guarded: its live member is never reached while a simulation runs.
--- @param key string
--- @return boolean
function Sim.IsGuarded(key)
    return GUARDED[key] ~= nil
end

--- Answer member `key` for the simulation: its provider, handed the fallback (the guarded answer,
--- else the live member), or the fallback alone.
--- @param key string the NS.Compat member's name
--- @param live function the live member
--- @return any the member's answers
function Sim.Answer(key, live, ...)
    local fallback = GUARDED[key] or live
    local provider = providers[key]
    if provider then return provider(fallback, ...) end
    return fallback(...)
end

--- Register (or, with nil, remove) the provider of member `key`: `fn(fallback, ...)`.
--- @param key string
--- @param fn function|nil
function Sim.SetProvider(key, fn)
    providers[key] = fn
end

--- Run `fn(...)` with the ordinary members answering for the client (the guarded ones do not).
--- @param fn function
--- @return any fn's answers
function Sim.Live(fn, ...)
    local was = Sim.bypass
    Sim.bypass = true
    local out = { pcall(fn, ...) }
    Sim.bypass = was
    if not out[1] then error(out[2], 0) end
    return unpack(out, 2, table.maxn(out))
end

-- One wrapped member: the seam first while a simulation runs.
local function wrap(key, live)
    return function(...)
        if Sim.active and (GUARDED[key] or not Sim.bypass) then return Sim.Answer(key, live, ...) end
        return live(...)
    end
end

local keys = {}
for key, member in pairs(Compat) do
    if type(member) == "function" and not PURE[key] then keys[#keys + 1] = key end
end
for _, key in ipairs(keys) do Compat[key] = wrap(key, Compat[key]) end

--- The members the seam wraps, sorted (diagnostics and the suites).
--- @return table
function Sim.SeamKeys()
    local out = {}
    for i, key in ipairs(keys) do out[i] = key end
    table.sort(out)
    return out
end
