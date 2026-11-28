local _, NS = ...
-- core/VerdictViews.lua — the names Drop Watcher's readers reach the verdict engine by, each a thin
-- view over LibKa0s-Verdict-1.0 (NS.Verdict, its pure kernel) or this addon's instance of it
-- (NS.VerdictEngine), both from core/VerdictSetup.lua (Item Search split plan, task C1).
--
-- The engine is the library's; these tables hold no logic of their own. What a view adds is what
-- the library leaves to its caller: THE CLIENT, named on every kernel call (NS.ClassData.ClientKey,
-- the client whose class list is in force), and THE LOCALE, handed to every tier-token word reader
-- (NS.L). Each view is a plain table of functions, read at call time, so a suite may stand one
-- member in (the feed's scorer, your snapshot) as it did when the engine was this addon's own.
--
--   NS.ClassData    the class list in force: the client's (V.ClassData.ForClient), its data and
--                   lookups; Install(list) puts another in force (a suite running Retail's spec
--                   model on the forever profile), ClientKey() names whose it is.
--   NS.Evaluate     the kernel: Evaluate, Equippability, ItemVerdict, TrackDelta, SubClassKey.
--   NS.OffSpec      the off-spec pass's readers; Initialized() is the clients-§4 gate
--                   (C.FEATURE.offSpec), Enabled(client) the pure query.
--   NS.TierTokens   tier tokens judged as gear, in this addon's words.
--   NS.ItemRead     a link read: the pure halves (V.ItemRead) and the instance's level and quality
--                   reads (EffectiveItemLevel, QualityOf, ItemLevelAt, QualityAt).
--   NS.ItemFacts    the instance's facts cache: Get, Read, Request, Counts, RereadCollections.
--   NS.Gear         the instance's snapshot of your gear and your candidate; NS.State.gear mirrors
--                   the snapshot this addon last saw (the diagnostics read it without a read).
--   NS.Scoring      the scorers: the pure halves (V.Score, the client named, a stat it does not
--                   score said once in the debug log) and the instance's Pawn and adapter reads.
--   NS.Collectibles a drop's category and its collection verdict (V.Collect, the client named; the
--                   instance's reads); IsFeedOnly, which reads a feed record, is the feed's own
--                   (modules/CollectFeed.lua).

local V = NS.Verdict
local C = NS.Constants

-- ── NS.ClassData ───────────────────────────────────────────────────────────────────────────

local CLIENT = NS.Compat.ClientKey()
local active = V.ClassData.ForClient(CLIENT)
local activeClient = CLIENT

local CD = {
    LISTS = V.ClassData.LISTS,
    STAT = V.ClassData.STAT,
}

--- The client whose class list is in force ("retail" | "forever"): the client every kernel view
--- names.
--- @return string
function CD.ClientKey() return activeClient end

--- The class list of `clientKey` (V.ClassData.ForClient: Retail's for any key but "forever").
function CD.ForClient(clientKey) return V.ClassData.ForClient(clientKey) end

--- Put `list` (one of CD.LISTS) in force: its data and lookups answer through NS.ClassData, and the
--- kernel views name its client.
--- @param list table
function CD.Install(list)
    active = list
    activeClient = CLIENT
    for key, l in pairs(V.ClassData.LISTS) do
        if l == list then activeClient = key end
    end
end

NS.ClassData = setmetatable(CD, { __index = function(_, k) return active and active[k] end })

-- The client the kernel views name.
local function client() return activeClient end

-- `opts` with the client named (a fresh table: the caller's is never written).
local function withClient(opts)
    local out = {}
    for k, v in pairs(type(opts) == "table" and opts or {}) do out[k] = v end
    if out.client == nil then out.client = client() end
    return out
end

-- RETAIL'S ALONE (clients-§4): the off-spec pass registers where C.FEATURE.offSpec is true, the
-- gate the declaration C.FEATURE_CLIENTS.offSpec decides (NS.Compat.ForClient, which fails at load
-- on an unknown token), whatever class list is in force. Where it is false a candidate's
-- offSpecGear is never handed to the kernel, so no off-spec part is attached.
local INITIALIZED = C.FEATURE.offSpec == true

local function gated(candidate)
    if INITIALIZED or type(candidate) ~= "table" or candidate.offSpecGear == nil then return candidate end
    local out = {}
    for k, v in pairs(candidate) do out[k] = v end
    out.offSpecGear = nil
    return out
end

-- ── NS.Evaluate ────────────────────────────────────────────────────────────────────────────

NS.Evaluate = {
    --- The verdict on `facts` for `candidate` (V.Evaluate), the client named. Never throws.
    Evaluate = function(facts, candidate, opts)
        return V.Evaluate(facts, gated(candidate), withClient(opts))
    end,
    --- Step 1 alone (V.Equippability), the client named.
    Equippability = function(facts, candidate) return V.Equippability(facts, candidate, client()) end,
    ItemVerdict = function(delta, band) return V.ItemVerdict(delta, band) end,
    TrackDelta = function(drop, base) return V.TrackDelta(drop, base) end,
    SubClassKey = function(classID, subClassID) return V.SubClassKey(classID, subClassID) end,
}

-- ── NS.OffSpec ─────────────────────────────────────────────────────────────────────────────

local OS = V.OffSpec

-- Initialized() is the gate above; Enabled(client) the pure query for a named client, never the gate.
NS.OffSpec = {
    SPEC_REASONS = OS.SPEC_REASONS,
    Initialized = function() return INITIALIZED end,
    Enabled = function(clientKey) return OS.Enabled(clientKey) end,
    Who = function(classFile, specID) return OS.Who(classFile, specID, client()) end,
    WornGear = function(gear, who) return OS.WornGear(gear, who, client()) end,
    Of = function(eval) return OS.Of(eval) end,
    EvalFor = function(eval) return OS.EvalFor(eval) end,
}

-- ── NS.TierTokens ──────────────────────────────────────────────────────────────────────────

local TT = V.TierTokens

NS.TierTokens = {
    Listed = function(itemID) return TT.Listed(itemID) end,
    UseNamesClass = function(useText) return TT.UseNamesClass(useText, NS.L) end,
    UseSlot = function(useText) return TT.UseSlot(useText, NS.L) end,
    NameSlot = function(name) return TT.NameSlot(name, NS.L) end,
    IsCurio = function(facts) return TT.IsCurio(facts, NS.L) end,
    Users = function(facts) return TT.Users(facts, NS.L) end,
    SlotOf = function(facts, readTooltip) return TT.SlotOf(facts, readTooltip, NS.L) end,
    Fold = function(facts, candidate, opts, run) return TT.Fold(facts, candidate, withClient(opts), run) end,
}

-- ── NS.ItemRead and NS.ItemFacts ───────────────────────────────────────────────────────────

local IR = V.ItemRead

-- The instance, read at each call (core/VerdictSetup.lua).
local function engine() return NS.VerdictEngine end

NS.ItemRead = {
    GEAR_CLASSES = IR.GEAR_CLASSES,
    ItemString = function(link) return IR.ItemString(link) end,
    LinkDetail = function(link) return IR.LinkDetail(link) end,
    BetterLink = function(a, b) return IR.BetterLink(a, b) end,
    IdentityKey = function(link) return IR.IdentityKey(link) end,
    EffectiveItemLevel = function(where) return engine():EffectiveItemLevel(where) end,
    QualityOf = function(link) return engine():QualityOf(link) end,
    ItemLevelAt = function(bag, slot) return engine():ItemLevelAt(bag, slot) end,
    QualityAt = function(bag, slot) return engine():QualityAt(bag, slot) end,
}

-- The cache tunables (MAX_LOAD_TRIES, CACHE_CAP, EVICT_SHARE, SPELL_LOAD_WAIT) are the library's
-- (V.Facts), read through the view.
NS.ItemFacts = setmetatable({
    --- The cached facts of `link`, or the facts read now when the client has the item, or nil.
    Get = function(link) return engine():Facts(link) end,
    --- The facts read now, uncached.
    Read = function(link) return engine():ReadFacts(link) end,
    --- Get, else a load: `facts, status` ("ready" | "loading" | "invalid" | "unavailable");
    --- `callback(facts | nil, link)` once the load answers.
    Request = function(link, callback) return engine():Request(link, callback) end,
    --- How many links are cached, and how many are loading.
    Counts = function() return engine():FactsCounts() end,
    --- Read the collection state again on every cached collectible; answers how many.
    RereadCollections = function() return engine():RereadCollections() end,
    TrackTier = function(stringID, name) return V.Facts.TrackTier(stringID, name) end,
}, { __index = V.Facts })

-- ── NS.Gear ────────────────────────────────────────────────────────────────────────────────

local State = NS.State

-- The instance's snapshot, mirrored on NS.State.gear: the snapshot this addon last saw, so a
-- report can show it without reading the client (modules/Diagnostics.lua). Answers it.
local function seen()
    NS.VerdictFresh()
    local snap = engine():Snapshot()
    State.gear = snap
    return snap
end

NS.Gear = {
    THROTTLE = V.Gear.THROTTLE,
    --- Every slot id this client reads, ascending. Read, never write.
    SLOTS = V.Gear.SlotsFor(CLIENT),
    --- Your snapshot, read lazily (and quietly) on first use. Read it, never write it.
    Snapshot = function() return seen() end,
    --- Your candidate for the kernel: a fresh outer table over the snapshot's own gear.
    Candidate = function() seen(); return engine():Candidate() end,
    --- Another spec of your class's gear (Retail), nil while an item still loads.
    OffSpecGear = function(specID) seen(); return engine():OffSpecGear(specID) end,
    --- Re-read now; GearChanged when it moved, unless `quiet`. Answers whether it moved.
    Refresh = function(cause, quiet, bagsOnly)
        NS.VerdictFresh()
        local changed = engine():RefreshGear(cause, quiet, bagsOnly)
        seen()
        return changed
    end,
    IsScheduled = function() return engine():GearScheduled() end,
}

-- ── NS.Scoring ─────────────────────────────────────────────────────────────────────────────

local Score = V.Score

-- The once-per-key debug line for a stat the verdict does not score (NS.DebugOnce).
local function warn(key, name)
    if NS.DebugOnce then
        NS.DebugOnce(key, "SCORE", "%s is not a stat the verdict scores; it counts 0", tostring(name))
    end
end

local S = {
    PAWN_STATS = Score.PAWN_STATS,
    STAT_KEYS = Score.STAT_KEYS,
    SCORERS = Score.SCORERS,
    ParseImport = function(text) return Score.ParseImport(text, warn) end,
    ImportInto = function(map, specID, text) return Score.ImportInto(map, specID, text, warn) end,
    WeightsScore = function(stats, weights) return Score.WeightsScore(stats, weights, warn) end,
    HasWeights = function(map) return Score.HasWeights(map) end,
    Resolve = function(configured, pawnReady, hasWeights) return Score.Resolve(configured, pawnReady, hasWeights) end,
    WeightsFor = function(map, candidate, dropStats) return Score.WeightsFor(map, candidate, dropStats, client(), warn) end,
    WeightsScorer = function(map) return Score.WeightsScorer(map, client(), warn) end,
    --- The adapter in use now ("pawn" | "weights" | "none"), from `cfg` (the host's config when nil).
    InUse = function(cfg) return engine():ScorerInUse(cfg) end,
    --- The scorer the kernel takes, from `cfg` (the host's config when nil).
    Scorer = function(cfg) return engine():Scorer(cfg) end,
    --- One item's score for `who` and how it was chosen.
    ScoreFor = function(link, who, cfg) return engine():ScoreFor(link, who, cfg) end,
}
-- Assigned apart: the compat gate reads a Pawn name in a table constructor as a client call.
S.PawnScale = function(candidate, dropLink) local e = engine(); return e.PawnScale(e, candidate, dropLink) end
S.PawnScorer = function() local e = engine(); return e.PawnScorer(e) end
NS.Scoring = S

-- ── NS.Collectibles ────────────────────────────────────────────────────────────────────────

local CO = V.Collect

NS.Collectibles = {
    --- The category the facts and the probe's collection answers name, first match wins.
    CategoryOf = function(facts, probe) return CO.CategoryOf(facts, probe) end,
    --- Whether a category gets a collection verdict.
    IsCollectible = function(facts) return CO.IsCollectible(facts) end,
    --- The `me` evaluation of a collectible, a kind word or an item of no kind; nil for gear.
    Verdict = function(facts, forced) return CO.Verdict(facts, forced, client()) end,
    --- Fill `facts.category` and `facts.collect` through the instance's reads; answers the table.
    Read = function(facts) return CO.Read(facts, engine().R) end,
}
