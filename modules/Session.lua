local _, NS = ...
-- modules/Session.lua — the session is the login (feedback-15 spec §0, DW-Q0): when this
-- character's session started, and where This instance starts, both kept per character so a
-- /reload changes neither.
--
--   DropWatcherDB.char[<character>].session = { start, instance = { at, situation, instance }, cleared }
--
-- THE START. `start` is time() (the epoch, so it means the same after a reload). PLAYER_ENTERING_WORLD
-- with `isInitialLogin` sets it to now; with `isReloadingUi` the stored value is kept; with neither (a
-- zone change) nothing moves. Until the event has run (the window's first paint can come first),
-- Start answers the stored value when it exists, else now, which it then stores, so it is never nil
-- and never moves on its own (a first run, a corrupt row). History's session key
-- (`feedKey@<start>`, NS.History.SessionStart) and every tab's This session read it.
--
-- THIS INSTANCE. The window's `instanceSince` (the last SituationChanged, in GetTime()) is also
-- stored as `instance`: `at` the epoch, `situation` the situation key and `instance` the instance
-- map id (GetInstanceInfo's eighth answer, nil outside an instance). After a reload, the first
-- situation announcement that names the same situation and instance gives back the stored moment,
-- turned into the client clock (GetTime() - (time() - at)), instead of now (MarkSituation).
--
-- THE CLEAR. `cleared` is the time() of the last live LootFeed.Clear (`/dw clear`, Clear on boss
-- kill): a reload restores only the entries dated from it on (modules/FeedRestore.lua), so what was
-- cleared stays cleared. A login drops it with the old session.
--
-- THE ORDER. Its PLAYER_ENTERING_WORLD row runs before modules/Situations.lua's (the TOC loads it
-- first), so a reload is known before the reload's first SituationChanged reaches the window. An
-- addon that started disabled never hears the event: its stand-up starts a session of its own.
--
-- The kit's AceDB fake has no `char` section, so without one (the suites that never seed it) the
-- record lives in a session-only table instead.

NS.Session = NS.Session or {}
local S = NS.Session

local TAG = "FEED"

local fallback = {}        -- the record when the database has no `char` section
local seen = false         -- a PLAYER_ENTERING_WORLD (or the stand-up) has run this load
local reloaded = false     -- that event said isReloadingUi
local marked = false       -- the first situation announcement has been answered

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function record()
    local db = NS.addon and NS.addon.db
    local char = db and type(db.char) == "table" and db.char or fallback
    if type(char.session) ~= "table" then char.session = {} end
    return char.session
end

--- When this session started (time()): the stored start, else now, stored. Never nil.
--- @return number
function S.Start()
    local r = record()
    if not num(r.start) then r.start = time() end
    return r.start
end

--- When this session started in the client clock (GetTime()), for the Drops tab's This session
--- (feedback-15 spec §1, DW-Q1): the start turned as This instance's is, less a second, since time()
--- counts whole seconds and a drop in the login's own second must not fall before it.
--- @return number
function S.StartClock()
    return GetTime() - (time() - S.Start()) - 1
end

--- The live feed was emptied now (LootFeed.Clear): remember when, for a reload's restore.
function S.MarkCleared() record().cleared = time() end

--- When the live feed was last emptied this session (time()), or nil.
--- @return number|nil
function S.Cleared() return num(record().cleared) end

--- Whether this load is a /reload (PLAYER_ENTERING_WORLD's isReloadingUi). False before the event.
--- @return boolean
function S.IsReload() return reloaded end

--- PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi): a login starts the session now, a reload
--- keeps it, a zone change moves nothing.
function S.OnEnteringWorld(isInitialLogin, isReloadingUi)
    if not seen then reloaded = isReloadingUi == true and not isInitialLogin end
    seen = true
    if isInitialLogin == true then
        record().start, record().cleared = time(), nil
        NS.Debug(TAG, "session: a login, started at %d", record().start)
    elseif isReloadingUi == true then
        NS.Debug(TAG, "session: a reload, kept from %d", S.Start())
    end
end

-- The instance map id you are in, or nil outside one.
local function instanceID()
    local Compat = NS.Compat
    if not Compat.InstanceState() then return nil end
    local _, _, _, _, id = Compat.InstanceInfo()
    if Compat.IsSecret(id) then return nil end
    return num(id)
end

--- A situation announcement (SituationChanged): where This instance starts, in GetTime(). The
--- reload's first one that names the stored situation and instance answers the stored moment;
--- anything else is now, and stored.
--- @param key string the situation
--- @return number since
function S.MarkSituation(key)
    local r, inst, first = record(), instanceID(), not marked
    marked = true
    local m = type(r.instance) == "table" and r.instance or nil
    if first and reloaded and m and num(m.at) and m.situation == key and m.instance == inst then
        NS.Debug(TAG, "session: This instance kept across the reload (%s)", tostring(key))
        return GetTime() - (time() - m.at)
    end
    r.instance = { at = time(), situation = key, instance = inst }
    return GetTime()
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

-- PLAYER_ENTERING_WORLD is shared (core/DropWatcher.lua's dispatcher).
NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "PLAYER_ENTERING_WORLD", "OnSessionWorldEvent" }

function NS.addon.OnSessionWorldEvent(_, _, isInitialLogin, isReloadingUi)
    S.OnEnteringWorld(isInitialLogin, isReloadingUi)
end

-- A stand-up only comes from releasing the latch: an addon that started disabled never heard the
-- session's PLAYER_ENTERING_WORLD, so it starts its session here.
NS.STAND_UP[#NS.STAND_UP + 1] = function()
    if seen then return end
    S.OnEnteringWorld(true, false)
end
