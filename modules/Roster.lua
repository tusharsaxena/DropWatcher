local _, NS = ...
-- modules/Roster.lua — who is in the group (design spec §4): each member by GUID, with the
-- Name-Realm, the unit token, the classFile, the specID (once an inspect has read it) and the
-- online state; and the resolver that turns a name or a GUID into a member.
--
-- THE EDGE. Refresh reads the client through NS.Compat (core/CompatWorld.lua, so a running
-- simulation answers it): IsInRaid / IsInGroup / GetNumGroupMembers for the tokens (raid1..N in a
-- raid, player and party1..N-1 in a party, player alone otherwise), then UnitGUID, UnitName,
-- UnitClass and UnitIsConnected per token. The realm of a same-realm member comes from
-- NS.Compat.NormalizedRealm. It runs on GROUP_ROSTER_UPDATE (declared in NS.FEATURE_EVENTS, shared
-- with modules/Situations.lua through core/DropWatcher.lua's dispatcher) and at the stand-up, and
-- lazily on the first read.
--
-- SECRETS. Every unit answer is guarded before it is compared, concatenated or used as a key: a
-- secret or missing GUID drops the token (it cannot key a member), a secret name leaves the member
-- reachable by GUID only, a secret class leaves classFile nil and a secret online flag reads as
-- online. The client's "Unknown" placeholder name counts as no name.
--
-- RESOLVING. Resolve(query, classFile) takes a GUID, a "Name-Realm" or a bare "Name", compared
-- without case, and with the realm normalized (spaces and hyphens dropped, as the client's
-- normalized realm names are). A bare name may match members on several realms: the classFile,
-- when given, narrows them; then a member on the player's own realm wins, because chat names a
-- same-realm player without a realm. Still ambiguous, or no match, answers nil. A miss re-reads
-- the client once, so a member whose name was still "Unknown" at the last event is found.
--
--   member = { guid, name, realm, fullName, unit, classFile, online, isPlayer, specID }

NS.Roster = NS.Roster or {}
local Ro = NS.Roster
local State = NS.State

local TAG = "ROSTER"

-- ── reading the client ──────────────────────────────────────────────────────────────────────

-- A plain, non-empty string, or nil (secret, missing or the client's "Unknown" placeholder).
local function plainName(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    if v == UNKNOWNOBJECT then return nil end
    return v
end

--- A realm name as the client normalizes it: spaces and hyphens dropped. Nil for anything else.
--- @param realm any
--- @return string|nil
function Ro.NormalizeRealm(realm)
    if NS.Compat.IsSecret(realm) or type(realm) ~= "string" then return nil end
    local out = realm:gsub("[%s%-]", "")
    if out == "" then return nil end
    return out
end

-- The unit tokens of the group now, in the client's order.
local function unitTokens()
    local Compat = NS.Compat
    local n = Compat.GroupSize()
    if Compat.InRaid() and n > 0 then
        local out = {}
        for i = 1, n do out[i] = "raid" .. i end
        return out
    end
    local out = { "player" }
    if Compat.InGroup() then
        for i = 1, n - 1 do out[#out + 1] = "party" .. i end
    end
    return out
end

local function classFileOf(unit)
    local _, classFile = NS.Compat.UnitClass(unit)
    return plainName(classFile)
end

local function onlineOf(unit)
    local online = NS.Compat.UnitIsConnected(unit)
    if NS.Compat.IsSecret(online) then return true end
    return online ~= false
end

-- Name, realm and Name-Realm of a unit; the name and full name are nil when unreadable.
local function identityOf(unit, ownRealm)
    local name, realm = NS.Compat.UnitName(unit)
    name = plainName(name)
    realm = Ro.NormalizeRealm(realm) or ownRealm
    if not name then return nil, realm, nil end
    return name, realm, realm and (name .. "-" .. realm) or name
end

-- One member read off `unit`, or nil when its GUID cannot key one.
local function readMember(unit, ownRealm, playerGUID)
    local guid = NS.Compat.UnitGUID(unit)
    if not NS.Compat.IsSafeKey(guid) or type(guid) ~= "string" then return nil end
    local name, realm, fullName = identityOf(unit, ownRealm)
    return {
        guid = guid, name = name, realm = realm, fullName = fullName, unit = unit,
        classFile = classFileOf(unit), online = onlineOf(unit), isPlayer = guid == playerGUID,
    }
end

local function playerGUID()
    local guid = NS.Compat.UnitGUID("player")
    if NS.Compat.IsSafeKey(guid) then return guid end
    return nil
end

-- A fresh roster: { byGUID = { [guid] = member }, list = { member, ... } }, carrying each known
-- member's specID over from `prev`.
local function build(prev)
    local ownRealm = NS.Compat.NormalizedRealm()
    local me = playerGUID()
    local roster = { byGUID = {}, list = {} }
    for _, unit in ipairs(unitTokens()) do
        local m = readMember(unit, ownRealm, me)
        if m and not roster.byGUID[m.guid] then
            local old = prev and prev.byGUID[m.guid]
            m.specID = old and old.specID
            roster.byGUID[m.guid] = m
            roster.list[#roster.list + 1] = m
        end
    end
    return roster
end

local function signature(roster)
    local parts = {}
    for i, m in ipairs(roster.list) do
        parts[i] = ("%s:%s:%s:%s"):format(m.guid, m.unit, m.fullName or "?", tostring(m.online))
    end
    return table.concat(parts, ",")
end

--- Re-read the group from the client.
--- @param cause string|nil the event (or `standUp`, `lazy`, `miss`) that asked, for the debug line
--- @return boolean changed whether any member, token, name or online state moved
function Ro.Refresh(cause)
    local prev = State.roster
    local roster = build(prev)
    roster.signature = signature(roster)
    State.roster = roster
    local changed = not prev or prev.signature ~= roster.signature
    if changed then
        NS.Debug(TAG, "roster: %d members (%s)", #roster.list, tostring(cause))
    end
    return changed
end

local function roster()
    if not State.roster then Ro.Refresh("lazy") end
    return State.roster
end

-- ── reading the roster ──────────────────────────────────────────────────────────────────────

--- Every member, in the client's unit order. The tables are the roster's own: read, never write.
--- @return table
function Ro.Members()
    return roster().list
end

--- The member with this GUID, or nil.
--- @param guid string
--- @return table|nil
function Ro.Get(guid)
    if not NS.Compat.IsSafeKey(guid) then return nil end
    return roster().byGUID[guid]
end

--- The player's own member.
--- @return table|nil
function Ro.Player()
    local guid = playerGUID()
    return guid and Ro.Get(guid)
end

--- How many members the roster holds.
--- @return number
function Ro.Count()
    return #roster().list
end

--- Record a member's specialization (the inspect broker, design spec §8). Kept across refreshes
--- while the GUID stays in the group.
--- @param guid string
--- @param specID number|nil
--- @return boolean recorded
function Ro.SetSpec(guid, specID)
    local m = Ro.Get(guid)
    if not m or NS.Compat.IsSecret(specID) then return false end
    m.specID = type(specID) == "number" and specID or nil
    return true
end

-- ── resolving ───────────────────────────────────────────────────────────────────────────────

-- The members whose name matches `name` (lowercased), and whose realm matches `realm` when given.
local function matching(list, name, realm)
    local out = {}
    for _, m in ipairs(list) do
        if m.name and m.name:lower() == name
            and (not realm or (m.realm and m.realm:lower() == realm)) then
            out[#out + 1] = m
        end
    end
    return out
end

local function narrow(cands, keep)
    if #cands < 2 then return cands end
    local out = {}
    for _, m in ipairs(cands) do
        if keep(m) then out[#out + 1] = m end
    end
    if #out == 0 then return cands end
    return out
end

-- The one member a parsed query names, or nil (no match, or still ambiguous).
local function pick(list, name, realm, classFile)
    local cands = matching(list, name, realm)
    if classFile then
        cands = narrow(cands, function(m) return m.classFile == classFile end)
    end
    if not realm then
        local own = Ro.NormalizeRealm(NS.Compat.NormalizedRealm())
        own = own and own:lower()
        cands = narrow(cands, function(m) return m.realm ~= nil and m.realm:lower() == own end)
    end
    if #cands == 1 then return cands[1] end
    return nil
end

-- A query split into a lowercased name and a lowercased normalized realm (nil for a bare name).
local function parse(query)
    local name, realm = query:match("^([^%-]+)%-(.+)$")
    if not name then return query:lower(), nil end
    realm = Ro.NormalizeRealm(realm)
    return name:lower(), realm and realm:lower()
end

local function lookup(query, classFile)
    local r = roster()
    if r.byGUID[query] then return r.byGUID[query] end
    local name, realm = parse(query)
    return pick(r.list, name, realm, plainName(classFile))
end

--- The member a GUID, a "Name-Realm" or a bare "Name" names. `classFile` settles two members of
--- the same name. A miss re-reads the client once.
--- @param query string
--- @param classFile string|nil
--- @return table|nil member
function Ro.Resolve(query, classFile)
    query = plainName(query)
    if not query then return nil end
    local m = lookup(query, classFile)
    if m then return m end
    Ro.Refresh("miss")
    return lookup(query, classFile)
end

-- ── events and the lifecycle ────────────────────────────────────────────────────────────────

NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { "GROUP_ROSTER_UPDATE", "OnRosterEvent" }

function NS.addon.OnRosterEvent(_, event)
    Ro.Refresh(event)
end

-- Stood down, no event reaches the roster, so it goes stale and is dropped; the stand-up re-reads.
NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() State.roster = nil end
NS.STAND_UP[#NS.STAND_UP + 1] = function() Ro.Refresh("standUp") end
