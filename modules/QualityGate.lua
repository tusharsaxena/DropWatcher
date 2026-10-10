local _, NS = ...
-- modules/QualityGate.lua — the minimum-quality gate (design spec §6.2): is a drop's quality high
-- enough for the feed to show it?
--
-- PURE. The decision functions take plain values and tables and make no WoW API call, read no saved
-- variable and keep no state, so the headless suite drives them table by table
-- (test_quality_gate). The settings reach it as plain `ctx` fields (DW-40 wires the rows); Gear
-- supplies the equipped qualities and Evaluate (the verdict for me) the baseline slot and the
-- verdict, both read by LootFeed before the inspect request (spec §6.2, Ordering).
--
--   ctx = { fixed = 3, floor = 2, upgradeOverride = true,
--           gear = { [slot] = quality | facts | false },  -- equipped; false = empty
--           baselineSlot = slot,                         -- the verdict for me's baselineSlot
--           equipLoc = "INVTYPE_...",                    -- the plan fallback with no baseline slot
--           verdict = "upgrade" | ... }                  -- the verdict for me
--
-- Modes: `fixed` (ctx.fixed), `dynamicSlot` (the baseline slot's equipped quality, floored; an
-- empty slot is the floor) and `dynamicCharacter` (the most common equipped quality ignoring
-- shirt, tabard and empty slots, ties to the lower, floored). A per-situation `quality` setting
-- replaces the global mode through ResolveMode.
--
-- It NEVER THROWS: garbage in ctx falls back to the spec defaults, and a drop whose quality cannot
-- be read passes (reason `qualityUnknown`), so the feed never hides what it could not judge.

NS.QualityGate = NS.QualityGate or {}
local Q = NS.QualityGate
local C = NS.Constants
local L = NS.L

local DEFAULT_MODE = C.QUALITY_MODES[1]
local MODES = {}
for _, mode in ipairs(C.QUALITY_MODES) do MODES[mode] = true end

-- The quality ids' display names (the filter bar's text).
local QL = C.QUALITY
local NAMES = {
    [QL.POOR] = L["Poor"], [QL.COMMON] = L["Common"], [QL.UNCOMMON] = L["Uncommon"],
    [QL.RARE] = L["Rare"], [QL.EPIC] = L["Epic"], [QL.LEGENDARY] = L["Legendary"],
    [QL.ARTIFACT] = L["Artifact"], [QL.HEIRLOOM] = L["Heirloom"],
}

local function isTable(v) return type(v) == "table" end

-- A real number, or nil (NaN and every non-number are nil).
local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function ctxOf(ctx)
    if isTable(ctx) then return ctx end
    return {}
end

local function floorOf(ctx) return num(ctx.floor) or C.QUALITY_DEFAULT.FLOOR end

--- `mode` when it is one of C.QUALITY_MODES, else the default `fixed`.
function Q.NormalizeMode(mode)
    if MODES[mode] then return mode end
    return DEFAULT_MODE
end

--- The mode in force in a situation: the situation's own `quality` setting when it names a mode,
--- else the global mode (absent, "global" or anything unknown). Always a valid mode.
function Q.ResolveMode(globalMode, situationQuality)
    if MODES[situationQuality] then return situationQuality end
    return Q.NormalizeMode(globalMode)
end

-- A gear entry's quality: the entry itself when it is a number, its facts' `quality` otherwise; nil
-- for an empty, unread or unreadable slot.
local function qualityOf(v)
    if isTable(v) then return num(v.quality) end
    return num(v)
end

--- The most common quality across the equipped gear, ignoring shirt, tabard and empty slots; ties
--- go to the lower quality. Nil when no slot has a readable quality.
function Q.CharacterQuality(gear)
    if not isTable(gear) then return nil end
    local counts = {}
    for slot, v in pairs(gear) do
        local q = qualityOf(v)
        if q and not C.QUALITY_IGNORED_SLOT[slot] then counts[q] = (counts[q] or 0) + 1 end
    end
    local best, bestCount
    for q, n in pairs(counts) do
        if not best or n > bestCount or (n == bestCount and q < best) then best, bestCount = q, n end
    end
    return best
end

-- The lowest equipped quality across the drop's slot plan, or nil when any of its slots is empty
-- (the drop fills that one) or the equip location has no plan.
local function planQuality(gear, equipLoc)
    local plan = C.SLOT_PLAN[equipLoc]
    if not plan then return nil end
    local low
    for _, slot in ipairs(plan.slots) do
        local q = qualityOf(gear[slot])
        if not q then return nil end
        if not low or q < low then low = q end
    end
    return low
end

-- The quality of the item the drop would replace: the baseline slot's, else the plan's lowest.
local function slotQuality(ctx)
    local gear = ctx.gear
    if not isTable(gear) then return nil end
    if ctx.baselineSlot ~= nil then return qualityOf(gear[ctx.baselineSlot]) end
    return planQuality(gear, ctx.equipLoc)
end

-- A dynamic quality floored; `missing` names the source when there is no quality at all.
local function floored(q, ctx, source, missing)
    local floor = floorOf(ctx)
    if not q then return floor, missing end
    if q < floor then return floor, "floor" end
    return q, source
end

local THRESHOLDS = {
    fixed = function(ctx) return num(ctx.fixed) or C.QUALITY_DEFAULT.FIXED, "fixed" end,
    dynamicSlot = function(ctx) return floored(slotQuality(ctx), ctx, "slot", "emptySlot") end,
    dynamicCharacter = function(ctx)
        return floored(Q.CharacterQuality(ctx.gear), ctx, "character", "noGear")
    end,
}

--- The threshold a mode sets, and where it came from: `fixed`, `slot`, `character`, `floor`,
--- `emptySlot` or `noGear`. For the debug line, the diagnostics report and the settings readout.
function Q.Threshold(mode, ctx)
    return THRESHOLDS[Q.NormalizeMode(mode)](ctxOf(ctx))
end

--- The decision (design spec §6.2): pass, threshold, reasonKey. reasonKey is `atThreshold`,
--- `upgradeOverride` (below the threshold but an upgrade for me, with the override on),
--- `belowThreshold` or `qualityUnknown` (the drop's quality is not a number; it passes).
function Q.Passes(dropQuality, mode, ctx)
    ctx = ctxOf(ctx)
    local threshold = Q.Threshold(mode, ctx)
    local q = num(dropQuality)
    if not q then return true, threshold, "qualityUnknown" end
    if q >= threshold then return true, threshold, "atThreshold" end
    if ctx.upgradeOverride ~= false and ctx.verdict == "upgrade" then
        return true, threshold, "upgradeOverride"
    end
    return false, threshold, "belowThreshold"
end

--- A quality id's display name ("Rare"), or the id itself as text when it is not a known quality.
function Q.QualityName(quality)
    return NAMES[quality] or tostring(quality)
end

--- The filter bar's text: `Quality: Rare+`, `Quality: Match slot` or `Quality: Match gear (Epic+)`.
--- The slot mode's threshold differs per drop, so its label names none.
function Q.ThresholdLabel(mode, threshold)
    mode = Q.NormalizeMode(mode)
    if mode == "dynamicSlot" then return L["Quality: Match slot"] end
    local t = num(threshold)
    if mode == "dynamicCharacter" then
        if not t then return L["Quality: Match gear"] end
        return L["Quality: Match gear (%s+)"]:format(Q.QualityName(t))
    end
    return L["Quality: %s+"]:format(Q.QualityName(t or C.QUALITY_DEFAULT.FIXED))
end
