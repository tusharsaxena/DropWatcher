local _, NS = ...
-- core/SimSetup.lua — the simulator's answer seam, on LibKa0s-Sim-1.0 (library-stack-§7; simulator
-- spec §2, §5): while a simulation runs, every client answer core/Compat.lua gives is asked of the
-- simulator first.
--
-- THE SEAM. At load, straight after core/Compat.lua, core/CompatWorld.lua and core/CompatItem.lua
-- and before anything reads a member, Sim:NewSeam wraps every NS.Compat function but the pure ones
-- (PURE) in place, once. While a session runs (modules/Sim.lua's NS.Sim) the call goes to the
-- member's provider; otherwise straight to the member, so a session with no simulation costs one
-- field test per call. This file names no client API: the compat family (core/Compat*.lua) stays the
-- only caller (compat). A member added to NS.Compat after this file loads escapes the wrap; the seam's
-- Unwrapped() lists it, and tests/test_sim_e2e.lua asserts that list is empty (the load-order guard).
--
-- PROVIDERS. The simulator registers `fn(fallback, ...)` per member name (NS.SimSeam:SetProvider)
-- and answers what it invents, handing anything else to `fallback`. For an ordinary member the
-- fallback is the live member, so the client still answers what the simulator does not invent
-- (your own gear, the item cache, the journal). For a GUARDED member the fallback is this file's
-- safe answer, and the live member is never reached while a simulation runs, whatever a provider
-- or a caller does (simulator spec §5):
--   ChatSender            a sender that prints `[sim] <channel> <target>: <text>` and counts it:
--                         nothing is ever whispered or posted
--   NotifyInspect, ClearInspectPlayer   no client call: a real player is never inspected
--   InitiateTrade         no client call: no real trade opens; the hand-over is printed instead
--
-- LIVE READS. NS.SimSeam:Live(fn, ...) runs `fn` with the ordinary members answering for the client
-- again (the guarded ones stay guarded): the simulator's own safety checks read the real world
-- through it.
--
-- LIBRARY ABSENT. NS.SimSeam is an inert stub (Live calls fn, SetProvider does nothing, Keys and
-- Unwrapped answer {}), nothing is wrapped and no simulation can start (modules/Sim.lua's stub).
--
-- The guarded answers count into NS.SimHost.counts (modules/Sim.lua publishes it), read at call time.

local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)
local L = NS.L

-- The members that answer for nobody: the secret guards and the pure text helpers. Never wrapped.
local PURE = {
    IsSecret = true, CanAccess = true, IsSafeKey = true, FormatToPattern = true, DecodeDuration = true,
    ParseTradeTimeRemaining = true, ReadTooltipLine = true, IsRestrictionStateActive = true,
}

-- ── the guarded answers ─────────────────────────────────────────────────────────────────────

-- One printed line for a send that a simulation kept local.
local function printSend(text, chatType, _, target)
    local c = NS.SimHost.counts
    c.sends = c.sends + 1
    local channel = tostring(chatType or "?")
    if target ~= nil then
        NS.Print(L["[sim] %s to %s: %s"]:format(channel, tostring(target), tostring(text)))
    else
        NS.Print(L["[sim] %s: %s"]:format(channel, tostring(text)))
    end
end

local function handOver(line, unit)
    local c = NS.SimHost.counts
    c.handOvers = c.handOvers + 1
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
GUARDED.InitiateTrade = function(unit) return handOver("[sim] Would open a trade with %s.", unit) end

-- ── the seam ────────────────────────────────────────────────────────────────────────────────

-- The reference seam stub (LibKa0s tests/test_sim_stub.lua): the live seam's four members, inert.
local function newSeamStub()
    local seam = {}
    function seam.SetProvider() end
    function seam.Live(_, fn, ...) return fn(...) end
    function seam.Keys() return {} end
    function seam.Unwrapped() return {} end
    return seam
end

if Sim then
    NS.SimSeam = Sim:NewSeam(NS.Compat, { name = "DropWatcher", pure = PURE, guarded = GUARDED })
else
    NS.SimSeam = newSeamStub()
end
