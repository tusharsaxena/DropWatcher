-- LibKa0s-Verdict-1.0 -- the scorers the kernel's `opts.scorer` takes, as `lib.Score` (the pure
-- halves) and the instance's v:Scorer / v:ScoreFor / v:ScorerInUse (the Pawn reads). Moved from
-- Ka0s Drop Watcher's modules/Scoring.lua (DropWatcher#19).
--
-- Three adapters, one chosen by the host config's `scorer` (auto | pawn | weights | none):
--
--   Pawn     an optional addon, reached only through the instance's reads (the Pawn seam). For
--            YOU, the scale is the best visible one Pawn reports for the drop (its highest
--            PercentUpgrade), else your spec's; for a looter, their spec's. The drop and the
--            baseline are both valued on that scale, so the kernel's scoreDelta is a difference on
--            one scale. A nil answer from Pawn means "not ready": the adapter answers "pending" and
--            the instance retries (VerdictGear.lua's v:Judge). WoW Forever (the class list's
--            PAWN_BY_TREE): Pawn has one scale per talent tree and no specs, so for you: your visible
--            custom scale, else your top talent tree's (the Druid's Feral 2 or 3 by your role), else
--            with no tree the best of your class's scales; for a looter the best of their class's.
--   Weights  your own per-spec weights, `weights[key] = { STAT_KEY = weight }`, the key the specID
--            (Retail) or "<classFile>:<tree>" (WoW Forever, ClassData's SpecKey): the score is the
--            sum of stat times weight. A Pawn scale string imports into one spec.
--   None     no scorer: the verdict is item level alone.
--
-- `auto` uses Pawn once it has initialized, else your weights when any are set, else none. `pawn`
-- with Pawn absent or not initialized is none, and so is `weights` with none set: ScorerInUse names
-- the adapter actually in use.
--
-- The pure halves take plain values and make no client call. The members whose answer depends on
-- the class list take the `client` last (WeightsFor, WeightsScorer; Retail's when nil). A weight
-- whose stat key is not one this file knows contributes 0 and is reported once through `warn(key)`
-- when the caller passes one (the instance's DebugOnce, tag SCORE); it never raises. A scorer is
-- called under pcall by the kernel, so even a third-party error is no score.
--
-- Depends on the Verdict shell (Verdict.lua) and VerdictClassData.lua; VerdictFacts.lua is read at
-- call time.

local lib = LibStub and LibStub("LibKa0s-Verdict-1.0", true)
if not lib or not lib.ClassData then return end

local SCORE_MINOR = 1
local ORDER = 80   -- its place in LibKa0s.xml (Verdict.lua, lib.__Stale)
-- Minor 1 (DropWatcher#19, task B2): Drop Watcher's scorers, the settings the host's config.
if lib.__scoreMinor and lib.__scoreMinor >= SCORE_MINOR
  and lib.__scoreShellMinor == lib.MINOR and not lib.__Stale(ORDER) then return end
lib.__scoreMinor      = SCORE_MINOR
lib.__scoreShellMinor = lib.MINOR
lib.__Ran(ORDER)

lib.MODULES = lib.MODULES or {}
lib.MODULES.VerdictScore = SCORE_MINOR

local S = {}
lib.Score = S
local methods = lib.__methods

-- Pawn's stat names -> GetItemStats' keys (the keys the item facts and a weights editor use).
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

local PAWN_META = { Class = true, Spec = true }

S.SCORERS = { auto = true, pawn = true, weights = true, none = true }

local function isTable(v) return type(v) == "table" end

local function num(v)
  if type(v) == "number" and v == v then return v end
  return nil
end

-- ---------------------------------------------------------------------------------------------
-- The pure halves
-- ---------------------------------------------------------------------------------------------

local function readPair(pair, out, warn)
  local key, value = pair:match("^%s*([%a_][%w_]*)%s*=%s*(%-?[%d%.]+)%s*$")
  value = value and tonumber(value)
  if not (key and value) or PAWN_META[key] then return end
  local stat = S.PAWN_STATS[key]
  if not stat then
    out.skipped[#out.skipped + 1] = key
    if warn then warn("import:" .. key, key) end
  elseif value ~= 0 then
    out.weights[stat] = value
  end
end

--- A Pawn scale string, `( Pawn: v1: "name": Key=value, ... )`, read into weights. Answers
--- { name, weights = { [STAT_KEY] = n }, skipped = { PawnKey, ... } }, or nil and a reason:
--- "empty", "format" (not a v1 Pawn string) or "noStats" (no stat it scores). `warn(key, name)` is
--- told of each stat it skips.
--- @param text string
--- @param warn function|nil
--- @return table|nil, string|nil
function S.ParseImport(text, warn)
  if type(text) ~= "string" or not text:match("%S") then return nil, "empty" end
  local name, body = text:match('^%s*%(%s*Pawn%s*:%s*v1%s*:%s*"([^"]*)"%s*:(.-)%)%s*$')
  if not name then return nil, "format" end
  local out = { name = name, weights = {}, skipped = {} }
  for pair in (body .. ","):gmatch("([^,]*),") do readPair(pair, out, warn) end
  table.sort(out.skipped)
  if next(out.weights) == nil then return nil, "noStats" end
  return out
end

--- The weights map with spec `specID`'s weights (a specID, or a "<classFile>:<tree>" key) replaced
--- by an imported string's, as a fresh table. Answers the map and ParseImport's result, or nil and
--- its reason ("noSpec" without a spec).
--- @return table|nil, table|string
function S.ImportInto(map, specID, text, warn)
  if num(specID) == nil and type(specID) ~= "string" then return nil, "noSpec" end
  local parsed, why = S.ParseImport(text, warn)
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
--- weights; a weight on a stat key this file does not know counts 0 and `warn(key)` is told.
--- @param stats table|nil
--- @param weights table|nil
--- @param warn function|nil
--- @return number|nil
function S.WeightsScore(stats, weights, warn)
  if not (isTable(stats) and isTable(weights)) or next(weights) == nil then return nil end
  local sum = 0
  for key, w in pairs(weights) do
    if S.STAT_KEYS[key] then
      sum = sum + (num(stats[key]) or 0) * (num(w) or 0)
    elseif warn then
      warn("weight:" .. tostring(key), tostring(key))
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
--- ready and whether any weights are set.
--- @return string
function S.Resolve(configured, pawnReady, hasWeights)
  if not S.SCORERS[configured] then configured = "auto" end
  if configured == "none" then return "none" end
  if configured ~= "weights" and pawnReady then return "pawn" end
  if configured ~= "pawn" and hasWeights then return "weights" end
  return "none"
end

-- WoW Forever with no talent tree: the class's tree whose weights score the drop highest.
local function bestTreeWeights(CD, map, classFile, dropStats, warn)
  local best, top
  for _, key in ipairs(CD.CLASS_SPECS[classFile] or {}) do
    local v = S.WeightsScore(dropStats, map[key], warn)
    if v and (top == nil or v > top) then best, top = map[key], v end
  end
  return best
end

--- The weights a candidate is scored with, and how they were chosen: their spec's (Retail) or
--- talent tree's (WoW Forever), how = "custom"; on Forever with no tree, the class's tree whose
--- weights score the drop's stats highest, how = "bestOfClass". Nil and "none" when there are none.
--- `client` names the class list (Retail's when nil).
--- @return table|nil, string
function S.WeightsFor(map, candidate, dropStats, client, warn)
  if not (isTable(map) and isTable(candidate)) then return nil, "none" end
  local CD = lib.ClassData.ForClient(client)
  local w, how
  if not CD.PAWN_BY_TREE then
    w, how = map[candidate.specID], "custom"
  else
    local key = CD.SpecKey(candidate.classFile, candidate.specID, num(candidate.tree))
    if key ~= nil then
      w, how = map[key], "custom"
    elseif isTable(dropStats) then
      w, how = bestTreeWeights(CD, map, candidate.classFile, dropStats, warn), "bestOfClass"
    end
  end
  if not isTable(w) or next(w) == nil then return nil, "none" end
  return w, how
end

--- The Weights adapter over a weights map: a scorer(facts, candidate, drop) answering the score
--- under the candidate's spec's (or talent tree's) weights, nil when it has none.
--- @param map table { [specKey] = { [STAT_KEY] = weight } }
--- @param client string|nil
--- @param warn function|nil
--- @return function
function S.WeightsScorer(map, client, warn)
  return function(facts, candidate, drop)
    if not isTable(facts) then return nil end
    local w = S.WeightsFor(map, candidate, isTable(drop) and drop.stats or facts.stats, client, warn)
    if not w then return nil end
    return S.WeightsScore(facts.stats, w, warn)
  end
end

-- ---------------------------------------------------------------------------------------------
-- The Pawn adapter (the instance's reads)
-- ---------------------------------------------------------------------------------------------

local function plainLink(R, v)
  if R.IsSecret(v) or type(v) ~= "string" or v == "" then return nil end
  return v
end

local function bestVisibleScale(R, link)
  local list = R.PawnUpgradeInfo(link)
  if list == nil then return "pending" end
  local best, pct
  for _, e in ipairs(list) do
    local p = isTable(e) and num(e.PercentUpgrade)
    if p and type(e.ScaleName) == "string" and (pct == nil or p > pct) then best, pct = e.ScaleName, p end
  end
  return best
end

local function specScale(v, candidate, visibleFirst)
  local CD = v:ClassData()
  local classID = CD.CLASS_ID[candidate.classFile]
  if not (classID and num(candidate.specID)) then return nil end
  local starter = v.R.PawnScaleForSpec(classID, candidate.specID, nil, nil, v.client)
  local shown = visibleFirst and v.R.PawnVisibleScale(classID, candidate.specID, nil, nil, v.client) or nil
  if shown and shown ~= starter then return shown, "custom" end
  return starter or shown, "tree"
end

local function specPick(v, candidate, dropLink)
  if not candidate.isPlayer then return specScale(v, candidate) end
  local best = bestVisibleScale(v.R, dropLink)
  if best == "pending" then return "pending", "none" end
  if best then return best, "bestOfClass" end
  return specScale(v, candidate, true)
end

local function roleOf(v, candidate)
  if candidate.role then return candidate.role end
  if candidate.isPlayer then return (v.R.PlayerRole()) end
  return nil
end

local function bestOfClass(R, classID, dropLink)
  if R.PawnItemData(dropLink) == nil then return "pending" end
  local best, top
  for _, s in ipairs(R.PawnClassScales(classID)) do
    local val = R.PawnItemValue(dropLink, s.name)
    if val and (top == nil or val > top) then best, top = s.name, val end
  end
  return best
end

local function treePick(v, candidate, classID, dropLink)
  local R = v.R
  local tree, mine = num(candidate.tree), candidate.isPlayer == true
  local role = roleOf(v, candidate)
  local starter = tree and R.PawnScaleForSpec(classID, candidate.specID, tree, role, v.client) or nil
  local shown
  if mine and tree then
    shown = R.PawnVisibleScale(classID, candidate.specID, tree, role, v.client)
  elseif mine then
    shown = R.PawnCustomScale(classID)
  end
  if shown and shown ~= starter then return shown, "custom" end
  if starter then return starter, "tree" end
  return bestOfClass(R, classID, dropLink), "bestOfClass"
end

--- The Pawn scale a candidate is scored on for a drop, and how it was chosen: "tree", "custom",
--- "bestOfClass" or "none"; the scale is "pending" while Pawn has not read the drop.
--- @return string|nil scale, string how
function methods:PawnScale(candidate, dropLink)
  dropLink = plainLink(self.R, dropLink)
  if not (isTable(candidate) and dropLink) then return nil, "none" end
  local CD = self:ClassData()
  local scale, how
  if CD.PAWN_BY_TREE then
    local classID = CD.CLASS_ID[candidate.classFile]
    if classID then scale, how = treePick(self, candidate, classID, dropLink) end
  else
    scale, how = specPick(self, candidate, dropLink)
  end
  if scale == nil then return nil, "none" end
  return scale, how or "none"
end

local function memoKey(candidate, dropLink)
  if candidate.isPlayer then return "me|" .. dropLink end
  return ("%s:%s:%s|%s"):format(tostring(candidate.classFile), tostring(candidate.specID),
    tostring(candidate.tree), dropLink)
end

--- The Pawn adapter: a scorer(facts, candidate, drop) for the kernel, one per evaluation pass, so
--- each candidate's scale is chosen once per drop.
--- @return function
function methods:PawnScorer()
  local memo, R = {}, self.R
  local function scaleFor(candidate, dropLink)
    local key = memoKey(candidate, dropLink)
    if memo[key] == nil then
      local scale = self:PawnScale(candidate, dropLink)
      if scale == "pending" then return "pending" end
      memo[key] = scale or false
    end
    return memo[key] or nil
  end
  return function(facts, candidate, drop)
    if not R.PawnIsReady() then return "pending" end
    local link = isTable(facts) and plainLink(R, facts.link)
    local dropLink = isTable(drop) and plainLink(R, drop.link) or link
    if not (link and dropLink and isTable(candidate)) then return nil end
    local scale = scaleFor(candidate, dropLink)
    if scale == "pending" then return "pending" end
    if scale == nil then return nil end
    return R.PawnItemValue(link, scale) or "pending"
  end
end

-- ---------------------------------------------------------------------------------------------
-- The instance's scorer
-- ---------------------------------------------------------------------------------------------

-- The instance's once-per-key report of a stat it does not score.
local function warnOf(v)
  return function(key, name)
    v:DebugOnce(key, "SCORE", "%s is not a stat the verdict scores; it counts 0", tostring(name))
  end
end

--- The adapter in use now: "pawn", "weights" or "none", from `cfg` (the host's config when nil).
--- @param cfg table|nil
--- @return string
function methods:ScorerInUse(cfg)
  cfg = isTable(cfg) and cfg or self:Config()
  return S.Resolve(cfg.scorer, self.R.PawnIsReady(), S.HasWeights(cfg.weights))
end

--- The scorer for the kernel's opts.scorer, or nil (item level alone), from `cfg` (the host's
--- config when nil). Read per judgment, so a settings change or Pawn loading takes effect on the
--- next one.
--- @param cfg table|nil
--- @return function|nil
function methods:Scorer(cfg)
  cfg = isTable(cfg) and cfg or self:Config()
  local use = self:ScorerInUse(cfg)
  if use == "pawn" then return self:PawnScorer() end
  if use == "weights" then return S.WeightsScorer(cfg.weights, self.client, warnOf(self)) end
  return nil
end

--- One item's score for `who` (a candidate) by the scorer in use, and how its scale or weights
--- were chosen; nil while Pawn or the item cache has not read it, or with no score at all.
--- @param link string
--- @param who table
--- @param cfg table|nil the host's config when nil
--- @return number|nil, string
function methods:ScoreFor(link, who, cfg)
  link = plainLink(self.R, link)
  if not (link and isTable(who)) then return nil, "none" end
  cfg = isTable(cfg) and cfg or self:Config()
  local use = self:ScorerInUse(cfg)
  if use == "pawn" then
    local scale, how = self:PawnScale(who, link)
    if scale == nil or scale == "pending" then return nil, how end
    return self.R.PawnItemValue(link, scale), how
  end
  if use ~= "weights" then return nil, "none" end
  local facts = self.Facts and self:Facts(link)
  local stats = isTable(facts) and facts.stats or nil
  local warn = warnOf(self)
  local w, how = S.WeightsFor(cfg.weights, who, stats, self.client, warn)
  local val = w and S.WeightsScore(stats, w, warn)
  if val == nil then return nil, "none" end
  return val, how
end
