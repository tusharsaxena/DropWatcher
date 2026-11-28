local _, NS = ...
-- modules/SimRoster.lua — the simulator's group and what it wears (simulator spec §2, §3): a
-- roster of the library's sample people (THE PEOPLE) with names, realms, GUIDs, classes and specs,
-- and each member's gear drawn slot by slot from the item pool (modules/SimPool.lua) and worn inside
-- an item-level band around the content's level (the median of the pool's drops, ContentLevel;
-- yours without one).
--
-- PURE. Random, Members and Gear take every input as an argument (the random source included)
-- and touch no client and no state, so a seed replays the same group. Create is the edge: it reads
-- your realm and your average item level, draws the group for the running session, marks each GUID
-- as the simulation's (NS.SimHost.MarkGUID, so the stop forgets it everywhere) and stores the list on
-- the session. It answers nothing to the client: the members reach the roster, the inspect replies
-- and the loot lines through the event drivers (DW-72), which read Members.
--
--   member = { sim = true, guid, name, realm, fullName, unit, classFile, classID, specID,
--              gear = { [slot] = link },    -- a slot the pool cannot fill is absent (empty)
--              levels = { [slot] = ilvl } } -- each worn item's level, drawn inside the band

NS.SimRoster = NS.SimRoster or {}
local R = NS.SimRoster
local C = NS.Constants
local CD = NS.ClassData
local S = C.SLOT

local TAG = "SIM"

--- The members besides you: 4 in a party, 9 to 19 in a raid (spec §2).
R.PARTY_SIZE = 4
R.RAID_MIN, R.RAID_MAX = 9, 19

--- The default item-level band around the content's level (sim feedback §0): from 1 to 12 above.
--- The group is a little ahead of the content it runs, so its drops are spare for their looters
--- and likely tradeable: what the window's Interesting view is for, whatever you wear. A scenario
--- (or a suite) passes its own band to draw a group behind the content instead.
R.BAND = { low = 1, high = 12 }

-- THE PEOPLE (LibKa0s#104, FB2-DW-01): every member and raider is a person of LibKa0s-Sim-1.0's
-- sample crowd (Sim.SampleCrowd), never a name list of this addon's, so the same people appear in
-- every Ka0s addon's sim. A crowd is seeded (R.Crowd: the session's seed), so a seed replays the
-- same group; a smaller crowd is a larger one's head, and the group takes the crowd's first rows and
-- the raiders the rows past it, so every name is apart. A person brings the class and spec (Retail's
-- specID; on WoW Forever its classic tree, which no member carries as a specID, as before) and its
-- name in the client's shape: "First Surname" with no realm on WoW Forever, one word on Retail, on
-- your realm or, one in three, on the crowd's own invented realm.

--- The library's whole seeded crowd for `client` ("retail" or "forever"), a copy the caller owns,
--- or an empty list without LibKa0s-Sim-1.0 (no person can be named; no member is drawn).
--- @param client string|nil
--- @param seed number|nil
--- @return table[]
function R.Crowd(client, seed)
    local Sim = LibStub and LibStub("LibKa0s-Sim-1.0", true)
    if not (Sim and Sim.SampleCrowd) then return {} end
    return Sim.SampleCrowd(client == "forever" and "forever" or "retail", Sim.CROWD_MAX,
        math.floor(tonumber(seed) or 1))
end

-- The order the gear is drawn in: the main hand before the off hand, so a two-hander empties it.
-- One list per client, picked once (clients-§5): WoW Forever's members wear the ranged slot too
-- (slot 18: a bow, gun, crossbow, wand, thrown weapon or relic, DW-FP06).
local ORDER_LISTS = {
    retail = {
        S.HEAD, S.NECK, S.SHOULDER, S.BACK, S.CHEST, S.WRIST, S.HANDS, S.WAIST, S.LEGS, S.FEET,
        S.FINGER1, S.FINGER2, S.TRINKET1, S.TRINKET2, S.MAINHAND, S.OFFHAND,
    },
    forever = {
        S.HEAD, S.NECK, S.SHOULDER, S.BACK, S.CHEST, S.WRIST, S.HANDS, S.WAIST, S.LEGS, S.FEET,
        S.FINGER1, S.FINGER2, S.TRINKET1, S.TRINKET2, S.MAINHAND, S.OFFHAND, S.RANGED,
    },
}
local ORDER = ORDER_LISTS[NS.Compat.ClientKey() == "forever" and "forever" or "retail"]
R.ORDER = ORDER

-- ── the random source ──────────────────────────────────────────────────────────────────────

--- A seeded random source shaped like math.random: `rnd()` in [0, 1), `rnd(n)` in 1..n and
--- `rnd(a, b)` in a..b. Park-Miller, exact in doubles, so a seed replays on every client.
--- @param seed number|nil
--- @return function
function R.Random(seed)
    local state = math.floor(tonumber(seed) or 1) % 2147483647
    if state <= 0 then state = state + 2147483646 end
    return function(a, b)
        state = state * 16807 % 2147483647
        local u = (state - 1) / 2147483646
        if a == nil then return u end
        if b == nil then a, b = 1, a end
        return a + math.floor(u * (b - a + 1))
    end
end

-- ── the members ────────────────────────────────────────────────────────────────────────────

--- How many members a group of `kind` (`party` or `raid`) has: `size` clamped to the kind's
--- range, else 4 for a party and a random 9 to 19 for a raid.
--- @param kind string
--- @param size number|nil
--- @param rnd function
--- @return number
function R.Size(kind, size, rnd)
    if kind ~= "raid" then return R.PARTY_SIZE end
    if type(size) ~= "number" then return rnd(R.RAID_MIN, R.RAID_MAX) end
    return math.max(R.RAID_MIN, math.min(R.RAID_MAX, math.floor(size)))
end

-- The client a draw names people for: the caller's `opts.client`, else the running one (fixed
-- for the session, clients-§5).
local function clientOf(opts)
    if opts.client == "forever" or opts.client == "retail" then return opts.client end
    return NS.Compat.ClientKey() == "forever" and "forever" or "retail"
end

-- A person's name, realm and fullName in the client's shape: the crowd's "First Surname" with no
-- realm on WoW Forever; else the one word on your realm or, one in three, on the crowd's own realm.
local function nameOf(row, opts, rnd)
    if clientOf(opts) == "forever" then return row.fullName, nil, row.fullName end
    local realm = opts.ownRealm
    if not realm or rnd(3) == 1 then realm = row.realm end
    return row.name, realm, row.name .. "-" .. realm
end

-- The unit token of member `i` in a group of `kind`; nil for a raider past the group (no kind).
local function unitOf(kind, i)
    if kind == nil then return nil end
    return kind == "raid" and ("raid" .. (i + 1)) or ("party" .. i)
end

-- Member `i` from crowd person `row`. WoW Forever's spec is class-wide and the client's alone
-- (libs/LibKa0s/VerdictClassData.lua), so a Forever member has no specID, as an inspect of one that
-- answered nothing (Forever port design §4.2).
local function makeMember(i, kind, row, opts, rnd)
    local name, realm, fullName = nameOf(row, opts, rnd)
    return {
        sim = true, name = name, realm = realm, fullName = fullName,
        guid = ("Player-%d-%08X"):format(3900 + i, rnd(0, 0x7FFFFFFF)),
        unit = unitOf(kind, i),
        classFile = row.classFile, classID = CD.CLASS_ID[row.classFile],
        specID = clientOf(opts) ~= "forever" and row.specID or nil,
    }
end

-- The crowd a draw uses: the caller's (`opts.crowd`, the session's), else one seeded off `rnd`.
local function crowdOf(opts, rnd)
    if type(opts.crowd) == "table" then return opts.crowd end
    return R.Crowd(clientOf(opts), rnd(1, 2147483646))
end

-- A person's first name, the part two people are told apart by.
local function firstOf(name) return tostring(name):match("^(%S+)") or "" end

--- A group of crowd people (spec §2). `opts` = { kind = `party`|`raid`, size, ownRealm, client
--- (`forever`: each member is then "First Surname" with no realm; else the running client), crowd (R.Crowd's; else one seeded
--- off `rnd`) }. In a raid you are raid1 and the members raid2 onward; in a party they are party1
--- onward. They are the crowd's first rows, so names are distinct; GUIDs are distinct, shaped as
--- the client's.
--- @param opts table
--- @param rnd function a random source (R.Random)
--- @return table members
function R.Members(opts, rnd)
    opts = type(opts) == "table" and opts or {}
    local kind = opts.kind == "raid" and "raid" or "party"
    local size = R.Size(kind, opts.size, rnd)
    local crowd, out, guids = crowdOf(opts, rnd), {}, {}
    for i = 1, math.min(size, #crowd) do
        local m = makeMember(i, kind, crowd[i], opts, rnd)
        while guids[m.guid] do m.guid = ("Player-%d-%08X"):format(3900 + i, rnd(0, 0x7FFFFFFF)) end
        guids[m.guid] = true
        out[i] = m
    end
    return out
end

--- `n` roll-only raiders past the group (`/dw sim raid`, rolls panel design §3.6): crowd people
--- shaped as members (`raider = true`, a name, realm, fullName, GUID, class and spec), each one the
--- crowd's next person whose name `members` and the raiders before it do not hold, with distinct
--- GUIDs. They are no group member: no unit token, no gear, never in the roster; they only roll.
--- `opts` = { ownRealm, client, crowd } as R.Members takes them. The crowd holds CROWD_MAX (64)
--- people, past a 40-player raid's 39 besides you.
--- @param n number
--- @param members table|nil the group's members
--- @param opts table|nil
--- @param rnd function a random source (R.Random)
--- @return table raiders
function R.Raiders(n, members, opts, rnd)
    opts = type(opts) == "table" and opts or {}
    local taken, guids, out = {}, {}, {}
    for _, m in ipairs(members or {}) do taken[firstOf(m.name)], guids[m.guid or ""] = true, true end
    local want = math.max(0, math.floor(tonumber(n) or 0))
    if want == 0 then return out end
    local base = #(members or {})
    for _, row in ipairs(crowdOf(opts, rnd)) do
        if #out >= want then break end
        if not taken[row.name] then
            taken[row.name] = true
            local i = base + #out + 1
            local m = makeMember(i, nil, row, opts, rnd)
            while guids[m.guid] do m.guid = ("Player-%d-%08X"):format(3900 + i, rnd(0, 0x7FFFFFFF)) end
            guids[m.guid], m.raider = true, true
            out[#out + 1] = m
        end
    end
    return out
end

-- ── the gear ───────────────────────────────────────────────────────────────────────────────

-- Whether the member can wear the entry at all: its armor type, its weapon type, a shield or a
-- held off hand. An unknown answer lets it through (the verdict kernel judges it later).
local function canUse(m, e)
    local loc = e.equipLoc
    if C.ARMOR_TYPED_EQUIPLOC[loc] and CD.CanWearArmor(m.classFile, e.subClassID) == false then return false end
    if e.classID == C.ITEM_CLASS.WEAPON and CD.CanUseWeapon(m.classFile, e.subClassID) == false then
        return false
    end
    if loc == "INVTYPE_SHIELD" then return CD.CanUseShield(m.classFile, m.specID) ~= false end
    if loc == "INVTYPE_HOLDABLE" then return CD.CanUseOffhand(m.classFile, m.specID) ~= false end
    return true
end

-- Whether a plan of `kind` may fill `slot` for this member: the off hand takes off-hand items, a
-- one-hander only when the member dual wields and a two-hander only with Titan's Grip.
local function fitsHand(m, kind, slot)
    if slot ~= S.OFFHAND then return kind ~= "offhand" end
    if kind == "offhand" then return true end
    if kind == "weapon1H" then return CD.DualWieldFor(m.classFile, m.specID) == true end
    if kind == "weapon2H" then return CD.TitanGripFor(m.classFile, m.specID) == true end
    return false
end

local function hasSlot(plan, slot)
    for _, s in ipairs(plan.slots) do
        if s == slot then return true end
    end
    return false
end

-- Every entry that may fill `slot` for this member, not worn already.
local function candidates(m, entries, slot, used)
    local out = {}
    for _, e in ipairs(entries) do
        local plan = C.SLOT_PLAN[e.equipLoc]
        if plan and not used[e.link] and hasSlot(plan, slot) and fitsHand(m, plan.kind, slot) and canUse(m, e) then
            out[#out + 1] = e
        end
    end
    return out
end

-- A level inside the band, at random.
local function levelIn(band, rnd)
    local low, high = math.floor(band.low), math.floor(band.high)
    if high <= low then return low end
    return rnd(low, high)
end

-- True when the main hand holds an item that fills both hands (a two-hander without Titan's
-- Grip, or a ranged weapon).
local function handsFull(m, entry)
    local kind = entry and C.SLOT_PLAN[entry.equipLoc].kind
    if kind == "ranged" then return true end
    return kind == "weapon2H" and CD.TitanGripFor(m.classFile, m.specID) ~= true
end

--- One member's gear (spec §3; sim feedback §0): each slot drawn at random from the entries it can
--- wear, and worn at an item level drawn inside `band` ({ low, high }, absolute levels), which the
--- simulated inspect answers (`levels`). The pool sits at the content's level and your band may
--- not: drawing the level apart from the item dresses the group around you whatever you wear, so
--- the content's drops are upgrades for some members and spare for others. A slot nothing fits
--- stays empty (absent), and so does the off hand behind a two-hander. `entries` are pool entries
--- with their facts: { link, equipLoc, ilvl, classID, subClassID }.
--- @param m table a member
--- @param entries table
--- @param band table
--- @param rnd function
--- @return table gear { [slot] = link }, table levels { [slot] = worn item level }
function R.Gear(m, entries, band, rnd)
    local gear, levels, used, main = {}, {}, {}, nil
    for _, slot in ipairs(ORDER) do
        if not (slot == S.OFFHAND and handsFull(m, main)) then
            local cands = candidates(m, entries, slot, used)
            if #cands > 0 then
                local e = cands[rnd(#cands)]
                gear[slot], levels[slot], used[e.link] = e.link, levelIn(band, rnd), true
                if slot == S.MAINHAND then main = e end
            end
        end
    end
    return gear, levels
end

--- The content's item level (pure): the median level of the pool's drops, nil for none.
--- @param entries table pool entries, each with its `ilvl` when known
--- @return number|nil
function R.ContentLevel(entries)
    local levels = {}
    for _, e in ipairs(type(entries) == "table" and entries or {}) do
        if type(e.ilvl) == "number" then levels[#levels + 1] = e.ilvl end
    end
    if #levels == 0 then return nil end
    table.sort(levels)
    return levels[math.floor((#levels + 1) / 2)]
end

--- The absolute band around an average item level: { low = avg + band.low, high = avg + band.high }.
--- @param avg number
--- @param band table|nil { low, high } offsets (R.BAND by default)
--- @return table
function R.BandAround(avg, band)
    band = type(band) == "table" and band or R.BAND
    return { low = avg + (band.low or R.BAND.low), high = avg + (band.high or R.BAND.high) }
end

-- ── the edge ───────────────────────────────────────────────────────────────────────────────

--- Draw the running simulation's group and its gear (spec §2, §3) and keep it on the session.
--- `opts` = { kind, size, seed, band = { low, high } offsets around the content's level }. The
--- pool is the session's
--- (modules/SimPool.lua); without one every member is drawn with empty slots. Nil when no
--- simulation runs.
--- @param opts table|nil
--- @return table|nil members
function R.Create(opts)
    local s = NS.Sim:Session()
    if not s then return nil end
    opts = type(opts) == "table" and opts or {}
    local seed = opts.seed or math.floor(GetTime() * 1000)
    local rnd = R.Random(seed)
    -- The session's crowd, which the raid's rollers draw past the group from (SimEvents).
    s.crowd = R.Crowd(NS.Compat.ClientKey(), seed)
    local members = R.Members({ kind = opts.kind, size = opts.size, ownRealm = NS.Compat.NameRealm(),
        client = NS.Compat.ClientKey(), crowd = s.crowd }, rnd)
    local entries = NS.SimPool.GearEntries(s.pool)
    local drops = {}
    for _, e in ipairs(NS.SimPool.Drops(s.pool)) do drops[#drops + 1] = NS.SimPool.Facts(e) end
    local anchor = R.ContentLevel(drops) or NS.SimPool.PlayerAverageLevel() or 0
    local band = R.BandAround(anchor, opts.band)
    for _, m in ipairs(members) do
        m.gear, m.levels = R.Gear(m, entries, band, rnd)
        NS.SimHost.MarkGUID(m.guid)
    end
    s.members = members
    NS.Debug(TAG, "roster: %d members, band %d-%d, %d pool entries", #members, band.low, band.high, #entries)
    return members
end

--- The running simulation's members, or an empty list. Read them, never write them.
--- @return table
function R.Get()
    local s = NS.Sim:Session()
    return s and s.members or {}
end
