local _, NS = ...
-- modules/Scoring.lua — the scorers the verdict kernel's `opts.scorer` takes (design spec §5.4).
--
-- Three adapters, one chosen by `comparison.scorer` (auto | pawn | weights | none):
--
--   Pawn     an optional dependency, reached only through NS.Compat's Pawn seam. For YOU, the scale
--            is the best visible one Pawn reports for the drop (PawnIsItemAnUpgrade's highest
--            PercentUpgrade), else your spec's; for a looter, their spec's (PawnFindScaleForSpec, asked
--            by the spec's place in its class, which is how Pawn numbers its scales; NS.Compat).
--            The drop and the baseline are both valued on that scale (PawnGetSingleValueFromItem's
--            unenchanted value, the one Pawn's own upgrade test compares), so the kernel's
--            scoreDelta is a difference on one scale. A nil answer from Pawn means
--            "not ready": the adapter answers "pending" and LootFeed retries on its shared timer.
--   Weights  your own per-spec weights, `comparison.weights[specID] = { STAT_KEY = weight }`: the
--            score is the sum of stat times weight. A Pawn scale string imports into one spec.
--   None     no scorer: the verdict is item level alone.
--
-- `auto` uses Pawn once it has initialized (Pawn's PawnIsReady(), design spec §5.4: merely loaded
-- is not enough), else your weights when any are set, else none. `pawn` with Pawn absent or not yet
-- initialized is none, and so is `weights` with none set: InUse names the adapter actually in use
-- (the diagnostics' Scoring section prints both).
--
-- The pure halves (ParseImport, ImportInto, WeightsScore, HasWeights, Resolve) take plain values
-- and make no client call, so test_scoring drives them directly. A weight whose stat key is not one
-- this file knows contributes 0 and is logged once per key (NS.DebugOnce, tag SCORE); it never
-- raises. A scorer is called under pcall by the kernel, so even a third-party error is no score.

NS.Scoring = NS.Scoring or {}
local S = NS.Scoring
local CD = NS.ClassData

-- Pawn's stat names -> GetItemStats' keys (the keys the item facts and the weights editor use).
S.PAWN_STATS = {
    Strength = "ITEM_MOD_STRENGTH_SHORT", Agility = "ITEM_MOD_AGILITY_SHORT",
    Intellect = "ITEM_MOD_INTELLECT_SHORT", Stamina = "ITEM_MOD_STAMINA_SHORT",
    CritRating = "ITEM_MOD_CRIT_RATING_SHORT", HasteRating = "ITEM_MOD_HASTE_RATING_SHORT",
    MasteryRating = "ITEM_MOD_MASTERY_RATING_SHORT", Versatility = "ITEM_MOD_VERSATILITY",
    Leech = "ITEM_MOD_CR_LIFESTEAL_SHORT", Avoidance = "ITEM_MOD_CR_AVOIDANCE_SHORT",
    MovementSpeed = "ITEM_MOD_CR_SPEED_SHORT", Indestructible = "ITEM_MOD_CR_STURDINESS_SHORT",
}

-- The stat keys a weight counts for.
S.STAT_KEYS = {}
for _, key in pairs(S.PAWN_STATS) do S.STAT_KEYS[key] = true end

-- A Pawn string's header fields: read past quietly, never reported as unknown stats.
local PAWN_META = { Class = true, Spec = true }

S.SCORERS = { auto = true, pawn = true, weights = true, none = true }

local function isTable(v) return type(v) == "table" end

local function num(v)
    if type(v) == "number" and v == v then return v end
    return nil
end

local function debugOnce(key, fmt, ...)
    if NS.DebugOnce then NS.DebugOnce(key, "SCORE", fmt, ...) end
end

-- ── the pure halves ─────────────────────────────────────────────────────────────────────────

-- One `Key=value` pair of a Pawn string into `out`: a known stat, a header field, or skipped.
local function readPair(pair, out)
    local key, value = pair:match("^%s*([%a_][%w_]*)%s*=%s*(%-?[%d%.]+)%s*$")
    value = value and tonumber(value)
    if not (key and value) or PAWN_META[key] then return end
    local stat = S.PAWN_STATS[key]
    if not stat then
        out.skipped[#out.skipped + 1] = key
        debugOnce("import:" .. key, "Pawn import: %s is not a stat Drop Watcher scores; it counts 0", key)
    elseif value ~= 0 then
        out.weights[stat] = value
    end
end

--- A Pawn scale string, `( Pawn: v1: "name": Key=value, ... )`, read into weights. Answers
--- { name, weights = { [STAT_KEY] = n }, skipped = { PawnKey, ... } }, or nil and a reason:
--- "empty", "format" (not a v1 Pawn string) or "noStats" (no stat it scores).
--- @param text string
--- @return table|nil, string|nil
function S.ParseImport(text)
    if type(text) ~= "string" or not text:match("%S") then return nil, "empty" end
    local name, body = text:match('^%s*%(%s*Pawn%s*:%s*v1%s*:%s*"([^"]*)"%s*:(.-)%)%s*$')
    if not name then return nil, "format" end
    local out = { name = name, weights = {}, skipped = {} }
    for pair in (body .. ","):gmatch("([^,]*),") do readPair(pair, out) end
    table.sort(out.skipped)
    if next(out.weights) == nil then return nil, "noStats" end
    return out
end

--- The weights map with spec `specID`'s weights replaced by an imported string's: a fresh table
--- (the seam stores what it is handed). Answers the map and ParseImport's result, or nil and its
--- reason ("noSpec" without a spec).
--- @return table|nil, table|string
function S.ImportInto(map, specID, text)
    if num(specID) == nil then return nil, "noSpec" end
    local parsed, why = S.ParseImport(text)
    if not parsed then return nil, why end
    local out = {}
    for spec, w in pairs(isTable(map) and map or {}) do
        local copy = {}
        for k, v in pairs(isTable(w) and w or {}) do copy[k] = v end
        out[spec] = copy
    end
    out[specID] = parsed.weights
    return out, parsed
end

--- An item's score under one spec's weights: the sum of stat times weight. Nil without stats or
--- weights; a weight on a stat key this file does not know counts 0 and is logged once.
--- @param stats table|nil { [STAT_KEY] = n }
--- @param weights table|nil { [STAT_KEY] = weight }
--- @return number|nil
function S.WeightsScore(stats, weights)
    if not (isTable(stats) and isTable(weights)) or next(weights) == nil then return nil end
    local sum = 0
    for key, w in pairs(weights) do
        if S.STAT_KEYS[key] then
            sum = sum + (num(stats[key]) or 0) * (num(w) or 0)
        else
            debugOnce("weight:" .. tostring(key), "weights: %s is not a stat Drop Watcher scores; it counts 0",
                tostring(key))
        end
    end
    return sum
end

--- Whether any spec has a weight set.
--- @return boolean
function S.HasWeights(map)
    if not isTable(map) then return false end
    for _, w in pairs(map) do
        if isTable(w) and next(w) ~= nil then return true end
    end
    return false
end

--- The adapter in use: "pawn", "weights" or "none", from the configured scorer, whether Pawn is
--- ready (initialized) and whether any weights are set.
--- @param configured string auto | pawn | weights | none
--- @param pawnReady boolean
--- @param hasWeights boolean
--- @return string
function S.Resolve(configured, pawnReady, hasWeights)
    if not S.SCORERS[configured] then configured = "auto" end
    if configured == "none" then return "none" end
    if configured ~= "weights" and pawnReady then return "pawn" end
    if configured ~= "pawn" and hasWeights then return "weights" end
    return "none"
end

-- ── the adapters ────────────────────────────────────────────────────────────────────────────

local function plainLink(v)
    if NS.Compat.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
    return v
end

-- The best visible scale Pawn reports for a drop against your gear: "pending" while Pawn has not
-- read it, nil when it upgrades nothing on any scale.
local function bestVisibleScale(link)
    local list = NS.Compat.PawnUpgradeInfo(link)
    if list == nil then return "pending" end
    local best, pct
    for _, e in ipairs(list) do
        local p = isTable(e) and num(e.PercentUpgrade)
        if p and type(e.ScaleName) == "string" and (pct == nil or p > pct) then best, pct = e.ScaleName, p end
    end
    return best
end

local function specScale(candidate)
    local classID = CD.CLASS_ID[candidate.classFile]
    if not (classID and num(candidate.specID)) then return nil end
    return NS.Compat.PawnScaleForSpec(classID, candidate.specID)
end

--- The Pawn adapter: a scorer(facts, candidate, drop) for the kernel. One per evaluation pass,
--- so your best visible scale is read once per drop.
--- @return function
function S.PawnScorer()
    local mine = {}
    local function scaleFor(candidate, dropLink)
        if not candidate.isPlayer then return specScale(candidate) end
        if mine[dropLink] == nil then mine[dropLink] = bestVisibleScale(dropLink) or specScale(candidate) or false end
        return mine[dropLink] or nil
    end
    return function(facts, candidate, drop)
        if not NS.Compat.PawnIsReady() then return "pending" end
        local link = isTable(facts) and plainLink(facts.link)
        local dropLink = isTable(drop) and plainLink(drop.link) or link
        if not (link and dropLink and isTable(candidate)) then return nil end
        local scale = scaleFor(candidate, dropLink)
        if scale == "pending" then mine[dropLink] = nil return "pending" end
        if scale == nil then return nil end
        return NS.Compat.PawnItemValue(link, scale) or "pending"
    end
end

--- The Weights adapter over a weights map: a scorer(facts, candidate) answering the score under
--- the candidate's spec's weights, nil when that spec has none.
--- @param map table { [specID] = { [STAT_KEY] = weight } }
--- @return function
function S.WeightsScorer(map)
    return function(facts, candidate)
        local w = isTable(map) and isTable(candidate) and map[candidate.specID]
        if not isTable(w) or not isTable(facts) then return nil end
        return S.WeightsScore(facts.stats, w)
    end
end

-- ── the edge: what the settings and the client say ──────────────────────────────────────────

--- The adapter in use now (design spec §13's Scoring section prints it beside the configured one).
--- @return string "pawn" | "weights" | "none"
function S.InUse()
    return S.Resolve(NS.Setting("comparison.scorer"), NS.Compat.PawnIsReady(),
        S.HasWeights(NS.Setting("comparison.weights")))
end

--- The scorer for the kernel's opts.scorer, or nil (item level alone). Read per evaluation pass by
--- LootFeed, so a settings change or Pawn loading takes effect on the next judgment.
--- @return function|nil
function S.Scorer()
    local use = S.InUse()
    if use == "pawn" then return S.PawnScorer() end
    if use == "weights" then return S.WeightsScorer(NS.Setting("comparison.weights")) end
    return nil
end
