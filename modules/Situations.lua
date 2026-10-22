local _, NS = ...
-- modules/Situations.lua — where Drop Watcher is active (design spec §6.1): the situation
-- classifier and its edge.
--
-- TWO HALVES. The classifier, Classify(inputs) -> key, is PURE: a plain table in, one of the
-- C.SITUATIONS keys out, no WoW call, never throws (test_situations drives it as a truth table).
-- Resolve(key, stored) is pure too: a situation's `track`, `autoOpen` and `quality` from its stored
-- row, with the defaults (defaults/Profile.lua) for anything absent or malformed.
--
-- The edge, ReadInputs, is the only place this module touches the client: GetInstanceInfo,
-- IsInInstance, C_ChallengeMode.IsChallengeModeActive, IsInGroup / IsInRaid and GetDifficultyInfo,
-- each through NS.Compat (core/CompatWorld.lua), so a running simulation answers them.
-- It runs on the six re-evaluation events of spec §6.1, all declared in NS.FEATURE_EVENTS so the
-- stand-down takes them down, and sends SITUATION_CHANGED (key, previousKey) when the key moves.
--
--   inputs = { inInstance, instanceType, difficultyID, isChallengeModeActive, isDelve,
--              isFollowerDungeon, inGroup, inRaid, isPvP }
--
-- The settings are the `situations.<key>.*` rows, read through the schema seam. Test mode ignores
-- the situation gate: that bypass is the consumer's (LootFeed), so IsTracking answers for the
-- situation itself, except that a running simulation tracks the situation it simulates.

NS.Situations = NS.Situations or {}
local Sit = NS.Situations
local C = NS.Constants
local State = NS.State

local TAG = "SIT"

local QUALITY_MODE = {}
for _, mode in ipairs(C.QUALITY_MODES) do QUALITY_MODE[mode] = true end

local PVP_TYPE = { pvp = true, arena = true }

-- Each situation's defaults (defaults/Profile.lua), and what an unknown key takes.
local DEFAULTS = NS.C.PROFILE.situations
local NONE = { track = false, autoOpen = false }

-- ── the classifier (pure) ───────────────────────────────────────────────────────────────────

local function openWorld(i)
    if i.inGroup or i.inRaid then return "openWorldGroup" end
    return "solo"
end

-- The key an instance type gives once the difficulty-led keys are ruled out, or nil for a type
-- the design does not name (a housing interior, say), which then reads as the open world.
local function byInstanceType(i, kind)
    local t = i.instanceType
    if t == "party" then return "dungeon" end
    if t == "raid" then
        if kind == "raidLFR" then return "raidLFR" end
        return "raid"
    end
    if t == "scenario" then return "scenario" end
    return nil
end

-- The instance keys only the difficulty (or its flag) tells apart from their instance type.
local function byDifficulty(i, kind)
    if i.isDelve or kind == "delve" then return "delve" end
    if i.isFollowerDungeon or kind == "followerDungeon" then return "followerDungeon" end
    return nil
end

--- The situation key for a set of inputs (design spec §6.1). Order: PvP, Mythic+, the open world,
--- then the difficulty-led delve and follower dungeon, then the instance type. A difficulty the
--- client did not confirm should arrive as nil, so the instance type decides.
--- @param i table|any the classifier inputs
--- @return string key one of C.SITUATIONS' keys; `solo` for anything unreadable
function Sit.Classify(i)
    if type(i) ~= "table" then return "solo" end
    local kind = C.DIFFICULTY_KIND[i.difficultyID]
    if i.isPvP or PVP_TYPE[i.instanceType] then return "pvp" end
    if i.isChallengeModeActive or kind == "mythicPlus" then return "mythicPlus" end
    if not i.inInstance then return openWorld(i) end
    return byDifficulty(i, kind) or byInstanceType(i, kind) or openWorld(i)
end

local function flag(stored, field, default)
    if type(stored) ~= "table" then return default end
    local v = stored[field]
    if type(v) == "boolean" then return v end
    return default
end

--- A situation's settings: `track`, `autoOpen` (booleans) and `quality` (a mode, or nil for the
--- global mode: absent, `global` or anything unknown). An unknown key tracks nothing.
--- @param key string a situation key
--- @param stored table|nil the stored `profile.situations[key]` row
--- @return table settings { track, autoOpen, quality }
function Sit.Resolve(key, stored)
    local def = DEFAULTS[key] or NONE
    local q = type(stored) == "table" and stored.quality
    return {
        track    = flag(stored, "track", def.track),
        autoOpen = flag(stored, "autoOpen", def.autoOpen),
        quality  = QUALITY_MODE[q] and q or nil,
    }
end

-- ── the edge ────────────────────────────────────────────────────────────────────────────────

-- The difficulty id, or nil when the client does not know it: a retired or renumbered id then
-- falls back to the instance type instead of misclassifying (spec §6.1).
local function confirmedDifficulty(id)
    if type(id) ~= "number" or id <= 0 then return nil end
    if not NS.Compat.DifficultyKnown(id) then return nil end
    return id
end

--- The classifier inputs, read from the client now. Read-only: safe in combat and stood down.
--- @return table inputs
function Sit.ReadInputs()
    local Compat = NS.Compat
    local inInstance, instanceType = Compat.InstanceState()
    local _, infoType, difficultyID = Compat.InstanceInfo()
    instanceType = instanceType or infoType or "none"
    difficultyID = confirmedDifficulty(difficultyID)
    local kind = C.DIFFICULTY_KIND[difficultyID]
    return {
        inInstance            = inInstance == true,
        instanceType          = instanceType,
        difficultyID          = difficultyID,
        isChallengeModeActive = Compat.ChallengeModeActive(),
        isDelve               = kind == "delve",
        isFollowerDungeon     = kind == "followerDungeon",
        inGroup               = Compat.InGroup(),
        inRaid                = Compat.InRaid(),
        isPvP                 = PVP_TYPE[instanceType] == true,
    }
end

--- Re-read the inputs and classify. Sends SITUATION_CHANGED (key, previousKey) when the key moved.
--- @param reason string|nil the event (or `standUp`) that asked, for the debug line
--- @return boolean changed
function Sit.Refresh(reason)
    local inputs = Sit.ReadInputs()
    local key = Sit.Classify(inputs)
    State.situationInputs = inputs
    local prev = State.situation
    if key == prev then return false end
    State.situation = key
    NS.Debug(TAG, "situation %s -> %s (%s)", tostring(prev), key, tostring(reason))
    NS.addon:SendMessage(NS.MSG.SITUATION_CHANGED, key, prev)
    return true
end

--- The current situation key. Before the first event (or while stood down) it is classified live,
--- without a message.
--- @return string key
function Sit.Current()
    return State.situation or Sit.Classify(Sit.ReadInputs())
end

-- A situation's three settings through the schema seam (NS.Setting); nil for an unknown key.
local function storedRow(key)
    if not C.SITUATION[key] then return nil end
    local base = "situations." .. key .. "."
    return {
        track = NS.Setting(base .. "track"), autoOpen = NS.Setting(base .. "autoOpen"),
        quality = NS.Setting(base .. "quality"),
    }
end

--- A situation's resolved settings, the current one when `key` is nil.
--- @param key string|nil
--- @return table settings { track, autoOpen, quality }
function Sit.Settings(key)
    key = key or Sit.Current()
    return Sit.Resolve(key, storedRow(key))
end

--- Whether loot is tracked in a situation (the current one when `key` is nil). A running
--- simulation always tracks the situation it simulates, whatever its row says (sim feedback §0:
--- a run exists to fill the window, the delve and the open world untracked by default included);
--- the real world keeps its own row.
function Sit.IsTracking(key)
    key = key or Sit.Current()
    local s = NS.Sim:IsActive() and NS.Sim:Session()
    if s and s.situation == key then return true end
    return Sit.Settings(key).track
end

--- Whether a drop added to the feed opens the window there (the current one when `key` is nil).
function Sit.ShouldAutoOpen(key) return Sit.Settings(key).autoOpen end

--- The situation's minimum-quality mode, or nil for the global mode (QualityGate.ResolveMode).
function Sit.QualityOverride(key) return Sit.Settings(key).quality end

--- The last inputs the edge read, or nil before the first refresh.
function Sit.LastInputs() return State.situationInputs end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

local EVENTS = {
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "CHALLENGE_MODE_START",
    "CHALLENGE_MODE_COMPLETED", "GROUP_ROSTER_UPDATE", "PLAYER_DIFFICULTY_CHANGED",
}
for _, event in ipairs(EVENTS) do
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { event, "OnSituationEvent" }
end

function NS.addon.OnSituationEvent(_, event)
    Sit.Refresh(event)
end

-- Stood down, the key goes stale (no event reaches it); the stand-up classifies from now, after
-- the bus has replayed its receivers, so they hear the situation they came back to.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function()
    State.situation = nil
    State.situationInputs = nil
end
NS.STAND_UP[#NS.STAND_UP + 1] = function() Sit.Refresh("standUp") end
