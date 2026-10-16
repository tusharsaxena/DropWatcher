local _, NS = ...
-- modules/OffSpec.lua — the off-spec verdict (feedback-19 spec §0): a drop your current spec cannot
-- use, judged for every other spec of your class against your best owned item for that spec.
--
-- PURE, like the kernel it serves: plain tables in, plain tables out, no WoW API, no saved
-- variable, no state. NS.Evaluate's `run` calls Attach after the main verdict, inside the same
-- pcall; Gear and Inspect take Who and WornGear to build each spec's gear.
--
-- WHEN. Only on a main verdict of `cantUse` whose refusal depends on the spec (SPEC_REASONS): a
-- refusal on the class (armor type, weapon type, the item's class list) rules out every spec. The
-- candidate must name a known spec and bring `offSpecGear(specID)`, which answers that spec's
-- kernel `gear` map (false = empty); a throw or a non-table answer skips the spec. The spec's own
-- undesired list comes from `candidate.undesiredBySpec[specID]`.
--
-- HOW. Each spec is judged by the kernel itself on a derived candidate (Who: the spec's own hand
-- flags, never the main spec's), with the same sidegrade band and heirloom rule, compareOwned off
-- and NO scorer: off-spec is item level only, so it never waits on a score.
--
--   eval.offSpec = { specID, verdict = "upgrade" | "sidegrade" | "downgrade", ilvlDelta, trackDelta,
--                    baseline (nil for an empty slot), baselineSlot, reasons }
--
-- THE BEST SPEC. Upgrade beats sidegrade beats downgrade; then the larger ilvlDelta (an empty slot
-- the largest); then the lower spec id. doesntWant, cantUse and unknown are never kept. The main
-- verdict is never changed.

NS.OffSpec = NS.OffSpec or {}
local OS = NS.OffSpec
local CD = NS.ClassData

-- The cantUse reasons that depend on the spec: another spec of the class may answer otherwise.
OS.SPEC_REASONS = { primaryStat = true, specList = true, shield = true, offhand = true, dualWield = true }

-- The verdicts an off-spec may carry, by rank.
local RANK = { upgrade = 3, sidegrade = 2, downgrade = 1 }

local function isTable(v) return type(v) == "table" end

local function knownSpec(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

--- The identity fields of `classFile`'s spec `specID` as a kernel candidate: the hand flags are
--- that spec's own, from ClassData.
--- @return table { classFile, specID, dualWield, titanGrip }
function OS.Who(classFile, specID)
    return {
        classFile = classFile, specID = specID,
        dualWield = CD.DualWieldFor(classFile, specID), titanGrip = CD.TitanGripFor(classFile, specID),
    }
end

--- Worn gear as another spec's kernel gear: each worn item `who` could wear, false where it could
--- not (the slot reads as empty), false for an empty slot, and a slot still loading left absent.
--- @param gear table { [slot] = facts | false }
--- @param who table a candidate's identity (Who)
--- @return table|nil
function OS.WornGear(gear, who)
    if not isTable(gear) then return nil end
    local out = {}
    for slot, item in pairs(gear) do
        out[slot] = isTable(item) and NS.Evaluate.Equippability(item, who) == "ok" and item or false
    end
    return out
end

local function specRefusal(out)
    if out.verdict ~= "cantUse" then return false end
    for _, r in ipairs(out.reasons) do
        if OS.SPEC_REASONS[r.key] then return true end
    end
    return false
end

-- The spec's gear, or nil when the candidate's builder throws or answers no table.
local function gearOf(candidate, specID)
    local ok, gear = pcall(candidate.offSpecGear, specID)
    if ok and isTable(gear) then return gear end
    return nil
end

local function undesiredOf(candidate, specID)
    local lists = candidate.undesiredBySpec
    local list = isTable(lists) and lists[specID]
    if isTable(list) then return { undesired = list } end
    return nil
end

-- The kernel's answer for spec `specID`, or nil when the spec has no gear to judge against.
local function judge(facts, candidate, specID, opts, run)
    local gear = gearOf(candidate, specID)
    if not gear then return nil end
    local who = OS.Who(candidate.classFile, specID)
    who.gear, who.prefs, who.isPlayer = gear, undesiredOf(candidate, specID), candidate.isPlayer
    return run(facts, who, opts)
end

-- The difference used to break a tie: an empty slot is the largest.
local function gain(res)
    if res.baselineSlot and not res.baseline then return math.huge end
    return res.ilvlDelta or -math.huge
end

-- Whether `res` beats `best`. Specs come in ascending order, so a tie keeps the lower id.
local function better(res, best)
    if not best then return true end
    local a, b = RANK[res.verdict], RANK[best.verdict]
    if a ~= b then return a > b end
    return gain(res) > gain(best)
end

local function shape(res, specID)
    return {
        specID = specID, verdict = res.verdict, ilvlDelta = res.ilvlDelta, trackDelta = res.trackDelta,
        baseline = res.baseline, baselineSlot = res.baselineSlot, reasons = res.reasons,
    }
end

--- Sets `out.offSpec` when another spec of the candidate's class can use what the main spec
--- cannot (see the header). `run` is the kernel's own evaluation, `run(facts, candidate, opts)`.
function OS.Attach(out, facts, candidate, opts, run)
    local specID = knownSpec(candidate.specID)
    local specs = CD.CLASS_SPECS[candidate.classFile]
    if not (specID and specs and type(candidate.offSpecGear) == "function" and specRefusal(out)) then return end
    local sub = { sidegradeBand = opts.sidegradeBand, heirloomProtect = opts.heirloomProtect }
    local best, bestID
    for _, x in ipairs(specs) do
        local res = x ~= specID and judge(facts, candidate, x, sub, run)
        if res and RANK[res.verdict] and better(res, best) then best, bestID = res, x end
    end
    if best then out.offSpec = shape(best, bestID) end
end
