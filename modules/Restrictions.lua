local _, NS = ...
-- modules/Restrictions.lua — what Blizzard's 12.0 addon restrictions allow right now (design spec
-- §4): whether a chat message may be sent, an inspect asked for, a trade opened, and the reason
-- the window's badge names.
--
-- THREE SOURCES, all through core/Compat.lua:
--   * ADDON_RESTRICTION_STATE_CHANGED (type, state): the type's state as the event said it, kept
--     as a HINT per type, because the event fires while the restriction is still Activating and
--     the client's own answer may not say so yet. The state arrives as a number (the
--     AddOnRestrictionState) or a boolean; a secret one reads as active.
--   * C_ChatInfo.InChatMessagingLockdown(), polled on every read (a secret answer is locked).
--   * Combat: the PLAYER_REGEN edge when one has been seen (core/DropWatcher.lua hands it over,
--     because the flag can lag the edge), else InCombatLockdown(); the Combat type counts too.
--
-- A type is active when its hint OR the client says so: a restriction is never assumed lifted
-- until both agree. The answers are read live on every call, so a caller is never behind the
-- client; RESTRICTION_CHANGED (reason, canSendChat) is sent when the four answers move, from the
-- event, both combat edges and the stand-up. A lockdown that lifts with no event of its own is
-- picked up by the next read, and by Refresh, which the messaging edge (modules/Asks.lua) calls on
-- ENCOUNTER_END and CHALLENGE_MODE_COMPLETED.
--
-- Reasons, in the badge's priority order: encounter, challengeMode, pvpMatch, chat (the Chat
-- type), chatLockdown, combat. The Map type is tracked and reported but blocks nothing: it is
-- active for the whole of a dungeon (docs/midnight-quirks.md). A type the client adds later is
-- reported under its own enum name and blocks nothing until it is classified here.

NS.Restrictions = NS.Restrictions or {}
local R = NS.Restrictions
local State = NS.State

local TAG = "RES"

-- Enum.AddOnRestrictionType member name -> reason key.
local REASON_BY_NAME = {
    Combat = "combat", Encounter = "encounter", ChallengeMode = "challengeMode",
    PvPMatch = "pvpMatch", Map = "map", Chat = "chat",
}

-- The reasons that stop a chat message, in the order ActiveReason reports them.
local CHAT_BLOCKERS = { "encounter", "challengeMode", "pvpMatch", "chat", "chatLockdown" }

-- Every reason ActiveReason may answer, in priority order.
local PRIORITY = { "encounter", "challengeMode", "pvpMatch", "chat", "chatLockdown", "combat" }

-- ── reading the client ──────────────────────────────────────────────────────────────────────

local function hints()
    State.restrictionHints = State.restrictionHints or {}
    return State.restrictionHints
end

-- True when the PLAYER_REGEN edge (or, before one, the client's flag) says the player is fighting.
local function inCombat()
    local edge = State.combatEdge
    if edge ~= nil then return edge end
    return InCombatLockdown() == true
end

-- The reason key for an enum member name: the known ones by table, any other by its own name.
local function reasonFor(name)
    return REASON_BY_NAME[name] or name
end

-- Adds the active restriction types to `set`, keyed by reason.
local function addTypes(set)
    local Compat = NS.Compat
    local h = hints()
    for name, value in pairs(Compat.RestrictionTypes()) do
        if Compat.IsSafeKey(value) and (h[value] or Compat.IsRestrictionActive(value)) then
            set[reasonFor(name)] = true
        end
    end
end

--- Every reason in effect now, as a set { [reason] = true }. Read live.
--- @return table
function R.ActiveSet()
    local set = {}
    addTypes(set)
    if NS.Compat.InChatMessagingLockdown() then set.chatLockdown = true end
    if inCombat() then set.combat = true end
    return set
end

local function anyOf(set, list)
    for _, reason in ipairs(list) do
        if set[reason] then return reason end
    end
    return nil
end

--- True when a chat message (an ask, an offer, an announce) may be sent now.
--- @return boolean
function R.CanSendChat()
    return anyOf(R.ActiveSet(), CHAT_BLOCKERS) == nil
end

--- True when an inspect may be asked for now (spec §8: never in combat).
--- @return boolean
function R.CanInspect()
    return not R.ActiveSet().combat
end

--- True while the player is fighting: the PLAYER_REGEN edge, else (before one) the client's flag.
--- @return boolean
function R.InCombat()
    return inCombat()
end

--- True when a trade may be opened now (spec §4: the trade helper guards combat).
--- @return boolean
function R.CanTrade()
    return not R.ActiveSet().combat
end

--- The reason that matters most now, for the window's badge, or nil when nothing the addon does
--- is restricted (the Map type alone is nil).
--- @return string|nil
function R.ActiveReason()
    return anyOf(R.ActiveSet(), PRIORITY)
end

--- The four answers at once: { reason, canSendChat, canInspect, canTrade }, from one read.
--- @return table
function R.Snapshot()
    local set = R.ActiveSet()
    return {
        reason      = anyOf(set, PRIORITY),
        canSendChat = anyOf(set, CHAT_BLOCKERS) == nil,
        canInspect  = not set.combat,
        canTrade    = not set.combat,
    }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

local UNRESTRICTED = "none|true|true|true"

local function signature(s)
    return ("%s|%s|%s|%s"):format(s.reason or "none", tostring(s.canSendChat),
        tostring(s.canInspect), tostring(s.canTrade))
end

--- Re-read the client. Sends RESTRICTION_CHANGED (reason, canSendChat) when any of the four
--- answers moved since the last send (before the first, since "nothing restricted").
--- @param cause string|nil the event (or `standUp`) that asked, for the debug line
--- @return boolean changed
function R.Refresh(cause)
    local s = R.Snapshot()
    local sig = signature(s)
    local prev = State.restrictionSignature or UNRESTRICTED
    if sig == prev then return false end
    State.restrictionSignature = sig
    NS.Debug(TAG, "restrictions %s -> %s (%s)", prev, sig, tostring(cause))
    NS.addon:SendMessage(NS.MSG.RESTRICTION_CHANGED, s.reason, s.canSendChat)
    return true
end

-- The hint an event's state gives: true or false, or nil when it says nothing readable.
local function stateHint(state)
    local Compat = NS.Compat
    if Compat.IsSecret(state) then return true end
    if state == nil then return nil end
    return Compat.IsRestrictionStateActive(state)
end

--- ADDON_RESTRICTION_STATE_CHANGED (type, state): records the type's hint, then refreshes. A secret
--- or missing type cannot key a hint, so only the client's own answers decide then.
function R.OnRestrictionStateChanged(rtype, state)
    if NS.Compat.IsSafeKey(rtype) then
        local hint = stateHint(state)
        if hint == false then hint = nil end
        hints()[rtype] = hint
    end
    return R.Refresh("ADDON_RESTRICTION_STATE_CHANGED")
end

--- A PLAYER_REGEN edge: `fighting` is true on DISABLED and false on ENABLED.
function R.OnCombatEdge(fighting)
    State.combatEdge = fighting and true or false
    return R.Refresh(fighting and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "ADDON_RESTRICTION_STATE_CHANGED", "OnRestrictionEvent" }

function NS.addon.OnRestrictionEvent(_, _, rtype, state)
    R.OnRestrictionStateChanged(rtype, state)
end

-- Stood down, no event reaches the hints or the edge, so both go stale and are dropped; the
-- stand-up re-reads the client after the bus has replayed its receivers, so they hear it.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.restrictionHints = nil
    State.combatEdge = nil
    State.restrictionSignature = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() R.Refresh("standUp") end
