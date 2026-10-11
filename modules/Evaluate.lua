local _, NS = ...
-- modules/Evaluate.lua — the verdict kernel (design spec §5): is a drop an upgrade for a candidate?
--
-- PURE. It takes plain tables and makes no WoW API call, reads no saved variable and keeps no
-- state, so the headless suite can drive it exhaustively (test_evaluate). Its inputs are built by
-- the edges: ItemFacts (the drop and every gear entry), Gear (your own snapshot), Inspect (another
-- player's) and Scoring (the scorer). Settings reach it as plain `opts` (LootFeed reads the rows).
--
--   facts     = { itemID, ilvl, equipLoc, classID, subClassID, quality, specs = { [specID] = true },
--                 stats = { [STAT_KEY] = n }, track = { name, rank, max, tier },
--                 unique = { cat, max }, isTierToken, classes = { [classFile] = true } }
--   candidate = { classFile, specID, dualWield, titanGrip, gear = { [slot] = facts | false },
--                 owned = { [slot] = facts }, prefs = { undesired = { [SubClassKey] = true } } }
--   opts      = { sidegradeBand = 0, compareOwned = false, scorer = function(facts, candidate) }
--
-- In `gear`, false is an empty slot and nil a slot nobody has read yet. A tier token's equipLoc is
-- the slot the token makes. A scorer answers a number, "pending" (Pawn not ready), or nil.
--
-- It NEVER THROWS: any nil or unexpected input answers verdict "unknown" with a reason, and the
-- public entry point runs the whole evaluation under pcall as the last line of defense.

NS.Evaluate = NS.Evaluate or {}
local E = NS.Evaluate
local C = NS.Constants
local CD = NS.ClassData

local MH, OH = C.SLOT.MAINHAND, C.SLOT.OFFHAND
local ITEM_CLASS, ARMOR = C.ITEM_CLASS, C.ARMOR_SUBCLASS

local PRIMARY = { CD.STAT.STRENGTH, CD.STAT.AGILITY, CD.STAT.INTELLECT }

-- Verdicts by the sign of the comparison.
local BY_SIGN = { [1] = "upgrade", [0] = "sidegrade", [-1] = "downgrade" }

local function isTable(v) return type(v) == "table" end

-- A real number, or nil (NaN and every non-number are nil).
local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function sign(x, band)
    if x > band then return 1 end
    if x < -band then return -1 end
    return 0
end

-- Appends { key = key } once.
local function addReason(reasons, key, detail)
    for _, r in ipairs(reasons) do
        if r.key == key then return end
    end
    reasons[#reasons + 1] = { key = key, detail = detail }
end

--- The key `prefs.undesired` is indexed by: "<classID>:<subClassID>", or nil when either is not a
--- number. Keying by both keeps a one-hand mace (weapon 4) apart from plate (armor 4).
function E.SubClassKey(classID, subClassID)
    if not num(classID) or not num(subClassID) then return nil end
    return classID .. ":" .. subClassID
end

-- ---------------------------------------------------------------------------------------------
-- Step 1: equippability -> "ok" | "cant" | "doesntWant" | "unknown", plus a reason key
-- ---------------------------------------------------------------------------------------------

-- A ClassData answer (true / false / nil) as a status; the reason names what decided a refusal.
local function tri(v, key)
    if v == true then return "ok" end
    if v == false then return "cant", key end
    return "unknown", key
end

local function hasEntries(t) return isTable(t) and next(t) ~= nil end

-- Shields, held off hands, jewelry and cloaks, then the armor types.
local function armorCheck(facts, classFile, specID)
    local loc = facts.equipLoc
    if loc == "INVTYPE_SHIELD" or facts.subClassID == ARMOR.SHIELD then
        return tri(CD.CanUseShield(classFile, specID), "shield")
    end
    if loc == "INVTYPE_HOLDABLE" then return tri(CD.CanUseOffhand(classFile, specID), "offhand") end
    if C.UNIVERSAL_EQUIPLOC[loc] then return "ok" end
    if C.ARMOR_TYPED_EQUIPLOC[loc] then return tri(CD.CanWearArmor(classFile, facts.subClassID), "armorType") end
    return "unknown", "notGear"
end

-- The candidate's own flag when it carries one, else the spec's, else the class's when every spec
-- agrees; nil when it cannot tell.
local function flagOf(candidate, field, lookup)
    if type(candidate[field]) == "boolean" then return candidate[field] end
    return lookup(candidate.classFile, num(candidate.specID))
end

-- Weapon proficiency; an off-hand-only weapon also needs a dual wielder.
local function weaponCheck(facts, candidate)
    local status, why = tri(CD.CanUseWeapon(candidate.classFile, facts.subClassID), "weaponType")
    if status == "ok" and facts.equipLoc == "INVTYPE_WEAPONOFFHAND" then
        return tri(flagOf(candidate, "dualWield", CD.DualWieldFor), "dualWield")
    end
    return status, why
end

-- The primary stats an item carries, as a set, or nil when it carries none.
local function primariesOf(stats)
    if not isTable(stats) then return nil end
    local found
    for _, key in ipairs(PRIMARY) do
        local v = num(stats[key])
        if v and v > 0 then
            found = found or {}
            found[key] = true
        end
    end
    return found
end

-- Whether the item's primary stat suits the candidate: by the spec (or the class, when every spec
-- shares one), else by how many of the class's specs it suits: all, none, or some (ambiguous).
local function statCheck(facts, classFile, specID)
    local prim = primariesOf(facts.stats)
    if not prim then return "ok" end
    local stat = CD.PrimaryStat(classFile, specID)
    if stat then return tri(prim[stat] == true, "primaryStat") end
    local any, all = false, true
    for _, id in ipairs(CD.CLASS_SPECS[classFile] or {}) do
        if prim[CD.SPECS[id].stat] then any = true else all = false end
    end
    if any and all then return "ok" end
    if not any then return "cant", "primaryStat" end
    return "unknown", "primaryStat"
end

-- The spec-unknown fallback (and the known-spec path when the item has no spec list).
local function byClassData(facts, candidate)
    local classFile, specID = candidate.classFile, num(candidate.specID)
    if not CD.ARMOR[classFile] then return "unknown", "unknownClass" end
    local status, why
    if facts.classID == ITEM_CLASS.ARMOR then
        status, why = armorCheck(facts, classFile, specID)
    elseif facts.classID == ITEM_CLASS.WEAPON then
        status, why = weaponCheck(facts, candidate)
    else
        return "unknown", "notGear"
    end
    if status ~= "ok" then return status, why end
    return statCheck(facts, classFile, specID)
end

local function usable(facts, candidate)
    if type(candidate.classFile) ~= "string" then return "unknown", "unknownClass" end
    if isTable(facts.classes) and not facts.classes[candidate.classFile] then
        return "cant", "classRestricted"
    end
    if facts.isTierToken then
        if isTable(facts.classes) then return "ok" end
        return "unknown", "tierToken"
    end
    local specID = num(candidate.specID)
    if specID and hasEntries(facts.specs) then
        if facts.specs[specID] then return "ok" end
        return "cant", "specList"
    end
    return byClassData(facts, candidate)
end

local function undesired(facts, candidate)
    local prefs = candidate.prefs
    local list = isTable(prefs) and prefs.undesired
    if not isTable(list) then return false end
    local key = E.SubClassKey(facts.classID, facts.subClassID)
    return key ~= nil and list[key] == true
end

--- Step 1 alone: "ok", "cant", "doesntWant" or "unknown", and the reason key for anything but ok.
function E.Equippability(facts, candidate)
    if not isTable(facts) or not isTable(candidate) then return "unknown", "badInput" end
    local status, why = usable(facts, candidate)
    if status == "ok" and undesired(facts, candidate) then return "doesntWant", "undesired" end
    return status, why
end

-- ---------------------------------------------------------------------------------------------
-- Step 2: the slot plan -> { slot, items = { facts, ... } } | { slot, empty = true } | nil
-- ---------------------------------------------------------------------------------------------

-- One slot's entry as a baseline: facts with a numeric ilvl, false (empty), or nil (not known).
local function entry(v)
    if v == false then return false end
    if isTable(v) and num(v.ilvl) then return v end
    return nil
end

-- The slot reader for this candidate: equipped, or the better of equipped and owned.
local function slotReader(candidate, opts)
    local gear = isTable(candidate.gear) and candidate.gear or {}
    local owned = opts.compareOwned == true and isTable(candidate.owned) and candidate.owned or nil
    return function(slot)
        local equipped = entry(gear[slot])
        local alt = owned and entry(owned[slot])
        if alt and not (equipped and equipped.ilvl >= alt.ilvl) then return alt end
        return equipped
    end
end

-- Two-handers fill both hands: bows (RANGED) and guns, crossbows and wands (RANGEDRIGHT) too.
local TWO_HAND = { INVTYPE_2HWEAPON = true, INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true }

local function isTwoHand(f)
    return isTable(f) and TWO_HAND[f.equipLoc] == true
end

local function one(f, slot)
    if f == false then return { slot = slot, empty = true } end
    if f == nil then return nil end
    return { slot = slot, items = { f } }
end

-- The lower of two slots; an empty slot wins, an unknown one leaves the answer unknown.
local function lowerOf(a, sa, b, sb)
    if a == false then return one(a, sa) end
    if b == false then return one(b, sb) end
    if a == nil or b == nil then return nil end
    if b.ilvl < a.ilvl then return one(b, sb) end
    return one(a, sa)
end

local function vsTwoHand(mh)
    local plan = one(mh, MH)
    plan.vsTwoHand = true
    return plan
end

local PLANS = {}

function PLANS.single(slots, read) return one(read(slots[1]), slots[1]) end

function PLANS.pair(slots, read) return lowerOf(read(slots[1]), slots[1], read(slots[2]), slots[2]) end

function PLANS.weapon1H(_, read, ctx)
    local mh, oh = read(MH), read(OH)
    if not ctx.dualWield then return one(mh, MH) end
    if isTwoHand(mh) and not isTable(oh) and not ctx.titanGrip then return vsTwoHand(mh) end
    return lowerOf(mh, MH, oh, OH)
end

function PLANS.weapon2H(_, read, ctx)
    local mh, oh = read(MH), read(OH)
    if ctx.titanGrip then return lowerOf(mh, MH, oh, OH) end
    if mh == false or mh == nil or isTwoHand(mh) or oh == false then return one(mh, MH) end
    if oh == nil then return nil end
    return { slot = MH, items = { mh, oh } }
end

function PLANS.offhand(_, read)
    local mh, oh = read(MH), read(OH)
    if isTwoHand(mh) and not isTable(oh) then return vsTwoHand(mh) end
    return one(oh, OH)
end

function PLANS.ranged(slots, read, ctx)
    if ctx.classFile == "HUNTER" then return PLANS.weapon2H(slots, read, ctx) end
    return one(read(MH), MH)
end

-- The unique-equipped redirection: when the candidate already wears `max` items of the drop's
-- unique category, the drop can only replace one of them, so the lowest of those is the baseline.
-- When one of the drop's own slots holds the category, the drop goes there (the count stays the
-- same), so the lowest holder among its own slots is the baseline.
-- Whether the gear entry in `slot` holds unique category `cat`: its facts, or nil.
local function holder(slot, v, cat)
    local f = entry(v)
    if not f or not num(slot) or not isTable(f.unique) then return nil end
    if f.unique.cat ~= cat then return nil end
    return f
end

-- Whether `f` in `slot` sorts below the current pick: the lower ilvl, then the lower slot id.
local function below(f, slot, best, bestSlot)
    if not best then return true end
    if f.ilvl ~= best.ilvl then return f.ilvl < best.ilvl end
    return slot < bestSlot
end

local function asSet(list)
    local set = {}
    for _, slot in ipairs(list) do set[slot] = true end
    return set
end

local function uniquePlan(facts, candidate, plan)
    local u = facts.unique
    if not isTable(u) or u.cat == nil or not isTable(candidate.gear) then return nil end
    local own = asSet(plan.slots)
    local best, bestSlot, mine, mineSlot, count = nil, nil, nil, nil, 0
    for slot, v in pairs(candidate.gear) do
        local f = holder(slot, v, u.cat)
        if f then
            count = count + 1
            if below(f, slot, best, bestSlot) then best, bestSlot = f, slot end
            if own[slot] and below(f, slot, mine, mineSlot) then mine, mineSlot = f, slot end
        end
    end
    if count == 0 or count < (num(u.max) or 1) then return nil end
    if mine then return { slot = mineSlot, items = { mine }, unique = true } end
    return { slot = bestSlot, items = { best }, unique = true }
end

local function planFor(facts, candidate, opts)
    local plan = C.SLOT_PLAN[facts.equipLoc]
    if not plan then return nil, "notGear" end
    local ctx = {
        classFile = candidate.classFile,
        dualWield = flagOf(candidate, "dualWield", CD.DualWieldFor) == true,
        titanGrip = flagOf(candidate, "titanGrip", CD.TitanGripFor) == true,
    }
    local base = uniquePlan(facts, candidate, plan) or PLANS[plan.kind](plan.slots, slotReader(candidate, opts), ctx)
    if not base then return nil, "noBaseline" end
    return base
end

-- ---------------------------------------------------------------------------------------------
-- Step 3: deltas
-- ---------------------------------------------------------------------------------------------

local function tierOf(track)
    return num(track.tier) or C.TRACK_TIER[track.name]
end

--- The track change from `base` to `drop`: { tier, rank, sign }, or nil when either has no track
--- or no known tier. Tier first (Explorer < ... < Myth), then rank within it.
function E.TrackDelta(drop, base)
    if not isTable(drop) or not isTable(base) then return nil end
    local ta, tb = tierOf(drop), tierOf(base)
    if not ta or not tb then return nil end
    local dt = ta - tb
    local dr = (num(drop.rank) or 0) - (num(base.rank) or 0)
    local s = sign(dt, 0)
    if s == 0 then s = sign(dr, 0) end
    return { tier = dt, rank = dr, sign = s }
end

local function average(items, value)
    local sum = 0
    for _, f in ipairs(items) do
        local v = value(f)
        if not v then return nil end
        sum = sum + v
    end
    return sum / #items
end

-- The scorer's answer for one item: a number, "pending", or nil. A scorer that throws is no score.
local function scoreOf(scorer, f, candidate)
    local ok, v = pcall(scorer, f, candidate)
    if not ok then return nil end
    if v == "pending" then return v end
    return num(v)
end

local function scoreDelta(facts, items, candidate, opts, reasons)
    local scorer = opts.scorer
    if type(scorer) ~= "function" then return nil end
    local pending = false
    local function value(f)
        local v = scoreOf(scorer, f, candidate)
        if v == "pending" then pending = true return nil end
        return v
    end
    local mine, base = value(facts), average(items, value)
    if pending then addReason(reasons, "scorePending") end
    if not mine or not base then return nil end
    return mine - base
end

-- ---------------------------------------------------------------------------------------------
-- Step 4: the verdict
-- ---------------------------------------------------------------------------------------------

-- ilvl alone, or ilvl and score (spec §5.2 step 4): the verdict takes the sign only when the two
-- agree in sign; when they disagree (one of them within its band counts) it is a sidegrade, as it
-- is when both are within. The band is in item levels, so the score's band is 0.
local function decide(out, band)
    local si = sign(out.ilvlDelta, band)
    if out.scoreDelta == nil then return BY_SIGN[si] end
    local ss = sign(out.scoreDelta, 0)
    if si == ss then return BY_SIGN[si] end
    addReason(out.reasons, "scoreDisagrees")
    return "sidegrade"
end

local function verdictOf(out, base, band)
    if out.equip == "cant" then return "cantUse" end
    if out.equip == "doesntWant" then return "doesntWant" end
    if out.equip ~= "ok" or not base then return "unknown" end
    if base.empty then
        addReason(out.reasons, "emptySlot")
        return "upgrade"
    end
    if not out.ilvlDelta then return "unknown" end
    return decide(out, band)
end

-- Fills the baseline and the deltas; answers the plan (nil when there is no baseline).
local function compare(out, facts, candidate, opts)
    local ilvl = num(facts.ilvl)
    if not ilvl then
        addReason(out.reasons, "noIlvl")
        return nil
    end
    local base, why = planFor(facts, candidate, opts)
    if not base then
        addReason(out.reasons, why)
        return nil
    end
    out.baselineSlot = base.slot
    if base.empty then return base end
    if base.unique then addReason(out.reasons, "uniqueEquipped") end
    if base.vsTwoHand then addReason(out.reasons, "vsTwoHand") end
    out.baseline = base.items[1]
    out.ilvlDelta = ilvl - average(base.items, function(f) return f.ilvl end)
    out.trackDelta = E.TrackDelta(facts.track, out.baseline.track)
    out.scoreDelta = scoreDelta(facts, base.items, candidate, opts, out.reasons)
    return base
end

local function run(facts, candidate, opts)
    local out = { verdict = "unknown", equip = "unknown", reasons = {} }
    if not isTable(facts) then
        addReason(out.reasons, "badFacts")
        return out
    end
    if not isTable(candidate) then
        addReason(out.reasons, "badCandidate")
        return out
    end
    opts = isTable(opts) and opts or {}
    local equip, why = E.Equippability(facts, candidate)
    out.equip = equip
    if why then addReason(out.reasons, why) end
    local base = compare(out, facts, candidate, opts)
    out.verdict = verdictOf(out, base, math.abs(num(opts.sidegradeBand) or 0))
    return out
end

--- Evaluates `facts` for `candidate` (design spec §5.2). Answers
--- { verdict, equip, ilvlDelta, trackDelta, scoreDelta, baselineSlot, baseline, reasons }, where
--- verdict is "upgrade", "sidegrade", "downgrade", "cantUse", "doesntWant" or "unknown", and
--- reasons is a list of { key = ... }. Never throws.
function E.Evaluate(facts, candidate, opts)
    local ok, res = pcall(run, facts, candidate, opts)
    if ok then return res end
    return { verdict = "unknown", equip = "unknown", reasons = { { key = "error", detail = tostring(res) } } }
end
