local _, NS = ...
-- modules/SimRoster.lua — the simulator's group and what it wears (simulator spec §2, §3): a
-- roster of invented members with names, realms, GUIDs, classes and specs, and each member's gear
-- drawn slot by slot from the item pool (modules/SimPool.lua) inside an item-level band around
-- yours.
--
-- PURE. Random, Members and Gear take every input as an argument (the random source included)
-- and touch no client and no state, so a seed replays the same group. Create is the edge: it reads
-- your realm and your average item level, draws the group for the running session, marks each GUID
-- as the simulation's (NS.Sim.MarkGUID, so the stop forgets it everywhere) and stores the list on
-- the session. It answers nothing to the client: the members reach the roster, the inspect replies
-- and the loot lines through the event drivers (DW-72), which read Members.
--
--   member = { sim = true, guid, name, realm, fullName, unit, classFile, classID, specID,
--              gear = { [slot] = link } }   -- a slot the pool cannot fill is absent (empty)

NS.SimRoster = NS.SimRoster or {}
local R = NS.SimRoster
local C = NS.Constants
local CD = NS.ClassData
local S = C.SLOT

local TAG = "SIM"

--- The members besides you: 4 in a party, 9 to 19 in a raid (spec §2).
R.PARTY_SIZE = 4
R.RAID_MIN, R.RAID_MAX = 9, 19

--- The default item-level band around your average (spec §3): from 10 below to 5 above.
R.BAND = { low = -10, high = 5 }

-- Invented names and realms. About one member in three comes from another realm.
local NAMES = {
    "Brakk", "Seta", "Ilyra", "Thornek", "Vaela", "Morwen", "Kazrik", "Elunor", "Dravos", "Saphine",
    "Gorrim", "Lysandra", "Tavi", "Orrin", "Zuleth", "Brinna", "Kaelis", "Mardok", "Nyssa", "Rokhan",
    "Fenwick", "Isolde", "Quillon", "Haskar", "Merrow",
}
local REALMS = { "Stormhold", "Ashcrest", "Duskmere", "Silverkeep", "Emberfall" }
R.NAMES, R.REALMS = NAMES, REALMS

-- Every classFile with specs, sorted, so a seed draws the same classes on every load.
local CLASSES = {}
for classFile in pairs(CD.CLASS_SPECS) do CLASSES[#CLASSES + 1] = classFile end
table.sort(CLASSES)

-- The order the gear is drawn in: the main hand before the off hand, so a two-hander empties it.
local ORDER = {
    S.HEAD, S.NECK, S.SHOULDER, S.BACK, S.CHEST, S.WRIST, S.HANDS, S.WAIST, S.LEGS, S.FEET,
    S.FINGER1, S.FINGER2, S.TRINKET1, S.TRINKET2, S.MAINHAND, S.OFFHAND,
}
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

-- A name not taken yet: the list in a random order, then numbered once it runs out.
local function pickName(rnd, taken)
    for _ = 1, #NAMES do
        local name = NAMES[rnd(#NAMES)]
        if not taken[name] then return name end
    end
    for _, name in ipairs(NAMES) do
        if not taken[name] then return name end
    end
    local n = 2
    while taken[NAMES[1] .. n] do n = n + 1 end
    return NAMES[1] .. n
end

local function makeMember(i, kind, ownRealm, rnd, taken)
    local classFile = CLASSES[rnd(#CLASSES)]
    local specs = CD.CLASS_SPECS[classFile]
    local name = pickName(rnd, taken)
    taken[name] = true
    local realm = ownRealm
    if not realm or rnd(3) == 1 then realm = REALMS[rnd(#REALMS)] end
    return {
        sim = true, name = name, realm = realm, fullName = name .. "-" .. realm,
        guid = ("Player-%d-%08X"):format(3900 + i, rnd(0, 0x7FFFFFFF)),
        unit = kind == "raid" and ("raid" .. (i + 1)) or ("party" .. i),
        classFile = classFile, classID = CD.CLASS_ID[classFile], specID = specs[rnd(#specs)],
    }
end

--- A group of invented members (spec §2). `opts` = { kind = `party`|`raid`, size, ownRealm }. In a
--- raid you are raid1 and the members raid2 onward; in a party they are party1 onward. Names are
--- distinct; GUIDs are distinct, shaped as the client's.
--- @param opts table
--- @param rnd function a random source (R.Random)
--- @return table members
function R.Members(opts, rnd)
    opts = type(opts) == "table" and opts or {}
    local kind = opts.kind == "raid" and "raid" or "party"
    local out, taken, guids = {}, {}, {}
    for i = 1, R.Size(kind, opts.size, rnd) do
        local m = makeMember(i, kind, opts.ownRealm, rnd, taken)
        while guids[m.guid] do m.guid = ("Player-%d-%08X"):format(3900 + i, rnd(0, 0x7FFFFFFF)) end
        guids[m.guid] = true
        out[i] = m
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

local function inBand(e, band)
    return type(e.ilvl) == "number" and e.ilvl >= band.low and e.ilvl <= band.high
end

-- Every entry that may fill `slot` for this member, not worn already.
local function candidates(m, entries, slot, band, used)
    local out = {}
    for _, e in ipairs(entries) do
        local plan = C.SLOT_PLAN[e.equipLoc]
        if plan and not used[e.link] and hasSlot(plan, slot) and inBand(e, band)
            and fitsHand(m, plan.kind, slot) and canUse(m, e) then
            out[#out + 1] = e
        end
    end
    return out
end

-- True when the main hand holds an item that fills both hands (a two-hander without Titan's
-- Grip, or a ranged weapon).
local function handsFull(m, entry)
    local kind = entry and C.SLOT_PLAN[entry.equipLoc].kind
    if kind == "ranged" then return true end
    return kind == "weapon2H" and CD.TitanGripFor(m.classFile, m.specID) ~= true
end

--- One member's gear (spec §3): each slot drawn at random from the entries it can wear whose item
--- level is inside `band` ({ low, high }, absolute levels). A slot no entry fits stays empty
--- (absent), and so does the off hand behind a two-hander. `entries` are pool entries with their
--- facts: { link, equipLoc, ilvl, classID, subClassID }.
--- @param m table a member
--- @param entries table
--- @param band table
--- @param rnd function
--- @return table gear { [slot] = link }
function R.Gear(m, entries, band, rnd)
    local gear, used, main = {}, {}, nil
    for _, slot in ipairs(ORDER) do
        if not (slot == S.OFFHAND and handsFull(m, main)) then
            local cands = candidates(m, entries, slot, band, used)
            if #cands > 0 then
                local e = cands[rnd(#cands)]
                gear[slot], used[e.link] = e.link, true
                if slot == S.MAINHAND then main = e end
            end
        end
    end
    return gear
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
--- `opts` = { kind, size, seed, band = { low, high } offsets }. The pool is the session's
--- (modules/SimPool.lua); without one every member is drawn with empty slots. Nil when no
--- simulation runs.
--- @param opts table|nil
--- @return table|nil members
function R.Create(opts)
    local s = NS.Sim.Session()
    if not s then return nil end
    opts = type(opts) == "table" and opts or {}
    local rnd = R.Random(opts.seed or math.floor(GetTime() * 1000))
    local members = R.Members({ kind = opts.kind, size = opts.size,
        ownRealm = NS.Compat.NormalizedRealm() }, rnd)
    local entries = NS.SimPool.GearEntries(s.pool)
    local band = R.BandAround(NS.SimPool.PlayerAverageLevel() or 0, opts.band)
    for _, m in ipairs(members) do
        m.gear = R.Gear(m, entries, band, rnd)
        NS.Sim.MarkGUID(m.guid)
    end
    s.members = members
    NS.Debug(TAG, "roster: %d members, band %d-%d, %d pool entries", #members, band.low, band.high, #entries)
    return members
end

--- The running simulation's members, or an empty list. Read them, never write them.
--- @return table
function R.Get()
    local s = NS.Sim.Session()
    return s and s.members or {}
end
