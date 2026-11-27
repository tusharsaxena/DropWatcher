local _, NS = ...
-- core/VerdictSetup.lua — NS.Verdict and NS.VerdictEngine, the LibKa0s-Verdict-1.0 seam
-- (library-stack-§7; Item Search split plan, task C1, DropWatcher#19).
--
-- The verdict engine ("what is this item to me": an upgrade, a sidegrade, a downgrade, something
-- you cannot use or do not want) is the library's: Drop Watcher's own engine moved there so Ka0s
-- Item Search judges the same item the same way. This file holds the descriptor, the one instance
-- and the library-absent stand-in; core/VerdictViews.lua holds the views Drop Watcher's readers
-- reach it through (NS.Evaluate, NS.ClassData, NS.OffSpec, NS.TierTokens, NS.ItemRead,
-- NS.ItemFacts, NS.Gear, NS.Scoring, NS.Collectibles).
--
-- NS.Verdict is the major (its pure kernel: Evaluate, ClassData, OffSpec, TierTokens, C, Collect,
-- Score, ItemRead, Settings). NS.VerdictEngine is this addon's one instance, `V:New(host)`, which
-- keeps the item facts cache, your gear snapshot, the scorer and the collection re-read. The host:
--
--   client     NS.Compat.ClientKey(), once: the class list, the slots, the off-spec and transmog
--              gates, the default verdict mode and the events are this client's.
--   config     NS.LootFeed.VerdictConfig(): the six `comparison.*` values and LF.VERDICT_MODE.
--   reads      every read the instance makes goes to NS.Compat's member of the same name (NS.Item's
--              for ItemIDFromLink, QualityFromLink and LoadItem), looked up at each call, so the
--              simulator's seam (core/SimSetup.lua wraps every NS.Compat member) still guards each
--              one, and this addon's own PlayerRole (its role override) is the one read.
--   deferWhile NS.Restrictions.InCombat: a bag event in combat waits for the combat's end.
--   events     registered through NS.FEATURE_EVENTS (core/DropWatcher.lua), one row per event the
--              instance listens to, so the stand-down drops them with every other row and the
--              simulator's replay (NS.DeliverEvent) reaches them. host.registerEvent only keeps
--              the instance's handler for its row.
--   onChange   "gear" sends NS.MSG.GEAR_CHANGED; "collection" runs the feed's re-judge
--              (NS.CollectFeed.OnCollectionsChanged).
--
-- THE LIFECYCLE. The instance stands up at OnEnable and at every stand-up (NS.VerdictStandUp, run by
-- core/DropWatcher.lua), which registers its handlers and reads your gear once; it stands down with
-- the addon (NS.STAND_DOWN), which drops its timers and caches.
--
-- Absent library: NS.Verdict is a stand-in whose kernel answers `unknown` for every item, and
-- NS.VerdictEngine one that reads nothing, so every verdict reads "unknown" and nothing raises.

local V = LibStub and LibStub("LibKa0s-Verdict-1.0", true)

-- ── the library-absent stand-in ────────────────────────────────────────────────────────────

local function none() return nil end
local function empty() return {} end
local MISSING = "LibKa0s-Verdict-1.0 is missing"

local function unknownVerdict()
    return { verdict = "unknown", equip = "unknown", reasons = { { key = "error", detail = MISSING } } }
end

-- A class list with no class in it: every lookup answers nothing.
local function emptyList()
    local list = { CLASS_ID = {}, ARMOR = {}, WEAPONS = {}, SPECS = {}, CLASS_SPECS = {}, SPEC_INDEX = {},
        STAT_GATE = {}, STAT = {} }
    for _, name in ipairs({ "Spec", "OwnSpec", "SpecKey", "PrimaryStat", "DualWieldFor", "TitanGripFor",
        "CanUseShield", "CanUseOffhand", "SpecIndex", "ArmorFor", "CanWearArmor", "CanUseRelic",
        "CanUseWeapon" }) do
        list[name] = none
    end
    return list
end

local function stubLib()
    local lists = { retail = emptyList(), forever = emptyList() }
    return {
        MISSING = true,
        Evaluate = unknownVerdict,
        Equippability = function() return "unknown", "error" end,
        ItemVerdict = none, TrackDelta = none,
        SubClassKey = function(classID, subClassID) return tostring(classID) .. ":" .. tostring(subClassID) end,
        VerdictModeFor = function(client) return client == "forever" and "scoreFirst" or "ilvlFirst" end,
        ClassData = { LISTS = lists, ForClient = function(key) return lists[key] or lists.retail end },
        OffSpec = {
            SPEC_REASONS = {}, Enabled = function() return false end,
            Who = function(classFile, specID) return { classFile = classFile, specID = specID } end,
            WornGear = empty, Of = none, EvalFor = function(eval) return eval end, Attach = none,
        },
        TierTokens = { Listed = function() return false end, UseNamesClass = function() return false end,
            UseSlot = none, NameSlot = none, IsCurio = function() return false end, Users = none,
            SlotOf = none, Fold = unknownVerdict },
        ItemRead = { GEAR_CLASSES = {}, ItemString = none, LinkDetail = none,
            BetterLink = function(a, b) return a or b end, IdentityKey = function(link) return link end },
        Facts = { TrackTier = none },
        Collect = { REREAD_DELAY = 0.5, CategoryOf = none, IsCollectible = function() return false end,
            Verdict = none, Read = none },
        Score = { PAWN_STATS = {}, STAT_KEYS = {}, SCORERS = { auto = true, pawn = true, weights = true, none = true },
            ParseImport = function() return {} end, ImportInto = function(map) return map, 0 end,
            WeightsScore = function() return 0 end, HasWeights = function() return false end,
            Resolve = function() return "none" end, WeightsFor = none, WeightsScorer = function() return none end },
        Gear = { THROTTLE = 0.5, SlotsFor = empty },
    }
end

-- The instance stand-in: no facts, an empty snapshot, no scorer; every method answers its nothing.
-- Its methods are plain functions (called with `:`, they ignore the instance).
local function stubEngine(client)
    local snap = { equipped = {}, owned = {}, pool = {}, bySpec = {}, loading = 0, signature = false }
    local function answer(...)
        local n, out = select("#", ...), { ... }
        return function() return unpack(out, 1, n) end
    end
    local nothing = function() end
    local e = {
        Client = answer(client), Judge = answer(nil, false), JudgeFacts = unknownVerdict, Facts = none,
        ReadFacts = none, Request = answer(nil, "unavailable"), FactsCounts = answer(0, 0),
        RereadCollections = answer(0), EffectiveItemLevel = none, QualityOf = none, ItemLevelAt = none,
        QualityAt = none, Snapshot = answer(snap), Signature = answer(false),
        Candidate = function() return { gear = snap.equipped, owned = snap.owned, isPlayer = true } end,
        OffSpecGear = none, ReadGear = answer(snap), RefreshGear = answer(false), ScheduleGear = nothing,
        GearScheduled = answer(false), OnGearEvent = nothing, OnGearDeferEnd = nothing, Scorer = none,
        ScorerInUse = answer("none"), ScoreFor = none,
        CollectionsChanged = nothing, StandUp = nothing, StandDown = nothing, IsStoodDown = answer(false),
    }
    -- Set apart: the compat gate reads a Pawn name in a table constructor as a client call.
    e.PawnScale, e.PawnScorer = none, none
    return e
end

NS.Verdict = V or stubLib()

-- ── the host ───────────────────────────────────────────────────────────────────────────────

local CLIENT = NS.Compat.ClientKey()

-- The reads the instance takes from NS.Item rather than NS.Compat.
local ITEM_READS = { ItemIDFromLink = true, QualityFromLink = true, LoadItem = true }

-- Each read the instance asks for, resolved at the call: NS.Compat's member (the simulator's
-- guarded one), else NS.Item's, else nil (the library's own default).
local reads = setmetatable({}, { __index = function(_, name)
    if ITEM_READS[name] then return NS.Item and NS.Item[name] end
    return NS.Compat[name]
end })

-- The instance's events, by client, as the library's API document lists them
-- (docs/api/Verdict, *The instance*). Each is one NS.FEATURE_EVENTS row whose handler hands the
-- event to the instance's handler for it (host.registerEvent).
local EVENTS = {
    { "PLAYER_EQUIPMENT_CHANGED" }, { "BAG_UPDATE_DELAYED" }, { "PLAYER_REGEN_ENABLED" },
    { "SPELL_TEXT_UPDATE" }, { "NEW_MOUNT_ADDED" }, { "NEW_PET_ADDED" }, { "NEW_TOY_ADDED" },
    { "NEW_RECIPE_LEARNED" }, { "SKILL_LINES_CHANGED" },
    { "PLAYER_SPECIALIZATION_CHANGED", { "retail" } }, { "TRANSMOG_COLLECTION_UPDATED", { "retail" } },
    { "TRAIT_CONFIG_UPDATED", { "forever" } }, { "CHARACTER_POINTS_CHANGED", { "forever" } },
    { "PLAYER_LEVEL_UP", { "forever" } },
}
local ROUTED = {}
for _, e in ipairs(EVENTS) do
    ROUTED[e[1]] = true
    NS.FEATURE_EVENTS[#NS.FEATURE_EVENTS + 1] = { e[1], "OnVerdictEvent", clients = e[2] }
end

-- The events whose handling has moved onto the instance so far (the C1 slices widen it).
local ADOPTED = { SPELL_TEXT_UPDATE = true, TRANSMOG_COLLECTION_UPDATED = true }

-- The instance's handler per event, kept while it is stood up.
local handlers = {}

function NS.addon.OnVerdictEvent(_, event, ...)
    local fn = handlers[event]
    if fn then fn(event, ...) end
end

local host = {
    client = CLIENT,
    L = NS.L,
    reads = reads,
    config = function() return NS.LootFeed and NS.LootFeed.VerdictConfig() or nil end,
    debug = function(tag, msg) NS.Debug(tag, "%s", msg) end,
    deferWhile = function() return NS.Restrictions ~= nil and NS.Restrictions.InCombat() end,
    registerEvent = function(event, fn)
        if not ADOPTED[event] then return end
        if not ROUTED[event] then
            NS.Debug("Init", "verdict: %s has no NS.FEATURE_EVENTS row; it is not heard", tostring(event))
        end
        handlers[event] = fn
    end,
    unregisterEvent = function(event) handlers[event] = nil end,
    onChange = function(kind)
        if kind == "gear" then
            return   -- modules/Gear.lua still sends it (until the gear slice)
        elseif kind == "collection" and NS.CollectFeed then
            NS.CollectFeed.OnCollectionsChanged()
        end
    end,
}

-- The perf harness (core/PerfSetup.lua) times the instance's gear rebuild (`gear.rebuild`) while a
-- capture is on; `on` is read at each call. The feed times its own verdicts (modules/LootFeed.lua's
-- `evaluate`, inside `feed.add`): it judges through the kernel views, never v:JudgeFacts.
host.perf = setmetatable({
    Note = function(key, ms) NS.Perf.Note(key, ms) end,
}, { __index = function(_, k) if k == "on" then return NS.Perf and NS.Perf.on end end })

NS.VerdictEngine = V and V:New(host) or stubEngine(CLIENT)

--- Stand the instance up: its handlers kept and your gear read once (core/DropWatcher.lua's
--- OnEnable and stand-up).
function NS.VerdictStandUp() NS.VerdictEngine:StandUp() end

NS.STAND_DOWN[#NS.STAND_DOWN + 1] = function() NS.VerdictEngine:StandDown() end
NS.STAND_UP[#NS.STAND_UP + 1] = NS.VerdictStandUp
